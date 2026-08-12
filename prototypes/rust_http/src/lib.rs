use std::ffi::CStr;
use std::fs;
use std::mem;
use std::os::raw::{c_char, c_void};
use std::ptr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread::{self, JoinHandle};
use std::time::Instant;

use futures_util::StreamExt;
use reqwest::redirect::Policy;
use reqwest::{Body, Client, Method};
use tokio::io::AsyncWriteExt;
use tokio::runtime::Builder;
use tokio::sync::Notify;
use tokio_util::io::ReaderStream;

const REQUEST_GET: i32 = 0;
const REQUEST_POST_BYTES: i32 = 1;
const REQUEST_UPLOAD_FILE: i32 = 2;
const REQUEST_DOWNLOAD_FILE: i32 = 3;
const ERROR_INVALID_ARGUMENT: i32 = -1;
const ERROR_INVALID_UTF8: i32 = -2;
const ERROR_RUNTIME: i32 = -3;
const ERROR_CLIENT: i32 = -4;
const ERROR_REQUEST: i32 = -5;
const ERROR_CANCELLED: i32 = -6;
const ERROR_FILE: i32 = -7;
const ERROR_WRITE: i32 = -8;

/// Result layout shared with the Dart FFI prototype.
#[repr(C)]
#[derive(Debug, Default, Copy, Clone)]
pub struct AxRustResult {
    pub status_code: i64,
    pub bytes_received: u64,
    pub total_ms: f64,
    pub time_to_first_byte_ms: f64,
    pub error_code: i32,
}

/// Callback invoked when response metadata is available.
pub type AxRustStreamStartCallback = extern "C" fn(i64, *const u8, u64, *mut c_void);
/// Callback invoked for an owned response chunk.
pub type AxRustStreamChunkCallback = extern "C" fn(*const u8, u64, *mut c_void);
/// Callback invoked exactly once when a request reaches a terminal state.
pub type AxRustStreamCompleteCallback = extern "C" fn(*mut AxRustResult, i32, *mut c_void);

struct Cancellation {
    requested: AtomicBool,
    notify: Notify,
}

impl Cancellation {
    fn new() -> Self {
        Self {
            requested: AtomicBool::new(false),
            notify: Notify::new(),
        }
    }

    fn cancel(&self) {
        self.requested.store(true, Ordering::Release);
        self.notify.notify_waiters();
    }

    async fn wait(&self) {
        if self.requested.load(Ordering::Acquire) {
            return;
        }
        self.notify.notified().await;
    }

    fn is_cancelled(&self) -> bool {
        self.requested.load(Ordering::Acquire)
    }
}

struct RequestConfig {
    url: String,
    request_kind: i32,
    body: Vec<u8>,
    file_path: Option<String>,
    follow_redirects: bool,
}

pub struct AxRustRequest {
    cancellation: Arc<Cancellation>,
    thread: Option<JoinHandle<()>>,
}

/// Performs one request using a reusable reqwest client.
pub async fn fetch(client: &Client, url: &str) -> Result<AxRustResult, reqwest::Error> {
    let started = Instant::now();
    let response = client.get(url).send().await?;
    let time_to_first_byte_ms = started.elapsed().as_secs_f64() * 1000.0;
    let status_code = i64::from(response.status().as_u16());
    let bytes_received = response.bytes().await?.len() as u64;
    Ok(AxRustResult {
        status_code,
        bytes_received,
        total_ms: started.elapsed().as_secs_f64() * 1000.0,
        time_to_first_byte_ms,
        error_code: 0,
    })
}

async fn run_request(
    config: RequestConfig,
    cancellation: Arc<Cancellation>,
    on_start: AxRustStreamStartCallback,
    on_chunk: AxRustStreamChunkCallback,
    user_data: *mut c_void,
) -> AxRustResult {
    let started = Instant::now();
    if cancellation.is_cancelled() {
        return cancelled_result(started);
    }
    let policy = if config.follow_redirects {
        Policy::limited(10)
    } else {
        Policy::none()
    };
    let client = match Client::builder().redirect(policy).build() {
        Ok(client) => client,
        Err(_) => return error_result(started, ERROR_CLIENT),
    };
    let method = match config.request_kind {
        REQUEST_GET | REQUEST_DOWNLOAD_FILE => Method::GET,
        REQUEST_POST_BYTES | REQUEST_UPLOAD_FILE => Method::POST,
        _ => return error_result(started, ERROR_INVALID_ARGUMENT),
    };
    let mut request = client.request(method, &config.url);
    match config.request_kind {
        REQUEST_POST_BYTES => {
            request = request.body(config.body);
        }
        REQUEST_UPLOAD_FILE => {
            let Some(path) = config.file_path.as_deref() else {
                return error_result(started, ERROR_INVALID_ARGUMENT);
            };
            let metadata = match fs::metadata(path) {
                Ok(metadata) => metadata,
                Err(_) => return error_result(started, ERROR_FILE),
            };
            let file = match tokio::fs::File::open(path).await {
                Ok(file) => file,
                Err(_) => return error_result(started, ERROR_FILE),
            };
            request = request
                .header(reqwest::header::CONTENT_LENGTH, metadata.len())
                .body(Body::wrap_stream(ReaderStream::new(file)));
        }
        REQUEST_GET | REQUEST_DOWNLOAD_FILE => {}
        _ => return error_result(started, ERROR_INVALID_ARGUMENT),
    }

    let response = tokio::select! {
        result = request.send() => match result {
            Ok(response) => response,
            Err(_) if cancellation.is_cancelled() => return cancelled_result(started),
            Err(_) => return error_result(started, ERROR_REQUEST),
        },
        _ = cancellation.wait() => return cancelled_result(started),
    };
    let status_code = i64::from(response.status().as_u16());
    let time_to_first_byte_ms = started.elapsed().as_secs_f64() * 1000.0;
    let headers = serialize_headers(status_code, response.headers());
    emit_owned_buffer(on_start, status_code, headers, user_data);

    let mut file = if config.request_kind == REQUEST_DOWNLOAD_FILE {
        let Some(path) = config.file_path.as_deref() else {
            return error_result(started, ERROR_INVALID_ARGUMENT);
        };
        match tokio::fs::File::create(path).await {
            Ok(file) => Some(file),
            Err(_) => return error_result(started, ERROR_FILE),
        }
    } else {
        None
    };
    let mut bytes_received = 0_u64;
    let mut stream = response.bytes_stream();
    while let Some(next) = tokio::select! {
        item = stream.next() => item,
        _ = cancellation.wait() => return cancelled_result(started),
    } {
        let chunk = match next {
            Ok(chunk) => chunk,
            Err(_) if cancellation.is_cancelled() => return cancelled_result(started),
            Err(_) => {
                return error_result_with_status(
                    started,
                    status_code,
                    time_to_first_byte_ms,
                    ERROR_REQUEST,
                )
            }
        };
        bytes_received += chunk.len() as u64;
        if let Some(file) = file.as_mut() {
            if file.write_all(&chunk).await.is_err() {
                return error_result_with_status(
                    started,
                    status_code,
                    time_to_first_byte_ms,
                    ERROR_WRITE,
                );
            }
        } else {
            emit_owned_chunk(on_chunk, chunk.to_vec(), user_data);
        }
    }
    if cancellation.is_cancelled() {
        return cancelled_result(started);
    }
    AxRustResult {
        status_code,
        bytes_received,
        total_ms: started.elapsed().as_secs_f64() * 1000.0,
        time_to_first_byte_ms,
        error_code: 0,
    }
}

fn serialize_headers(status_code: i64, headers: &reqwest::header::HeaderMap) -> Vec<u8> {
    let mut output = format!("HTTP/1.1 {status_code}\r\n").into_bytes();
    for (name, value) in headers {
        output.extend_from_slice(name.as_str().as_bytes());
        output.extend_from_slice(b": ");
        output.extend_from_slice(value.as_bytes());
        output.extend_from_slice(b"\r\n");
    }
    output.extend_from_slice(b"\r\n");
    output
}

fn emit_owned_buffer(
    callback: AxRustStreamStartCallback,
    status_code: i64,
    bytes: Vec<u8>,
    user_data: *mut c_void,
) {
    let (pointer, length) = leak_bytes(bytes);
    callback(status_code, pointer, length, user_data);
}

fn emit_owned_chunk(callback: AxRustStreamChunkCallback, bytes: Vec<u8>, user_data: *mut c_void) {
    let (pointer, length) = leak_bytes(bytes);
    callback(pointer, length, user_data);
}

fn leak_bytes(mut bytes: Vec<u8>) -> (*const u8, u64) {
    let length = bytes.len() as u64;
    if length == 0 {
        return (ptr::null(), 0);
    }
    let pointer = bytes.as_mut_ptr();
    mem::forget(bytes);
    (pointer, length)
}

fn error_result(started: Instant, error_code: i32) -> AxRustResult {
    AxRustResult {
        total_ms: started.elapsed().as_secs_f64() * 1000.0,
        error_code,
        ..AxRustResult::default()
    }
}

fn error_result_with_status(
    started: Instant,
    status_code: i64,
    time_to_first_byte_ms: f64,
    error_code: i32,
) -> AxRustResult {
    AxRustResult {
        status_code,
        total_ms: started.elapsed().as_secs_f64() * 1000.0,
        time_to_first_byte_ms,
        error_code,
        ..AxRustResult::default()
    }
}

fn cancelled_result(started: Instant) -> AxRustResult {
    error_result(started, ERROR_CANCELLED)
}

/// Synchronous C ABI entry point for one Dart FFI request.
#[no_mangle]
pub extern "C" fn ax_rust_get(url: *const c_char, out: *mut AxRustResult) -> i32 {
    if url.is_null() || out.is_null() {
        return ERROR_INVALID_ARGUMENT;
    }

    // SAFETY: the caller must provide a valid NUL-terminated string and writable
    // result pointer for the duration of this call. The pointers are not retained.
    let url = unsafe { CStr::from_ptr(url) };
    let Ok(url) = url.to_str() else {
        return ERROR_INVALID_UTF8;
    };
    let runtime = match Builder::new_current_thread().enable_all().build() {
        Ok(runtime) => runtime,
        Err(_) => return ERROR_RUNTIME,
    };
    let client = match Client::builder().build() {
        Ok(client) => client,
        Err(_) => return ERROR_CLIENT,
    };

    match runtime.block_on(fetch(&client, url)) {
        Ok(result) => {
            // SAFETY: validated non-null above and the caller owns the output slot.
            unsafe { ptr::write(out, result) };
            0
        }
        Err(_) => ERROR_REQUEST,
    }
}

/// Starts an asynchronous request for the Dart benchmark contract.
#[no_mangle]
pub extern "C" fn ax_rust_request_start(
    url: *const c_char,
    request_kind: i32,
    body: *const u8,
    body_length: u64,
    file_path: *const c_char,
    follow_redirects: i32,
    on_start: AxRustStreamStartCallback,
    on_chunk: AxRustStreamChunkCallback,
    on_complete: AxRustStreamCompleteCallback,
    user_data: *mut c_void,
) -> *mut AxRustRequest {
    if url.is_null() || on_complete as usize == 0 {
        return ptr::null_mut();
    }
    if !(REQUEST_GET..=REQUEST_DOWNLOAD_FILE).contains(&request_kind) {
        return ptr::null_mut();
    }
    if request_kind == REQUEST_POST_BYTES && (body_length > 0 && body.is_null()) {
        return ptr::null_mut();
    }
    if (request_kind == REQUEST_UPLOAD_FILE || request_kind == REQUEST_DOWNLOAD_FILE)
        && file_path.is_null()
    {
        return ptr::null_mut();
    }

    // SAFETY: callers provide NUL-terminated strings valid for this call. All
    // values copied below are owned by the spawned request thread.
    let url = match unsafe { CStr::from_ptr(url) }.to_str() {
        Ok(url) => url.to_owned(),
        Err(_) => return ptr::null_mut(),
    };
    let file_path = if file_path.is_null() {
        None
    } else {
        match unsafe { CStr::from_ptr(file_path) }.to_str() {
            Ok(path) => Some(path.to_owned()),
            Err(_) => return ptr::null_mut(),
        }
    };
    let body = if body_length == 0 {
        Vec::new()
    } else {
        // SAFETY: the null/length combination was validated above.
        unsafe { std::slice::from_raw_parts(body, body_length as usize) }.to_vec()
    };
    let config = RequestConfig {
        url,
        request_kind,
        body,
        file_path,
        follow_redirects: follow_redirects != 0,
    };
    let cancellation = Arc::new(Cancellation::new());
    let worker_cancellation = Arc::clone(&cancellation);
    let user_data_address = user_data as usize;
    let thread = match thread::Builder::new()
        .name("alphax-rust-http".into())
        .spawn(move || {
            let result = match Builder::new_current_thread().enable_all().build() {
                Ok(runtime) => runtime.block_on(run_request(
                    config,
                    worker_cancellation,
                    on_start,
                    on_chunk,
                    user_data_address as *mut c_void,
                )),
                Err(_) => error_result(Instant::now(), ERROR_RUNTIME),
            };
            let error_code = result.error_code;
            let result_pointer = Box::into_raw(Box::new(result));
            on_complete(result_pointer, error_code, user_data_address as *mut c_void);
        }) {
        Ok(thread) => thread,
        Err(_) => return ptr::null_mut(),
    };
    Box::into_raw(Box::new(AxRustRequest {
        cancellation,
        thread: Some(thread),
    }))
}

/// Requests cancellation of an asynchronous Rust operation.
#[no_mangle]
pub extern "C" fn ax_rust_request_cancel(request: *mut AxRustRequest) -> i32 {
    if request.is_null() {
        return ERROR_INVALID_ARGUMENT;
    }
    // SAFETY: the handle remains owned by the caller until request_free.
    unsafe { (*request).cancellation.cancel() };
    0
}

/// Joins and releases an asynchronous Rust operation.
#[no_mangle]
pub extern "C" fn ax_rust_request_free(request: *mut AxRustRequest) {
    if request.is_null() {
        return;
    }
    // SAFETY: the caller owns this opaque allocation and calls free once after
    // the completion callback has been delivered.
    let mut request = unsafe { Box::from_raw(request) };
    request.cancellation.cancel();
    if let Some(thread) = request.thread.take() {
        let _ = thread.join();
    }
}

/// Releases a buffer allocated for a start or chunk callback.
#[no_mangle]
pub extern "C" fn ax_rust_free_buffer(pointer: *mut u8, length: u64) {
    if pointer.is_null() || length == 0 {
        return;
    }
    // SAFETY: pointer/length originate from emit_owned_buffer or
    // emit_owned_chunk and are released exactly once by the Dart callback.
    unsafe {
        drop(Box::from_raw(std::ptr::slice_from_raw_parts_mut(
            pointer,
            length as usize,
        )));
    }
}

/// Releases a terminal result allocated for a completion callback.
#[no_mangle]
pub extern "C" fn ax_rust_free_result(pointer: *mut AxRustResult) {
    if pointer.is_null() {
        return;
    }
    // SAFETY: pointer originates from the completion callback and is released
    // exactly once by Dart.
    unsafe { drop(Box::from_raw(pointer)) };
}

/// Returns the prototype's C ABI version.
#[no_mangle]
pub extern "C" fn ax_rust_ffi_version() -> u32 {
    2
}

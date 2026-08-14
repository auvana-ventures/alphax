use std::ffi::CStr;
use std::fs;
use std::mem;
use std::os::raw::{c_char, c_void};
use std::ptr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::Instant;

use futures_util::StreamExt;
use reqwest::redirect::Policy;
use reqwest::{Body, Certificate, Client, Method, Version};
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
    pub connection_id: u64,
    pub http_version: i32,
    pub stream_chunk_size: u64,
    pub stream_window_chunks: u64,
    pub stream_max_in_flight_chunks: u64,
    pub stream_max_buffered_bytes: u64,
    pub stream_chunk_notifications: u64,
    pub stream_credit_exhausted_count: u64,
    pub stream_pause_count: u64,
    pub stream_resume_count: u64,
    pub stream_pause_wait_ns: u64,
    pub stream_resume_latency_ns: u64,
    pub stream_ack_count: u64,
    pub stream_acked_bytes: u64,
    pub stream_in_flight_chunks_at_completion: u64,
    pub stream_buffered_bytes_at_completion: u64,
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

#[derive(Clone, Copy)]
struct StreamConfig {
    chunk_size: u64,
    window_chunks: u64,
}

impl Default for StreamConfig {
    fn default() -> Self {
        Self {
            chunk_size: 64 * 1024,
            window_chunks: 4,
        }
    }
}

struct FlowState {
    credits: u64,
    in_flight_chunks: u64,
    in_flight_bytes: u64,
    max_in_flight_chunks: u64,
    max_buffered_bytes: u64,
    chunk_notifications: u64,
    credit_exhausted_count: u64,
    pause_count: u64,
    resume_count: u64,
    pause_wait_ns: u64,
    resume_latency_ns: u64,
    ack_count: u64,
    acked_bytes: u64,
    pending_bytes: u64,
    pause_started: Option<Instant>,
    last_credit: Option<Instant>,
}

struct FlowControl {
    config: StreamConfig,
    state: Mutex<FlowState>,
    notify: Notify,
}

impl FlowControl {
    fn new(config: StreamConfig) -> Self {
        Self {
            config,
            state: Mutex::new(FlowState {
                credits: config.window_chunks,
                in_flight_chunks: 0,
                in_flight_bytes: 0,
                max_in_flight_chunks: 0,
                max_buffered_bytes: 0,
                chunk_notifications: 0,
                credit_exhausted_count: 0,
                pause_count: 0,
                resume_count: 0,
                pause_wait_ns: 0,
                resume_latency_ns: 0,
                ack_count: 0,
                acked_bytes: 0,
                pending_bytes: 0,
                pause_started: None,
                last_credit: None,
            }),
            notify: Notify::new(),
        }
    }

    async fn reserve(&self, length: u64, cancellation: &Cancellation) -> bool {
        loop {
            if cancellation.is_cancelled() {
                return false;
            }
            let notified = self.notify.notified();
            {
                let mut state = self.state.lock().expect("flow-control mutex poisoned");
                if state.credits > 0 {
                    if let Some(started) = state.pause_started.take() {
                        state.pause_wait_ns = state
                            .pause_wait_ns
                            .saturating_add(started.elapsed().as_nanos() as u64);
                        if let Some(credit_time) = state.last_credit.take() {
                            state.resume_latency_ns = state
                                .resume_latency_ns
                                .saturating_add(credit_time.elapsed().as_nanos() as u64);
                        }
                        state.resume_count += 1;
                    }
                    state.credits -= 1;
                    state.in_flight_chunks += 1;
                    state.in_flight_bytes = state.in_flight_bytes.saturating_add(length);
                    state.max_in_flight_chunks =
                        state.max_in_flight_chunks.max(state.in_flight_chunks);
                    state.max_buffered_bytes = state.max_buffered_bytes.max(state.in_flight_bytes);
                    return true;
                }
                if state.pause_started.is_none() {
                    state.pause_started = Some(Instant::now());
                    state.pause_count += 1;
                    state.credit_exhausted_count += 1;
                }
            }
            tokio::select! {
                _ = notified => {}
                _ = cancellation.wait() => return false,
            }
        }
    }

    fn record_notification(&self) {
        let mut state = self.state.lock().expect("flow-control mutex poisoned");
        state.chunk_notifications += 1;
    }

    fn set_pending_bytes(&self, pending_bytes: u64) {
        let mut state = self.state.lock().expect("flow-control mutex poisoned");
        state.pending_bytes = pending_bytes;
        state.max_buffered_bytes = state
            .max_buffered_bytes
            .max(state.in_flight_bytes.saturating_add(pending_bytes));
    }

    fn acknowledge(&self, chunk_count: u64, byte_count: u64) {
        if chunk_count == 0 {
            return;
        }
        let mut state = self.state.lock().expect("flow-control mutex poisoned");
        let acknowledged = chunk_count.min(state.in_flight_chunks);
        if acknowledged == 0 {
            return;
        }
        let available_credits = self.config.window_chunks.saturating_sub(state.credits);
        state.credits = state
            .credits
            .saturating_add(acknowledged.min(available_credits));
        state.in_flight_chunks = state.in_flight_chunks.saturating_sub(acknowledged);
        state.in_flight_bytes = state.in_flight_bytes.saturating_sub(byte_count);
        state.ack_count = state.ack_count.saturating_add(acknowledged);
        state.acked_bytes = state.acked_bytes.saturating_add(byte_count);
        state.last_credit = Some(Instant::now());
        drop(state);
        self.notify.notify_waiters();
    }

    fn apply_result(&self, result: &mut AxRustResult) {
        let state = self.state.lock().expect("flow-control mutex poisoned");
        result.stream_chunk_size = self.config.chunk_size;
        result.stream_window_chunks = self.config.window_chunks;
        result.stream_max_in_flight_chunks = state.max_in_flight_chunks;
        result.stream_max_buffered_bytes = state.max_buffered_bytes;
        result.stream_chunk_notifications = state.chunk_notifications;
        result.stream_credit_exhausted_count = state.credit_exhausted_count;
        result.stream_pause_count = state.pause_count;
        result.stream_resume_count = state.resume_count;
        result.stream_pause_wait_ns = state.pause_wait_ns;
        result.stream_resume_latency_ns = state.resume_latency_ns;
        result.stream_ack_count = state.ack_count;
        result.stream_acked_bytes = state.acked_bytes;
        result.stream_in_flight_chunks_at_completion = state.in_flight_chunks;
        result.stream_buffered_bytes_at_completion =
            state.in_flight_bytes.saturating_add(state.pending_bytes);
    }
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
    flow: Arc<FlowControl>,
    thread: Option<JoinHandle<()>>,
}

pub struct AxRustClient {
    client: Client,
    runtime: Arc<tokio::runtime::Runtime>,
    stream_config: Mutex<StreamConfig>,
}

fn configured_client(redirect: Policy) -> Result<Client, String> {
    let mut builder = Client::builder().redirect(redirect);
    if let Ok(path) = std::env::var("ALPHAX_BENCHMARK_CA_CERT") {
        if !path.is_empty() {
            let pem = fs::read(&path)
                .map_err(|error| format!("unable to read benchmark CA certificate: {error}"))?;
            let certificate = Certificate::from_pem(&pem)
                .map_err(|error| format!("unable to parse benchmark CA certificate: {error}"))?;
            builder = builder.add_root_certificate(certificate);
        }
    }
    builder
        .build()
        .map_err(|error| format!("unable to build reqwest client: {error}"))
}

/// Performs one request using a reusable reqwest client.
pub async fn fetch(client: &Client, url: &str) -> Result<AxRustResult, reqwest::Error> {
    let started = Instant::now();
    let response = client.get(url).send().await?;
    let time_to_first_byte_ms = started.elapsed().as_secs_f64() * 1000.0;
    let status_code = i64::from(response.status().as_u16());
    let connection_id = response_connection_id(response.headers());
    let http_version = protocol_code(response.version());
    let bytes_received = response.bytes().await?.len() as u64;
    Ok(AxRustResult {
        status_code,
        bytes_received,
        total_ms: started.elapsed().as_secs_f64() * 1000.0,
        time_to_first_byte_ms,
        error_code: 0,
        connection_id,
        http_version,
        ..AxRustResult::default()
    })
}

async fn run_request(
    config: RequestConfig,
    cancellation: Arc<Cancellation>,
    shared_client: Client,
    on_start: AxRustStreamStartCallback,
    on_chunk: AxRustStreamChunkCallback,
    user_data: *mut c_void,
    flow: Arc<FlowControl>,
) -> AxRustResult {
    let mut result = run_request_inner(
        config,
        cancellation,
        shared_client,
        on_start,
        on_chunk,
        user_data,
        Arc::clone(&flow),
    )
    .await;
    flow.apply_result(&mut result);
    result
}

async fn run_request_inner(
    config: RequestConfig,
    cancellation: Arc<Cancellation>,
    shared_client: Client,
    on_start: AxRustStreamStartCallback,
    on_chunk: AxRustStreamChunkCallback,
    user_data: *mut c_void,
    flow: Arc<FlowControl>,
) -> AxRustResult {
    let started = Instant::now();
    if cancellation.is_cancelled() {
        return cancelled_result(started);
    }
    let client = if config.follow_redirects {
        shared_client
    } else {
        match configured_client(Policy::none()) {
            Ok(client) => client,
            Err(_) => return error_result(started, ERROR_CLIENT),
        }
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
            Err(error) => {
                eprintln!("AlphaX Rust request failed before response: {error:?}");
                return error_result(started, ERROR_REQUEST);
            }
        },
        _ = cancellation.wait() => return cancelled_result(started),
    };
    let status_code = i64::from(response.status().as_u16());
    let time_to_first_byte_ms = started.elapsed().as_secs_f64() * 1000.0;
    let connection_id = response_connection_id(response.headers());
    let http_version = protocol_code(response.version());
    let expected_body_bytes = response.content_length();
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
    let target_chunk_size = flow.config.chunk_size as usize;
    let mut pending_stream_bytes = Vec::with_capacity(target_chunk_size);
    while let Some(next) = tokio::select! {
        item = stream.next() => item,
        _ = cancellation.wait() => return cancelled_result(started),
    } {
        let chunk = match next {
            Ok(chunk) => chunk,
            Err(_) if cancellation.is_cancelled() => return cancelled_result(started),
            Err(error) => {
                eprintln!(
                    "AlphaX Rust response stream failed after {} bytes (declared body length: {:?}): {:?}",
                    bytes_received,
                    expected_body_bytes,
                    error,
                );
                return error_result_with_status(
                    started,
                    status_code,
                    time_to_first_byte_ms,
                    ERROR_REQUEST,
                );
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
            if pending_stream_bytes.try_reserve(chunk.len()).is_err() {
                return error_result_with_status(
                    started,
                    status_code,
                    time_to_first_byte_ms,
                    ERROR_WRITE,
                );
            }
            pending_stream_bytes.extend_from_slice(&chunk);
            flow.set_pending_bytes(pending_stream_bytes.len() as u64);
            while pending_stream_bytes.len() >= target_chunk_size {
                // Split the accumulated response without copying the
                // remainder. This gives Rust the same target-size batching
                // semantics as the libcurl callback accumulator.
                let remainder = pending_stream_bytes.split_off(target_chunk_size);
                let owned = std::mem::replace(&mut pending_stream_bytes, remainder);
                let length = owned.len() as u64;
                flow.set_pending_bytes(
                    pending_stream_bytes.len().saturating_add(owned.len()) as u64
                );
                if !flow.reserve(length, &cancellation).await {
                    flow.set_pending_bytes(0);
                    return cancelled_result(started);
                }
                flow.set_pending_bytes(pending_stream_bytes.len() as u64);
                emit_owned_chunk(on_chunk, owned, user_data);
                flow.record_notification();
            }
        }
    }
    if file.is_none() && !pending_stream_bytes.is_empty() {
        let length = pending_stream_bytes.len() as u64;
        flow.set_pending_bytes(length);
        if !flow.reserve(length, &cancellation).await {
            flow.set_pending_bytes(0);
            return cancelled_result(started);
        }
        flow.set_pending_bytes(0);
        emit_owned_chunk(on_chunk, pending_stream_bytes, user_data);
        flow.record_notification();
    }
    if cancellation.is_cancelled() {
        return cancelled_result(started);
    }
    if let Some(mut file) = file {
        // Tokio documents that dropping a File with in-flight operations can
        // defer the OS close. The completion callback is also the direct-file
        // completion boundary, so flush before returning the result.
        if file.flush().await.is_err() {
            return error_result_with_status(
                started,
                status_code,
                time_to_first_byte_ms,
                ERROR_WRITE,
            );
        }
    }
    AxRustResult {
        status_code,
        bytes_received,
        total_ms: started.elapsed().as_secs_f64() * 1000.0,
        time_to_first_byte_ms,
        error_code: 0,
        connection_id,
        http_version,
        ..AxRustResult::default()
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

fn response_connection_id(headers: &reqwest::header::HeaderMap) -> u64 {
    headers
        .get("x-alphax-server-connection-id")
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.parse::<u64>().ok())
        .unwrap_or(0)
}

fn protocol_code(version: Version) -> i32 {
    match version {
        Version::HTTP_09 => 9,
        Version::HTTP_10 => 10,
        Version::HTTP_11 => 11,
        Version::HTTP_2 => 20,
        Version::HTTP_3 => 30,
        _ => 0,
    }
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
    let client = match configured_client(Policy::limited(10)) {
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
    client: *mut AxRustClient,
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
    if client.is_null() || url.is_null() || on_complete as usize == 0 {
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
    // SAFETY: the caller keeps the client alive until all request handles have
    // completed. Clone both the client and its long-lived runtime state so the
    // reqwest dispatcher is not tied to a request-local runtime.
    let (shared_client, runtime, stream_config) = unsafe {
        let client = &*client;
        (
            client.client.clone(),
            Arc::clone(&client.runtime),
            *client
                .stream_config
                .lock()
                .expect("stream config mutex poisoned"),
        )
    };
    let flow = Arc::new(FlowControl::new(stream_config));
    let worker_flow = Arc::clone(&flow);
    let user_data_address = user_data as usize;
    let thread = match thread::Builder::new()
        .name("alphax-rust-http".into())
        .spawn(move || {
            let result = runtime.handle().block_on(run_request(
                config,
                worker_cancellation,
                shared_client,
                on_start,
                on_chunk,
                user_data_address as *mut c_void,
                worker_flow,
            ));
            let error_code = result.error_code;
            let result_pointer = Box::into_raw(Box::new(result));
            on_complete(result_pointer, error_code, user_data_address as *mut c_void);
        }) {
        Ok(thread) => thread,
        Err(_) => return ptr::null_mut(),
    };
    Box::into_raw(Box::new(AxRustRequest {
        cancellation,
        flow,
        thread: Some(thread),
    }))
}

/// Creates a shared reqwest client for one Dart transport instance.
#[no_mangle]
pub extern "C" fn ax_rust_client_create() -> *mut AxRustClient {
    let runtime = match Builder::new_multi_thread()
        .worker_threads(2)
        .enable_all()
        .build()
    {
        Ok(runtime) => Arc::new(runtime),
        Err(_) => return ptr::null_mut(),
    };
    let client = match configured_client(Policy::limited(10)) {
        Ok(client) => client,
        Err(_) => return ptr::null_mut(),
    };
    Box::into_raw(Box::new(AxRustClient {
        client,
        runtime,
        stream_config: Mutex::new(StreamConfig::default()),
    }))
}

/// Sets the experimental bounded-stream settings for a client instance.
#[no_mangle]
pub extern "C" fn ax_rust_client_set_stream_config(
    client: *mut AxRustClient,
    chunk_size: u64,
    window_chunks: u64,
) -> i32 {
    if client.is_null() || chunk_size == 0 || chunk_size > usize::MAX as u64 || window_chunks == 0 {
        return ERROR_INVALID_ARGUMENT;
    }
    // SAFETY: the caller owns the live client handle for the duration of this
    // configuration call and does not mutate it concurrently in the benchmark.
    unsafe {
        (*client)
            .stream_config
            .lock()
            .expect("stream config mutex poisoned")
            .clone_from(&StreamConfig {
                chunk_size,
                window_chunks,
            });
    }
    0
}

/// Releases a shared reqwest client after its request handles are closed.
#[no_mangle]
pub extern "C" fn ax_rust_client_free(client: *mut AxRustClient) {
    if client.is_null() {
        return;
    }
    // SAFETY: the caller owns this opaque allocation and calls free once after
    // all request handles have completed.
    unsafe { drop(Box::from_raw(client)) };
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

/// Returns credits to a bounded response stream after Dart consumes chunks.
#[no_mangle]
pub extern "C" fn ax_rust_stream_ack(
    request: *mut AxRustRequest,
    chunk_count: u64,
    byte_count: u64,
) -> i32 {
    if request.is_null() {
        return ERROR_INVALID_ARGUMENT;
    }
    // SAFETY: the request remains owned by the caller until request_free.
    unsafe { (*request).flow.acknowledge(chunk_count, byte_count) };
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
    5
}

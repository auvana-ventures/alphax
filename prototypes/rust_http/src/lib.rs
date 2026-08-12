use std::ffi::CStr;
use std::os::raw::c_char;
use std::ptr;
use std::time::Instant;

use reqwest::Client;
use tokio::runtime::Builder;

/// Result layout shared with the Dart FFI prototype.
#[repr(C)]
#[derive(Debug, Default, Copy, Clone)]
pub struct AxRustResult {
    pub status_code: i64,
    pub bytes_received: u64,
    pub total_ms: f64,
    pub error_code: i32,
}

/// Performs one request using a reusable reqwest client.
pub async fn fetch(client: &Client, url: &str) -> Result<AxRustResult, reqwest::Error> {
    let started = Instant::now();
    let response = client.get(url).send().await?;
    let status_code = i64::from(response.status().as_u16());
    let bytes_received = response.bytes().await?.len() as u64;
    Ok(AxRustResult {
        status_code,
        bytes_received,
        total_ms: started.elapsed().as_secs_f64() * 1000.0,
        error_code: 0,
    })
}

/// Synchronous C ABI entry point for one Dart FFI request.
#[no_mangle]
pub extern "C" fn ax_rust_get(url: *const c_char, out: *mut AxRustResult) -> i32 {
    if url.is_null() || out.is_null() {
        return -1;
    }

    // SAFETY: the caller must provide a valid NUL-terminated string and writable
    // result pointer for the duration of this call. The pointers are not retained.
    let url = unsafe { CStr::from_ptr(url) };
    let Ok(url) = url.to_str() else {
        return -2;
    };
    let runtime = match Builder::new_current_thread().enable_all().build() {
        Ok(runtime) => runtime,
        Err(_) => return -3,
    };
    let client = match Client::builder().build() {
        Ok(client) => client,
        Err(_) => return -4,
    };

    match runtime.block_on(fetch(&client, url)) {
        Ok(result) => {
            // SAFETY: validated non-null above and the caller owns the output slot.
            unsafe { ptr::write(out, result) };
            0
        }
        Err(_) => -5,
    }
}

/// Returns the prototype's C ABI version.
#[no_mangle]
pub extern "C" fn ax_rust_ffi_version() -> u32 {
    1
}

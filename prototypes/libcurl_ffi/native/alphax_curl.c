#if !defined(_WIN32) && !defined(_POSIX_C_SOURCE)
#define _POSIX_C_SOURCE 200809L
#endif

#include "alphax_curl.h"

#include <curl/curl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <time.h>

typedef struct WriteContext {
  AxCurlResult *result;
  FILE *file;
} WriteContext;

static char last_error[256] = "";

static uint64_t monotonic_now_ns(void) {
  struct timespec timestamp;
  if (clock_gettime(CLOCK_MONOTONIC, &timestamp) != 0) {
    return 0;
  }
  return (uint64_t)timestamp.tv_sec * 1000000000ULL + (uint64_t)timestamp.tv_nsec;
}

static size_t write_callback(char *buffer, size_t size, size_t count, void *userdata) {
  WriteContext *context = (WriteContext *)userdata;
  const size_t length = size * count;
  if (context->file != NULL) {
    return fwrite(buffer, 1, length, context->file);
  }
  context->result->bytes_received += length;
  return length;
}

static size_t read_callback(char *buffer, size_t size, size_t count, void *userdata) {
  FILE *file = (FILE *)userdata;
  return fread(buffer, size, count, file);
}

static int ensure_curl_initialized(void) {
  static int initialized = 0;
  if (!initialized) {
    const CURLcode code = curl_global_init(CURL_GLOBAL_DEFAULT);
    if (code != CURLE_OK) {
      snprintf(last_error, sizeof(last_error), "curl_global_init failed: %s", curl_easy_strerror(code));
      return (int)code;
    }
    initialized = 1;
  }
  return 0;
}

static void set_error(const char *message) {
  snprintf(last_error, sizeof(last_error), "%s", message);
}

static int perform_request(const char *url, FILE *download, FILE *upload, AxCurlResult *out) {
  if (url == NULL || out == NULL) {
    set_error("url and output are required");
    return CURLE_BAD_FUNCTION_ARGUMENT;
  }
  memset(out, 0, sizeof(*out));
  const int init_code = ensure_curl_initialized();
  if (init_code != 0) {
    out->curl_code = init_code;
    return init_code;
  }

  CURLM *multi = curl_multi_init();
  CURL *easy = curl_easy_init();
  if (multi == NULL || easy == NULL) {
    if (easy != NULL) {
      curl_easy_cleanup(easy);
    }
    if (multi != NULL) {
      curl_multi_cleanup(multi);
    }
    set_error("unable to initialize libcurl handles");
    out->curl_code = CURLE_FAILED_INIT;
    return CURLE_FAILED_INIT;
  }

  WriteContext context = {.result = out, .file = download};
  curl_easy_setopt(easy, CURLOPT_URL, url);
  curl_easy_setopt(easy, CURLOPT_FOLLOWLOCATION, 1L);
  curl_easy_setopt(easy, CURLOPT_NOSIGNAL, 1L);
  curl_easy_setopt(easy, CURLOPT_USERAGENT, "alphax-phase0-libcurl/0.1");
  curl_easy_setopt(easy, CURLOPT_WRITEFUNCTION, write_callback);
  curl_easy_setopt(easy, CURLOPT_WRITEDATA, &context);

  if (upload != NULL) {
    long file_size = 0;
    if (fseek(upload, 0, SEEK_END) != 0 || (file_size = ftell(upload)) < 0 || fseek(upload, 0, SEEK_SET) != 0) {
      set_error("unable to determine upload file size");
      curl_easy_cleanup(easy);
      curl_multi_cleanup(multi);
      out->curl_code = CURLE_READ_ERROR;
      return CURLE_READ_ERROR;
    }
    curl_easy_setopt(easy, CURLOPT_UPLOAD, 1L);
    curl_easy_setopt(easy, CURLOPT_READFUNCTION, read_callback);
    curl_easy_setopt(easy, CURLOPT_READDATA, upload);
    curl_easy_setopt(easy, CURLOPT_INFILESIZE_LARGE, (curl_off_t)file_size);
  }

  CURLMcode multi_code = curl_multi_add_handle(multi, easy);
  if (multi_code != CURLM_OK) {
    snprintf(last_error, sizeof(last_error), "curl_multi_add_handle failed: %s", curl_multi_strerror(multi_code));
    curl_easy_cleanup(easy);
    curl_multi_cleanup(multi);
    out->curl_code = CURLE_FAILED_INIT;
    return CURLE_FAILED_INIT;
  }

  int running = 0;
  CURLcode result_code = CURLE_OK;
  do {
    multi_code = curl_multi_perform(multi, &running);
    if (multi_code != CURLM_OK) {
      snprintf(last_error, sizeof(last_error), "curl_multi_perform failed: %s", curl_multi_strerror(multi_code));
      result_code = CURLE_FAILED_INIT;
      break;
    }
    if (running > 0) {
      long timeout_ms = -1;
      multi_code = curl_multi_timeout(multi, &timeout_ms);
      if (multi_code != CURLM_OK) {
        snprintf(last_error, sizeof(last_error), "curl_multi_timeout failed: %s", curl_multi_strerror(multi_code));
        result_code = CURLE_FAILED_INIT;
        break;
      }
      if (timeout_ms < 0 || timeout_ms > 1000) {
        timeout_ms = 1000;
      }
      int descriptors = 0;
      const uint64_t wait_start_ns = monotonic_now_ns();
      multi_code = curl_multi_poll(multi, NULL, 0, (int)timeout_ms, &descriptors);
      const uint64_t wait_elapsed_ns = monotonic_now_ns() - wait_start_ns;
      out->event_loop_wait_count++;
      out->event_loop_wait_ns += wait_elapsed_ns;
      if (wait_elapsed_ns > out->event_loop_max_wait_ns) {
        out->event_loop_max_wait_ns = wait_elapsed_ns;
      }
      if (multi_code != CURLM_OK) {
        snprintf(last_error, sizeof(last_error), "curl_multi_poll failed: %s", curl_multi_strerror(multi_code));
        result_code = CURLE_FAILED_INIT;
        break;
      }
    }
  } while (running > 0);

  out->response_body_complete_ns = monotonic_now_ns();

  int messages_left = 0;
  CURLMsg *message = NULL;
  while ((message = curl_multi_info_read(multi, &messages_left)) != NULL) {
    if (message->msg == CURLMSG_DONE) {
      result_code = message->data.result;
      out->curl_done_ns = monotonic_now_ns();
    }
  }

  curl_easy_getinfo(easy, CURLINFO_RESPONSE_CODE, &out->status_code);
  curl_easy_getinfo(easy, CURLINFO_NAMELOOKUP_TIME, &out->name_lookup_ms);
  curl_easy_getinfo(easy, CURLINFO_CONNECT_TIME, &out->connect_ms);
  curl_easy_getinfo(easy, CURLINFO_APPCONNECT_TIME, &out->tls_ms);
  curl_easy_getinfo(easy, CURLINFO_STARTTRANSFER_TIME, &out->time_to_first_byte_ms);
  curl_easy_getinfo(easy, CURLINFO_TOTAL_TIME, &out->total_ms);
  long http_version = 0;
  curl_easy_getinfo(easy, CURLINFO_HTTP_VERSION, &http_version);
  out->name_lookup_ms *= 1000.0;
  out->connect_ms *= 1000.0;
  out->tls_ms *= 1000.0;
  out->time_to_first_byte_ms *= 1000.0;
  out->total_ms *= 1000.0;
  out->http_version = (int32_t)http_version;
  out->curl_code = (int32_t)result_code;

  curl_multi_remove_handle(multi, easy);
  curl_easy_cleanup(easy);
  curl_multi_cleanup(multi);
  return (int)result_code;
}

ALPHAX_CURL_EXPORT int32_t ax_curl_get(const char *url, AxCurlResult *out) {
  return perform_request(url, NULL, NULL, out);
}

ALPHAX_CURL_EXPORT int32_t ax_curl_download(const char *url, const char *path, AxCurlResult *out) {
  if (path == NULL) {
    set_error("download path is required");
    return CURLE_BAD_FUNCTION_ARGUMENT;
  }
  FILE *file = fopen(path, "wb");
  if (file == NULL) {
    set_error("unable to open download path");
    return CURLE_WRITE_ERROR;
  }
  const int code = perform_request(url, file, NULL, out);
  fclose(file);
  return code;
}

ALPHAX_CURL_EXPORT int32_t ax_curl_upload(const char *url, const char *path, AxCurlResult *out) {
  if (path == NULL) {
    set_error("upload path is required");
    return CURLE_BAD_FUNCTION_ARGUMENT;
  }
  FILE *file = fopen(path, "rb");
  if (file == NULL) {
    set_error("unable to open upload path");
    return CURLE_READ_ERROR;
  }
  const int code = perform_request(url, NULL, file, out);
  fclose(file);
  return code;
}

struct AxCurlClient {
  CURLSH *share;
  pthread_mutex_t mutex;
  uint64_t stream_chunk_size;
  uint64_t stream_window_chunks;
};

static void share_lock(CURL *easy,
                       curl_lock_data data,
                       curl_lock_access access,
                       void *userdata) {
  (void)easy;
  (void)data;
  (void)access;
  AxCurlClient *client = (AxCurlClient *)userdata;
  pthread_mutex_lock(&client->mutex);
}

static void share_unlock(CURL *easy, curl_lock_data data, void *userdata) {
  (void)easy;
  (void)data;
  AxCurlClient *client = (AxCurlClient *)userdata;
  pthread_mutex_unlock(&client->mutex);
}

struct AxCurlStreamHandle {
  pthread_t thread;
  pthread_mutex_t mutex;
  pthread_cond_t flow_condition;
  int thread_started;
  int cancel_requested;
  CURLM *multi;
  int32_t request_kind;
  int32_t follow_redirects;
  char *url;
  uint8_t *body;
  size_t body_length;
  char *file_path;
  FILE *file;
  curl_off_t upload_size;
  AxCurlStreamStartCallback on_start;
  AxCurlStreamChunkCallback on_chunk;
  AxCurlStreamCompleteCallback on_complete;
  void *user_data;
  AxCurlResult result;
  char *header_block;
  size_t header_length;
  size_t header_capacity;
  int64_t header_status_code;
  int start_emitted;
  int callback_failed;
  AxCurlClient *client;
  struct curl_slist *request_headers;
  uint64_t stream_chunk_size;
  uint64_t stream_window_chunks;
  uint64_t stream_credits;
  uint64_t stream_in_flight_chunks;
  uint64_t stream_in_flight_bytes;
  uint64_t stream_max_in_flight_chunks;
  uint64_t stream_max_buffered_bytes;
  uint64_t stream_chunk_notifications;
  uint64_t stream_credit_exhausted_count;
  uint64_t stream_pause_count;
  uint64_t stream_resume_count;
  uint64_t stream_pause_wait_ns;
  uint64_t stream_resume_latency_ns;
  uint64_t stream_ack_count;
  uint64_t stream_acked_bytes;
  uint64_t stream_pause_started_ns;
  uint64_t stream_last_credit_ns;
  int stream_paused;
  uint8_t *stream_batch_buffer;
  size_t stream_batch_length;
  size_t stream_batch_capacity;
};

static char *duplicate_string(const char *value) {
  if (value == NULL) {
    return NULL;
  }
  const size_t length = strlen(value);
  char *copy = (char *)malloc(length + 1);
  if (copy == NULL) {
    return NULL;
  }
  memcpy(copy, value, length + 1);
  return copy;
}

static int is_cancelled(AxCurlStreamHandle *handle) {
  int cancelled = 0;
  pthread_mutex_lock(&handle->mutex);
  cancelled = handle->cancel_requested;
  pthread_mutex_unlock(&handle->mutex);
  return cancelled;
}

static int append_header_bytes(AxCurlStreamHandle *handle, const char *bytes, size_t length) {
  if (length == 0) {
    return 1;
  }
  if (handle->header_length > SIZE_MAX - length) {
    return 0;
  }
  const size_t required = handle->header_length + length;
  if (required > handle->header_capacity) {
    size_t capacity = handle->header_capacity == 0 ? 256 : handle->header_capacity;
    while (capacity < required) {
      if (capacity > SIZE_MAX / 2) {
        capacity = required;
        break;
      }
      capacity *= 2;
    }
    char *buffer = (char *)realloc(handle->header_block, capacity);
    if (buffer == NULL) {
      return 0;
    }
    handle->header_block = buffer;
    handle->header_capacity = capacity;
  }
  memcpy(handle->header_block + handle->header_length, bytes, length);
  handle->header_length += length;
  return 1;
}

static uint64_t parse_header_uint64(const char *bytes, size_t length, const char *name) {
  const size_t name_length = strlen(name);
  if (length <= name_length || strncasecmp(bytes, name, name_length) != 0 ||
      bytes[name_length] != ':') {
    return 0;
  }
  char value[64];
  size_t value_length = length - name_length - 1;
  if (value_length >= sizeof(value)) {
    value_length = sizeof(value) - 1;
  }
  memcpy(value, bytes + name_length + 1, value_length);
  value[value_length] = '\0';
  char *start = value;
  while (*start == ' ' || *start == '\t') {
    start++;
  }
  char *end = NULL;
  const unsigned long long parsed = strtoull(start, &end, 10);
  return end == start ? 0 : (uint64_t)parsed;
}

static size_t async_header_callback(char *buffer,
                                    size_t size,
                                    size_t count,
                                    void *userdata) {
  AxCurlStreamHandle *handle = (AxCurlStreamHandle *)userdata;
  const size_t length = size * count;
  if (length >= 5 && strncmp(buffer, "HTTP/", 5) == 0) {
    handle->header_length = 0;
    handle->header_status_code = 0;
    char line[256];
    const size_t line_length = length < sizeof(line) - 1 ? length : sizeof(line) - 1;
    memcpy(line, buffer, line_length);
    line[line_length] = '\0';
    const char *status_start = strchr(line + 5, ' ');
    if (status_start != NULL) {
      char *end = NULL;
      const long status = strtol(status_start + 1, &end, 10);
      if (end != status_start + 1 && status >= 0) {
        handle->header_status_code = status;
        if (status != 100 && handle->result.response_headers_ns == 0) {
          handle->result.response_headers_ns = monotonic_now_ns();
        }
      }
    }
  }
  const uint64_t server_body_read_us =
      parse_header_uint64(buffer, length, "x-alphax-server-body-read-us");
  if (server_body_read_us != 0) {
    handle->result.server_body_read_us = server_body_read_us;
  }
  if (!append_header_bytes(handle, buffer, length)) {
    handle->callback_failed = 1;
    return 0;
  }
  return length;
}

static void emit_stream_start(AxCurlStreamHandle *handle) {
  if (handle->start_emitted) {
    return;
  }
  handle->start_emitted = 1;
  if (handle->on_start == NULL) {
    return;
  }
  uint8_t *headers = NULL;
  if (handle->header_length > 0) {
    headers = (uint8_t *)malloc(handle->header_length);
    if (headers == NULL) {
      handle->callback_failed = 1;
      return;
    }
    memcpy(headers, handle->header_block, handle->header_length);
  }
  handle->on_start(
      handle->header_status_code,
      headers,
      handle->header_length,
      handle->user_data);
}

static int reserve_stream_credit(AxCurlStreamHandle *handle, size_t length) {
  pthread_mutex_lock(&handle->mutex);
  while (handle->stream_credits == 0 && !handle->cancel_requested) {
    if (!handle->stream_paused) {
      handle->stream_paused = 1;
      handle->stream_pause_started_ns = monotonic_now_ns();
      handle->stream_pause_count++;
      handle->stream_credit_exhausted_count++;
    }
    pthread_cond_wait(&handle->flow_condition, &handle->mutex);
  }
  if (handle->cancel_requested) {
    pthread_mutex_unlock(&handle->mutex);
    return 0;
  }
  const uint64_t resumed_ns = monotonic_now_ns();
  if (handle->stream_paused) {
    if (resumed_ns >= handle->stream_pause_started_ns) {
      handle->stream_pause_wait_ns += resumed_ns - handle->stream_pause_started_ns;
    }
    if (handle->stream_last_credit_ns != 0 && resumed_ns >= handle->stream_last_credit_ns) {
      handle->stream_resume_latency_ns += resumed_ns - handle->stream_last_credit_ns;
    }
    handle->stream_resume_count++;
    handle->stream_paused = 0;
    handle->stream_pause_started_ns = 0;
  }
  handle->stream_credits--;
  handle->stream_in_flight_chunks++;
  handle->stream_in_flight_bytes += length;
  if (handle->stream_in_flight_chunks > handle->stream_max_in_flight_chunks) {
    handle->stream_max_in_flight_chunks = handle->stream_in_flight_chunks;
  }
  if (handle->stream_in_flight_bytes > handle->stream_max_buffered_bytes) {
    handle->stream_max_buffered_bytes = handle->stream_in_flight_bytes;
  }
  pthread_mutex_unlock(&handle->mutex);
  return 1;
}

static void rollback_stream_credit(AxCurlStreamHandle *handle, size_t length) {
  pthread_mutex_lock(&handle->mutex);
  if (handle->stream_credits < handle->stream_window_chunks) {
    handle->stream_credits++;
  }
  if (handle->stream_in_flight_chunks > 0) {
    handle->stream_in_flight_chunks--;
  }
  if (handle->stream_in_flight_bytes >= length) {
    handle->stream_in_flight_bytes -= length;
  } else {
    handle->stream_in_flight_bytes = 0;
  }
  pthread_cond_signal(&handle->flow_condition);
  pthread_mutex_unlock(&handle->mutex);
}

static int emit_reserved_chunk(AxCurlStreamHandle *handle,
                               const uint8_t *buffer,
                               size_t length,
                               size_t reserved_length) {
  if (reserved_length != length) {
    pthread_mutex_lock(&handle->mutex);
    if (handle->stream_in_flight_bytes >= reserved_length) {
      handle->stream_in_flight_bytes -= reserved_length;
    } else {
      handle->stream_in_flight_bytes = 0;
    }
    handle->stream_in_flight_bytes += length;
    if (handle->stream_in_flight_bytes > handle->stream_max_buffered_bytes) {
      handle->stream_max_buffered_bytes = handle->stream_in_flight_bytes;
    }
    pthread_mutex_unlock(&handle->mutex);
  }
  uint8_t *chunk = (uint8_t *)malloc(length);
  if (chunk == NULL) {
    rollback_stream_credit(handle, length);
    handle->callback_failed = 1;
    return 0;
  }
  memcpy(chunk, buffer, length);
  handle->stream_chunk_notifications++;
  handle->on_chunk(chunk, length, handle->user_data);
  return 1;
}

static int append_bounded_body(AxCurlStreamHandle *handle,
                               const char *buffer,
                               size_t length) {
  if (length == 0) {
    return 1;
  }
  const size_t chunk_size = (size_t)handle->stream_chunk_size;
  size_t offset = 0;
  while (offset < length) {
    const size_t remaining = length - offset;
    if (handle->stream_batch_length == 0) {
      if (!reserve_stream_credit(handle, chunk_size)) {
        return 0;
      }
    }
    const size_t capacity = chunk_size - handle->stream_batch_length;
    const size_t current = remaining < capacity ? remaining : capacity;
    memcpy(handle->stream_batch_buffer + handle->stream_batch_length,
           buffer + offset,
           current);
    handle->stream_batch_length += current;
    offset += current;
    if (handle->stream_batch_length == chunk_size) {
      if (!emit_reserved_chunk(handle,
                               handle->stream_batch_buffer,
                               handle->stream_batch_length,
                               chunk_size)) {
        return 0;
      }
      handle->stream_batch_length = 0;
    }
  }
  return 1;
}

static int flush_bounded_body(AxCurlStreamHandle *handle) {
  if (handle->stream_batch_length == 0) {
    return 1;
  }
  const int result = emit_reserved_chunk(handle,
                                         handle->stream_batch_buffer,
                                         handle->stream_batch_length,
                                         (size_t)handle->stream_chunk_size);
  handle->stream_batch_length = 0;
  return result;
}

static size_t async_write_callback(char *buffer,
                                   size_t size,
                                   size_t count,
                                   void *userdata) {
  AxCurlStreamHandle *handle = (AxCurlStreamHandle *)userdata;
  const size_t length = size * count;
  if (is_cancelled(handle)) {
    return 0;
  }
  handle->result.response_callback_count++;
  handle->result.response_bytes_delivered += length;
  emit_stream_start(handle);
  if (handle->callback_failed) {
    return 0;
  }
  if (handle->request_kind == AX_CURL_DOWNLOAD_FILE && handle->file != NULL) {
    const size_t written = fwrite(buffer, 1, length, handle->file);
    handle->result.bytes_received += written;
    return written;
  }

  if (handle->on_chunk == NULL || length == 0) {
    handle->result.bytes_received += length;
    return length;
  }
  if (!append_bounded_body(handle, buffer, length)) {
    return 0;
  }
  handle->result.bytes_received += length;
  return length;
}

static size_t async_read_callback(char *buffer,
                                  size_t size,
                                  size_t count,
                                  void *userdata) {
  AxCurlStreamHandle *handle = (AxCurlStreamHandle *)userdata;
  const size_t length = size * count;
  handle->result.upload_callback_count++;
  if (handle->result.first_upload_callback_ns == 0) {
    handle->result.first_upload_callback_ns = monotonic_now_ns();
  }
  const size_t bytes_read = fread(buffer, 1, length, handle->file);
  if (bytes_read > 0) {
    handle->result.upload_bytes_read += bytes_read;
  }
  return bytes_read;
}

static int async_progress_callback(void *userdata,
                                   curl_off_t download_total,
                                   curl_off_t download_now,
                                   curl_off_t upload_total,
                                   curl_off_t upload_now) {
  (void)download_total;
  (void)download_now;
  if (upload_now > 0) {
    AxCurlStreamHandle *handle = (AxCurlStreamHandle *)userdata;
    if (handle->result.first_upload_byte_ns == 0) {
      handle->result.first_upload_byte_ns = monotonic_now_ns();
    }
    handle->result.upload_bytes_submitted = (uint64_t)upload_now;
    if (upload_total > 0 && upload_now >= upload_total &&
        handle->result.last_upload_byte_ns == 0) {
      handle->result.last_upload_byte_ns = monotonic_now_ns();
    }
  }
  return is_cancelled((AxCurlStreamHandle *)userdata) ? 1 : 0;
}

static void populate_async_metrics(CURL *easy, AxCurlResult *result) {
  curl_easy_getinfo(easy, CURLINFO_RESPONSE_CODE, &result->status_code);
  curl_easy_getinfo(easy, CURLINFO_NAMELOOKUP_TIME, &result->name_lookup_ms);
  curl_easy_getinfo(easy, CURLINFO_CONNECT_TIME, &result->connect_ms);
  curl_easy_getinfo(easy, CURLINFO_APPCONNECT_TIME, &result->tls_ms);
  curl_easy_getinfo(easy, CURLINFO_STARTTRANSFER_TIME, &result->time_to_first_byte_ms);
  curl_easy_getinfo(easy, CURLINFO_TOTAL_TIME, &result->total_ms);
  long http_version = 0;
  curl_easy_getinfo(easy, CURLINFO_HTTP_VERSION, &http_version);
  result->name_lookup_ms *= 1000.0;
  result->connect_ms *= 1000.0;
  result->tls_ms *= 1000.0;
  result->time_to_first_byte_ms *= 1000.0;
  result->total_ms *= 1000.0;
  result->http_version = (int32_t)http_version;
}

static int prepare_async_file(AxCurlStreamHandle *handle) {
  if (handle->request_kind == AX_CURL_UPLOAD_FILE) {
    handle->file = fopen(handle->file_path, "rb");
    if (handle->file == NULL) {
      set_error("unable to open upload path");
      return CURLE_READ_ERROR;
    }
  } else if (handle->request_kind == AX_CURL_DOWNLOAD_FILE) {
    handle->file = fopen(handle->file_path, "wb");
    if (handle->file == NULL) {
      set_error("unable to open download path");
      return CURLE_WRITE_ERROR;
    }
  }
  return CURLE_OK;
}

static int get_async_file_size(FILE *file, curl_off_t *size) {
  if (fseek(file, 0, SEEK_END) != 0) {
    return 0;
  }
  const long end = ftell(file);
  if (end < 0 || fseek(file, 0, SEEK_SET) != 0) {
    return 0;
  }
  *size = (curl_off_t)end;
  return 1;
}

static void populate_flow_result(AxCurlStreamHandle *handle) {
  pthread_mutex_lock(&handle->mutex);
  handle->result.stream_chunk_size = handle->stream_chunk_size;
  handle->result.stream_window_chunks = handle->stream_window_chunks;
  handle->result.stream_max_in_flight_chunks = handle->stream_max_in_flight_chunks;
  handle->result.stream_max_buffered_bytes = handle->stream_max_buffered_bytes;
  handle->result.stream_chunk_notifications = handle->stream_chunk_notifications;
  handle->result.stream_credit_exhausted_count = handle->stream_credit_exhausted_count;
  handle->result.stream_pause_count = handle->stream_pause_count;
  handle->result.stream_resume_count = handle->stream_resume_count;
  handle->result.stream_pause_wait_ns = handle->stream_pause_wait_ns;
  handle->result.stream_resume_latency_ns = handle->stream_resume_latency_ns;
  handle->result.stream_ack_count = handle->stream_ack_count;
  handle->result.stream_acked_bytes = handle->stream_acked_bytes;
  handle->result.stream_in_flight_chunks_at_completion = handle->stream_in_flight_chunks;
  handle->result.stream_buffered_bytes_at_completion = handle->stream_in_flight_bytes;
  pthread_mutex_unlock(&handle->mutex);
}

static int run_async_request(AxCurlStreamHandle *handle) {
  const uint64_t request_created_ns = handle->result.request_created_ns;
  memset(&handle->result, 0, sizeof(handle->result));
  handle->result.request_created_ns = request_created_ns;
  handle->result.stream_chunk_size = handle->stream_chunk_size;
  handle->result.stream_window_chunks = handle->stream_window_chunks;
  handle->result.body_preparation_start_ns = monotonic_now_ns();
  const int init_code = ensure_curl_initialized();
  if (init_code != 0) {
    handle->result.curl_code = init_code;
    return init_code;
  }

  const int file_code = prepare_async_file(handle);
  if (file_code != CURLE_OK) {
    handle->result.curl_code = file_code;
    return file_code;
  }
  handle->result.body_preparation_end_ns = monotonic_now_ns();

  CURLM *multi = curl_multi_init();
  CURL *easy = curl_easy_init();
  if (multi == NULL || easy == NULL) {
    if (easy != NULL) {
      curl_easy_cleanup(easy);
    }
    if (multi != NULL) {
      curl_multi_cleanup(multi);
    }
    set_error("unable to initialize libcurl handles");
    if (handle->file != NULL) {
      fclose(handle->file);
      handle->file = NULL;
    }
    handle->result.curl_code = CURLE_FAILED_INIT;
    return CURLE_FAILED_INIT;
  }

  pthread_mutex_lock(&handle->mutex);
  handle->multi = multi;
  pthread_mutex_unlock(&handle->mutex);

  curl_easy_setopt(easy, CURLOPT_URL, handle->url);
  curl_easy_setopt(easy, CURLOPT_SHARE, handle->client->share);
  curl_easy_setopt(easy, CURLOPT_FOLLOWLOCATION, handle->follow_redirects ? 1L : 0L);
  curl_easy_setopt(easy, CURLOPT_MAXREDIRS, 10L);
  curl_easy_setopt(easy, CURLOPT_NOSIGNAL, 1L);
  curl_easy_setopt(easy, CURLOPT_USERAGENT, "alphax-phase0-libcurl/0.1");
  curl_easy_setopt(easy, CURLOPT_HEADERFUNCTION, async_header_callback);
  curl_easy_setopt(easy, CURLOPT_HEADERDATA, handle);
  curl_easy_setopt(easy, CURLOPT_WRITEFUNCTION, async_write_callback);
  curl_easy_setopt(easy, CURLOPT_WRITEDATA, handle);
  curl_easy_setopt(easy, CURLOPT_XFERINFOFUNCTION, async_progress_callback);
  curl_easy_setopt(easy, CURLOPT_XFERINFODATA, handle);
  curl_easy_setopt(easy, CURLOPT_NOPROGRESS, 0L);

  if (handle->request_kind == AX_CURL_POST_BYTES) {
    curl_easy_setopt(easy, CURLOPT_POST, 1L);
    curl_easy_setopt(easy, CURLOPT_POSTFIELDS, handle->body);
    curl_easy_setopt(easy, CURLOPT_POSTFIELDSIZE_LARGE, (curl_off_t)handle->body_length);
  } else if (handle->request_kind == AX_CURL_UPLOAD_FILE) {
    curl_off_t file_size = 0;
    if (!get_async_file_size(handle->file, &file_size)) {
      set_error("unable to determine upload file size");
      curl_easy_cleanup(easy);
      curl_multi_cleanup(multi);
      pthread_mutex_lock(&handle->mutex);
      handle->multi = NULL;
      pthread_mutex_unlock(&handle->mutex);
      if (handle->file != NULL) {
        fclose(handle->file);
        handle->file = NULL;
      }
      handle->result.curl_code = CURLE_READ_ERROR;
      return CURLE_READ_ERROR;
    }
    handle->result.body_preparation_end_ns = monotonic_now_ns();
    curl_easy_setopt(easy, CURLOPT_POST, 1L);
    curl_easy_setopt(easy, CURLOPT_READFUNCTION, async_read_callback);
    curl_easy_setopt(easy, CURLOPT_READDATA, handle);
    curl_easy_setopt(easy, CURLOPT_POSTFIELDSIZE_LARGE, file_size);
    handle->upload_size = file_size;
    handle->request_headers = curl_slist_append(NULL, "Expect:");
    if (handle->request_headers == NULL) {
      set_error("unable to allocate upload request headers");
      curl_easy_cleanup(easy);
      curl_multi_cleanup(multi);
      pthread_mutex_lock(&handle->mutex);
      handle->multi = NULL;
      pthread_mutex_unlock(&handle->mutex);
      if (handle->file != NULL) {
        fclose(handle->file);
        handle->file = NULL;
      }
      handle->result.curl_code = CURLE_OUT_OF_MEMORY;
      return CURLE_OUT_OF_MEMORY;
    }
    curl_easy_setopt(easy, CURLOPT_HTTPHEADER, handle->request_headers);
  }

  handle->result.easy_handle_configured_ns = monotonic_now_ns();

  CURLMcode multi_code = curl_multi_add_handle(multi, easy);
  if (multi_code != CURLM_OK) {
    snprintf(last_error, sizeof(last_error), "curl_multi_add_handle failed: %s", curl_multi_strerror(multi_code));
    curl_easy_cleanup(easy);
    curl_slist_free_all(handle->request_headers);
    handle->request_headers = NULL;
    curl_multi_cleanup(multi);
    pthread_mutex_lock(&handle->mutex);
    handle->multi = NULL;
    pthread_mutex_unlock(&handle->mutex);
    if (handle->file != NULL) {
      fclose(handle->file);
      handle->file = NULL;
    }
    handle->result.curl_code = CURLE_FAILED_INIT;
    return CURLE_FAILED_INIT;
  }
  handle->result.multi_add_handle_ns = monotonic_now_ns();

  int running = 0;
  CURLcode result_code = CURLE_OK;
  do {
    multi_code = curl_multi_perform(multi, &running);
    if (multi_code != CURLM_OK) {
      snprintf(last_error, sizeof(last_error), "curl_multi_perform failed: %s", curl_multi_strerror(multi_code));
      result_code = CURLE_FAILED_INIT;
      break;
    }
    if (running > 0) {
      long timeout_ms = -1;
      multi_code = curl_multi_timeout(multi, &timeout_ms);
      if (multi_code != CURLM_OK) {
        snprintf(last_error, sizeof(last_error), "curl_multi_timeout failed: %s", curl_multi_strerror(multi_code));
        result_code = CURLE_FAILED_INIT;
        break;
      }
      if (timeout_ms < 0 || timeout_ms > 1000) {
        timeout_ms = 1000;
      }
      int descriptors = 0;
      const uint64_t wait_start_ns = monotonic_now_ns();
      multi_code = curl_multi_poll(multi, NULL, 0, (int)timeout_ms, &descriptors);
      const uint64_t wait_elapsed_ns = monotonic_now_ns() - wait_start_ns;
      handle->result.event_loop_wait_count++;
      handle->result.event_loop_wait_ns += wait_elapsed_ns;
      if (wait_elapsed_ns > handle->result.event_loop_max_wait_ns) {
        handle->result.event_loop_max_wait_ns = wait_elapsed_ns;
      }
      if (multi_code != CURLM_OK) {
        snprintf(last_error, sizeof(last_error), "curl_multi_poll failed: %s", curl_multi_strerror(multi_code));
        result_code = CURLE_FAILED_INIT;
        break;
      }
    }
  } while (running > 0);

  if (result_code == CURLE_OK && !is_cancelled(handle) && !flush_bounded_body(handle)) {
    result_code = CURLE_WRITE_ERROR;
  }
  handle->result.response_body_complete_ns = monotonic_now_ns();

  int messages_left = 0;
  CURLMsg *message = NULL;
  while ((message = curl_multi_info_read(multi, &messages_left)) != NULL) {
    if (message->msg == CURLMSG_DONE) {
      result_code = message->data.result;
      handle->result.curl_done_ns = monotonic_now_ns();
    }
  }
  populate_async_metrics(easy, &handle->result);
  if (handle->callback_failed && result_code == CURLE_OK) {
    result_code = CURLE_WRITE_ERROR;
  }
  handle->result.curl_code = (int32_t)result_code;

  curl_multi_remove_handle(multi, easy);
  curl_easy_cleanup(easy);
  curl_slist_free_all(handle->request_headers);
  handle->request_headers = NULL;
  curl_multi_cleanup(multi);
  pthread_mutex_lock(&handle->mutex);
  handle->multi = NULL;
  pthread_mutex_unlock(&handle->mutex);
  if (handle->file != NULL) {
    fclose(handle->file);
    handle->file = NULL;
  }
  populate_flow_result(handle);
  handle->result.native_cleanup_ns = monotonic_now_ns();
  return (int)result_code;
}

static void *async_request_thread(void *userdata) {
  AxCurlStreamHandle *handle = (AxCurlStreamHandle *)userdata;
  const int code = run_async_request(handle);
  populate_flow_result(handle);
  handle->result.native_completion_notification_ns = monotonic_now_ns();
  if (!handle->start_emitted) {
    emit_stream_start(handle);
  }
  if (handle->on_complete != NULL) {
    handle->on_complete(&handle->result, code, handle->user_data);
  }
  return NULL;
}

ALPHAX_CURL_EXPORT AxCurlStreamHandle *ax_curl_request_start(
    AxCurlClient *client,
    const char *url,
    int32_t request_kind,
    const uint8_t *body,
    uint64_t body_length,
    const char *file_path,
    int32_t follow_redirects,
    AxCurlStreamStartCallback on_start,
    AxCurlStreamChunkCallback on_chunk,
    AxCurlStreamCompleteCallback on_complete,
    void *user_data) {
  if (client == NULL || url == NULL || on_complete == NULL || request_kind < AX_CURL_GET ||
      request_kind > AX_CURL_DOWNLOAD_FILE) {
    set_error("invalid async request arguments");
    return NULL;
  }
  if ((request_kind == AX_CURL_POST_BYTES && body_length > 0 && body == NULL) ||
      ((request_kind == AX_CURL_UPLOAD_FILE || request_kind == AX_CURL_DOWNLOAD_FILE) &&
       (file_path == NULL || file_path[0] == '\0'))) {
    set_error("request body or file path is required");
    return NULL;
  }
  AxCurlStreamHandle *handle = (AxCurlStreamHandle *)calloc(1, sizeof(*handle));
  if (handle == NULL) {
    set_error("unable to allocate async request handle");
    return NULL;
  }
  if (pthread_mutex_init(&handle->mutex, NULL) != 0) {
    free(handle);
    set_error("unable to initialize async request mutex");
    return NULL;
  }
  if (pthread_cond_init(&handle->flow_condition, NULL) != 0) {
    pthread_mutex_destroy(&handle->mutex);
    free(handle);
    set_error("unable to initialize async flow condition");
    return NULL;
  }
  pthread_mutex_lock(&client->mutex);
  handle->stream_chunk_size = client->stream_chunk_size;
  handle->stream_window_chunks = client->stream_window_chunks;
  pthread_mutex_unlock(&client->mutex);
  if (handle->stream_chunk_size == 0) {
    handle->stream_chunk_size = 64 * 1024;
  }
  if (handle->stream_window_chunks == 0) {
    handle->stream_window_chunks = 4;
  }
  handle->stream_credits = handle->stream_window_chunks;
  if (request_kind != AX_CURL_DOWNLOAD_FILE && on_chunk != NULL) {
    handle->stream_batch_capacity = (size_t)handle->stream_chunk_size;
    handle->stream_batch_buffer = (uint8_t *)malloc(handle->stream_batch_capacity);
    if (handle->stream_batch_buffer == NULL) {
      pthread_cond_destroy(&handle->flow_condition);
      pthread_mutex_destroy(&handle->mutex);
      free(handle);
      set_error("unable to allocate bounded stream buffer");
      return NULL;
    }
  }
  handle->result.request_created_ns = monotonic_now_ns();
  handle->url = duplicate_string(url);
  handle->file_path = duplicate_string(file_path);
  handle->request_kind = request_kind;
  handle->follow_redirects = follow_redirects;
  handle->on_start = on_start;
  handle->on_chunk = on_chunk;
  handle->on_complete = on_complete;
  handle->user_data = user_data;
  handle->client = client;
  if (handle->url == NULL || (file_path != NULL && handle->file_path == NULL)) {
    pthread_cond_destroy(&handle->flow_condition);
    pthread_mutex_destroy(&handle->mutex);
    free(handle->stream_batch_buffer);
    free(handle->url);
    free(handle->file_path);
    free(handle);
    set_error("unable to copy async request arguments");
    return NULL;
  }
  if (body_length > SIZE_MAX) {
    pthread_cond_destroy(&handle->flow_condition);
    pthread_mutex_destroy(&handle->mutex);
    free(handle->stream_batch_buffer);
    free(handle->url);
    free(handle->file_path);
    free(handle);
    set_error("async request body is too large");
    return NULL;
  }
  if (body_length > 0) {
    handle->body = (uint8_t *)malloc((size_t)body_length);
    if (handle->body == NULL) {
      pthread_cond_destroy(&handle->flow_condition);
      pthread_mutex_destroy(&handle->mutex);
      free(handle->stream_batch_buffer);
      free(handle->url);
      free(handle->file_path);
      free(handle);
      set_error("unable to copy async request body");
      return NULL;
    }
    memcpy(handle->body, body, (size_t)body_length);
  }
  handle->body_length = (size_t)body_length;
  if (pthread_create(&handle->thread, NULL, async_request_thread, handle) != 0) {
    pthread_cond_destroy(&handle->flow_condition);
    pthread_mutex_destroy(&handle->mutex);
    free(handle->stream_batch_buffer);
    free(handle->body);
    free(handle->url);
    free(handle->file_path);
    free(handle);
    set_error("unable to create async request thread");
    return NULL;
  }
  handle->thread_started = 1;
  return handle;
}

ALPHAX_CURL_EXPORT AxCurlClient *ax_curl_client_create(void) {
  const int init_code = ensure_curl_initialized();
  if (init_code != 0) {
    return NULL;
  }
  AxCurlClient *client = (AxCurlClient *)calloc(1, sizeof(*client));
  pthread_mutexattr_t mutex_attributes;
  const int attributes_code = pthread_mutexattr_init(&mutex_attributes);
  if (attributes_code != 0) {
    free(client);
    set_error("unable to initialize libcurl client mutex attributes");
    return NULL;
  }
  pthread_mutexattr_settype(&mutex_attributes, PTHREAD_MUTEX_RECURSIVE);
  const int mutex_code = client == NULL ? -1 : pthread_mutex_init(&client->mutex, &mutex_attributes);
  pthread_mutexattr_destroy(&mutex_attributes);
  if (client == NULL || mutex_code != 0) {
    free(client);
    set_error("unable to allocate libcurl client");
    return NULL;
  }
  client->stream_chunk_size = 64 * 1024;
  client->stream_window_chunks = 4;
  client->share = curl_share_init();
  if (client->share == NULL ||
      curl_share_setopt(client->share, CURLSHOPT_SHARE, CURL_LOCK_DATA_DNS) != CURLSHE_OK ||
      curl_share_setopt(client->share, CURLSHOPT_LOCKFUNC, share_lock) != CURLSHE_OK ||
      curl_share_setopt(client->share, CURLSHOPT_UNLOCKFUNC, share_unlock) != CURLSHE_OK ||
      curl_share_setopt(client->share, CURLSHOPT_USERDATA, client) != CURLSHE_OK) {
    if (client->share != NULL) {
      curl_share_cleanup(client->share);
    }
    pthread_mutex_destroy(&client->mutex);
    free(client);
    set_error("unable to configure libcurl shared connection state");
    return NULL;
  }
  return client;
}

ALPHAX_CURL_EXPORT int32_t ax_curl_client_set_stream_config(
    AxCurlClient *client,
    uint64_t chunk_size,
    uint64_t window_chunks) {
  if (client == NULL || chunk_size == 0 || chunk_size > SIZE_MAX || window_chunks == 0) {
    return CURLE_BAD_FUNCTION_ARGUMENT;
  }
  pthread_mutex_lock(&client->mutex);
  client->stream_chunk_size = chunk_size;
  client->stream_window_chunks = window_chunks;
  pthread_mutex_unlock(&client->mutex);
  return CURLE_OK;
}

ALPHAX_CURL_EXPORT void ax_curl_client_free(AxCurlClient *client) {
  if (client == NULL) {
    return;
  }
  curl_share_cleanup(client->share);
  pthread_mutex_destroy(&client->mutex);
  free(client);
}

ALPHAX_CURL_EXPORT int32_t ax_curl_request_cancel(AxCurlStreamHandle *handle) {
  if (handle == NULL) {
    return CURLE_BAD_FUNCTION_ARGUMENT;
  }
  CURLM *multi = NULL;
  pthread_mutex_lock(&handle->mutex);
  handle->cancel_requested = 1;
  multi = handle->multi;
  pthread_cond_broadcast(&handle->flow_condition);
  pthread_mutex_unlock(&handle->mutex);
  if (multi != NULL) {
    curl_multi_wakeup(multi);
  }
  return CURLE_OK;
}

ALPHAX_CURL_EXPORT int32_t ax_curl_stream_ack(
    AxCurlStreamHandle *handle,
    uint64_t chunk_count,
    uint64_t byte_count) {
  if (handle == NULL) {
    return CURLE_BAD_FUNCTION_ARGUMENT;
  }
  pthread_mutex_lock(&handle->mutex);
  const uint64_t acknowledged_chunks =
      chunk_count < handle->stream_in_flight_chunks ? chunk_count : handle->stream_in_flight_chunks;
  if (acknowledged_chunks > 0) {
    const uint64_t available_credits = handle->stream_window_chunks - handle->stream_credits;
    const uint64_t restored_credits =
        acknowledged_chunks < available_credits ? acknowledged_chunks : available_credits;
    handle->stream_credits += restored_credits;
    handle->stream_in_flight_chunks -= acknowledged_chunks;
    if (byte_count >= handle->stream_in_flight_bytes) {
      handle->stream_in_flight_bytes = 0;
    } else {
      handle->stream_in_flight_bytes -= byte_count;
    }
    handle->stream_ack_count += acknowledged_chunks;
    handle->stream_acked_bytes += byte_count;
    handle->stream_last_credit_ns = monotonic_now_ns();
    pthread_cond_broadcast(&handle->flow_condition);
  }
  pthread_mutex_unlock(&handle->mutex);
  return CURLE_OK;
}

ALPHAX_CURL_EXPORT void ax_curl_request_free(AxCurlStreamHandle *handle) {
  if (handle == NULL) {
    return;
  }
  ax_curl_request_cancel(handle);
  if (handle->thread_started) {
    pthread_join(handle->thread, NULL);
  }
  pthread_cond_destroy(&handle->flow_condition);
  pthread_mutex_destroy(&handle->mutex);
  free(handle->body);
  free(handle->url);
  free(handle->file_path);
  free(handle->header_block);
  free(handle->stream_batch_buffer);
  free(handle);
}

ALPHAX_CURL_EXPORT void ax_curl_free_buffer(const uint8_t *buffer) {
  free((void *)buffer);
}

ALPHAX_CURL_EXPORT const char *ax_curl_last_error(void) {
  return last_error;
}

ALPHAX_CURL_EXPORT const char *ax_curl_version(void) {
  return curl_version();
}

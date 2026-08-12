#include "alphax_curl.h"

#include <curl/curl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct WriteContext {
  AxCurlResult *result;
  FILE *file;
} WriteContext;

static char last_error[256] = "";

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
      int descriptors = 0;
      multi_code = curl_multi_poll(multi, NULL, 0, 1000, &descriptors);
      if (multi_code != CURLM_OK) {
        snprintf(last_error, sizeof(last_error), "curl_multi_poll failed: %s", curl_multi_strerror(multi_code));
        result_code = CURLE_FAILED_INIT;
        break;
      }
    }
  } while (running > 0);

  int messages_left = 0;
  CURLMsg *message = NULL;
  while ((message = curl_multi_info_read(multi, &messages_left)) != NULL) {
    if (message->msg == CURLMSG_DONE) {
      result_code = message->data.result;
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

struct AxCurlStreamHandle {
  pthread_t thread;
  pthread_mutex_t mutex;
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

static size_t async_header_callback(char *buffer,
                                    size_t size,
                                    size_t count,
                                    void *userdata) {
  AxCurlStreamHandle *handle = (AxCurlStreamHandle *)userdata;
  const size_t length = size * count;
  if (length >= 5 && strncmp(buffer, "HTTP/", 5) == 0) {
    handle->header_length = 0;
    handle->header_status_code = 0;
    const char *status_start = strchr(buffer + 5, ' ');
    if (status_start != NULL) {
      char *end = NULL;
      const long status = strtol(status_start + 1, &end, 10);
      if (end != status_start + 1 && status >= 0) {
        handle->header_status_code = status;
      }
    }
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

static size_t async_write_callback(char *buffer,
                                   size_t size,
                                   size_t count,
                                   void *userdata) {
  AxCurlStreamHandle *handle = (AxCurlStreamHandle *)userdata;
  const size_t length = size * count;
  if (is_cancelled(handle)) {
    return 0;
  }
  emit_stream_start(handle);
  if (handle->callback_failed) {
    return 0;
  }
  if (handle->request_kind == AX_CURL_DOWNLOAD_FILE && handle->file != NULL) {
    const size_t written = fwrite(buffer, 1, length, handle->file);
    handle->result.bytes_received += written;
    return written;
  }

  handle->result.bytes_received += length;
  if (handle->on_chunk == NULL || length == 0) {
    return length;
  }
  uint8_t *chunk = (uint8_t *)malloc(length);
  if (chunk == NULL) {
    handle->callback_failed = 1;
    return 0;
  }
  memcpy(chunk, buffer, length);
  handle->on_chunk(chunk, length, handle->user_data);
  return length;
}

static int async_progress_callback(void *userdata,
                                   curl_off_t download_total,
                                   curl_off_t download_now,
                                   curl_off_t upload_total,
                                   curl_off_t upload_now) {
  (void)download_total;
  (void)download_now;
  (void)upload_total;
  (void)upload_now;
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

static int run_async_request(AxCurlStreamHandle *handle) {
  memset(&handle->result, 0, sizeof(handle->result));
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
    curl_easy_setopt(easy, CURLOPT_POST, 1L);
    curl_easy_setopt(easy, CURLOPT_READFUNCTION, read_callback);
    curl_easy_setopt(easy, CURLOPT_READDATA, handle->file);
    curl_easy_setopt(easy, CURLOPT_POSTFIELDSIZE_LARGE, file_size);
  }

  CURLMcode multi_code = curl_multi_add_handle(multi, easy);
  if (multi_code != CURLM_OK) {
    snprintf(last_error, sizeof(last_error), "curl_multi_add_handle failed: %s", curl_multi_strerror(multi_code));
    curl_easy_cleanup(easy);
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
      int descriptors = 0;
      multi_code = curl_multi_poll(multi, NULL, 0, 1000, &descriptors);
      if (multi_code != CURLM_OK) {
        snprintf(last_error, sizeof(last_error), "curl_multi_poll failed: %s", curl_multi_strerror(multi_code));
        result_code = CURLE_FAILED_INIT;
        break;
      }
    }
  } while (running > 0);

  int messages_left = 0;
  CURLMsg *message = NULL;
  while ((message = curl_multi_info_read(multi, &messages_left)) != NULL) {
    if (message->msg == CURLMSG_DONE) {
      result_code = message->data.result;
    }
  }
  populate_async_metrics(easy, &handle->result);
  if (handle->callback_failed && result_code == CURLE_OK) {
    result_code = CURLE_WRITE_ERROR;
  }
  handle->result.curl_code = (int32_t)result_code;

  curl_multi_remove_handle(multi, easy);
  curl_easy_cleanup(easy);
  curl_multi_cleanup(multi);
  pthread_mutex_lock(&handle->mutex);
  handle->multi = NULL;
  pthread_mutex_unlock(&handle->mutex);
  if (handle->file != NULL) {
    fclose(handle->file);
    handle->file = NULL;
  }
  return (int)result_code;
}

static void *async_request_thread(void *userdata) {
  AxCurlStreamHandle *handle = (AxCurlStreamHandle *)userdata;
  const int code = run_async_request(handle);
  if (!handle->start_emitted) {
    emit_stream_start(handle);
  }
  if (handle->on_complete != NULL) {
    handle->on_complete(&handle->result, code, handle->user_data);
  }
  return NULL;
}

ALPHAX_CURL_EXPORT AxCurlStreamHandle *ax_curl_request_start(
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
  if (url == NULL || on_complete == NULL || request_kind < AX_CURL_GET ||
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
  handle->url = duplicate_string(url);
  handle->file_path = duplicate_string(file_path);
  handle->request_kind = request_kind;
  handle->follow_redirects = follow_redirects;
  handle->on_start = on_start;
  handle->on_chunk = on_chunk;
  handle->on_complete = on_complete;
  handle->user_data = user_data;
  if (handle->url == NULL || (file_path != NULL && handle->file_path == NULL)) {
    pthread_mutex_destroy(&handle->mutex);
    free(handle->url);
    free(handle->file_path);
    free(handle);
    set_error("unable to copy async request arguments");
    return NULL;
  }
  if (body_length > SIZE_MAX) {
    pthread_mutex_destroy(&handle->mutex);
    free(handle->url);
    free(handle->file_path);
    free(handle);
    set_error("async request body is too large");
    return NULL;
  }
  if (body_length > 0) {
    handle->body = (uint8_t *)malloc((size_t)body_length);
    if (handle->body == NULL) {
      pthread_mutex_destroy(&handle->mutex);
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
    pthread_mutex_destroy(&handle->mutex);
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

ALPHAX_CURL_EXPORT int32_t ax_curl_request_cancel(AxCurlStreamHandle *handle) {
  if (handle == NULL) {
    return CURLE_BAD_FUNCTION_ARGUMENT;
  }
  CURLM *multi = NULL;
  pthread_mutex_lock(&handle->mutex);
  handle->cancel_requested = 1;
  multi = handle->multi;
  pthread_mutex_unlock(&handle->mutex);
  if (multi != NULL) {
    curl_multi_wakeup(multi);
  }
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
  pthread_mutex_destroy(&handle->mutex);
  free(handle->body);
  free(handle->url);
  free(handle->file_path);
  free(handle->header_block);
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

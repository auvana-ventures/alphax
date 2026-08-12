#include "alphax_curl.h"

#include <curl/curl.h>
#include <stdio.h>
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

ALPHAX_CURL_EXPORT const char *ax_curl_last_error(void) {
  return last_error;
}

ALPHAX_CURL_EXPORT const char *ax_curl_version(void) {
  return curl_version();
}

#ifndef ALPHAX_CURL_H
#define ALPHAX_CURL_H

#include <stdint.h>

#if defined(_WIN32)
#define ALPHAX_CURL_EXPORT __declspec(dllexport)
#else
#define ALPHAX_CURL_EXPORT __attribute__((visibility("default")))
#endif

typedef struct AxCurlResult {
  int64_t status_code;
  uint64_t bytes_received;
  double name_lookup_ms;
  double connect_ms;
  double tls_ms;
  double time_to_first_byte_ms;
  double total_ms;
  int32_t curl_code;
  int32_t http_version;
} AxCurlResult;

typedef struct AxCurlStreamHandle AxCurlStreamHandle;
typedef struct AxCurlClient AxCurlClient;

typedef void (*AxCurlStreamStartCallback)(int64_t status_code,
                                          const uint8_t *headers,
                                          uint64_t headers_length,
                                          void *user_data);
typedef void (*AxCurlStreamChunkCallback)(const uint8_t *bytes,
                                          uint64_t length,
                                          void *user_data);
typedef void (*AxCurlStreamCompleteCallback)(const AxCurlResult *result,
                                             int32_t curl_code,
                                             void *user_data);

enum AxCurlRequestKind {
  AX_CURL_GET = 0,
  AX_CURL_POST_BYTES = 1,
  AX_CURL_UPLOAD_FILE = 2,
  AX_CURL_DOWNLOAD_FILE = 3,
};

ALPHAX_CURL_EXPORT int32_t ax_curl_get(const char *url, AxCurlResult *out);
ALPHAX_CURL_EXPORT int32_t ax_curl_download(const char *url, const char *path, AxCurlResult *out);
ALPHAX_CURL_EXPORT int32_t ax_curl_upload(const char *url, const char *path, AxCurlResult *out);
ALPHAX_CURL_EXPORT AxCurlClient *ax_curl_client_create(void);
ALPHAX_CURL_EXPORT void ax_curl_client_free(AxCurlClient *client);
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
    void *user_data);
ALPHAX_CURL_EXPORT int32_t ax_curl_request_cancel(AxCurlStreamHandle *handle);
ALPHAX_CURL_EXPORT void ax_curl_request_free(AxCurlStreamHandle *handle);
ALPHAX_CURL_EXPORT void ax_curl_free_buffer(const uint8_t *buffer);
ALPHAX_CURL_EXPORT const char *ax_curl_last_error(void);
ALPHAX_CURL_EXPORT const char *ax_curl_version(void);

#endif

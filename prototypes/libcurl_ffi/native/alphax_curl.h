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

ALPHAX_CURL_EXPORT int32_t ax_curl_get(const char *url, AxCurlResult *out);
ALPHAX_CURL_EXPORT int32_t ax_curl_download(const char *url, const char *path, AxCurlResult *out);
ALPHAX_CURL_EXPORT int32_t ax_curl_upload(const char *url, const char *path, AxCurlResult *out);
ALPHAX_CURL_EXPORT const char *ax_curl_last_error(void);
ALPHAX_CURL_EXPORT const char *ax_curl_version(void);

#endif

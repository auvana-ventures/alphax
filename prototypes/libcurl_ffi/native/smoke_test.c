#include "alphax_curl.h"

#include <stdio.h>
#include <string.h>

int main(void) {
  const char *version = ax_curl_version();
  if (version == NULL || strlen(version) == 0) {
    fprintf(stderr, "libcurl version was empty\n");
    return 1;
  }

  AxCurlResult result;
  const int code = ax_curl_get("://invalid-url", &result);
  if (code == 0 || result.curl_code == 0) {
    fprintf(stderr, "invalid URL unexpectedly succeeded\n");
    return 1;
  }
  printf("libcurl smoke test passed: %s\n", version);
  return 0;
}

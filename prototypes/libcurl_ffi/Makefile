CC ?= cc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -fPIC -fvisibility=hidden
CURL_CFLAGS := $(shell curl-config --cflags)
CURL_LIBS := $(shell curl-config --libs)
UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Darwin)
  SHARED_LIBRARY := libalphax_curl.dylib
  SHARED_FLAGS := -dynamiclib
  RPATH_FLAGS := -Wl,-rpath,@loader_path
else
  SHARED_LIBRARY := libalphax_curl.so
  SHARED_FLAGS := -shared
  RPATH_FLAGS := -Wl,-rpath,'$$ORIGIN'
endif

.PHONY: all test clean

all: $(SHARED_LIBRARY)

$(SHARED_LIBRARY): native/alphax_curl.c native/alphax_curl.h
	$(CC) $(CFLAGS) $(CURL_CFLAGS) $(SHARED_FLAGS) -o $@ native/alphax_curl.c $(CURL_LIBS)

test: $(SHARED_LIBRARY)
	$(CC) $(CFLAGS) $(CURL_CFLAGS) -o smoke_test native/smoke_test.c -L. -lalphax_curl $(CURL_LIBS) $(RPATH_FLAGS)
	./smoke_test

clean:
	rm -f $(SHARED_LIBRARY) smoke_test

# File transfer example

File transfer is demonstrated in [`../basic`](../basic/README.md) using the
transport-neutral `AlphaXClient.download()` and `AlphaXClient.upload()` APIs.
The selected adapter may use a Dart stream or a native file-backed task; the
application does not choose a different API. Native file paths are described as
minimal-copy/direct-file paths, never as zero-copy.

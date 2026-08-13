# Linux final Phase 0 decision environment

This image is a benchmark toolchain, not an AlphaX runtime. It combines the
Dart SDK, Debian Rust toolchain, libcurl development files, `tc`/`netem`, and
the process-level measurement tools needed by the final Phase 0 experiment.

The experiment runs two endpoint containers on a private Docker bridge:

```text
Linux Dart/native client -- shaped eth0 -- Docker bridge -- shaped eth0 -- TLS server
```

The same profile is applied to both endpoint interfaces. The script's 15/50/150
ms one-way delays therefore approximate 30/100/300 ms RTT before bridge and
processing overhead. The Linux container architecture and Docker host are
recorded with the raw result metadata. Performance conclusions are not
generalized to mobile hardware or shared CI runners.

Build the image with:

```text
docker build -t alphax-phase0-final-client:round5 benchmarks/linux-final
```

The orchestration entry point is
`benchmarks/scripts/run-linux-final-decision.sh`. It applies and resets qdiscs
in a cleanup trap and requires no host network changes.

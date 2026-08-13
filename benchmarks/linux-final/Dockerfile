FROM rust:1.86-slim-bookworm AS rust_toolchain

FROM dart:stable

ENV DEBIAN_FRONTEND=noninteractive
COPY --from=rust_toolchain /usr/local/cargo /usr/local/cargo
COPY --from=rust_toolchain /usr/local/rustup /usr/local/rustup
ENV PATH="/usr/lib/dart/bin:/usr/local/cargo/bin:${PATH}"
ENV CARGO_HOME=/usr/local/cargo
ENV RUSTUP_HOME=/usr/local/rustup

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
      bash \
      build-essential \
      ca-certificates \
      curl \
      git \
      iproute2 \
      jq \
      libcurl4-openssl-dev \
      make \
      openssl \
      pkg-config \
      procps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
ENTRYPOINT []

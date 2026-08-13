FROM python:3.12-slim

RUN apt-get update \
    && apt-get install --yes --no-install-recommends iproute2 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/alphax-http2-requirements.txt
RUN python -m pip install --no-cache-dir --disable-pip-version-check \
    -r /tmp/alphax-http2-requirements.txt

WORKDIR /app
EXPOSE 8443

ENTRYPOINT ["hypercorn"]

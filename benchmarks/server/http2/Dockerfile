FROM python:3.12-slim

COPY requirements.txt /tmp/alphax-http2-requirements.txt
RUN python -m pip install --no-cache-dir --disable-pip-version-check \
    -r /tmp/alphax-http2-requirements.txt

WORKDIR /app
EXPOSE 8443

ENTRYPOINT ["hypercorn"]

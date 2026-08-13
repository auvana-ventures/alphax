"""Deterministic HTTP/2 benchmark server for the AlphaX Phase 0 harness.

This is an ASGI application intended to run behind Hypercorn in the checked-in
benchmark Docker image. It deliberately mirrors the Dart benchmark server's
endpoint contract and does not implement production AlphaX behavior.
"""

from __future__ import annotations

import asyncio
import json
import time
from collections import defaultdict
from typing import Any
from urllib.parse import parse_qs


FNV_OFFSET = 0xCBF29CE484222325
FNV_PRIME = 0x100000001B3
FNV_MASK = 0xFFFFFFFFFFFFFFFF


class ConnectionTracker:
    def __init__(self) -> None:
        self._ids: dict[str, int] = {}
        self._request_counts: defaultdict[str, int] = defaultdict(int)
        self._requests_observed = 0

    def observe(self, scope: dict[str, Any]) -> tuple[int, int, int, int]:
        client = scope.get("client") or ("unknown", id(scope))
        key = f"{client[0]}:{client[1]}"
        connection_id = self._ids.setdefault(key, len(self._ids) + 1)
        self._request_counts[key] += 1
        self._requests_observed += 1
        return (
            connection_id,
            self._request_counts[key],
            len(self._ids),
            self._requests_observed,
        )

    def snapshot(self) -> dict[str, Any]:
        return {
            "requests_observed": self._requests_observed,
            "connections_established": len(self._ids),
            "requests_per_connection": {
                str(self._ids[key]): count
                for key, count in self._request_counts.items()
            },
            "connection_close_events": "unavailable:asgi-server-api",
            "connection_observation": "remote-address-and-port",
        }


tracker = ConnectionTracker()


def deterministic_bytes(length: int, offset: int) -> bytes:
    return bytes((index + offset) % 251 for index in range(length))


def fnv1a64_update(value: int, body: bytes) -> int:
    for byte in body:
        value = ((value ^ byte) * FNV_PRIME) & FNV_MASK
    return value


def parse_nonnegative(value: str, name: str) -> int:
    result = int(value)
    if result < 0:
        raise ValueError(f"Invalid {name}: {value}")
    return result


def query_parameters(scope: dict[str, Any]) -> dict[str, list[str]]:
    return parse_qs(scope.get("query_string", b"").decode("ascii"))


def first_query(query: dict[str, list[str]], key: str) -> str | None:
    values = query.get(key)
    return values[0] if values else None


async def receive_body(receive: Any) -> bytes:
    chunks: list[bytes] = []
    while True:
        event = await receive()
        if event["type"] != "http.request":
            continue
        chunks.append(event.get("body", b""))
        if not event.get("more_body", False):
            return b"".join(chunks)


async def receive_upload(receive: Any) -> tuple[int, int]:
    byte_count = 0
    digest = FNV_OFFSET
    while True:
        event = await receive()
        if event["type"] != "http.request":
            continue
        body = event.get("body", b"")
        byte_count += len(body)
        digest = fnv1a64_update(digest, body)
        if not event.get("more_body", False):
            return byte_count, digest


async def send_body(
    send: Any,
    status: int,
    headers: list[tuple[bytes, bytes]],
    body: bytes,
) -> None:
    if not any(name == b"content-type" for name, _ in headers):
        headers = headers + [(b"content-type", b"text/plain; charset=utf-8")]
    await send({"type": "http.response.start", "status": status, "headers": headers})
    await send({"type": "http.response.body", "body": body, "more_body": False})


def common_headers(
    scope: dict[str, Any],
    connection: tuple[int, int, int, int],
) -> list[tuple[bytes, bytes]]:
    connection_id, request_count, established, observed = connection
    protocol = str(scope.get("http_version", "unknown")).encode("ascii")
    return [
        (b"x-alphax-server-connection-id", str(connection_id).encode("ascii")),
        (b"x-alphax-server-connection-request-count", str(request_count).encode("ascii")),
        (b"x-alphax-server-connections-established", str(established).encode("ascii")),
        (b"x-alphax-server-requests-observed", str(observed).encode("ascii")),
        (b"x-alphax-server-connection-close-events", b"unavailable:asgi-server-api"),
        (b"x-alphax-server-protocol", protocol),
    ]


async def app(scope: dict[str, Any], receive: Any, send: Any) -> None:
    if scope["type"] != "http":
        return

    connection = tracker.observe(scope)
    headers = common_headers(scope, connection)
    path = scope.get("path", "/")
    segments = [segment for segment in path.split("/") if segment]
    method = scope.get("method", "GET")
    query = query_parameters(scope)

    try:
        if not segments:
            await send_body(send, 200, headers, b"AlphaX benchmark server")
            return

        route = segments[0]
        if route == "health":
            body = json.dumps({"status": "ok"}, separators=(",", ":")).encode()
            await send_body(send, 200, headers + [(b"content-length", str(len(body)).encode()), (b"content-type", b"application/json")], body)
            return
        if route == "bytes":
            size = parse_nonnegative(segments[1], "size")
            response_headers = headers + [(b"content-type", b"application/octet-stream"), (b"content-length", str(size).encode())]
            await send({"type": "http.response.start", "status": 200, "headers": response_headers})
            offset = 0
            while offset < size:
                chunk = deterministic_bytes(min(64 * 1024, size - offset), offset)
                offset += len(chunk)
                await send({"type": "http.response.body", "body": chunk, "more_body": offset < size})
            if size == 0:
                await send({"type": "http.response.body", "body": b"", "more_body": False})
            return
        if route == "json":
            size = parse_nonnegative(segments[1], "size")
            body = json.dumps({"payload": "a" * max(0, size - 16)}, separators=(",", ":")).encode()
            await send_body(send, 200, headers + [(b"content-length", str(len(body)).encode()), (b"content-type", b"application/json")], body)
            return
        if route == "stream":
            chunks = parse_nonnegative(segments[1], "chunks")
            chunk_size = parse_nonnegative(segments[2], "chunkSize")
            delay_ms = parse_nonnegative(first_query(query, "delay_ms") or "0", "delay_ms")
            await send({"type": "http.response.start", "status": 200, "headers": headers + [(b"content-type", b"application/octet-stream")]})
            for index in range(chunks):
                await send({"type": "http.response.body", "body": deterministic_bytes(chunk_size, index), "more_body": index + 1 < chunks})
                if delay_ms:
                    await asyncio.sleep(delay_ms / 1000)
            if chunks == 0:
                await send({"type": "http.response.body", "body": b"", "more_body": False})
            return
        if route == "echo":
            body = await receive_body(receive)
            await send_body(send, 200, headers + [(b"content-type", b"application/octet-stream"), (b"content-length", str(len(body)).encode())], body)
            return
        if route == "upload":
            byte_count, digest = await receive_upload(receive)
            started = time.perf_counter_ns()
            elapsed_us = (time.perf_counter_ns() - started) // 1000
            actual_hash = f"{digest:016x}"
            expected = first_query(query, "expected")
            expected_hash = first_query(query, "expected_hash")
            valid = (expected is None or int(expected) == byte_count) and (expected_hash is None or expected_hash == actual_hash)
            response_headers = headers + [
                (b"x-alphax-server-body-read-us", str(elapsed_us).encode()),
                (b"x-alphax-upload-hash-algorithm", b"fnv1a64"),
                (b"x-alphax-upload-fnv1a64", actual_hash.encode()),
                (b"x-alphax-uploaded-bytes", str(byte_count).encode()),
                (b"content-type", b"application/json"),
            ]
            response = {"bytes": byte_count, "expected": int(expected) if expected else byte_count, "hash": actual_hash, "expected_hash": expected_hash or actual_hash, "ok": valid}
            encoded = json.dumps(response, separators=(",", ":")).encode()
            await send_body(send, 200 if valid else 400, response_headers + [(b"content-length", str(len(encoded)).encode())], encoded)
            return
        if route == "connections":
            body = json.dumps(tracker.snapshot(), separators=(",", ":")).encode()
            await send_body(send, 200, headers + [(b"content-type", b"application/json"), (b"content-length", str(len(body)).encode())], body)
            return
        if route == "delay":
            await asyncio.sleep(parse_nonnegative(segments[1], "milliseconds") / 1000)
            await send_body(send, 200, headers, b"delayed")
            return
        if route == "status":
            status = parse_nonnegative(segments[1], "status")
            await send_body(send, status, headers, f"status {status}".encode())
            return
        if route == "headers":
            response_headers = headers + [(b"x-alphax-server", b"benchmark"), (b"x-alphax-request-method", method.encode())]
            trace = dict(scope.get("headers", [])).get(b"x-trace")
            if trace is not None:
                response_headers.append((b"x-alphax-echo-trace", trace))
            await send_body(send, 200, response_headers, b"headers")
            return
        if route == "redirect":
            count = parse_nonnegative(segments[1], "count")
            if count == 0:
                await send_body(send, 200, headers, b"redirect complete")
            else:
                await send_body(send, 302, headers + [(b"location", f"/redirect/{count - 1}".encode())], b"")
            return

        await send_body(send, 404, headers, b"not found")
    except (asyncio.CancelledError, ConnectionError):
        return
    except (IndexError, TypeError, ValueError) as error:
        await send_body(send, 400, headers, str(error).encode())

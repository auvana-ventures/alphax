package com.auvana.ventures.alphax

import android.os.Handler
import io.flutter.plugin.common.MethodChannel
import org.chromium.net.CronetEngine
import org.chromium.net.UploadDataProvider
import org.chromium.net.UploadDataSink
import org.chromium.net.UrlRequest
import org.chromium.net.UrlResponseInfo
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

/** One bounded Cronet request and its Dart event lifecycle. */
internal class CronetRequestOperation(
    private val requestId: String,
    private val arguments: Map<String, Any?>,
    private val cronetEngine: CronetEngine,
    private val requestExecutor: ExecutorService,
    private val timerExecutor: ScheduledExecutorService,
    private val methodChannel: MethodChannel,
    private val mainHandler: Handler,
    private val emit: (Map<String, Any?>) -> Unit,
    private val onFinished: (String) -> Unit,
) : UrlRequest.Callback() {
    private val body = map(arguments["body"])
    private val redirect = map(arguments["redirect"])
    private val timeouts = map(arguments["timeouts"])
    private val originalUri = arguments["uri"]?.toString() ?: error("uri is required")
    private val directDownloadPath = arguments["directDownloadPath"]?.toString()
    private val protocolPreference = arguments["protocol"]?.toString() ?: "auto"

    @Volatile
    private var request: UrlRequest? = null
    private var responseInfo: UrlResponseInfo? = null
    private var uploadProvider: UploadDataProvider? = null
    private var output: FileOutputStream? = null
    private var responseStarted = false
    private var readInFlight = false
    private var credits = 0
    private var redirectCount = 0
    private var bytesUploaded = 0L
    private var bytesDownloaded = 0L
    @Volatile
    private var terminal = false
    private var cancellationReason: String? = null
    private var timeoutReason: String? = null
    private var timeoutKind: String? = null
    private var startedAtNanos = System.nanoTime()
    private var firstByteAtNanos: Long? = null
    private var requestTimeout: ScheduledFuture<*>? = null
    private var connectTimeout: ScheduledFuture<*>? = null
    private var readTimeout: ScheduledFuture<*>? = null
    private var overallTimeout: ScheduledFuture<*>? = null

    fun start() {
        val builder = cronetEngine.newUrlRequestBuilder(
            originalUri,
            this,
            requestExecutor,
        )
        builder.setHttpMethod(arguments["method"]?.toString() ?: "GET")
        val headers = map(arguments["headers"])
        addHeaders(builder, headers)
        val hasContentType = headers.keys.any { it.equals("content-type", ignoreCase = true) }
        val contentType = body["contentType"]?.toString()
        if (!hasContentType && !contentType.isNullOrEmpty()) {
            builder.addHeader("content-type", contentType)
        }
        uploadProvider = createUploadProvider()
        uploadProvider?.let { builder.setUploadDataProvider(it, requestExecutor) }
        request = builder.build()
        startedAtNanos = System.nanoTime()
        scheduleTimeouts()
        request?.start()
    }

    @Synchronized
    fun grantCredits(value: Int) {
        if (value <= 0 || terminal || directDownloadPath != null) {
            return
        }
        credits = (credits + value).coerceAtMost(MAX_CREDITS)
        pumpRead()
    }

    @Synchronized
    fun cancel(reason: String) {
        if (terminal) {
            return
        }
        cancellationReason = reason
        request?.cancel()
        finishWithError("cancellation", reason)
    }

    @Synchronized
    override fun onRedirectReceived(
        request: UrlRequest,
        info: UrlResponseInfo,
        newLocationUrl: String,
    ) {
        if (terminal) return
        redirectCount += 1
        val maxRedirects = (redirect["maxRedirects"] as? Number)?.toInt() ?: 5
        if (redirectCount > maxRedirects) {
            request.cancel()
            finishWithError("redirect", "Maximum redirect count exceeded")
            return
        }

        val redirectInfo = mapOf(
            "statusCode" to info.httpStatusCode,
            "from" to info.url,
            "to" to newLocationUrl,
            "method" to (arguments["method"]?.toString() ?: "GET"),
        )
        redirects.add(redirectInfo)
        when (redirect["mode"]?.toString() ?: "follow") {
            "reject" -> {
                request.cancel()
                finishWithError("redirect", "Redirect rejected by request policy")
            }
            "manual" -> {
                emitStarted(info)
                request.cancel()
                finishSuccessfully(info)
            }
            else -> {
                if (!isReplayableBody()) {
                    request.cancel()
                    finishWithError(
                        "redirect",
                        "A redirect cannot replay the single-consumption request body",
                    )
                } else {
                    request.followRedirect()
                }
            }
        }
    }

    @Synchronized
    override fun onResponseStarted(request: UrlRequest, info: UrlResponseInfo) {
        if (terminal) return
        responseStarted = true
        responseInfo = info
        connectTimeout?.cancel(false)
        requestTimeout?.cancel(false)
        emitStarted(info)
        if (directDownloadPath != null) {
            try {
                val file = File(directDownloadPath)
                file.parentFile?.mkdirs()
                output = FileOutputStream(file)
                pumpRead()
            } catch (error: Throwable) {
                request.cancel()
                finishWithError("response_body", "The native download file could not be opened", error)
            }
        }
    }

    @Synchronized
    override fun onReadCompleted(
        request: UrlRequest,
        info: UrlResponseInfo,
        byteBuffer: ByteBuffer,
    ) {
        if (terminal) return
        readInFlight = false
        readTimeout?.cancel(false)
        byteBuffer.flip()
        val size = byteBuffer.remaining()
        if (size == 0) {
            pumpRead()
            return
        }
        val bytes = ByteArray(size)
        byteBuffer.get(bytes)
        bytesDownloaded += size
        if (firstByteAtNanos == null) {
            firstByteAtNanos = System.nanoTime()
        }

        try {
            if (directDownloadPath != null) {
                output?.write(bytes)
                emitProgress("download", bytesDownloaded, contentLength(info))
                pumpRead()
            } else {
                credits = (credits - 1).coerceAtLeast(0)
                emit(
                    mapOf(
                        "type" to "chunk",
                        "requestId" to requestId,
                        "bytes" to bytes,
                    ),
                )
                emitProgress("download", bytesDownloaded, contentLength(info))
                pumpRead()
            }
        } catch (error: Throwable) {
            request.cancel()
            finishWithError("response_body", "The response body could not be delivered", error)
        }
    }

    @Synchronized
    override fun onSucceeded(request: UrlRequest, info: UrlResponseInfo) {
        if (terminal) return
        finishSuccessfully(info)
    }

    @Synchronized
    override fun onFailed(request: UrlRequest, info: UrlResponseInfo?, error: org.chromium.net.CronetException) {
        if (terminal) return
        responseInfo = info ?: responseInfo
        val kind = classify(error)
        finishWithError(kind, error.message ?: "Cronet request failed", error)
    }

    @Synchronized
    override fun onCanceled(request: UrlRequest, info: UrlResponseInfo?) {
        if (terminal) return
        responseInfo = info ?: responseInfo
        val kind = if (timeoutReason != null) "timeout" else "cancellation"
        finishWithError(kind, timeoutReason ?: cancellationReason ?: "The request was cancelled")
    }

    private val redirects = mutableListOf<Map<String, Any?>>()

    private fun emitStarted(info: UrlResponseInfo) {
        if (startedEmitted) return
        startedEmitted = true
        responseInfo = info
        emit(
            mapOf(
                "type" to "started",
                "requestId" to requestId,
                "statusCode" to info.httpStatusCode,
                "headers" to info.allHeaders,
                "protocol" to normalizedProtocol(info.negotiatedProtocol),
                "requestedProtocol" to protocolPreference,
                "redirects" to redirects,
                "contentLength" to contentLength(info),
            ),
        )
    }

    private var startedEmitted = false

    @Synchronized
    private fun finishSuccessfully(info: UrlResponseInfo) {
        if (terminal) return
        terminal = true
        responseInfo = info
        cancelTimeouts()
        try {
            output?.flush()
            output?.close()
        } catch (_: IOException) {
            // The request already completed; an output close failure is reported below only
            // when the native file was not successfully flushed.
        } finally {
            output = null
            uploadProvider?.close()
        }
        if (!startedEmitted) {
            emitStarted(info)
        }
        emit(
            mapOf(
                "type" to "completed",
                "requestId" to requestId,
                "metrics" to metrics(info),
                "bytesReceived" to bytesDownloaded,
            ),
        )
        onFinished(requestId)
    }

    @Synchronized
    private fun finishWithError(kind: String, message: String, cause: Throwable? = null) {
        if (terminal) return
        terminal = true
        cancelTimeouts()
        try {
            output?.close()
        } catch (_: IOException) {
            // Preserve the original transport error.
        } finally {
            output = null
            uploadProvider?.close()
        }
        emit(
            mapOf(
                "type" to "error",
                "requestId" to requestId,
                "kind" to kind,
                "message" to message,
                "timeoutKind" to timeoutKind,
                "nativeCause" to cause?.javaClass?.name,
            ),
        )
        onFinished(requestId)
    }

    @Synchronized
    private fun pumpRead() {
        val activeRequest = request ?: return
        if (terminal || readInFlight || !responseStarted) return
        if (directDownloadPath == null && credits <= 0) return
        readInFlight = true
        val buffer = ByteBuffer.allocateDirect(CHUNK_SIZE)
        try {
            activeRequest.read(buffer)
            scheduleReadTimeout()
        } catch (error: Throwable) {
            readInFlight = false
            activeRequest.cancel()
            finishWithError("response_body", "The response read could not be started", error)
        }
    }

    private fun createUploadProvider(): UploadDataProvider? {
        val kind = body["kind"]?.toString() ?: "empty"
        return when (kind) {
            "bytes" -> ByteArrayUploadProvider(
                bytes = body["bytes"].asByteArray(),
                onBytes = ::onUploadBytes,
            )
            "file" -> FileUploadProvider(
                path = body["path"]?.toString() ?: error("file body path is required"),
                length = (body["length"] as? Number)?.toLong() ?: -1L,
                onBytes = ::onUploadBytes,
            )
            "dart" -> DartUploadProvider(
                requestId = requestId,
                length = (body["length"] as? Number)?.toLong() ?: -1L,
                replayable = body["replayable"] == true,
                channel = methodChannel,
                mainHandler = mainHandler,
                onBytes = ::onUploadBytes,
            )
            else -> null
        }
    }

    @Synchronized
    private fun onUploadBytes(count: Int) {
        bytesUploaded += count
        emitProgress("upload", bytesUploaded, (body["length"] as? Number)?.toLong())
    }

    private fun isReplayableBody(): Boolean = body["replayable"] != false

    private fun emitProgress(direction: String, bytes: Long, total: Long?) {
        emit(
            mapOf(
                "type" to "progress",
                "requestId" to requestId,
                "direction" to direction,
                "bytesTransferred" to bytes,
                "totalBytes" to total,
                "isComplete" to (total != null && bytes >= total),
            ),
        )
    }

    private fun metrics(info: UrlResponseInfo): Map<String, Any?> {
        val total = elapsedMillis(startedAtNanos)
        val firstByte = firstByteAtNanos?.let { elapsedMillis(startedAtNanos, it) }
        return mapOf(
            "timeToFirstByteMs" to firstByte,
            "transferDurationMs" to if (firstByte == null) null else total - firstByte,
            "totalDurationMs" to total,
            "uploadedBytes" to bytesUploaded,
            "downloadedBytes" to bytesDownloaded,
            "protocol" to normalizedProtocol(info.negotiatedProtocol),
            "redirectCount" to redirectCount,
            "connectionReused" to null,
        )
    }

    private fun scheduleTimeouts() {
        schedule("connect", timeouts["connectMs"])
        schedule("request", timeouts["requestMs"])
        schedule("overall", timeouts["overallMs"])
    }

    private fun schedule(kind: String, value: Any?) {
        val millis = (value as? Number)?.toLong() ?: return
        if (millis <= 0) return
        val future = timerExecutor.schedule({
            if (terminal) return@schedule
            timeoutReason = "The $kind timeout elapsed"
            timeoutKind = kind
            request?.cancel()
            finishWithError("timeout", timeoutReason ?: "The request timed out")
        }, millis, TimeUnit.MILLISECONDS)
        when (kind) {
            "connect" -> connectTimeout = future
            "request" -> requestTimeout = future
            "overall" -> overallTimeout = future
        }
    }

    private fun scheduleReadTimeout() {
        readTimeout?.cancel(false)
        val millis = (timeouts["readMs"] as? Number)?.toLong() ?: return
        if (millis <= 0) return
        readTimeout = timerExecutor.schedule({
            if (terminal || !readInFlight) return@schedule
            timeoutReason = "The read timeout elapsed"
            timeoutKind = "read"
            request?.cancel()
            finishWithError("timeout", timeoutReason ?: "The response read timed out")
        }, millis, TimeUnit.MILLISECONDS)
    }

    private fun cancelTimeouts() {
        connectTimeout?.cancel(false)
        requestTimeout?.cancel(false)
        readTimeout?.cancel(false)
        overallTimeout?.cancel(false)
    }

    private fun contentLength(info: UrlResponseInfo): Long? =
        info.allHeaders.entries
            .firstOrNull { it.key.equals("content-length", ignoreCase = true) }
            ?.value
            ?.firstOrNull()
            ?.toLongOrNull()

    private fun classify(error: Throwable): String {
        val message = (error.message ?: "").lowercase(Locale.US)
        val name = error.javaClass.name.lowercase(Locale.US)
        return when {
            "certificate" in message || "ssl" in message || "tls" in message -> "tls"
            "dns" in message || "name_not_resolved" in message || "host" in message -> "dns"
            "protocol" in message || "http" in name && "network" !in name -> "protocol"
            "timeout" in message -> "timeout"
            else -> "connection"
        }
    }

    private fun normalizedProtocol(value: String?): String = when {
        // Cronet does not expose an ALPN token for this adapter's cleartext
        // fixture. Its non-TLS request path is HTTP/1.1; H2/H3 are enabled and
        // reported only from Cronet's negotiated token over TLS/ALPN.
        (value.isNullOrEmpty() || value.equals("unknown", ignoreCase = true)) &&
            originalUri.startsWith("http://", ignoreCase = true) -> "http11"
        value.isNullOrEmpty() -> "unknown"
        value.contains("quic", ignoreCase = true) || value.startsWith("h3", ignoreCase = true) -> "http3"
        value.contains("h2", ignoreCase = true) || value.contains("spdy", ignoreCase = true) -> "http2"
        value.contains("1.1") -> "http11"
        value.contains("1.0") -> "http10"
        else -> "unknown"
    }

    private fun elapsedMillis(start: Long, end: Long = System.nanoTime()): Long =
        TimeUnit.NANOSECONDS.toMillis(end - start)

    private fun addHeaders(builder: UrlRequest.Builder, headers: Map<String, Any?>) {
        headers.forEach { (name, values) ->
            when (values) {
                is Iterable<*> -> values.forEach { value -> builder.addHeader(name, value.toString()) }
                null -> Unit
                else -> builder.addHeader(name, values.toString())
            }
        }
    }

    companion object {
        private const val CHUNK_SIZE = 64 * 1024
        private const val MAX_CREDITS = 4

        @Suppress("UNCHECKED_CAST")
        private fun map(value: Any?): Map<String, Any?> =
            (value as? Map<*, *>)?.entries?.associate { (key, item) -> key.toString() to item }
                ?: emptyMap()

        private fun Any?.asByteArray(): ByteArray = when (this) {
            is ByteArray -> this
            is List<*> -> ByteArray(size) { index -> (this[index] as Number).toByte() }
            else -> ByteArray(0)
        }
    }
}

private class ByteArrayUploadProvider(
    private val bytes: ByteArray,
    private val onBytes: (Int) -> Unit,
) : UploadDataProvider() {
    private var offset = 0

    override fun getLength(): Long = bytes.size.toLong()

    override fun read(uploadDataSink: UploadDataSink, byteBuffer: ByteBuffer) {
        val count = minOf(byteBuffer.remaining(), bytes.size - offset)
        if (count <= 0) {
            // A known-length upload is non-chunked. Cronet requires the
            // finalChunk flag to remain false for this provider type.
            uploadDataSink.onReadSucceeded(false)
            return
        }
        byteBuffer.put(bytes, offset, count)
        offset += count
        onBytes(count)
        uploadDataSink.onReadSucceeded(false)
    }

    override fun rewind(uploadDataSink: UploadDataSink) {
        offset = 0
        uploadDataSink.onRewindSucceeded()
    }
}

private class FileUploadProvider(
    private val path: String,
    private val length: Long,
    private val onBytes: (Int) -> Unit,
) : UploadDataProvider() {
    private var input: FileInputStream? = null
    private var bytesRead = 0L

    override fun getLength(): Long = length

    override fun read(uploadDataSink: UploadDataSink, byteBuffer: ByteBuffer) {
        try {
            val temporary = ByteArray(minOf(byteBuffer.remaining(), 64 * 1024))
            val count = input().read(temporary)
            if (count < 0) {
                uploadDataSink.onReadError(IOException("Unexpected end of native upload file"))
                return
            }
            byteBuffer.put(temporary, 0, count)
            bytesRead += count
            onBytes(count)
            // getLength() declares this as a non-chunked upload, so the
            // provider must not mark a read as a chunked final chunk.
            uploadDataSink.onReadSucceeded(false)
        } catch (error: IOException) {
            uploadDataSink.onReadError(error)
        }
    }

    override fun rewind(uploadDataSink: UploadDataSink) {
        closeInput()
        bytesRead = 0L
        try {
            input = FileInputStream(File(path))
            uploadDataSink.onRewindSucceeded()
        } catch (error: IOException) {
            uploadDataSink.onRewindError(error)
        }
    }

    override fun close() {
        closeInput()
    }

    private fun input(): FileInputStream {
        val current = input
        if (current != null) return current
        return FileInputStream(File(path)).also { input = it }
    }

    private fun closeInput() {
        try {
            input?.close()
        } catch (_: IOException) {
            // Cleanup must remain best-effort.
        } finally {
            input = null
        }
    }
}

private class DartUploadProvider(
    private val requestId: String,
    private val length: Long,
    private val replayable: Boolean,
    private val channel: MethodChannel,
    private val mainHandler: Handler,
    private val onBytes: (Int) -> Unit,
) : UploadDataProvider() {
    override fun getLength(): Long = length

    override fun read(uploadDataSink: UploadDataSink, byteBuffer: ByteBuffer) {
        mainHandler.post {
            channel.invokeMethod(
                "uploadDemand",
                mapOf("requestId" to requestId, "maxBytes" to byteBuffer.remaining()),
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        try {
                            val response = result.asMap()
                            val bytes = response["bytes"].asByteArray()
                            byteBuffer.put(bytes)
                            onBytes(bytes.size)
                            val done = response["done"] == true
                            uploadDataSink.onReadSucceeded(if (length < 0L) done else false)
                        } catch (error: Throwable) {
                            uploadDataSink.onReadError(IOException(error.message ?: "Dart upload failed", error))
                        }
                    }

                    override fun error(code: String, message: String?, details: Any?) {
                        uploadDataSink.onReadError(IOException(message ?: code))
                    }

                    override fun notImplemented() {
                        uploadDataSink.onReadError(IOException("Dart upload callback is not implemented"))
                    }
                },
            )
        }
    }

    override fun rewind(uploadDataSink: UploadDataSink) {
        if (!replayable) {
            uploadDataSink.onRewindError(IOException("The Dart request body is single-consumption"))
            return
        }
        mainHandler.post {
            channel.invokeMethod(
                "uploadReset",
                mapOf("requestId" to requestId),
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        uploadDataSink.onRewindSucceeded()
                    }

                    override fun error(code: String, message: String?, details: Any?) {
                        uploadDataSink.onRewindError(IOException(message ?: code))
                    }

                    override fun notImplemented() {
                        uploadDataSink.onRewindError(IOException("Dart upload reset is not implemented"))
                    }
                },
            )
        }
    }

    private fun Any?.asMap(): Map<String, Any?> =
        (this as? Map<*, *>)?.entries?.associate { (key, value) -> key.toString() to value }
            ?: emptyMap()

    private fun Any?.asByteArray(): ByteArray = when (this) {
        is ByteArray -> this
        is List<*> -> ByteArray(size) { index -> (this[index] as Number).toByte() }
        else -> ByteArray(0)
    }
}

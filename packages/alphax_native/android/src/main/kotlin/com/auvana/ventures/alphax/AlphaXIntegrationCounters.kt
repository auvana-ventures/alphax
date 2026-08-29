package com.auvana.ventures.alphax

/**
 * Explicitly gated counters used by the post-1.0 integration-cost spike.
 *
 * This is intentionally not part of the Dart package API. The counters are
 * empty/disabled unless a benchmark process invokes the private debug method
 * on the transport channel, and they do not alter request scheduling.
 */
internal class AlphaXIntegrationCounters {
    private val lock = Any()
    private var enabled = false
    private var configuredChunkSize: Int? = null
    private var configuredMaxCredits: Int? = null
    private val requests = linkedMapOf<String, RequestCounters>()

    fun configure(value: Boolean, chunkSize: Int? = null, maxCredits: Int? = null) {
        synchronized(lock) {
            enabled = value
            configuredChunkSize = chunkSize?.takeIf { it > 0 }
            configuredMaxCredits = maxCredits?.takeIf { it > 0 }
            requests.clear()
        }
    }

    fun chunkSize(default: Int): Int = synchronized(lock) {
        configuredChunkSize ?: default
    }

    fun maxCredits(default: Int): Int = synchronized(lock) {
        configuredMaxCredits ?: default
    }

    fun register(requestId: String, nativeFileMode: String) {
        synchronized(lock) {
            if (!enabled) return
            requests[requestId] = RequestCounters(nativeFileMode = nativeFileMode)
        }
    }

    fun credit(requestId: String, amount: Int) = update(requestId) {
        it.creditMessageCount += 1
        it.creditUnits += amount.coerceAtLeast(0).toLong()
    }

    fun chunk(requestId: String, bytes: Int) = update(requestId) {
        it.responseChunkCount += 1
        it.responseBodyBytes += bytes.coerceAtLeast(0).toLong()
    }

    fun nativeRead(requestId: String, bytes: Int) = update(requestId) {
        it.nativeReadCount += 1
        it.nativeReadBytes += bytes.coerceAtLeast(0).toLong()
    }

    fun nativeFileWrite(requestId: String, bytes: Int) = update(requestId) {
        val count = bytes.coerceAtLeast(0).toLong()
        it.nativeFileWriteCount += 1
        it.nativeFileWriteBytes += count
        it.responseBodyBytes += count
    }

    fun progress(requestId: String) = update(requestId) {
        it.progressEventCount += 1
    }

    fun uploadDemand(requestId: String) = update(requestId) {
        it.uploadDemandCount += 1
    }

    fun observableBuffer(requestId: String, bytes: Int) = update(requestId) {
        it.peakObservableBufferBytes = maxOf(
            it.peakObservableBufferBytes,
            bytes.coerceAtLeast(0).toLong(),
        )
    }

    fun androidBufferCopy(requestId: String, bytes: Int) = update(requestId) {
        it.androidBufferCopyCount += 1
        it.androidBufferCopyBytes += bytes.coerceAtLeast(0).toLong()
    }

    fun snapshot(): Map<String, Any?> = synchronized(lock) {
        mapOf(
            "enabled" to enabled,
            "platform" to "android",
            "requests" to requests.map { (requestId, value) ->
                mapOf(
                    "requestId" to requestId,
                    "nativeFileMode" to value.nativeFileMode,
                    "responseChunkCount" to value.responseChunkCount,
                    "responseBodyBytes" to value.responseBodyBytes,
                    "nativeReadCount" to value.nativeReadCount,
                    "nativeReadBytes" to value.nativeReadBytes,
                    "nativeFileWriteCount" to value.nativeFileWriteCount,
                    "nativeFileWriteBytes" to value.nativeFileWriteBytes,
                    "progressEventCount" to value.progressEventCount,
                    "creditMessageCount" to value.creditMessageCount,
                    "creditUnits" to value.creditUnits,
                    "uploadDemandCount" to value.uploadDemandCount,
                    "peakObservableBufferBytes" to value.peakObservableBufferBytes,
                    "androidBufferCopyCount" to value.androidBufferCopyCount,
                    "androidBufferCopyBytes" to value.androidBufferCopyBytes,
                )
            },
        )
    }

    private fun update(requestId: String, action: (RequestCounters) -> Unit) {
        synchronized(lock) {
            if (!enabled) return
            requests[requestId]?.let(action)
        }
    }

    private data class RequestCounters(
        val nativeFileMode: String,
        var responseChunkCount: Long = 0,
        var responseBodyBytes: Long = 0,
        var nativeReadCount: Long = 0,
        var nativeReadBytes: Long = 0,
        var nativeFileWriteCount: Long = 0,
        var nativeFileWriteBytes: Long = 0,
        var progressEventCount: Long = 0,
        var creditMessageCount: Long = 0,
        var creditUnits: Long = 0,
        var uploadDemandCount: Long = 0,
        var peakObservableBufferBytes: Long = 0,
        var androidBufferCopyCount: Long = 0,
        var androidBufferCopyBytes: Long = 0,
    )
}

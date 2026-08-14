package com.auvana.ventures.alphax

import android.content.Context
import android.os.Handler
import com.google.android.gms.net.CronetProviderInstaller
import io.flutter.plugin.common.MethodChannel
import org.chromium.net.CronetEngine
import org.chromium.net.CronetProvider
import org.chromium.net.UrlRequest
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ThreadFactory
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/** Owns one Cronet engine and all request operations for a Flutter engine. */
internal class CronetTransportEngine(
    private val context: Context,
    private val methodChannel: MethodChannel,
    private val mainHandler: Handler,
) {
    @Volatile
    var eventSink: io.flutter.plugin.common.EventChannel.EventSink? = null

    private val controlExecutor = Executors.newSingleThreadExecutor(namedThreadFactory("alphax-cronet-control"))
    private val requestExecutor = Executors.newFixedThreadPool(4, namedThreadFactory("alphax-cronet-request"))
    private val timerExecutor: ScheduledExecutorService = Executors.newScheduledThreadPool(
        1,
        namedThreadFactory("alphax-cronet-timer"),
    )
    private val operations = mutableMapOf<String, CronetRequestOperation>()
    private val lock = Any()
    private var engine: CronetEngine? = null
    private var providerName: String = "uninitialized"
    private var providerVersion: String = "unknown"
    private var nativeProvider = false
    private var initialized = false
    private var closed = false

    fun initialize(result: MethodChannel.Result) {
        synchronized(lock) {
            if (closed) {
                result.error("closed", "AlphaX Android transport is closed", null)
                return
            }
            if (initialized) {
                mainHandler.post { result.success(capabilities()) }
                return
            }
        }

        controlExecutor.execute {
            try {
                installGooglePlayProviderIfAvailable()
                val providers = CronetProvider.getAllProviders(context)
                    .filter { it.isEnabled }
                if (providers.isEmpty()) {
                    throw IllegalStateException("No enabled Cronet provider is available")
                }
                val selected = providers.firstOrNull { !isFallback(it) } ?: providers.first()
                val builder = selected.createBuilder()
                builder.enableHttp2(true)
                builder.enableQuic(true)
                engine = builder.build()
                providerName = selected.name
                providerVersion = selected.version
                nativeProvider = !isFallback(selected)
                initialized = true
                mainHandler.post { result.success(capabilities()) }
            } catch (error: Throwable) {
                mainHandler.post {
                    result.error(
                        "provider_unavailable",
                        error.message ?: "No usable Cronet provider is available",
                        error.javaClass.name,
                    )
                }
            }
        }
    }

    fun start(arguments: Map<String, Any?>, result: MethodChannel.Result) {
        val requestId = arguments["requestId"]?.toString()
        if (requestId.isNullOrEmpty()) {
            result.error("invalid_request", "requestId is required", null)
            return
        }
        val activeEngine = engine
        if (!initialized || activeEngine == null) {
            result.error("not_initialized", "Initialize the Android transport first", null)
            return
        }
        synchronized(lock) {
            if (closed) {
                result.error("closed", "AlphaX Android transport is closed", null)
                return
            }
            if (operations.containsKey(requestId)) {
                result.error("duplicate_request", "requestId is already active", null)
                return
            }
            val operation = CronetRequestOperation(
                requestId = requestId,
                arguments = arguments,
                cronetEngine = activeEngine,
                requestExecutor = requestExecutor,
                timerExecutor = timerExecutor,
                methodChannel = methodChannel,
                mainHandler = mainHandler,
                emit = ::emit,
                onFinished = ::removeOperation,
            )
            operations[requestId] = operation
            try {
                operation.start()
                result.success(null)
            } catch (error: Throwable) {
                operations.remove(requestId)
                result.error("start_failed", error.message, error.javaClass.name)
            }
        }
    }

    fun grantCredits(arguments: Map<String, Any?>, result: MethodChannel.Result) {
        val requestId = arguments["requestId"]?.toString()
        val credits = (arguments["credits"] as? Number)?.toInt() ?: 0
        val operation = requestId?.let { synchronized(lock) { operations[it] } }
        if (operation == null) {
            result.error("unknown_request", "No active request for the supplied requestId", null)
            return
        }
        operation.grantCredits(credits)
        result.success(null)
    }

    fun cancel(arguments: Map<String, Any?>, result: MethodChannel.Result) {
        val requestId = arguments["requestId"]?.toString()
        val reason = arguments["reason"]?.toString() ?: "The operation was cancelled"
        requestId?.let { synchronized(lock) { operations[it] } }?.cancel(reason)
        result.success(null)
    }

    fun close(result: MethodChannel.Result) {
        synchronized(lock) {
            if (closed) {
                mainHandler.post { result.success(null) }
                return
            }
            closed = true
            operations.values.toList().forEach { it.cancel("AlphaX Android transport is closed") }
            operations.clear()
        }
        controlExecutor.execute {
            try {
                engine?.shutdown()
            } finally {
                engine = null
                mainHandler.post { result.success(null) }
            }
        }
    }

    fun shutdown() {
        synchronized(lock) {
            if (!closed) {
                closed = true
                operations.values.toList().forEach { it.cancel("AlphaX Android transport is detached") }
                operations.clear()
            }
        }
        try {
            engine?.shutdown()
        } catch (_: Throwable) {
            // Detachment is best-effort; the owning Flutter engine is already going away.
        }
        engine = null
        controlExecutor.shutdownNow()
        requestExecutor.shutdownNow()
        timerExecutor.shutdownNow()
    }

    fun emit(event: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(event)
        }
    }

    private fun removeOperation(requestId: String) {
        synchronized(lock) {
            operations.remove(requestId)
        }
    }

    private fun capabilities(): Map<String, Any?> {
        val fullProtocol = if (nativeProvider) "supported" else "unsupported"
        return mapOf(
            "transportName" to "Android Cronet",
            "transportVersion" to providerVersion,
            "providerName" to providerName,
            "http10" to "unsupported",
            "http11" to "supported",
            "http2" to fullProtocol,
            "http3" to fullProtocol,
            "streamingUpload" to "supported",
            "streamingDownload" to "supported",
            "nativeFileUpload" to "supported",
            "nativeFileDownload" to "supported",
            "uploadProgress" to "supported",
            "downloadProgress" to "supported",
            "proxyConfiguration" to "unsupported",
            "certificatePinning" to "unsupported",
            "mutualTls" to "unsupported",
            // The provider exposes experimental migration controls, but this adapter does
            // not configure or guarantee them as a 1.0 behavior.
            "connectionMigration" to "unknown",
            "backgroundTransfer" to "unsupported",
            "negotiatedProtocolReporting" to "supported",
        )
    }

    private fun installGooglePlayProviderIfAvailable() {
        // The Play Services provider is preferred when its dependency is present. The
        // installer is synchronous only on this private control thread; no network work
        // occurs on the Flutter platform thread. If installation is unavailable, provider
        // discovery below still permits the Android HttpEngine provider on API 34+.
        try {
            val task = CronetProviderInstaller.installProvider(context)
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5)
            while (!task.isComplete && System.nanoTime() < deadline) {
                Thread.sleep(10)
            }
        } catch (_: Throwable) {
            // Provider discovery is authoritative. A device without Play Services can
            // still use the platform provider, while a Java fallback is reported honestly.
        }
    }

    private fun isFallback(provider: CronetProvider): Boolean =
        provider.name == CronetProvider.PROVIDER_NAME_FALLBACK ||
            provider.name.contains("fallback", ignoreCase = true)

    private fun namedThreadFactory(prefix: String): ThreadFactory {
        val counter = AtomicInteger()
        return ThreadFactory { runnable ->
            Thread(runnable, "$prefix-${counter.incrementAndGet()}").apply { isDaemon = true }
        }
    }
}

package com.auvana.ventures.alphax

import android.content.Context
import android.os.Handler
import android.util.Base64
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
import java.util.Date

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
    private val integrationCounters = AlphaXIntegrationCounters()
    private val lock = Any()
    private var engine: CronetEngine? = null
    private var providerName: String = "uninitialized"
    private var providerVersion: String = "unknown"
    private var nativeProvider = false
    private var initialized = false
    private var closed = false

    fun initialize(arguments: Map<String, Any?>, result: MethodChannel.Result) {
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
                configureTls(builder, map(arguments["tlsPolicy"]))
                configureProxy(builder, map(arguments["proxyPolicy"]))
                engine = builder.build()
                providerName = selected.name
                providerVersion = selected.version
                nativeProvider = !isFallback(selected)
                initialized = true
                mainHandler.post { result.success(capabilities()) }
            } catch (error: Throwable) {
                mainHandler.post {
                    result.error(
                        (error as? AlphaXPolicyException)?.code ?: "provider_unavailable",
                        error.message ?: "No usable Cronet provider is available",
                        (error as? AlphaXPolicyException)?.details ?: error.javaClass.name,
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
                integrationCounters = integrationCounters,
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
        requestId?.let { integrationCounters.credit(it, credits) }
        val operation = requestId?.let { synchronized(lock) { operations[it] } }
        if (operation == null) {
            result.error("unknown_request", "No active request for the supplied requestId", null)
            return
        }
        operation.grantCredits(credits)
        result.success(null)
    }

    fun debugEnableInstrumentation(arguments: Map<String, Any?>, result: MethodChannel.Result) {
        integrationCounters.configure(
            value = arguments["enabled"] as? Boolean ?: true,
            chunkSize = (arguments["chunkSize"] as? Number)?.toInt(),
            maxCredits = (arguments["maxCredits"] as? Number)?.toInt(),
        )
        result.success(null)
    }

    fun debugSnapshot(result: MethodChannel.Result) {
        result.success(integrationCounters.snapshot())
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
            "tlsDefaultTrust" to "supported",
            "customTrustAnchors" to "unsupported",
            "certificatePinning" to "supported",
            "mutualTls" to "unsupported",
            "systemProxy" to "supported",
            "directConnectionPolicy" to "unsupported",
            "explicitHttpProxy" to "unsupported",
            "explicitHttpsProxy" to "unsupported",
            "proxyAuthentication" to "unsupported",
            "protocolRequirement" to if (nativeProvider) "supported" else "unsupported",
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

    private fun configureTls(builder: CronetEngine.Builder, policy: Map<String, Any?>) {
        val includePlatformTrust = policy["includePlatformTrust"] as? Boolean ?: true
        val anchors = policy["trustAnchors"] as? List<*> ?: emptyList<Any?>()
        val clientIdentity = policy["clientIdentityReference"]?.toString()
        if (!includePlatformTrust || anchors.isNotEmpty()) {
            throw AlphaXPolicyException(
                code = "unsupported_tls_policy",
                message = "Cronet does not expose a safe custom trust-anchor mapping in this provider",
                details = mapOf("capability" to "customTrustAnchors"),
            )
        }
        if (!clientIdentity.isNullOrBlank()) {
            throw AlphaXPolicyException(
                code = "unsupported_tls_policy",
                message = "Cronet client-identity mapping is not implemented",
                details = mapOf("capability" to "mutualTls"),
            )
        }

        val pinEntries = policy["pins"] as? List<*> ?: emptyList<Any?>()
        if (pinEntries.isEmpty()) return
        val grouped = linkedMapOf<String, MutableList<Pair<Map<String, Any?>, ByteArray>>>()
        for (entry in pinEntries) {
            val pin = map(entry)
            val host = pin["host"]?.toString()?.trim().orEmpty()
            val digest = pin["sha256SpkiBase64"]?.toString().orEmpty()
            val expiresAtMs = (pin["expiresAtMs"] as? Number)?.toLong() ?: 0L
            if (host.isEmpty() || digest.isEmpty() || expiresAtMs <= System.currentTimeMillis()) {
                throw AlphaXPolicyException(
                    code = "unsupported_tls_policy",
                    message = "Cronet pin configuration is invalid or expired",
                    details = mapOf("capability" to "certificatePinning"),
                )
            }
            val bytes = try {
                Base64.decode(digest, Base64.DEFAULT)
            } catch (error: IllegalArgumentException) {
                throw AlphaXPolicyException(
                    code = "unsupported_tls_policy",
                    message = "Cronet pin configuration is not valid base64",
                    details = mapOf("capability" to "certificatePinning"),
                    underlyingCause = error,
                )
            }
            if (bytes.size != 32) {
                throw AlphaXPolicyException(
                    code = "unsupported_tls_policy",
                    message = "Cronet pins must be SHA-256 SPKI digests",
                    details = mapOf("capability" to "certificatePinning"),
                )
            }
            grouped.getOrPut(host.lowercase()) { mutableListOf() }.add(pin to bytes)
        }
        for ((host, values) in grouped) {
            val subdomainValues = values.map { it.first["includeSubdomains"] as? Boolean ?: false }.distinct()
            if (subdomainValues.size > 1) {
                throw AlphaXPolicyException(
                    code = "unsupported_tls_policy",
                    message = "Cronet requires one includeSubdomains value per pin host",
                    details = mapOf("capability" to "certificatePinning"),
                )
            }
            builder.addPublicKeyPins(
                host,
                values.map { it.second }.toSet(),
                subdomainValues.singleOrNull() ?: false,
                Date(values.minOf { (it.first["expiresAtMs"] as Number).toLong() }),
            )
        }
        // Do not let local trust anchors bypass an explicitly configured pin.
        builder.enablePublicKeyPinningBypassForLocalTrustAnchors(false)
    }

    private fun configureProxy(builder: CronetEngine.Builder, policy: Map<String, Any?>) {
        when (policy["mode"]?.toString() ?: "system") {
            "system" -> Unit
            "direct" -> throw AlphaXPolicyException(
                code = "unsupported_proxy_policy",
                message = "The selected Cronet API cannot enforce a direct-only policy",
                details = mapOf("capability" to "directConnectionPolicy"),
            )
            "explicit" -> throw AlphaXPolicyException(
                code = "unsupported_proxy_policy",
                message = "Explicit Cronet proxy configuration requires a newer provider API",
                details = mapOf(
                    "capability" to if (policy["scheme"]?.toString() == "https") {
                        "explicitHttpsProxy"
                    } else {
                        "explicitHttpProxy"
                    },
                ),
            )
            else -> throw AlphaXPolicyException(
                code = "unsupported_proxy_policy",
                message = "The Cronet proxy policy is invalid",
                details = mapOf("capability" to "proxyConfiguration"),
            )
        }
    }

    private data class AlphaXPolicyException(
        val code: String,
        override val message: String,
        val details: Any?,
        val underlyingCause: Throwable? = null,
    ) : IllegalArgumentException(message, underlyingCause)

    @Suppress("UNCHECKED_CAST")
    private fun map(value: Any?): Map<String, Any?> =
        (value as? Map<*, *>)?.entries?.associate { (key, item) -> key.toString() to item } ?: emptyMap()

    private fun namedThreadFactory(prefix: String): ThreadFactory {
        val counter = AtomicInteger()
        return ThreadFactory { runnable ->
            Thread(runnable, "$prefix-${counter.incrementAndGet()}").apply { isDaemon = true }
        }
    }
}

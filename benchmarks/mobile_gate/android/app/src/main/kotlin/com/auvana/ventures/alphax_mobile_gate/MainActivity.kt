package com.auvana.ventures.alphax_mobile_gate

import android.content.Context
import android.content.ContentValues
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    companion object {
        private const val NETWORK_CHANNEL = "alphax_mobile_gate/network"
    }

    private var connectivityManager: ConnectivityManager? = null
    private var cellularCallback: ConnectivityManager.NetworkCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NETWORK_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "bindCellular" -> bindCellular(result)
                "activeNetwork" -> result.success(activeNetworkSnapshot())
                "restoreDefault" -> restoreDefault(result)
                "exportReport" -> exportReport(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun exportReport(call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error(
                "downloads_export_unsupported",
                "The runner requires Android 10 or newer for scoped Downloads export",
                null,
            )
            return
        }
        val content = call.argument<String>("content")
        if (content == null) {
            result.error("invalid_report", "Report content is required", null)
            return
        }
        val requestedName = call.argument<String>("fileName") ?: "alphax-report.json"
        val safeName = requestedName
            .substringAfterLast('/')
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, safeName)
            put(MediaStore.Downloads.MIME_TYPE, "application/json")
            put(
                MediaStore.Downloads.RELATIVE_PATH,
                "${Environment.DIRECTORY_DOWNLOADS}/AlphaX",
            )
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val resolver = contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
        if (uri == null) {
            result.error("downloads_export_failed", "Android could not create the Downloads report", null)
            return
        }
        try {
            resolver.openOutputStream(uri)?.use { output ->
                output.write(content.toByteArray(Charsets.UTF_8))
                output.flush()
            } ?: error("Android could not open the Downloads report")
            resolver.update(
                uri,
                ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) },
                null,
                null,
            )
            result.success(
                mapOf(
                    "uri" to uri.toString(),
                    "displayName" to safeName,
                    "relativePath" to "${Environment.DIRECTORY_DOWNLOADS}/AlphaX",
                ),
            )
        } catch (error: Throwable) {
            resolver.delete(uri, null, null)
            result.error(
                "downloads_export_failed",
                "Android could not write the Downloads report",
                error.message,
            )
        }
    }

    private fun bindCellular(result: MethodChannel.Result) {
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        connectivityManager = manager
        restoreCallback(manager)

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
            .build()
        val replied = AtomicBoolean(false)
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                if (!replied.compareAndSet(false, true)) return
                val bound = manager.bindProcessToNetwork(network)
                if (!bound) {
                    result.error(
                        "bind_failed",
                        "Android could not bind the runner process to cellular data",
                        null,
                    )
                    return
                }
                cellularCallback = this
                result.success(networkSnapshot(network, manager.getNetworkCapabilities(network)))
            }

            override fun onUnavailable() {
                if (!replied.compareAndSet(false, true)) return
                result.error(
                    "cellular_unavailable",
                    "No usable cellular internet network became available",
                    null,
                )
            }
        }
        cellularCallback = callback

        try {
            manager.requestNetwork(request, callback, 30_000)
        } catch (error: SecurityException) {
            if (replied.compareAndSet(false, true)) {
                result.error(
                    "network_permission",
                    "The runner cannot request a cellular network",
                    error.message,
                )
            }
        } catch (error: RuntimeException) {
            if (replied.compareAndSet(false, true)) {
                result.error(
                    "network_request_failed",
                    "The runner could not request a cellular network",
                    error.message,
                )
            }
        }
    }

    private fun restoreDefault(result: MethodChannel.Result) {
        val manager = connectivityManager
        if (manager != null) {
            restoreCallback(manager)
            manager.bindProcessToNetwork(null)
        }
        result.success(activeNetworkSnapshot())
    }

    private fun restoreCallback(manager: ConnectivityManager) {
        cellularCallback?.let { callback ->
            runCatching { manager.unregisterNetworkCallback(callback) }
        }
        cellularCallback = null
    }

    private fun activeNetworkSnapshot(): Map<String, Any?> {
        val manager = connectivityManager
            ?: (getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager)
                .also { connectivityManager = it }
        val network = manager.activeNetwork
        return networkSnapshot(network, network?.let(manager::getNetworkCapabilities))
    }

    private fun networkSnapshot(
        network: Network?,
        capabilities: NetworkCapabilities?,
    ): Map<String, Any?> = mapOf(
        "active" to (network != null),
        "transports" to buildList {
            if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true) {
                add("cellular")
            }
            if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true) {
                add("wifi")
            }
            if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true) {
                add("ethernet")
            }
            if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true) {
                add("vpn")
            }
            if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) == true) {
                add("bluetooth")
            }
        },
        "validated" to (capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            ?: false),
        "internet" to (capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            ?: false),
        "not_restricted" to (capabilities?.hasCapability(
            NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED,
        ) ?: false),
    )

    override fun onDestroy() {
        connectivityManager?.let { manager ->
            restoreCallback(manager)
            runCatching { manager.bindProcessToNetwork(null) }
        }
        super.onDestroy()
    }
}

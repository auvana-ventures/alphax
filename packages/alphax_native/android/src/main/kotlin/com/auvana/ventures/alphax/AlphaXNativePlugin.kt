package com.auvana.ventures.alphax

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

/** Flutter plugin entry point for the Android AlphaX transport. */
class AlphaXNativePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var transportEngine: CronetTransportEngine? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val methods = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        val events = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        methodChannel = methods
        eventChannel = events
        transportEngine = CronetTransportEngine(
            context = binding.applicationContext,
            methodChannel = methods,
            mainHandler = mainHandler,
        )
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val engine = transportEngine
        if (engine == null) {
            result.error("not_attached", "AlphaXNativePlugin is not attached", null)
            return
        }
        when (call.method) {
            "initialize" -> engine.initialize(result)
            "start" -> engine.start(call.argumentsAsMap(), result)
            "grantCredits" -> engine.grantCredits(call.argumentsAsMap(), result)
            "cancel" -> engine.cancel(call.argumentsAsMap(), result)
            "close" -> engine.close(result)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        transportEngine?.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        transportEngine?.eventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        transportEngine?.shutdown()
        transportEngine = null
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
    }

    companion object {
        const val METHOD_CHANNEL = "alphax_native/transport"
        const val EVENT_CHANNEL = "alphax_native/events"
    }
}

private fun MethodCall.argumentsAsMap(): Map<String, Any?> {
    @Suppress("UNCHECKED_CAST")
    return (arguments as? Map<*, *>)
        ?.entries
        ?.associate { (key, value) -> key.toString() to value }
        ?: emptyMap()
}

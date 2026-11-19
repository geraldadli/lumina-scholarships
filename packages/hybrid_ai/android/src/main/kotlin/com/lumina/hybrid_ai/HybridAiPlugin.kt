package com.lumina.hybrid_ai

import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

/** Mendaftarkan [HybridAiApiImpl] ke Flutter lewat kanal Pigeon. */
class HybridAiPlugin : FlutterPlugin {
    private var scope: CoroutineScope? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        scope = pluginScope
        HybridAiHostApi.setUp(
            binding.binaryMessenger,
            HybridAiApiImpl(HybridAiFlutterApi(binding.binaryMessenger), pluginScope),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        HybridAiHostApi.setUp(binding.binaryMessenger, null)
        scope?.cancel()
        scope = null
    }
}

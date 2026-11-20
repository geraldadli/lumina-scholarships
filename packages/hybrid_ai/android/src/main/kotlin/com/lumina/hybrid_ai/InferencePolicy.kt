package com.lumina.hybrid_ai

/**
 * Mode inferensi Lumina. Cermin dari `com.google.firebase.ai.InferenceMode`, tetapi tanpa
 * ketergantungan ke SDK Firebase agar aturannya bisa diuji dengan unit test biasa.
 */
enum class AiMode { PREFER_ON_DEVICE, ONLY_ON_DEVICE, PREFER_IN_CLOUD, ONLY_IN_CLOUD }

/** Kode error yang dikirim ke Flutter (`PlatformException.code`). Didokumentasikan di README paket. */
object ErrorCodes {
    const val INVALID_REQUEST = "INVALID_REQUEST"
    const val NO_CONTEXT = "NO_CONTEXT"
    const val PRIVATE_MODE_UNAVAILABLE = "PRIVATE_MODE_UNAVAILABLE"
    const val ON_DEVICE_UNSUPPORTED = "ON_DEVICE_UNSUPPORTED"
    const val MODEL_NOT_DOWNLOADED = "MODEL_NOT_DOWNLOADED"
    const val MODEL_DOWNLOADING = "MODEL_DOWNLOADING"
    const val BUSY = "BUSY"
    const val QUOTA_EXCEEDED = "QUOTA_EXCEEDED"
    const val APP_CHECK_FAILED = "APP_CHECK_FAILED"
    const val NETWORK = "NETWORK"
    const val TIMEOUT = "TIMEOUT"
    const val CONTENT_BLOCKED = "CONTENT_BLOCKED"
    const val EMPTY_RESPONSE = "EMPTY_RESPONSE"
    const val FIREBASE_NOT_CONFIGURED = "FIREBASE_NOT_CONFIGURED"
    const val UNKNOWN = "UNKNOWN"
}

object InferencePolicy {
    val DEFAULT_MODE = AiMode.PREFER_ON_DEVICE

    /** Membaca nilai Remote Config `ai_inference_mode`. Nilai tak dikenal → default. */
    fun parse(raw: String?): AiMode =
        AiMode.entries.firstOrNull { it.name.equals(raw?.trim(), ignoreCase = true) } ?: DEFAULT_MODE

    /**
     * Privasi selalu menang atas Remote Config: jika user tidak mengizinkan cloud
     * (`privacy.cloudAiAllowed == false`), hanya Gemini Nano yang boleh dipakai.
     */
    fun resolve(remoteMode: AiMode, allowCloud: Boolean): AiMode =
        if (!allowCloud) AiMode.ONLY_ON_DEVICE else remoteMode

    /**
     * Error yang harus dilempar SEBELUM memanggil model, atau `null` bila boleh jalan.
     * Hanya relevan untuk ONLY_ON_DEVICE; mode lain otomatis jatuh ke cloud bila Nano tidak siap.
     */
    fun precheck(mode: AiMode, onDevice: ModelAvailability, allowCloud: Boolean): HybridAiError? {
        if (mode != AiMode.ONLY_ON_DEVICE || onDevice == ModelAvailability.AVAILABLE) return null
        return when (onDevice) {
            ModelAvailability.DOWNLOADABLE -> HybridAiError(
                ErrorCodes.MODEL_NOT_DOWNLOADED,
                "Gemini Nano has not been downloaded yet. Call downloadModel() first.",
            )
            ModelAvailability.DOWNLOADING -> HybridAiError(
                ErrorCodes.MODEL_DOWNLOADING,
                "Gemini Nano is still downloading. Try again when the download finishes.",
            )
            else -> if (!allowCloud) {
                HybridAiError(
                    ErrorCodes.PRIVATE_MODE_UNAVAILABLE,
                    "Private mode is on, but this device does not support Gemini Nano.",
                )
            } else {
                HybridAiError(ErrorCodes.ON_DEVICE_UNSUPPORTED, "This device does not support Gemini Nano.")
            }
        }
    }
}

/** Klasifikasi error dari pesan teks (dipakai untuk exception on-device yang tidak bertipe spesifik). */
object ErrorClassifier {
    private const val MAX_CAUSE_DEPTH = 8

    fun fromMessage(message: String?): String? {
        val m = message?.lowercase() ?: return null
        return when {
            "battery" in m && "quota" in m -> ErrorCodes.QUOTA_EXCEEDED
            "busy" in m -> ErrorCodes.BUSY
            "app check" in m || "appcheck" in m || "app_check" in m -> ErrorCodes.APP_CHECK_FAILED
            // A timeout wins over a network error: "AI took too long" is what the user must see
            // even when the same failure also mentions the network.
            isTimeoutMessage(m) -> ErrorCodes.TIMEOUT
            "unable to resolve host" in m || "network" in m -> ErrorCodes.NETWORK
            else -> null
        }
    }

    /**
     * Standard Java exceptions, looking through the whole cause chain. A timeout anywhere in the chain
     * wins over a network error: an `IOException` that wraps a `SocketTimeoutException` is a TIMEOUT.
     * Only when no timeout is present is an `IOException` (DNS failure, no signal, ...) reported as NETWORK.
     */
    fun fromThrowable(error: Throwable?): String? {
        val chain = causeChain(error)
        return when {
            chain.isEmpty() -> null
            isTimeout(error) -> ErrorCodes.TIMEOUT
            chain.any { it is java.io.IOException } -> ErrorCodes.NETWORK
            else -> null
        }
    }

    /** True when the exception, any of its causes, or any of their messages describes a timeout. */
    fun isTimeout(error: Throwable?): Boolean = causeChain(error).any {
        it is java.net.SocketTimeoutException ||
            it is java.util.concurrent.TimeoutException ||
            isTimeoutMessage(it.message?.lowercase())
    }

    /** The exception followed by its causes, outermost first. Bounded and safe against cause cycles. */
    fun causeChain(error: Throwable?): List<Throwable> {
        val chain = ArrayList<Throwable>()
        var current = error
        while (current != null && chain.size < MAX_CAUSE_DEPTH && chain.none { it === current }) {
            chain += current
            current = current.cause
        }
        return chain
    }

    private fun isTimeoutMessage(lowercased: String?): Boolean {
        val m = lowercased ?: return false
        return "deadline_exceeded" in m || "deadline exceeded" in m || "timed out" in m || "timeout" in m
    }
}

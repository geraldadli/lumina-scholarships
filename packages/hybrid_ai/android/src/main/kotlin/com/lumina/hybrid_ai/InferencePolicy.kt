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
                "Gemini Nano belum diunduh. Panggil downloadModel() terlebih dahulu.",
            )
            ModelAvailability.DOWNLOADING -> HybridAiError(
                ErrorCodes.MODEL_DOWNLOADING,
                "Gemini Nano sedang diunduh. Coba lagi setelah unduhan selesai.",
            )
            else -> if (!allowCloud) {
                HybridAiError(
                    ErrorCodes.PRIVATE_MODE_UNAVAILABLE,
                    "Mode privat aktif, tetapi perangkat ini tidak mendukung Gemini Nano.",
                )
            } else {
                HybridAiError(ErrorCodes.ON_DEVICE_UNSUPPORTED, "Perangkat ini tidak mendukung Gemini Nano.")
            }
        }
    }
}

/** Klasifikasi error dari pesan teks (dipakai untuk exception on-device yang tidak bertipe spesifik). */
object ErrorClassifier {
    fun fromMessage(message: String?): String? {
        val m = message?.lowercase() ?: return null
        return when {
            "battery" in m && "quota" in m -> ErrorCodes.QUOTA_EXCEEDED
            "busy" in m -> ErrorCodes.BUSY
            "app check" in m || "appcheck" in m || "app_check" in m -> ErrorCodes.APP_CHECK_FAILED
            // Putus koneksi dan "terlalu lama menjawab" adalah dua masalah berbeda untuk user.
            "unable to resolve host" in m -> ErrorCodes.NETWORK
            "deadline_exceeded" in m || "deadline exceeded" in m || "timed out" in m || "timeout" in m -> ErrorCodes.TIMEOUT
            "network" in m -> ErrorCodes.NETWORK
            else -> null
        }
    }

    /** Exception Java standar: timeout dipisah dari putus koneksi (DNS, tidak ada sinyal, dll). */
    fun fromThrowable(error: Throwable?): String? = when (error) {
        null -> null
        is java.net.SocketTimeoutException -> ErrorCodes.TIMEOUT
        is java.io.IOException -> ErrorCodes.NETWORK
        else -> null
    }
}

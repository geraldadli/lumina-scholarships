package com.lumina.hybrid_ai

/**
 * Penjaga konteks: AI hanya boleh menjawab bila ada data beasiswa yang bisa dijadikan sumber.
 *
 * Konteks berasal dari dokumen Firestore yang boleh dibaca user (atau dari cache-nya) dan
 * dikirim oleh Flutter. Tanpa judul dan tautan sumber resmi, jawaban tidak bisa "berbasis
 * sumber", dan model kecil seperti Gemini Nano berisiko mengarang. Pemeriksaan ini berjalan
 * SEBELUM model dipanggil, tanpa Firebase, sehingga mudah diuji dengan unit test biasa.
 */
object ContextGuard {

    /** Error yang harus dilempar sebelum memanggil model, atau `null` bila konteks layak dipakai. */
    fun check(scholarship: ScholarshipContext): HybridAiError? {
        val missing = buildList {
            if (scholarship.title.isBlank()) add("title")
            if (!isUsableSourceUrl(scholarship.sourceUrl)) add("sourceUrl")
        }
        if (missing.isEmpty()) return null
        return HybridAiError(
            ErrorCodes.NO_CONTEXT,
            "Scholarship data is incomplete and cannot be used as an answer source (missing: ${missing.joinToString()}).",
        )
    }

    internal fun isUsableSourceUrl(url: String): Boolean {
        val value = url.trim()
        return value.startsWith("https://", ignoreCase = true) || value.startsWith("http://", ignoreCase = true)
    }
}

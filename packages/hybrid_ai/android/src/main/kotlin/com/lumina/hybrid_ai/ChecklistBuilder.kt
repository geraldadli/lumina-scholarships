package com.lumina.hybrid_ai

/**
 * Checklist "Prepare". Item & label SELALU berasal dari data resmi (`requirements`), sehingga
 * AI tidak bisa menambah/mengubah syarat. AI hanya menyumbang `tip` per item.
 * Jika AI gagal / formatnya rusak, checklist tetap bisa dipakai (tanpa tip).
 */
object ChecklistBuilder {
    const val ID_OFFICIAL_GUIDE = "official-guide"
    const val ID_DEADLINE = "deadline"

    fun base(s: ScholarshipContext, languageCode: String): List<ChecklistItem> {
        val id = languageCode.lowercase() == "id"
        val items = s.requirements
            .filter { it.id.isNotBlank() && it.label.isNotBlank() }
            .distinctBy { it.id }
            .map { ChecklistItem(id = it.id, label = it.label.trim()) }
            .toMutableList()
        if (s.sourceUrl.isNotBlank()) {
            items += ChecklistItem(
                id = ID_OFFICIAL_GUIDE,
                label = if (id) "Baca panduan resmi: ${s.sourceUrl}" else "Read the official guide: ${s.sourceUrl}",
            )
        }
        if (!s.deadline.isNullOrBlank()) {
            items += ChecklistItem(
                id = ID_DEADLINE,
                label = if (id) "Kirim pendaftaran sebelum ${s.deadline}" else "Submit the application before ${s.deadline}",
            )
        }
        return items
    }

    private val objectPattern = Regex("""\{[^{}]*\}""")
    private val idPattern = Regex(""""id"\s*:\s*"((?:[^"\\]|\\.)*)"""")
    private val tipPattern = Regex(""""tip"\s*:\s*"((?:[^"\\]|\\.)*)"""")

    /**
     * Membaca `[{"id": "...", "tip": "..."}]` secara toleran: model kecil sering menambah teks,
     * markdown fence, atau mengubah urutan key. Hanya id yang dikenal yang diterima.
     */
    fun parseTips(raw: String, knownIds: Set<String>): Map<String, String> {
        val tips = LinkedHashMap<String, String>()
        for (match in objectPattern.findAll(raw)) {
            val obj = match.value
            val id = idPattern.find(obj)?.groupValues?.get(1)?.let(::unescape)?.trim() ?: continue
            val tip = tipPattern.find(obj)?.groupValues?.get(1)?.let(::unescape)?.trim() ?: continue
            if (id in knownIds && tip.isNotEmpty() && id !in tips) {
                tips[id] = PromptBuilder.clip(tip, 300)
            }
        }
        return tips
    }

    fun withTips(base: List<ChecklistItem>, tips: Map<String, String>): List<ChecklistItem> =
        base.map { item -> tips[item.id]?.let { item.copy(tip = it) } ?: item }

    private fun unescape(s: String): String =
        s.replace("\\n", " ").replace("\\\"", "\"").replace("\\\\", "\\")
}

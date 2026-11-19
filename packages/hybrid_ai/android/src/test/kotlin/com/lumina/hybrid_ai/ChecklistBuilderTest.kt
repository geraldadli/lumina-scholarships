package com.lumina.hybrid_ai

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

internal class ChecklistBuilderTest {

    private val ids = setOf("cv", "lor")

    @Test
    fun base_usesOfficialRequirementsPlusGuideAndDeadline() {
        val items = ChecklistBuilder.base(Fixtures.scholarship(), "id")
        assertEquals(listOf("cv", "lor", ChecklistBuilder.ID_OFFICIAL_GUIDE, ChecklistBuilder.ID_DEADLINE), items.map { it.id })
        assertEquals("CV dalam bahasa Inggris", items[0].label)
        assertTrue(items[3].label.contains("2027-05-10"))
        assertTrue(items.all { it.tip == null })
    }

    @Test
    fun base_skipsDeadlineItemWhenUnknownAndDedupesIds() {
        val s = Fixtures.scholarship(
            requirements = listOf(RequirementItem("cv", "CV"), RequirementItem("cv", "CV lagi"), RequirementItem("", "kosong")),
            deadline = null,
        )
        assertEquals(listOf("cv", ChecklistBuilder.ID_OFFICIAL_GUIDE), ChecklistBuilder.base(s, "en").map { it.id })
    }

    @Test
    fun parseTips_readsCleanJson() {
        val tips = ChecklistBuilder.parseTips("""[{"id":"cv","tip":"Satu halaman."},{"id":"lor","tip":"Minta dosen."}]""", ids)
        assertEquals(mapOf("cv" to "Satu halaman.", "lor" to "Minta dosen."), tips)
    }

    @Test
    fun parseTips_toleratesFencesExtraTextAndSwappedKeys() {
        val raw = """
            Berikut tipsnya:
            ```json
            [ { "tip": "Tulis \"prestasi\" utama.", "id": "cv" } ]
            ```
        """.trimIndent()
        assertEquals(mapOf("cv" to "Tulis \"prestasi\" utama."), ChecklistBuilder.parseTips(raw, ids))
    }

    @Test
    fun parseTips_ignoresUnknownIdsEmptyTipsAndGarbage() {
        val raw = """[{"id":"passport","tip":"x"},{"id":"cv","tip":""},{"id":"lor"}] not json at all"""
        assertTrue(ChecklistBuilder.parseTips(raw, ids).isEmpty())
        assertTrue(ChecklistBuilder.parseTips("maaf saya tidak bisa", ids).isEmpty())
    }

    @Test
    fun withTips_attachesTipsByIdOnly() {
        val merged = ChecklistBuilder.withTips(ChecklistBuilder.base(Fixtures.scholarship(), "id"), mapOf("lor" to "Minta 2 minggu sebelumnya."))
        assertNull(merged.first { it.id == "cv" }.tip)
        assertEquals("Minta 2 minggu sebelumnya.", merged.first { it.id == "lor" }.tip)
    }
}

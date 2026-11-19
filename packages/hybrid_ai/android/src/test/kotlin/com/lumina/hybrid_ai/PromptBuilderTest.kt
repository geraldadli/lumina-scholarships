package com.lumina.hybrid_ai

import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertFalse
import kotlin.test.assertTrue

internal class PromptBuilderTest {

    private fun ask(question: String = "Apa syarat bahasanya?", lang: String = "id", withStudent: Boolean = true) =
        AskRequest(
            question = question,
            scholarship = Fixtures.scholarship(),
            student = if (withStudent) Fixtures.student() else null,
            allowCloud = true,
            languageCode = lang,
        )

    @Test
    fun ask_containsGroundingRulesSourceAndQuestion() {
        val prompt = PromptBuilder.ask(ask())
        assertContains(prompt, "Answer ONLY using the SCHOLARSHIP DATA")
        assertContains(prompt, "Never invent dates")
        assertContains(prompt, "https://www.id.emb-japan.go.jp/sch.html")
        assertContains(prompt, "Language requirement: JLPT N2 / IELTS 6.0")
        assertContains(prompt, "QUESTION:\nApa syarat bahasanya?")
        assertContains(prompt, "Reply in Bahasa Indonesia")
    }

    @Test
    fun ask_usesEnglishForOtherLanguageCodes() {
        assertContains(PromptBuilder.ask(ask(lang = "en")), "Reply in English")
    }

    @Test
    fun ask_includesStudentProfileOnlyWhenProvided() {
        assertContains(PromptBuilder.ask(ask()), "GPA (4.0 scale): 3.6")
        val without = PromptBuilder.ask(ask(withStudent = false))
        assertContains(without, "STUDENT PROFILE:\n- not provided")
        assertFalse("- GPA (4.0 scale): 3.6" in without, "IPK mahasiswa tidak boleh muncul tanpa profil")
    }

    @Test
    fun ask_clipsVeryLongQuestion() {
        val prompt = PromptBuilder.ask(ask(question = "x".repeat(5_000)))
        assertTrue(prompt.length < 5_000 + 4_000, "prompt harus dipangkas")
        assertContains(prompt, "…")
    }

    @Test
    fun scholarshipBlock_marksUnannouncedFields() {
        val block = PromptBuilder.scholarshipBlock(Fixtures.scholarship(fieldsOfStudy = emptyList()))
        assertContains(block, "Fields of study: not announced yet")
    }

    @Test
    fun checklist_listsRequirementIdsAndAsksForJson() {
        val prompt = PromptBuilder.checklist(
            ChecklistRequest(Fixtures.scholarship(), student = null, allowCloud = true, languageCode = "id"),
        )
        assertContains(prompt, "- cv: CV dalam bahasa Inggris")
        assertContains(prompt, "- lor: 2 surat rekomendasi")
        assertContains(prompt, """[{"id": "<requirement id>", "tip": "<tip>"}]""")
    }
}

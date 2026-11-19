package com.lumina.hybrid_ai

/**
 * Merakit prompt yang "grounded": model hanya boleh menjawab dari data beasiswa & profil
 * yang dikirim Flutter. Instruksi ditulis dalam bahasa Inggris karena Gemini Nano paling
 * stabil mengikuti instruksi Inggris; bahasa JAWABAN mengikuti `languageCode`.
 *
 * Batas on-device: input ±4000 token, output disarankan ≤ 256 token. Karena itu konteks
 * dipangkas dan jawaban diminta singkat.
 */
object PromptBuilder {
    const val MAX_QUESTION_CHARS = 1000
    internal const val MAX_FIELD_CHARS = 600
    internal const val MAX_LIST_ITEMS = 15
    internal const val MAX_CONTEXT_CHARS = 6000

    fun languageName(code: String): String = when (code.lowercase()) {
        "id" -> "Bahasa Indonesia"
        else -> "English"
    }

    fun ask(request: AskRequest): String {
        val s = request.scholarship
        val context = trimContext(scholarshipBlock(s) + "\n\n" + studentBlock(request.student))
        return """
            |You are Lumina, a scholarship assistant for university students in Indonesia.
            |Answer ONLY using the SCHOLARSHIP DATA and STUDENT PROFILE below.
            |Rules:
            |1. If the answer is not in the data, say you do not know and tell the student to check the official page: ${s.sourceUrl}
            |2. Never invent dates, amounts, scores, or requirements that are not in the data.
            |3. When the student profile is relevant, compare it honestly with the requirements. Never promise acceptance.
            |4. Reply in ${languageName(request.languageCode)}, in plain text, at most 120 words.
            |
            |$context
            |
            |QUESTION:
            |${clip(request.question.trim(), MAX_QUESTION_CHARS)}
            |
            |ANSWER:
        """.trimMargin()
    }

    fun checklist(request: ChecklistRequest): String {
        val s = request.scholarship
        val reqs = s.requirements.take(MAX_LIST_ITEMS).joinToString("\n") { "- ${it.id}: ${clip(it.label, 200)}" }
        return """
            |You help a student prepare documents for the scholarship "${clip(s.title, 200)}".
            |For EACH requirement below, write one short practical tip (at most 20 words) in ${languageName(request.languageCode)}.
            |Use only general preparation advice; do not invent new requirements, dates, or scores.
            |Return ONLY a JSON array with no other text, in this exact format:
            |[{"id": "<requirement id>", "tip": "<tip>"}]
            |Use exactly these ids.
            |
            |REQUIREMENTS:
            |$reqs
            |${studentBlock(request.student)}
        """.trimMargin()
    }

    internal fun scholarshipBlock(s: ScholarshipContext): String = buildString {
        appendLine("SCHOLARSHIP DATA:")
        line("Title", s.title)
        line("Provider", s.provider)
        line("Description", s.description)
        line("Funding", s.fundingType)
        list("Education levels", s.educationLevels)
        list("Eligible citizenships", s.eligibleCitizenships)
        list("Host countries", s.hostCountries)
        if (s.fieldsOfStudy.isEmpty()) line("Fields of study", "not announced yet") else list("Fields of study", s.fieldsOfStudy)
        line("Minimum GPA (4.0 scale)", s.minGpa?.toString())
        line("Language requirement", s.languageRequirement)
        line("Application opens", s.openDate)
        line("Deadline", s.deadline)
        line("Status", s.status)
        list("Requirements", s.requirements.map { it.label })
        list("Benefits", s.benefits)
        line("Notes", s.notes)
        line("Official page", s.sourceUrl)
    }.trimEnd()

    internal fun studentBlock(st: StudentContext?): String {
        if (st == null) return "STUDENT PROFILE:\n- not provided"
        return buildString {
            appendLine("STUDENT PROFILE:")
            line("Target education level", st.educationLevel)
            line("Citizenship", st.citizenship)
            list("Target countries", st.targetCountries)
            list("Fields of study", st.fieldsOfStudy)
            line("GPA (4.0 scale)", st.gpa?.toString())
            line("Language scores", st.languageSummary)
            list("Skills", st.skills)
            line("Work experience (years)", st.experienceYears?.toString())
        }.trimEnd()
    }

    private fun StringBuilder.line(label: String, value: String?) {
        if (!value.isNullOrBlank()) appendLine("- $label: ${clip(value.trim(), MAX_FIELD_CHARS)}")
    }

    private fun StringBuilder.list(label: String, values: List<String>) {
        val items = values.map { it.trim() }.filter { it.isNotEmpty() }.take(MAX_LIST_ITEMS)
        if (items.isNotEmpty()) appendLine("- $label: ${clip(items.joinToString("; "), MAX_FIELD_CHARS)}")
    }

    internal fun clip(text: String, max: Int): String = if (text.length <= max) text else text.take(max - 1) + "…"

    private fun trimContext(context: String): String = clip(context, MAX_CONTEXT_CHARS)
}

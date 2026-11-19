package com.lumina.hybrid_ai

internal object Fixtures {
    fun scholarship(
        requirements: List<RequirementItem> = listOf(
            RequirementItem("cv", "CV dalam bahasa Inggris"),
            RequirementItem("lor", "2 surat rekomendasi"),
        ),
        fieldsOfStudy: List<String> = listOf("ALL"),
        deadline: String? = "2027-05-10",
    ) = ScholarshipContext(
        id = "mext-scholarship-2027",
        title = "MEXT Scholarship 2027",
        provider = "Government of Japan",
        description = "Beasiswa penuh pemerintah Jepang.",
        fundingType = "full",
        educationLevels = listOf("masters", "phd"),
        eligibleCitizenships = listOf("ID"),
        hostCountries = listOf("JP"),
        fieldsOfStudy = fieldsOfStudy,
        minGpa = 3.2,
        languageRequirement = "JLPT N2 / IELTS 6.0",
        openDate = "2027-04-01",
        deadline = deadline,
        status = "active",
        requirements = requirements,
        benefits = listOf("Biaya kuliah penuh", "Tunjangan bulanan"),
        sourceUrl = "https://www.id.emb-japan.go.jp/sch.html",
        notes = null,
    )

    fun student() = StudentContext(
        educationLevel = "masters",
        citizenship = "ID",
        targetCountries = listOf("JP"),
        fieldsOfStudy = listOf("Computer Science"),
        gpa = 3.6,
        languageSummary = "IELTS 7.0",
        skills = listOf("Flutter"),
        experienceYears = 2,
    )
}

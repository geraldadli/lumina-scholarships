package com.lumina.hybrid_ai

import java.net.MalformedURLException
import java.net.URL

/**
 * Context guard: the AI may only answer when there is scholarship data it can be grounded in.
 *
 * The context comes from a Firestore document the user may read (or its cache) and is sent by Flutter.
 * Without a title and an official source link, an answer cannot be "source-backed", and a small model such
 * as Gemini Nano is likely to make things up. This check runs BEFORE any model is called, with no Firebase
 * dependency, so it is easy to cover with plain unit tests.
 */
object ContextGuard {

    /** The error to throw before calling a model, or `null` when the context is usable. */
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

    internal fun isUsableSourceUrl(url: String): Boolean = hostOf(url) != null

    /**
     * The hostname of an http(s) link, or `null` when the link cannot serve as a source.
     *
     * A bare scheme is not enough: "https://", "https:///path", an empty host, or an empty label
     * (".com", "a..b", "example.") are all rejected, so a link without a real host never counts as a source.
     */
    internal fun hostOf(url: String): String? {
        val value = url.trim()
        // The first character after "://" must belong to the host, not be "/", "?", "#", or whitespace.
        if (!SCHEME_THEN_HOST.containsMatchIn(value)) return null
        val parsed = try {
            URL(value)
        } catch (e: MalformedURLException) {
            return null
        }
        val host = parsed.host.orEmpty()
        if (host.isBlank() || host.any { it.isWhitespace() }) return null
        if (host.startsWith("[") && host.endsWith("]")) return host // IPv6 literal
        return if (host.split('.').all { it.isNotEmpty() }) host else null
    }

    private val SCHEME_THEN_HOST = Regex("""^https?://[^/?#\s]""", RegexOption.IGNORE_CASE)
}

package com.lumina.hybrid_ai

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

internal class ContextGuardTest {

    @Test
    fun check_allowsCompleteScholarship() {
        assertNull(ContextGuard.check(Fixtures.scholarship()))
    }

    @Test
    fun check_rejectsBlankTitle() {
        val error = ContextGuard.check(Fixtures.scholarship().copy(title = "   "))
        assertNotNull(error)
        assertEquals(ErrorCodes.NO_CONTEXT, error.code)
        assertTrue(error.message.orEmpty().contains("title"))
    }

    @Test
    fun check_rejectsBlankSourceUrl() {
        val error = ContextGuard.check(Fixtures.scholarship().copy(sourceUrl = ""))
        assertNotNull(error)
        assertEquals(ErrorCodes.NO_CONTEXT, error.code)
        assertTrue(error.message.orEmpty().contains("sourceUrl"))
    }

    @Test
    fun check_rejectsSourceUrlThatIsNotAWebLink() {
        for (bad in listOf("-", "example.org", "javascript:alert(1)", "ftp://example.org")) {
            val error = ContextGuard.check(Fixtures.scholarship().copy(sourceUrl = bad))
            assertNotNull(error, "seharusnya ditolak: $bad")
            assertEquals(ErrorCodes.NO_CONTEXT, error.code)
        }
    }

    @Test
    fun check_rejectsLinksWithoutARealHost() {
        val bare = listOf(
            "https://",
            "http://",
            "https:///path",
            "https://?q=1",
            "https://#frag",
            "https://:8080",
            "https://@/x",
            "https://.com",
            "https://example.",
            "https://a..b",
            "https://exa mple.com",
        )
        for (bad in bare) {
            val error = ContextGuard.check(Fixtures.scholarship().copy(sourceUrl = bad))
            assertNotNull(error, "should be rejected: $bad")
            assertEquals(ErrorCodes.NO_CONTEXT, error.code)
            assertTrue(error.message.orEmpty().contains("sourceUrl"))
        }
    }

    @Test
    fun check_acceptsRealHosts() {
        val good = listOf(
            "https://example.org",
            "https://www.id.emb-japan.go.jp/sch.html",
            "https://example.org:8443/path?x=1#y",
            "http://localhost:8080",
            "http://[::1]/",
            "https://münchen.de/",
        )
        for (ok in good) {
            assertNull(ContextGuard.check(Fixtures.scholarship().copy(sourceUrl = ok)), "should pass: $ok")
        }
    }

    @Test
    fun hostOf_returnsTheHostname() {
        assertEquals("example.org", ContextGuard.hostOf("https://example.org/a/b"))
        assertEquals("example.org", ContextGuard.hostOf("  HTTPS://example.org:8443  "))
        assertNull(ContextGuard.hostOf("https://"))
    }

    @Test
    fun check_acceptsHttpAndHttpsCaseInsensitively() {
        for (ok in listOf("https://example.org", " HTTPS://example.org ", "http://example.org")) {
            assertNull(ContextGuard.check(Fixtures.scholarship().copy(sourceUrl = ok)), "seharusnya lolos: $ok")
        }
    }

    @Test
    fun check_reportsEveryMissingField() {
        val error = ContextGuard.check(Fixtures.scholarship().copy(title = "", sourceUrl = ""))
        assertNotNull(error)
        assertTrue(error.message.orEmpty().contains("title"))
        assertTrue(error.message.orEmpty().contains("sourceUrl"))
    }
}

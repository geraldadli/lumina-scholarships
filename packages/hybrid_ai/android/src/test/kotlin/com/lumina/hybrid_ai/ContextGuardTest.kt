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

package com.lumina.hybrid_ai

import java.io.IOException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

internal class ErrorClassifierTest {

    @Test
    fun fromMessage_separatesTimeoutFromNoConnection() {
        assertEquals(ErrorCodes.TIMEOUT, ErrorClassifier.fromMessage("DEADLINE_EXCEEDED"))
        assertEquals(ErrorCodes.TIMEOUT, ErrorClassifier.fromMessage("Status: Deadline exceeded while waiting"))
        assertEquals(ErrorCodes.TIMEOUT, ErrorClassifier.fromMessage("Request timed out."))
        assertEquals(ErrorCodes.TIMEOUT, ErrorClassifier.fromMessage("Read timeout"))
        assertEquals(ErrorCodes.NETWORK, ErrorClassifier.fromMessage("Unable to resolve host firebasevertexai.googleapis.com"))
        assertEquals(ErrorCodes.NETWORK, ErrorClassifier.fromMessage("Network is unreachable"))
    }

    @Test
    fun fromMessage_keepsOtherCodes() {
        assertEquals(ErrorCodes.BUSY, ErrorClassifier.fromMessage("AICore is busy"))
        assertEquals(ErrorCodes.APP_CHECK_FAILED, ErrorClassifier.fromMessage("App Check token is invalid"))
        assertNull(ErrorClassifier.fromMessage("something unexpected"))
    }

    @Test
    fun fromThrowable_socketTimeoutIsTimeout() {
        assertEquals(ErrorCodes.TIMEOUT, ErrorClassifier.fromThrowable(SocketTimeoutException("timeout")))
    }

    @Test
    fun fromThrowable_otherIoErrorsAreNoConnection() {
        assertEquals(ErrorCodes.NETWORK, ErrorClassifier.fromThrowable(UnknownHostException("host")))
        assertEquals(ErrorCodes.NETWORK, ErrorClassifier.fromThrowable(ConnectException("refused")))
        assertEquals(ErrorCodes.NETWORK, ErrorClassifier.fromThrowable(IOException("broken pipe")))
    }

    @Test
    fun fromThrowable_ignoresNonIoErrors() {
        assertNull(ErrorClassifier.fromThrowable(IllegalStateException("x")))
        assertNull(ErrorClassifier.fromThrowable(null))
    }
}

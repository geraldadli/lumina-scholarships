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
    fun fromThrowable_timeoutWinsOverNetworkErrorWhenWrapped() {
        // A network error that wraps a timeout is still a timeout.
        assertEquals(
            ErrorCodes.TIMEOUT,
            ErrorClassifier.fromThrowable(IOException("Network error", SocketTimeoutException("read timed out"))),
        )
        assertEquals(
            ErrorCodes.TIMEOUT,
            ErrorClassifier.fromThrowable(RuntimeException("request failed", SocketTimeoutException("timeout"))),
        )
        // The same failure described as both a network error and a timeout.
        assertEquals(ErrorCodes.TIMEOUT, ErrorClassifier.fromThrowable(IOException("Network timeout")))
        assertEquals(
            ErrorCodes.TIMEOUT,
            ErrorClassifier.fromThrowable(IOException("Network error", RuntimeException("DEADLINE_EXCEEDED"))),
        )
        assertEquals(ErrorCodes.TIMEOUT, ErrorClassifier.fromThrowable(java.util.concurrent.TimeoutException("slow")))
    }

    @Test
    fun fromThrowable_networkErrorWithoutTimeoutStaysNetwork() {
        assertEquals(
            ErrorCodes.NETWORK,
            ErrorClassifier.fromThrowable(IOException("broken pipe", UnknownHostException("host"))),
        )
        assertEquals(ErrorCodes.NETWORK, ErrorClassifier.fromThrowable(RuntimeException("x", ConnectException("refused"))))
    }

    @Test
    fun fromMessage_timeoutWinsOverNetworkWording() {
        assertEquals(ErrorCodes.TIMEOUT, ErrorClassifier.fromMessage("Unable to resolve host x: connection timed out"))
        assertEquals(ErrorCodes.TIMEOUT, ErrorClassifier.fromMessage("Network error: DEADLINE_EXCEEDED"))
        assertEquals(ErrorCodes.NETWORK, ErrorClassifier.fromMessage("Unable to resolve host x"))
    }

    @Test
    fun isTimeout_looksThroughTheCauseChainAndIgnoresUnrelatedErrors() {
        assertEquals(true, ErrorClassifier.isTimeout(RuntimeException("outer", RuntimeException("deadline exceeded"))))
        assertEquals(false, ErrorClassifier.isTimeout(IOException("Network is unreachable")))
        assertEquals(false, ErrorClassifier.isTimeout(null))
    }

    @Test
    fun causeChain_isBoundedAndSafeAgainstCycles() {
        val a = RuntimeException("a")
        val b = RuntimeException("b")
        a.initCause(b)
        b.initCause(a)
        assertEquals(2, ErrorClassifier.causeChain(a).size)
        assertNull(ErrorClassifier.fromThrowable(a))
    }

    @Test
    fun fromThrowable_ignoresNonIoErrors() {
        assertNull(ErrorClassifier.fromThrowable(IllegalStateException("x")))
        assertNull(ErrorClassifier.fromThrowable(null))
    }
}

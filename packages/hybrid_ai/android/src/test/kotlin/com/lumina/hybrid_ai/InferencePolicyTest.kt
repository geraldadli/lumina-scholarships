package com.lumina.hybrid_ai

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

internal class InferencePolicyTest {

    @Test
    fun parse_readsRemoteConfigValuesCaseInsensitively() {
        assertEquals(AiMode.PREFER_ON_DEVICE, InferencePolicy.parse("PREFER_ON_DEVICE"))
        assertEquals(AiMode.ONLY_IN_CLOUD, InferencePolicy.parse(" only_in_cloud "))
    }

    @Test
    fun parse_fallsBackToDefaultForUnknownOrEmpty() {
        assertEquals(AiMode.PREFER_ON_DEVICE, InferencePolicy.parse("SOMETHING_ELSE"))
        assertEquals(AiMode.PREFER_ON_DEVICE, InferencePolicy.parse(""))
        assertEquals(AiMode.PREFER_ON_DEVICE, InferencePolicy.parse(null))
    }

    @Test
    fun resolve_privacyAlwaysWins() {
        for (mode in AiMode.entries) {
            assertEquals(AiMode.ONLY_ON_DEVICE, InferencePolicy.resolve(mode, allowCloud = false))
        }
    }

    @Test
    fun resolve_keepsRemoteModeWhenCloudAllowed() {
        assertEquals(AiMode.PREFER_IN_CLOUD, InferencePolicy.resolve(AiMode.PREFER_IN_CLOUD, allowCloud = true))
    }

    @Test
    fun precheck_allowsNonOnDeviceOnlyModes() {
        assertNull(InferencePolicy.precheck(AiMode.PREFER_ON_DEVICE, ModelAvailability.UNAVAILABLE, true))
        assertNull(InferencePolicy.precheck(AiMode.ONLY_IN_CLOUD, ModelAvailability.UNAVAILABLE, true))
    }

    @Test
    fun precheck_allowsOnDeviceWhenModelAvailable() {
        assertNull(InferencePolicy.precheck(AiMode.ONLY_ON_DEVICE, ModelAvailability.AVAILABLE, false))
    }

    @Test
    fun precheck_reportsWhyOnDeviceCannotRun() {
        assertEquals(
            ErrorCodes.MODEL_NOT_DOWNLOADED,
            InferencePolicy.precheck(AiMode.ONLY_ON_DEVICE, ModelAvailability.DOWNLOADABLE, false)?.code,
        )
        assertEquals(
            ErrorCodes.MODEL_DOWNLOADING,
            InferencePolicy.precheck(AiMode.ONLY_ON_DEVICE, ModelAvailability.DOWNLOADING, false)?.code,
        )
        assertEquals(
            ErrorCodes.PRIVATE_MODE_UNAVAILABLE,
            InferencePolicy.precheck(AiMode.ONLY_ON_DEVICE, ModelAvailability.UNAVAILABLE, allowCloud = false)?.code,
        )
        assertEquals(
            ErrorCodes.ON_DEVICE_UNSUPPORTED,
            InferencePolicy.precheck(AiMode.ONLY_ON_DEVICE, ModelAvailability.UNAVAILABLE, allowCloud = true)?.code,
        )
    }

    @Test
    fun precheck_unknownCauseIsNeverReportedAsUnsupported() {
        for (allowCloud in listOf(true, false)) {
            assertEquals(
                ErrorCodes.ON_DEVICE_UNAVAILABLE,
                InferencePolicy.precheck(AiMode.ONLY_ON_DEVICE, ModelAvailability.UNKNOWN, allowCloud)?.code,
            )
        }
        assertNull(InferencePolicy.precheck(AiMode.PREFER_ON_DEVICE, ModelAvailability.UNKNOWN, true))
    }

    @Test
    fun nanoProbe_onlyARealAnswerCanBeUnavailable() {
        assertEquals(ModelAvailability.UNKNOWN, NanoStatusProbe.ExtensionMissing.toAvailability())
        assertEquals(ModelAvailability.UNKNOWN, NanoStatusProbe.CheckFailed(RuntimeException("boom")).toAvailability())
        assertEquals(
            ModelAvailability.UNAVAILABLE,
            NanoStatusProbe.Reported(ModelAvailability.UNAVAILABLE, "UNAVAILABLE").toAvailability(),
        )
        assertEquals(
            ModelAvailability.AVAILABLE,
            NanoStatusProbe.Reported(ModelAvailability.AVAILABLE, "AVAILABLE").toAvailability(),
        )
    }

    @Test
    fun nanoProbe_logLineNamesTheOutcome() {
        assertTrue("EXTENSION_MISSING" in NanoStatusProbe.ExtensionMissing.describe())
        val failed = NanoStatusProbe.CheckFailed(IllegalStateException("AICore not reachable")).describe()
        assertTrue("CHECK_FAILED" in failed && "IllegalStateException" in failed && "AICore not reachable" in failed)
        val reported = NanoStatusProbe.Reported(ModelAvailability.UNAVAILABLE, "UNAVAILABLE").describe()
        assertTrue("REPORTED" in reported && "UNAVAILABLE" in reported)
    }

    @Test
    fun nanoProbe_longErrorMessagesAreTruncatedInTheLog() {
        val line = NanoStatusProbe.CheckFailed(RuntimeException("x".repeat(5_000))).describe()
        assertTrue(line.length < 400)
    }

    @Test
    fun errorClassifier_mapsKnownMessages() {
        assertEquals(ErrorCodes.BUSY, ErrorClassifier.fromMessage("ErrorCode.BUSY: AICore is busy"))
        assertEquals(ErrorCodes.QUOTA_EXCEEDED, ErrorClassifier.fromMessage("PER_APP_BATTERY_USE_QUOTA_EXCEEDED"))
        assertEquals(ErrorCodes.APP_CHECK_FAILED, ErrorClassifier.fromMessage("Firebase App Check token is invalid"))
        assertEquals(ErrorCodes.NETWORK, ErrorClassifier.fromMessage("Unable to resolve host firebasevertexai.googleapis.com"))
        assertNull(ErrorClassifier.fromMessage("something unexpected"))
        assertNull(ErrorClassifier.fromMessage(null))
    }
}

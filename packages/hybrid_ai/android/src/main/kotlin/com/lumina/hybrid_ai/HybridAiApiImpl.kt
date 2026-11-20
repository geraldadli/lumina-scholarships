@file:OptIn(PublicPreviewAPI::class)

package com.lumina.hybrid_ai

import android.os.SystemClock
import android.util.Log
import com.google.android.gms.tasks.Task
import com.google.firebase.Firebase
import com.google.firebase.ai.DownloadStatus
import com.google.firebase.ai.GenerativeModel
import com.google.firebase.ai.InferenceMode
import com.google.firebase.ai.InferenceSource
import com.google.firebase.ai.OnDeviceConfig
import com.google.firebase.ai.OnDeviceModelStatus
import com.google.firebase.ai.ai
import com.google.firebase.ai.type.ContentBlockedException
import com.google.firebase.ai.type.FirebaseAIOnDeviceInvalidRequestException
import com.google.firebase.ai.type.FirebaseAIOnDeviceNotAvailableException
import com.google.firebase.ai.type.GenerateContentResponse
import com.google.firebase.ai.type.GenerativeBackend
import com.google.firebase.ai.type.PromptBlockedException
import com.google.firebase.ai.type.PublicPreviewAPI
import com.google.firebase.ai.type.QuotaExceededException
import com.google.firebase.ai.type.RequestTimeoutException
import com.google.firebase.ai.type.ResponseStoppedException
import com.google.firebase.ai.type.generationConfig
import com.google.firebase.remoteconfig.FirebaseRemoteConfig
import com.google.firebase.remoteconfig.remoteConfig
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeout
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Implementasi Hybrid AI: Gemini Nano on-device (via Android AICore) dengan fallback ke model
 * cloud Firebase AI Logic, dikendalikan oleh Remote Config dan pengaturan privasi user.
 *
 * Privasi: isi prompt, pertanyaan, dan profil mahasiswa TIDAK PERNAH ditulis ke log.
 */
class HybridAiApiImpl(
    private val flutterApi: HybridAiFlutterApi,
    private val scope: CoroutineScope,
) : HybridAiHostApi {

    private data class Settings(
        val mode: AiMode,
        val cloudModel: String,
        val minMatchScore: Double,
        val fetched: Boolean,
    )

    private val configMutex = Mutex()
    private var configFetchAttempted = false
    private var configFetched = false
    private val models = HashMap<Pair<AiMode, String>, GenerativeModel>()
    private var downloadJob: Job? = null
    private var warmedUp = false

    // ───────────────────────── HostApi ─────────────────────────

    override suspend fun getStatus(): AiStatus = guard {
        val settings = loadSettings()
        val model = model(AiMode.PREFER_ON_DEVICE, settings.cloudModel)
        val availability = availability(model)
        val name = if (availability == ModelAvailability.AVAILABLE) {
            warmUpOnce(model)
            runCatching { model.onDeviceExtension?.getModelName() }.getOrNull()
        } else null
        AiStatus(
            onDeviceModel = availability,
            onDeviceModelName = name,
            inferenceMode = settings.mode.name,
            cloudModel = settings.cloudModel,
            minMatchScore = settings.minMatchScore,
            remoteConfigFetched = settings.fetched,
        )
    }

    override suspend fun startModelDownload(): Unit = guard {
        if (downloadJob?.isActive == true) return@guard
        val settings = loadSettings()
        val model = model(AiMode.PREFER_ON_DEVICE, settings.cloudModel)
        when (availability(model)) {
            ModelAvailability.AVAILABLE -> {
                send(DownloadProgress(state = DownloadState.COMPLETED))
                return@guard
            }
            ModelAvailability.UNAVAILABLE -> throw HybridAiError(
                ErrorCodes.ON_DEVICE_UNSUPPORTED,
                "Perangkat ini tidak mendukung Gemini Nano.",
            )
            else -> Unit
        }
        val extension = model.onDeviceExtension ?: throw HybridAiError(
            ErrorCodes.ON_DEVICE_UNSUPPORTED,
            "Ekstensi on-device tidak tersedia.",
        )
        downloadJob = scope.launch {
            var total: Long? = null
            try {
                extension.download().collect { status ->
                    if (status is DownloadStatus.DownloadStarted) total = status.bytesToDownload
                    send(status.toProgress(total))
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                send(DownloadProgress(state = DownloadState.FAILED, errorMessage = e.toHybridAiError().message))
            }
        }
    }

    override suspend fun ask(request: AskRequest): AiAnswer = guard {
        val question = request.question.trim()
        if (question.isEmpty() || question.length > PromptBuilder.MAX_QUESTION_CHARS) {
            throw HybridAiError(
                ErrorCodes.INVALID_REQUEST,
                "Pertanyaan wajib diisi dan maksimal ${PromptBuilder.MAX_QUESTION_CHARS} karakter.",
            )
        }
        // Tanpa data beasiswa yang bisa dijadikan sumber, jangan sentuh model sama sekali.
        ContextGuard.check(request.scholarship)?.let { throw it }
        val settings = loadSettings()
        val mode = InferencePolicy.resolve(settings.mode, request.allowCloud)
        val model = model(mode, settings.cloudModel)
        InferencePolicy.precheck(mode, availabilityIfNeeded(mode, model), request.allowCloud)?.let { throw it }

        val started = SystemClock.elapsedRealtime()
        val response = generateWithRetry(model, PromptBuilder.ask(request))
        val latency = SystemClock.elapsedRealtime() - started

        val text = response.text?.trim().orEmpty()
        if (text.isEmpty()) throw HybridAiError(ErrorCodes.EMPTY_RESPONSE, "Model tidak memberikan jawaban.")

        val source = response.aiSource()
        Log.d(TAG, "ask selesai: mode=${mode.name} source=${source.name} latencyMs=$latency")
        AiAnswer(
            text = text,
            source = source,
            modelName = modelName(source, model, response, settings.cloudModel),
            latencyMs = latency,
            citations = listOf(request.scholarship.sourceUrl).filter { it.isNotBlank() },
        )
    }

    override suspend fun generateChecklist(request: ChecklistRequest): ChecklistResult = guard {
        val base = ChecklistBuilder.base(request.scholarship, request.languageCode)
        val knownIds = request.scholarship.requirements.map { it.id }.toSet()
        if (knownIds.isEmpty()) {
            return@guard ChecklistResult(base, AiSource.RULES, note = "Syarat beasiswa belum tersedia di data Lumina.")
        }
        try {
            val settings = loadSettings()
            val mode = InferencePolicy.resolve(settings.mode, request.allowCloud)
            val model = model(mode, settings.cloudModel)
            InferencePolicy.precheck(mode, availabilityIfNeeded(mode, model), request.allowCloud)?.let { throw it }

            val response = generateWithRetry(model, PromptBuilder.checklist(request))
            val tips = ChecklistBuilder.parseTips(response.text.orEmpty(), knownIds)
            val source = response.aiSource()
            Log.d(TAG, "checklist selesai: mode=${mode.name} source=${source.name} tips=${tips.size}")
            if (tips.isEmpty()) {
                ChecklistResult(base, AiSource.RULES, note = "AI tidak memberi tips yang valid; checklist dari syarat resmi.")
            } else {
                ChecklistResult(ChecklistBuilder.withTips(base, tips), source)
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            val error = e.toHybridAiError()
            Log.d(TAG, "checklist memakai aturan: code=${error.code}")
            ChecklistResult(base, AiSource.RULES, note = "AI tidak tersedia (${error.code}); checklist dari syarat resmi.")
        }
    }

    // ───────────────────────── Internal ─────────────────────────

    /** Membungkus semua error menjadi [HybridAiError] dengan kode yang konsisten untuk Flutter. */
    private suspend fun <T> guard(block: suspend () -> T): T = try {
        block()
    } catch (e: CancellationException) {
        throw e
    } catch (e: Throwable) {
        throw e.toHybridAiError()
    }

    private suspend fun loadSettings(): Settings {
        val rc = remoteConfig()
        configMutex.withLock {
            if (!configFetchAttempted) {
                configFetchAttempted = true
                configFetched = runCatching {
                    withTimeout(FETCH_TIMEOUT_MS) { rc.fetchAndActivate().awaitResult() }
                }.isSuccess
                Log.d(TAG, "Remote Config fetched=$configFetched")
            }
        }
        val threshold = rc.getDouble(KEY_MIN_MATCH)
        return Settings(
            mode = InferencePolicy.parse(rc.getString(KEY_MODE)),
            cloudModel = rc.getString(KEY_CLOUD_MODEL).trim().ifEmpty { DEFAULT_CLOUD_MODEL },
            minMatchScore = if (threshold in 0.0..1.0 && threshold > 0.0) threshold else DEFAULT_MIN_MATCH,
            fetched = configFetched,
        )
    }

    private var remoteConfigInstance: FirebaseRemoteConfig? = null

    private suspend fun remoteConfig(): FirebaseRemoteConfig {
        remoteConfigInstance?.let { return it }
        val rc = Firebase.remoteConfig
        rc.setDefaultsAsync(
            mapOf(
                KEY_MODE to InferencePolicy.DEFAULT_MODE.name,
                KEY_CLOUD_MODEL to DEFAULT_CLOUD_MODEL,
                KEY_MIN_MATCH to DEFAULT_MIN_MATCH,
            ),
        ).awaitResult()
        remoteConfigInstance = rc
        return rc
    }

    private fun model(mode: AiMode, cloudModel: String): GenerativeModel =
        models.getOrPut(mode to cloudModel) {
            Firebase.ai(backend = GenerativeBackend.googleAI()).generativeModel(
                modelName = cloudModel,
                generationConfig = generationConfig {
                    temperature = 0.2f
                    maxOutputTokens = 512
                },
                onDeviceConfig = OnDeviceConfig(
                    mode = mode.toFirebase(),
                    maxOutputTokens = ON_DEVICE_MAX_OUTPUT_TOKENS,
                    temperature = 0.2f,
                ),
            )
        }

    private suspend fun availability(model: GenerativeModel): ModelAvailability {
        val status = runCatching { model.onDeviceExtension?.checkStatus() }.getOrNull()
        return when (status) {
            OnDeviceModelStatus.AVAILABLE -> ModelAvailability.AVAILABLE
            OnDeviceModelStatus.DOWNLOADABLE -> ModelAvailability.DOWNLOADABLE
            OnDeviceModelStatus.DOWNLOADING -> ModelAvailability.DOWNLOADING
            else -> ModelAvailability.UNAVAILABLE
        }
    }

    /** Cek status hanya jika diperlukan (ONLY_ON_DEVICE), agar mode lain tidak menambah latensi. */
    private suspend fun availabilityIfNeeded(mode: AiMode, model: GenerativeModel): ModelAvailability =
        if (mode == AiMode.ONLY_ON_DEVICE) availability(model) else ModelAvailability.AVAILABLE

    private fun warmUpOnce(model: GenerativeModel) {
        if (warmedUp) return
        warmedUp = true
        scope.launch { runCatching { model.onDeviceExtension?.warmUp() } }
    }

    /** Nano bisa sibuk (BUSY) bila dipakai app lain; dokumentasi menyarankan exponential backoff. */
    private suspend fun generateWithRetry(model: GenerativeModel, prompt: String): GenerateContentResponse {
        var attempt = 0
        while (true) {
            try {
                return model.generateContent(prompt)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                val busy = e.toHybridAiError().code == ErrorCodes.BUSY
                if (!busy || attempt >= RETRY_DELAYS_MS.size) throw e
                delay(RETRY_DELAYS_MS[attempt++])
            }
        }
    }

    private suspend fun modelName(
        source: AiSource,
        model: GenerativeModel,
        response: GenerateContentResponse,
        cloudModel: String,
    ): String? = when (source) {
        AiSource.ON_DEVICE -> runCatching { model.onDeviceExtension?.getModelName() }.getOrNull() ?: "gemini-nano"
        else -> response.modelVersion ?: cloudModel
    }

    private suspend fun send(progress: DownloadProgress) {
        runCatching { flutterApi.onDownloadProgress(progress) }
    }

    companion object {
        private const val TAG = "LuminaHybridAi"
        const val KEY_MODE = "ai_inference_mode"
        const val KEY_CLOUD_MODEL = "cloud_fallback_model"
        const val KEY_MIN_MATCH = "min_match_score_threshold"
        const val DEFAULT_CLOUD_MODEL = "gemini-2.5-flash"
        const val DEFAULT_MIN_MATCH = 0.65
        private const val FETCH_TIMEOUT_MS = 5_000L
        private const val ON_DEVICE_MAX_OUTPUT_TOKENS = 256
        private val RETRY_DELAYS_MS = longArrayOf(500L, 1_500L)
    }
}

// ───────────────────────── Konversi ─────────────────────────

private fun AiMode.toFirebase(): InferenceMode = when (this) {
    AiMode.PREFER_ON_DEVICE -> InferenceMode.PREFER_ON_DEVICE
    AiMode.ONLY_ON_DEVICE -> InferenceMode.ONLY_ON_DEVICE
    AiMode.PREFER_IN_CLOUD -> InferenceMode.PREFER_IN_CLOUD
    AiMode.ONLY_IN_CLOUD -> InferenceMode.ONLY_IN_CLOUD
}

private fun GenerateContentResponse.aiSource(): AiSource =
    if (inferenceSource == InferenceSource.ON_DEVICE) AiSource.ON_DEVICE else AiSource.CLOUD

private fun DownloadStatus.toProgress(total: Long?): DownloadProgress = when (this) {
    is DownloadStatus.DownloadStarted -> DownloadProgress(state = DownloadState.STARTED, totalBytes = bytesToDownload)
    is DownloadStatus.DownloadInProgress -> DownloadProgress(
        state = DownloadState.IN_PROGRESS,
        bytesDownloaded = totalBytesDownloaded,
        totalBytes = total,
    )
    is DownloadStatus.DownloadCompleted -> DownloadProgress(state = DownloadState.COMPLETED, totalBytes = total)
    is DownloadStatus.DownloadFailed -> DownloadProgress(
        state = DownloadState.FAILED,
        errorMessage = exception.message ?: "Unduhan gagal.",
    )
    else -> DownloadProgress(state = DownloadState.IN_PROGRESS, totalBytes = total)
}

internal fun Throwable.toHybridAiError(): HybridAiError {
    if (this is HybridAiError) return this
    val text = message ?: javaClass.simpleName
    val code = when (this) {
        is QuotaExceededException -> ErrorCodes.QUOTA_EXCEEDED
        is PromptBlockedException, is ContentBlockedException, is ResponseStoppedException -> ErrorCodes.CONTENT_BLOCKED
        is FirebaseAIOnDeviceNotAvailableException -> ErrorCodes.ON_DEVICE_UNSUPPORTED
        is FirebaseAIOnDeviceInvalidRequestException -> ErrorCodes.INVALID_REQUEST
        is RequestTimeoutException -> ErrorCodes.TIMEOUT
        is IllegalStateException if "FirebaseApp" in text -> ErrorCodes.FIREBASE_NOT_CONFIGURED
        else -> ErrorClassifier.fromThrowable(this)
            ?: ErrorClassifier.fromThrowable(cause)
            ?: ErrorClassifier.fromMessage(text)
            ?: ErrorClassifier.fromMessage(cause?.message)
            ?: ErrorCodes.UNKNOWN
    }
    return HybridAiError(code, text)
}

private suspend fun <T> Task<T>.awaitResult(): T = suspendCancellableCoroutine { cont ->
    addOnCompleteListener { task ->
        if (task.isSuccessful) {
            @Suppress("UNCHECKED_CAST")
            cont.resume(task.result as T)
        } else {
            cont.resumeWithException(task.exception ?: RuntimeException("Task Firebase gagal."))
        }
    }
}

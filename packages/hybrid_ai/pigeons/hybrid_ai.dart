// Kontrak Pigeon: jembatan type-safe Flutter (Dart) <-> Android (Kotlin) untuk Hybrid AI Lumina.
//
// Setelah mengubah file ini, generate ulang kode dengan:
//   dart run pigeon --input pigeons/hybrid_ai.dart
//
// Prinsip: Flutter hanya mengirim DATA terstruktur (beasiswa, profil, pertanyaan).
// Prompt dirakit di sisi Kotlin agar aturan grounding & privasi tidak bisa dilewati dari UI.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'hybrid_ai',
    dartOut: 'lib/src/hybrid_ai.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/src/main/kotlin/com/lumina/hybrid_ai/HybridAi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.lumina.hybrid_ai',
      errorClassName: 'HybridAiError',
    ),
  ),
)
/// Ketersediaan model Gemini Nano di perangkat (dikelola Android AICore).
enum ModelAvailability {
  /// Model siap dipakai.
  available,

  /// Perangkat mendukung, tetapi model belum diunduh. Panggil `downloadModel()`.
  downloadable,

  /// Model sedang diunduh.
  downloading,

  /// Perangkat tidak mendukung Gemini Nano. Hanya jalur cloud yang bisa dipakai.
  unavailable,
}

/// Dari mana sebuah hasil berasal.
enum AiSource {
  /// Gemini Nano di perangkat (data tidak keluar dari HP).
  onDevice,

  /// Model cloud lewat Firebase AI Logic.
  cloud,

  /// Bukan AI: hasil berbasis aturan (dipakai bila AI gagal / tidak tersedia).
  rules,
}

enum DownloadState { started, inProgress, completed, failed }

/// Kondisi AI saat ini, untuk ditampilkan / dipakai mengatur UI.
class AiStatus {
  AiStatus({
    required this.onDeviceModel,
    required this.inferenceMode,
    required this.cloudModel,
    required this.minMatchScore,
    required this.remoteConfigFetched,
    this.onDeviceModelName,
  });

  ModelAvailability onDeviceModel;

  /// Nama model on-device (mis. varian Gemini Nano), bila tersedia.
  String? onDeviceModelName;

  /// Mode dari Remote Config `ai_inference_mode`, mis. `PREFER_ON_DEVICE`.
  String inferenceMode;

  /// Model cloud dari Remote Config `cloud_fallback_model`.
  String cloudModel;

  /// Remote Config `min_match_score_threshold` (0..1).
  double minMatchScore;

  /// `false` bila Remote Config gagal diambil dan nilai default dipakai.
  bool remoteConfigFetched;
}

class DownloadProgress {
  DownloadProgress({
    required this.state,
    this.bytesDownloaded,
    this.totalBytes,
    this.errorMessage,
  });

  DownloadState state;
  int? bytesDownloaded;
  int? totalBytes;
  String? errorMessage;
}

/// Satu syarat beasiswa (`scholarships.requirements[]` di Firestore).
class RequirementItem {
  RequirementItem({required this.id, required this.label});

  String id;
  String label;
}

/// Data beasiswa yang menjadi satu-satunya sumber fakta jawaban AI (grounding).
/// Field mengikuti `scholarships/{id}` di docs/firestore-contract.md.
class ScholarshipContext {
  ScholarshipContext({
    required this.id,
    required this.title,
    required this.provider,
    required this.fundingType,
    required this.educationLevels,
    required this.eligibleCitizenships,
    required this.hostCountries,
    required this.fieldsOfStudy,
    required this.status,
    required this.requirements,
    required this.benefits,
    required this.sourceUrl,
    this.description,
    this.minGpa,
    this.languageRequirement,
    this.openDate,
    this.deadline,
    this.notes,
  });

  String id;
  String title;
  String provider;
  String? description;
  String fundingType;
  List<String> educationLevels;
  List<String> eligibleCitizenships;
  List<String> hostCountries;
  List<String> fieldsOfStudy;
  double? minGpa;
  String? languageRequirement;

  /// Tanggal ISO 8601 (`YYYY-MM-DD`), opsional.
  String? openDate;

  /// Tanggal ISO 8601 (`YYYY-MM-DD`), opsional.
  String? deadline;

  /// `active` | `closed`
  String status;
  List<RequirementItem> requirements;
  List<String> benefits;
  String sourceUrl;
  String? notes;
}

/// Ringkasan profil mahasiswa (`users/{uid}`). Semua opsional: AI tetap bisa
/// menjawab pertanyaan umum tanpa profil.
class StudentContext {
  StudentContext({
    required this.targetCountries,
    required this.fieldsOfStudy,
    required this.skills,
    this.educationLevel,
    this.citizenship,
    this.gpa,
    this.languageSummary,
    this.experienceYears,
  });

  /// Jenjang yang DITUJU: `undergraduate` | `masters` | `phd`.
  String? educationLevel;

  /// ISO alpha-2, mis. `ID`.
  String? citizenship;
  List<String> targetCountries;
  List<String> fieldsOfStudy;
  double? gpa;

  /// Ringkasan skor bahasa, mis. `IELTS 7.0; JLPT N3`.
  String? languageSummary;
  List<String> skills;
  int? experienceYears;
}

class AskRequest {
  AskRequest({
    required this.question,
    required this.scholarship,
    required this.allowCloud,
    required this.languageCode,
    this.student,
  });

  /// Pertanyaan mahasiswa (maks. 1000 karakter).
  String question;
  ScholarshipContext scholarship;
  StudentContext? student;

  /// `privacy.cloudAiAllowed`. `false` = mode privat: hanya Gemini Nano.
  bool allowCloud;

  /// Bahasa jawaban: `id` atau `en`.
  String languageCode;
}

class AiAnswer {
  AiAnswer({
    required this.text,
    required this.source,
    required this.latencyMs,
    required this.citations,
    this.modelName,
  });

  String text;
  AiSource source;
  String? modelName;
  int latencyMs;

  /// URL sumber resmi yang menjadi dasar jawaban (untuk ditampilkan sebagai sitasi).
  List<String> citations;
}

class ChecklistRequest {
  ChecklistRequest({
    required this.scholarship,
    required this.allowCloud,
    required this.languageCode,
    this.student,
  });

  ScholarshipContext scholarship;
  StudentContext? student;
  bool allowCloud;
  String languageCode;
}

class ChecklistItem {
  ChecklistItem({required this.id, required this.label, this.tip});

  /// Sama dengan `RequirementItem.id` bila item berasal dari syarat resmi.
  String id;
  String label;

  /// Saran singkat cara menyiapkan dokumen ini (dari AI), opsional.
  String? tip;
}

class ChecklistResult {
  ChecklistResult({required this.items, required this.source, this.note});

  List<ChecklistItem> items;

  /// `rules` berarti AI tidak dipakai/gagal dan checklist dibuat dari syarat resmi.
  AiSource source;
  String? note;
}

/// Dipanggil dari Flutter, dijalankan di Kotlin.
@HostApi()
abstract class HybridAiHostApi {
  @async
  AiStatus getStatus();

  /// Mulai mengunduh Gemini Nano. Progres dikirim lewat [HybridAiFlutterApi.onDownloadProgress].
  @async
  void startModelDownload();

  @async
  AiAnswer ask(AskRequest request);

  @async
  ChecklistResult generateChecklist(ChecklistRequest request);
}

/// Dipanggil dari Kotlin, dijalankan di Flutter.
@FlutterApi()
abstract class HybridAiFlutterApi {
  void onDownloadProgress(DownloadProgress progress);
}

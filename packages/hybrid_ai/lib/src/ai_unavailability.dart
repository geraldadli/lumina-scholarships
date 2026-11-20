/// Tombol/aksi yang sebaiknya ditampilkan UI saat AI tidak tersedia.
enum AiUnavailableAction {
  /// Arahkan ke Pengaturan privasi agar user bisa mengizinkan AI cloud.
  openPrivacySettings,

  /// Tampilkan tombol "Unduh model AI" (panggil `HybridAi.downloadModel()`).
  downloadModel,

  /// Gemini Nano sedang diunduh: tampilkan progres (dari `HybridAi.downloadModel()`) dan
  /// teks "tunggu unduhan selesai". Tawarkan "Coba lagi" begitu state-nya `completed`.
  waitForDownload,

  /// Tampilkan tombol "Coba lagi".
  retry,

  /// Minta user mengubah pertanyaan.
  editQuestion,

  /// Tidak ada yang bisa dilakukan user; tampilkan penjelasan saja.
  none,
}

/// Penjelasan tunggal untuk kondisi "AI tidak tersedia" (kotak kuning di diagram alur AI).
///
/// UI cukup menampilkan [title], [message], dan tombol sesuai [action], tanpa
/// perlu mengenal 13 kode error satu per satu. Dapatkan lewat
/// `HybridAiException.unavailability`.
class AiUnavailability {
  const AiUnavailability({required this.title, required this.message, required this.action});

  /// Judul pendek, cocok untuk judul kartu/dialog.
  final String title;

  /// Penjelasan ramah dalam Bahasa Indonesia.
  final String message;

  /// Aksi yang disarankan untuk user.
  final AiUnavailableAction action;

  @override
  String toString() => 'AiUnavailability($title, $action)';
}

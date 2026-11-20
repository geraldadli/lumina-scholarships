import 'package:flutter/services.dart';

import 'ai_unavailability.dart';

/// Kode error dari sisi native. Gunakan untuk memilih tampilan UI yang tepat.
enum HybridAiErrorCode {
  invalidRequest,

  /// Data beasiswa (judul / tautan sumber) kosong, sehingga AI tidak punya sumber untuk dijadikan dasar jawaban.
  noContext,

  /// Mode privat aktif (cloud tidak diizinkan) tetapi perangkat tidak mendukung Gemini Nano.
  privateModeUnavailable,

  /// Perangkat tidak mendukung Gemini Nano.
  onDeviceUnsupported,

  /// Gemini Nano belum diunduh: tawarkan tombol "Unduh model".
  modelNotDownloaded,

  /// Gemini Nano sedang diunduh: tampilkan progres.
  modelDownloading,

  /// Gemini Nano sedang dipakai app lain: coba lagi sebentar lagi.
  busy,
  quotaExceeded,

  /// Token App Check belum terdaftar / tidak valid (jalur cloud).
  appCheckFailed,
  network,

  /// AI cloud terlalu lama menjawab (timeout / `DEADLINE_EXCEEDED`). Bukan masalah koneksi: tawarkan "Coba lagi".
  timeout,
  contentBlocked,
  emptyResponse,

  /// `google-services.json` belum dipasang di app.
  firebaseNotConfigured,
  unknown,
}

/// Error dari paket hybrid_ai, sudah diterjemahkan dari `PlatformException`.
class HybridAiException implements Exception {
  const HybridAiException(this.code, this.rawCode, [this.message]);

  factory HybridAiException.fromPlatform(PlatformException e) =>
      HybridAiException(_codes[e.code] ?? HybridAiErrorCode.unknown, e.code, e.message);

  final HybridAiErrorCode code;

  /// Kode asli dari Kotlin, mis. `PRIVATE_MODE_UNAVAILABLE`.
  final String rawCode;

  /// Pesan teknis (untuk log), bukan untuk ditampilkan ke user.
  final String? message;

  /// Pesan yang ramah untuk ditampilkan ke mahasiswa (Bahasa Indonesia).
  String get userMessage => switch (code) {
        HybridAiErrorCode.privateModeUnavailable =>
          'Mode privat aktif, tetapi HP ini belum mendukung AI di perangkat. Izinkan AI cloud di Pengaturan untuk memakai asisten.',
        HybridAiErrorCode.onDeviceUnsupported => 'HP ini belum mendukung AI di perangkat.',
        HybridAiErrorCode.modelNotDownloaded => 'Model AI di perangkat belum diunduh. Unduh dulu untuk memakai asisten tanpa internet.',
        HybridAiErrorCode.modelDownloading => 'Model AI sedang diunduh. Tunggu sampai unduhan selesai, lalu coba lagi.',
        HybridAiErrorCode.busy => 'AI sedang sibuk. Coba lagi beberapa detik lagi.',
        HybridAiErrorCode.quotaExceeded => 'Batas pemakaian AI tercapai. Coba lagi nanti.',
        HybridAiErrorCode.appCheckFailed => 'Aplikasi belum terverifikasi untuk memakai AI cloud.',
        HybridAiErrorCode.network =>
          'Tidak ada koneksi internet. AI cloud butuh internet; AI di perangkat hanya bisa dipakai bila model Nano sudah siap di HP ini.',
        HybridAiErrorCode.timeout => 'Permintaan ke AI terlalu lama dan melewati batas waktu. Coba lagi.',
        HybridAiErrorCode.contentBlocked => 'Pertanyaan tidak dapat dijawab. Coba ubah kalimatnya.',
        HybridAiErrorCode.emptyResponse => 'AI tidak memberikan jawaban. Coba lagi.',
        HybridAiErrorCode.invalidRequest => 'Pertanyaan tidak valid atau terlalu panjang.',
        HybridAiErrorCode.noContext => 'Data beasiswa belum tersedia atau belum lengkap, jadi AI belum bisa menjawab. Buka dulu detail beasiswanya.',
        HybridAiErrorCode.firebaseNotConfigured => 'Konfigurasi Firebase belum terpasang di aplikasi.',
        HybridAiErrorCode.unknown => 'Asisten AI sedang tidak tersedia. Coba lagi nanti.',
      };

  /// Penjelasan + aksi untuk ditampilkan saat AI tidak tersedia. Satu pintu untuk semua kode error.
  AiUnavailability get unavailability => AiUnavailability(
        title: _title,
        message: userMessage,
        action: _action,
      );

  String get _title => switch (code) {
        HybridAiErrorCode.privateModeUnavailable => 'Mode privat aktif',
        HybridAiErrorCode.onDeviceUnsupported => 'HP belum mendukung AI di perangkat',
        HybridAiErrorCode.modelNotDownloaded => 'Model AI belum diunduh',
        HybridAiErrorCode.modelDownloading => 'Model AI sedang diunduh',
        HybridAiErrorCode.busy => 'AI sedang sibuk',
        HybridAiErrorCode.quotaExceeded => 'Batas pemakaian tercapai',
        HybridAiErrorCode.appCheckFailed => 'Aplikasi belum terverifikasi',
        HybridAiErrorCode.network => 'Tidak ada koneksi',
        HybridAiErrorCode.timeout => 'Permintaan AI habis waktu',
        HybridAiErrorCode.contentBlocked => 'Pertanyaan tidak bisa dijawab',
        HybridAiErrorCode.emptyResponse => 'AI tidak menjawab',
        HybridAiErrorCode.invalidRequest => 'Pertanyaan tidak valid',
        HybridAiErrorCode.noContext => 'Data beasiswa belum tersedia',
        HybridAiErrorCode.firebaseNotConfigured => 'Konfigurasi belum lengkap',
        HybridAiErrorCode.unknown => 'Asisten AI tidak tersedia',
      };

  AiUnavailableAction get _action => switch (code) {
        HybridAiErrorCode.privateModeUnavailable => AiUnavailableAction.openPrivacySettings,
        HybridAiErrorCode.modelNotDownloaded => AiUnavailableAction.downloadModel,
        HybridAiErrorCode.modelDownloading => AiUnavailableAction.waitForDownload,
        HybridAiErrorCode.busy ||
        HybridAiErrorCode.quotaExceeded ||
        HybridAiErrorCode.network ||
        HybridAiErrorCode.timeout ||
        HybridAiErrorCode.emptyResponse ||
        HybridAiErrorCode.unknown =>
          AiUnavailableAction.retry,
        HybridAiErrorCode.contentBlocked || HybridAiErrorCode.invalidRequest => AiUnavailableAction.editQuestion,
        HybridAiErrorCode.noContext ||
        HybridAiErrorCode.onDeviceUnsupported ||
        HybridAiErrorCode.appCheckFailed ||
        HybridAiErrorCode.firebaseNotConfigured =>
          AiUnavailableAction.none,
      };

  static const _codes = <String, HybridAiErrorCode>{
    'INVALID_REQUEST': HybridAiErrorCode.invalidRequest,
    'NO_CONTEXT': HybridAiErrorCode.noContext,
    'PRIVATE_MODE_UNAVAILABLE': HybridAiErrorCode.privateModeUnavailable,
    'ON_DEVICE_UNSUPPORTED': HybridAiErrorCode.onDeviceUnsupported,
    'MODEL_NOT_DOWNLOADED': HybridAiErrorCode.modelNotDownloaded,
    'MODEL_DOWNLOADING': HybridAiErrorCode.modelDownloading,
    'BUSY': HybridAiErrorCode.busy,
    'QUOTA_EXCEEDED': HybridAiErrorCode.quotaExceeded,
    'APP_CHECK_FAILED': HybridAiErrorCode.appCheckFailed,
    'NETWORK': HybridAiErrorCode.network,
    'TIMEOUT': HybridAiErrorCode.timeout,
    'CONTENT_BLOCKED': HybridAiErrorCode.contentBlocked,
    'EMPTY_RESPONSE': HybridAiErrorCode.emptyResponse,
    'FIREBASE_NOT_CONFIGURED': HybridAiErrorCode.firebaseNotConfigured,
  };

  @override
  String toString() => 'HybridAiException($rawCode${message == null ? '' : ': $message'})';
}

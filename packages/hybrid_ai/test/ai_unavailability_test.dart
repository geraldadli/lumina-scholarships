import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_ai/hybrid_ai.dart';

HybridAiException error(HybridAiErrorCode code) => HybridAiException(code, code.name);

void main() {
  group('HybridAiException.unavailability', () {
    test('mode privat tanpa Nano mengarahkan ke Pengaturan privasi', () {
      final u = error(HybridAiErrorCode.privateModeUnavailable).unavailability;
      expect(u.action, AiUnavailableAction.openPrivacySettings);
      expect(u.title, 'Mode privat aktif');
    });

    test('Nano belum diunduh menawarkan unduhan', () {
      expect(error(HybridAiErrorCode.modelNotDownloaded).unavailability.action, AiUnavailableAction.downloadModel);
    });

    test('masalah sementara menawarkan coba lagi', () {
      for (final code in [
        HybridAiErrorCode.network,
        HybridAiErrorCode.timeout,
        HybridAiErrorCode.busy,
        HybridAiErrorCode.quotaExceeded,
        HybridAiErrorCode.emptyResponse,
        HybridAiErrorCode.unknown,
      ]) {
        expect(error(code).unavailability.action, AiUnavailableAction.retry, reason: code.name);
      }
    });

    test('timeout dijelaskan terpisah dari putus koneksi', () {
      final timeout = error(HybridAiErrorCode.timeout).unavailability;
      final network = error(HybridAiErrorCode.network).unavailability;
      expect(timeout.title, 'Permintaan AI habis waktu');
      expect(timeout.message, contains('melewati batas waktu'));
      expect(network.title, 'Tidak ada koneksi');
      expect(network.message, contains('Tidak ada koneksi internet'));
      expect(timeout.message, isNot(network.message));
      expect(timeout.action, AiUnavailableAction.retry);
      expect(network.action, AiUnavailableAction.retry);
    });

    test('Nano masih diunduh: minta user menunggu, bukan langsung coba lagi', () {
      final u = error(HybridAiErrorCode.modelDownloading).unavailability;
      expect(u.action, AiUnavailableAction.waitForDownload);
      expect(u.message, contains('Tunggu sampai unduhan selesai'));
    });

    test('pertanyaan bermasalah meminta user mengubah pertanyaan', () {
      expect(error(HybridAiErrorCode.contentBlocked).unavailability.action, AiUnavailableAction.editQuestion);
      expect(error(HybridAiErrorCode.invalidRequest).unavailability.action, AiUnavailableAction.editQuestion);
    });

    test('tanpa data beasiswa AI tidak menjawab dan hanya menjelaskan', () {
      final u = error(HybridAiErrorCode.noContext).unavailability;
      expect(u.title, 'Data beasiswa belum tersedia');
      expect(u.action, AiUnavailableAction.none);
    });

    test('masalah yang tidak bisa diatasi user hanya dijelaskan', () {
      for (final code in [
        HybridAiErrorCode.onDeviceUnsupported,
        HybridAiErrorCode.appCheckFailed,
        HybridAiErrorCode.firebaseNotConfigured,
      ]) {
        expect(error(code).unavailability.action, AiUnavailableAction.none, reason: code.name);
      }
    });

    test('setiap kode error punya judul dan pesan yang tidak kosong', () {
      for (final code in HybridAiErrorCode.values) {
        final u = error(code).unavailability;
        expect(u.title, isNotEmpty, reason: code.name);
        expect(u.message, isNotEmpty, reason: code.name);
        expect(u.message, error(code).userMessage, reason: code.name);
      }
    });
  });
}

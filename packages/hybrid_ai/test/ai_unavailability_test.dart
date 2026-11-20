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
        HybridAiErrorCode.busy,
        HybridAiErrorCode.quotaExceeded,
        HybridAiErrorCode.modelDownloading,
        HybridAiErrorCode.emptyResponse,
        HybridAiErrorCode.unknown,
      ]) {
        expect(error(code).unavailability.action, AiUnavailableAction.retry, reason: code.name);
      }
    });

    test('pertanyaan bermasalah meminta user mengubah pertanyaan', () {
      expect(error(HybridAiErrorCode.contentBlocked).unavailability.action, AiUnavailableAction.editQuestion);
      expect(error(HybridAiErrorCode.invalidRequest).unavailability.action, AiUnavailableAction.editQuestion);
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

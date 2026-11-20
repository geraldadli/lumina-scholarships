import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_ai/hybrid_ai.dart';

HybridAiException error(HybridAiErrorCode code) => HybridAiException(code, code.name);

void main() {
  group('HybridAiException.unavailability', () {
    test('private mode without Nano points to the privacy settings', () {
      final u = error(HybridAiErrorCode.privateModeUnavailable).unavailability;
      expect(u.action, AiUnavailableAction.openPrivacySettings);
      expect(u.title, 'Private mode is on');
    });

    test('Nano not downloaded offers the download', () {
      expect(error(HybridAiErrorCode.modelNotDownloaded).unavailability.action, AiUnavailableAction.downloadModel);
    });

    test('temporary problems offer "try again"', () {
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

    test('timeout is explained separately from no connection', () {
      final timeout = error(HybridAiErrorCode.timeout).unavailability;
      final network = error(HybridAiErrorCode.network).unavailability;
      expect(timeout.title, 'AI request timed out');
      expect(timeout.message, 'AI request timed out. Try again.');
      expect(network.title, 'No connection');
      expect(network.message, startsWith('No connection.'));
      expect(timeout.message, isNot(network.message));
      expect(timeout.action, AiUnavailableAction.retry);
      expect(network.action, AiUnavailableAction.retry);
    });

    test('Nano still downloading: ask the user to wait instead of retrying right away', () {
      final u = error(HybridAiErrorCode.modelDownloading).unavailability;
      expect(u.action, AiUnavailableAction.waitForDownload);
      expect(u.message, contains('Wait for the download to finish'));
    });

    test('problem questions ask the user to change the question', () {
      expect(error(HybridAiErrorCode.contentBlocked).unavailability.action, AiUnavailableAction.editQuestion);
      expect(error(HybridAiErrorCode.invalidRequest).unavailability.action, AiUnavailableAction.editQuestion);
    });

    test('without scholarship data the AI does not answer and only explains', () {
      final u = error(HybridAiErrorCode.noContext).unavailability;
      expect(u.title, 'Scholarship data unavailable');
      expect(u.action, AiUnavailableAction.none);
    });

    test('problems the user cannot fix are only explained', () {
      for (final code in [
        HybridAiErrorCode.onDeviceUnsupported,
        HybridAiErrorCode.appCheckFailed,
        HybridAiErrorCode.firebaseNotConfigured,
      ]) {
        expect(error(code).unavailability.action, AiUnavailableAction.none, reason: code.name);
      }
    });

    test('every error code has a non-empty title and message', () {
      for (final code in HybridAiErrorCode.values) {
        final u = error(code).unavailability;
        expect(u.title, isNotEmpty, reason: code.name);
        expect(u.message, isNotEmpty, reason: code.name);
        expect(u.message, error(code).userMessage, reason: code.name);
      }
    });
  });
}

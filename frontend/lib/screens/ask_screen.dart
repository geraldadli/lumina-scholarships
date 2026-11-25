import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:material_ui/material_ui.dart';

import '../models/scholarship.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import 'detail_screen.dart';
import 'profile_form.dart';

const _suggestions = ['Am I eligible?', 'What documents do I need?', 'Explain the language requirement'];

/// Ask AI, grounded in one scholarship (hybrid_ai `ask`). Every answer links the official page.
class AskScreen extends StatefulWidget {
  const AskScreen({super.key, required this.scholarshipId, this.initialQuestion});

  final String scholarshipId;
  final String? initialQuestion;

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final _draft = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuestion;
    if (q != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(q));
    }
  }

  @override
  void dispose() {
    _draft.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Scholarship? get _s => AppScope.read(context).byId(widget.scholarshipId);

  Future<void> _send(String text) async {
    final s = _s;
    if (s == null || text.trim().isEmpty) return;
    _draft.clear();
    final future = AppScope.read(context).ask(s, text);
    _scrollToEnd();
    await future;
    _scrollToEnd();
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final s = c.byId(widget.scholarshipId);
    if (s == null) {
      return const Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              LHeader(title: 'Ask AI', border: false),
              EmptyState(
                icon: Icons.search_off_rounded,
                title: 'This listing is no longer available',
                message: 'It was removed from the catalog, so the AI has no official page to answer from.',
              ),
            ],
          ),
        ),
      );
    }
    final t = c.thread(s.id);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LHeader(
              title: 'Ask about: ${s.title}',
              bottom: Row(
                children: [
                  LBadge(c.inferModeLabel),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Answers use only the official scholarship page.', style: ts(12, color: LColors.text2)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  Text('Suggested questions', style: ts(13, weight: FontWeight.w600, color: LColors.text2)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final q in _suggestions)
                        ActionChip(
                          label: Text(q, style: ts(13, weight: FontWeight.w500)),
                          backgroundColor: LColors.white,
                          side: const BorderSide(color: LColors.line),
                          shape: const StadiumBorder(),
                          onPressed: t.thinking ? null : () => _send(q),
                        ),
                    ],
                  ),
                  for (final m in t.messages) ...[
                    const SizedBox(height: 14),
                    m.role == ChatRole.user ? _UserBubble(m.text) : _AiBubble(message: m, scholarship: s),
                  ],
                  if (t.thinking) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: LColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: LColors.line),
                        ),
                        child: Text('Reading the official page…', style: ts(14, color: LColors.text2)),
                      ),
                    ),
                  ],
                  if (t.error != null) ...[
                    const SizedBox(height: 14),
                    _UnavailableCard(scholarship: s, error: t.error!, askedWithCloud: t.askedWithCloud, onEditQuestion: () {
                      _draft.text = t.failedQuestion ?? '';
                      _focus.requestFocus();
                    }),
                  ],
                  const SizedBox(height: 14),
                  Text('Always confirm on the official website.',
                      textAlign: TextAlign.center, style: ts(12, color: LColors.text2)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: LColors.bg,
                border: Border(top: BorderSide(color: LColors.soft)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _draft,
                      focusNode: _focus,
                      maxLength: AppController.maxQuestionLength,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      decoration: lInputDecoration(hint: 'Type your question (max 1000)', counter: ''),
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: LColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: t.thinking ? null : () => _send(_draft.text),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.arrow_upward_rounded, size: 22, color: LColors.bg, semanticLabel: 'Send'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: LColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(text, style: ts(14, color: LColors.bg, height: 1.45)),
          ),
        ),
      );
}

class _AiBubble extends StatelessWidget {
  const _AiBubble({required this.message, required this.scholarship});

  final ChatMessage message;
  final Scholarship scholarship;

  @override
  Widget build(BuildContext context) {
    // The scholarship's own sourceUrl is always shown, so every answer carries an official link
    // even when the model returns no citations.
    final links = <String>{scholarship.sourceUrl, ...message.citations}.where((u) => u.startsWith('https://'));
    final sourceLabel = switch (message.source) {
      AiSource.onDevice => 'Answered on this phone',
      AiSource.cloud => 'Answered with cloud AI',
      _ => null,
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.86),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: LColors.white,
            border: Border.all(color: LColors.line),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              SelectableText(message.text, style: ts(14, height: 1.5)),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final url in links)
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => openOfficialPage(context, url),
                      child: LBadge(hostOf(url), icon: Icons.link_rounded),
                    ),
                ],
              ),
              if (sourceLabel != null) Text(sourceLabel, style: ts(11, color: LColors.text2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// On-device errors that cloud AI would have avoided. `MODEL_DOWNLOADING` is left out: its
/// progress bar and "Try again" fit better than asking to switch to cloud mid-download.
const _onDeviceCodes = {
  HybridAiErrorCode.privateModeUnavailable,
  HybridAiErrorCode.onDeviceUnsupported,
  HybridAiErrorCode.onDeviceUnavailable,
  HybridAiErrorCode.modelNotDownloaded,
};

/// The single "AI unavailable" state, driven by `HybridAiException.unavailability`.
class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({
    required this.scholarship,
    required this.error,
    required this.askedWithCloud,
    required this.onEditQuestion,
  });

  final Scholarship scholarship;
  final HybridAiException error;

  /// Whether cloud AI was allowed when the failed question was asked.
  final bool askedWithCloud;
  final VoidCallback onEditQuestion;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final u = error.unavailability;
    void privacy() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()));
    void retry() => c.retryLast(scholarship);

    // Asks again with cloud AI at once. If the setting then fails to save, the controller's
    // notices say the question was sent and that cloud AI is off again.
    void allowCloudAndRetry() => c.allowCloudAndRetry(scholarship);

    // The question failed on the phone because cloud AI was off when it was asked.
    final onDeviceOnly = !askedWithCloud && _onDeviceCodes.contains(error.code);
    // ...and cloud AI is still off: offer it.
    final cloudOff = onDeviceOnly && !c.cloudAllowed;
    // ...but cloud AI was turned on since (e.g. in Privacy & AI): asking again will work.
    final cloudNowOn = onDeviceOnly && c.cloudAllowed;
    final phoneUnsupported = error.code == HybridAiErrorCode.privateModeUnavailable ||
        error.code == HybridAiErrorCode.onDeviceUnsupported ||
        c.aiStatus?.onDeviceModel == ModelAvailability.unavailable;

    final title = cloudOff
        ? 'Cloud AI is turned off'
        : cloudNowOn
            ? 'Cloud AI is on now'
            : u.title;
    final message = cloudNowOn
        ? 'Cloud AI was off when you asked. Try again to get an answer.'
        : cloudOff && phoneUnsupported
            ? 'This phone does not support on-device AI, so with cloud AI off the assistant cannot answer. '
                'Allow cloud AI to use it.'
            : cloudOff && error.code == HybridAiErrorCode.onDeviceUnavailable
                ? 'On-device AI is not available on this phone right now, and cloud AI is off. '
                    'Allow cloud AI to get an answer, or try again later.'
                : u.message;

    final buttons = <Widget>[
      if (cloudNowOn)
        LButton(label: 'Try again', height: 44, radius: 12, fontSize: 14, onPressed: retry)
      else if (cloudOff) ...[
        LButton(label: 'Allow cloud AI', height: 44, radius: 12, fontSize: 14, onPressed: allowCloudAndRetry),
        if (error.code == HybridAiErrorCode.onDeviceUnavailable)
          LButton(
            label: 'Try again',
            kind: LButtonKind.secondary,
            height: 40,
            radius: 12,
            fontSize: 13,
            onPressed: retry,
          )
        else if (!phoneUnsupported)
          LButton(
            label: 'Download on-device model instead',
            kind: LButtonKind.secondary,
            height: 40,
            radius: 12,
            fontSize: 13,
            onPressed: privacy,
          ),
      ] else
        ...switch (u.action) {
          AiUnavailableAction.openPrivacySettings => [
              LButton(label: 'Open Privacy & AI', height: 44, radius: 12, fontSize: 14, onPressed: privacy),
            ],
          AiUnavailableAction.downloadModel => [
              LButton(
                label: 'Download AI model',
                height: 44,
                radius: 12,
                fontSize: 14,
                onPressed: () {
                  c.startModelDownload();
                  privacy();
                },
              ),
            ],
          AiUnavailableAction.waitForDownload => [
              if (c.downloading) LProgressBar(value: c.downloadFraction ?? 0.05),
              LButton(
                label: 'Try again',
                kind: LButtonKind.secondary,
                height: 44,
                radius: 12,
                fontSize: 14,
                onPressed: c.downloading ? null : () => c.retryLast(scholarship),
              ),
            ],
          AiUnavailableAction.retry => [
              LButton(label: 'Try again', height: 44, radius: 12, fontSize: 14, onPressed: () => c.retryLast(scholarship)),
            ],
          AiUnavailableAction.editQuestion => [
              LButton(
                label: 'Edit question',
                kind: LButtonKind.secondary,
                height: 44,
                radius: 12,
                fontSize: 14,
                onPressed: onEditQuestion,
              ),
            ],
          AiUnavailableAction.none => const <Widget>[],
        },
    ];

    return LCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: LColors.soft, borderRadius: BorderRadius.circular(10)),
                child: Icon(
                  cloudOff
                      ? Icons.cloud_off_rounded
                      : cloudNowOn
                          ? Icons.cloud_done_rounded
                          : Icons.info_outline_rounded,
                  size: 20,
                  color: LColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: ts(15, weight: FontWeight.w700))),
            ],
          ),
          Text(message, style: ts(13, color: LColors.text3, height: 1.45)),
          ...buttons,
          TextButton(
            onPressed: () => openOfficialPage(context, scholarship.sourceUrl),
            child: Text('Read the official page instead', style: ts(13, weight: FontWeight.w600, color: LColors.text2)),
          ),
        ],
      ),
    );
  }
}

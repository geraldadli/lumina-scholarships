import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../main.dart';
import '../theme.dart';

class _Msg {
  _Msg.user(this.text) : fromUser = true, answer = null, error = null;
  _Msg.ai(AiAnswer this.answer) : fromUser = false, text = answer.text, error = null;
  _Msg.error(HybridAiException this.error) : fromUser = false, text = '', answer = null;
  final bool fromUser;
  final String text;
  final AiAnswer? answer;
  final HybridAiException? error;
}

class AskAiScreen extends StatefulWidget {
  const AskAiScreen({super.key, required this.id});
  final String id;
  @override
  State<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends State<AskAiScreen> {
  final _ctrl = TextEditingController();
  final _msgs = <_Msg>[];
  bool _thinking = false;

  static const _suggested = [
    'Am I eligible for this scholarship?',
    'What is the language requirement?',
    'Which documents do I need?',
    'What does the scholarship cover?',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _ask(String q) async {
    q = q.trim();
    if (q.isEmpty || _thinking) return;
    final state = AppScope.of(context);
    final s = state.byId(widget.id);
    _ctrl.clear();
    setState(() {
      _msgs.add(_Msg.user(q));
      _thinking = true;
    });
    try {
      final a = await state.ai.ask(AskRequest(
        question: q,
        scholarship: s.toAiContext(),
        student: state.profile.toAiContext(),
        allowCloud: state.profile.cloudAiAllowed,
        languageCode: 'en',
      ));
      _msgs.add(_Msg.ai(a));
    } on HybridAiException catch (e) {
      _msgs.add(_Msg.error(e));
    } finally {
      if (mounted) setState(() => _thinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).byId(widget.id);
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ask AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(s.title, style: const TextStyle(fontSize: 12, color: LColors.text2)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: LColors.soft, borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Symbols.link, size: 18, color: LColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Answers use only the official scholarship page.',
                      style: TextStyle(fontSize: 13)),
                ),
              ]),
            ),
            if (_msgs.isEmpty) ...[
              const SizedBox(height: 20),
              const Text('Suggested questions', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              for (final q in _suggested)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    onTap: () => _ask(q),
                    child: Text(q, style: const TextStyle(fontSize: 14)),
                  ),
                ),
            ],
            for (final m in _msgs) Padding(padding: const EdgeInsets.only(top: 12), child: _bubble(m)),
            if (_thinking)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Row(children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Reading the official page…', style: TextStyle(color: LColors.text2)),
                ]),
              ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  maxLength: 1000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _ask,
                  decoration: const InputDecoration(hintText: 'Ask about this scholarship', counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: LColors.primary, fixedSize: const Size(50, 50)),
                onPressed: _thinking ? null : () => _ask(_ctrl.text),
                icon: const Icon(Symbols.arrow_upward, color: LColors.bg),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _bubble(_Msg m) {
    if (m.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 290),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: LColors.primary, borderRadius: BorderRadius.circular(16)),
          child: Text(m.text, style: const TextStyle(color: LColors.bg)),
        ),
      );
    }
    if (m.error != null) {
      final u = m.error!.unavailability;
      return LCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Symbols.cloud_off, color: LColors.text2),
            const SizedBox(width: 10),
            Expanded(child: Text(u.title, style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 6),
          Text(u.message, style: const TextStyle(fontSize: 13, color: LColors.text2, height: 1.4)),
          if (u.action == AiUnavailableAction.openPrivacySettings ||
              u.action == AiUnavailableAction.downloadModel ||
              u.action == AiUnavailableAction.waitForDownload) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              onPressed: () => context.push('/edit/3'),
              child: Text(u.action == AiUnavailableAction.openPrivacySettings
                  ? 'Open privacy settings'
                  : 'Download on-device model'),
            ),
          ],
          if (u.action == AiUnavailableAction.retry) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              onPressed: () {
                final last = _msgs.lastWhere((x) => x.fromUser).text;
                setState(() => _msgs.remove(m));
                _ask(last);
              },
              child: const Text('Try again'),
            ),
          ],
        ]),
      );
    }
    final a = m.answer!;
    return LCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a.text, style: const TextStyle(fontSize: 14, height: 1.5)),
        const SizedBox(height: 10),
        Row(children: [
          LTag(switch (a.source) {
            AiSource.onDevice => 'On-device · AI',
            AiSource.cloud => 'Cloud · AI',
            AiSource.rules => 'From official data',
          }),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Always confirm on the official website.',
                style: TextStyle(fontSize: 11, color: LColors.text2)),
          ),
        ]),
      ]),
    );
  }
}

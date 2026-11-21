import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'widgets.dart';

Future<void> openOfficial(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showToast(context, 'Could not open $url');
}

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.id});
  final String id;
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _showChange = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    if (state.hasUpdate(widget.id)) {
      _showChange = true;
      // Contract §3: opening the details marks the update as seen.
      WidgetsBinding.instance.addPostFrameCallback((_) => state.markSeen(widget.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.byId(widget.id);
    final saved = state.isSaved(s.id);
    final m = state.match(s);

    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            child,
          ]),
        );
    Widget bullets(List<String> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final b in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Symbols.check, size: 18, color: LColors.primary)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(b, style: const TextStyle(fontSize: 14, height: 1.45))),
                ]),
              ),
          ],
        );
    Widget fact(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 120, child: Text(k, style: const TextStyle(fontSize: 14, color: LColors.text2))),
            Expanded(child: Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          ]),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scholarship', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: () => state.toggleSaved(s.id),
            icon: Icon(Symbols.bookmark, fill: saved ? 1 : 0),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        Text(s.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.2)),
        const SizedBox(height: 4),
        Text(s.provider, style: const TextStyle(fontSize: 14, color: LColors.text2)),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          LTag(s.fundingLabel),
          LTag(s.levelLabel),
          if (!s.isActive) const LTag('Closed', strong: true),
          if (s.isUrgent) const LTag('Closing soon', strong: true),
          if (!s.isVerified) const LTag('Not yet verified'),
        ]),
        if (_showChange && s.lastChangeSummary != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: LColors.soft, borderRadius: BorderRadius.circular(14)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Symbols.update, color: LColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('What changed', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(s.lastChangeSummary!, style: const TextStyle(fontSize: 13, height: 1.4)),
                ]),
              ),
            ]),
          ),
        ],
        if (s.isActive) ...[
          const SizedBox(height: 16),
          LCard(
            onTap: () => _showMatch(context, m),
            child: Row(children: [
              const Icon(Symbols.auto_awesome, color: LColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(m.eligible ? 'Match with your profile' : 'You may not be eligible',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              MatchBadge(score: m.score, eligible: m.eligible),
              const Icon(Symbols.chevron_right, color: LColors.muted),
            ]),
          ),
        ],
        section('Key facts', LCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            fact('Deadline', formatDate(s.deadline)),
            if (s.openDate != null) fact('Opens', formatDate(s.openDate!)),
            fact('Study in', s.hostLabel),
            if (s.minGpa != null) fact('Minimum GPA', '${s.minGpa} / 4.0'),
            if (s.languageRequirement != null) fact('Language', s.languageRequirement!),
          ]),
        )),
        section('About', Text(s.description, style: const TextStyle(fontSize: 14, height: 1.5))),
        if (s.benefits.isNotEmpty) section('Benefits', bullets(s.benefits)),
        if (s.requirements.isNotEmpty) section('Requirements', bullets([for (final r in s.requirements) r.label])),
        section('Eligible citizenships', Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in s.eligibleCitizenships) LTag(countryName(c)),
        ])),
        section('Fields of study', Text(s.fieldsLabel, style: const TextStyle(fontSize: 14))),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.push('/scholarship/${s.id}/ask'),
              icon: const Icon(Symbols.auto_awesome),
              label: const Text('Ask AI'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                if (!state.isSaved(s.id)) state.toggleSaved(s.id);
                context.push('/scholarship/${s.id}/prepare');
              },
              icon: const Icon(Symbols.checklist),
              label: const Text('Prepare'),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => openOfficial(context, s.sourceUrl),
          icon: const Icon(Symbols.north_east),
          label: const Text('Apply on official website'),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text('Source: ${s.sourceHost}', style: const TextStyle(fontSize: 12, color: LColors.text2)),
        ),
      ]),
    );
  }

  void _showMatch(BuildContext context, MatchResult m) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: LColors.bg,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${(m.score * 100).round()}% match',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(m.eligible ? 'Eligible' : 'Not eligible', style: const TextStyle(color: LColors.text2)),
            const SizedBox(height: 12),
            for (final r in m.reasons)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  switch (r.result) {
                    CriterionResult.met => Symbols.check_circle,
                    CriterionResult.notMet => Symbols.cancel,
                    CriterionResult.unknown => Symbols.help,
                  },
                  fill: 1,
                  color: r.result == CriterionResult.met ? LColors.primary : LColors.muted,
                ),
                title: Text(r.message, style: const TextStyle(fontSize: 14)),
              ),
            if (m.reasons.any((r) => r.result == CriterionResult.unknown)) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/edit/1');
                },
                child: const Text('Fill in missing profile info'),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

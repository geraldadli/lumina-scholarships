import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/scholarship.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/scholarship_card.dart';
import 'ask_screen.dart';
import 'prepare_screen.dart';
import 'profile_form.dart';

Future<void> openOfficialPage(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final ok = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showToast(context, 'Could not open $url', icon: Icons.error_outline_rounded);
}

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.scholarshipId});

  final String scholarshipId;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  /// Captured on open, so "What changed" stays visible after `lastSeenUpdatedAt` is rewritten.
  bool _showUpdate = false;

  @override
  void initState() {
    super.initState();
    final c = AppScope.read(context);
    final s = c.byId(widget.scholarshipId);
    if (s != null && c.hasUpdate(s)) {
      _showUpdate = true;
      c.markSeen(s).catchError((Object e) => debugPrint('Lumina: markSeen failed: $e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final s = c.byId(widget.scholarshipId);
    if (s == null) {
      return const Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              LHeader(title: 'Scholarship', border: false),
              EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Scholarship not found',
                message: 'It may have been removed from the catalog.',
              ),
            ],
          ),
        ),
      );
    }
    final now = c.now;
    final m = c.matchFor(s);
    final checked = s.lastCheckedAt ?? s.lastVerifiedAt;

    final facts = <(String, String)>[
      ('Deadline', s.deadline == null ? 'Not announced' : formatDate(s.deadline!)),
      ('Opens', s.openDate == null ? '–' : formatDate(s.openDate!)),
      ('Funding', fundingLabel(s.fundingType)),
      ('Level', s.levelsLabel.isEmpty ? '–' : s.levelsLabel),
      ('Host country', s.hostLabel),
      ('Min GPA', s.minGpa == null ? 'None' : '${s.minGpa!.toStringAsFixed(2)} / 4.0'),
      ('Language', s.languageRequirement ?? 'Not stated'),
      ('Status', s.isClosedAt(now) ? 'Closed' : (s.isUpcomingAt(now) ? 'Opening soon' : 'Open')),
    ];
    final cits = s.eligibleCitizenships;
    const maxCit = 6;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LHeader(
              title: 'Scholarship',
              border: false,
              actions: [
                LIconButton(
                  icon: Icons.ios_share_rounded,
                  iconSize: 20,
                  tooltip: 'Copy link',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: s.sourceUrl));
                    if (context.mounted) showToast(context, 'Link copied');
                  },
                ),
                BookmarkButton(scholarship: s, size: 40),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Text(s.title, style: ts(26, weight: FontWeight.w700, spacing: -0.52, height: 1.15)),
                  const SizedBox(height: 10),
                  Text(s.provider, style: ts(14, color: LColors.text2)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...scholarshipTags(s, now),
                      LTag(
                        s.verified ? 'Verified' : 'Not yet verified',
                        icon: s.verified ? Icons.verified_rounded : Icons.help_outline_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  LButton(
                    label: m.eligible ? 'Match ${(m.score * 100).round()}% · see why' : 'Not eligible · see why',
                    kind: LButtonKind.soft,
                    trailingIcon: Icons.chevron_right_rounded,
                    onPressed: () => showLSheet<void>(
                      context,
                      (_) => AppScope(controller: c, child: MatchSheet(scholarship: s)),
                    ),
                  ),
                  if (_showUpdate && s.lastChangeSummary != null) ...[
                    const SizedBox(height: 22),
                    LCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.update_rounded, size: 22, color: LColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 3,
                              children: [
                                Text('What changed', style: ts(14, weight: FontWeight.w700)),
                                Text(
                                  '${s.lastChangeSummary} Check the official page to confirm.',
                                  style: ts(13, color: LColors.text3, height: 1.45),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text('Key facts', style: ts(17, weight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, box) {
                      final w = (box.maxWidth - 8) / 2;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (k, v) in facts)
                            SizedBox(
                              width: w,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: LColors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: LColors.line),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 3,
                                  children: [
                                    Text(k, style: ts(12, color: LColors.text2)),
                                    Text(v, style: ts(15, weight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (s.description != null && s.description!.isNotEmpty)
                    _Block(
                      title: 'About',
                      child: Text(s.description!, style: ts(14, color: LColors.text3, height: 1.55)),
                    ),
                  if (s.benefits.isNotEmpty)
                    _Block(
                      title: 'Benefits',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 8,
                        children: [
                          for (final b in s.benefits)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_rounded, size: 18, color: LColors.primary),
                                const SizedBox(width: 10),
                                Expanded(child: Text(b, style: ts(14, color: LColors.text3, height: 1.4))),
                              ],
                            ),
                        ],
                      ),
                    ),
                  if (s.requirements.isNotEmpty)
                    _Block(
                      title: 'Requirements',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 8,
                        children: [
                          for (final r in s.requirements)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(top: 7),
                                  decoration: const BoxDecoration(color: LColors.muted, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(r.label, style: ts(14, color: LColors.text3, height: 1.4))),
                              ],
                            ),
                        ],
                      ),
                    ),
                  if (cits.isNotEmpty)
                    _Block(
                      title: 'Eligible citizenships',
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in cits.take(maxCit)) _Pill(countryName(c) == 'Any country' ? 'All countries' : countryName(c)),
                          if (cits.length > maxCit) _Pill('+ ${cits.length - maxCit} more', muted: true),
                        ],
                      ),
                    ),
                  _Block(
                    title: 'Fields of study',
                    child: Text(s.fieldsLabel, style: ts(14, color: LColors.text3)),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Source: ${hostOf(s.sourceUrl)}'
                    '${checked == null ? '' : ' · Last checked ${timeAgo(checked, now: now)}'}'
                    '. Always confirm on the official website.',
                    style: ts(12, color: LColors.text2, height: 1.45),
                  ),
                ],
              ),
            ),
            LFooter(children: [
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: LButton(
                      label: 'Ask AI',
                      icon: Icons.auto_awesome_rounded,
                      kind: LButtonKind.secondary,
                      height: 46,
                      radius: 12,
                      fontSize: 14,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => AskScreen(scholarshipId: s.id)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LButton(
                      label: 'Prepare',
                      icon: Icons.checklist_rounded,
                      kind: LButtonKind.secondary,
                      height: 46,
                      radius: 12,
                      fontSize: 14,
                      onPressed: () => openPrepare(context, s),
                    ),
                  ),
                ],
              ),
              LButton(
                label: 'Apply on official website',
                trailingIcon: Icons.north_east_rounded,
                onPressed: () => openOfficialPage(context, s.sourceUrl),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: ts(17, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, {this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: muted ? LColors.bg : LColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: LColors.line),
        ),
        child: Text(label, style: ts(13, color: muted ? LColors.text2 : LColors.ink)),
      );
}

/// "Match 82% · see why": the MatchScorer reasons, one row per criterion.
class MatchSheet extends StatelessWidget {
  const MatchSheet({super.key, required this.scholarship});

  final Scholarship scholarship;

  static const _labels = {
    MatchCriterion.citizenship: 'Citizenship',
    MatchCriterion.educationLevel: 'Education level',
    MatchCriterion.gpa: 'GPA',
    MatchCriterion.fieldOfStudy: 'Field of study',
    MatchCriterion.hostCountry: 'Host country',
    MatchCriterion.status: 'Status',
  };

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final m = c.matchFor(scholarship);
    final pct = (m.score * 100).round();
    final hasUnknown = m.reasons.any((r) => r.result == CriterionResult.unknown);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('$pct%', style: ts(44, weight: FontWeight.w700, spacing: -1.3)),
              const SizedBox(width: 12),
              LBadge(m.eligible ? 'Eligible' : 'Not eligible'),
            ],
          ),
          Text('Match with your profile', style: ts(14, color: LColors.text2)),
          const SizedBox(height: 12),
          for (final r in m.reasons)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: LColors.soft))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    switch (r.result) {
                      CriterionResult.met => Icons.check_circle_rounded,
                      CriterionResult.notMet => Icons.cancel_outlined,
                      CriterionResult.unknown => Icons.radio_button_unchecked_rounded,
                    },
                    size: 22,
                    color: r.result == CriterionResult.met ? LColors.primary : LColors.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(_labels[r.criterion] ?? r.criterion.name, style: ts(15, weight: FontWeight.w600)),
                        Text(r.message, style: ts(13, color: LColors.text2, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (hasUnknown) ...[
            LButton(
              label: 'Fill in missing profile info',
              height: 48,
              radius: 12,
              onPressed: () {
                final nav = Navigator.of(context)..pop();
                nav.push(MaterialPageRoute<void>(builder: (_) => const EditPreferencesScreen()));
              },
            ),
            const SizedBox(height: 8),
          ],
          LButton(
            label: 'Ask AI to explain',
            kind: LButtonKind.secondary,
            height: 48,
            radius: 12,
            onPressed: () {
              final nav = Navigator.of(context)..pop();
              nav.push(MaterialPageRoute<void>(
                builder: (_) => AskScreen(
                  scholarshipId: scholarship.id,
                  initialQuestion: 'Why is my match $pct%? Which requirements do I meet or miss?',
                ),
              ));
            },
          ),
        ],
      ),
    );
  }
}

void openPrepare(BuildContext context, Scholarship s) {
  // A failure is reported by the controller's notices (shown from the app root).
  unawaited(AppScope.read(context).startPreparing(s));
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PrepareScreen(scholarshipId: s.id)));
}

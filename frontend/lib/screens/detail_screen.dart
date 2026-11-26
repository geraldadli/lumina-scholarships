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
import '../widgets/layout.dart';
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

    // Only facts that are known: an empty row is noise.
    final facts = <(IconData, String, String)>[
      (Icons.event_outlined, 'Deadline', s.deadline == null ? 'Not announced' : formatDate(s.deadline!)),
      if (s.openDate != null) (Icons.event_available_outlined, 'Opens', formatDate(s.openDate!)),
      (
        Icons.timelapse_rounded,
        'Status',
        s.isClosedAt(now) ? 'Closed' : (s.isUpcomingAt(now) ? 'Opening soon' : 'Open')
      ),
      (Icons.payments_outlined, 'Funding', fundingLabel(s.fundingType)),
      if (s.levelsLabel.isNotEmpty) (Icons.school_outlined, 'Level', s.levelsLabel),
      (Icons.place_outlined, 'Host country', s.hostLabel),
      (Icons.grade_outlined, 'Minimum GPA', s.minGpa == null ? 'None' : '${s.minGpa!.toStringAsFixed(2)} / 4.0'),
      (Icons.translate_rounded, 'Language', s.languageRequirement ?? 'Not stated'),
    ];
    final cits = s.eligibleCitizenships;
    const maxCit = 6;
    final gap = L.s(28);

    final header = <Widget>[
      Text(s.title, style: ts(26, weight: FontWeight.w700, spacing: -0.52, height: 1.2)),
      const SizedBox(height: 8),
      Text(s.provider, style: ts(15, color: LColors.text2, height: 1.4)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (s.isClosedAt(now)) const LTag('Closed'),
          if (s.isUrgentAt(now)) const LTag('Closing soon', strong: true),
          LTag(
            s.verified ? 'Verified' : 'Not yet verified',
            icon: s.verified ? Icons.verified_rounded : Icons.help_outline_rounded,
          ),
        ],
      ),
    ];

    final match = LButton(
      label: m.eligible ? '${(m.score * 100).round()}% match · see why' : 'Not eligible · see why',
      kind: LButtonKind.soft,
      icon: m.eligible ? Icons.star_rounded : Icons.block_rounded,
      trailingIcon: Icons.chevron_right_rounded,
      onPressed: () => showLSheet<void>(
        context,
        (_) => AppScope(controller: c, child: MatchSheet(scholarship: s)),
      ),
    );

    final keyFacts = <Widget>[
      Text('Key facts', style: ts(19, weight: FontWeight.w700)),
      const SizedBox(height: 10),
      LCard(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            for (var i = 0; i < facts.length; i++)
              _Fact(icon: facts[i].$1, label: facts[i].$2, value: facts[i].$3, last: i == facts.length - 1),
          ],
        ),
      ),
    ];

    final update = _showUpdate && s.lastChangeSummary != null
        ? LCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.update_rounded, size: 22, color: LColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text('What changed', style: ts(15, weight: FontWeight.w700)),
                      Text(
                        '${s.lastChangeSummary} Check the official page to confirm.',
                        style: ts(14, color: LColors.text3, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : null;

    final body = <Widget>[
      if (s.description != null && s.description!.isNotEmpty)
        _Block(
          title: 'About',
          child: Text(s.description!, style: ts(15, color: LColors.text3, height: 1.6)),
        ),
      if (s.benefits.isNotEmpty)
        _Block(
          title: 'Benefits',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              for (final b in s.benefits)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_rounded, size: 20, color: LColors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(b, style: ts(15, color: LColors.text3, height: 1.45))),
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
            spacing: 10,
            children: [
              for (final r in s.requirements)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 8, left: 7, right: 7),
                      decoration: BoxDecoration(color: LColors.muted, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(r.label, style: ts(15, color: LColors.text3, height: 1.45))),
                  ],
                ),
            ],
          ),
        ),
      if (cits.isNotEmpty)
        _Block(
          title: 'Eligible citizenships',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cits.take(maxCit))
                _Pill(countryName(c) == 'Any country' ? 'All countries' : countryName(c)),
              if (cits.length > maxCit) _Pill('+ ${cits.length - maxCit} more', muted: true),
            ],
          ),
        ),
      _Block(
        title: 'Fields of study',
        child: Text(s.fieldsLabel, style: ts(15, color: LColors.text3, height: 1.5)),
      ),
      SizedBox(height: gap),
      Text(
        'Source: ${hostOf(s.sourceUrl)}'
        '${checked == null ? '' : ' · Last checked ${timeAgo(checked, now: now)}'}'
        '. Always confirm on the official website.',
        style: ts(13, color: LColors.text2, height: 1.5),
      ),
    ];

    final apply = LButton(
      // Applications are over, but the official page is still the source of truth.
      label: s.isClosedAt(now) ? 'View official source' : 'Apply on official website',
      trailingIcon: Icons.north_east_rounded,
      onPressed: () => openOfficialPage(context, s.sourceUrl),
    );
    final helpers = Row(
      spacing: 8,
      children: [
        Expanded(
          child: LButton(
            label: 'Ask AI',
            icon: Icons.auto_awesome_rounded,
            kind: LButtonKind.secondary,
            height: 48,
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
            height: 48,
            radius: 12,
            fontSize: 14,
            onPressed: () => openPrepare(context, s),
          ),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final twoColumns = box.maxWidth >= LBreak.twoColumn;
            final maxWidth = twoColumns ? LBreak.wide - 80 : LBreak.reading;
            return Column(
              children: [
                LHeader(
                  title: 'Scholarship',
                  border: false,
                  maxWidth: maxWidth,
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
                    BookmarkButton(scholarship: s),
                  ],
                ),
                Expanded(
                  child: Gutter(
                    maxWidth: maxWidth,
                    builder: (context, side) {
                      if (!twoColumns) {
                        return ListView(
                          padding: EdgeInsets.fromLTRB(side, 4, side, 28),
                          children: [
                            ...header,
                            SizedBox(height: gap),
                            match,
                            if (update != null) ...[SizedBox(height: gap), update],
                            SizedBox(height: gap),
                            ...keyFacts,
                            ...body,
                          ],
                        );
                      }
                      // Reading on the left; match, facts and actions stay visible on the right.
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(side, 12, 20, 32),
                              children: [
                                ...header,
                                if (update != null) ...[SizedBox(height: gap), update],
                                ...body,
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 360 + side,
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(20, 12, side, 32),
                              children: [
                                match,
                                const SizedBox(height: 10),
                                apply,
                                const SizedBox(height: 8),
                                helpers,
                                SizedBox(height: gap),
                                ...keyFacts,
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (!twoColumns) LFooter(children: [helpers, apply]),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One row of "Key facts": what it is on the left, the answer beside it.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value, required this.last});

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(vertical: L.s(13)),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: LColors.soft)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: LColors.muted),
            const SizedBox(width: 10),
            Expanded(flex: 4, child: Text(label, style: ts(14, color: LColors.text2, height: 1.4))),
            const SizedBox(width: 10),
            Expanded(flex: 5, child: Text(value, style: ts(15, weight: FontWeight.w600, height: 1.35))),
          ],
        ),
      );
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: L.s(28)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: ts(19, weight: FontWeight.w700)),
            const SizedBox(height: 10),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: muted ? LColors.bg : LColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: LColors.line),
        ),
        child: Text(label, style: ts(14, color: muted ? LColors.text2 : LColors.ink)),
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
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: LColors.soft))),
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

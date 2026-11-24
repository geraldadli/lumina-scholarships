import 'package:material_ui/material_ui.dart';

import '../models/scholarship.dart';
import '../screens/detail_screen.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/format.dart';
import 'common.dart';

/// Tags shown on cards and the detail header: funding, levels, host, Urgent / Closed.
List<Widget> scholarshipTags(Scholarship s, DateTime now) => [
      if (s.isClosedAt(now)) const LTag('Closed'),
      LTag(fundingLabel(s.fundingType)),
      for (final l in s.educationLevels) LTag(levelLabel(l)),
      for (final c in s.hostCountries.take(2)) LTag(countryName(c)),
      if (s.hostCountries.length > 2) LTag('+${s.hostCountries.length - 2}'),
      if (s.isUrgentAt(now)) const LTag('Urgent', strong: true),
    ];

/// "Deadline: 15 Feb · 86 days", "Opens: 1 Dec", or "Closed: 3 Nov".
String deadlineLine(Scholarship s, DateTime now) {
  if (s.isUpcomingAt(now)) return 'Opens: ${formatShortDate(s.openDate!)}';
  if (s.deadline == null) return 'Deadline: not announced';
  if (s.isClosedAt(now)) return 'Closed: ${formatShortDate(s.deadline!)}';
  final d = s.daysLeftAt(now) ?? 0;
  return 'Deadline: ${formatShortDate(s.deadline!)} · ${plural(d, 'day')}';
}

/// A failed write is reported by the controller's notices (shown from the app root).
void toggleSaveWithToast(BuildContext context, Scholarship s) => showToast(context, AppScope.read(context).toggleSave(s));

void openScholarship(BuildContext context, Scholarship s) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DetailScreen(scholarshipId: s.id)));

class BookmarkButton extends StatelessWidget {
  const BookmarkButton({super.key, required this.scholarship, this.size = 38});

  final Scholarship scholarship;
  final double size;

  @override
  Widget build(BuildContext context) {
    final saved = AppScope.of(context).isSaved(scholarship.id);
    return LIconButton(
      icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      tooltip: saved ? 'Remove from saved' : 'Save',
      size: size,
      iconSize: 20,
      color: LColors.primary,
      background: size < 40 ? LColors.bg : LColors.white,
      onPressed: () => toggleSaveWithToast(context, scholarship),
    );
  }
}

class VerificationLine extends StatelessWidget {
  const VerificationLine({super.key, required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(verified ? Icons.verified_rounded : Icons.help_outline_rounded, size: 16, color: LColors.text2),
          const SizedBox(width: 4),
          Text(verified ? 'Verified' : 'Not yet verified', style: ts(12, color: LColors.text2)),
        ],
      );
}

/// The list card from Home and Browse.
class ScholarshipCard extends StatelessWidget {
  const ScholarshipCard({super.key, required this.scholarship});

  final Scholarship scholarship;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final s = scholarship;
    final now = c.now;
    return Opacity(
      opacity: s.isClosedAt(now) ? 0.55 : 1,
      child: LCard(
        onTap: () => openScholarship(context, s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, style: ts(16, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        s.provider,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(13, color: LColors.text2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                BookmarkButton(scholarship: s),
              ],
            ),
            Wrap(spacing: 6, runSpacing: 6, children: scholarshipTags(s, now)),
            Row(
              children: [
                Expanded(child: Text(deadlineLine(s, now), style: ts(13))),
                const SizedBox(width: 8),
                MatchBadge(scholarship: s),
              ],
            ),
            VerificationLine(verified: s.verified),
          ],
        ),
      ),
    );
  }
}

class MatchBadge extends StatelessWidget {
  const MatchBadge({super.key, required this.scholarship});

  final Scholarship scholarship;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final m = c.matchFor(scholarship);
    final pct = (m.score * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: LColors.soft, borderRadius: BorderRadius.circular(6)),
      child: Text(
        m.eligible ? 'Match $pct%' : 'Not eligible',
        style: ts(13, weight: FontWeight.w700),
      ),
    );
  }
}

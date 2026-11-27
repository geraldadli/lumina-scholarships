import 'package:material_ui/material_ui.dart';

import '../models/scholarship.dart';
import '../screens/detail_screen.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/format.dart';
import 'common.dart';

/// "Deadline: 15 Feb · 86 days left", "Opens: 1 Dec", or "Closed: 3 Nov".
String deadlineLine(Scholarship s, DateTime now) {
  if (s.isUpcomingAt(now)) return 'Opens: ${formatShortDate(s.openDate!)}';
  if (s.deadline == null) return 'Deadline: not announced';
  if (s.isClosedAt(now)) return 'Closed: ${formatShortDate(s.deadline!)}';
  final d = s.daysLeftAt(now) ?? 0;
  return 'Deadline: ${formatShortDate(s.deadline!)} · ${plural(d, 'day')} left';
}

/// A failed write is reported by the controller's notices (shown from the app root).
void toggleSaveWithToast(BuildContext context, Scholarship s) => showToast(context, AppScope.read(context).toggleSave(s));

void openScholarship(BuildContext context, Scholarship s) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DetailScreen(scholarshipId: s.id)));

class BookmarkButton extends StatelessWidget {
  const BookmarkButton({super.key, required this.scholarship, this.size = 44});

  final Scholarship scholarship;
  final double size;

  @override
  Widget build(BuildContext context) {
    final saved = AppScope.of(context).isSaved(scholarship.id);
    return LIconButton(
      icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      tooltip: saved ? 'Remove from saved' : 'Save',
      size: size,
      iconSize: 22,
      color: LColors.primary,
      background: saved ? LColors.soft : LColors.white,
      onPressed: () => toggleSaveWithToast(context, scholarship),
    );
  }
}

/// An icon and one fact about a scholarship, e.g. the deadline.
class InfoLine extends StatelessWidget {
  const InfoLine({super.key, required this.icon, required this.text, this.strong = false});

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: LColors.muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: ts(14, weight: strong ? FontWeight.w600 : FontWeight.w400, color: LColors.text3, height: 1.4),
            ),
          ),
        ],
      );
}

/// "Fully funded · Masters"
String fundingAndLevels(Scholarship s) =>
    [fundingLabel(s.fundingType), if (s.levelsLabel.isNotEmpty) s.levelsLabel].join(' · ');

/// "United States", or "Japan, Germany +3 more".
String hostSummary(Scholarship s) {
  final names = s.hostCountries.map(countryName).toList();
  if (names.isEmpty) return 'Host country not stated';
  if (names.length <= 2) return names.join(', ');
  return '${names.take(2).join(', ')} +${names.length - 2} more';
}

class VerificationLine extends StatelessWidget {
  const VerificationLine({super.key, required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(verified ? Icons.verified_rounded : Icons.help_outline_rounded, size: 17, color: LColors.text2),
          const SizedBox(width: 5),
          Flexible(child: Text(verified ? 'Verified' : 'Not yet verified', style: ts(13, color: LColors.text2))),
        ],
      );
}

/// The list card from Home and Browse: name first, then three facts, then the match.
class ScholarshipCard extends StatelessWidget {
  const ScholarshipCard({super.key, required this.scholarship});

  final Scholarship scholarship;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final s = scholarship;
    final now = c.now;
    final closed = s.isClosedAt(now);
    final urgent = s.isUrgentAt(now);
    return Opacity(
      opacity: closed ? 0.65 : 1,
      child: LCard(
        onTap: () => openScholarship(context, s),
        // In a grid, cards in a row are equally tall; this keeps their footers aligned.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          Text(s.title, style: ts(17, weight: FontWeight.w700, height: 1.3)),
                          Text(
                            s.provider,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ts(14, color: LColors.text2, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    BookmarkButton(scholarship: s),
                  ],
                ),
            SizedBox(height: L.s(14)),
            InfoLine(icon: Icons.school_outlined, text: fundingAndLevels(s)),
            SizedBox(height: L.s(8)),
            InfoLine(icon: Icons.place_outlined, text: hostSummary(s)),
            SizedBox(height: L.s(8)),
            InfoLine(icon: Icons.event_outlined, text: deadlineLine(s, now), strong: true),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: L.s(14)),
                Divider(height: 1, color: LColors.soft),
                SizedBox(height: L.s(12)),
                // "Verified" sits at the right, and drops to its own line when there is no room.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        MatchBadge(scholarship: s),
                        if (closed) const LTag('Closed'),
                        if (urgent) const LTag('Closing soon', strong: true),
                      ],
                    ),
                    VerificationLine(verified: s.verified),
                  ],
                ),
              ],
            ),
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
    return LBadge(
      m.eligible ? '$pct% match' : 'Not eligible',
      icon: m.eligible ? Icons.star_rounded : Icons.block_rounded,
    );
  }
}

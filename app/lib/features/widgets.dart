import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';

/// Scholarship list card (prototype browse / home rows).
class ScholarshipCard extends StatelessWidget {
  const ScholarshipCard(this.s, {super.key});
  final Scholarship s;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final m = state.match(s);
    final saved = state.isSaved(s.id);
    return LCard(
      onTap: () => context.push('/scholarship/${s.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(s.provider,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: LColors.text2)),
            ]),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              state.toggleSaved(s.id);
              showToast(context, saved ? 'Removed from saved' : 'Saved');
            },
            icon: Icon(Symbols.bookmark, fill: saved ? 1 : 0, color: LColors.primary),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          LTag(s.fundingType == 'full' ? 'Full' : 'Partial'),
          LTag(s.levelLabel),
          LTag(s.hostLabel),
          if (!s.isVerified) const LTag('Not yet verified'),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Symbols.event, size: 16, color: s.isUrgent ? LColors.primary : LColors.text2),
          const SizedBox(width: 6),
          Expanded(child: DeadlineText(s)),
          if (s.isActive) MatchBadge(score: m.score, eligible: m.eligible),
        ]),
      ]),
    );
  }
}

class DeadlineText extends StatelessWidget {
  const DeadlineText(this.s, {super.key});
  final Scholarship s;
  @override
  Widget build(BuildContext context) {
    final String text;
    if (!s.isActive) {
      text = 'Closed · ${formatDate(s.deadline)}';
    } else if (s.opensSoon) {
      text = 'Opens ${formatDate(s.openDate!)}';
    } else {
      final d = s.daysLeft;
      text = '${d <= 0 ? 'Closes today' : '$d days left'} · ${formatDate(s.deadline)}';
    }
    return Text(text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: s.isUrgent ? FontWeight.w700 : FontWeight.w500,
          color: s.isUrgent ? LColors.ink : LColors.text2,
        ));
  }
}

class MatchBadge extends StatelessWidget {
  const MatchBadge({super.key, required this.score, required this.eligible});
  final double score;
  final bool eligible;
  @override
  Widget build(BuildContext context) {
    final good = eligible && score >= AppScope.of(context).minMatchScore;
    return LTag('${(score * 100).round()}% match', strong: good);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action, this.onAction});
  final IconData icon;
  final String title, body;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: LColors.muted),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: LColors.text2, height: 1.45)),
          if (action != null) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              child: Text(action!, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ]),
      );
}

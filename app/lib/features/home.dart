import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../main.dart';
import '../theme.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.profile;
    final updated = state.saved.keys.where(state.hasUpdate).map(state.byId).toList();
    final top = [...state.active]..sort((a, b) => state.match(b).score.compareTo(state.match(a).score));
    final name = p.displayName.isEmpty ? 'there' : p.displayName.split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
          Row(children: [
            Expanded(child: Text('Hi, $name', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700))),
            IconButton(onPressed: () => context.go('/saved'), icon: const Icon(Symbols.notifications)),
          ]),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.go('/browse'),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: LColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LColors.line),
              ),
              child: const Row(children: [
                Icon(Symbols.search, color: LColors.text2),
                SizedBox(width: 10),
                Text('Search scholarships', style: TextStyle(color: LColors.muted, fontSize: 15)),
              ]),
            ),
          ),
          if (p.completeness < 1) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: LColors.soft, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Complete your profile for better matches',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: p.completeness, minHeight: 6, color: LColors.primary, backgroundColor: LColors.white),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/edit/1'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  child: const Text('Complete profile', style: TextStyle(fontSize: 14)),
                ),
              ]),
            ),
          ],
          if (updated.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Updates on saved', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final s in updated)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LCard(
                  onTap: () => context.push('/scholarship/${s.id}'),
                  child: Row(children: [
                    const Icon(Symbols.update, color: LColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(s.lastChangeSummary!, style: const TextStyle(fontSize: 13, color: LColors.text2)),
                      ]),
                    ),
                    const Icon(Symbols.chevron_right, color: LColors.muted),
                  ]),
                ),
              ),
          ],
          const SizedBox(height: 24),
          Row(children: [
            const Expanded(child: Text('Top matches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            TextButton(onPressed: () => context.go('/browse'), child: const Text('See all')),
          ]),
          const SizedBox(height: 6),
          if (top.isEmpty)
            const EmptyState(
              icon: Symbols.event_busy,
              title: 'No open scholarships right now',
              body: 'Closed programmes are still listed in Browse so you can prepare for the next intake.',
            ),
          for (final s in top.take(3))
            Padding(padding: const EdgeInsets.only(bottom: 12), child: ScholarshipCard(s)),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../main.dart';
import '../theme.dart';
import 'widgets.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  String _tab = 'all';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = state.saved.values.where((x) => _tab == 'all' || x.status == _tab).toList()
      ..sort((a, b) => state.byId(a.scholarshipId).deadline.compareTo(state.byId(b.scholarshipId).deadline));

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
          const Text('Saved', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final t in const ['all', 'saved', 'preparing', 'applied'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: LChip('${t[0].toUpperCase()}${t.substring(1)}',
                      selected: _tab == t, onTap: () => setState(() => _tab = t)),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            EmptyState(
              icon: Symbols.bookmarks,
              title: state.saved.isEmpty ? 'Nothing saved yet' : 'Nothing here',
              body: 'Bookmark scholarships to track deadlines and prepare your application.',
              action: 'Browse scholarships',
              onAction: () => context.go('/browse'),
            ),
          for (final x in items) ...[
            Builder(builder: (context) {
              final s = state.byId(x.scholarshipId);
              final done = x.checklist.where((c) => c.done).length;
              return LCard(
                onTap: () => context.push('/scholarship/${s.id}'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(s.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                    if (state.hasUpdate(s.id)) const LTag('Updated', strong: true),
                  ]),
                  const SizedBox(height: 6),
                  DeadlineText(s),
                  const SizedBox(height: 12),
                  Row(children: [
                    LTag(switch (x.status) { 'preparing' => 'Preparing', 'applied' => 'Applied', _ => 'Saved' }),
                    if (x.checklist.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('Checklist $done/${x.checklist.length}',
                          style: const TextStyle(fontSize: 13, color: LColors.text2)),
                    ],
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => context.push('/scholarship/${s.id}/prepare'),
                      icon: const Icon(Symbols.checklist, size: 18),
                      label: const Text('Prepare'),
                    ),
                  ]),
                ]),
              );
            }),
            const SizedBox(height: 12),
          ],
        ]),
      ),
    );
  }
}

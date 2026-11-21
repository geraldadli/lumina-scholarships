import 'package:material_ui/material_ui.dart';

import '../models/saved_scholarship.dart';
import '../models/scholarship.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/scholarship_card.dart';
import 'detail_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  String? _menuOpenFor;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final seg = c.savedSegment;
    int count(String status) => c.saved.values.where((v) => v.status == status).length;
    final inSegment = [for (final sv in c.saved.values) if (sv.status == seg) sv];
    final entries = [
      for (final sv in inSegment)
        if (c.byId(sv.scholarshipId) case final s?) (s: s, sv: sv),
    ]..sort((a, b) => (a.s.deadline ?? DateTime(9999)).compareTo(b.s.deadline ?? DateTime(9999)));
    // Saved, but withdrawn from the catalog. Only judged once the live catalog has loaded.
    final gone = c.catalogReady ? [for (final sv in inSegment) if (c.byId(sv.scholarshipId) == null) sv] : const <SavedScholarship>[];
    final total = entries.length + gone.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Text('Saved', style: ts(28, weight: FontWeight.w700, spacing: -0.56)),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: LColors.soft, borderRadius: BorderRadius.circular(13)),
                child: Row(
                  spacing: 4,
                  children: [
                    for (final st in savedStatuses)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _menuOpenFor = null);
                            c.setSavedSegment(st);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: seg == st ? LColors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: seg == st
                                  ? const [BoxShadow(color: Color(0x261F2D3D), blurRadius: 3, offset: Offset(0, 1))]
                                  : null,
                            ),
                            child: Text(
                              '${savedStatusLabels[st]} ${count(st)}',
                              style: ts(
                                14,
                                weight: seg == st ? FontWeight.w700 : FontWeight.w500,
                                color: seg == st ? LColors.ink : LColors.text2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(plural(total, 'scholarship'), style: ts(14, color: LColors.text2)),
            ],
          ),
        ),
        Expanded(
          child: total == 0
              ? SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.bookmarks_outlined,
                    title: seg == 'saved' ? 'Nothing saved yet' : 'Nothing in ${savedStatusLabels[seg]} yet',
                    message: 'Bookmark scholarships to track deadlines and prepare your application.',
                    actionLabel: 'Browse scholarships',
                    primaryAction: true,
                    onAction: () => c.setTab(1),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: total,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => i >= entries.length
                      ? _GoneCard(saved: gone[i - entries.length])
                      : _SavedCard(
                    scholarship: entries[i].s,
                    saved: entries[i].sv,
                    menuOpen: _menuOpenFor == entries[i].s.id,
                    onToggleMenu: () =>
                        setState(() => _menuOpenFor = _menuOpenFor == entries[i].s.id ? null : entries[i].s.id),
                    onCloseMenu: () => setState(() => _menuOpenFor = null),
                  ),
                ),
        ),
      ],
    );
  }
}

class _SavedCard extends StatelessWidget {
  const _SavedCard({
    required this.scholarship,
    required this.saved,
    required this.menuOpen,
    required this.onToggleMenu,
    required this.onCloseMenu,
  });

  final Scholarship scholarship;
  final SavedScholarship saved;
  final bool menuOpen;
  final VoidCallback onToggleMenu;
  final VoidCallback onCloseMenu;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final s = scholarship;
    final total = saved.checklist.length;
    final done = saved.doneCount;
    final updated = c.hasUpdate(s);

    return LCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          InkWell(
            onTap: () => openScholarship(context, s),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 3,
                    children: [
                      Text(s.title, style: ts(16, weight: FontWeight.w700)),
                      Text(deadlineLine(s, c.now), style: ts(13, color: LColors.text2)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 22, color: LColors.muted),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Checklist', style: ts(13, color: LColors.text2))),
                  Text(total == 0 ? 'Not started' : '$done/$total', style: ts(13, weight: FontWeight.w600)),
                ],
              ),
              LProgressBar(value: total == 0 ? 0 : done / total),
            ],
          ),
          if (updated)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: LColors.soft, borderRadius: BorderRadius.circular(5)),
                  child: Text('UPDATED', style: ts(11, weight: FontWeight.w700, color: LColors.primary, spacing: 0.44)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(s.lastChangeSummary ?? '', style: ts(13, color: LColors.text3))),
              ],
            ),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: LButton(
                  label: 'Prepare',
                  height: 44,
                  radius: 12,
                  fontSize: 14,
                  onPressed: () => openPrepare(context, s),
                ),
              ),
              Expanded(
                child: LButton(
                  label: 'Change status',
                  kind: LButtonKind.secondary,
                  trailingIcon: menuOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  height: 44,
                  radius: 12,
                  fontSize: 14,
                  onPressed: onToggleMenu,
                ),
              ),
            ],
          ),
          if (menuOpen)
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: LColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LColors.line),
              ),
              child: Column(
                children: [
                  for (final st in savedStatuses)
                    _MenuRow(
                      label: savedStatusLabels[st]!,
                      checked: saved.status == st,
                      onTap: () async {
                        onCloseMenu();
                        if (await c.setStatus(s, st) && context.mounted) {
                          showToast(context, 'Moved to ${savedStatusLabels[st]}');
                        }
                      },
                    ),
                  _MenuRow(
                    label: 'Remove from saved',
                    muted: true,
                    last: true,
                    onTap: () async {
                      onCloseMenu();
                      if (await c.unsave(s.id) && context.mounted) showToast(context, 'Removed from saved');
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A saved scholarship the research team has withdrawn from the catalog.
class _GoneCard extends StatelessWidget {
  const _GoneCard({required this.saved});

  final SavedScholarship saved;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return LCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.search_off_rounded, size: 22, color: LColors.text2),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    Text('This listing is no longer available', style: ts(16, weight: FontWeight.w700)),
                    Text(
                      'It was removed from the catalog, so its details and deadline can no longer be shown.',
                      style: ts(13, color: LColors.text2, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          LButton(
            label: 'Remove from saved',
            kind: LButtonKind.secondary,
            height: 44,
            radius: 12,
            fontSize: 14,
            onPressed: () async {
              if (await c.unsave(saved.scholarshipId) && context.mounted) showToast(context, 'Removed from saved');
            },
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.onTap, this.checked = false, this.muted = false, this.last = false});

  final String label;
  final VoidCallback onTap;
  final bool checked;
  final bool muted;
  final bool last;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: LColors.soft))),
          child: Row(
            children: [
              Expanded(child: Text(label, style: ts(14, color: muted ? LColors.text2 : LColors.ink))),
              if (checked) const Icon(Icons.check_rounded, size: 18, color: LColors.primary),
            ],
          ),
        ),
      );
}

import 'package:material_ui/material_ui.dart';

import '../models/scholarship.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/layout.dart';
import '../widgets/loading.dart';
import '../widgets/scholarship_card.dart';
import 'auth_screens.dart';
import 'profile_form.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final p = c.profile;
    final complete = p?.completeness ?? 0;
    final updates = c.savedWithUpdates;
    final name = p?.firstName;
    final sections = [
      ('Closing soon', c.closingSoon),
      ('Best matches for you', c.bestMatches),
      ('Opening soon', c.openingSoon),
    ].where((s) => s.$2.isNotEmpty);

    return RefreshIndicator(
      color: LColors.primary,
      onRefresh: c.refreshAiStatus,
      child: Gutter(
        maxWidth: LBreak.wide,
        builder: (context, side) => ListView(
          padding: EdgeInsets.fromLTRB(side, 12, side, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text('Hi, ${name ?? 'there'}', style: ts(28, weight: FontWeight.w700, spacing: -0.56)),
                      Text('Find your next scholarship.', style: ts(15, color: LColors.text2)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                LIconButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Updates on saved',
                  badge: updates.isNotEmpty,
                  onPressed: () {
                    c.setSavedSegment('saved');
                    c.setTab(2);
                  },
                ),
              ],
            ),
            SizedBox(height: L.s(18)),
            _SearchShortcut(onTap: () => c.setTab(1)),
            if (c.backend.isDemo) ...[SizedBox(height: L.s(12)), const DemoModeBanner()],
            if (complete < 1) ...[SizedBox(height: L.s(14)), _ProfileNudge(complete: complete)],
            // News about saved scholarships comes first: it is why a returning student opens the app.
            if (updates.isNotEmpty) ...[
              SizedBox(height: L.s(28)),
              Text('Updates on saved', style: ts(20, weight: FontWeight.w700)),
              SizedBox(height: L.s(12)),
              _UpdatesList(items: updates),
            ],
            if (!c.catalogLoaded) ...[
              SizedBox(height: L.s(28)),
              const ScholarshipSkeletons(),
            ] else if (c.catalogError != null)
              const CatalogError()
            else if (sections.isEmpty)
              EmptyState(
                icon: Icons.school_outlined,
                title: 'No open scholarships right now',
                message: 'New rounds are added as soon as providers publish them. Browse closed ones for reference.',
                actionLabel: 'Browse scholarships',
                onAction: () => c.setTab(1),
              ),
            for (final (title, items) in sections) ...[
              SizedBox(height: L.s(30)),
              _SectionHeader(title: title, onSeeAll: () => c.setTab(1)),
              SizedBox(height: L.s(12)),
              CardGrid(children: [for (final s in items) ScholarshipCard(scholarship: s)]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Looks like a search field; opens Browse.
class _SearchShortcut extends StatelessWidget {
  const _SearchShortcut({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: LColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(L.r(14)),
          side: BorderSide(color: LColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 22, color: LColors.muted),
                const SizedBox(width: 10),
                Expanded(child: Text('Search scholarships', style: ts(15, color: LColors.text2))),
              ],
            ),
          ),
        ),
      );
}

/// One compact panel that asks for the missing profile details.
class _ProfileNudge extends StatelessWidget {
  const _ProfileNudge({required this.complete});

  final double complete;

  @override
  Widget build(BuildContext context) {
    void open() =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EditPreferencesScreen()));
    return LPanel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Text('Your profile is ${(complete * 100).round()}% complete',
                    style: ts(15, weight: FontWeight.w700)),
                LProgressBar(value: complete, track: LColors.bg),
                Text('Add details to get better matches.', style: ts(14, color: LColors.text3)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 112,
            child: LButton(label: 'Complete', height: 44, radius: 12, fontSize: 14, onPressed: open),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: ts(20, weight: FontWeight.w700))),
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 40),
              foregroundColor: LColors.primary,
            ),
            child: Text('See all', style: ts(14, weight: FontWeight.w700, color: LColors.primary)),
          ),
        ],
      );
}

class _UpdatesList extends StatelessWidget {
  const _UpdatesList({required this.items});

  final List<Scholarship> items;

  @override
  Widget build(BuildContext context) => LCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++)
              InkWell(
                onTap: () => openScholarship(context, items[i]),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: L.s(14)),
                  decoration: BoxDecoration(
                    border: i == items.length - 1 ? null : Border(bottom: BorderSide(color: LColors.soft)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: LColors.soft, borderRadius: BorderRadius.circular(L.r(10))),
                        child: Icon(Icons.update_rounded, size: 20, color: LColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 3,
                          children: [
                            Text(items[i].title, style: ts(15, weight: FontWeight.w600)),
                            Text(items[i].lastChangeSummary ?? '', style: ts(14, color: LColors.text2, height: 1.4)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 20, color: LColors.muted),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

/// Shown when Firestore refuses the catalog (usually rules / sign-in / App Check).
class CatalogError extends StatelessWidget {
  const CatalogError({super.key});

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load scholarships",
        message: 'Check your connection and try again. If it keeps happening, sign out and back in.',
        actionLabel: 'Try again',
        primaryAction: true,
        onAction: AppScope.read(context).retryCatalog,
      );
}

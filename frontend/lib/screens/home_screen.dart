import 'package:material_ui/material_ui.dart';

import '../models/scholarship.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
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
    final sections = [
      ('Closing soon', c.closingSoon),
      ('Best matches for you', c.bestMatches),
      ('Opening soon', c.openingSoon),
    ].where((s) => s.$2.isNotEmpty);

    return RefreshIndicator(
      color: LColors.primary,
      onRefresh: c.refreshAiStatus,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Hi, ${p?.firstName ?? 'there'}', style: ts(28, weight: FontWeight.w700, spacing: -0.56)),
              ),
              LIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Updates on saved',
                size: 42,
                badge: updates.isNotEmpty,
                onPressed: () {
                  c.setSavedSegment('saved');
                  c.setTab(2);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: LColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: LColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => c.setTab(1),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    const Icon(Icons.search_rounded, size: 22, color: LColors.muted),
                    const SizedBox(width: 10),
                    Text('Search scholarships', style: ts(15, color: LColors.text2)),
                  ],
                ),
              ),
            ),
          ),
          if (c.backend.isDemo) ...[const SizedBox(height: 12), const DemoModeBanner()],
          if (complete < 1) ...[
            const SizedBox(height: 16),
            LPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Complete your profile for better matches', style: ts(15, weight: FontWeight.w600)),
                      ),
                      Text('${(complete * 100).round()}%', style: ts(14, weight: FontWeight.w700)),
                    ],
                  ),
                  LProgressBar(value: complete, track: LColors.bg),
                  LButton(
                    label: 'Complete profile',
                    height: 44,
                    radius: 12,
                    fontSize: 14,
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => const EditPreferencesScreen())),
                  ),
                ],
              ),
            ),
          ],
          if (!c.catalogLoaded)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator(color: LColors.primary)),
            )
          else if (c.catalogError != null)
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
            const SizedBox(height: 26),
            _SectionHeader(title: title, onSeeAll: () => c.setTab(1)),
            const SizedBox(height: 12),
            for (final s in items) ...[ScholarshipCard(scholarship: s), const SizedBox(height: 12)],
          ],
          if (updates.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Updates on saved', style: ts(18, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            _UpdatesList(items: updates),
          ],
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(title, style: ts(18, weight: FontWeight.w700))),
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 32),
              foregroundColor: LColors.text2,
            ),
            child: Text('See all', style: ts(14, weight: FontWeight.w600, color: LColors.text2)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: i == items.length - 1 ? null : const Border(bottom: BorderSide(color: LColors.soft)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: LColors.soft, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.update_rounded, size: 20, color: LColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(items[i].title, style: ts(15, weight: FontWeight.w600)),
                            Text(items[i].lastChangeSummary ?? '', style: ts(13, color: LColors.text2)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 20, color: LColors.muted),
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

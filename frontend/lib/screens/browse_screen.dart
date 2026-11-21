import 'package:material_ui/material_ui.dart';

import '../state/app_scope.dart';
import '../state/browse_filters.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/scholarship_card.dart';
import 'home_screen.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = AppScope.read(context).filters.query;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final f = c.filters;
    if (_search.text != f.query) _search.text = f.query;
    final results = c.browseResults;
    final active = f.active;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      decoration: lInputDecoration(
                        hint: 'Search scholarships',
                        prefix: const Icon(Icons.search_rounded, size: 22, color: LColors.muted),
                      ).copyWith(
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: LColors.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: LColors.primary, width: 1.5),
                        ),
                      ),
                      onChanged: (v) {
                        f.query = v;
                        c.filtersChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  LIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'Filters',
                    size: 48,
                    onPressed: () => showLSheet<void>(context, (_) => AppScope(controller: c, child: const FilterSheet())),
                  ),
                ],
              ),
              if (active.isNotEmpty)
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final a in active) ...[
                        _ActiveChip(
                          label: a.label,
                          onTap: () {
                            a.remove();
                            c.filtersChanged();
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      Material(
                        color: LColors.white,
                        shape: const StadiumBorder(side: BorderSide(color: LColors.line)),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            f.clearAll();
                            c.filtersChanged();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            child: Text('Clear all', style: ts(14, weight: FontWeight.w600, color: LColors.text2)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(child: Text(plural(results.length, 'result'), style: ts(14, color: LColors.text2))),
                  Material(
                    color: LColors.white,
                    shape: const StadiumBorder(side: BorderSide(color: LColors.line)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        f.sort = f.sort == SortBy.deadline ? SortBy.match : SortBy.deadline;
                        c.filtersChanged();
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Sort: ${f.sort == SortBy.deadline ? 'Deadline' : 'Match'}',
                              style: ts(13, weight: FontWeight.w600),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.swap_vert_rounded, size: 18, color: LColors.ink),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: !c.catalogLoaded
              ? const Center(child: CircularProgressIndicator(color: LColors.primary))
              : c.catalogError != null
                  ? const SingleChildScrollView(child: CatalogError())
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: results.isEmpty ? 1 : results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => results.isEmpty
                          ? EmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No scholarships match these filters',
                              message: 'Try removing a filter or searching a different keyword.',
                              actionLabel: 'Clear filters',
                              onAction: () {
                                f.clearAll();
                                c.filtersChanged();
                              },
                            )
                          : ScholarshipCard(scholarship: results[i]),
                    ),
        ),
      ],
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: LColors.soft,
        shape: const StadiumBorder(side: BorderSide(color: LColors.primary)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: ts(14, weight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.close_rounded, size: 16, color: LColors.ink),
              ],
            ),
          ),
        ),
      );
}

class FilterSheet extends StatelessWidget {
  const FilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final f = c.filters;
    final count = c.browseResults.length;

    Widget group(String title, Iterable<(String, String)> options, Set<String> selected) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: ts(14, weight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, label) in options)
                  LChip(
                    label: label,
                    selected: selected.contains(value),
                    onTap: () {
                      selected.contains(value) ? selected.remove(value) : selected.add(value);
                      c.filtersChanged();
                    },
                  ),
              ],
            ),
          ],
        );

    Widget toggle(String label, bool value, void Function(bool) set) => Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: LColors.soft))),
          child: Row(
            children: [
              Expanded(child: Text(label, style: ts(15))),
              LToggle(
                value: value,
                semanticLabel: label,
                onChanged: (v) {
                  set(v);
                  c.filtersChanged();
                },
              ),
            ],
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Row(
            children: [
              Expanded(child: Text('Filters', style: ts(20, weight: FontWeight.w700))),
              TextButton(
                onPressed: () {
                  f.reset();
                  final level = c.profile?.educationLevel;
                  if (level != null) f.levels.add(level);
                  c.filtersChanged();
                },
                child: Text('Reset', style: ts(14, weight: FontWeight.w600, color: LColors.text2)),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 18,
              children: [
                group('Education level', levelLabels.entries.map((e) => (e.key, e.value)), f.levels),
                group('Funding type', fundingLabels.entries.map((e) => (e.key, e.value)), f.funding),
                group('Host country', targetCountryOptions.map((c) => (c, countryName(c))), f.countries),
                group('Field of study', fieldOptions.map((x) => (x, x)), f.fields),
                Container(
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: LColors.soft))),
                  child: Column(
                    children: [
                      toggle('Eligible for my citizenship', f.eligibleOnly, (v) => f.eligibleOnly = v),
                      toggle('Meets my GPA', f.meetsGpa, (v) => f.meetsGpa = v),
                      toggle('Show closed', f.showClosed, (v) => f.showClosed = v),
                      toggle('Only verified', f.verifiedOnly, (v) => f.verifiedOnly = v),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
          child: LButton(
            label: 'Show ${plural(count, 'result')}',
            height: 54,
            fontSize: 16,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

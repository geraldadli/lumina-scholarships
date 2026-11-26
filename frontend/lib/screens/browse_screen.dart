import 'package:material_ui/material_ui.dart';

import '../state/app_controller.dart';
import '../state/app_scope.dart';
import '../state/browse_filters.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/layout.dart';
import '../widgets/loading.dart';
import '../widgets/scholarship_card.dart';
import 'home_screen.dart';

/// Search and results. Wide screens show the filters beside the results; phones open a sheet.
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _search = TextEditingController();
  final _results = GlobalKey();

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
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final rail = box.maxWidth >= LBreak.filterRail;
          final results = KeyedSubtree(key: _results, child: _buildResults(context, rail: rail));
          if (!rail) return results;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: 300, child: _FilterRail()),
              Expanded(child: results),
            ],
          );
        },
      );

  Widget _buildResults(BuildContext context, {required bool rail}) {
    final c = AppScope.of(context);
    final f = c.filters;
    if (_search.text != f.query) _search.text = f.query;
    final results = c.browseResults;
    final active = f.active;

    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(L.r(14)),
          borderSide: BorderSide(color: color, width: width),
        );

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        if (active.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final a in active)
                _ActiveChip(
                  label: a.label,
                  onTap: () {
                    a.remove();
                    c.filtersChanged();
                  },
                ),
              TextButton(
                onPressed: () {
                  f.clearAll();
                  c.filtersChanged();
                },
                child: Text('Clear all', style: ts(14, weight: FontWeight.w700, color: LColors.primary)),
              ),
            ],
          ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(plural(results.length, 'result'), style: ts(16, weight: FontWeight.w700)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Sort by', style: ts(14, color: LColors.text2)),
                for (final (sort, label) in const [(SortBy.deadline, 'Deadline'), (SortBy.match, 'Match')])
                  LChip(
                    label: label,
                    selected: f.sort == sort,
                    onTap: () {
                      f.sort = sort;
                      c.filtersChanged();
                    },
                  ),
              ],
            ),
          ],
        ),
      ],
    );

    return Gutter(
      maxWidth: LBreak.wide,
      builder: (context, side) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(side, 12, side, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    decoration: lInputDecoration(
                      hint: 'Search scholarships',
                      prefix: Icon(Icons.search_rounded, size: 22, color: LColors.muted),
                    ).copyWith(enabledBorder: border(LColors.line), focusedBorder: border(LColors.primary, 2)),
                    onChanged: (v) {
                      f.query = v;
                      c.filtersChanged();
                    },
                  ),
                ),
                if (!rail) ...[
                  const SizedBox(width: 10),
                  LIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'Filters',
                    size: 50,
                    badge: active.isNotEmpty,
                    onPressed: () => showLSheet<void>(context, (_) => AppScope(controller: c, child: const FilterSheet())),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final columns = CardGrid.columnsFor(box.maxWidth - side * 2);
                final gap = L.s(14);
                final rows = (results.length / columns).ceil();
                Widget body(int row) {
                  if (!c.catalogLoaded) return const ScholarshipSkeletons();
                  if (c.catalogError != null) return const CatalogError();
                  if (results.isEmpty) return _noResults(c);
                  return CardRow(
                    columns: columns,
                    gap: gap,
                    children: [
                      for (final s in results.skip(row * columns).take(columns)) ScholarshipCard(scholarship: s),
                    ],
                  );
                }

                final bodyCount = !c.catalogLoaded || c.catalogError != null || results.isEmpty ? 1 : rows;
                // The first item is the filter summary, so it scrolls away with the results.
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(side, 0, side, 28),
                  itemCount: bodyCount + 1,
                  separatorBuilder: (_, _) => SizedBox(height: gap),
                  itemBuilder: (context, i) => i == 0 ? summary : body(i - 1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _noResults(AppController c) => EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No scholarships match these filters',
        message: 'Try removing a filter or searching a different keyword.',
        actionLabel: 'Clear filters',
        onAction: () {
          c.filters.clearAll();
          c.filtersChanged();
        },
      );
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: LColors.soft,
        shape: StadiumBorder(side: BorderSide(color: LColors.primary)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: ts(14, weight: FontWeight.w600)),
                const SizedBox(width: 6),
                Icon(Icons.close_rounded, size: 16, color: LColors.ink),
              ],
            ),
          ),
        ),
      );
}

void _resetFilters(AppController c) {
  c.filters.reset();
  final level = c.profile?.educationLevel;
  if (level != null) c.filters.levels.add(level);
  c.filtersChanged();
}

class _FiltersHeading extends StatelessWidget {
  const _FiltersHeading();

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Row(
      children: [
        Expanded(child: Text('Filters', style: ts(20, weight: FontWeight.w700))),
        TextButton(
          onPressed: () => _resetFilters(c),
          child: Text('Reset', style: ts(14, weight: FontWeight.w700, color: LColors.primary)),
        ),
      ],
    );
  }
}

/// Every filter, grouped. Shared by the phone sheet and the desktop side panel.
class FilterOptions extends StatelessWidget {
  const FilterOptions({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final f = c.filters;

    Widget group(String title, Iterable<(String, String)> options, Set<String> selected) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: ts(15, weight: FontWeight.w700)),
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

    Widget toggle(String label, bool value, void Function(bool) set) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(child: Text(label, style: ts(15))),
              const SizedBox(width: 12),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: L.s(22),
      children: [
        // The on/off switches are the quickest filters, so they come first.
        Column(
          children: [
            toggle('Eligible for my citizenship', f.eligibleOnly, (v) => f.eligibleOnly = v),
            toggle('Meets my GPA', f.meetsGpa, (v) => f.meetsGpa = v),
            toggle('Only verified', f.verifiedOnly, (v) => f.verifiedOnly = v),
            toggle('Show closed', f.showClosed, (v) => f.showClosed = v),
          ],
        ),
        group('Education level', levelLabels.entries.map((e) => (e.key, e.value)), f.levels),
        group('Funding type', fundingLabels.entries.map((e) => (e.key, e.value)), f.funding),
        group('Host country', targetCountryOptions.map((c) => (c, countryName(c))), f.countries),
        group('Field of study', fieldOptions.map((x) => (x, x)), f.fields),
      ],
    );
  }
}

class _FilterRail extends StatelessWidget {
  const _FilterRail();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(border: Border(right: BorderSide(color: LColors.soft))),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: const [_FiltersHeading(), SizedBox(height: 10), FilterOptions()],
        ),
      );
}

class FilterSheet extends StatelessWidget {
  const FilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final count = AppScope.of(context).browseResults.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 12, 6),
          child: _FiltersHeading(),
        ),
        const Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: FilterOptions(),
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

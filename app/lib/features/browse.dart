import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'widgets.dart';

class _Filters {
  Set<String> levels = {};
  Set<String> countries = {};
  bool fullOnly = false;
  bool eligibleOnly = false;
  bool showClosed = true;
  bool sortByMatch = false;

  int get count =>
      levels.length + countries.length + (fullOnly ? 1 : 0) + (eligibleOnly ? 1 : 0) + (showClosed ? 0 : 1);
}

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});
  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  var _f = _Filters();
  String _q = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    // Client-side filtering, as the contract recommends for the small catalog.
    final q = _q.toLowerCase();
    final results = state.scholarships.where((s) {
      if (q.isNotEmpty && !'${s.title} ${s.provider} ${s.hostLabel}'.toLowerCase().contains(q)) return false;
      if (!_f.showClosed && !s.isActive) return false;
      if (_f.fullOnly && s.fundingType != 'full') return false;
      if (_f.levels.isNotEmpty && !s.educationLevels.any(_f.levels.contains)) return false;
      if (_f.countries.isNotEmpty && !s.hostCountries.any(_f.countries.contains)) return false;
      if (_f.eligibleOnly && !state.match(s).eligible) return false;
      return true;
    }).toList();
    if (_f.sortByMatch) {
      results.sort((a, b) => state.match(b).score.compareTo(state.match(a).score));
    }
    final open = results.where((s) => s.isActive).toList();
    final closed = results.where((s) => !s.isActive).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: 'Search scholarships',
                    prefixIcon: const Icon(Symbols.search),
                    suffixIcon: _q.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Symbols.close),
                            onPressed: () => setState(() {
                              _ctrl.clear();
                              _q = '';
                            })),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Badge(
                isLabelVisible: _f.count > 0,
                label: Text('${_f.count}'),
                backgroundColor: LColors.primary,
                child: IconButton.outlined(
                  style: IconButton.styleFrom(
                    fixedSize: const Size(50, 50),
                    side: const BorderSide(color: LColors.line),
                    backgroundColor: LColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _openFilters,
                  icon: const Icon(Symbols.tune),
                ),
              ),
            ]),
          ),
          if (state.catalogError != null)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: LColors.soft, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Symbols.cloud_off, size: 18, color: LColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(state.catalogError!, style: const TextStyle(fontSize: 12))),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text('${results.length} scholarships', style: const TextStyle(color: LColors.text2, fontSize: 13)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _f.sortByMatch = !_f.sortByMatch),
                icon: const Icon(Symbols.swap_vert, size: 18),
                label: Text(_f.sortByMatch ? 'Best match' : 'Deadline'),
              ),
            ]),
          ),
          Expanded(
            child: results.isEmpty
                ? EmptyState(
                    icon: Symbols.search_off,
                    title: 'No scholarships match these filters',
                    body: 'Try removing a filter or searching a different keyword.',
                    action: 'Clear filters',
                    onAction: () => setState(() {
                      _f = _Filters();
                      _ctrl.clear();
                      _q = '';
                    }),
                  )
                : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
                    for (final s in open) Padding(padding: const EdgeInsets.only(bottom: 12), child: ScholarshipCard(s)),
                    if (closed.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(0, 12, 0, 4),
                        child: Text('Recently closed · next intake',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('Save these to prepare early for the next round.',
                            style: TextStyle(fontSize: 13, color: LColors.text2)),
                      ),
                      for (final s in closed)
                        Padding(padding: const EdgeInsets.only(bottom: 12), child: ScholarshipCard(s)),
                    ],
                  ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _openFilters() async {
    final hosts = {for (final s in AppScope.of(context).scholarships) ...s.hostCountries}.toList()..sort();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LColors.bg,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        void upd(VoidCallback f) {
          set(f);
          setState(() {});
        }

        Widget toggleSet(Set<String> s, String v, String label) =>
            LChip(label, selected: s.contains(v), onTap: () => upd(() => s.contains(v) ? s.remove(v) : s.add(v)));

        Widget sw(String label, bool v, ValueChanged<bool> on) => SwitchListTile(
            contentPadding: EdgeInsets.zero, title: Text(label), value: v, onChanged: (x) => upd(() => on(x)));

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                TextButton(onPressed: () => upd(() => _f = _Filters()), child: const Text('Reset')),
              ]),
              const SizedBox(height: 12),
              const Text('Degree', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final l in educationLevels) toggleSet(_f.levels, l, levelName(l)),
              ]),
              const SizedBox(height: 16),
              const Text('Study in', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in hosts) toggleSet(_f.countries, c, countryName(c)),
              ]),
              const SizedBox(height: 8),
              sw('Full funding only', _f.fullOnly, (v) => _f.fullOnly = v),
              sw('Eligible for me', _f.eligibleOnly, (v) => _f.eligibleOnly = v),
              sw('Show closed scholarships', _f.showClosed, (v) => _f.showClosed = v),
              const SizedBox(height: 8),
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Show results')),
            ]),
          ),
        );
      }),
    );
  }
}

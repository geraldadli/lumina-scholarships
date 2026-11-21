import 'package:flutter/material.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'detail.dart';

class PrepareScreen extends StatefulWidget {
  const PrepareScreen({super.key, required this.id});
  final String id;
  @override
  State<PrepareScreen> createState() => _PrepareScreenState();
}

class _PrepareScreenState extends State<PrepareScreen> {
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    final saved = state.saved[widget.id]!;
    if (saved.checklist.isEmpty) {
      // Contract §3: copy scholarships.requirements when the user starts Prepare.
      saved.checklist = [
        for (final r in state.byId(widget.id).requirements) ChecklistEntry(id: r.id, label: r.label),
      ];
      if (saved.status == 'saved') saved.status = 'preparing';
      WidgetsBinding.instance.addPostFrameCallback((_) => state.updateSaved(widget.id, immediate: true));
    }
  }

  Future<void> _regenerate() async {
    final state = AppScope.of(context);
    final saved = state.saved[widget.id]!;
    setState(() => _loading = true);
    try {
      final r = await state.ai.generateChecklist(ChecklistRequest(
        scholarship: state.byId(widget.id).toAiContext(),
        student: state.profile.toAiContext(),
        allowCloud: state.profile.cloudAiAllowed,
        languageCode: 'en',
      ));
      final done = {for (final c in saved.checklist) if (c.done) c.id};
      saved.checklist = [
        for (final i in r.items) ChecklistEntry(id: i.id, label: i.label, tip: i.tip, done: done.contains(i.id)),
      ];
      state.updateSaved(widget.id, immediate: true);
      if (mounted && r.note != null) showToast(context, r.note!);
    } on HybridAiException catch (e) {
      if (mounted) showToast(context, e.unavailability.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.byId(widget.id);
    final saved = state.saved[widget.id]!;
    final done = saved.checklist.where((c) => c.done).length;
    final total = saved.checklist.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Prepare', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        Text(s.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'saved', label: Text('Saved')),
            ButtonSegment(value: 'preparing', label: Text('Preparing')),
            ButtonSegment(value: 'applied', label: Text('Applied')),
          ],
          selected: {saved.status},
          onSelectionChanged: (v) => state.setSavedStatus(s.id, v.first),
        ),
        const SizedBox(height: 20),
        Row(children: [
          const Expanded(child: Text('Checklist', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          Text('$done of $total', style: const TextStyle(color: LColors.text2, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : done / total, minHeight: 6, color: LColors.primary, backgroundColor: LColors.soft),
        ),
        const SizedBox(height: 12),
        if (total == 0)
          const Text('No official requirements listed yet. Try generating a checklist with AI.',
              style: TextStyle(color: LColors.text2)),
        for (final c in saved.checklist)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: c.done,
            onChanged: (v) {
              c.done = v ?? false;
              state.updateSaved(s.id);
            },
            title: Text(c.label, style: const TextStyle(fontSize: 14)),
            subtitle: c.tip == null ? null : Text(c.tip!, style: const TextStyle(fontSize: 12, color: LColors.text2)),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loading ? null : _regenerate,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          icon: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Symbols.auto_awesome),
          label: const Text('Regenerate with AI', style: TextStyle(fontSize: 14)),
        ),
        const SizedBox(height: 24),
        const Text('Notes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: saved.notes,
          maxLines: 5,
          maxLength: 5000,
          decoration: const InputDecoration(hintText: 'Referees, essay ideas, reminders…'),
          onChanged: (v) {
            saved.notes = v;
            state.updateSaved(s.id); // debounced
          },
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => openOfficial(context, s.sourceUrl),
          icon: const Icon(Symbols.north_east),
          label: const Text('Apply on official website'),
        ),
      ]),
    );
  }
}

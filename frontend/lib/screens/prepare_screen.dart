import 'dart:async';

import 'package:flutter/services.dart';

import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:material_ui/material_ui.dart';

import '../models/saved_scholarship.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/layout.dart';
import '../widgets/scholarship_card.dart';

/// Prepare checklist + notes, stored on `users/{uid}/saved_scholarships/{id}`.
class PrepareScreen extends StatefulWidget {
  const PrepareScreen({super.key, required this.scholarshipId});

  final String scholarshipId;

  @override
  State<PrepareScreen> createState() => _PrepareScreenState();
}

class _PrepareScreenState extends State<PrepareScreen> {
  final _newItem = TextEditingController();
  final _notes = TextEditingController();
  Timer? _notesDebounce;
  bool _notesLoaded = false;
  bool _regenerating = false;

  /// Kept from when the screen was active: dispose() can no longer look up AppScope, and the
  /// last notes edit must go to the account it was typed in, never to one signed in after it.
  late AppController _controller;
  String? _uid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = AppScope.read(context);
    _uid ??= _controller.user?.uid;
  }

  @override
  void dispose() {
    // Flush first: it saves only while the autosave is still pending, then cancels it.
    _flushNotes();
    _newItem.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _flushNotes() {
    if (_notesDebounce?.isActive ?? false) {
      _notesDebounce!.cancel();
      _saveNotes();
    }
  }

  /// Also runs from dispose() (leaving Prepare before the autosave fired), so it must not use
  /// [context]. A failure still reaches the student through the controller's notices.
  void _saveNotes() {
    final uid = _uid;
    final s = _controller.byId(widget.scholarshipId);
    if (s != null && uid != null) unawaited(_controller.setNotes(s, _notes.text, uid: uid));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final s = c.byId(widget.scholarshipId);
    final sv = c.saved[widget.scholarshipId];
    if (s == null) return const _ListingGone(title: 'Prepare');
    if (sv != null && !_notesLoaded) {
      _notes.text = sv.notes;
      _notesLoaded = true;
    }
    final items = sv?.checklist ?? const <ChecklistEntry>[];
    final done = items.where((i) => i.done).length;
    final tips = c.checklistTips[s.id] ?? const {};
    final source = c.checklistSource[s.id];

    void setItems(List<ChecklistEntry> next) => unawaited(c.setChecklist(s, next));

    void addItem() {
      final t = _newItem.text.trim();
      if (t.isEmpty || items.length >= 50) return;
      _newItem.clear();
      setItems([...items, ChecklistEntry(id: 'custom-${DateTime.now().millisecondsSinceEpoch}', label: t)]);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LHeader(
              title: 'Prepare checklist',
              subtitle: s.title,
              bottom: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(deadlineLine(s, c.now), style: ts(14, color: LColors.text2))),
                      const SizedBox(width: 12),
                      Text('$done/${items.length} done', style: ts(14, weight: FontWeight.w700)),
                    ],
                  ),
                  LProgressBar(value: items.isEmpty ? 0 : done / items.length),
                ],
              ),
            ),
            Expanded(
              child: sv == null
                  ? Center(child: CircularProgressIndicator(color: LColors.primary))
                  : Gutter(
                      builder: (context, side) => ListView(
                        padding: EdgeInsets.fromLTRB(side, 8, side, 20),
                        children: [
                          if (items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'No official requirements are listed yet. Add your own items, or regenerate with AI.',
                                style: ts(14, color: LColors.text2, height: 1.45),
                              ),
                            ),
                          for (var i = 0; i < items.length; i++)
                            InkWell(
                              onTap: () => setItems([for (var j = 0; j < items.length; j++) j == i ? items[j].toggled() : items[j]]),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: L.s(15)),
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: LColors.soft))),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _CheckBox(done: items[i].done),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        spacing: 3,
                                        children: [
                                          Text(
                                            items[i].label,
                                            style: ts(
                                              15,
                                              weight: FontWeight.w500,
                                              color: items[i].done ? LColors.text2 : LColors.ink,
                                              decoration: items[i].done ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          if (tips[items[i].id] != null)
                                            Text(tips[items[i].id]!, style: ts(14, color: LColors.text2, height: 1.4)),
                                        ],
                                      ),
                                    ),
                                    if (items[i].id.startsWith('custom-'))
                                      IconButton(
                                        tooltip: 'Remove item',
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(Icons.close_rounded, size: 18, color: LColors.muted),
                                        onPressed: () => setItems([...items]..removeAt(i)),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _newItem,
                                  textCapitalization: TextCapitalization.sentences,
                                  decoration: lInputDecoration(hint: 'Add your own item'),
                                  onSubmitted: (_) => addItem(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 72,
                                child: LButton(
                                  label: 'Add',
                                  kind: LButtonKind.secondary,
                                  height: 48,
                                  radius: 12,
                                  fontSize: 14,
                                  onPressed: addItem,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LBadge(source == null || source == AiSource.rules ? 'Official' : 'Sourced · AI'),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${source == null || source == AiSource.rules ? 'From the requirements on' : 'Generated from'} '
                                  '${hostOf(s.sourceUrl)}. Check official requirements before submitting.',
                                  style: ts(13, color: LColors.text2, height: 1.45),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(child: Text('Notes', style: ts(16, weight: FontWeight.w700))),
                              ValueListenableBuilder(
                                valueListenable: _notes,
                                builder: (_, v, _) => Text('${v.text.length} / $maxNotesLength', style: ts(13, color: LColors.text2)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notes,
                            // Limit in UTF-16 units like the backend and the counter (maxLength counts
                            // graphemes, so emoji-heavy notes would be cut silently on save).
                            inputFormatters: [_Utf16Limit(maxNotesLength)],
                            minLines: 5,
                            maxLines: 8,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: lInputDecoration(hint: 'Add notes about this application…', counter: ''),
                            onChanged: (_) {
                              _notesDebounce?.cancel();
                              _notesDebounce = Timer(const Duration(milliseconds: 800), _saveNotes);
                            },
                          ),
                        ],
                      ),
                    ),
            ),
            LFooter(children: [
              LButton(
                label: 'Regenerate with AI',
                icon: Icons.auto_awesome_rounded,
                kind: LButtonKind.secondary,
                height: 46,
                radius: 12,
                fontSize: 14,
                busy: _regenerating,
                onPressed: sv == null
                    ? null
                    : () async {
                        setState(() => _regenerating = true);
                        final msg = await c.regenerateChecklist(s);
                        if (!context.mounted) return;
                        setState(() => _regenerating = false);
                        showToast(context, msg);
                      },
              ),
              LButton(
                label: sv?.status == 'applied' ? 'Applied' : 'Mark as applied',
                onPressed: sv == null || sv.status == 'applied'
                    ? null
                    : () {
                        _flushNotes();
                        // Not awaited: offline, Firestore only confirms once back online. A failure
                        // is reported by the controller's notices (shown from the app root).
                        unawaited(c.setStatus(s, 'applied'));
                        c
                          ..setSavedSegment('applied')
                          ..setTab(2);
                        showToast(context, 'Marked as applied');
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Rejects edits that would make the text longer than [max] UTF-16 code units.
class _Utf16Limit extends TextInputFormatter {
  _Utf16Limit(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.text.length <= max ? newValue : oldValue;
}

/// Shown when the scholarship is no longer in the catalog (withdrawn by the research team).
class _ListingGone extends StatelessWidget {
  const _ListingGone({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              LHeader(title: title, border: false),
              const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'This listing is no longer available',
                message: 'It was removed from the catalog. You can remove it from the Saved tab.',
              ),
            ],
          ),
        ),
      );
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 24,
        height: 24,
        margin: const EdgeInsets.only(top: 1),
        decoration: BoxDecoration(
          color: done ? LColors.primary : LColors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: done ? LColors.primary : LColors.muted, width: 1.5),
        ),
        child: done ? Icon(Icons.check_rounded, size: 18, color: LColors.bg) : null,
      );
}

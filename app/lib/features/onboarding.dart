import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';

const _steps = ['About you', 'Study goals', 'Academics', 'Privacy & AI'];

/// Onboarding stepper (prototype `show.form`). With [editSection] it edits one section from Profile.
class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({super.key, this.editSection});
  final int? editSection;

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  late int step = widget.editSection ?? 0;
  bool get editing => widget.editSection != null;

  void _next() {
    final state = AppScope.of(context);
    void save() => state.saveProfile().catchError((Object e) {
          if (mounted) showToast(context, 'Could not save your profile. Check your connection.');
        });
    if (editing) {
      save();
      context.pop();
    } else if (step < _steps.length - 1) {
      save(); // keep progress if the app is closed mid-onboarding
      setState(() => step++);
    } else {
      state.profile.onboardingCompleted = true;
      save(); // router redirects to Home
    }
  }

  void _back() {
    if (editing) {
      context.pop();
    } else if (step == 0) {
      AppScope.of(context).signOut(); // router returns to Welcome
    } else {
      setState(() => step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).profile;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            child: Row(children: [
              _SquareButton(icon: Symbols.arrow_back, onTap: _back),
              const SizedBox(width: 12),
              if (editing)
                Text(_steps[step], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))
              else ...[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (step + 1) / _steps.length,
                      minHeight: 6,
                      backgroundColor: LColors.soft,
                      color: LColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${step + 1} of ${_steps.length}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: LColors.text2)),
              ],
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              children: [
                switch (step) {
                  0 => _About(p),
                  1 => _Goals(p),
                  2 => _Academics(p),
                  _ => _Privacy(p, showTitle: !editing),
                },
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton(
              onPressed: _next,
              child: Text(editing ? 'Save' : (step == _steps.length - 1 ? 'Finish' : 'Continue')),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 40,
        height: 40,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(40, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Icon(icon, size: 22),
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.child);
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        child,
      ]);
}

class _About extends StatefulWidget {
  const _About(this.p);
  final UserProfile p;
  @override
  State<_About> createState() => _AboutState();
}

class _AboutState extends State<_About> {
  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('About you', subtitle: 'We use this to match you with scholarships you can apply for.'),
      const SizedBox(height: 18),
      _Field('Display name', TextFormField(
        initialValue: p.displayName,
        decoration: const InputDecoration(hintText: 'Your name'),
        onChanged: (v) => p.displayName = v.trim(),
      )),
      const SizedBox(height: 18),
      _Field('Citizenship', DropdownButtonFormField<String>(
        initialValue: p.citizenship,
        hint: const Text('Select country'),
        items: [
          for (final e in countryNames.entries.where((e) => e.key != 'GLOBAL'))
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => setState(() => p.citizenship = v),
      )),
      const SizedBox(height: 18),
      _Field('Current education level', DropdownButtonFormField<String>(
        initialValue: p.currentEducationLevel,
        hint: const Text('Select level'),
        items: [
          for (final l in ['high_school', ...educationLevels])
            DropdownMenuItem(value: l, child: Text(levelName(l))),
        ],
        onChanged: (v) => setState(() => p.currentEducationLevel = v),
      )),
    ]);
  }
}

class _Goals extends StatefulWidget {
  const _Goals(this.p);
  final UserProfile p;
  @override
  State<_Goals> createState() => _GoalsState();
}

class _GoalsState extends State<_Goals> {
  static const _fields = ['Computer Science', 'Engineering', 'Business', 'Public Policy', 'Health', 'Education', 'Social Sciences', 'Arts'];
  static const _countries = ['AU', 'US', 'GB', 'JP', 'DE', 'NL', 'KR', 'SE', 'CN'];

  Widget _group(String title, List<Widget> chips) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ]),
      );

  void _toggle(List<String> list, String v) =>
      setState(() => list.contains(v) ? list.remove(v) : list.add(v));

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Study goals', subtitle: "Pick what you're aiming for. You can choose more than one."),
      _group('Degree', [
        for (final l in educationLevels)
          LChip(levelName(l), selected: p.educationLevel == l, onTap: () => setState(() => p.educationLevel = l)),
      ]),
      _group('Field of study', [
        for (final f in _fields) LChip(f, selected: p.fieldsOfStudy.contains(f), onTap: () => _toggle(p.fieldsOfStudy, f)),
      ]),
      _group('Where to study', [
        for (final c in _countries)
          LChip(countryName(c), selected: p.targetCountries.contains(c), onTap: () => _toggle(p.targetCountries, c)),
      ]),
      _group('Funding', [
        for (final f in const ['full', 'partial', 'any'])
          LChip(f == 'any' ? 'Any' : '${f[0].toUpperCase()}${f.substring(1)}',
              selected: p.fundingPreference == f, onTap: () => setState(() => p.fundingPreference = f)),
      ]),
    ]);
  }
}

class _Academics extends StatelessWidget {
  const _Academics(this.p);
  final UserProfile p;

  Widget _row(String label, String hint, String? initial, ValueChanged<String> onChanged) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(children: [
          SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          Expanded(
            child: TextFormField(
              initialValue: initial,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: hint),
              onChanged: onChanged,
            ),
          ),
        ]),
      );

  void _score(String key, String v) {
    final n = num.tryParse(v);
    n == null ? p.languageScores.remove(key) : p.languageScores[key] = n;
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Academics', subtitle: 'Optional. Scores let us check minimum requirements for you.'),
      _row('GPA', 'e.g. 3.5 (out of 4.0)', p.gpa?.toString(), (v) {
        final g = double.tryParse(v);
        p.gpa = (g != null && g >= 0 && g <= 4) ? g : null;
      }),
      _row('IELTS', 'e.g. 6.5', p.languageScores['ielts']?.toString(), (v) => _score('ielts', v)),
      _row('TOEFL iBT', 'e.g. 90', p.languageScores['toeflIbt']?.toString(), (v) => _score('toeflIbt', v)),
      _row('Duolingo', 'e.g. 115', p.languageScores['duolingo']?.toString(), (v) => _score('duolingo', v)),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => showToast(context, 'CV import is coming soon'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: LColors.bg),
        icon: const Icon(Symbols.upload_file),
        label: const Text('Import from CV (optional)', style: TextStyle(fontSize: 14)),
      ),
    ]);
  }
}

class _Privacy extends StatefulWidget {
  const _Privacy(this.p, {required this.showTitle});
  final UserProfile p;
  final bool showTitle;
  @override
  State<_Privacy> createState() => _PrivacyState();
}

class _PrivacyState extends State<_Privacy> {
  AiStatus? _status;
  String? _error;
  double? _progress;
  StreamSubscription<DownloadProgress>? _sub;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final s = await AppScope.of(context).ai.getStatus();
      if (mounted) setState(() => _status = s);
    } catch (e) {
      if (mounted) setState(() => _error = e is HybridAiException ? e.unavailability.message : '$e');
    }
  }

  void _download() {
    setState(() => _progress = 0);
    _sub = AppScope.of(context).ai.downloadModel().listen(
      (d) {
        final total = d.totalBytes ?? 0;
        setState(() => _progress = total > 0 ? (d.bytesDownloaded ?? 0) / total : null);
      },
      onError: (e) => setState(() {
        _progress = null;
        _error = e is HybridAiException ? e.unavailability.message : '$e';
      }),
      onDone: () {
        setState(() => _progress = null);
        _refresh();
      },
    );
  }

  String get _statusLabel => switch (_status?.onDeviceModel) {
        null => _error == null ? 'Checking…' : 'Unavailable',
        ModelAvailability.available => 'Ready',
        ModelAvailability.downloadable => 'Not downloaded',
        ModelAvailability.downloading => 'Downloading',
        _ => 'Not supported',
      };

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.showTitle) ...[
        const SectionTitle('Privacy & AI', subtitle: "Choose how Lumina's assistant answers your questions."),
        const SizedBox(height: 18),
      ],
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: LColors.soft, borderRadius: BorderRadius.circular(16)),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Symbols.shield_lock, color: LColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('On-device AI by default', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Questions are answered on your phone. Nothing leaves your device unless you allow cloud AI.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF33465A), height: 1.45)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      LCard(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Allow cloud AI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: const Text('Sends your question and the relevant scholarship text to a server for faster answers.',
              style: TextStyle(fontSize: 13, color: LColors.text2)),
          value: p.cloudAiAllowed,
          onChanged: (v) => setState(() => p.cloudAiAllowed = v),
        ),
      ),
      const SizedBox(height: 18),
      LCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: Text('On-device AI model', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            LTag(_statusLabel),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(child: Text('Inference mode', style: TextStyle(fontSize: 13, color: LColors.text2))),
            Text(_status?.inferenceMode ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(fontSize: 13, color: LColors.text2)),
          ],
          if (_status?.onDeviceModel == ModelAvailability.downloadable && _progress == null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _download,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), backgroundColor: LColors.bg),
              icon: const Icon(Symbols.download),
              label: const Text('Download model', style: TextStyle(fontSize: 14)),
            ),
          ],
          if (_sub != null && (_progress != null || _status?.onDeviceModel == ModelAvailability.downloading)) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress, color: LColors.primary, backgroundColor: LColors.soft),
          ],
        ]),
      ),
    ]);
  }
}

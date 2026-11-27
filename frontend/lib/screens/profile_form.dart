import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:material_ui/material_ui.dart';

import '../models/user_profile.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/layout.dart';
import '../widgets/motion.dart';

/// Editable copy of [UserProfile] backing the onboarding / preferences / privacy forms.
class ProfileDraft {
  ProfileDraft.from(UserProfile p)
      : name = TextEditingController(text: p.displayName),
        citizenship = p.citizenship,
        currentLevel = p.currentEducationLevel,
        customField = TextEditingController(
          text: p.fieldsOfStudy.where((f) => !fieldOptions.contains(f)).join(', '),
        ),
        targetLevel = p.educationLevel,
        fields = p.fieldsOfStudy.where(fieldOptions.contains).toSet(),
        countries = p.targetCountries.toSet(),
        funding = p.fundingPreference,
        gpa = TextEditingController(text: _n(p.gpa)),
        ielts = TextEditingController(text: _n(p.languageScores.ielts)),
        toefl = TextEditingController(text: _n(p.languageScores.toeflIbt)),
        duolingo = TextEditingController(text: _n(p.languageScores.duolingo)),
        jlpt = TextEditingController(text: p.languageScores.jlpt ?? ''),
        topik = TextEditingController(text: _n(p.languageScores.topik)),
        cloudAllowed = p.cloudAiAllowed,
        _base = p;

  final UserProfile _base;
  final TextEditingController name;
  String? citizenship;
  String? currentLevel;
  final TextEditingController customField;
  String? targetLevel;
  final Set<String> fields;
  final Set<String> countries;
  String? funding;
  final TextEditingController gpa, ielts, toefl, duolingo, jlpt, topik;
  bool cloudAllowed;

  static String _n(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  void dispose() {
    for (final c in [name, customField, gpa, ielts, toefl, duolingo, jlpt, topik]) {
      c.dispose();
    }
  }

  /// Validation messages for the academics block; empty when everything parses.
  Map<String, String> get scoreErrors {
    final e = <String, String>{};
    void range(String key, TextEditingController c, double min, double max) {
      final t = c.text.trim();
      if (t.isEmpty) return;
      final v = double.tryParse(t.replaceAll(',', '.'));
      if (v == null || v < min || v > max) e[key] = 'Enter a number from ${_n(min)} to ${_n(max)}.';
    }

    range('gpa', gpa, 0, 4);
    range('ielts', ielts, 0, 9);
    range('toefl', toefl, 0, 120);
    range('duolingo', duolingo, 10, 160);
    range('topik', topik, 1, 6);
    final j = jlpt.text.trim().toUpperCase();
    if (j.isNotEmpty && !RegExp(r'^N[1-5]$').hasMatch(j)) e['jlpt'] = 'Use N1 to N5.';
    return e;
  }

  UserProfile build({bool? onboardingCompleted}) {
    double? d(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));
    final custom = customField.text.split(',').map((f) => f.trim()).where((f) => f.isNotEmpty);
    final j = jlpt.text.trim().toUpperCase();
    return _base.copyWith(
      displayName: name.text.trim(),
      citizenship: () => citizenship,
      currentEducationLevel: () => currentLevel,
      educationLevel: () => targetLevel,
      fieldsOfStudy: {...custom, ...fields}.toList(),
      targetCountries: countries.toList(),
      fundingPreference: () => funding,
      gpa: () => d(gpa),
      languageScores: LanguageScores(
        ielts: d(ielts),
        toeflIbt: d(toefl),
        duolingo: d(duolingo),
        jlpt: j.isEmpty ? null : j,
        topik: d(topik),
      ),
      cloudAiAllowed: cloudAllowed,
      onboardingCompleted: onboardingCompleted,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ts(24, weight: FontWeight.w700, spacing: -0.24)),
          const SizedBox(height: 6),
          Text(subtitle, style: ts(14, color: LColors.text2, height: 1.45)),
        ],
      );
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.value, required this.hint, required this.items, required this.onChanged});

  final String? value;
  final String hint;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: lInputDecoration(),
        hint: Text(hint, style: ts(15, color: LColors.muted)),
        borderRadius: BorderRadius.circular(L.r(12)),
        dropdownColor: LColors.white,
        style: ts(15),
        items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: onChanged,
      );
}

class AboutYouSection extends StatelessWidget {
  const AboutYouSection({super.key, required this.draft, required this.onChanged});

  final ProfileDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 18,
        children: [
          const _SectionTitle('About you', 'We use this to match you with scholarships you can apply for.'),
          LField(
            label: 'Display name',
            child: TextField(
              controller: draft.name,
              textCapitalization: TextCapitalization.words,
              decoration: lInputDecoration(hint: 'Your name'),
              onChanged: (_) => onChanged(),
            ),
          ),
          LField(
            label: 'Citizenship',
            child: _Dropdown(
              value: draft.citizenship,
              hint: 'Select country',
              items: {for (final c in citizenshipOptions) c: countryName(c)},
              onChanged: (v) {
                draft.citizenship = v;
                onChanged();
              },
            ),
          ),
          LField(
            label: 'Current education level',
            child: _Dropdown(
              value: draft.currentLevel,
              hint: 'Select level',
              items: currentLevelLabels,
              onChanged: (v) {
                draft.currentLevel = v;
                onChanged();
              },
            ),
          ),
          LField(
            label: 'Current field of study',
            child: TextField(
              controller: draft.customField,
              textCapitalization: TextCapitalization.words,
              decoration: lInputDecoration(hint: 'e.g. Computer Science'),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      );
}

class StudyGoalsSection extends StatelessWidget {
  const StudyGoalsSection({super.key, required this.draft, required this.onChanged});

  final ProfileDraft draft;
  final VoidCallback onChanged;

  Widget _group(String title, List<Widget> chips) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: ts(15, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      );

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          const _SectionTitle('Study goals', "Pick what you're aiming for. You can choose more than one."),
          _group('Target level', [
            for (final e in levelLabels.entries)
              LChip(
                label: e.value,
                selected: draft.targetLevel == e.key,
                onTap: () {
                  // The contract stores one target level.
                  draft.targetLevel = draft.targetLevel == e.key ? null : e.key;
                  onChanged();
                },
              ),
          ]),
          _group('Field of study', [
            for (final f in fieldOptions)
              LChip(
                label: f,
                selected: draft.fields.contains(f),
                onTap: () {
                  draft.fields.contains(f) ? draft.fields.remove(f) : draft.fields.add(f);
                  onChanged();
                },
              ),
          ]),
          _group('Target countries', [
            for (final c in targetCountryOptions)
              LChip(
                label: countryName(c),
                selected: draft.countries.contains(c),
                onTap: () {
                  draft.countries.contains(c) ? draft.countries.remove(c) : draft.countries.add(c);
                  onChanged();
                },
              ),
          ]),
          _group('Funding preference', [
            for (final e in fundingLabels.entries)
              LChip(
                label: e.value,
                selected: draft.funding == e.key,
                onTap: () {
                  draft.funding = draft.funding == e.key ? null : e.key;
                  onChanged();
                },
              ),
          ]),
        ],
      );
}

class AcademicsSection extends StatelessWidget {
  const AcademicsSection({super.key, required this.draft, required this.onChanged, this.showErrors = false});

  final ProfileDraft draft;
  final VoidCallback onChanged;
  final bool showErrors;

  @override
  Widget build(BuildContext context) {
    final errors = showErrors ? draft.scoreErrors : const <String, String>{};
    Widget field(String label, String key, TextEditingController c, String hint, {bool text = false}) => LField(
          label: label,
          child: TextField(
            controller: c,
            keyboardType: text ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
            textCapitalization: text ? TextCapitalization.characters : TextCapitalization.none,
            decoration: lInputDecoration(hint: hint).copyWith(errorText: errors[key], errorMaxLines: 2),
            onChanged: (_) => onChanged(),
          ),
        );
    Widget group(String title, List<Widget> fields) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(title, style: ts(15, weight: FontWeight.w700)),
            LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth >= 300 ? 2 : 1;
                final width = (box.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [for (final f in fields) SizedBox(width: width, child: f)],
                );
              },
            ),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: L.s(22),
      children: [
        const _SectionTitle('Academics', 'Optional. Scores let us check minimum requirements for you.'),
        group('Grades', [field('GPA (0–4)', 'gpa', draft.gpa, 'e.g. 3.40')]),
        group('English tests', [
          field('IELTS', 'ielts', draft.ielts, '0 – 9'),
          field('TOEFL iBT', 'toefl', draft.toefl, '0 – 120'),
          field('Duolingo', 'duolingo', draft.duolingo, '10 – 160'),
        ]),
        group('Japanese and Korean tests', [
          field('JLPT (Japanese)', 'jlpt', draft.jlpt, 'N5 – N1', text: true),
          field('TOPIK (Korean)', 'topik', draft.topik, '1 – 6'),
        ]),
        if (showCvImport) const CvImportButton(),
      ],
    );
  }
}

/// CV import is not built yet, so its buttons stay hidden until it is. Flip to show them again.
const showCvImport = false;

class CvImportButton extends StatelessWidget {
  const CvImportButton({super.key, this.label = 'Import from CV (optional)'});

  final String label;

  @override
  Widget build(BuildContext context) => Material(
        color: LColors.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(L.r(12)),
          side: BorderSide(color: LColors.muted),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showToast(context, 'CV import arrives in a later sprint', icon: Icons.info_outline_rounded),
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file_rounded, size: 20, color: LColors.ink),
                const SizedBox(width: 8),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: ts(14, weight: FontWeight.w600))),
              ],
            ),
          ),
        ),
      );
}

/// Privacy & AI block: cloud toggle and Gemini Nano status / download.
class PrivacySection extends StatelessWidget {
  const PrivacySection({super.key, required this.cloudAllowed, required this.onCloudChanged, this.showTitle = true});

  final bool cloudAllowed;
  final ValueChanged<bool> onCloudChanged;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final dl = c.download;
    final fraction = c.downloadFraction;
    final canDownload =
        !c.downloading && c.aiStatus?.onDeviceModel == ModelAvailability.downloadable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 18,
      children: [
        if (showTitle) const _SectionTitle('Privacy & AI', "Choose how Lumina's assistant answers your questions."),
        LPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 24, color: LColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('On-device AI by default', style: ts(15, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Questions are answered on your phone. Nothing leaves your device unless you allow cloud AI.',
                      style: ts(14, color: LColors.text3, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        LCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Allow cloud AI', style: ts(15, weight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      'Sends your question and the relevant scholarship text to a server for faster answers.',
                      style: ts(14, color: LColors.text2, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              LToggle(value: cloudAllowed, onChanged: onCloudChanged, semanticLabel: 'Allow cloud AI'),
            ],
          ),
        ),
        LCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              _StatusRow(
                label: Text('On-device AI model', style: ts(15, weight: FontWeight.w600)),
                value: LBadge(c.modelStatusLabel),
              ),
              _StatusRow(
                label: Text('Inference mode', style: ts(14, color: LColors.text2)),
                value: Text(c.inferModeLabel, style: ts(14, weight: FontWeight.w600)),
              ),
              if (c.aiStatus?.onDeviceModelName != null)
                _StatusRow(
                  label: Text('Model', style: ts(14, color: LColors.text2)),
                  value: Text(c.aiStatus!.onDeviceModelName!, style: ts(14, weight: FontWeight.w600)),
                ),
              if (c.downloading) ...[
                LProgressBar(value: fraction ?? 0.05),
                Text(
                  fraction == null ? 'Downloading…' : 'Downloading… ${(fraction * 100).round()}%',
                  style: ts(14, color: LColors.text2),
                ),
              ] else if (canDownload)
                LButton(
                  label: 'Download AI model',
                  icon: Icons.download_rounded,
                  kind: LButtonKind.secondary,
                  height: 46,
                  radius: 12,
                  fontSize: 14,
                  onPressed: c.startModelDownload,
                ),
              if (dl?.state == DownloadState.failed)
                Text(dl!.errorMessage ?? 'Download failed. Try again.', style: ts(14, color: LColors.text2)),
              if (c.aiStatus?.onDeviceModel == ModelAvailability.unavailable)
                Text(
                  'This phone does not support on-device AI. Allow cloud AI to use the assistant.',
                  style: ts(14, color: LColors.text2, height: 1.4),
                ),
              if (c.aiStatus == null && c.aiStatusError != null)
                Text(c.aiStatusError!.userMessage, style: ts(14, color: LColors.text2, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

/// A name on the left and its value on the right; the value moves below when they do not fit.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final Widget label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [label, value],
      );
}

/// First-run setup: About you → Study goals → Academics → Privacy & AI.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final ProfileDraft _draft;
  int _step = 1;
  bool _busy = false;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final c = AppScope.read(context);
    _draft = ProfileDraft.from(c.profile ?? UserProfile(displayName: c.user?.displayName ?? ''));
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step--);
    } else {
      AppScope.read(context).signOut();
    }
  }

  Future<void> _next() async {
    if (_step == 3 && _draft.scoreErrors.isNotEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    if (_step < 4) {
      setState(() => _step++);
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.read(context).saveProfile(_draft.build(onboardingCompleted: true));
      if (mounted) showToast(context, 'Profile set up. Here are your matches');
    } on Object catch (e) {
      debugPrint('Lumina: onboarding save failed: $e');
      if (mounted) showToast(context, 'Could not save your profile. Try again.', icon: Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    void changed() => setState(() {});
    final section = switch (_step) {
      1 => AboutYouSection(draft: _draft, onChanged: changed),
      2 => StudyGoalsSection(draft: _draft, onChanged: changed),
      3 => AcademicsSection(draft: _draft, onChanged: changed, showErrors: _showErrors),
      _ => PrivacySection(
          cloudAllowed: _draft.cloudAllowed,
          onCloudChanged: (v) => setState(() => _draft.cloudAllowed = v),
        ),
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Gutter(
                builder: (context, side) => Container(
                  padding: EdgeInsets.fromLTRB(side, 10, side, 14),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: LColors.soft))),
                  child: Row(
                    children: [
                      LIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: _back),
                      const SizedBox(width: 14),
                      Expanded(child: LProgressBar(value: _step / 4)),
                      const SizedBox(width: 14),
                      Text('$_step of 4', style: ts(14, weight: FontWeight.w600, color: LColors.text2)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: PageSwitch(
                  page: _step,
                  child: Gutter(
                    builder: (context, side) => SingleChildScrollView(
                      // A new step starts at its top, not where the last one was scrolled to.
                      key: ValueKey(_step),
                      padding: EdgeInsets.fromLTRB(side, 24, side, 28),
                      child: section,
                    ),
                  ),
                ),
              ),
              LFooter(children: [
                LButton(label: _step == 4 ? 'Finish' : 'Next', height: 54, fontSize: 16, busy: _busy, onPressed: _next),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profile → Edit preferences (sections 1–3 on one page).
class EditPreferencesScreen extends StatefulWidget {
  const EditPreferencesScreen({super.key});

  @override
  State<EditPreferencesScreen> createState() => _EditPreferencesScreenState();
}

class _EditPreferencesScreenState extends State<EditPreferencesScreen> {
  late final ProfileDraft _draft;
  bool _busy = false;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _draft = ProfileDraft.from(AppScope.read(context).profile ?? const UserProfile());
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_draft.scoreErrors.isNotEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    try {
      await AppScope.read(context).saveProfile(_draft.build());
      if (mounted) {
        showToast(context, 'Preferences saved');
        nav.pop();
      }
    } on Object catch (e) {
      debugPrint('Lumina: preferences save failed: $e');
      if (mounted) showToast(context, 'Could not save. Try again.', icon: Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    void changed() => setState(() {});
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const LHeader(title: 'Edit preferences'),
            Expanded(
              child: Gutter(
                builder: (context, side) => SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(side, 20, side, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: L.s(20),
                    children: [
                      // One card per section, so the long form reads as three short ones.
                      for (final section in [
                        AboutYouSection(draft: _draft, onChanged: changed),
                        StudyGoalsSection(draft: _draft, onChanged: changed),
                        AcademicsSection(draft: _draft, onChanged: changed, showErrors: _showErrors),
                      ])
                        LCard(child: section),
                    ],
                  ),
                ),
              ),
            ),
            LFooter(children: [LButton(label: 'Save', height: 54, fontSize: 16, busy: _busy, onPressed: _save)]),
          ],
        ),
      ),
    );
  }
}

/// Profile → Privacy & AI. The cloud toggle saves immediately.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const LHeader(title: 'Privacy & AI'),
            Expanded(
              child: Gutter(
                builder: (context, side) => SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(side, 22, side, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PrivacySection(
                        showTitle: false,
                        // The latest choice, even while saving; questions follow c.cloudAllowed.
                        cloudAllowed: c.cloudSwitch,
                        // A failed save keeps cloud AI off on this phone and says so (controller notices).
                        onCloudChanged: c.setCloudAllowed,
                      ),
                      if (c.cloudSaving && c.cloudSwitch) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Saving… Cloud AI is used once your account has this setting.',
                          style: ts(14, color: LColors.text2, height: 1.4),
                        ),
                      ],
                      if (showCvImport) ...[
                        const SizedBox(height: 24),
                        Text('CV data', style: ts(16, weight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        const CvImportButton(label: 'Import CV'),
                        const SizedBox(height: 10),
                        Text(
                          'Your raw CV file is never stored. Only a short summary of skills and scores is kept.',
                          style: ts(14, color: LColors.text2, height: 1.45),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

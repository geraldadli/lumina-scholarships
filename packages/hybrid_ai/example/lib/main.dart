import 'dart:async';

import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:material_ui/material_ui.dart';

import 'sample_data.dart';

void main() => runApp(const LuminaAiLabApp());

/// Test tool for the hybrid_ai package on a device (NOT the Lumina product UI).
class LuminaAiLabApp extends StatelessWidget {
  const LuminaAiLabApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Lumina AI Lab',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF1F4E79), useMaterial3: true),
        home: const LabPage(),
      );
}

class LabPage extends StatefulWidget {
  const LabPage({super.key});

  @override
  State<LabPage> createState() => _LabPageState();
}

class _LabPageState extends State<LabPage> {
  final _ai = HybridAi();
  final _question = TextEditingController(text: sampleQuestions.first);
  final _scorer = const MatchScorer();

  AiStatus? _status;
  String? _statusError;
  DownloadProgress? _download;
  StreamSubscription<DownloadProgress>? _downloadSub;

  bool _allowCloud = true;
  bool _indonesian = false;
  ScholarshipContext _scholarship = sampleScholarships.first;

  bool _asking = false;
  AiAnswer? _answer;
  String? _askError;

  bool _checking = false;
  ChecklistResult? _checklist;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    _question.dispose();
    super.dispose();
  }

  String get _lang => _indonesian ? 'id' : 'en';

  Future<void> _refreshStatus() async {
    setState(() => _statusError = null);
    try {
      final status = await _ai.getStatus();
      if (mounted) setState(() => _status = status);
    } on HybridAiException catch (e) {
      if (mounted) setState(() => _statusError = '${e.userMessage} (${e.rawCode})');
    }
  }

  void _startDownload() {
    _downloadSub?.cancel();
    _downloadSub = _ai.downloadModel().listen(
      (p) => setState(() => _download = p),
      onError: (Object e) => setState(() => _statusError = e is HybridAiException ? '${e.userMessage} (${e.rawCode})' : '$e'),
      onDone: _refreshStatus,
    );
  }

  Future<void> _ask() async {
    setState(() {
      _asking = true;
      _answer = null;
      _askError = null;
    });
    try {
      final answer = await _ai.ask(AskRequest(
        question: _question.text,
        scholarship: _scholarship,
        student: sampleStudent,
        allowCloud: _allowCloud,
        languageCode: _lang,
      ));
      if (mounted) setState(() => _answer = answer);
    } on HybridAiException catch (e) {
      if (mounted) setState(() => _askError = '${e.userMessage}\nCode: ${e.rawCode}');
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _generateChecklist() async {
    setState(() {
      _checking = true;
      _checklist = null;
    });
    try {
      final result = await _ai.generateChecklist(ChecklistRequest(
        scholarship: _scholarship,
        student: sampleStudent,
        allowCloud: _allowCloud,
        languageCode: _lang,
      ));
      if (mounted) setState(() => _checklist = result);
    } on HybridAiException catch (e) {
      if (mounted) setState(() => _askError = '${e.userMessage}\nCode: ${e.rawCode}');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lumina AI Lab')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statusCard(),
          _settingsCard(),
          _matchCard(),
          _askCard(),
          _checklistCard(),
        ],
      ),
    );
  }

  // ───────────── Gemini Nano status & Remote Config ─────────────
  Widget _statusCard() {
    final s = _status;
    final downloading = _download != null &&
        _download!.state != DownloadState.completed &&
        _download!.state != DownloadState.failed;
    return _section(
      title: '1. AI status',
      trailing: IconButton(onPressed: _refreshStatus, icon: const Icon(Icons.refresh)),
      children: [
        if (_statusError != null) Text(_statusError!, style: const TextStyle(color: Colors.red)),
        if (s == null && _statusError == null) const LinearProgressIndicator(),
        if (s != null) ...[
          _kv('Gemini Nano', _availabilityLabel(s.onDeviceModel)),
          if (s.onDeviceModelName != null) _kv('On-device model', s.onDeviceModelName!),
          _kv('Mode (Remote Config)', s.inferenceMode),
          _kv('Cloud model', s.cloudModel),
          _kv('Match score threshold', s.minMatchScore.toStringAsFixed(2)),
          _kv('Remote Config', s.remoteConfigFetched ? 'fetched' : 'using defaults'),
          if (s.onDeviceModel == ModelAvailability.downloadable && !downloading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download),
                label: const Text('Download Gemini Nano'),
              ),
            ),
        ],
        if (_download != null) ...[
          const SizedBox(height: 8),
          Text('Download: ${_download!.state.name}${_download!.errorMessage == null ? '' : ' - ${_download!.errorMessage}'}'),
          if (downloading) LinearProgressIndicator(value: _downloadFraction(_download!)),
        ],
      ],
    );
  }

  // ───────────── Privacy & language ─────────────
  Widget _settingsCard() => _section(
        title: '2. Settings',
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow cloud AI'),
            subtitle: Text(_allowCloud
                ? 'Gemini Nano first, cloud if needed'
                : 'Private mode: Gemini Nano only, data never leaves the phone'),
            value: _allowCloud,
            onChanged: (v) => setState(() => _allowCloud = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Answer in Indonesian'),
            subtitle: const Text('Gemini Nano is most reliable in English'),
            value: _indonesian,
            onChanged: (v) => setState(() => _indonesian = v),
          ),
        ],
      );

  // ───────────── Scholarship & match score ─────────────
  Widget _matchCard() {
    final result = _scorer.score(sampleStudent, _scholarship);
    final threshold = _status?.minMatchScore ?? 0.65;
    return _section(
      title: '3. Scholarship & match score',
      children: [
        DropdownButton<ScholarshipContext>(
          isExpanded: true,
          value: _scholarship,
          items: [
            for (final s in sampleScholarships)
              DropdownMenuItem(value: s, child: Text('${s.title} (${s.status})', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (s) => setState(() {
            _scholarship = s!;
            _answer = null;
            _checklist = null;
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Score ${(result.score * 100).round()}% · ${result.meetsThreshold(threshold) ? 'MATCH' : 'not a match yet'}'
          '${result.eligible ? '' : ' · a mandatory requirement is not met'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        for (final r in result.reasons)
          Text('${switch (r.result) { CriterionResult.met => '✓', CriterionResult.notMet => '✗', CriterionResult.unknown => '?' }} ${r.message}'),
      ],
    );
  }

  // ───────────── Ask AI ─────────────
  Widget _askCard() => _section(
        title: '4. Ask AI',
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final q in sampleQuestions) ActionChip(label: Text(q), onPressed: () => setState(() => _question.text = q)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _question,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Question'),
          ),
          FilledButton.icon(
            onPressed: _asking ? null : _ask,
            icon: _asking
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(_asking ? 'Waiting for the answer…' : 'Ask AI'),
          ),
          if (_askError != null) ...[
            const SizedBox(height: 8),
            Text(_askError!, style: const TextStyle(color: Colors.red)),
          ],
          if (_answer != null) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, children: [
              Chip(label: Text(_sourceLabel(_answer!.source, _answer!.modelName))),
              Chip(label: Text('${_answer!.latencyMs} ms')),
            ]),
            const SizedBox(height: 6),
            SelectableText(_answer!.text),
            for (final url in _answer!.citations)
              Text('Source: $url', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ],
      );

  // ───────────── Prepare checklist ─────────────
  Widget _checklistCard() => _section(
        title: '5. Prepare checklist',
        children: [
          OutlinedButton.icon(
            onPressed: _checking ? null : _generateChecklist,
            icon: const Icon(Icons.checklist),
            label: Text(_checking ? 'Building…' : 'Create checklist'),
          ),
          if (_checklist != null) ...[
            const SizedBox(height: 8),
            Chip(label: Text(_sourceLabel(_checklist!.source, null))),
            if (_checklist!.note != null) Text(_checklist!.note!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            for (final item in _checklist!.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_box_outline_blank),
                title: Text(item.label),
                subtitle: item.tip == null ? null : Text(item.tip!),
              ),
          ],
        ],
      );

  // ───────────── Helper UI ─────────────
  Widget _section({required String title, Widget? trailing, required List<Widget> children}) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                ?trailing,
              ]),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(k, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(v)),
        ]),
      );

  static String _availabilityLabel(ModelAvailability a) => switch (a) {
        ModelAvailability.available => 'Available ✓',
        ModelAvailability.downloadable => 'Can be downloaded',
        ModelAvailability.downloading => 'Downloading…',
        ModelAvailability.unavailable => 'Not supported on this device',
        // The cause is unknown (see the "LuminaHybridAi" log): do not claim "not supported".
        ModelAvailability.unknown => 'On-device AI is unavailable',
      };

  static String _sourceLabel(AiSource s, String? model) => switch (s) {
        AiSource.onDevice => 'On-device${model == null ? '' : ' · $model'}',
        AiSource.cloud => 'Cloud${model == null ? '' : ' · $model'}',
        AiSource.rules => 'No AI (official requirements)',
      };

  static double? _downloadFraction(DownloadProgress p) {
    final total = p.totalBytes;
    final done = p.bytesDownloaded;
    if (total == null || total <= 0 || done == null) return null;
    return (done / total).clamp(0.0, 1.0);
  }
}

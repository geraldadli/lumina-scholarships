import 'dart:async';

import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:material_ui/material_ui.dart';

import 'sample_data.dart';

void main() => runApp(const LuminaAiLabApp());

/// Alat uji paket hybrid_ai di perangkat (BUKAN UI produk Lumina).
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
  bool _english = false;
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

  String get _lang => _english ? 'en' : 'id';

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
      if (mounted) setState(() => _askError = '${e.userMessage}\nKode: ${e.rawCode}');
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
      if (mounted) setState(() => _askError = '${e.userMessage}\nKode: ${e.rawCode}');
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

  // ───────────── Status Gemini Nano & Remote Config ─────────────
  Widget _statusCard() {
    final s = _status;
    final downloading = _download != null &&
        _download!.state != DownloadState.completed &&
        _download!.state != DownloadState.failed;
    return _section(
      title: '1. Status AI',
      trailing: IconButton(onPressed: _refreshStatus, icon: const Icon(Icons.refresh)),
      children: [
        if (_statusError != null) Text(_statusError!, style: const TextStyle(color: Colors.red)),
        if (s == null && _statusError == null) const LinearProgressIndicator(),
        if (s != null) ...[
          _kv('Gemini Nano', _availabilityLabel(s.onDeviceModel)),
          if (s.onDeviceModelName != null) _kv('Model perangkat', s.onDeviceModelName!),
          _kv('Mode (Remote Config)', s.inferenceMode),
          _kv('Model cloud', s.cloudModel),
          _kv('Ambang skor cocok', s.minMatchScore.toStringAsFixed(2)),
          _kv('Remote Config', s.remoteConfigFetched ? 'terambil' : 'pakai default'),
          if (s.onDeviceModel == ModelAvailability.downloadable && !downloading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download),
                label: const Text('Unduh Gemini Nano'),
              ),
            ),
        ],
        if (_download != null) ...[
          const SizedBox(height: 8),
          Text('Unduhan: ${_download!.state.name}${_download!.errorMessage == null ? '' : ' - ${_download!.errorMessage}'}'),
          if (downloading) LinearProgressIndicator(value: _downloadFraction(_download!)),
        ],
      ],
    );
  }

  // ───────────── Privasi & bahasa ─────────────
  Widget _settingsCard() => _section(
        title: '2. Pengaturan',
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Izinkan AI cloud'),
            subtitle: Text(_allowCloud
                ? 'Gemini Nano dulu, cloud bila perlu'
                : 'Mode privat: hanya Gemini Nano, data tidak keluar dari HP'),
            value: _allowCloud,
            onChanged: (v) => setState(() => _allowCloud = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Jawab dalam bahasa Inggris'),
            subtitle: const Text('Nano paling stabil untuk bahasa Inggris'),
            value: _english,
            onChanged: (v) => setState(() => _english = v),
          ),
        ],
      );

  // ───────────── Beasiswa & skor kecocokan ─────────────
  Widget _matchCard() {
    final result = _scorer.score(sampleStudent, _scholarship);
    final threshold = _status?.minMatchScore ?? 0.65;
    return _section(
      title: '3. Beasiswa & skor kecocokan',
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
          'Skor ${(result.score * 100).round()}% · ${result.meetsThreshold(threshold) ? 'COCOK' : 'belum cocok'}'
          '${result.eligible ? '' : ' · ada syarat wajib tidak terpenuhi'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        for (final r in result.reasons)
          Text('${switch (r.result) { CriterionResult.met => '✓', CriterionResult.notMet => '✗', CriterionResult.unknown => '?' }} ${r.message}'),
      ],
    );
  }

  // ───────────── Ask AI ─────────────
  Widget _askCard() => _section(
        title: '4. Tanya AI',
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
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Pertanyaan'),
          ),
          FilledButton.icon(
            onPressed: _asking ? null : _ask,
            icon: _asking
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(_asking ? 'Menunggu jawaban…' : 'Tanya AI'),
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
              Text('Sumber: $url', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ],
      );

  // ───────────── Checklist Prepare ─────────────
  Widget _checklistCard() => _section(
        title: '5. Checklist Prepare',
        children: [
          OutlinedButton.icon(
            onPressed: _checking ? null : _generateChecklist,
            icon: const Icon(Icons.checklist),
            label: Text(_checking ? 'Menyusun…' : 'Buat checklist'),
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
        ModelAvailability.available => 'Tersedia ✓',
        ModelAvailability.downloadable => 'Bisa diunduh',
        ModelAvailability.downloading => 'Sedang diunduh…',
        ModelAvailability.unavailable => 'Tidak didukung perangkat',
      };

  static String _sourceLabel(AiSource s, String? model) => switch (s) {
        AiSource.onDevice => 'Di perangkat${model == null ? '' : ' · $model'}',
        AiSource.cloud => 'Cloud${model == null ? '' : ' · $model'}',
        AiSource.rules => 'Tanpa AI (syarat resmi)',
      };

  static double? _downloadFraction(DownloadProgress p) {
    final total = p.totalBytes;
    final done = p.bytesDownloaded;
    if (total == null || total <= 0 || done == null) return null;
    return (done / total).clamp(0.0, 1.0);
  }
}

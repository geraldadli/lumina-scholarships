import 'hybrid_ai.g.dart';

/// Kriteria yang dinilai [MatchScorer].
enum MatchCriterion { citizenship, educationLevel, gpa, fieldOfStudy, hostCountry, status }

/// Hasil penilaian satu kriteria.
enum CriterionResult {
  /// Memenuhi.
  met,

  /// Tidak memenuhi.
  notMet,

  /// Data profil / beasiswa belum lengkap sehingga belum bisa dinilai.
  unknown,
}

class MatchReason {
  const MatchReason(this.criterion, this.result, this.message);

  final MatchCriterion criterion;
  final CriterionResult result;

  /// Penjelasan singkat (Bahasa Indonesia) untuk ditampilkan di UI.
  final String message;
}

class MatchResult {
  const MatchResult({required this.score, required this.eligible, required this.reasons});

  /// 0.0–1.0. Bandingkan dengan Remote Config `min_match_score_threshold` (lihat [AiStatus.minMatchScore]).
  final double score;

  /// `false` bila ada syarat wajib yang jelas tidak terpenuhi (kewarganegaraan, jenjang, IPK, status ditutup).
  final bool eligible;
  final List<MatchReason> reasons;

  bool meetsThreshold(double threshold) => eligible && score >= threshold;
}

/// Skor kecocokan mahasiswa ↔ beasiswa berbasis aturan: cepat, konsisten, bisa offline,
/// dan bisa dijelaskan. AI dipakai untuk MENJELASKAN hasil ini, bukan menggantikannya.
///
/// Bobot: kewarganegaraan 0.30, jenjang 0.25, IPK 0.20, bidang studi 0.15, negara tujuan 0.10.
/// Kriteria yang belum bisa dinilai mendapat setengah bobot.
class MatchScorer {
  const MatchScorer();

  static const _weights = <MatchCriterion, double>{
    MatchCriterion.citizenship: 0.30,
    MatchCriterion.educationLevel: 0.25,
    MatchCriterion.gpa: 0.20,
    MatchCriterion.fieldOfStudy: 0.15,
    MatchCriterion.hostCountry: 0.10,
  };

  /// Skor maksimum bila ada syarat wajib yang tidak terpenuhi (di bawah ambang default 0.65).
  static const ineligibleCap = 0.4;

  static const _hard = {
    MatchCriterion.citizenship,
    MatchCriterion.educationLevel,
    MatchCriterion.gpa,
    MatchCriterion.status,
  };

  MatchResult score(StudentContext student, ScholarshipContext scholarship) {
    final reasons = <MatchReason>[
      _citizenship(student, scholarship),
      _educationLevel(student, scholarship),
      _gpa(student, scholarship),
      _fieldOfStudy(student, scholarship),
      _hostCountry(student, scholarship),
      if (scholarship.status.toLowerCase() == 'closed')
        const MatchReason(MatchCriterion.status, CriterionResult.notMet, 'Pendaftaran sudah ditutup.'),
    ];

    var total = 0.0;
    for (final r in reasons) {
      final w = _weights[r.criterion] ?? 0;
      total += switch (r.result) {
        CriterionResult.met => w,
        CriterionResult.unknown => w / 2,
        CriterionResult.notMet => 0,
      };
    }
    final eligible = !reasons.any((r) => _hard.contains(r.criterion) && r.result == CriterionResult.notMet);
    if (!eligible && total > ineligibleCap) total = ineligibleCap;
    return MatchResult(score: double.parse(total.toStringAsFixed(2)), eligible: eligible, reasons: reasons);
  }

  MatchReason _citizenship(StudentContext st, ScholarshipContext s) {
    final c = _country(st.citizenship);
    if (c == null) return const MatchReason(MatchCriterion.citizenship, CriterionResult.unknown, 'Kewarganegaraan belum diisi di profil.');
    final allowed = s.eligibleCitizenships.map(_country).whereType<String>().toSet();
    if (allowed.isEmpty) return const MatchReason(MatchCriterion.citizenship, CriterionResult.unknown, 'Syarat kewarganegaraan belum tersedia.');
    return allowed.contains('GLOBAL') || allowed.contains(c)
        ? const MatchReason(MatchCriterion.citizenship, CriterionResult.met, 'Kewarganegaraan memenuhi syarat.')
        : const MatchReason(MatchCriterion.citizenship, CriterionResult.notMet, 'Kewarganegaraan tidak termasuk yang diizinkan.');
  }

  MatchReason _educationLevel(StudentContext st, ScholarshipContext s) {
    final level = st.educationLevel?.trim().toLowerCase();
    if (level == null || level.isEmpty) {
      return const MatchReason(MatchCriterion.educationLevel, CriterionResult.unknown, 'Jenjang tujuan belum diisi di profil.');
    }
    final levels = s.educationLevels.map((e) => e.trim().toLowerCase()).toSet();
    if (levels.isEmpty) return const MatchReason(MatchCriterion.educationLevel, CriterionResult.unknown, 'Jenjang beasiswa belum tersedia.');
    return levels.contains(level)
        ? const MatchReason(MatchCriterion.educationLevel, CriterionResult.met, 'Jenjang studi sesuai.')
        : const MatchReason(MatchCriterion.educationLevel, CriterionResult.notMet, 'Beasiswa ini tidak membuka jenjang yang kamu tuju.');
  }

  MatchReason _gpa(StudentContext st, ScholarshipContext s) {
    final min = s.minGpa;
    if (min == null || min <= 0) return const MatchReason(MatchCriterion.gpa, CriterionResult.met, 'Tidak ada syarat IPK minimum.');
    final gpa = st.gpa;
    if (gpa == null) return const MatchReason(MatchCriterion.gpa, CriterionResult.unknown, 'IPK belum diisi di profil.');
    return gpa >= min
        ? MatchReason(MatchCriterion.gpa, CriterionResult.met, 'IPK ${_fmt(gpa)} memenuhi minimum ${_fmt(min)}.')
        : MatchReason(MatchCriterion.gpa, CriterionResult.notMet, 'IPK ${_fmt(gpa)} di bawah minimum ${_fmt(min)}.');
  }

  MatchReason _fieldOfStudy(StudentContext st, ScholarshipContext s) {
    final offered = s.fieldsOfStudy.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
    if (offered.contains('all')) return const MatchReason(MatchCriterion.fieldOfStudy, CriterionResult.met, 'Terbuka untuk semua bidang studi.');
    // `[]` di kontrak data = bidang belum diumumkan: jangan dianggap tidak cocok.
    if (offered.isEmpty) return const MatchReason(MatchCriterion.fieldOfStudy, CriterionResult.unknown, 'Bidang studi belum diumumkan penyelenggara.');
    final mine = st.fieldsOfStudy.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
    if (mine.isEmpty) return const MatchReason(MatchCriterion.fieldOfStudy, CriterionResult.unknown, 'Bidang studi belum diisi di profil.');
    final match = mine.any((m) => offered.any((o) => o.contains(m) || m.contains(o)));
    return match
        ? const MatchReason(MatchCriterion.fieldOfStudy, CriterionResult.met, 'Bidang studi sesuai.')
        : const MatchReason(MatchCriterion.fieldOfStudy, CriterionResult.notMet, 'Bidang studi kamu tidak tercantum.');
  }

  MatchReason _hostCountry(StudentContext st, ScholarshipContext s) {
    final hosts = s.hostCountries.map(_country).whereType<String>().toSet();
    final targets = st.targetCountries.map(_country).whereType<String>().toSet();
    if (targets.isEmpty) return const MatchReason(MatchCriterion.hostCountry, CriterionResult.unknown, 'Negara tujuan belum diisi di profil.');
    if (hosts.isEmpty) return const MatchReason(MatchCriterion.hostCountry, CriterionResult.unknown, 'Negara tujuan beasiswa belum tersedia.');
    return hosts.contains('GLOBAL') || hosts.any(targets.contains)
        ? const MatchReason(MatchCriterion.hostCountry, CriterionResult.met, 'Negara tujuan sesuai preferensi.')
        : const MatchReason(MatchCriterion.hostCountry, CriterionResult.notMet, 'Negara tujuan berbeda dari preferensi.');
  }

  /// Normalisasi kode negara: huruf besar, `UK` (data lama) dianggap `GB`.
  static String? _country(String? raw) {
    final c = raw?.trim().toUpperCase();
    if (c == null || c.isEmpty) return null;
    return c == 'UK' ? 'GB' : c;
  }

  static String _fmt(double v) => v.toStringAsFixed(2);
}

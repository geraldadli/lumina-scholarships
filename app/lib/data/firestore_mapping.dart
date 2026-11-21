import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hybrid_ai/hybrid_ai.dart';

import '../models.dart';

/// Firestore <-> model mapping, following docs/firestore-contract.md.

String _code(String c) => c == 'UK' ? 'GB' : c; // contract: treat legacy UK as GB
List<String> _strs(dynamic v) => (v as List? ?? const []).whereType<String>().toList();
DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

/// `scholarships/{id}` (§1).
Scholarship scholarshipFromFirestore(String id, Map<String, dynamic> d) => Scholarship(
      id: id,
      title: d['title'] as String? ?? id,
      provider: d['provider'] as String? ?? '',
      description: d['description'] as String? ?? '',
      fundingType: d['fundingType'] as String? ?? 'full',
      educationLevels: _strs(d['educationLevels']),
      eligibleCitizenships: _strs(d['eligibleCitizenships']).map(_code).toList(),
      hostCountries: _strs(d['hostCountries']).map(_code).toList(),
      fieldsOfStudy: _strs(d['fieldsOfStudy']),
      minGpa: (d['minGpa'] as num?)?.toDouble(),
      languageRequirement: d['languageRequirement'] as String?,
      openDate: _ts(d['openDate']),
      deadline: _ts(d['deadline']) ?? DateTime.now(),
      status: d['status'] as String? ?? 'closed',
      sourceUrl: d['sourceUrl'] as String? ?? '',
      requirements: [
        for (final r in (d['requirements'] as List? ?? const []))
          if (r is Map) RequirementItem(id: '${r['id']}', label: '${r['label']}'),
      ],
      benefits: _strs(d['benefits']),
      notes: d['notes'] as String?,
      verificationStatus: d['verificationStatus'] as String? ?? 'pending',
      lastChangeSummary: d['lastChangeSummary'] as String?,
      updatedAt: _ts(d['updatedAt']),
    );

/// `users/{uid}` (§2) -> fills [p].
void profileFromFirestore(UserProfile p, Map<String, dynamic> d) {
  p.displayName = d['displayName'] as String? ?? '';
  p.citizenship = d['citizenship'] as String? ?? p.citizenship;
  p.currentEducationLevel = d['currentEducationLevel'] as String?;
  p.educationLevel = d['educationLevel'] as String?;
  p.fieldsOfStudy = _strs(d['fieldsOfStudy']);
  p.targetCountries = _strs(d['targetCountries']);
  p.fundingPreference = d['fundingPreference'] as String? ?? 'any';
  p.gpa = (d['gpa'] as num?)?.toDouble();
  p.languageScores = {
    for (final e in ((d['languageScores'] as Map?) ?? const {}).entries)
      if (e.value != null) '${e.key}': e.value as Object,
  };
  p.cloudAiAllowed = ((d['privacy'] as Map?)?['cloudAiAllowed'] as bool?) ?? false;
  p.onboardingCompleted = d['onboardingCompleted'] as bool? ?? false;
}

/// Only fields the rules (`validProfile`) accept; absent values are left out.
Map<String, dynamic> profileToFirestore(UserProfile p) => {
      'displayName': p.displayName,
      if (p.citizenship != null) 'citizenship': p.citizenship,
      if (p.currentEducationLevel != null) 'currentEducationLevel': p.currentEducationLevel,
      if (p.educationLevel != null) 'educationLevel': p.educationLevel,
      'fieldsOfStudy': p.fieldsOfStudy.take(20).toList(),
      'targetCountries': p.targetCountries.take(30).toList(),
      'fundingPreference': p.fundingPreference,
      'gpa': p.gpa,
      'languageScores': p.languageScores,
      'privacy': {'cloudAiAllowed': p.cloudAiAllowed},
      'onboardingCompleted': p.onboardingCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
    };

/// `users/{uid}/saved_scholarships/{id}` (§3).
SavedScholarship savedFromFirestore(String id, Map<String, dynamic> d) {
  final s = SavedScholarship(
    scholarshipId: id,
    status: d['status'] as String? ?? 'saved',
    lastSeenUpdatedAt: _ts(d['lastSeenUpdatedAt']),
  );
  s.notes = d['notes'] as String? ?? '';
  s.checklist = [
    for (final c in (d['checklist'] as List? ?? const []))
      if (c is Map)
        ChecklistEntry(
          id: '${c['id']}',
          label: '${c['label']}',
          tip: c['tip'] as String?,
          done: c['done'] == true,
        ),
  ];
  return s;
}

Map<String, dynamic> savedToFirestore(SavedScholarship s, {double? matchScore}) => {
      'scholarshipId': s.scholarshipId,
      'status': s.status,
      if (matchScore != null) 'matchScore': matchScore.clamp(0.0, 1.0),
      'checklist': [
        for (final c in s.checklist.take(50))
          {'id': c.id, 'label': c.label, 'done': c.done, if (c.tip != null) 'tip': c.tip},
      ],
      'notes': s.notes.length > 5000 ? s.notes.substring(0, 5000) : s.notes,
      'lastSeenUpdatedAt': s.lastSeenUpdatedAt == null ? null : Timestamp.fromDate(s.lastSeenUpdatedAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };

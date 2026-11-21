/// `users/{uid}/saved_scholarships/{scholarshipId}`, see docs/firestore-contract.md section 3.
library;

const savedStatuses = ['saved', 'preparing', 'applied'];
const savedStatusLabels = {'saved': 'Saved', 'preparing': 'Preparing', 'applied': 'Applied'};

class ChecklistEntry {
  const ChecklistEntry({required this.id, required this.label, this.done = false});

  final String id;
  final String label;
  final bool done;

  ChecklistEntry toggled() => ChecklistEntry(id: id, label: label, done: !done);

  Map<String, Object> toMap() => {'id': id, 'label': label, 'done': done};

  factory ChecklistEntry.fromMap(Map<String, dynamic> m) => ChecklistEntry(
        id: m['id'] as String? ?? '',
        label: m['label'] as String? ?? '',
        done: m['done'] == true,
      );
}

class SavedScholarship {
  const SavedScholarship({
    required this.scholarshipId,
    required this.status,
    this.matchScore,
    this.checklist = const [],
    this.notes = '',
    this.lastSeenUpdatedAt,
    this.savedAt,
  });

  final String scholarshipId;

  /// `saved` | `preparing` | `applied`
  final String status;

  /// 0–1, from the match scorer at save time.
  final double? matchScore;

  /// Max 50 items (enforced by the rules).
  final List<ChecklistEntry> checklist;

  /// Max 5000 characters.
  final String notes;
  final DateTime? lastSeenUpdatedAt;
  final DateTime? savedAt;

  int get doneCount => checklist.where((c) => c.done).length;

  SavedScholarship copyWith({
    String? status,
    List<ChecklistEntry>? checklist,
    String? notes,
    DateTime? lastSeenUpdatedAt,
  }) =>
      SavedScholarship(
        scholarshipId: scholarshipId,
        status: status ?? this.status,
        matchScore: matchScore,
        checklist: checklist ?? this.checklist,
        notes: notes ?? this.notes,
        lastSeenUpdatedAt: lastSeenUpdatedAt ?? this.lastSeenUpdatedAt,
        savedAt: savedAt,
      );
}

/// A partial update to a saved scholarship. Null fields are left unchanged.
class SavedPatch {
  const SavedPatch({this.status, this.checklist, this.notes, this.lastSeenUpdatedAt});

  final String? status;
  final List<ChecklistEntry>? checklist;
  final String? notes;
  final DateTime? lastSeenUpdatedAt;
}

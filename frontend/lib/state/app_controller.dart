import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hybrid_ai/hybrid_ai.dart';

import '../data/backend.dart';
import '../models/saved_scholarship.dart';
import '../models/scholarship.dart';
import '../models/user_profile.dart';
import '../util/format.dart';
import 'browse_filters.dart';

/// Remote Config `min_match_score_threshold` default (contract section 6), used until
/// `HybridAi.getStatus()` reports the live value.
const defaultMinMatchScore = 0.65;

enum ChatRole { user, ai }

class ChatMessage {
  const ChatMessage.user(this.text)
      : role = ChatRole.user,
        source = null,
        citations = const [];

  const ChatMessage.ai(this.text, {required this.source, required this.citations}) : role = ChatRole.ai;

  final ChatRole role;
  final String text;
  final AiSource? source;
  final List<String> citations;
}

/// Ask-AI state for one scholarship.
class ChatThread {
  final messages = <ChatMessage>[];
  bool thinking = false;

  /// The last failure, shown as the "AI unavailable" card until the next attempt.
  HybridAiException? error;
  String? failedQuestion;

  /// Whether cloud AI was allowed for the last question sent (the one in [failedQuestion] if it failed).
  bool askedWithCloud = false;
}

/// App-wide state: session, profile, catalog, saved scholarships and AI.
class AppController extends ChangeNotifier {
  AppController({required this.backend, required this.ai, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final LuminaBackend backend;
  final HybridAi ai;
  final DateTime Function() _clock;

  DateTime get now => _clock();

  // ───────────── Session ─────────────

  AuthUser? user;
  bool authResolved = false;
  UserProfile? profile;
  bool profileLoaded = false;

  List<Scholarship> scholarships = const [];
  bool catalogLoaded = false;
  Object? catalogError;

  Map<String, SavedScholarship> saved = const {};

  StreamSubscription<AuthUser?>? _authSub;
  final _userSubs = <StreamSubscription<Object?>>[];
  StreamSubscription<List<Scholarship>>? _catalogSub;

  /// Bottom-nav tab (0 home, 1 browse, 2 saved, 3 profile) and the Saved segment.
  int tab = 0;
  String savedSegment = 'saved';

  final filters = BrowseFilters();
  bool _filtersSeeded = false;

  void start() {
    _authSub ??= backend.authState().listen(_onAuth);
    unawaited(refreshAiStatus());
  }

  void _onAuth(AuthUser? u) {
    for (final s in _userSubs) {
      s.cancel();
    }
    _userSubs.clear();
    _catalogSub?.cancel();
    _catalogSub = null;
    user = u;
    authResolved = true;
    profile = null;
    profileLoaded = false;
    saved = const {};
    scholarships = const [];
    catalogLoaded = false;
    catalogError = null;
    chats.clear();
    _matchCache.clear();
    checklistTips.clear();
    checklistSource.clear();
    tab = 0;
    savedSegment = 'saved';
    _filtersSeeded = false;
    filters.reset();
    if (u != null) {
      _userSubs
        ..add(backend.profile(u.uid).listen((p) {
          profile = p;
          profileLoaded = true;
          _matchCache.clear();
          _seedFilters();
          notifyListeners();
        }, onError: (Object e) {
          debugPrint('Lumina: profile stream failed: $e');
          profileLoaded = true;
          notifyListeners();
        }))
        ..add(backend.saved(u.uid).listen((m) {
          saved = m;
          notifyListeners();
        }, onError: (Object e) => debugPrint('Lumina: saved stream failed: $e')));
      _subscribeCatalog();
    }
    notifyListeners();
  }

  /// A failed Firestore listener stays failed, so "Try again" opens a new one.
  void _subscribeCatalog() {
    _catalogSub = backend.scholarships().listen((list) {
      scholarships = list;
      catalogLoaded = true;
      catalogError = null;
      _matchCache.clear();
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Lumina: catalog stream failed: $e');
      catalogError = e;
      catalogLoaded = true;
      notifyListeners();
    });
  }

  /// "Try again" on the couldn't-load-scholarships message.
  void retryCatalog() {
    if (user == null) return;
    _catalogSub?.cancel();
    catalogLoaded = false;
    catalogError = null;
    notifyListeners();
    _subscribeCatalog();
  }

  /// Browse starts filtered to the student's target level and citizenship (prototype defaults).
  void _seedFilters() {
    if (_filtersSeeded || profile == null) return;
    _filtersSeeded = true;
    final level = profile!.educationLevel;
    if (level != null) filters.levels.add(level);
  }

  // ───────────── Write failures ─────────────

  final _notices = StreamController<String>.broadcast();

  /// Messages for writes that failed. The app shows them as a toast from the root, so they
  /// still appear when the screen that started the write has already closed (e.g. notes).
  Stream<String> get notices => _notices.stream;

  /// Runs a Firestore write; on failure reports [failure] on [notices] and returns false.
  Future<bool> _write(Future<void> Function() call, String failure) async {
    try {
      await call();
      return true;
    } on Object catch (e) {
      debugPrint('Lumina: $failure ($e)');
      if (!_notices.isClosed) _notices.add(failure);
      return false;
    }
  }

  @override
  void dispose() {
    _notices.close();
    _authSub?.cancel();
    _catalogSub?.cancel();
    for (final s in _userSubs) {
      s.cancel();
    }
    _downloadSub?.cancel();
    super.dispose();
  }

  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  void setSavedSegment(String s) {
    savedSegment = s;
    notifyListeners();
  }

  void filtersChanged() => notifyListeners();

  /// The live catalog has loaded, so a saved id missing from it really was withdrawn.
  bool get catalogReady => catalogLoaded && catalogError == null;

  Scholarship? byId(String id) {
    for (final s in scholarships) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ───────────── Profile ─────────────

  Future<void> saveProfile(UserProfile p) async {
    final u = user;
    if (u == null) return;
    final isNew = profile == null;
    await backend.saveProfile(u.uid, p, isNew: isNew);
  }

  /// Takes effect at once, so a question asked right after uses the new choice: the profile
  /// stream only reports it once Firestore has the write. Put back if the write fails.
  Future<void> setCloudAllowed(bool allowed) async {
    final p = profile;
    if (p == null) return;
    final next = p.copyWith(cloudAiAllowed: allowed);
    profile = next;
    notifyListeners();
    try {
      await saveProfile(next);
    } on Object {
      if (identical(profile, next)) {
        profile = p;
        notifyListeners();
      }
      rethrow;
    }
  }

  bool get cloudAllowed => profile?.cloudAiAllowed ?? false;

  // ───────────── Match score (hybrid_ai MatchScorer) ─────────────

  final _matchCache = <String, MatchResult>{};

  MatchResult matchFor(Scholarship s) => _matchCache.putIfAbsent(
        s.id,
        () => const MatchScorer().score((profile ?? const UserProfile()).toStudentContext(), s.toContext()),
      );

  double get minMatchScore => aiStatus?.minMatchScore ?? defaultMinMatchScore;

  int matchPercent(Scholarship s) => (matchFor(s).score * 100).round();

  // ───────────── Catalog views ─────────────

  List<Scholarship> get openScholarships => scholarships.where((s) => !s.isClosedAt(now)).toList();

  List<Scholarship> get closingSoon =>
      openScholarships.where((s) => s.isUrgentAt(now) && !s.isUpcomingAt(now)).toList();

  List<Scholarship> get bestMatches {
    final list = openScholarships.where((s) => !s.isUpcomingAt(now) && matchFor(s).eligible).toList()
      ..sort((a, b) => matchFor(b).score.compareTo(matchFor(a).score));
    return list.take(2).toList();
  }

  List<Scholarship> get openingSoon => openScholarships.where((s) => s.isUpcomingAt(now)).toList();

  List<Scholarship> get browseResults => filters.apply(scholarships, profile: profile, now: now, matchScore: (s) => matchFor(s).score);

  /// "Updated" badge: `scholarship.updatedAt > saved.lastSeenUpdatedAt` (contract section 3).
  bool hasUpdate(Scholarship s) {
    final sv = saved[s.id];
    if (sv == null || s.lastChangeSummary == null || s.updatedAt == null) return false;
    final seen = sv.lastSeenUpdatedAt;
    return seen == null || s.updatedAt!.isAfter(seen);
  }

  List<Scholarship> get savedWithUpdates => scholarships.where(hasUpdate).toList();

  // ───────────── Save → Prepare → Apply ─────────────

  bool isSaved(String id) => saved.containsKey(id);

  /// Returns the toast message for the action taken, without waiting for the write.
  ///
  /// Firestore shows a write locally at once but only confirms it once the server has it, so
  /// waiting would hold the toast for as long as the phone is offline. A failure arrives on
  /// [notices] instead.
  String toggleSave(Scholarship s) {
    final u = user;
    if (u == null) return 'Sign in to save scholarships';
    if (isSaved(s.id)) {
      unawaited(_write(() => backend.unsave(u.uid, s.id), 'Could not remove it from saved. Try again.'));
      return 'Removed from saved';
    }
    unawaited(_write(() => backend.save(u.uid, s, matchScore: matchFor(s).score), 'Could not save it. Try again.'));
    return 'Saved. Track it in the Saved tab';
  }

  Future<bool> setStatus(Scholarship s, String status) async {
    final u = user;
    if (u == null) return false;
    return _write(
      () => isSaved(s.id)
          ? backend.updateSaved(u.uid, s.id, SavedPatch(status: status))
          : backend.save(u.uid, s, matchScore: matchFor(s).score, status: status),
      'Could not change the status. Try again.',
    );
  }

  /// Takes an id so a saved scholarship that left the catalog can still be removed.
  Future<bool> unsave(String scholarshipId) async {
    final u = user;
    if (u == null) return false;
    return _write(() => backend.unsave(u.uid, scholarshipId), 'Could not remove it from saved. Try again.');
  }

  /// Rewrites `lastSeenUpdatedAt` after the details are opened.
  Future<void> markSeen(Scholarship s) async {
    final u = user;
    if (u == null || !hasUpdate(s)) return;
    await backend.updateSaved(u.uid, s.id, SavedPatch(lastSeenUpdatedAt: s.updatedAt));
  }

  /// "Prepare": moves the scholarship to `preparing` and copies the official requirements
  /// into the checklist the first time (contract section 3).
  Future<bool> startPreparing(Scholarship s) async {
    final u = user;
    if (u == null) return false;
    final cur = saved[s.id];
    final fromRequirements = [for (final r in s.requirements) ChecklistEntry(id: r.id, label: r.label)];
    return _write(
      () => cur == null
          ? backend.save(u.uid, s, matchScore: matchFor(s).score, status: 'preparing', checklist: fromRequirements)
          : backend.updateSaved(
              u.uid,
              s.id,
              SavedPatch(
                status: cur.status == 'saved' ? 'preparing' : null,
                checklist: cur.checklist.isEmpty ? fromRequirements : null,
              ),
            ),
      'Could not start preparing. Try again.',
    );
  }

  /// The signed-in user, or null if nobody is, or if [uid] is given and someone else is now.
  /// Work started in one session (a slow AI call, a notes flush) passes its [uid] so it is
  /// dropped instead of being written into the account signed in after it.
  AuthUser? _session([String? uid]) {
    final u = user;
    return u == null || (uid != null && u.uid != uid) ? null : u;
  }

  Future<bool> setChecklist(Scholarship s, List<ChecklistEntry> items, {String? uid}) async {
    final u = _session(uid);
    if (u == null || !isSaved(s.id)) return false;
    return _write(
      () => backend.updateSaved(u.uid, s.id, SavedPatch(checklist: items.take(50).toList())),
      'Could not save your checklist. Try again.',
    );
  }

  /// [uid]: the account the notes were typed in (see [_session]).
  Future<bool> setNotes(Scholarship s, String notes, {String? uid}) async {
    final u = _session(uid);
    if (u == null || !isSaved(s.id)) return false;
    return _write(() => backend.updateSaved(u.uid, s.id, SavedPatch(notes: notes)), 'Could not save your notes.');
  }

  /// AI tips per checklist item id, from the last `generateChecklist` call (not persisted:
  /// the contract's checklist items are `{id, label, done}` only).
  final checklistTips = <String, Map<String, String>>{};
  final checklistSource = <String, AiSource>{};

  /// "Regenerate with AI". Never fails because of AI: the plugin falls back to the official
  /// requirements (`AiSource.rules`). Keeps `done` for items that survive and the user's own items.
  Future<String> regenerateChecklist(Scholarship s) async {
    final uid = user?.uid;
    if (uid == null || !isSaved(s.id)) return 'Save the scholarship first';
    final ChecklistResult result;
    try {
      result = await ai.generateChecklist(ChecklistRequest(
        scholarship: s.toContext(),
        student: profile?.toStudentContext(),
        allowCloud: cloudAllowed,
        languageCode: 'en',
      ));
    } on HybridAiException catch (e) {
      return e.userMessage;
    } on Object catch (e) {
      debugPrint('Lumina: checklist failed: $e');
      return 'Could not regenerate the checklist. Try again.';
    }
    // The AI call can take a while: the student may have switched accounts or removed the
    // scholarship meanwhile, and ticked items while waiting, so re-read the state now.
    if (user == null) return 'You signed out, so the checklist was not changed.';
    if (_session(uid) == null) return 'You switched accounts, so the checklist was not changed.';
    final cur = saved[s.id];
    if (cur == null) return 'Save the scholarship first';
    final doneIds = {for (final c in cur.checklist) if (c.done) c.id};
    final aiIds = {for (final i in result.items) i.id};
    final custom = cur.checklist.where((c) => c.id.startsWith('custom-') && !aiIds.contains(c.id));
    final items = [
      for (final i in result.items) ChecklistEntry(id: i.id, label: i.label, done: doneIds.contains(i.id)),
      ...custom,
    ];
    // Only show AI tips and the "Sourced · AI" badge for a checklist that was actually saved.
    if (!await setChecklist(s, items, uid: uid)) return 'Could not save your checklist. Try again.';
    // Check again: the account can change while Firestore confirms the write, and the tips
    // belong to account [uid] only. Its checklist is saved; the Prepare screen is gone.
    if (_session(uid) == null) return 'Checklist saved to the account you were signed in with.';
    checklistTips[s.id] = {for (final i in result.items) if (i.tip != null && i.tip!.isNotEmpty) i.id: i.tip!};
    checklistSource[s.id] = result.source;
    notifyListeners();
    return result.source == AiSource.rules
        ? 'Checklist rebuilt from the official requirements'
        : 'Checklist regenerated from the official page';
  }

  // ───────────── AI status & Gemini Nano download ─────────────

  AiStatus? aiStatus;
  HybridAiException? aiStatusError;
  DownloadProgress? download;
  StreamSubscription<DownloadProgress>? _downloadSub;

  bool get downloading =>
      download != null && download!.state != DownloadState.completed && download!.state != DownloadState.failed;

  /// 0–1 when the plugin reports byte counts, otherwise null (indeterminate).
  double? get downloadFraction {
    final total = download?.totalBytes ?? 0;
    return total > 0 ? (download!.bytesDownloaded ?? 0) / total : null;
  }

  Future<void> refreshAiStatus() async {
    try {
      aiStatus = await ai.getStatus();
      aiStatusError = null;
    } on HybridAiException catch (e) {
      aiStatusError = e;
    } on Object catch (e) {
      // MissingPluginException in tests / unsupported platforms.
      aiStatusError = HybridAiException(HybridAiErrorCode.unknown, 'UNAVAILABLE', '$e');
    }
    notifyListeners();
  }

  void startModelDownload() {
    _downloadSub?.cancel();
    download = DownloadProgress(state: DownloadState.started);
    notifyListeners();
    _downloadSub = ai.downloadModel().listen(
      (p) {
        download = p;
        notifyListeners();
      },
      onError: (Object e) {
        download = DownloadProgress(
          state: DownloadState.failed,
          errorMessage: e is HybridAiException ? e.userMessage : '$e',
        );
        notifyListeners();
      },
      onDone: refreshAiStatus,
    );
  }

  /// Label for the inference-mode badge: what will actually answer right now.
  String get inferModeLabel {
    if (aiStatus?.onDeviceModel == ModelAvailability.available) return 'On-device';
    if (cloudAllowed) return 'Cloud AI';
    return 'AI off';
  }

  String get modelStatusLabel {
    if (downloading) return 'Downloading';
    return switch (aiStatus?.onDeviceModel) {
      ModelAvailability.available => 'Ready',
      ModelAvailability.downloadable => 'Not downloaded',
      ModelAvailability.downloading => 'Downloading',
      ModelAvailability.unavailable => 'Not supported',
      ModelAvailability.unknown || null => 'Unknown',
    };
  }

  // ───────────── Ask AI ─────────────

  final chats = <String, ChatThread>{};

  ChatThread thread(String scholarshipId) => chats.putIfAbsent(scholarshipId, ChatThread.new);

  static const maxQuestionLength = 1000;

  Future<void> ask(Scholarship s, String question, {bool retry = false}) async {
    final q = question.trim();
    if (q.isEmpty) return;
    final t = thread(s.id);
    if (t.thinking) return;
    if (!retry) t.messages.add(ChatMessage.user(q.length > maxQuestionLength ? q.substring(0, maxQuestionLength) : q));
    t
      ..thinking = true
      ..error = null
      ..failedQuestion = null
      ..askedWithCloud = cloudAllowed;
    notifyListeners();
    try {
      final answer = await ai.ask(AskRequest(
        question: q.length > maxQuestionLength ? q.substring(0, maxQuestionLength) : q,
        scholarship: s.toContext(),
        student: profile?.toStudentContext(),
        allowCloud: t.askedWithCloud,
        languageCode: 'en',
      ));
      t.messages.add(ChatMessage.ai(answer.text, source: answer.source, citations: answer.citations));
    } on HybridAiException catch (e) {
      t
        ..error = e
        ..failedQuestion = q;
    } on PlatformException catch (e) {
      t
        ..error = HybridAiException.fromPlatform(e)
        ..failedQuestion = q;
    } on Object catch (e) {
      debugPrint('Lumina: ask failed: $e');
      t
        ..error = HybridAiException(HybridAiErrorCode.unknown, 'UNAVAILABLE', '$e')
        ..failedQuestion = q;
    } finally {
      t.thinking = false;
      notifyListeners();
    }
  }

  Future<void> retryLast(Scholarship s) async {
    final q = thread(s.id).failedQuestion;
    if (q != null) await ask(s, q, retry: true);
  }

  // ───────────── Account ─────────────

  Future<void> signOut() => backend.signOut();

  /// Email accounts confirm with their password, Google accounts by signing in again.
  bool get usesPassword => user?.usesPassword ?? false;

  /// Throws [AuthFailure] (wrong password, cancelled confirmation) before anything is deleted.
  Future<void> deleteAccount({String? password}) async {
    final u = user;
    if (u != null) await backend.deleteAccount(u.uid, password: password);
  }

  /// Official source hosts for "About & data sources".
  List<({String host, String url})> get sources {
    final seen = <String>{};
    return [
      for (final s in scholarships)
        if (s.sourceUrl.isNotEmpty && seen.add(hostOf(s.sourceUrl))) (host: hostOf(s.sourceUrl), url: s.sourceUrl),
    ];
  }
}

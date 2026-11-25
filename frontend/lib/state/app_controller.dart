import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hybrid_ai/hybrid_ai.dart';

import '../data/backend.dart';
import '../data/privacy_store.dart';
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
  AppController({required this.backend, required this.ai, DateTime Function()? clock, LocalPrivacyStore? privacyStore})
      : _clock = clock ?? DateTime.now,
        privacyStore = privacyStore ?? MemoryPrivacyStore();

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
    _privacyLoaded = false;
    _cloudOffHere = false;
    _cloudRequest = null;
    _cloudAttempt++;
    _offSyncTried = false;
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
          _settleCloudOff();
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
      unawaited(_loadPrivacy(u.uid));
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

  /// Saves the profile from onboarding or Edit preferences. Its cloud AI value is the one
  /// chosen on this phone (an unsaved "off", or a change still saving), not an older copy.
  Future<void> saveProfile(UserProfile p) async {
    final u = user;
    if (u == null) return;
    final forcedOff = _cloudOffHere;
    await _saveProfileNow(u.uid, p, cloud: forcedOff ? false : _cloudRequest);
    if (forcedOff && _cloudOffHere && _cloudRequest == null && user?.uid == u.uid) {
      _clearCloudOff(u.uid); // the account has "off" now
      notifyListeners();
    }
  }

  Future<void> _saveProfileNow(String uid, UserProfile p, {bool? cloud}) =>
      backend.saveProfile(uid, cloud == null ? p : p.copyWith(cloudAiAllowed: cloud), isNew: profile == null);

  // ───────────── Cloud AI setting (privacy first) ─────────────
  //
  // Questions use cloud AI only when the account has "on", confirmed by Firestore, and this
  // phone has no unsaved "off". "Off" counts at once and is remembered on the phone until the
  // account has it, also across a restart. "On" counts only once Firestore confirms it.

  /// Remembers an unsaved "off" across restarts.
  final LocalPrivacyStore privacyStore;

  /// The remembered "off" has been read for this user. Until then cloud AI stays off.
  bool _privacyLoaded = false;

  /// "Off" was chosen on this phone and the account does not have it yet.
  bool _cloudOffHere = false;

  /// A change being saved: what the switch shows meanwhile.
  bool? _cloudRequest;

  /// Counts [setCloudAllowed] calls, so only the latest one settles the choice.
  int _cloudAttempt = 0;

  /// A remembered "off" was re-saved to the account once since sign-in.
  bool _offSyncTried = false;

  /// Whether questions may use cloud AI (see above).
  bool get cloudAllowed {
    final p = profile;
    return _privacyLoaded && !_cloudOffHere && _cloudRequest == null && p != null && p.cloudAiAllowed && !p.savePending;
  }

  /// What the "Allow cloud AI" switch shows: the latest choice, even while it saves.
  bool get cloudSwitch => _cloudRequest ?? (!_cloudOffHere && (profile?.cloudAiAllowed ?? false));

  /// A change to the cloud AI setting is waiting for Firestore.
  bool get cloudSaving => _cloudRequest != null;

  /// "Off" counts at once (and is remembered on this phone first); "on" counts only once
  /// saved. If the save fails, cloud AI is off on this phone either way, and [failure] (or a
  /// default message) is reported on [notices]. Returns whether the choice was saved.
  Future<bool> setCloudAllowed(bool allowed, {String? failure}) async {
    final u = user;
    if (u == null || profile == null) return false;
    final attempt = ++_cloudAttempt;
    _cloudRequest = allowed;
    if (!allowed) _cloudOffHere = true;
    notifyListeners();
    if (!allowed) await _rememberCloudOff(u.uid, true);
    final saved = await _write(
      () => _saveProfileNow(u.uid, profile!, cloud: allowed),
      failure ??
          (allowed
              ? 'Could not turn on cloud AI, so it is still off. Try again.'
              : 'Could not save that to your account, but cloud AI is off on this phone. Try again to save it.'),
    );
    if (attempt != _cloudAttempt || user?.uid != u.uid) return saved; // a newer choice is in charge
    _cloudRequest = null;
    // Saved: the account has the choice, so nothing is left to remember here. Not saved: a
    // remembered "off" stays, and a failed "on" never counted.
    if (saved) _clearCloudOff(u.uid);
    notifyListeners();
    return saved;
  }

  /// "Allow cloud AI" on a question that failed with cloud AI off: sends that question with
  /// cloud AI right away (the tap is consent for it) and saves the setting, which counts for
  /// the next questions only once Firestore confirms it. If the save fails, the message says
  /// the question was already sent with cloud AI and that cloud AI is still off.
  Future<void> allowCloudAndRetry(Scholarship s) async {
    final t = thread(s.id);
    final sending = t.failedQuestion != null && !t.thinking;
    final saving = setCloudAllowed(
      true,
      failure: sending
          ? 'Your question was sent with cloud AI, but the setting could not be saved, '
              'so cloud AI is still off for your next questions.'
          : null,
    );
    await retryLast(s, allowCloud: true);
    await saving;
  }

  Future<void> _loadPrivacy(String uid) async {
    var off = false;
    try {
      off = await privacyStore.unsavedCloudOff(uid);
    } on Object catch (e) {
      debugPrint('Lumina: reading the cloud AI choice failed: $e');
    }
    if (user?.uid != uid) return;
    _cloudOffHere = _cloudOffHere || off;
    _privacyLoaded = true;
    _settleCloudOff();
    notifyListeners();
  }

  /// A remembered "off" the account lacks is saved once more; one the account already has is
  /// forgotten.
  void _settleCloudOff() {
    final u = user;
    final p = profile;
    if (u == null || p == null || !_privacyLoaded || !_cloudOffHere || _cloudRequest != null || p.savePending) return;
    if (!p.cloudAiAllowed) {
      _clearCloudOff(u.uid);
    } else if (!_offSyncTried) {
      _offSyncTried = true;
      saveProfile(p).catchError((Object e) => debugPrint('Lumina: saving cloud AI off failed again: $e'));
    }
  }

  void _clearCloudOff(String uid) {
    if (!_cloudOffHere) return;
    _cloudOffHere = false;
    unawaited(_rememberCloudOff(uid, false));
  }

  Future<void> _rememberCloudOff(String uid, bool off) async {
    try {
      await privacyStore.setUnsavedCloudOff(uid, off);
    } on Object catch (e) {
      debugPrint('Lumina: storing the cloud AI choice failed: $e');
    }
  }

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

  /// [allowCloud] overrides the setting for this one question ("Allow cloud AI" on the card).
  Future<void> ask(Scholarship s, String question, {bool retry = false, bool? allowCloud}) async {
    final q = question.trim();
    if (q.isEmpty) return;
    final t = thread(s.id);
    if (t.thinking) return;
    if (!retry) t.messages.add(ChatMessage.user(q.length > maxQuestionLength ? q.substring(0, maxQuestionLength) : q));
    t
      ..thinking = true
      ..error = null
      ..failedQuestion = null
      ..askedWithCloud = allowCloud ?? cloudAllowed;
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

  Future<void> retryLast(Scholarship s, {bool? allowCloud}) async {
    final q = thread(s.id).failedQuestion;
    if (q != null) await ask(s, q, retry: true, allowCloud: allowCloud);
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

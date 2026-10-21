import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import '../services/post_upload_queue.dart';
import '../services/media_upload_helper.dart';

class PostUploadProvider extends ChangeNotifier with WidgetsBindingObserver {
  final Future<void> Function()? onCompleted;
  PostUploadProvider({this.onCompleted}) {
    WidgetsBinding.instance.addObserver(this);
    ready = _initialize().catchError((Object error) {
      _initializationError = error;
      debugPrint('Upload queue initialization failed: $error');
    });
  }
  late final Future<void> ready;
  late PostUploadStore _store;
  Timer? _timer;
  bool _disposed = false;
  bool _loading = false;
  Object? _initializationError;
  List<QueuedPost> jobs = [];

  Future<void> _initialize() async {
    _store = await PostUploadStore.open();
    await refresh();
    for (final job in jobs.where((j) => !j.terminal)) {
      try {
        await scheduleQueuedPost(job.id);
      } catch (_) {}
    }
    if (!_disposed) _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
  }

  Future<void> refresh() async {
    if (_loading || _disposed) return;
    _loading = true;
    try {
      final next = await _store.list();
      final completed = next.any(
        (job) =>
            job.state == 'complete' &&
            jobs.any((old) => old.id == job.id && old.state != 'complete'),
      );
      jobs = next;
      if (!_disposed) notifyListeners();
      if (completed && !_disposed) await onCompleted?.call();
    } catch (error) {
      debugPrint('Upload queue refresh failed: $error');
    } finally {
      _loading = false;
    }
  }

  Future<void> enqueue({
    required String ownerId,
    required String identityType,
    String? identityId,
    required Map<String, dynamic> payload,
    required List<PickedMediaResult> media,
  }) async {
    await ready;
    if (_initializationError != null) {
      throw StateError(
        'Unable to save the upload queue. Please reopen the app and try again.',
      );
    }
    final job = await _store.create(
      ownerId: ownerId,
      identityType: identityType,
      identityId: identityId,
      payload: payload,
      selections: media,
    );
    try {
      await scheduleQueuedPost(job.id);
      // iOS may defer BGProcessing. Start immediately while foregrounded;
      // the on-disk lock prevents concurrent native/background processing.
      if (Platform.isIOS) unawaited(runQueuedPost(_store, job.id));
    } catch (error) {
      job.state = 'failed';
      job.label = 'Could not start background upload';
      job.error = 'Your post is saved. Tap Retry to schedule it again.';
      await _store.save(job);
    }
    await refresh();
  }

  Future<void> retry(String id) async {
    final job = await _store.read(id);
    if (job == null || !job.terminal || job.state == 'complete') return;
    job.state = 'queued';
    job.error = null;
    job.attempts = 0;
    job.label = 'Waiting to upload';
    await _store.save(job);
    try {
      await scheduleQueuedPost(id);
      if (Platform.isIOS) unawaited(runQueuedPost(_store, id));
    } catch (_) {
      job.state = 'failed';
      job.error = 'Unable to start upload. Please try again.';
      await _store.save(job);
    }
    await refresh();
  }

  Future<void> dismiss(String id) async {
    final job = await _store.read(id);
    if (job != null) await _store.dismiss(job);
    await refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ready.then((_) {
        if (!_disposed) {
          refresh();
          _startPolling();
        }
      });
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

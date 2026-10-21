import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';
import 'api_service.dart';
import 'media_upload_helper.dart';

const postUploadTask = 'com.peto.jr.postUploads';
const postUploadChain = 'peto-post-upload-queue';

class QueuedUploadFailure implements Exception {
  final String message;
  final bool retryable;
  const QueuedUploadFailure(this.message, {this.retryable = false});
  @override
  String toString() => message;
}

String uploadFailureMessage(Object error) {
  if (error is QueuedUploadFailure) return error.message;
  if (error is StateError) return error.message.toString();
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) return data['message'];
    if (error.type == DioExceptionType.cancel && error.error is String) {
      return error.error as String;
    }
    if (error.response?.statusCode != null) {
      return 'The server could not finish your post (HTTP ${error.response!.statusCode}). Your post is saved.';
    }
    if (error.type == DioExceptionType.receiveTimeout) {
      return 'The server response timed out. Your post is saved for recovery.';
    }
    return 'The connection was interrupted. Your post is saved for retry.';
  }
  return 'Unable to finish uploading. Your post is saved. Please retry.';
}

class QueuedPost {
  final String id;
  final String ownerId;
  final String identityType;
  final String? identityId;
  final String apiBaseUrl;
  final Map<String, dynamic> payload;
  final List<Map<String, dynamic>> media;
  String state;
  String label;
  String? error;
  double progress;
  int attempts;

  QueuedPost({
    required this.id,
    required this.ownerId,
    required this.identityType,
    this.identityId,
    required this.apiBaseUrl,
    required this.payload,
    required this.media,
    this.state = 'queued',
    this.label = 'Waiting to upload',
    this.error,
    this.progress = 0,
    this.attempts = 0,
  });

  bool get terminal =>
      state == 'complete' || state == 'failed' || state == 'login';
  bool get processing =>
      state == 'processing' || state == 'publishing' || state == 'checking';
  String get statusHint => state == 'retrying'
      ? 'Your post is saved. We will retry automatically when the connection or server recovers.'
      : state == 'checking'
      ? 'File transferred. Checking whether the server has finished preparing it. You can leave the app.'
      : processing
      ? 'Preparing your media. You can leave the app.'
      : 'Uploading in the background. You can keep browsing.';
  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'identityType': identityType,
    'identityId': identityId,
    'apiBaseUrl': apiBaseUrl,
    'payload': payload,
    'media': media,
    'state': state,
    'label': label,
    'error': error,
    'progress': progress,
    'attempts': attempts,
  };
  factory QueuedPost.fromJson(Map<String, dynamic> json) => QueuedPost(
    id: json['id'],
    ownerId: json['ownerId'],
    identityType: json['identityType'],
    identityId: json['identityId'],
    apiBaseUrl: json['apiBaseUrl'],
    payload: Map<String, dynamic>.from(json['payload']),
    media: (json['media'] as List)
        .map((m) => Map<String, dynamic>.from(m))
        .toList(),
    state: json['state'],
    label: json['label'],
    error: json['error'],
    progress: (json['progress'] as num).toDouble(),
    attempts: json['attempts'],
  );
}

/// One file per post, atomically replaced. Credentials never enter queue files.
class PostUploadStore {
  final Directory root;
  PostUploadStore(this.root);
  static Future<PostUploadStore> open() async => PostUploadStore(
    Directory('${(await getApplicationSupportDirectory()).path}/post_uploads'),
  );

  Directory directory(String id) {
    if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(id)) {
      throw ArgumentError('Invalid upload id');
    }
    return Directory('${root.path}/$id');
  }

  Future<void> save(QueuedPost job) async {
    final dir = directory(job.id);
    await dir.create(recursive: true);
    final temp = File('${dir.path}/job.tmp');
    await temp.writeAsString(jsonEncode(job.toJson()), flush: true);
    await temp.rename('${dir.path}/job.json');
  }

  Future<QueuedPost?> read(String id) async {
    final file = File('${directory(id).path}/job.json');
    if (!await file.exists()) return null;
    return QueuedPost.fromJson(jsonDecode(await file.readAsString()));
  }

  Future<List<QueuedPost>> list() async {
    if (!await root.exists()) return [];
    final jobs = <QueuedPost>[];
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      try {
        final id = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
        final job = await read(id);
        if (job != null) jobs.add(job);
      } catch (error) {
        debugPrint('Cannot read queued post: $error');
      }
    }
    return jobs;
  }

  Future<QueuedPost> create({
    required String ownerId,
    required String identityType,
    String? identityId,
    required Map<String, dynamic> payload,
    required List<PickedMediaResult> selections,
  }) async {
    final id = const Uuid().v4();
    final dir = directory(id);
    await dir.create(recursive: true);
    final items = <Map<String, dynamic>>[];
    try {
      for (var i = 0; i < selections.length; i++) {
        final item = selections[i];
        // Persist picker files before leaving the composer or scheduling work.
        // Use a safe extension; the API inspects video signatures independently.
        final name = item.localPath.replaceAll('\\', '/').split('/').last;
        final ext = name.contains('.')
            ? name.split('.').last.toLowerCase()
            : '';
        final safeExt = RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext)
            ? ext
            : (item.isVideo ? 'mp4' : 'jpg');
        final copy = await File(
          item.localPath,
        ).copy('${dir.path}/media-$i.$safeExt');
        items.add({
          'uploadId': const Uuid().v4(),
          'path': copy.path,
          'isVideo': item.isVideo,
          'mediaId': item.mediaId,
          'size': await copy.length(),
        });
      }
      final job = QueuedPost(
        id: id,
        ownerId: ownerId,
        identityType: identityType,
        identityId: identityId,
        apiBaseUrl: ApiService.defaultBaseUrl,
        payload: {...payload, 'client_post_id': id},
        media: items,
      );
      await save(job);
      return job;
    } catch (_) {
      await dir.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> removeMedia(QueuedPost job) async {
    if (!await directory(job.id).exists()) return;
    // Never delete paths from serialized state: restrict cleanup to our directory.
    await for (final entry in directory(job.id).list()) {
      if (entry is File && entry.uri.pathSegments.last.startsWith('media-')) {
        await entry.delete();
      }
    }
  }

  Future<void> dismiss(QueuedPost job) async {
    if (!job.terminal) return;
    final dir = directory(job.id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

class UploadNotifications {
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  Future<void> initialize() async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<void> show(QueuedPost job) async {
    if (!Platform.isAndroid) return;
    final done = job.terminal;
    await plugin.show(
      id: done ? 7402 : 7401,
      title: job.state == 'complete'
          ? 'Your post is published'
          : 'Peto post upload',
      body:
          job.error ??
          '${job.label} (${(job.progress * 100).floor()}% transferred)',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'peto_uploads',
          'Post uploads',
          channelDescription: 'Background post upload progress',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: !done,
          onlyAlertOnce: true,
          showProgress: !done,
          maxProgress: 100,
          progress: (job.progress * 100).floor(),
          indeterminate:
              job.processing ||
              job.state == 'queued' ||
              job.state == 'retrying',
        ),
      ),
    );
  }
}

@pragma('vm:entry-point')
void postUploadDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().executeTask((task, data) async {
    final store = await PostUploadStore.open();
    final ids = data?['jobId'] != null
        ? <String>[data!['jobId'] as String]
        : (await store.list())
              .where((job) => !job.terminal)
              .map((job) => job.id)
              .toList();
    var success = true;
    for (final id in ids) {
      success = await runQueuedPost(store, id) && success;
    }
    if (!success && Platform.isIOS && ids.isNotEmpty) {
      await scheduleQueuedPost(ids.first);
    }
    return success;
  });
}

/// OS-owned work is independent of the composer and its Flutter engine.
Future<bool> runQueuedPost(
  PostUploadStore store,
  String id, {
  ApiService? apiOverride,
  UploadNotifications? notificationsOverride,
  int recoveryChecks = 36,
  Duration recoveryInterval = const Duration(seconds: 5),
}) async {
  if (!await store.directory(id).exists()) return true;
  final lock = await File(
    '${store.directory(id).path}/worker.lock',
  ).open(mode: FileMode.append);
  try {
    await lock.lock(FileLock.blockingExclusive);
    final job = await store.read(id);
    if (job == null || job.terminal) return true;
    final api =
        apiOverride ??
        ApiService(
          baseUrl: job.apiBaseUrl,
          expectedOwnerId: job.ownerId,
          actingIdentityType: job.identityType,
          actingIdentityId: job.identityId,
        );
    final notifications = notificationsOverride ?? UploadNotifications();
    try {
      await notifications.initialize();
    } catch (_) {}
    Future<void> report() async {
      await store.save(job);
      try {
        await notifications.show(job);
      } catch (_) {}
    }

    Future<void> writes = Future.value();
    Future<MediaUploadResult?> recover(Map<String, dynamic> item) async {
      if (item['uploadId'] is! String) return null;
      job.state = 'checking';
      job.label = 'Confirming your upload';
      job.error = null;
      await report();
      for (var check = 0; check < recoveryChecks; check++) {
        try {
          final completed = await api.getUploadedMedia(item['uploadId']);
          if (completed != null) return completed;
        } on DioException catch (error) {
          final status = error.response?.statusCode;
          if (error.type == DioExceptionType.cancel ||
              (status != null && status < 500 && status != 429)) {
            rethrow;
          }
        }
        if (check + 1 < recoveryChecks) {
          await Future<void>.delayed(recoveryInterval);
        }
      }
      return null;
    }

    job.attempts++;
    try {
      for (var i = 0; i < job.media.length; i++) {
        final item = job.media[i];
        if (item['mediaId'] != null) continue;
        // Reconcile pending 100% uploads saved by the previous APK as well.
        if (!item.containsKey('transferComplete') &&
            i == job.media.length - 1 &&
            job.progress >= 1) {
          item['transferComplete'] = true;
        }
        final totalBytes = job.media.fold<num>(
          0,
          (sum, m) => sum + (m['size'] as num),
        );
        final previousBytes = job.media
            .take(i)
            .fold<num>(0, (sum, m) => sum + (m['size'] as num));
        final itemBytes = item['size'] as num;
        MediaUploadResult? result;
        if (item['transferComplete'] == true) {
          result = await recover(item);
        }
        job.state = 'uploading';
        job.label = 'Uploading file ${i + 1} of ${job.media.length}';
        job.error = null;
        await report();
        var lastPercent = -1;
        if (result == null) {
          item['transferComplete'] = false;
          await report();
          result = await api.uploadMediaFile(
            item['path'],
            clientMediaId: item['uploadId'],
            isVideo: item['isVideo'],
            onProgress: (sent, total) {
              if (total <= 0) return;
              final fraction = (sent / total).clamp(0.0, 1.0);
              final percent = (fraction * 100).floor();
              if (percent == lastPercent) return;
              lastPercent = percent;
              // Serialize disk writes and notification updates from progress events.
              writes = writes.then((_) async {
                job.progress = totalBytes > 0
                    ? (previousBytes + fraction * itemBytes) / totalBytes
                    : 0;
                if (sent >= total) {
                  item['transferComplete'] = true;
                  job.state = 'processing';
                  job.label = 'Processing file ${i + 1} of ${job.media.length}';
                }
                await report();
              });
            },
          );
          await writes;
          if (!result.success &&
              result.retryable &&
              (result.transferComplete || item['transferComplete'] == true)) {
            item['transferComplete'] = true;
            final recovered = await recover(item);
            if (recovered != null) result = recovered;
          }
        }
        if (!result.success || result.mediaId == null) {
          throw QueuedUploadFailure(
            result.errorMessage ?? 'Upload could not be confirmed.',
            retryable: result.retryable,
          );
        }
        item['mediaId'] = result.mediaId;
        job.progress = totalBytes > 0
            ? (previousBytes + itemBytes) / totalBytes
            : 0;
        await report();
      }
      job.state = 'publishing';
      job.label = 'Publishing your post';
      job.progress = 1;
      await report();
      final response = await api.createPost({
        ...job.payload,
        'media': job.media.map((m) => m['mediaId']).toList(),
      });
      if (response.data is Map && response.data['success'] == false) {
        throw StateError(response.data['message'] ?? 'Unable to publish post');
      }
      job.state = 'complete';
      job.label = 'Your post is published';
      await report();
      try {
        await store.removeMedia(job);
      } catch (error) {
        debugPrint('Published post local cleanup failed: $error');
      }
      return true;
    } catch (error) {
      await writes.catchError((_) {});
      final transient =
          (error is QueuedUploadFailure && error.retryable) ||
          error is SocketException ||
          (error is DioException &&
              ((error.response == null &&
                      error.type != DioExceptionType.cancel) ||
                  (error.response?.statusCode ?? 0) >= 500 ||
                  error.response?.statusCode == 429));
      job.state = transient && job.attempts < 5 ? 'retrying' : 'failed';
      job.label = job.state == 'retrying'
          ? 'Upload saved; will retry'
          : 'Upload needs attention';
      job.error = uploadFailureMessage(error);
      debugPrint(
        'Post upload attempt failed: job=${job.id} attempt=${job.attempts} '
        'state=${job.state} message=${job.error}',
      );
      await report();
      return job.state != 'retrying';
    } finally {
      if (apiOverride == null) api.client.close();
    }
  } finally {
    await lock.unlock();
    await lock.close();
  }
}

Future<void> scheduleQueuedPost(String id) async {
  if (Platform.isAndroid) {
    await Workmanager().registerOneOffTask(
      postUploadChain,
      postUploadTask,
      inputData: {'jobId': id},
      existingWorkPolicy: ExistingWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
      foregroundServiceConfig: ForegroundServiceConfig(
        notificationTitle: 'Peto post upload',
        notificationText: 'Uploading your post in the background',
        notificationChannelId: 'peto_uploads',
        notificationChannelName: 'Post uploads',
        notificationId: 7401,
        foregroundServiceType: ForegroundServiceType.dataSync,
      ),
    );
  } else if (Platform.isIOS) {
    await Workmanager().registerProcessingTask(
      postUploadTask,
      postUploadTask,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}

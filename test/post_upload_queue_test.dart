import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peto_user/services/api_service.dart';
import 'package:peto_user/services/media_upload_helper.dart';
import 'package:peto_user/services/post_upload_queue.dart';
import 'package:peto_user/providers/post_provider.dart';
import 'upload_progress_test.dart' show StubAdapter, jsonResponse;

class SilentNotifications extends UploadNotifications {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> show(QueuedPost job) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late PostUploadStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'peto_token': 'test-token'});
    temp = await Directory.systemTemp.createTemp('peto-queue-test-');
    store = PostUploadStore(Directory('${temp.path}/queue'));
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  Future<QueuedPost> createJob() async {
    final source = File('${temp.path}/camera.mp4');
    final bytes = List<int>.filled(64, 0);
    bytes.setRange(4, 12, ascii.encode('ftypisom'));
    await source.writeAsBytes(bytes);
    return store.create(
      ownerId: 'owner',
      identityType: 'BUSINESS',
      identityId: 'business',
      payload: {'text': 'My video', 'visibility': 'public'},
      selections: [PickedMediaResult(localPath: source.path, isVideo: true)],
    );
  }

  test(
    'queue survives picker-cache removal and a new store instance',
    () async {
      final job = await createJob();
      await File('${temp.path}/camera.mp4').delete();
      final recovered = await PostUploadStore(store.root).read(job.id);
      expect(recovered!.identityId, 'business');
      expect(recovered.payload['client_post_id'], job.id);
      expect(await File(recovered.media.single['path']).exists(), isTrue);
      expect(recovered.media.single['uploadId'], isNotEmpty);
      expect(jsonEncode(recovered.toJson()), isNot(contains('test-token')));
    },
  );

  test(
    'post retry reuses persisted media and stable post ID, then cleans copied files',
    () async {
      final job = await createJob();
      final api = ApiService();
      var uploads = 0;
      var publishes = 0;
      api.client.httpClientAdapter = StubAdapter((options, bytes) async {
        if (options.path.startsWith('/media/status/')) {
          return jsonResponse(404, {'success': false});
        }
        if (options.path == '/media/upload') {
          uploads++;
          expect(
            utf8.decode(bytes, allowMalformed: true),
            contains(job.media.single['uploadId']),
          );
          return jsonResponse(201, {
            'success': true,
            'mediaId': 'media-id',
            'mediaUrl': 'https://example.com/video.mp4',
          });
        }
        publishes++;
        expect(options.data['client_post_id'], job.id);
        expect(options.data['media'], ['media-id']);
        if (publishes == 1) {
          return jsonResponse(503, {'message': 'Temporary unavailable'});
        }
        return jsonResponse(201, {'success': true});
      });
      expect(
        await runQueuedPost(
          store,
          job.id,
          apiOverride: api,
          notificationsOverride: SilentNotifications(),
        ),
        isFalse,
      );
      final pending = await store.read(job.id);
      expect(pending!.state, 'retrying');
      expect(pending.media.single['mediaId'], 'media-id');
      expect(
        await runQueuedPost(
          PostUploadStore(store.root),
          job.id,
          apiOverride: api,
          notificationsOverride: SilentNotifications(),
        ),
        isTrue,
      );
      expect(uploads, 1);
      expect(publishes, 2);
      expect((await store.read(job.id))!.state, 'complete');
      expect(await File(pending.media.single['path']).exists(), isFalse);
      // A duplicate OS callback cannot publish the post again.
      await runQueuedPost(
        store,
        job.id,
        apiOverride: api,
        notificationsOverride: SilentNotifications(),
      );
      expect(publishes, 2);
      api.client.close();
    },
  );

  test(
    'lost upload response is recovered through owner-scoped status lookup',
    () async {
      final job = await createJob();
      final api = ApiService();
      var uploads = 0;
      api.client.httpClientAdapter = StubAdapter((options, bytes) async {
        if (options.path.startsWith('/media/status/')) {
          return jsonResponse(200, {
            'success': true,
            'mediaId': 'existing-media',
            'mediaUrl': 'https://example.com/video.mp4',
          });
        }
        if (options.path == '/media/upload') uploads++;
        expect(options.data['media'], ['existing-media']);
        return jsonResponse(201, {'success': true});
      });
      expect(
        await runQueuedPost(
          store,
          job.id,
          apiOverride: api,
          notificationsOverride: SilentNotifications(),
        ),
        isTrue,
      );
      expect(uploads, 0);
      api.client.close();
    },
  );

  test('a changed signed-in account cannot send queued posts', () async {
    final claims = base64Url.encode(
      utf8.encode(jsonEncode({'sub': 'different-account'})),
    );
    FlutterSecureStorage.setMockInitialValues({
      'peto_token': 'header.$claims.signature',
    });
    final api = ApiService(
      expectedOwnerId: 'original-account',
      actingIdentityType: 'PERSON',
    );
    var requests = 0;
    api.client.httpClientAdapter = StubAdapter((options, bytes) async {
      requests++;
      return jsonResponse(201, {'success': true});
    });
    await expectLater(
      api.createPost({'text': 'Private draft'}),
      throwsA(anything),
    );
    expect(requests, 0);
    api.client.close();
  });

  test(
    '100% transfer with lost response waits for server completion without resending',
    () async {
      final job = await createJob();
      final api = ApiService();
      var statusChecks = 0;
      var uploads = 0;
      var publishes = 0;
      api.client.httpClientAdapter = StubAdapter((options, bytes) async {
        if (options.path.startsWith('/media/status/')) {
          statusChecks++;
          if (statusChecks < 3) return jsonResponse(404, {'success': false});
          return jsonResponse(200, {
            'success': true,
            'mediaId': 'confirmed-media',
            'mediaUrl': 'https://example.com/video.mp4',
          });
        }
        if (options.path == '/media/upload') {
          uploads++;
          return jsonResponse(504, {'message': 'Gateway response timed out'});
        }
        publishes++;
        expect(options.data['media'], ['confirmed-media']);
        return jsonResponse(201, {'success': true});
      });
      expect(
        await runQueuedPost(
          store,
          job.id,
          apiOverride: api,
          notificationsOverride: SilentNotifications(),
          recoveryChecks: 4,
          recoveryInterval: Duration.zero,
        ),
        isTrue,
      );
      expect(uploads, 1);
      expect(publishes, 1);
      expect(statusChecks, 3);
      expect((await store.read(job.id))!.state, 'complete');
      api.client.close();
    },
  );

  test(
    'retry preserves real server error instead of inventing SocketException',
    () async {
      final job = await createJob();
      final api = ApiService();
      api.client.httpClientAdapter = StubAdapter((options, bytes) async {
        if (options.path.startsWith('/media/status/')) {
          return jsonResponse(404, {'success': false});
        }
        return jsonResponse(503, {
          'message': 'Video storage temporarily unavailable',
        });
      });
      expect(
        await runQueuedPost(
          store,
          job.id,
          apiOverride: api,
          notificationsOverride: SilentNotifications(),
          recoveryChecks: 0,
        ),
        isFalse,
      );
      final saved = (await store.read(job.id))!;
      expect(saved.error, 'Video storage temporarily unavailable');
      expect(saved.error, isNot(contains('SocketException')));
      expect(saved.label, 'Upload saved; will retry');
      expect(saved.statusHint, contains('server recovers'));
      api.client.close();
    },
  );

  test(
    'old APK pending 100% state is confirmed before any new transfer',
    () async {
      final job = await createJob();
      job.progress = 1;
      job.state = 'retrying';
      await store.save(job);
      final api = ApiService();
      var checks = 0;
      var uploads = 0;
      api.client.httpClientAdapter = StubAdapter((options, bytes) async {
        if (options.path.startsWith('/media/status/')) {
          if (++checks == 1) return jsonResponse(404, {'success': false});
          return jsonResponse(200, {
            'success': true,
            'mediaId': 'already-uploaded',
            'mediaUrl': 'https://example.com/video.mp4',
          });
        }
        if (options.path == '/media/upload') uploads++;
        return jsonResponse(201, {'success': true});
      });
      expect(
        await runQueuedPost(
          store,
          job.id,
          apiOverride: api,
          notificationsOverride: SilentNotifications(),
          recoveryChecks: 2,
          recoveryInterval: Duration.zero,
        ),
        isTrue,
      );
      expect(uploads, 0);
      api.client.close();
    },
  );

  test('temporary feed failure retains existing posts', () async {
    final api = ApiService();
    var requests = 0;
    api.client.httpClientAdapter = StubAdapter((options, bytes) async {
      if (++requests == 1) {
        return jsonResponse(200, {
          'posts': [
            {
              'id': 'post-id',
              'text': 'Existing post',
              'created_at': '2026-10-21T06:00:00Z',
            },
          ],
        });
      }
      return jsonResponse(503, {'message': 'Server busy'});
    });
    final provider = PostProvider(apiService: api);
    await provider.fetchPosts();
    expect(provider.posts.single.id, 'post-id');
    await provider.fetchPosts(refresh: true);
    expect(provider.posts.single.id, 'post-id');
    expect(provider.feedError, isNotNull);
    provider.dispose();
    api.client.close();
  });
}

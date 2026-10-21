import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peto_user/providers/post_provider.dart';
import 'package:peto_user/services/api_service.dart';
import 'package:peto_user/widgets/media_upload_progress.dart';

class StubAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options, List<int> bytes)
  respond;
  StubAdapter(this.respond);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    return respond(options, bytes);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(int code, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      code,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'peto_token': 'expired-token',
      'peto_refresh_token': 'refresh-token',
    });
  });

  testWidgets(
    'transfer shows percentage; processing remains indeterminate at 100%',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MediaUploadProgress(
              label: 'Uploading file 1 of 2',
              progress: 0.42,
            ),
          ),
        ),
      );
      expect(find.text('42%'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.42,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MediaUploadProgress(
              label: 'Processing video',
              progress: 1,
              processing: true,
            ),
          ),
        ),
      );
      expect(find.text('100% transferred'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
      expect(find.textContaining('Keep this screen open'), findsOneWidget);
    },
  );

  test(
    'expired login retries finalized multipart and preserves upload timeouts/progress',
    () async {
      final dir = await Directory.systemTemp.createTemp('peto-upload-test-');
      final api = ApiService();
      var uploads = 0;
      var refreshes = 0;
      var sent = 0;
      api.client.httpClientAdapter = StubAdapter((options, bytes) async {
        if (options.path == '/auth/refresh') {
          refreshes++;
          return jsonResponse(200, {'success': true, 'token': 'new-token'});
        }
        uploads++;
        expect(options.sendTimeout, const Duration(minutes: 5));
        expect(options.receiveTimeout, const Duration(minutes: 5));
        expect(bytes.length, greaterThan(32));
        if (uploads == 1) {
          return jsonResponse(401, {'message': 'Expired token'});
        }
        expect(options.headers['Authorization'], 'Bearer new-token');
        return jsonResponse(201, {
          'success': true,
          'data': [
            {'id': 'media-id', 'url': 'https://example.com/video.mp4'},
          ],
        });
      });
      try {
        final file = File('${dir.path}/phone.mp4');
        final header = List<int>.filled(32, 0);
        header.setRange(4, 12, ascii.encode('ftypisom'));
        await file.writeAsBytes(header);
        final result = await api.uploadMediaFile(
          file.path,
          isVideo: true,
          onProgress: (count, total) {
            sent = count;
          },
        );
        expect(result.success, isTrue);
        expect(result.mediaId, 'media-id');
        expect(uploads, 2);
        expect(refreshes, 1);
        expect(sent, greaterThan(0));
      } finally {
        api.client.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test('mobile exposes post failure after a successful media upload', () async {
    final api = ApiService();
    api.client.httpClientAdapter = StubAdapter(
      (options, bytes) async => jsonResponse(403, {
        'message': 'You must be an active community member.',
      }),
    );
    final provider = PostProvider(apiService: api);
    expect(
      await provider.createPost('My video', mediaUrls: ['media-id']),
      isFalse,
    );
    expect(provider.createPostError, 'You must be an active community member.');
    provider.dispose();
    api.client.close();
  });
}

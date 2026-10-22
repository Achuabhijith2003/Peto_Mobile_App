import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peto_user/models/reel_model.dart';
import 'package:peto_user/models/user_model.dart';
import 'package:peto_user/providers/reel_provider.dart';
import 'package:peto_user/providers/post_provider.dart';
import 'package:peto_user/services/api_service.dart';
import 'upload_progress_test.dart' show StubAdapter, jsonResponse;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'peto_token': 'test-token'});
  });
  Reel selected() => Reel(
    id: 'feed-post',
    mediaUrl: 'https://example.com/selected-second-video.mp4',
    author: User(id: 'author', email: '', username: 'pet'),
    likesCount: 4,
  );

  test(
    'feed video outside fetched page can like and bookmark with live state',
    () async {
      final api = ApiService();
      final calls = <String>[];
      api.client.httpClientAdapter = StubAdapter((options, bytes) async {
        calls.add('${options.method} ${options.path}');
        if (options.path == '/posts/reels') {
          return jsonResponse(200, {'posts': []});
        }
        return jsonResponse(200, {'success': true});
      });
      final provider = ReelProvider(apiService: api);
      provider.seedReel(selected());
      await provider.fetchReels();
      expect(await provider.toggleLike('feed-post'), isTrue);
      expect(await provider.toggleBookmark('feed-post'), isTrue);
      final displayed = provider.displayReels(selected()).first;
      expect(displayed.isLiked, isTrue);
      expect(displayed.likesCount, 5);
      expect(displayed.isBookmarked, isTrue);
      expect(displayed.mediaUrl, selected().mediaUrl);
      expect(calls, contains('POST /posts/feed-post/like'));
      expect(calls, contains('POST /my/posts/feed-post/bookmark'));
      expect(await provider.toggleLike('feed-post'), isTrue);
      expect(await provider.toggleBookmark('feed-post'), isTrue);
      expect(provider.reelById('feed-post')!.likesCount, 4);
      expect(calls, contains('DELETE /posts/feed-post/like'));
      expect(calls, contains('DELETE /my/posts/feed-post/bookmark'));
      provider.dispose();
      api.client.close();
    },
  );

  test(
    'failed like rolls back only the like while successful bookmark survives',
    () async {
      final api = ApiService();
      final like = Completer<void>();
      api.client.httpClientAdapter = StubAdapter((options, bytes) async {
        if (options.path.endsWith('/like')) {
          await like.future;
          return jsonResponse(503, {'message': 'Busy'});
        }
        return jsonResponse(200, {'success': true});
      });
      final provider = ReelProvider(apiService: api);
      final pending = provider.toggleLike('feed-post', fallback: selected());
      expect(provider.isLiking('feed-post'), isTrue);
      expect(await provider.toggleLike('feed-post'), isFalse);
      expect(await provider.toggleBookmark('feed-post'), isTrue);
      like.complete();
      expect(await pending, isFalse);
      final state = provider.reelById('feed-post')!;
      expect(state.isLiked, isFalse);
      expect(state.likesCount, 4);
      expect(state.isBookmarked, isTrue);
      provider.dispose();
      api.client.close();
    },
  );

  test('late reels fetch cannot overwrite a just-completed like', () async {
    final api = ApiService();
    final fetch = Completer<void>();
    api.client.httpClientAdapter = StubAdapter((options, bytes) async {
      if (options.path == '/posts/reels') {
        await fetch.future;
        return jsonResponse(200, {
          'posts': [
            {
              'id': 'feed-post',
              'likes_count': 4,
              'is_liked': false,
              'video_url': 'https://example.com/first-video.mp4',
            },
          ],
        });
      }
      return jsonResponse(200, {'success': true});
    });
    final provider = ReelProvider(apiService: api);
    provider.seedReel(selected());
    final loading = provider.fetchReels();
    await provider.toggleLike('feed-post');
    fetch.complete();
    await loading;
    final displayed = provider.displayReels(selected()).first;
    expect(displayed.isLiked, isTrue);
    expect(displayed.likesCount, 5);
    expect(displayed.mediaUrl, selected().mediaUrl);
    provider.dispose();
    api.client.close();
  });

  test('feed and saved posts reflect changes made from reels', () async {
    final api = ApiService();
    api.client.httpClientAdapter = StubAdapter(
      (options, bytes) async => jsonResponse(200, {
        'posts': [
          {'id': 'feed-post', 'text': 'Video', 'likes_count': 4},
        ],
      }),
    );
    final provider = PostProvider(apiService: api);
    await provider.fetchPosts();
    provider.syncReelEngagement(
      'feed-post',
      isLiked: true,
      likesCount: 5,
      isBookmarked: true,
    );
    expect(provider.posts.single.isLiked, isTrue);
    expect(provider.bookmarkedPosts.single.id, 'feed-post');
    provider.syncReelEngagement(
      'feed-post',
      isLiked: false,
      likesCount: 4,
      isBookmarked: false,
    );
    expect(provider.posts.single.isBookmarked, isFalse);
    expect(provider.bookmarkedPosts, isEmpty);
    provider.dispose();
    api.client.close();
  });
}

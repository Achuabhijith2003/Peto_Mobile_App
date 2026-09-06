import 'package:flutter_test/flutter_test.dart';
import 'package:peto_user/models/post_model.dart';
import 'package:peto_user/models/reel_model.dart';
import 'package:peto_user/services/feed_video_manager.dart';
import 'package:peto_user/services/api_service.dart';

void main() {
  group('PostMedia Tests', () {
    test('Correctly identifies video by extension and type', () {
      final mediaMp4 = PostMedia.fromJson('https://example.com/video.mp4');
      expect(mediaMp4.isVideo, isTrue);
      expect(mediaMp4.type, 'video');

      final mediaMov = PostMedia.fromJson({'url': 'https://example.com/pet.mov'});
      expect(mediaMov.isVideo, isTrue);

      final mediaImage = PostMedia.fromJson('https://example.com/dog.jpg');
      expect(mediaImage.isVideo, isFalse);
      expect(mediaImage.type, 'image');
    });

    test('Sanitizes duplicated video and image path prefixes', () {
      final sanitizedVideo = PostMedia.sanitizeUrl(
        'https://peto.com/storage/v1/object/public/posts-videos/posts-videos/pet_123.mp4',
      );
      expect(
        sanitizedVideo,
        'https://peto.com/storage/v1/object/public/posts-videos/pet_123.mp4',
      );

      final sanitizedImage = PostMedia.sanitizeUrl(
        'https://peto.com/storage/v1/object/public/posts-images/posts-images/dog.jpg',
      );
      expect(
        sanitizedImage,
        'https://peto.com/storage/v1/object/public/posts-images/dog.jpg',
      );
    });
  });

  group('Reel Model Tests', () {
    test('Extracts video URL even if mixed with image media', () {
      final json = {
        'id': 'reel_1',
        'media': [
          {'url': 'https://example.com/thumb.jpg', 'type': 'image'},
          {'url': 'https://example.com/posts-videos/posts-videos/pet_reel.mp4', 'type': 'video'},
        ],
        'caption': 'Cute kitten reel',
        'author': {
          'id': 'u1',
          'username': 'catlover',
        },
      };

      final reel = Reel.fromJson(json);
      expect(reel.id, 'reel_1');
      expect(
        reel.mediaUrl,
        'https://example.com/posts-videos/pet_reel.mp4',
      );
    });
  });

  group('FeedVideoManager Tests', () {
    test('Only allows one video to be active at a time', () {
      final manager = FeedVideoManager();
      bool video1Paused = false;
      bool video2Paused = false;

      manager.play('vid1', () => video1Paused = true);
      expect(manager.activeVideoId, 'vid1');
      expect(video1Paused, isFalse);

      manager.play('vid2', () => video2Paused = true);
      expect(manager.activeVideoId, 'vid2');
      expect(video1Paused, isTrue); // First video was auto-paused
      expect(video2Paused, isFalse);

      manager.pauseAll();
      expect(manager.activeVideoId, isNull);
      expect(video2Paused, isTrue);
    });
  });

  group('Media Upload Model Tests', () {
    test('MediaUploadResult holds URL and error states', () {
      final success = MediaUploadResult(success: true, mediaUrl: 'https://example.com/pic.webp');
      expect(success.success, isTrue);
      expect(success.mediaUrl, 'https://example.com/pic.webp');
      expect(success.errorMessage, isNull);

      final failure = MediaUploadResult(success: false, errorMessage: 'Please log in');
      expect(failure.success, isFalse);
      expect(failure.mediaUrl, isNull);
      expect(failure.errorMessage, 'Please log in');
    });
  });
}


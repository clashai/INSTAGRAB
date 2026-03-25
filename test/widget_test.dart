import 'package:flutter_test/flutter_test.dart';
import 'package:instagrab/services/instagram_service.dart';

void main() {
  group('InstagramService URL detection', () {
    test('detects reel URL', () {
      expect(InstagramService.isInstagramUrl('https://www.instagram.com/reel/ABC123/'), true);
    });

    test('detects post URL', () {
      expect(InstagramService.isInstagramUrl('https://www.instagram.com/p/XYZ789/'), true);
    });

    test('detects short URL', () {
      expect(InstagramService.isInstagramUrl('https://instagr.am/ABC123'), true);
    });

    test('rejects non-instagram URL', () {
      expect(InstagramService.isInstagramUrl('https://twitter.com/status/123'), false);
    });

    test('extracts URL from mixed text', () {
      final url = InstagramService.extractInstagramUrl(
        'Check this out https://www.instagram.com/reel/ABC123/ so cool!',
      );
      expect(url, 'https://www.instagram.com/reel/ABC123');
    });
  });
}

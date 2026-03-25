import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

const _encodingChars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

class InstagramService {
  static final _reelPattern = RegExp(
    r'(https?://)?(www\.)?instagram\.com/(reel|p|tv|reels)/[A-Za-z0-9_-]+',
  );
  static final _shortPattern = RegExp(
    r'(https?://)?instagr\.am/[A-Za-z0-9_-]+',
  );

  static const _appId = '936619743392459';
  static const _graphqlDocId = '8845758582119845';

  static const _apiHeaders = {
    'X-IG-App-ID': _appId,
    'X-ASBD-ID': '198387',
    'X-IG-WWW-Claim': '0',
    'Origin': 'https://www.instagram.com',
    'Accept': '*/*',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  };

  static bool isInstagramUrl(String text) {
    return _reelPattern.hasMatch(text) || _shortPattern.hasMatch(text);
  }

  static String? extractInstagramUrl(String text) {
    final match =
        _reelPattern.firstMatch(text) ?? _shortPattern.firstMatch(text);
    if (match == null) return null;
    var url = match.group(0)!;
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.parse(url);
    return '${uri.scheme}://${uri.host}${uri.path}';
  }

  static String _extractShortcode(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2) return segments[1];
    return segments.last;
  }

  /// Convert Instagram shortcode to numeric PK (same algorithm as yt-dlp).
  static BigInt _shortcodeToPk(String shortcode) {
    if (shortcode.length > 28) shortcode = shortcode.substring(0, shortcode.length - 28);
    var result = BigInt.zero;
    for (var i = 0; i < shortcode.length; i++) {
      final idx = _encodingChars.indexOf(shortcode[i]);
      if (idx < 0) continue;
      result = result * BigInt.from(64) + BigInt.from(idx);
    }
    return result;
  }

  static Future<Map<String, String?>> getVideoInfo(String url) async {
    final shortcode = _extractShortcode(url);
    final mediaPk = _shortcodeToPk(shortcode);

    String? videoUrl;
    String? thumbnailUrl;
    String? caption;

    // Strategy 1: GraphQL query (yt-dlp primary method for non-logged-in users)
    videoUrl = null;
    try {
      final result = await _tryGraphQL(shortcode);
      videoUrl = result['videoUrl'];
      thumbnailUrl = result['thumbnailUrl'];
      caption = result['caption'];
    } catch (_) {}

    // Strategy 2: Embed page (yt-dlp fallback)
    if (videoUrl == null) {
      try {
        final result = await _tryEmbedPage(url, shortcode);
        videoUrl = result['videoUrl'];
        thumbnailUrl ??= result['thumbnailUrl'];
        caption ??= result['caption'];
      } catch (_) {}
    }

    // Strategy 3: API v1 media info (needs the numeric PK)
    if (videoUrl == null) {
      try {
        final result = await _tryApiV1(mediaPk);
        videoUrl = result['videoUrl'];
        thumbnailUrl ??= result['thumbnailUrl'];
        caption ??= result['caption'];
      } catch (_) {}
    }

    // Strategy 4: ?__a=1&__d=dis JSON endpoint
    if (videoUrl == null) {
      try {
        final result = await _tryJsonEndpoint(url);
        videoUrl = result['videoUrl'];
        thumbnailUrl ??= result['thumbnailUrl'];
        caption ??= result['caption'];
      } catch (_) {}
    }

    // Strategy 5: Direct HTML scrape for og:video meta tags
    if (videoUrl == null) {
      try {
        final result = await _tryHtmlScrape(url);
        videoUrl = result['videoUrl'];
        thumbnailUrl ??= result['thumbnailUrl'];
        caption ??= result['caption'];
      } catch (_) {}
    }

    // Strategy 6: oEmbed for metadata (no video URL, just enrichment)
    if (thumbnailUrl == null || caption == null) {
      try {
        final result = await _tryOembed(url);
        thumbnailUrl ??= result['thumbnailUrl'];
        caption ??= result['caption'];
      } catch (_) {}
    }

    return {
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
    };
  }

  /// Strategy 1: GraphQL query with doc_id (same as yt-dlp)
  static Future<Map<String, String?>> _tryGraphQL(String shortcode) async {
    // First, set up a session by hitting the ruling endpoint
    final client = http.Client();
    try {
      final mediaPk = _shortcodeToPk(shortcode);

      // Setup session — get csrftoken cookie
      try {
        await client.get(
          Uri.parse(
              'https://i.instagram.com/api/v1/web/get_ruling_for_content/'
              '?content_type=MEDIA&target_id=$mediaPk'),
          headers: _apiHeaders,
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}

      final variables = jsonEncode({
        'shortcode': shortcode,
        'child_comment_count': 3,
        'fetch_comment_count': 40,
        'parent_comment_count': 24,
        'has_threaded_comments': true,
      });

      final res = await client.get(
        Uri.parse('https://www.instagram.com/graphql/query/')
            .replace(queryParameters: {
          'doc_id': _graphqlDocId,
          'variables': variables,
        }),
        headers: {
          ..._apiHeaders,
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': 'https://www.instagram.com/',
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final media = data['data']?['xdt_shortcode_media'];
        if (media != null) {
          return _parseGraphqlMedia(media);
        }
      }
    } finally {
      client.close();
    }
    return {'videoUrl': null, 'thumbnailUrl': null, 'caption': null};
  }

  /// Strategy 2: Embed page parsing (yt-dlp fallback)
  static Future<Map<String, String?>> _tryEmbedPage(
      String url, String shortcode) async {
    final cleanUrl = url.endsWith('/') ? url : '$url/';
    final embedUrl = '${cleanUrl}embed/';

    final res = await http.get(
      Uri.parse(embedUrl),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml',
      },
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      return {'videoUrl': null, 'thumbnailUrl': null, 'caption': null};
    }

    final body = res.body;

    // Look for window.__additionalDataLoaded (yt-dlp's method)
    final additionalDataMatch = RegExp(
      r'window\.__additionalDataLoaded\s*\(\s*[^,]+,\s*(\{.+?\})\s*\)',
      dotAll: true,
    ).firstMatch(body);

    if (additionalDataMatch != null) {
      try {
        final data = jsonDecode(additionalDataMatch.group(1)!);

        // Check for items array (product media format)
        final items = data['items'];
        if (items is List && items.isNotEmpty) {
          final item = items[0];
          final versions = item['video_versions'];
          String? vUrl;
          if (versions is List && versions.isNotEmpty) {
            vUrl = versions[0]['url'];
          }
          final thumb =
              item['image_versions2']?['candidates']?[0]?['url'] as String?;
          final cap = item['caption']?['text'] as String?;
          if (vUrl != null) {
            return {'videoUrl': vUrl, 'thumbnailUrl': thumb, 'caption': cap};
          }
        }

        // Check for graphql shortcode_media
        final media =
            data['graphql']?['shortcode_media'] ?? data['shortcode_media'];
        if (media != null) {
          return _parseGraphqlMedia(media);
        }
      } catch (_) {}
    }

    // Fallback: look for video_url in any script tag
    final videoUrlMatch =
        RegExp(r'"video_url"\s*:\s*"([^"]+)"').firstMatch(body);
    if (videoUrlMatch != null) {
      final vUrl = videoUrlMatch.group(1)!.replaceAll(r'\u0026', '&');
      return {'videoUrl': vUrl, 'thumbnailUrl': null, 'caption': null};
    }

    return {'videoUrl': null, 'thumbnailUrl': null, 'caption': null};
  }

  /// Strategy 3: Instagram API v1 media info
  static Future<Map<String, String?>> _tryApiV1(BigInt mediaPk) async {
    final res = await http.get(
      Uri.parse(
          'https://i.instagram.com/api/v1/media/${mediaPk}/info/'),
      headers: _apiHeaders,
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final items = data['items'];
      if (items is List && items.isNotEmpty) {
        final item = items[0];
        final versions = item['video_versions'];
        String? vUrl;
        if (versions is List && versions.isNotEmpty) {
          // Pick the highest quality
          vUrl = versions[0]['url'];
        }
        final thumb =
            item['image_versions2']?['candidates']?[0]?['url'] as String?;
        final cap = item['caption']?['text'] as String?;
        return {'videoUrl': vUrl, 'thumbnailUrl': thumb, 'caption': cap};
      }
    }

    return {'videoUrl': null, 'thumbnailUrl': null, 'caption': null};
  }

  /// Strategy 4: ?__a=1&__d=dis JSON endpoint
  static Future<Map<String, String?>> _tryJsonEndpoint(String url) async {
    final cleanUrl = url.endsWith('/') ? url : '$url/';
    final jsonUrl = '${cleanUrl}?__a=1&__d=dis';
    final res = await http.get(
      Uri.parse(jsonUrl),
      headers: {
        ..._apiHeaders,
        'Accept': '*/*',
        'X-Requested-With': 'XMLHttpRequest',
      },
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final media = data['graphql']?['shortcode_media'] ??
          data['data']?['shortcode_media'];
      if (media != null) {
        return _parseGraphqlMedia(media);
      }

      // v1 format
      final items = data['items'];
      if (items is List && items.isNotEmpty) {
        final item = items[0];
        final versions = item['video_versions'];
        String? vUrl;
        if (versions is List && versions.isNotEmpty) {
          vUrl = versions[0]['url'];
        }
        final thumb =
            item['image_versions2']?['candidates']?[0]?['url'] as String?;
        final cap = item['caption']?['text'] as String?;
        return {'videoUrl': vUrl, 'thumbnailUrl': thumb, 'caption': cap};
      }
    }

    return {'videoUrl': null, 'thumbnailUrl': null, 'caption': null};
  }

  /// Strategy 5: HTML scrape for og:video
  static Future<Map<String, String?>> _tryHtmlScrape(String url) async {
    final res = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml',
      },
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      return {'videoUrl': null, 'thumbnailUrl': null, 'caption': null};
    }

    String? videoUrl;
    String? thumbnailUrl;
    String? caption;

    final document = html_parser.parse(res.body);
    for (final tag in document.getElementsByTagName('meta')) {
      final property =
          tag.attributes['property'] ?? tag.attributes['name'] ?? '';
      final content = tag.attributes['content'] ?? '';
      if (content.isEmpty) continue;
      if (property == 'og:video' || property == 'og:video:url') {
        videoUrl ??= content;
      }
      if (property == 'og:image') thumbnailUrl ??= content;
      if (property == 'og:description') caption ??= content;
    }

    // Also look for sharedData or video_url in scripts
    if (videoUrl == null) {
      for (final script in document.getElementsByTagName('script')) {
        final text = script.text;

        // window._sharedData
        if (text.contains('window._sharedData')) {
          final match =
              RegExp(r'window\._sharedData\s*=\s*(\{.+?\})\s*;').firstMatch(text);
          if (match != null) {
            try {
              final shared = jsonDecode(match.group(1)!);
              final media = shared['entry_data']?['PostPage']?[0]
                      ?['graphql']?['shortcode_media'] ??
                  shared['entry_data']?['PostPage']?[0]?['media'];
              if (media != null) {
                final parsed = _parseGraphqlMedia(media);
                videoUrl ??= parsed['videoUrl'];
                thumbnailUrl ??= parsed['thumbnailUrl'];
                caption ??= parsed['caption'];
              }
            } catch (_) {}
          }
        }

        // Direct video_url in JSON
        if (videoUrl == null && text.contains('"video_url"')) {
          final m = RegExp(r'"video_url"\s*:\s*"([^"]+)"').firstMatch(text);
          if (m != null) {
            videoUrl = m.group(1)!.replaceAll(r'\u0026', '&');
          }
        }
      }
    }

    return {
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
    };
  }

  /// Strategy 6: oEmbed for metadata
  static Future<Map<String, String?>> _tryOembed(String url) async {
    final res = await http.get(
      Uri.parse('https://api.instagram.com/oembed?url=$url'),
      headers: {'User-Agent': 'Mozilla/5.0'},
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return {
        'videoUrl': null,
        'thumbnailUrl': data['thumbnail_url'] as String?,
        'caption': data['title'] as String?,
      };
    }

    return {'videoUrl': null, 'thumbnailUrl': null, 'caption': null};
  }

  /// Parse GraphQL shortcode_media into our result format (shared by multiple strategies)
  static Map<String, String?> _parseGraphqlMedia(Map<String, dynamic> media) {
    String? videoUrl = media['video_url'] as String?;
    String? thumbnailUrl = (media['display_url'] ??
        media['thumbnail_src'] ??
        media['display_src']) as String?;
    String? caption;

    final edges = media['edge_media_to_caption']?['edges'];
    if (edges is List && edges.isNotEmpty) {
      caption = edges[0]['node']?['text'] as String?;
    }
    caption ??= media['caption']?['text'] as String?;

    // If main media has no video_url, check carousel children
    if (videoUrl == null) {
      final sidecar = media['edge_sidecar_to_children']?['edges'];
      if (sidecar is List) {
        for (final edge in sidecar) {
          final node = edge['node'];
          if (node != null &&
              (node['__typename'] == 'GraphVideo' ||
                  node['is_video'] == true)) {
            videoUrl = node['video_url'] as String?;
            thumbnailUrl ??= node['display_url'] as String?;
            if (videoUrl != null) break;
          }
        }
      }
    }

    // Also check video_versions (API v1 format sometimes nested in graphql)
    if (videoUrl == null) {
      final versions = media['video_versions'];
      if (versions is List && versions.isNotEmpty) {
        videoUrl = versions[0]['url'] as String?;
      }
    }

    return {
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
    };
  }
}

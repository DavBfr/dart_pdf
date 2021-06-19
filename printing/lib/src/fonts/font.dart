import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart';

import '../cache.dart';
import 'manifest.dart';

/// Downloadable font object
class DownloadbleFont {
  /// Create a downloadable font object
  const DownloadbleFont(this.url, this.name);

  /// The Url to get the font from
  final String url;

  /// The Font filename
  final String name;

  /// The cache to use
  static var cache = PdfBaseCache.defaultCache;

  /// Get the font to use in a Pdf document
  Future<Font> getFont({
    PdfBaseCache? pdfCache,
    bool protect = false,
    Map<String, String>? headers,
    String assetPrefix = 'google_fonts/',
    AssetBundle? bundle,
    bool cache = true,
  }) async {
    final asset = '$assetPrefix$name.ttf';
    if (await AssetManifest.contains(asset)) {
      bundle ??= rootBundle;
      final data = await bundle.load(asset);
      return TtfFont(
        data,
        protect: protect,
      );
    }

    pdfCache ??= PdfBaseCache.defaultCache;

    try {
      final bytes = await pdfCache.resolve(
        name: name,
        uri: Uri.parse(url),
        headers: headers,
        cache: cache,
      );

      return TtfFont(
        bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes),
        protect: protect,
      );
    } catch (e) {
      print('$e\nError loading $name, fallback to Helvetica.');
      return Font.helvetica();
    }
  }
}

/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart';

import '../cache.dart';
import 'manifest.dart' as manifest;

/// Downloadable font object
class DownloadableFont {
  /// Create a downloadable font object
  const DownloadableFont(this.url, this.name);

  /// The Url to get the font from
  final String url;

  /// The Font filename
  final String name;

  /// The cache to use
  static var cache = PdfBaseCache.defaultCache;

  /// The font to substitute when a download fails.
  ///
  /// Null by default, which makes [getFont] report the failure to the caller.
  /// Set it once - to `Font.helvetica()` - to restore the behaviour of printing
  /// 5.16 and earlier, where a failed download silently produced a Helvetica
  /// document: a PDF in which every rune outside 0x00-0xFF is a crossed box.
  static Font? defaultFallback;

  /// Get the font to use in a Pdf document
  Future<Font> getFont({
    PdfBaseCache? pdfCache,
    bool protect = false,
    Map<String, String>? headers,
    String assetPrefix = 'google_fonts/',
    AssetBundle? bundle,
    bool cache = true,
    Font? fallback,
  }) async {
    final asset = '$assetPrefix$name.ttf';
    if (await manifest.AssetManifest.contains(asset)) {
      bundle ??= rootBundle;
      final data = await bundle.load(asset);
      return TtfFont(data, protect: protect);
    }

    pdfCache ??= PdfBaseCache.defaultCache;

    try {
      final bytes = await pdfCache.resolve(
        name: name,
        uri: Uri.parse(url),
        headers: headers,
        cache: cache,
      );

      final font = TtfFont(
        bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes),
        protect: protect,
      );

      try {
        // TtfFont parses lazily, so reading the name is what tells a real font
        // from a captive portal's HTML body or a truncated download. Without
        // this the bad bytes were happily returned and surfaced much later as a
        // RangeError from inside the TTF reader, with no mention of the font.
        if (font.fontName.isEmpty) {
          throw Exception('it carries no name');
        }

        return font;
      } catch (e) {
        // And do not serve those bytes again.
        await pdfCache.remove(name);
        throw FlutterError('Unable to read the font $name from $url: $e');
      }
    } catch (e, s) {
      final substitute = fallback ?? defaultFallback;

      if (substitute == null) {
        // The caller's problem, not a silent Helvetica document. The old code's
        // only report sat inside an assert, which release and profile builds
        // strip entirely.
        rethrow;
      }

      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'printing',
          context: ErrorDescription(
            'while downloading the font $name, substituting the fallback',
          ),
        ),
      );

      return substitute;
    }
  }
}

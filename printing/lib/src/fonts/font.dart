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
      assert(() {
        // ignore: avoid_print
        print('$e\nError loading $name, fallback to Helvetica.');
        return true;
      }());

      return Font.helvetica();
    }
  }
}

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

/// Where the web backend loads pdf.js from.
///
/// This holds no web dependency, so it can be read and tested on its own.
class PdfJsUrls {
  /// Build a set of URLs directly. Prefer [PdfJsUrls.resolve].
  const PdfJsUrls({
    required this.module,
    required this.worker,
    required this.cMap,
  });

  /// Resolve every URL from the values an app can set on `window`.
  ///
  /// [documentBaseUri] is `document.baseURI`: the page's own URL, or the
  /// `<base href>` when it has one.
  ///
  /// [configuredBase] is `dartPdfJsBaseUrl`. It is resolved against
  /// [documentBaseUri] and given a trailing slash, because a dynamic `import()`
  /// resolves its argument as a module specifier rather than as a
  /// document-relative URL: anything that is not absolute and does not start
  /// with `/`, `./` or `../` is a bare specifier, which a browser with no
  /// import map rejects outright. The value this package's README documented,
  /// `assets/js/pdf/<version>/`, has exactly that shape, so self-hosting could
  /// not work once pdf.js moved to ES modules.
  ///
  /// [configuredCMapUrl] is `dartPdfJsCMapUrl`, for a self-hoster whose
  /// `cmaps/` directory is not beside the library.
  factory PdfJsUrls.resolve({
    required String documentBaseUri,
    String? configuredBase,
    String? configuredCMapUrl,
    String cdnPath = defaultCdnPath,
    String version = defaultVersion,
  }) {
    final String base;
    final String cMap;

    if (configuredBase != null && configuredBase.isNotEmpty) {
      base = _absolute(configuredBase, documentBaseUri);
      cMap = '${base}cmaps/';
    } else {
      base = '$cdnPath@$version/build/';
      // pdfjs-dist keeps the .bcmap files in cmaps/, a sibling of build/ and
      // not a child of it.
      cMap = '$cdnPath@$version/cmaps/';
    }

    return PdfJsUrls(
      module: '${base}pdf.min.mjs',
      worker: '${base}pdf.worker.min.mjs',
      cMap: configuredCMapUrl != null && configuredCMapUrl.isNotEmpty
          ? _absolute(configuredCMapUrl, documentBaseUri)
          : cMap,
    );
  }

  /// The package the default URLs point at.
  static const defaultCdnPath = 'https://unpkg.com/pdfjs-dist';

  /// The pdf.js version the default URLs request.
  static const defaultVersion = '6.2.108';

  /// The ES module to `import()`.
  final String module;

  /// The value for `GlobalWorkerOptions.workerSrc`.
  final String worker;

  /// The directory holding the predefined CMaps, with a trailing slash.
  ///
  /// Without it, a PDF whose CID fonts use a predefined CMap - `UniJIS-UCS2-H`,
  /// `GBK-EUC-H` - rasterizes with that text missing and no error.
  final String cMap;

  /// Resolve [url] against [documentBaseUri] and give it a trailing slash.
  static String _absolute(String url, String documentBaseUri) {
    final withSlash = url.endsWith('/') ? url : '$url/';

    try {
      return Uri.parse(documentBaseUri).resolve(withSlash).toString();
    } on FormatException {
      // A document base this malformed cannot be made worse than the bare
      // specifier this replaces.
      return withSlash;
    }
  }

  @override
  String toString() => '$runtimeType $module worker:$worker cmaps:$cMap';
}

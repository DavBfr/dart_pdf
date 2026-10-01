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

import 'package:flutter_test/flutter_test.dart';
import 'package:printing/src/pdfjs_urls.dart';

/// A page served from a subdirectory, which is what makes a relative base
/// ambiguous in the first place.
const _pageUri = 'https://example.com/app/index.html';

void main() {
  group('the default configuration', () {
    final urls = PdfJsUrls.resolve(documentBaseUri: _pageUri);

    test('loads the module from the CDN', () {
      expect(
        urls.module,
        'https://unpkg.com/pdfjs-dist@${PdfJsUrls.defaultVersion}'
        '/build/pdf.min.mjs',
      );
    });

    test('loads the worker beside it', () {
      expect(
        urls.worker,
        'https://unpkg.com/pdfjs-dist@${PdfJsUrls.defaultVersion}'
        '/build/pdf.worker.min.mjs',
      );
    });

    test('takes the cmaps from beside build, not from inside it', () {
      // pdfjs-dist keeps them at <pkg>/cmaps/. The old code asked for
      // '<pkg>/build//cmaps/', which is a 404.
      expect(
        urls.cMap,
        'https://unpkg.com/pdfjs-dist@${PdfJsUrls.defaultVersion}/cmaps/',
      );
      expect(urls.cMap, isNot(contains('build')));
      expect(urls.cMap, isNot(contains('//cmaps')));
    });

    test('honours an explicit version', () {
      final pinned = PdfJsUrls.resolve(
        documentBaseUri: _pageUri,
        version: '4.0.0',
      );

      expect(pinned.module, contains('pdfjs-dist@4.0.0/build/'));
      expect(pinned.cMap, 'https://unpkg.com/pdfjs-dist@4.0.0/cmaps/');
    });
  });

  group('a configured base is made absolute', () {
    // A dynamic import() treats anything that is not absolute and does not
    // start with '/', './' or '../' as a bare module specifier, which the
    // browser rejects with 'Failed to resolve module specifier'. Every one of
    // these has to come out as a URL.
    const cases = <String, String>{
      // The shape the README documented, which never worked.
      'assets/js/pdf/6.2.108/':
          'https://example.com/app/assets/js/pdf/6.2.108/',
      './assets/js/pdf/': 'https://example.com/app/assets/js/pdf/',
      '../shared/pdfjs/': 'https://example.com/shared/pdfjs/',
      '/assets/js/pdf/': 'https://example.com/assets/js/pdf/',
      'https://cdn.example.com/pdfjs/': 'https://cdn.example.com/pdfjs/',
      '//cdn.example.com/pdfjs/': 'https://cdn.example.com/pdfjs/',
    };

    cases.forEach((String base, String expected) {
      test("'$base' resolves to '$expected'", () {
        final urls = PdfJsUrls.resolve(
          documentBaseUri: _pageUri,
          configuredBase: base,
        );

        expect(urls.module, '${expected}pdf.min.mjs');
        expect(urls.worker, '${expected}pdf.worker.min.mjs');
        expect(urls.cMap, '${expected}cmaps/');
      });
    });

    test('a base with no trailing slash gains one', () {
      final urls = PdfJsUrls.resolve(
        documentBaseUri: _pageUri,
        configuredBase: 'assets/js/pdf/6.2.108',
      );

      expect(
        urls.module,
        'https://example.com/app/assets/js/pdf/6.2.108/pdf.min.mjs',
      );
      expect(urls.module, isNot(contains('6.2.108pdf')));
    });

    test('a <base href> is what a relative base resolves against', () {
      // document.baseURI is the <base href> when the page sets one.
      final urls = PdfJsUrls.resolve(
        documentBaseUri: 'https://example.com/deployed/at/',
        configuredBase: 'assets/js/pdf/',
      );

      expect(
        urls.module,
        'https://example.com/deployed/at/assets/js/pdf/pdf.min.mjs',
      );
    });

    test('an empty base is no base at all', () {
      final urls = PdfJsUrls.resolve(
        documentBaseUri: _pageUri,
        configuredBase: '',
      );

      expect(urls.module, startsWith(PdfJsUrls.defaultCdnPath));
    });
  });

  group('the cmaps URL', () {
    test('can be overridden on its own', () {
      final urls = PdfJsUrls.resolve(
        documentBaseUri: _pageUri,
        configuredCMapUrl: 'assets/cmaps/',
      );

      expect(urls.cMap, 'https://example.com/app/assets/cmaps/');
      // The library still comes from the CDN.
      expect(urls.module, startsWith(PdfJsUrls.defaultCdnPath));
    });

    test('overrides the one derived from a configured base', () {
      final urls = PdfJsUrls.resolve(
        documentBaseUri: _pageUri,
        configuredBase: 'assets/js/pdf/',
        configuredCMapUrl: '/shared/cmaps/',
      );

      expect(urls.cMap, 'https://example.com/shared/cmaps/');
    });

    test('is a directory, so it always ends in a slash', () {
      final urls = PdfJsUrls.resolve(
        documentBaseUri: _pageUri,
        configuredCMapUrl: 'assets/cmaps',
      );

      expect(urls.cMap, endsWith('/'));
    });
  });

  test('a malformed document base does not throw', () {
    // Nothing useful can be resolved, but the caller gets a specifier that is
    // no worse than what it passed in.
    final urls = PdfJsUrls.resolve(
      documentBaseUri: 'http://[',
      configuredBase: './assets/js/pdf/',
    );

    expect(urls.module, contains('pdf.min.mjs'));
  });
}

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
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart';
import 'package:printing/printing.dart';

/// flutter_test answers 400 for every HTTP request, so any download fails.
const _url = 'https://example.com/missing.ttf';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<FlutterErrorDetails> reported;
  late FlutterExceptionHandler? previousOnError;
  late PdfMemoryCache cache;

  setUp(() {
    reported = <FlutterErrorDetails>[];
    previousOnError = FlutterError.onError;
    FlutterError.onError = reported.add;
    cache = PdfMemoryCache();
    DownloadableFont.defaultFallback = null;
  });

  tearDown(() {
    FlutterError.onError = previousOnError;
    DownloadableFont.defaultFallback = null;
  });

  test('a failed download reaches the caller', () async {
    // It used to return Helvetica, so a release build shipped a document in
    // which every rune outside 0x00-0xFF was a crossed box - silently, because
    // the only report sat inside an assert.
    await expectLater(
      const DownloadableFont(_url, 'Missing').getFont(pdfCache: cache),
      throwsA(isA<Object>()),
    );

    expect(reported, isEmpty, reason: 'the caller was told; nothing to report');
  });

  test('a failed download carries a stack trace', () async {
    Object? error;
    StackTrace? stack;

    try {
      await const DownloadableFont(_url, 'Missing').getFont(pdfCache: cache);
    } catch (e, s) {
      error = e;
      stack = s;
    }

    expect(error, isNotNull);
    expect(stack, isNotNull);
  });

  test('an explicit fallback is substituted, and reported once', () async {
    final font = await const DownloadableFont(
      _url,
      'Missing',
    ).getFont(pdfCache: cache, fallback: Font.helvetica());

    expect(font, isA<Font>());
    expect(reported, hasLength(1));
    expect(reported.single.library, 'printing');
    expect(reported.single.context.toString(), contains('Missing'));
    expect(reported.single.stack, isNotNull);
  });

  test('the default fallback restores the old behaviour', () async {
    DownloadableFont.defaultFallback = Font.helvetica();

    final font = await const DownloadableFont(
      _url,
      'Missing',
    ).getFont(pdfCache: cache);

    expect(font, isA<Font>());
    expect(reported, hasLength(1));
  });

  test('a body that is not a font is a named font error', () async {
    // What a captive portal serves. It used to surface as a RangeError from
    // deep inside the TTF reader, with no mention of the font.
    await cache.add(
      'Missing',
      Uint8List.fromList('<html>Sign in</html>'.codeUnits),
    );
    expect(await cache.contains('Missing'), isTrue);

    await expectLater(
      const DownloadableFont(_url, 'Missing').getFont(pdfCache: cache),
      throwsA(
        isA<FlutterError>().having(
          (FlutterError e) => e.message,
          'message',
          allOf(contains('Missing'), contains(_url)),
        ),
      ),
    );

    expect(
      await cache.contains('Missing'),
      isFalse,
      reason: 'the bad bytes must not be served again',
    );
  });

  test(
    'a body that is not a font can still be replaced by a fallback',
    () async {
      await cache.add(
        'Missing',
        Uint8List.fromList('<html>Sign in</html>'.codeUnits),
      );

      final font = await const DownloadableFont(
        _url,
        'Missing',
      ).getFont(pdfCache: cache, fallback: Font.helvetica());

      expect(font, isA<Font>());
      expect(reported, hasLength(1));
      expect(await cache.contains('Missing'), isFalse);
    },
  );
}

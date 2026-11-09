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

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:printing/printing.dart';

final _uri = Uri.parse('https://example.invalid/asset');

/// Runs [body] with every `http.get` answered by [handler], counting requests.
Future<T> _withServer<T>(
  Future<http.Response> Function() handler,
  Future<T> Function(int Function() requests) body,
) {
  var requests = 0;
  return http.runWithClient(
    () => body(() => requests),
    () => MockClient((_) {
      requests++;
      return handler();
    }),
  );
}

void main() {
  test('simultaneous cached requests share one download', () async {
    final gate = Completer<http.Response>();
    await _withServer(() => gate.future, (requests) async {
      final cache = PdfMemoryCache();
      final results = List.generate(
        12,
        (_) => cache.resolve(name: 'same-font', uri: _uri),
      );

      // Let every request reach the network without answering it.
      await pumpEventQueue();
      expect(requests(), 1);

      gate.complete(http.Response.bytes([1, 2, 3, 4], 200));
      final first = await results.first;
      expect(first, [1, 2, 3, 4]);
      for (final result in await Future.wait(results)) {
        expect(result, same(first));
      }

      expect(await cache.resolve(name: 'same-font', uri: _uri), same(first));
      expect(requests(), 1);
    });
  });

  test('a failed download is shared, then retried', () async {
    var status = 404;
    await _withServer(() async => http.Response.bytes([7], status), (
      requests,
    ) async {
      final cache = PdfMemoryCache();
      final failures = await Future.wait([
        for (var i = 0; i < 3; i++)
          cache
              .resolve(name: 'retry', uri: _uri)
              .then<Object?>((_) => null, onError: (Object e) => e),
      ]);
      expect(failures, everyElement(isA<Error>()));
      expect(requests(), 1);
      expect(await cache.contains('retry'), isFalse);

      status = 200;
      expect(await cache.resolve(name: 'retry', uri: _uri), [7]);
      expect(requests(), 2);
    });
  });

  test('cache=false bypasses the cached result and deduplication', () async {
    await _withServer(() async => http.Response.bytes([9], 200), (
      requests,
    ) async {
      final cache = PdfMemoryCache();
      await cache.resolve(name: 'asset', uri: _uri);
      await Future.wait([
        cache.resolve(name: 'asset', uri: _uri, cache: false),
        cache.resolve(name: 'asset', uri: _uri, cache: false),
      ]);
      expect(requests(), 3);
    });
  });
}

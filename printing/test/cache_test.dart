import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:printing/src/cache.dart';

class _FakeMemoryCache extends PdfMemoryCache {
  _FakeMemoryCache(this.fetch);

  final Future<Uint8List?> Function() fetch;
  int requests = 0;

  @override
  Future<Uint8List?> download(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    requests++;
    return fetch();
  }
}

void main() {
  final uri = Uri.parse('https://example.invalid/asset');

  test('simultaneous cached asset requests share one download', () async {
    final gate = Completer<Uint8List?>();
    final cache = _FakeMemoryCache(() => gate.future);
    final results = List.generate(
      12,
      (_) => cache.resolve(name: 'same-font', uri: uri),
    );

    // Let the first request reach download without completing it.
    await Future<void>.delayed(Duration.zero);
    expect(cache.requests, 1);

    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    gate.complete(bytes);
    for (final result in await Future.wait(results)) {
      expect(result, same(bytes));
    }

    expect(await cache.resolve(name: 'same-font', uri: uri), same(bytes));
    expect(cache.requests, 1);
  });

  test('a download error is not cached or left in flight', () async {
    var fails = true;
    final cache = _FakeMemoryCache(() async {
      if (fails) {
        throw StateError('network failed');
      }
      return Uint8List.fromList([7]);
    });

    await expectLater(
      cache.resolve(name: 'retry', uri: uri),
      throwsStateError,
    );
    fails = false;
    expect(await cache.resolve(name: 'retry', uri: uri), [7]);
    expect(cache.requests, 2);
  });

  test('cache=false bypasses cached result and deduplication', () async {
    final cache = _FakeMemoryCache(() async => Uint8List.fromList([9]));
    await cache.resolve(name: 'asset', uri: uri);
    await Future.wait([
      cache.resolve(name: 'asset', uri: uri, cache: false),
      cache.resolve(name: 'asset', uri: uri, cache: false),
    ]);
    expect(cache.requests, 3);
  });
}

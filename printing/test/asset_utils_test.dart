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
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' as rdr;
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';

/// An image whose pixels cannot be read.
///
/// On the web this is what a canvas tainted by a cross-origin image behaves
/// like: the decode succeeds and the read-back throws.
class _UnreadableImage implements ui.Image {
  _UnreadableImage({required this.readBack});

  /// What `toByteData` does: throw, or resolve to null.
  final Future<ByteData?> Function() readBack;

  @override
  int get width => 2;

  @override
  int get height => 2;

  @override
  Future<ByteData?> toByteData({
    ui.ImageByteFormat format = ui.ImageByteFormat.rawRgba,
  }) => readBack();

  @override
  void dispose() {}

  @override
  bool get debugDisposed => false;

  @override
  ui.ColorSpace get colorSpace => ui.ColorSpace.sRGB;

  @override
  ui.Image clone() => this;

  @override
  bool isCloneOf(ui.Image other) => other == this;

  @override
  List<StackTrace>? debugGetOpenHandleStackTraces() => null;
}

/// Delivers one image, or one failure, to whoever listens.
class _StubProvider extends rdr.ImageProvider<Object> {
  _StubProvider({this.image, this.failure});

  final ui.Image? image;
  final Object? failure;

  int listeners = 0;
  int removed = 0;

  bool get stillListening => _completer.stillListening;

  late final _completer = _StubCompleter(this);

  @override
  Future<Object> obtainKey(rdr.ImageConfiguration configuration) async => this;

  @override
  rdr.ImageStreamCompleter loadImage(
    Object key,
    rdr.ImageDecoderCallback decode,
  ) => _completer;

  void deliver() {
    final failed = failure;
    if (failed != null) {
      _completer.fail(failed);
      return;
    }
    _completer.deliver(image!);
  }
}

class _StubCompleter extends rdr.ImageStreamCompleter {
  _StubCompleter(this.provider);

  final _StubProvider provider;

  void deliver(ui.Image image) {
    setImage(rdr.ImageInfo(image: image));
  }

  void fail(Object error) {
    reportError(exception: error, stack: StackTrace.current);
  }

  @override
  void addListener(rdr.ImageStreamListener listener) {
    provider.listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(rdr.ImageStreamListener listener) {
    provider.removed++;
    super.removeListener(listener);
  }

  /// Whether anything is still subscribed.
  ///
  /// The count of add/remove calls also sees ImageStream's own handover
  /// listener, so this is what says the provider let go of its own.
  bool get stillListening => hasListeners;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Resolve [provider] and settle, collecting anything that escapes to the
  /// ambient zone on the way.
  Future<({Object? error, List<Object> zoneErrors, List<Object> reported})>
  resolve(_StubProvider provider, {bool withOnError = false}) async {
    final zoneErrors = <Object>[];
    final reported = <Object>[];
    final done = Completer<void>();
    Object? error;

    // An async body whose error reaches runZonedGuarded's handler leaves the
    // future it returns pending for ever, so completion is signalled
    // explicitly and nothing inside the zone asserts.
    runZonedGuarded(
      () async {
        try {
          final pending = flutterImageProvider(
            provider,
            onError: withOnError
                ? (Object e, StackTrace? s) => reported.add(e)
                : null,
          );

          // ImageProvider.resolve is non-virtual and attaches the completer
          // through an async obtainKey, so wait for the listener before
          // delivering anything to it.
          for (var i = 0; provider.listeners == 0 && i < 200; i++) {
            await Future<void>.delayed(Duration.zero);
          }
          provider.deliver();

          await pending.timeout(const Duration(seconds: 2));
        } catch (e) {
          error = e;
        } finally {
          if (!done.isCompleted) {
            done.complete();
          }
        }
      },
      (Object e, StackTrace s) {
        zoneErrors.add(e);
        if (!done.isCompleted) {
          done.complete();
        }
      },
    );

    await done.future;

    return (error: error, zoneErrors: zoneErrors, reported: reported);
  }

  test('a read-back that throws rejects instead of hanging', () async {
    // setImage discards the future the listener returns, so this used to become
    // an unhandled zone error and the completer was never settled: on web a
    // CORS-tainted image made the preview spin for ever.
    final provider = _StubProvider(
      image: _UnreadableImage(
        readBack: () async => throw Exception('tainted canvas'),
      ),
    );

    final result = await resolve(provider);

    expect(result.error, isA<Exception>());
    expect(result.error.toString(), contains('tainted canvas'));
    expect(result.error, isNot(isA<TimeoutException>()));
    expect(result.zoneErrors, isEmpty);
    expect(provider.removed, greaterThanOrEqualTo(1));
    expect(provider.stillListening, isFalse);
  });

  test('a read-back that resolves to null rejects descriptively', () async {
    final provider = _StubProvider(
      image: _UnreadableImage(readBack: () async => null),
    );

    final result = await resolve(provider);

    expect(result.error, isA<Exception>());
    expect(
      result.error.toString(),
      contains('2x2'),
      reason: 'a null-check TypeError says nothing about which image',
    );
    expect(result.zoneErrors, isEmpty);
    expect(provider.removed, greaterThanOrEqualTo(1));
    expect(provider.stillListening, isFalse);
  });

  test('a load failure rejects with the exception itself', () async {
    final provider = _StubProvider(failure: Exception('404'));

    final result = await resolve(provider, withOnError: true);

    // It used to reject with the string 'image failed to load', dropping the
    // exception and its stack.
    expect(result.error, isA<Exception>());
    expect(result.error.toString(), contains('404'));
    expect(result.reported, hasLength(1));
    // The listener is gone, though the completer keeps its own error
    // bookkeeping, so stillListening is not the invariant on this path.
    expect(provider.removed, greaterThanOrEqualTo(1));
  });

  test('a read-back failure reports to onError exactly once', () async {
    final provider = _StubProvider(
      image: _UnreadableImage(readBack: () async => throw Exception('nope')),
    );

    final result = await resolve(provider, withOnError: true);

    expect(result.reported, hasLength(1));
    expect(result.error, isNotNull);
    expect(provider.removed, greaterThanOrEqualTo(1));
    expect(provider.stillListening, isFalse);
  });
}

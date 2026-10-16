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
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';

const _channel = MethodChannel('net.nfet.printing');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  /// Start a raster and let the request reach the channel.
  Future<void> raster({int? background}) async {
    final stream = background == null
        ? Printing.raster(Uint8List(0))
        : Printing.raster(Uint8List(0), background: background);
    final subscription = stream.listen(null);
    await pumpEventQueue();
    await subscription.cancel();
  }

  test('the page backdrop is opaque white by default', () async {
    // Every native backend left the page transparent, so saving a rastered page
    // as PNG or re-encoding it as JPEG gave a black page. Web was opaque only
    // because pdf.js fills its canvas white regardless.
    await raster();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'rasterPdf');
    expect(calls.single.arguments['background'], 0xffffffff);
  });

  test('a caller can ask for the transparent pages of 5.17', () async {
    await raster(background: 0x00000000);

    expect(calls.single.arguments['background'], 0x00000000);
  });

  test('a caller can ask for any colour', () async {
    await raster(background: 0xff112233);

    expect(calls.single.arguments['background'], 0xff112233);
  });

  test('the rest of the request is unchanged', () async {
    await raster();

    final args = calls.single.arguments as Map<Object?, Object?>;
    expect(args.keys, containsAll(<String>['doc', 'pages', 'scale', 'job']));
  });
}

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
  setUp(TestWidgetsFlutterBinding.ensureInitialized);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('PrintingInfo', () async {
    const info = PrintingInfo.unavailable;
    expect(info.canConvertHtml, false);
    expect(info.directPrint, false);
    expect(info.dynamicLayout, false);
    expect(info.canPrint, false);
    expect(info.canConvertHtml, false);
    expect(info.canShare, false);
    expect(info.canRaster, false);

    expect(info.toString(), isA<String>());
  });

  test('PrintingInfo.fromMap', () async {
    final info = PrintingInfo.fromMap(<dynamic, dynamic>{'canPrint': true});

    expect(info.canConvertHtml, false);
    expect(info.directPrint, false);
    expect(info.dynamicLayout, false);
    expect(info.canPrint, true);
    expect(info.canConvertHtml, false);
    expect(info.canShare, false);
    expect(info.canRaster, false);
  });

  test('Printing.info surfaces a platform that cannot print', () async {
    // An Android engine with no Activity attached cannot print, and used to
    // report that it could and then fail the call.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          if (call.method == 'printingInfo') {
            return <String, dynamic>{
              'canPrint': false,
              'canShare': true,
              'canRaster': true,
              'dynamicLayout': false,
            };
          }
          return null;
        });

    final info = await Printing.info();

    expect(info.canPrint, isFalse);
    expect(info.dynamicLayout, isFalse);
    expect(info.canShare, isTrue, reason: 'sharing works without an Activity');
    expect(info.canRaster, isTrue);
  });
}

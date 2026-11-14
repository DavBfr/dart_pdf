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
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/method_channel.dart';

void main() {
  const channel = MethodChannel('net.nfet.printing');
  const codec = StandardMethodCodec();
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final printing = MethodChannelPrinting();
  final calls = <MethodCall>[];

  /// Answers a print job like the platform does: it reports the outcome of
  /// the job with an onCompleted call before printPdf returns.
  void completePrintJobs({String? error}) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'listPaperSizes') {
        return [
          {
            'id': '272',
            'name': '4x6 (borderless)',
            'width': 297,
            'height': 442.5,
          },
        ];
      }
      if (call.method == 'printPdf') {
        await messenger.handlePlatformMessage(
          channel.name,
          codec.encodeMethodCall(
            MethodCall('onCompleted', {
              'job': call.arguments['job'],
              'completed': error == null,
              'error': ?error,
            }),
          ),
          (_) {},
        );
        return 1;
      }
      return null;
    });
  }

  setUp(calls.clear);

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<bool> printPdf({PrinterPaper? paper}) => printing.layoutPdf(
    const Printer(url: 'Kodak'),
    (_) => Uint8List(0),
    'Document',
    PdfPageFormat.a6,
    false,
    false,
    OutputType.generic,
    false,
    false,
    paper,
  );

  test('listPaperSizes', () async {
    completePrintJobs();

    expect(await printing.listPaperSizes(const Printer(url: 'Kodak')), [
      const PrinterPaper(
        id: '272',
        name: '4x6 (borderless)',
        width: 297,
        height: 442.5,
      ),
    ]);
    expect(calls.single.arguments, {'printer': 'Kodak'});
  });

  test('printPdf sends the paper only when set', () async {
    completePrintJobs();
    const paper = PrinterPaper(id: '272', name: '', width: 297, height: 442.5);

    expect(await printPdf(paper: paper), true);
    expect(await printPdf(), true);

    expect(calls[0].arguments['paper'], '272');
    expect((calls[1].arguments as Map).containsKey('paper'), false);
  });

  test('printPdf throws an error reported before it returns', () async {
    completePrintJobs(error: 'The printer has no paper with id 1');

    await expectLater(
      printPdf(),
      throwsA('The printer has no paper with id 1'),
    );
  });
}

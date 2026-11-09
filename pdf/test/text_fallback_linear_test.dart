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

import 'dart:convert';

import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

import 'utils.dart';

Future<String> _render(pw.TextSpan text) async {
  final document = pw.Document(compress: false);
  document.addPage(
    pw.Page(build: (context) => pw.RichText(text: text, softWrap: false)),
  );
  return latin1.decode(await document.save());
}

void main() {
  test(
    'supported text surrounding unsupported runes is kept in order',
    () async {
      final data = await _render(
        pw.TextSpan(
          text: 'ABC😀DEF😃GHI',
          style: pw.TextStyle(font: pw.Font.helvetica()),
        ),
      );

      final abc = data.indexOf('(ABC)');
      final def = data.indexOf('(DEF)');
      final ghi = data.indexOf('(GHI)');
      expect(abc, isNonNegative);
      expect(def, greaterThan(abc));
      expect(ghi, greaterThan(def));
    },
  );

  test('repeated fallback characters preserve all adjacent text', () async {
    final data = await _render(
      pw.TextSpan(
        text: '${List.filled(120, 'xΩ').join()}END',
        style: pw.TextStyle(
          font: pw.Font.helvetica(),
          fontSize: 3,
          fontFallback: [loadFont('open-sans.ttf')],
        ),
      ),
    );

    expect(RegExp(r'\(x\)').allMatches(data).length, 120);
    expect(data, contains('(END)'));
  });
}

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

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

/// Paints [child] on a single page and returns the uncompressed PDF content.
Future<String> _render(pw.Widget child) async {
  final pdf = pw.Document(compress: false);
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      build: (pw.Context context) => child,
    ),
  );
  return latin1.decode(await pdf.save());
}

pw.Widget _box({PdfColor? color, pw.BoxBorder? border}) => pw.Container(
  width: 100,
  height: 100,
  decoration: pw.BoxDecoration(color: color, border: border),
);

void main() {
  group('BoxDecoration color alpha', () {
    test('is applied as the fill opacity of the graphic state', () async {
      final content = await _render(
        _box(color: const PdfColor(1, 0, 0, 0.5)),
      );
      expect(content, contains('/ca 0.5'));
      expect(content, contains(' gs'));
    });

    test('alpha 0 from PdfColor.fromInt(0x00000000) is applied', () async {
      final content = await _render(
        _box(color: const PdfColor.fromInt(0x00000000)),
      );
      expect(content, contains('/ca 0'));
    });

    test('a translucent color still paints its fill', () async {
      final content = await _render(
        _box(color: const PdfColor(0, 0, 1, 0.3)),
      );
      expect(content, contains('0 0 1 rg'));
      expect(content, contains('f'));
      expect(content, contains('/ca 0.3'));
    });

    test('an opaque color produces the same output as before', () async {
      final content = await _render(_box(color: PdfColors.red));
      expect(content, contains(' rg f'));
      expect(content, isNot(contains('/ca')));
      expect(content, isNot(contains(' gs')));
    });

    test('no graphic state is emitted without a color', () async {
      final content = await _render(
        _box(border: pw.Border.all(color: PdfColors.green)),
      );
      expect(content, isNot(contains('/ca')));
    });
  });

  group('Border color alpha', () {
    test('uniform border is applied as the stroke opacity', () async {
      final content = await _render(
        _box(
          color: PdfColors.white,
          border: pw.Border.all(color: const PdfColor(0, 0, 0, 0.25)),
        ),
      );
      expect(content, contains('/CA 0.25'));
      expect(content, contains(' gs'));
    });

    test('each side of a non uniform border keeps its own opacity', () async {
      final content = await _render(
        _box(
          border: const pw.Border(
            left: pw.BorderSide(color: PdfColor(0, 0, 0, 0.25), width: 2),
            top: pw.BorderSide(color: PdfColor(1, 0, 0, 0.75), width: 2),
          ),
        ),
      );
      expect(content, contains('/CA 0.25'));
      expect(content, contains('/CA 0.75'));
    });

    test('a translucent fill does not hide the border', () async {
      final content = await _render(
        _box(
          color: const PdfColor(1, 1, 0, 0.5),
          border: pw.Border.all(color: PdfColors.black),
        ),
      );
      // The border is stroked outside the transparent fill graphic state.
      expect(content, contains('/ca 0.5'));
      expect(content.lastIndexOf('S'), greaterThan(content.indexOf('/ca 0.5')));
    });

    test('opaque borders emit no graphic state', () async {
      final content = await _render(
        _box(border: pw.Border.all(color: const PdfColor(0, 1, 0))),
      );
      expect(content, isNot(contains('/CA')));
    });
  });
}

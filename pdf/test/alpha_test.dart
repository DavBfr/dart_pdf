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

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';

/// Draw on a page and hand back the whole file.
Future<String> draw(
  void Function(PdfGraphics canvas) body, {
  bool colorAlpha = true,
}) async {
  final document = PdfDocument(compress: false, colorAlpha: colorAlpha);
  final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
  body(page.getGraphics());
  return String.fromCharCodes(await document.save());
}

/// The page's content stream.
String content(String pdf) {
  for (final m in RegExp(
    r'stream(.*?)endstream',
    dotAll: true,
  ).allMatches(pdf)) {
    if (m.group(1)!.contains(' re ')) {
      return m.group(1)!.trim();
    }
  }
  return '(no content stream)';
}

void main() {
  group('a fill colour with alpha', () {
    test('puts its alpha in an ExtGState', () async {
      // The colour operators carry no alpha - PDF keeps constant alpha in an
      // /ExtGState - so rg and k threw a PdfColor's alpha away and every
      // translucent fill painted opaque.
      final pdf = await draw(
        (PdfGraphics canvas) => canvas
          ..drawBox(const PdfRect(0, 0, 10, 10))
          ..setFillColor(const PdfColor(1, 0, 0, 0.5))
          ..fillPath(),
      );

      expect(content(pdf), contains('1 0 0 rg'));
      expect(content(pdf), matches(RegExp(r'1 0 0 rg /\w+ gs ')));
      expect(pdf, contains('/ca 0.5'));
    });

    test('works the same in CMYK', () async {
      final pdf = await draw(
        (PdfGraphics canvas) => canvas
          ..drawBox(const PdfRect(0, 0, 10, 10))
          ..setFillColor(const PdfColorCmyk(0, 1, 1, 0, 0.5))
          ..fillPath(),
      );

      expect(content(pdf), matches(RegExp(r'0 1 1 0 k /\w+ gs ')));
      expect(pdf, contains('/ca 0.5'));
    });

    test('of zero paints nothing', () async {
      final pdf = await draw(
        (PdfGraphics canvas) => canvas
          ..drawBox(const PdfRect(0, 0, 10, 10))
          ..setFillColor(PdfColor.fromInt(0x00000000))
          ..fillPath(),
      );

      expect(pdf, contains('/ca 0'));
    });

    test('is restored by the next opaque colour', () async {
      final pdf = await draw(
        (PdfGraphics canvas) => canvas
          ..drawBox(const PdfRect(0, 0, 10, 10))
          ..setFillColor(const PdfColor(1, 0, 0, 0.5))
          ..fillPath()
          ..drawBox(const PdfRect(0, 20, 10, 10))
          ..setFillColor(PdfColors.blue)
          ..fillPath(),
      );

      expect(pdf, contains('/ca 0.5'));
      expect(pdf, contains('/ca 1'));
      expect(RegExp(r' gs ').allMatches(content(pdf)), hasLength(2));
    });

    test('is written once however many times it is used', () async {
      final pdf = await draw((PdfGraphics canvas) {
        for (var i = 0; i < 10; i++) {
          canvas
            ..drawBox(PdfRect(0, i * 12, 10, 10))
            ..setFillColor(const PdfColor(1, 0, 0, 0.5))
            ..fillPath();
        }
      });

      expect(RegExp(r' gs ').allMatches(content(pdf)), hasLength(1));
      expect(RegExp(r'/ca 0.5').allMatches(pdf), hasLength(1));
    });
  });

  test('a stroke colour with alpha uses /CA', () async {
    final pdf = await draw(
      (PdfGraphics canvas) => canvas
        ..drawBox(const PdfRect(0, 0, 10, 10))
        ..setStrokeColor(const PdfColor(0, 0, 1, 0.25))
        ..strokePath(),
    );

    expect(content(pdf), matches(RegExp(r'0 0 1 RG /\w+ gs ')));
    expect(pdf, contains('/CA 0.25'));
    expect(pdf, isNot(contains('/ca ')));
  });

  test('an opaque page carries no ExtGState at all', () async {
    final pdf = await draw(
      (PdfGraphics canvas) => canvas
        ..drawBox(const PdfRect(0, 0, 10, 10))
        ..setFillColor(PdfColors.red)
        ..fillPath()
        ..drawBox(const PdfRect(0, 20, 10, 10))
        ..setStrokeColor(PdfColors.blue)
        ..strokePath(),
    );

    expect(pdf, isNot(contains('/ExtGState')));
    expect(content(pdf), isNot(contains(' gs ')));
  });

  test('the setting turns it off', () async {
    // A fill colour's alpha now emits an /ExtGState, which PDF/A-1 forbids.
    final pdf = await draw(
      (PdfGraphics canvas) => canvas
        ..drawBox(const PdfRect(0, 0, 10, 10))
        ..setFillColor(const PdfColor(1, 0, 0, 0.5))
        ..fillPath(),
      colorAlpha: false,
    );

    expect(content(pdf), contains('1 0 0 rg'));
    expect(pdf, isNot(contains('/ExtGState')));
    expect(content(pdf), isNot(contains(' gs ')));
  });

  test('a saved context restores the alpha it had', () async {
    final pdf = await draw(
      (PdfGraphics canvas) => canvas
        ..saveContext()
        ..drawBox(const PdfRect(0, 0, 10, 10))
        ..setFillColor(const PdfColor(1, 0, 0, 0.5))
        ..fillPath()
        ..restoreContext()
        ..drawBox(const PdfRect(0, 20, 10, 10))
        ..setFillColor(const PdfColor(0, 0, 1, 0.5))
        ..fillPath(),
    );

    // Q put the opaque state back, so the second translucent fill has to say so
    // again rather than assume the first one's gs is still in force.
    expect(RegExp(r' gs ').allMatches(content(pdf)), hasLength(2));
  });
}

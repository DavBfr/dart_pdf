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

import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';

/// The six operands of every `c` operator in the stream, in order.
List<List<double>> curves(String stream) =>
    RegExp(
          r'([-\d.]+) ([-\d.]+) ([-\d.]+) ([-\d.]+) ([-\d.]+) ([-\d.]+) c(?![a-z])',
        )
        .allMatches(stream)
        .map(
          (RegExpMatch m) => <double>[
            for (var i = 1; i <= 6; i++) double.parse(m.group(i)!),
          ],
        )
        .toList();

/// Draw one arc and hand back its curves.
Future<List<List<double>>> arc(
  double x1,
  double y1,
  double rx,
  double ry,
  double x2,
  double y2, {
  bool large = false,
  bool sweep = false,
}) async {
  final document = PdfDocument(compress: false);
  final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
  page.getGraphics()
    ..moveTo(x1, y1)
    ..bezierArc(x1, y1, rx, ry, x2, y2, large: large, sweep: sweep)
    ..strokePath();

  final pdf = String.fromCharCodes(await document.save());
  final start = pdf.indexOf('stream', pdf.indexOf('/Length'));
  return curves(pdf.substring(start + 6, pdf.indexOf('endstream', start)));
}

void main() {
  // The stream carries five decimals, so an endpoint can only be checked to
  // about 1e-5 however exact the arithmetic behind it is.
  const tolerance = 1e-5;

  test('radii too small for the chord still reach the end point', () async {
    // One variable held F.6.6's radii ratio and then F.6.5's centre factor. The
    // out-of-range branch scaled the radii and re-assigned the ratio without
    // converting it, so it stayed 1.0 where it has to be 0, and sqrt(1.0) put the
    // centre a whole radius away: this arc ended at (185.35534, 414.64466).
    final drawn = await arc(100, 400, 10, 10, 200, 400, sweep: true);

    expect(drawn, isNotEmpty);
    expect(drawn.last[4], closeTo(200, tolerance));
    expect(drawn.last[5], closeTo(400, tolerance));
  });

  test('every large and sweep combination reaches it', () async {
    for (final large in <bool>[false, true]) {
      for (final sweep in <bool>[false, true]) {
        final drawn = await arc(
          100,
          400,
          10,
          10,
          200,
          400,
          large: large,
          sweep: sweep,
        );

        final label = 'large $large, sweep $sweep';
        expect(drawn, isNotEmpty, reason: label);
        expect(drawn.last[4], closeTo(200, tolerance), reason: label);
        expect(drawn.last[5], closeTo(400, tolerance), reason: label);
      }
    }
  });

  test('a half circle ends at the antipode, at every angle', () async {
    // 180 degrees is where the ratio rounds to 1 + 1 ULP and takes the scaling
    // branch, so these were out by the radius: 20.7pt on a radius-50 circle.
    var worst = 0.0;

    for (var degrees = 0; degrees < 360; degrees++) {
      final angle = degrees * math.pi / 180;
      final x1 = 100 + 50 * math.cos(angle);
      final y1 = 100 + 50 * math.sin(angle);
      final x2 = 100 - 50 * math.cos(angle);
      final y2 = 100 - 50 * math.sin(angle);

      final drawn = await arc(x1, y1, 50, 50, x2, y2, sweep: true);
      expect(drawn, isNotEmpty, reason: '$degrees degrees');

      worst = math.max(
        worst,
        math.sqrt(
          math.pow(drawn.last[4] - x2, 2) + math.pow(drawn.last[5] - y2, 2),
        ),
      );
    }

    expect(worst, lessThan(tolerance));
  });
}

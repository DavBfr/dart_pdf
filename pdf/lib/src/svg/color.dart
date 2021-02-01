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

import 'colors.dart';
import 'gradient.dart';
import 'operation.dart';
import 'painter.dart';
import 'parser.dart';

class SvgColor {
  const SvgColor({
    this.color,
    this.opacity,
    this.inherit = false,
  });

  factory SvgColor.fromXml(String? color, SvgPainter painter) {
    if (color == null) {
      return inherited;
    }

    if (color == 'none') {
      return none;
    }

    if (svgColors.containsKey(color)) {
      return SvgColor(color: svgColors[color]);
    }

    // handle rgba() colors e.g. rgba(255, 255, 255, 1.0)
    if (color.toLowerCase().startsWith('rgba')) {
      final rgba = SvgParser.splitNumeric(
        color.substring(color.indexOf('(') + 1, color.indexOf(')')),
        null,
      ).toList();

      return SvgColor(
        color: PdfColor(
          rgba[0].colorValue,
          rgba[1].colorValue,
          rgba[2].colorValue,
          rgba[3].value,
        ),
      );
    }

    // handle hsl() colors e.g. hsl(255, 255, 255)
    if (color.toLowerCase().startsWith('hsl')) {
      final hsl = SvgParser.splitNumeric(
        color.substring(color.indexOf('(') + 1, color.indexOf(')')),
        null,
      ).toList();

      return SvgColor(
        color: PdfColorHsl(
          hsl[0].colorValue,
          hsl[1].colorValue,
          hsl[2].colorValue,
        ),
      );
    }

    // handle rgb() colors e.g. rgb(255, 255, 255)
    if (color.toLowerCase().startsWith('rgb')) {
      final rgb = SvgParser.splitNumeric(
        color.substring(color.indexOf('(') + 1, color.indexOf(')')),
        null,
      ).toList();

      return SvgColor(
        color: PdfColor(
          rgb[0].colorValue,
          rgb[1].colorValue,
          rgb[2].colorValue,
        ),
      );
    }

    if (color.toLowerCase().startsWith('url(#')) {
      final gradient =
          painter.parser.findById(color.substring(5, color.indexOf(')')))!;
      if (gradient.name.local == 'linearGradient') {
        return SvgLinearGradient.fromXml(gradient, painter);
      }
      if (gradient.name.local == 'radialGradient') {
        return SvgRadialGradient.fromXml(gradient, painter);
      }
      return SvgColor.unknown;
    }

    try {
      return SvgColor(color: PdfColor.fromHex(color));
    } catch (e) {
      print('Unknown color: $color');
      return SvgColor.unknown;
    }
  }

  static const unknown = SvgColor();
  static const defaultColor = SvgColor(color: PdfColors.black);
  static const none = SvgColor();
  static const inherited = SvgColor(inherit: true);

  final PdfColor? color;

  final double? opacity;

  final bool inherit;

  bool get isEmpty => color == null;

  bool get isNotEmpty => !isEmpty;

  SvgColor merge(SvgColor other) {
    return SvgColor(
      color: other.color ?? color,
    );
  }

  void setFillColor(SvgOperation op, PdfGraphics canvas) {
    if (isEmpty) {
      return;
    }

    canvas.setFillColor(color);
  }

  void setStrokeColor(SvgOperation op, PdfGraphics canvas) {
    if (isEmpty) {
      return;
    }

    canvas.setStrokeColor(color);
  }

  @override
  String toString() =>
      '$runtimeType color: $color inherit:$inherit isEmpty: $isEmpty';
}

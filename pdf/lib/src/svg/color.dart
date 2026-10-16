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

import '../../pdf.dart';
import 'colors.dart';
import 'gradient.dart';
import 'operation.dart';
import 'painter.dart';
import 'parser.dart';

class SvgColor {
  const SvgColor({this.color, this.opacity, this.inherit = false});

  factory SvgColor.fromXml(
    String? color,
    SvgPainter painter, {
    PdfColor? currentColor,
  }) {
    if (color == null) {
      return inherited;
    }

    if (color == 'none') {
      return none;
    }

    if (painter.parser.colorFilter != null) {
      return SvgColor(color: painter.parser.colorFilter);
    }

    if (color.toLowerCase() == 'currentcolor') {
      return SvgColor(color: currentColor ?? PdfColors.black);
    }

    if (svgColors.containsKey(color)) {
      final named = svgColors[color]!;
      return SvgColor(color: named, opacity: named.alpha);
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
        opacity: rgba[3].value,
      );
    }

    // handle hsl() and hsla() colors e.g. hsl(255, 255, 255)
    if (color.toLowerCase().startsWith('hsl')) {
      final hsl = SvgParser.splitNumeric(
        color.substring(color.indexOf('(') + 1, color.indexOf(')')),
        null,
      ).toList();

      final alpha = hsl.length > 3 ? hsl[3].value : 1.0;
      return SvgColor(
        color: PdfColorHsl(
          hsl[0].colorValue,
          hsl[1].colorValue,
          hsl[2].colorValue,
          alpha,
        ),
        opacity: alpha,
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

    if (color.toLowerCase().startsWith('url(')) {
      final close = color.indexOf(')');
      if (close > 0) {
        var reference = color.substring(4, close).trim();
        if ((reference.startsWith("'") && reference.endsWith("'")) ||
            (reference.startsWith('"') && reference.endsWith('"'))) {
          reference = reference.substring(1, reference.length - 1).trim();
        }
        // A paint server reference may be followed by a fallback colour,
        // which is what to use when the reference cannot be resolved.
        final fallback = color.substring(close + 1).trim();

        if (reference.startsWith('#')) {
          final gradient = painter.parser.findById(reference.substring(1));
          if (gradient != null) {
            if (gradient.name.local == 'linearGradient') {
              return SvgLinearGradient.fromXml(gradient, painter);
            }
            if (gradient.name.local == 'radialGradient') {
              return SvgRadialGradient.fromXml(gradient, painter);
            }
          }
        }

        // Unresolvable: the fallback if there is one, otherwise no paint.
        // This used to force-unwrap the lookup and crash the whole document.
        if (fallback.isNotEmpty) {
          return SvgColor.fromXml(
            fallback,
            painter,
            currentColor: currentColor,
          );
        }
      }
      return SvgColor.none;
    }

    try {
      final parsed = PdfColor.fromHex(color);
      return SvgColor(color: parsed, opacity: parsed.alpha);
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('Unknown color: $color');
        return true;
      }());
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
    if (other.color == null) {
      // `other` only inherits, so keep this instance: returning a plain
      // SvgColor here erased paint-server subclasses, which is why a gradient
      // declared on an ancestor was lost by its children.
      return this;
    }
    return SvgColor(color: other.color, opacity: other.opacity ?? opacity);
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

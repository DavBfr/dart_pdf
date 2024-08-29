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

import 'package:meta/meta.dart';
import 'package:xml/xml.dart';

import '../../pdf.dart';
import 'color.dart';
import 'mask_path.dart';
import 'painter.dart';
import 'parser.dart';

enum SvgTextAnchor { start, middle, end }

enum SvgDominantBaseline { auto, alphabetic, ideographic, middle, central, mathematical, hanging, textTop, textBottom }

@immutable
class SvgBrush {
  const SvgBrush({
    required this.opacity,
    required this.fill,
    required this.fillEvenOdd,
    required this.fillOpacity,
    required this.stroke,
    required this.strokeOpacity,
    required this.strokeWidth,
    required this.strokeDashArray,
    required this.strokeDashOffset,
    required this.strokeLineCap,
    required this.strokeLineJoin,
    required this.strokeMiterLimit,
    required this.fontFamily,
    required this.fontSize,
    required this.fontStyle,
    required this.fontWeight,
    required this.textAnchor,
    required this.dominantBaseline,
    required this.blendMode,
    this.mask,
  });

  factory SvgBrush.fromXml(
    XmlElement element,
    SvgBrush parent,
    SvgPainter painter,
  ) {
    SvgParser.convertStyle(element);

    final strokeDashArray = element.getAttribute('stroke-dasharray');
    final fillRule = element.getAttribute('fill-rule');
    final strokeLineCap = element.getAttribute('stroke-linecap');
    final strokeLineJoin = element.getAttribute('stroke-linejoin');
    final blendMode = element.getAttribute('mix-blend-mode');

    final result = parent.merge(SvgBrush(
      opacity: SvgParser.getDouble(element, 'opacity', defaultValue: null),
      blendMode: blendMode == null ? null : _blendModes[blendMode],
      fillOpacity:
          SvgParser.getDouble(element, 'fill-opacity', defaultValue: null),
      strokeOpacity:
          SvgParser.getDouble(element, 'stroke-opacity', defaultValue: null),
      strokeLineCap:
          strokeLineCap == null ? null : _strokeLineCap[strokeLineCap],
      strokeLineJoin:
          strokeLineJoin == null ? null : _strokeLineJoin[strokeLineJoin],
      strokeMiterLimit:
          SvgParser.getDouble(element, 'stroke-miterlimit', defaultValue: null),
      fill: SvgColor.fromXml(element.getAttribute('fill'), painter),
      fillEvenOdd: fillRule == null ? null : fillRule == 'evenodd',
      stroke: SvgColor.fromXml(element.getAttribute('stroke'), painter),
      strokeWidth: SvgParser.getNumeric(element, 'stroke-width', parent),
      strokeDashArray: strokeDashArray == null
          ? null
          : (strokeDashArray == 'none'
              ? []
              : SvgParser.splitNumeric(strokeDashArray, parent)
                  .map((e) => e.value)
                  .toList()),
      strokeDashOffset:
          SvgParser.getNumeric(element, 'stroke-dashoffset', parent)?.sizeValue,
      fontSize: SvgParser.getNumeric(element, 'font-size', parent),
      fontFamily: element.getAttribute('font-family'),
      fontStyle: element.getAttribute('font-style'),
      fontWeight: element.getAttribute('font-weight'),
      textAnchor: _textAnchors[element.getAttribute('text-anchor')],
      dominantBaseline: _dominantBaselines[element.getAttribute('dominant-baseline')],
    ));

    final mask = SvgMaskPath.fromXml(element, painter, result);
    if (mask != null) {
      return result.copyWith(mask: mask);
    }

    return result;
  }

  static const defaultContext = SvgBrush(
    opacity: 1,
    blendMode: null,
    fillOpacity: 1,
    strokeOpacity: 1,
    fill: SvgColor.defaultColor,
    fillEvenOdd: false,
    stroke: SvgColor.none,
    strokeLineCap: PdfLineCap.butt,
    strokeLineJoin: PdfLineJoin.miter,
    strokeMiterLimit: 4,
    strokeWidth: SvgNumeric.value(1, null, SvgUnit.pixels),
    strokeDashArray: [],
    strokeDashOffset: 0,
    fontSize: SvgNumeric.value(16, null),
    fontFamily: 'sans-serif',
    fontWeight: 'normal',
    fontStyle: 'normal',
    textAnchor: SvgTextAnchor.start,
    dominantBaseline: SvgDominantBaseline.auto,
    mask: null,
  );

  static const _blendModes = <String, PdfBlendMode>{
    'normal': PdfBlendMode.normal,
    'multiply': PdfBlendMode.multiply,
    'screen': PdfBlendMode.screen,
    'overlay': PdfBlendMode.overlay,
    'darken': PdfBlendMode.darken,
    'lighten': PdfBlendMode.lighten,
    'color-dodge': PdfBlendMode.color,
    'color-burn': PdfBlendMode.color,
    'hard-light': PdfBlendMode.hardLight,
    'soft-light': PdfBlendMode.softLight,
    'difference': PdfBlendMode.difference,
    'exclusion': PdfBlendMode.exclusion,
    'hue': PdfBlendMode.hue,
    'saturation': PdfBlendMode.saturation,
    'color': PdfBlendMode.color,
    'luminosity': PdfBlendMode.luminosity,
  };

  static const _strokeLineCap = <String, PdfLineCap>{
    'butt': PdfLineCap.butt,
    'round': PdfLineCap.round,
    'square': PdfLineCap.square,
  };

  static const _strokeLineJoin = <String, PdfLineJoin>{
    'miter ': PdfLineJoin.miter,
    'bevel': PdfLineJoin.bevel,
    'round': PdfLineJoin.round,
  };

  static const _textAnchors = <String, SvgTextAnchor>{
    'start': SvgTextAnchor.start,
    'middle': SvgTextAnchor.middle,
    'end': SvgTextAnchor.end,
  };

  static const _dominantBaselines = <String, SvgDominantBaseline>{
    'auto':  SvgDominantBaseline.auto,
    'alphabetic':  SvgDominantBaseline.alphabetic,
    'ideographic':  SvgDominantBaseline.ideographic,
    'middle':  SvgDominantBaseline.middle,
    'central':  SvgDominantBaseline.central,
    'mathematical':  SvgDominantBaseline.mathematical,
    'hanging':  SvgDominantBaseline.hanging,
    'textTop':  SvgDominantBaseline.textTop,
    'textBottom': SvgDominantBaseline.textBottom,
  };

  final double? opacity;
  final SvgColor? fill;
  final bool? fillEvenOdd;
  final double? fillOpacity;
  final SvgColor? stroke;
  final double? strokeOpacity;
  final SvgNumeric? strokeWidth;
  final List<double>? strokeDashArray;
  final double? strokeDashOffset;
  final PdfLineCap? strokeLineCap;
  final PdfLineJoin? strokeLineJoin;
  final double? strokeMiterLimit;
  final SvgNumeric? fontSize;
  final String? fontFamily;
  final String? fontStyle;
  final String? fontWeight;
  final SvgTextAnchor? textAnchor;
  final SvgDominantBaseline? dominantBaseline;
  final PdfBlendMode? blendMode;
  final SvgMaskPath? mask;

  SvgBrush merge(SvgBrush? other) {
    if (other == null) {
      return this;
    }

    var _fill = other.fill ?? fill;

    if (_fill?.inherit ?? false) {
      _fill = fill!.merge(other.fill!);
    }

    var _stroke = other.stroke ?? stroke;

    if (_stroke?.inherit ?? false) {
      _stroke = stroke!.merge(other.stroke!);
    }

    return SvgBrush(
      opacity: other.opacity ?? 1.0,
      blendMode: other.blendMode,
      fillOpacity: other.fillOpacity ?? fillOpacity,
      strokeOpacity: other.strokeOpacity ?? strokeOpacity,
      fill: _fill,
      fillEvenOdd: other.fillEvenOdd ?? fillEvenOdd,
      stroke: _stroke,
      strokeWidth: other.strokeWidth ?? strokeWidth,
      strokeDashArray: other.strokeDashArray ?? strokeDashArray,
      strokeDashOffset: other.strokeDashOffset ?? strokeDashOffset,
      fontSize: other.fontSize ?? fontSize,
      fontFamily: other.fontFamily ?? fontFamily,
      fontStyle: other.fontStyle ?? fontStyle,
      fontWeight: other.fontWeight ?? fontWeight,
      textAnchor: other.textAnchor ?? textAnchor,
      dominantBaseline: other.dominantBaseline ?? dominantBaseline,
      strokeLineCap: other.strokeLineCap ?? strokeLineCap,
      strokeLineJoin: other.strokeLineJoin ?? strokeLineJoin,
      strokeMiterLimit: other.strokeMiterLimit ?? strokeMiterLimit,
      mask: other.mask,
    );
  }

  SvgBrush copyWith({
    double? opacity,
    SvgColor? fill,
    bool? fillEvenOdd,
    double? fillOpacity,
    SvgColor? stroke,
    double? strokeOpacity,
    SvgNumeric? strokeWidth,
    List<double>? strokeDashArray,
    double? strokeDashOffset,
    PdfLineCap? strokeLineCap,
    PdfLineJoin? strokeLineJoin,
    double? strokeMiterLimit,
    SvgNumeric? fontSize,
    String? fontFamily,
    String? fontStyle,
    String? fontWeight,
    SvgTextAnchor? textAnchor,
    SvgDominantBaseline? dominantBaseline,
    PdfBlendMode? blendMode,
    SvgMaskPath? mask,
  }) {
    return SvgBrush(
      opacity: opacity ?? this.opacity,
      fill: fill ?? this.fill,
      fillEvenOdd: fillEvenOdd ?? this.fillEvenOdd,
      fillOpacity: fillOpacity ?? this.fillOpacity,
      stroke: stroke ?? this.stroke,
      strokeOpacity: strokeOpacity ?? this.strokeOpacity,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokeDashArray: strokeDashArray ?? this.strokeDashArray,
      strokeDashOffset: strokeDashOffset ?? this.strokeDashOffset,
      strokeLineCap: strokeLineCap ?? this.strokeLineCap,
      strokeLineJoin: strokeLineJoin ?? this.strokeLineJoin,
      strokeMiterLimit: strokeMiterLimit ?? this.strokeMiterLimit,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      fontStyle: fontStyle ?? this.fontStyle,
      fontWeight: fontWeight ?? this.fontWeight,
      textAnchor: textAnchor ?? this.textAnchor,
      dominantBaseline: dominantBaseline ?? this.dominantBaseline,
      blendMode: blendMode ?? this.blendMode,
      mask: mask ?? this.mask,
    );
  }

  @override
  String toString() =>
      '$runtimeType fill: $fill fillEvenOdd: $fillEvenOdd stroke:$stroke strokeWidth:$strokeWidth strokeDashArray:$strokeDashArray fontSize:$fontSize fontFamily:$fontFamily textAnchor:$textAnchor ';
}

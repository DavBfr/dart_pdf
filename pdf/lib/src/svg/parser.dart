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

import 'package:xml/xml.dart';

import '../../pdf.dart';
import 'brush.dart';

/// Which extent of the viewport a percentage length is a fraction of.
enum SvgAxis {
  /// The viewport's width: x, width, cx, dx.
  horizontal,

  /// Its height: y, height, cy, dy.
  vertical,

  /// sqrt((w^2 + h^2) / 2), for a length that is on neither axis - a radius, a
  /// stroke width, a dash offset.
  diagonal,
}

class SvgParser {
  /// Create an SVG parser

  factory SvgParser({required XmlDocument xml, PdfColor? colorFilter}) {
    final root = xml.rootElement;

    final vbattr = root.getAttribute('viewBox');

    // Kept as numerics, so a percentage root size stays a percentage: taking
    // sizeValue here turned width="100%" into 1.0, which the widget then laid out
    // as one point, and the fallback viewBox became 1x1 so the content was
    // clipped away.
    final rootWidth = getNumeric(root, 'width', null);
    final rootHeight = getNumeric(root, 'height', null);

    final width = rootWidth?.unit == SvgUnit.percent
        ? null
        : rootWidth?.sizeValue;
    final height = rootHeight?.unit == SvgUnit.percent
        ? null
        : rootHeight?.sizeValue;

    final vb = vbattr == null
        ? <double>[0, 0, width ?? 1000, height ?? 1000]
        : splitDoubles(vbattr);

    if (vb.isEmpty || vb.length > 4) {
      throw PdfException('ViewBox must contain 1..4 parameters');
    }

    final fvb = [...List<double>.filled(4 - vb.length, 0), ...vb];

    final viewBox = PdfRect(fvb[0], fvb[1], fvb[2], fvb[3]);

    return SvgParser._(
      width,
      height,
      rootWidth,
      rootHeight,
      viewBox,
      root,
      colorFilter,
    );
  }

  SvgParser._(
    this.width,
    this.height,
    this.rootWidth,
    this.rootHeight,
    this.viewBox,
    this.root,
    this.colorFilter,
  );

  final PdfRect viewBox;

  /// The root width in points, or null when it is a percentage or absent.
  final double? width;

  /// The root height in points, or null when it is a percentage or absent.
  final double? height;

  /// The root `width` attribute as written, so a percentage can be resolved
  /// against whatever box the SVG is given.
  final SvgNumeric? rootWidth;

  /// The root `height` attribute as written.
  final SvgNumeric? rootHeight;

  final XmlElement root;

  final PdfColor? colorFilter;

  static final _transformParameterRegExp = RegExp(
    r'[\w.-]+(px|pt|em|cm|mm|in|%|)',
  );

  XmlElement? findById(String id) {
    try {
      return root.descendants.whereType<XmlElement>().firstWhere(
        (e) => e.getAttribute('id') == id,
      );
    } on StateError {
      return null;
    }
  }

  static double? getDouble(
    XmlElement xml,
    String name, {
    String? namespace,
    double? defaultValue = 0,
  }) {
    final attr = xml.getAttribute(name, namespaceUri: namespace);

    if (attr == null) {
      return defaultValue;
    }

    return double.parse(attr);
  }

  static SvgNumeric? getNumeric(
    XmlElement xml,
    String name,
    SvgBrush? brush, {
    String? namespace,
    double? defaultValue,
  }) {
    final attr = xml.getAttribute(name, namespaceUri: namespace);

    if (attr == null) {
      return defaultValue == null ? null : SvgNumeric.value(defaultValue, null);
    }

    return SvgNumeric(attr, brush);
  }

  static Iterable<SvgNumeric> splitNumeric(String parameters, SvgBrush? brush) {
    final parameterMatches = _transformParameterRegExp.allMatches(parameters);
    return parameterMatches.map((m) => SvgNumeric(m.group(0)!, brush));
  }

  static Iterable<double> splitDoubles(String parameters) {
    final parameterMatches = _transformParameterRegExp.allMatches(parameters);
    return parameterMatches.map((m) => double.parse(m.group(0)!));
  }

  static Iterable<int> splitIntegers(String parameters) {
    final parameterMatches = _transformParameterRegExp.allMatches(parameters);

    return parameterMatches.map((m) {
      return int.parse(m.group(0)!);
    });
  }

  /// Convert style to attributes
  static void convertStyle(XmlElement element) {
    final style = element.getAttribute('style')?.trim();
    if (style != null && style.isNotEmpty) {
      for (final style in style.split(';')) {
        if (style.trim().isEmpty) {
          continue;
        }
        final kv = RegExp(r'([\w-]+)\s*:\s*(.*)').allMatches(style).first;
        final key = kv.group(1)!;
        final value = kv.group(2)!;

        element.setAttribute(key, value);
      }
    }
  }
}

enum SvgUnit {
  pixels,
  milimeters,
  centimeters,
  inch,
  em,
  percent,
  points,
  direct,
}

class SvgNumeric {
  factory SvgNumeric(String value, SvgBrush? brush) {
    final r = RegExp(
      r'([-+]?[\d\.]+)\s*(px|pt|em|cm|mm|in|%|)',
    ).allMatches(value).first;

    return SvgNumeric.value(
      double.parse(r.group(1)!),
      brush,
      _svgUnits[r.group(2)]!,
    );
  }

  const SvgNumeric.value(this.value, this.brush, [this.unit = SvgUnit.direct]);

  static const _svgUnits = <String, SvgUnit>{
    'px': SvgUnit.pixels,
    'mm': SvgUnit.milimeters,
    'cm': SvgUnit.centimeters,
    'in': SvgUnit.inch,
    'em': SvgUnit.em,
    '%': SvgUnit.percent,
    'pt': SvgUnit.points,
    '': SvgUnit.direct,
  };

  final double value;

  final SvgUnit unit;

  final SvgBrush? brush;

  double get colorValue {
    switch (unit) {
      case SvgUnit.percent:
        return value / 100.0;
      case SvgUnit.direct:
        return value / 255.0;
      default:
        throw PdfException('Invalid color value $value ($unit)');
    }
  }

  /// This length in points, with a percentage resolved against [viewport].
  ///
  /// SVG 1.1 7.10: a percentage is a fraction of the current viewport - of its
  /// width for a horizontal length, its height for a vertical one, and of
  /// sqrt((w^2 + h^2) / 2) for anything else, such as a radius or a stroke width.
  /// [sizeValue] cannot know which, so it treats a percentage as a bare fraction;
  /// that is right for a gradient coordinate and wrong for geometry, where
  /// width="100%" came out as 1.0 point.
  double sizeIn(PdfPoint? viewport, SvgAxis axis) {
    if (unit != SvgUnit.percent || viewport == null) {
      return sizeValue;
    }

    final double basis;
    switch (axis) {
      case SvgAxis.horizontal:
        basis = viewport.x;
        break;
      case SvgAxis.vertical:
        basis = viewport.y;
        break;
      case SvgAxis.diagonal:
        basis = math.sqrt(
          (viewport.x * viewport.x + viewport.y * viewport.y) / 2.0,
        );
        break;
    }

    return value / 100.0 * basis;
  }

  double get sizeValue {
    switch (unit) {
      case SvgUnit.percent:
        return value / 100.0;
      case SvgUnit.direct:
      case SvgUnit.pixels:
      case SvgUnit.points:
        return value;
      case SvgUnit.milimeters:
        return value * PdfPageFormat.mm;
      case SvgUnit.centimeters:
        return value * PdfPageFormat.cm;
      case SvgUnit.inch:
        return value * PdfPageFormat.inch;
      case SvgUnit.em:
        return value * brush!.fontSize!.sizeValue;
    }
  }
}

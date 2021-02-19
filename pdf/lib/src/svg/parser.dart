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
import 'package:xml/xml.dart';

import 'brush.dart';

class SvgParser {
  /// Create an SVG parser

  factory SvgParser({required XmlDocument xml}) {
    final root = xml.rootElement;

    final vbattr = root.getAttribute('viewBox');

    final width = getNumeric(root, 'width', null)?.sizeValue;
    final height = getNumeric(root, 'height', null)?.sizeValue;

    final vb = vbattr == null
        ? <double>[0, 0, width ?? 1000, height ?? 1000]
        : splitDoubles(vbattr);

    if (vb.isEmpty || vb.length > 4) {
      throw Exception('viewBox must contain 1..4 parameters');
    }

    final fvb = [
      ...List<double>.filled(4 - vb.length, 0),
      ...vb,
    ];

    final viewBox = PdfRect(fvb[0], fvb[1], fvb[2], fvb[3]);

    return SvgParser._(width, height, viewBox, root);
  }

  SvgParser._(this.width, this.height, this.viewBox, this.root);

  final PdfRect viewBox;

  final double? width;

  final double? height;

  final XmlElement root;

  static final _transformParameterRegExp =
      RegExp(r'[\w.-]+(px|pt|em|cm|mm|in|%|)');

  XmlElement? findById(String id) {
    try {
      return root.descendants.whereType<XmlElement>().firstWhere(
            (e) => e.getAttribute('id') == id,
          );
    } on StateError {
      return null;
    }
  }

  static double? getDouble(XmlElement xml, String name,
      {String? namespace, double? defaultValue = 0}) {
    final attr = xml.getAttribute(name, namespace: namespace);

    if (attr == null) {
      return defaultValue;
    }

    return double.parse(attr);
  }

  static SvgNumeric? getNumeric(XmlElement xml, String name, SvgBrush? brush,
      {String? namespace, double? defaultValue}) {
    final attr = xml.getAttribute(name, namespace: namespace);

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
  direct
}

class SvgNumeric {
  factory SvgNumeric(String value, SvgBrush? brush) {
    final r = RegExp(r'([-+]?[\d\.]+)\s*(px|pt|em|cm|mm|in|%|)')
        .allMatches(value)
        .first;

    return SvgNumeric.value(
        double.parse(r.group(1)!), brush, _svgUnits[r.group(2)]!);
  }

  const SvgNumeric.value(
    this.value,
    this.brush, [
    this.unit = SvgUnit.direct,
  ]);

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
        throw Exception('Invalid color value $value ($unit)');
    }
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

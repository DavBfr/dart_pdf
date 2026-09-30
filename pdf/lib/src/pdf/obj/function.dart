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

import '../../base/exceptions.dart';
import '../color.dart';
import '../document.dart';
import '../format/array.dart';
import '../format/dict.dart';
import '../format/num.dart';
import 'object.dart';
import 'object_stream.dart';

abstract class PdfBaseFunction extends PdfObject<PdfDict> {
  PdfBaseFunction(PdfDocument pdfDocument)
    : super(pdfDocument, params: PdfDict());

  factory PdfBaseFunction.colorsAndStops(
    PdfDocument pdfDocument,
    List<PdfColor?> colors, [
    List<double>? stops,
  ]) {
    if (stops == null || stops.isEmpty) {
      return PdfFunction.fromColors(pdfDocument, colors);
    }

    final _colors = List<PdfColor>.from(colors);
    final _stops = List<double>.from(stops);

    final fn = <PdfFunction>[];
    var lc = _colors.first;

    if (_stops[0] > 0) {
      _colors.insert(0, lc);
      _stops.insert(0, 0);
    }

    if (_stops.last < 1) {
      _colors.add(_colors.last);
      _stops.add(1);
    }

    if (_stops.length != _colors.length) {
      throw PdfException(
        'The number of colors in a gradient must match the number of stops',
      );
    }

    for (final c in _colors.sublist(1)) {
      fn.add(PdfFunction.fromColors(pdfDocument, <PdfColor>[lc, c]));
      lc = c;
    }

    return PdfStitchingFunction(
      pdfDocument,
      functions: fn,
      bounds: _stops.sublist(1, _stops.length - 1),
      domainStart: 0,
      domainEnd: 1,
    );
  }
}

class PdfFunction extends PdfObjectStream implements PdfBaseFunction {
  PdfFunction(
    PdfDocument pdfDocument, {
    this.data,
    this.bitsPerSample = 8,
    this.order = 1,
    this.domain = const <num>[0, 1],
    this.range = const <num>[0, 1],
  }) : super(pdfDocument) {
    if (order != 1 && order != 3) {
      throw PdfException(
        'A sampled function interpolates linearly (order 1) or cubically '
        '(order 3), not with order $order',
      );
    }
  }

  factory PdfFunction.fromColors(
    PdfDocument pdfDocument,
    List<PdfColor?> colors,
  ) {
    final data = <int>[];
    for (final color in colors) {
      data.add((color!.red * 255.0).round() & 0xff);
      data.add((color.green * 255.0).round() & 0xff);
      data.add((color.blue * 255.0).round() & 0xff);
    }
    return PdfFunction(
      pdfDocument,
      data: data,
      range: const <num>[0, 1, 0, 1, 0, 1],
    );
  }

  final List<int>? data;

  final int bitsPerSample;

  /// The order of interpolation between samples: 1 for linear, 3 for cubic
  /// spline. Cubic interpolation needs at least four samples per dimension.
  final int order;

  final List<num> domain;

  final List<num> range;

  @override
  void prepare() {
    buf.putBytes(data!);
    super.prepare();

    // One sample holds one value per output, each bitsPerSample bits wide, so
    // that is what the byte count has to be divided by to count the samples.
    // /Size used to be data.length ~/ order, and order meant components per
    // sample - which made /Order, the interpolation order, unusable: every
    // gradient carried /Order 3 over the two samples it interpolates, where
    // cubic needs four.
    final outputs = range.length ~/ 2;
    final samples = data!.length * 8 ~/ (outputs * bitsPerSample);

    if (order == 3 && samples < 4) {
      throw PdfException(
        'Cubic interpolation needs at least 4 samples, this function has '
        '$samples',
      );
    }

    params['/FunctionType'] = const PdfNum(0);
    params['/BitsPerSample'] = PdfNum(bitsPerSample);
    if (order != 1) {
      params['/Order'] = PdfNum(order);
    }
    params['/Domain'] = PdfArray.fromNum(domain);
    params['/Range'] = PdfArray.fromNum(range);
    params['/Size'] = PdfArray.fromNum(<int>[samples]);
  }

  @override
  String toString() => '$runtimeType $bitsPerSample $order $data';
}

class PdfStitchingFunction extends PdfBaseFunction {
  PdfStitchingFunction(
    PdfDocument pdfDocument, {
    required this.functions,
    required this.bounds,
    this.domainStart = 0,
    this.domainEnd = 1,
  }) : super(pdfDocument);

  final List<PdfFunction> functions;

  final List<double> bounds;

  final double domainStart;

  final double domainEnd;

  @override
  void prepare() {
    super.prepare();

    params['/FunctionType'] = const PdfNum(3);
    params['/Functions'] = PdfArray.fromObjects(functions);
    params['/Domain'] = PdfArray.fromNum(<num>[domainStart, domainEnd]);
    params['/Bounds'] = PdfArray.fromNum(bounds);
    params['/Encode'] = PdfArray.fromNum(
      List<int>.generate(functions.length * 2, (int i) => i % 2),
    );
  }

  @override
  String toString() =>
      '$runtimeType $domainStart $bounds $domainEnd $functions';
}

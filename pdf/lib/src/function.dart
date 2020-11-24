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

import 'color.dart';
import 'data_types.dart';
import 'document.dart';
import 'object.dart';
import 'object_stream.dart';

abstract class PdfBaseFunction extends PdfObject {
  PdfBaseFunction(PdfDocument pdfDocument) : super(pdfDocument);
}

class PdfFunction extends PdfObjectStream implements PdfBaseFunction {
  PdfFunction(
    PdfDocument pdfDocument, {
    this.colors,
  }) : super(pdfDocument);

  final List<PdfColor> colors;

  @override
  void prepare() {
    for (final color in colors) {
      buf.putBytes(<int>[
        (color.red * 255.0).round() & 0xff,
        (color.green * 255.0).round() & 0xff,
        (color.blue * 255.0).round() & 0xff,
      ]);
    }

    super.prepare();

    params['/FunctionType'] = const PdfNum(0);
    params['/BitsPerSample'] = const PdfNum(8);
    params['/Order'] = const PdfNum(3);
    params['/Domain'] = PdfArray.fromNum(const <num>[0, 1]);
    params['/Range'] = PdfArray.fromNum(const <num>[0, 1, 0, 1, 0, 1]);
    params['/Size'] = PdfArray.fromNum(<int>[colors.length]);
  }
}

class PdfStitchingFunction extends PdfBaseFunction {
  PdfStitchingFunction(
    PdfDocument pdfDocument, {
    @required this.functions,
    @required this.bounds,
    this.domainStart = 0,
    this.domainEnd = 1,
  })  : assert(functions != null),
        assert(bounds != null),
        super(pdfDocument);

  final List<PdfFunction> functions;

  final List<double> bounds;

  final double domainStart;

  final double domainEnd;

  @override
  void prepare() {
    super.prepare();

    params['/FunctionType'] = const PdfNum(3);
    params['/Functions'] = PdfArray.fromObjects(functions);
    params['/Order'] = const PdfNum(3);
    params['/Domain'] = PdfArray.fromNum(<num>[domainStart, domainEnd]);
    params['/Bounds'] = PdfArray.fromNum(bounds);
    params['/Encode'] = PdfArray.fromNum(
        List<int>.generate(functions.length * 2, (int i) => i % 2));
  }
}

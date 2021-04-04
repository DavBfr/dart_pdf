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

import 'package:vector_math/vector_math_64.dart';

import 'data_types.dart';
import 'document.dart';
import 'graphic_state.dart';
import 'object_dict.dart';
import 'shading.dart';

abstract class PdfPattern extends PdfObjectDict {
  PdfPattern(PdfDocument pdfDocument, this.patternType, this.matrix)
      : super(pdfDocument);

  /// Name of the Pattern object
  String get name => '/P$objser';

  final int patternType;

  final Matrix4? matrix;

  @override
  void prepare() {
    super.prepare();

    params['/PatternType'] = PdfNum(patternType);

    if (matrix != null) {
      final s = matrix!.storage;
      params['/Matrix'] =
          PdfArray.fromNum(<double>[s[0], s[1], s[4], s[5], s[12], s[13]]);
    }
  }
}

class PdfShadingPattern extends PdfPattern {
  PdfShadingPattern(
    PdfDocument pdfDocument, {
    required this.shading,
    Matrix4? matrix,
    this.graphicState,
  }) : super(pdfDocument, 2, matrix);

  final PdfShading shading;

  final PdfGraphicState? graphicState;

  @override
  void prepare() {
    super.prepare();

    params['/Shading'] = shading.ref();

    if (graphicState != null) {
      params['/ExtGState'] = graphicState!.output();
    }
  }
}

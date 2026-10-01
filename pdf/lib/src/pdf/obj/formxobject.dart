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

import '../document.dart';
import '../format/array.dart';
import '../format/num.dart';
import 'graphic_stream.dart';
import 'xobject.dart';

/// Form XObject
///
/// Mixes in [PdfGraphicStream], so every font, shader, pattern, xobject and
/// graphic state a [PdfGraphics] registers while painting into it lands in this
/// form's own /Resources. It used to carry only a font and xobject map of its
/// own, and its subclasses painted onto a page of a second, discarded document:
/// the bytes reached the form but the resources did not, so the stream named
/// objects that were never written and the form rendered blank.
class PdfFormXObject extends PdfXObject with PdfGraphicStream {
  /// Create a Form XObject
  PdfFormXObject(PdfDocument pdfDocument) : super(pdfDocument, '/Form') {
    params['/FormType'] = const PdfNum(1);
    params['/BBox'] = PdfArray.fromNum(const <int>[0, 0, 1000, 1000]);
  }

  /// Transformation matrix
  void setMatrix(Matrix4 t) {
    final s = t.storage;
    params['/Matrix'] = PdfArray.fromNum(<double>[
      s[0],
      s[1],
      s[4],
      s[5],
      s[12],
      s[13],
    ]);
  }
}

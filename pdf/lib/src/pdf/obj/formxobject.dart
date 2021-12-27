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

import '../data_types.dart';
import '../document.dart';
import 'font.dart';
import 'xobject.dart';

/// Form XObject
class PdfFormXObject extends PdfXObject {
  /// Create a Form XObject
  PdfFormXObject(PdfDocument pdfDocument) : super(pdfDocument, '/Form') {
    params['/FormType'] = const PdfNum(1);
    params['/BBox'] = PdfArray.fromNum(const <int>[0, 0, 1000, 1000]);
  }

  /// The fonts associated with this page
  final Map<String, PdfFont> fonts = <String, PdfFont>{};

  /// The xobjects or other images in the pdf
  final Map<String, PdfXObject> xobjects = <String, PdfXObject>{};

  /// Transformation matrix
  void setMatrix(Matrix4 t) {
    final s = t.storage;
    params['/Matrix'] =
        PdfArray.fromNum(<double>[s[0], s[1], s[4], s[5], s[12], s[13]]);
  }

  @override
  void prepare() {
    super.prepare();

    // This holds any resources for this FormXObject
    final resources = PdfDict();

    // fonts
    if (fonts.isNotEmpty) {
      resources['/Font'] = PdfDict.fromObjectMap(fonts);
    }

    // Now the XObjects
    if (xobjects.isNotEmpty) {
      resources['/XObject'] = PdfDict.fromObjectMap(xobjects);
    }

    if (resources.isNotEmpty) {
      params['/Resources'] = resources;
    }
  }
}

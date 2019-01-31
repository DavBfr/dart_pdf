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

part of pdf;

class PdfFormXObject extends PdfXObject {
  /// The fonts associated with this page
  final fonts = Map<String, PdfFont>();

  /// The xobjects or other images in the pdf
  final xobjects = Map<String, PdfXObject>();

  PdfFormXObject(PdfDocument pdfDocument) : super(pdfDocument, '/Form') {
    params["/FormType"] = PdfStream.string("1");
    params["/BBox"] = PdfStream.string("[0 0 1000 1000]");
  }

  /// set matrix
  void setMatrix(Matrix4 t) {
    var s = t.storage;
    params["/Matrix"] =
        PdfStream.string("[${s[0]} ${s[1]} ${s[4]} ${s[5]} ${s[12]} ${s[13]}]");
  }

  @override
  void _prepare() {
    super._prepare();

    // Now the resources
    /// This holds any resources for this FormXObject
    final resources = Map<String, PdfStream>();

    // fonts
    if (fonts.length > 0) {
      resources["/Font"] = PdfStream()..putObjectDictionary(fonts);
    }

    // Now the XObjects
    if (xobjects.length > 0) {
      resources["/XObject"] = PdfStream()..putObjectDictionary(xobjects);
    }

    if (resources.length > 0) {
      params["/Resources"] = PdfStream.dictionary(resources);
    }
  }
}

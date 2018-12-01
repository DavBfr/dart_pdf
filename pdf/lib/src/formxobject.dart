/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
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

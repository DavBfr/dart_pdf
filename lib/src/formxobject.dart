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

class PDFFormXObject extends PDFXObject {
  /// The fonts associated with this page
  final fonts = new Map<String, PDFFont>();

  /// The xobjects or other images in the pdf
  final xobjects = new Map<String, PDFXObject>();

  PDFFormXObject(PDFDocument pdfDocument) : super(pdfDocument, '/Form') {
    params["/FormType"] = PDFStream.string("1");
    params["/BBox"] = PDFStream.string("[0 0 1000 1000]");
  }

  /// set matrix
  void setMatrix(Matrix4 t) {
    var s = t.storage;
    params["/Matrix"] = PDFStream.string("[${s[0]} ${s[1]} ${s[4]} ${s[5]} ${s[12]} ${s[13]}]");
  }

  @override
  void prepare() {
    super.prepare();

    // Now the resources
    /// This holds any resources for this FormXObject
    final resources = new Map<String, PDFStream>();

    // fonts
    if (fonts.length > 0) {
      resources["/Font"] = new PDFStream()..putObjectDictionary(fonts);
    }

    // Now the XObjects
    if (xobjects.length > 0) {
      resources["/XObject"] = new PDFStream()..putObjectDictionary(xobjects);
    }

    if (resources.length > 0) {
      params["/Resources"] = PDFStream.dictionary(resources);
    }
  }
}

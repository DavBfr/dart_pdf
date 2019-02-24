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

class PdfPage extends PdfObject {
  /// This constructs a Page object, which will hold any contents for this
  /// page.
  ///
  /// Once created, it is added to the document via the [PdfDocument.add()] method.
  ///
  /// @param pdfDocument Document
  /// @param pageFormat [PdfPageFormat] describing the page size
  PdfPage(PdfDocument pdfDocument, {this.pageFormat = PdfPageFormat.a4})
      : super(pdfDocument, '/Page') {
    pdfDocument.pdfPageList.pages.add(this);
  }

  /// This is this page format, ie the size of the page, margins, and rotation
  final PdfPageFormat pageFormat;

  /// This holds the contents of the page.
  List<PdfObjectStream> contents = <PdfObjectStream>[];

  /// Object ID that contains a thumbnail sketch of the page.
  /// -1 indicates no thumbnail.
  PdfObject thumbnail;

  /// This holds any Annotations contained within this page.
  List<PdfAnnot> annotations = <PdfAnnot>[];

  /// The fonts associated with this page
  final Map<String, PdfFont> fonts = <String, PdfFont>{};

  /// The xobjects or other images in the pdf
  final Map<String, PdfXObject> xObjects = <String, PdfXObject>{};

  /// This returns a [PdfGraphics] object, which can then be used to render
  /// on to this page. If a previous [PdfGraphics] object was used, this object
  /// is appended to the page, and will be drawn over the top of any previous
  /// objects.
  ///
  /// @return a new [PdfGraphics] object to be used to draw this page.
  PdfGraphics getGraphics() {
    final PdfObjectStream stream = PdfObjectStream(pdfDocument);
    final PdfGraphics g = PdfGraphics(this, stream.buf);
    contents.add(stream);
    return g;
  }

  /// This adds an Annotation to the page.
  ///
  /// As with other objects, the annotation must be added to the pdf
  /// document using [PdfDocument.add()] before adding to the page.
  ///
  /// @param ob Annotation to add.
  void addAnnotation(PdfObject ob) {
    annotations.add(ob);
  }

  /// @param os OutputStream to send the object to
  @override
  void _prepare() {
    super._prepare();

    // the /Parent pages object
    params['/Parent'] = pdfDocument.pdfPageList.ref();

    // the /MediaBox for the page size
    params['/MediaBox'] = PdfStream()
      ..putNumArray(<double>[0, 0, pageFormat.width, pageFormat.height]);

    // Rotation (if not zero)
//        if(rotate!=0) {
//            os.write("/Rotate ");
//            os.write(Integer.toString(rotate).getBytes());
//            os.write("\n");
//        }

    // the /Contents pages object
    if (contents.isNotEmpty) {
      if (contents.length == 1) {
        params['/Contents'] = contents[0].ref();
      } else {
        params['/Contents'] = PdfStream()..putObjectArray(contents);
      }
    }

    // Now the resources
    /// This holds any resources for this page
    final Map<String, PdfStream> resources = <String, PdfStream>{};

    // fonts
    if (fonts.isNotEmpty) {
      resources['/Font'] = PdfStream()..putObjectDictionary(fonts);
    }

    // Now the XObjects
    if (xObjects.isNotEmpty) {
      resources['/XObject'] = PdfStream()..putObjectDictionary(xObjects);
    }

    params['/Resources'] = PdfStream.dictionary(resources);

    // The thumbnail
    if (thumbnail != null) {
      params['/Thumb'] = thumbnail.ref();
    }

    // The /Annots object
    if (annotations.isNotEmpty) {
      params['/Annots'] = PdfStream()..putObjectArray(annotations);
    }
  }
}

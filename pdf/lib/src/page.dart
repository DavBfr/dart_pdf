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

// ignore_for_file: omit_local_variable_types

part of pdf;

class PdfPage extends PdfObject {
  /// This constructs a Page object, which will hold any contents for this
  /// page.
  ///
  /// Once created, it is added to the document via the [PdfDocument.add()] method.
  ///
  /// @param pdfDocument Document
  /// @param pageFormat [PdfPageFormat] describing the page size
  PdfPage(PdfDocument pdfDocument, {this.pageFormat = PdfPageFormat.standard})
      : super(pdfDocument, '/Page') {
    pdfDocument.pdfPageList.pages.add(this);
  }

  /// This is this page format, ie the size of the page, margins, and rotation
  PdfPageFormat pageFormat;

  /// This holds the contents of the page.
  List<PdfObjectStream> contents = <PdfObjectStream>[];

  /// Object ID that contains a thumbnail sketch of the page.
  /// -1 indicates no thumbnail.
  PdfObject thumbnail;

  /// Isolated transparency: If this flag is true, objects within the group
  /// shall be composited against a fully transparent initial backdrop;
  /// if false, they shall be composited against the group’s backdrop
  bool isolatedTransparency = false;

  /// Whether the transparency group is a knockout group.
  /// If this flag is false, later objects within the group shall be composited
  /// with earlier ones with which they overlap; if true, they shall be
  /// composited with the group’s initial backdrop and shall overwrite any
  /// earlier overlapping objects.
  bool knockoutTransparency = false;

  /// This holds any Annotations contained within this page.
  List<PdfAnnot> annotations = <PdfAnnot>[];

  /// The fonts associated with this page
  final Map<String, PdfFont> fonts = <String, PdfFont>{};

  /// The fonts associated with this page
  final Map<String, PdfShading> shading = <String, PdfShading>{};

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
    params['/MediaBox'] =
        PdfArray.fromNum(<double>[0, 0, pageFormat.width, pageFormat.height]);

    // Rotation (if not zero)
//        if(rotate!=0) {
//            os.write("/Rotate ");
//            os.write(Integer.toString(rotate).getBytes());
//            os.write("\n");
//        }

    // the /Contents pages object
    if (contents.isNotEmpty) {
      if (contents.length == 1) {
        params['/Contents'] = contents.first.ref();
      } else {
        params['/Contents'] = PdfArray.fromObjects(contents);
      }
    }

    // Now the resources
    /// This holds any resources for this page
    final PdfDict resources = PdfDict();

    resources['/ProcSet'] = PdfArray(const <PdfName>[
      PdfName('/PDF'),
      PdfName('/Text'),
      PdfName('/ImageB'),
      PdfName('/ImageC'),
    ]);

    // fonts
    if (fonts.isNotEmpty) {
      resources['/Font'] = PdfDict.fromObjectMap(fonts);
    }

    // shading
    if (shading.isNotEmpty) {
      resources['/Shading'] = PdfDict.fromObjectMap(shading);
    }

    // Now the XObjects
    if (xObjects.isNotEmpty) {
      resources['/XObject'] = PdfDict.fromObjectMap(xObjects);
    }

    if (pdfDocument.hasGraphicStates) {
      // Declare Transparency Group settings
      params['/Group'] = PdfDict(<String, PdfDataType>{
        '/Type': const PdfName('/Group'),
        '/S': const PdfName('/Transparency'),
        '/CS': const PdfName('/DeviceRGB'),
        '/I': PdfBool(isolatedTransparency),
        '/K': PdfBool(knockoutTransparency),
      });

      resources['/ExtGState'] = pdfDocument.graphicStates.ref();
    }

    params['/Resources'] = resources;

    // The thumbnail
    if (thumbnail != null) {
      params['/Thumb'] = thumbnail.ref();
    }

    // The /Annots object
    if (annotations.isNotEmpty) {
      params['/Annots'] = PdfArray.fromObjects(annotations);
    }
  }
}

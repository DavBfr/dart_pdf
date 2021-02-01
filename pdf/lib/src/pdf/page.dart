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

import 'annotation.dart';
import 'data_types.dart';
import 'document.dart';
import 'graphic_stream.dart';
import 'graphics.dart';
import 'object.dart';
import 'object_stream.dart';
import 'page_format.dart';

/// Page object, which will hold any contents for this page.
class PdfPage extends PdfObject with PdfGraphicStream {
  /// This constructs a Page object, which will hold any contents for this
  /// page.
  PdfPage(
    PdfDocument pdfDocument, {
    this.pageFormat = PdfPageFormat.standard,
    int? index,
  }) : super(pdfDocument, type: '/Page') {
    if (index != null) {
      pdfDocument.pdfPageList.pages.insert(index, this);
    } else {
      pdfDocument.pdfPageList.pages.add(this);
    }
  }

  /// This is this page format, ie the size of the page, margins, and rotation
  PdfPageFormat pageFormat;

  /// This holds the contents of the page.
  List<PdfObjectStream> contents = <PdfObjectStream>[];

  /// This holds any Annotations contained within this page.
  List<PdfAnnot> annotations = <PdfAnnot>[];

  /// This returns a [PdfGraphics] object, which can then be used to render
  /// on to this page. If a previous [PdfGraphics] object was used, this object
  /// is appended to the page, and will be drawn over the top of any previous
  /// objects.
  PdfGraphics getGraphics() {
    final stream = PdfObjectStream(pdfDocument);
    final g = PdfGraphics(this, stream.buf);
    contents.add(stream);
    return g;
  }

  /// This adds an Annotation to the page.
  void addAnnotation(PdfAnnot ob) {
    annotations.add(ob);
  }

  @override
  void prepare() {
    super.prepare();

    // the /Parent pages object
    params['/Parent'] = pdfDocument.pdfPageList.ref();

    // the /MediaBox for the page size
    params['/MediaBox'] =
        PdfArray.fromNum(<double>[0, 0, pageFormat.width, pageFormat.height]);

    // The graphic operations to draw the page
    if (contents.isNotEmpty) {
      final contentList = PdfArray.fromObjects(contents);

      if (params.containsKey('/Contents')) {
        final prevContent = params['/Contents'];
        if (prevContent is PdfArray) {
          contentList.values.insertAll(0, prevContent.values);
        } else {
          contentList.values.insert(0, prevContent);
        }
      }

      contentList.uniq();

      if (contentList.values.length == 1) {
        params['/Contents'] = contentList.values.first;
      } else {
        params['/Contents'] = contentList;
      }
    }

    // The /Annots object
    if (annotations.isNotEmpty) {
      if (params.containsKey('/Annots')) {
        final annotsList = params['/Annots'];
        if (annotsList is PdfArray) {
          annotsList.values.addAll(PdfArray.fromObjects(annotations).values);
        }
      } else {
        params['/Annots'] = PdfArray.fromObjects(annotations);
      }
    }
  }
}

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

import '../data_types.dart';
import '../document.dart';
import '../graphics.dart';
import '../page_format.dart';
import 'annotation.dart';
import 'graphic_stream.dart';
import 'object.dart';
import 'object_dict.dart';
import 'object_stream.dart';

/// Page rotation
enum PdfPageRotation {
  /// No rotation
  none,

  /// Rotated 90 degree clockwise
  rotate90,

  /// Rotated 180 degree clockwise
  rotate180,

  /// Rotated 270 degree clockwise
  rotate270,
}

/// Page object, which will hold any contents for this page.
class PdfPage extends PdfObjectDict with PdfGraphicStream {
  /// This constructs a Page object, which will hold any contents for this
  /// page.
  PdfPage(
    PdfDocument pdfDocument, {
    this.pageFormat = PdfPageFormat.standard,
    this.rotate = PdfPageRotation.none,
    int? index,
    int? objser,
    int objgen = 0,
  }) : super(pdfDocument, type: '/Page', objser: objser, objgen: objgen) {
    if (index != null) {
      pdfDocument.pdfPageList.pages.insert(index, this);
    } else {
      pdfDocument.pdfPageList.pages.add(this);
    }
  }

  /// This is this page format, ie the size of the page, margins, and rotation
  PdfPageFormat pageFormat;

  /// The page rotation angle
  PdfPageRotation rotate;

  /// This holds the contents of the page.
  final contents = <PdfObject>[];

  /// This holds any Annotations contained within this page.
  final annotations = <PdfAnnot>[];

  final _contentGraphics = <PdfObject, PdfGraphics>{};

  /// This returns a [PdfGraphics] object, which can then be used to render
  /// on to this page. If a previous [PdfGraphics] object was used, this object
  /// is appended to the page, and will be drawn over the top of any previous
  /// objects.
  PdfGraphics getGraphics() {
    final stream = PdfObjectStream(pdfDocument);
    final g = PdfGraphics(this, stream.buf);
    _contentGraphics[stream] = g;
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

    if (rotate != PdfPageRotation.none) {
      params['/Rotate'] = PdfNum(rotate.index * 90);
    }

    // the /MediaBox for the page size
    params['/MediaBox'] =
        PdfArray.fromNum(<double>[0, 0, pageFormat.width, pageFormat.height]);

    for (final content in contents) {
      if (!_contentGraphics[content]!.altered) {
        content.inUse = false;
      }
    }

    // The graphic operations to draw the page
    final contentList =
        PdfArray.fromObjects(contents.where((e) => e.inUse).toList());

    if (params.containsKey('/Contents')) {
      final prevContent = params['/Contents']!;
      if (prevContent is PdfArray) {
        contentList.values
            .insertAll(0, prevContent.values.whereType<PdfIndirect>());
      } else if (prevContent is PdfIndirect) {
        contentList.values.insert(0, prevContent);
      }
    }

    contentList.uniq();

    if (contentList.values.length == 1) {
      params['/Contents'] = contentList.values.first;
    } else if (contentList.isNotEmpty) {
      params['/Contents'] = contentList;
    }

    // The /Annots object
    if (annotations.isNotEmpty) {
      if (params.containsKey('/Annots')) {
        final annotationList = params['/Annots'];
        if (annotationList is PdfArray) {
          annotationList.values
              .addAll(PdfArray.fromObjects(annotations).values);
        }
      } else {
        params['/Annots'] = PdfArray.fromObjects(annotations);
      }
    }
  }
}

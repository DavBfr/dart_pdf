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

import '../document.dart';
import '../format/array.dart';
import '../format/dict.dart';
import '../format/indirect.dart';
import '../format/name.dart';
import '../format/num.dart';
import '../graphics.dart';
import '../page_format.dart';
import '../point.dart';
import 'annotation.dart';
import 'graphic_stream.dart';
import 'object.dart';
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
class PdfPage extends PdfObject<PdfDict> with PdfGraphicStream {
  /// This constructs a Page object, which will hold any contents for this
  /// page.
  PdfPage(
    PdfDocument pdfDocument, {
    this.pageFormat = PdfPageFormat.standard,
    this.rotate = PdfPageRotation.none,
    this.origin = PdfPoint.zero,
    this.protectImportedContents = true,
    int? index,
    int? objser,
    int objgen = 0,
  }) : super(
         pdfDocument,
         params: PdfDict.values({'/Type': const PdfName('/Page')}),
         objser: objser,
         objgen: objgen,
       ) {
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

  /// The lower left corner of the page, in PDF units.
  ///
  /// [pageFormat] carries only a width and a height, and `/MediaBox` was written
  /// as `[0 0 w h]` whatever the page said - so loading a PDF whose box has a
  /// negative origin and re-saving it pinned the box to 0,0 and the imported
  /// content at negative coordinates fell off the page.
  PdfPoint origin;

  /// Whether content appended to an imported page starts from the default
  /// graphics state.
  ///
  /// ISO 32000-1 7.8.2 concatenates a `/Contents` array into one stream, so the
  /// producer's leftover state - a top-level flip, an unbalanced `q` - was still
  /// in force for anything added afterwards. Set false to go back to that.
  final bool protectImportedContents;

  /// This holds the contents of the page.
  final contents = <PdfObject>[];

  /// This holds any Annotations contained within this page.
  final annotations = <PdfAnnot>[];

  final _contentGraphics = <PdfObject, PdfGraphics>{};

  /// The two streams that bracket imported content, created on the first
  /// [getGraphics] of a page that has some.
  ///
  /// They are made here and not in prepare(), because PdfDocument._write
  /// iterates the object list while calling prepare() and a new PdfObject
  /// registers itself in it - a ConcurrentModificationError. They stay out of
  /// [contents], whose _contentGraphics lookup would not find them.
  PdfObjectStream? _importedOpen;

  PdfObjectStream? _importedClose;

  /// This returns a [PdfGraphics] object, which can then be used to render
  /// on to this page. If a previous [PdfGraphics] object was used, this object
  /// is appended to the page, and will be drawn over the top of any previous
  /// objects.
  PdfGraphics getGraphics() {
    // ISO 32000-1 7.8.2 concatenates a /Contents array into one stream, so
    // whatever graphics state the imported content leaves behind - a top-level
    // flip, an unbalanced q - is still in force for anything appended after it.
    // Stamping text onto a loaded page came out mirrored, rotated or offset
    // depending on which tool wrote the file. Bracketing the imported entries
    // puts the default state back first.
    if (protectImportedContents &&
        _importedOpen == null &&
        params.containsKey('/Contents')) {
      _importedOpen = PdfObjectStream(pdfDocument)..buf.putString('q ');
      _importedClose = PdfObjectStream(pdfDocument)..buf.putString('Q ');
    }

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

    // the /MediaBox for the page size, from the page's own origin
    params['/MediaBox'] = PdfArray.fromNum(<double>[
      origin.x,
      origin.y,
      origin.x + pageFormat.width,
      origin.y + pageFormat.height,
    ]);

    // An inherited /CropBox was written in the source page's coordinates and is
    // not rewritten here, so it could name a region outside the box above.
    if (origin != PdfPoint.zero) {
      params.values.remove('/CropBox');
    }

    for (final content in contents) {
      if (!_contentGraphics[content]!.altered) {
        content.inUse = false;
      }
    }

    // The graphic operations to draw the page
    final contentList = PdfArray.fromObjects(
      contents.where((e) => e.inUse).toList(),
    );

    if (params.containsKey('/Contents')) {
      final prevContent = params['/Contents']!;
      final previous = <PdfIndirect>[
        if (prevContent is PdfArray)
          ...prevContent.values.whereType<PdfIndirect>()
        else if (prevContent is PdfIndirect)
          prevContent,
      ];

      // uniq() runs below and these two are distinct objects, so the brackets
      // survive it while a repeated imported reference still collapses.
      contentList.values.insertAll(0, <PdfIndirect>[
        if (_importedOpen != null && previous.isNotEmpty) _importedOpen!.ref(),
        ...previous,
        if (_importedClose != null && previous.isNotEmpty)
          _importedClose!.ref(),
      ]);
    }

    contentList.uniq();

    if (contentList.values.length == 1) {
      params['/Contents'] = contentList.values.first;
    } else if (contentList.isNotEmpty) {
      params['/Contents'] = contentList;
    }

    // The /Annots object, built the way /Contents is above: appending to the
    // array already in params re-added every annotation on each prepare(), so
    // writing one document twice listed them twice.
    if (annotations.isNotEmpty) {
      final annotationList = PdfArray.fromObjects(annotations);

      final previous = params['/Annots'];
      if (previous is PdfArray) {
        annotationList.values.insertAll(
          0,
          previous.values.whereType<PdfIndirect>(),
        );
      } else if (previous is PdfIndirect) {
        annotationList.values.insert(0, previous);
      }

      annotationList.uniq();
      params['/Annots'] = annotationList;
    }
  }
}

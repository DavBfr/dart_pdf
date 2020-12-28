/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'catalog.dart';
import 'document_parser.dart';
import 'encryption.dart';
import 'font.dart';
import 'graphic_state.dart';
import 'info.dart';
import 'io/interface.dart'
    if (dart.library.io) 'io/vm.dart'
    if (dart.library.js) 'io/js.dart';
import 'names.dart';
import 'object.dart';
import 'outline.dart';
import 'output.dart';
import 'page.dart';
import 'page_list.dart';
import 'signature.dart';
import 'stream.dart';

/// Display hint for the PDF viewer
enum PdfPageMode {
  /// This page mode indicates that the document
  /// should be opened just with the page visible.  This is the default
  none,

  /// This page mode indicates that the Outlines
  /// should also be displayed when the document is opened.
  outlines,

  /// This page mode indicates that the Thumbnails should be visible when the
  /// document first opens.
  thumbs,

  /// This page mode indicates that when the document is opened, it is displayed
  /// in full-screen-mode. There is no menu bar, window controls nor any other
  /// window present.
  fullscreen
}

/// Callback used to compress the data
typedef DeflateCallback = List<int> Function(List<int> data);

/// This class is the base of the Pdf generator. A [PdfDocument] class is
/// created for a document, and each page, object, annotation,
/// etc is added to the document.
/// Once complete, the document can be written to a Stream, and the Pdf
/// document's internal structures are kept in sync.
class PdfDocument {
  /// This creates a Pdf document
  PdfDocument({
    PdfPageMode pageMode = PdfPageMode.none,
    DeflateCallback deflate,
    bool compress = true,
  })  : deflate = compress ? (deflate ?? defaultDeflate) : null,
        prev = null {
    _objser = 1;

    // Now create some standard objects
    pdfPageList = PdfPageList(this);
    pdfNames = PdfNames(this);
    catalog = PdfCatalog(this, pdfPageList, pageMode, pdfNames);
  }

  PdfDocument.load(
    this.prev, {
    PdfPageMode pageMode = PdfPageMode.none,
    DeflateCallback deflate,
    bool compress = true,
  }) : deflate = compress ? (deflate ?? defaultDeflate) : null {
    _objser = prev.size;

    // Now create some standard objects
    pdfPageList = PdfPageList(this);
    pdfNames = PdfNames(this);
    catalog = PdfCatalog(this, pdfPageList, pageMode, pdfNames);

    // Import the existing document
    prev.mergeDocument(this);
  }

  final PdfDocumentParserBase prev;

  /// This is used to allocate objects a unique serial number in the document.
  int _objser;

  int get objser => _objser;

  /// This vector contains each indirect object within the document.
  final Set<PdfObject> objects = <PdfObject>{};

  /// This is the Catalog object, which is required by each Pdf Document
  PdfCatalog catalog;

  /// This is the info object. Although this is an optional object, we
  /// include it.
  PdfInfo info;

  /// This is the Pages object, which is required by each Pdf Document
  PdfPageList pdfPageList;

  /// The name dictionary
  PdfNames pdfNames;

  /// This is the Outline object, which is optional
  PdfOutline _outline;

  /// This holds a [PdfObject] describing the default border for annotations.
  /// It's only used when the document is being written.
  PdfObject defaultOutlineBorder;

  /// Callback to compress the stream in the pdf file.
  /// Use `deflate: zlib.encode` if using dart:io
  /// No compression by default
  final DeflateCallback deflate;

  /// Object used to encrypt the document
  PdfEncryption encryption;

  /// Object used to sign the document
  PdfSignature sign;

  /// Graphics state, representing only opacity.
  PdfGraphicStates _graphicStates;

  /// The PDF specification version
  final String version = '1.7';

  /// This holds the current fonts
  final Set<PdfFont> fonts = <PdfFont>{};

  Uint8List _documentID;

  /// Generates the document ID
  Uint8List get documentID {
    if (_documentID == null) {
      final rnd = math.Random();
      _documentID = Uint8List.fromList(sha256
          .convert(DateTime.now().toIso8601String().codeUnits +
              List<int>.generate(32, (_) => rnd.nextInt(256)))
          .bytes);
    }

    return _documentID;
  }

  /// Creates a new serial number
  int genSerial() => _objser++;

  /// This returns a specific page. It's used mainly when using a
  /// Serialized template file.
  PdfPage page(int page) {
    return pdfPageList.pages[page];
  }

  /// The root outline
  PdfOutline get outline {
    if (_outline == null) {
      _outline = PdfOutline(this);
      catalog.outlines = _outline;
    }
    return _outline;
  }

  /// Graphic states for opacity and transfer modes
  PdfGraphicStates get graphicStates {
    _graphicStates ??= PdfGraphicStates(this);
    return _graphicStates;
  }

  /// This document has at least one graphic state
  bool get hasGraphicStates => _graphicStates != null;

  /// This writes the document to an OutputStream.
  void _write(PdfStream os) {
    final pos = PdfOutput(os);

    // Write each object to the [PdfStream]. We call via the output
    // as that builds the xref table
    objects.forEach(pos.write);

    // Finally close the output, which writes the xref table.
    pos.close();
  }

  /// Generate the PDF document as a memory file
  Uint8List save() {
    final os = PdfStream();
    if (prev != null) {
      os.putBytes(prev.bytes);
    }
    _write(os);
    return os.output();
  }
}

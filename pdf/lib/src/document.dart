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

part of pdf;

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

typedef DeflateCallback = List<int> Function(List<int> data);

/// This class is the base of the Pdf generator. A [PdfDocument] class is
/// created for a document, and each page, object, annotation,
/// etc is added to the document.
/// Once complete, the document can be written to a Stream, and the Pdf
/// document's internal structures are kept in sync.
class PdfDocument {
  /// This creates a Pdf document
  /// @param pagemode an int, determines how the document will present itself to
  /// the viewer when it first opens.
  PdfDocument({
    PdfPageMode pageMode = PdfPageMode.none,
    DeflateCallback deflate,
    bool compress = true,
  }) : deflate = compress ? (deflate ?? defaultDeflate) : null {
    _objser = 1;

    // Now create some standard objects
    pdfPageList = PdfPageList(this);
    pdfNames = PdfNames(this);
    catalog = PdfCatalog(this, pdfPageList, pageMode, pdfNames);
  }

  /// This is used to allocate objects a unique serial number in the document.
  int _objser;

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

  /// The PDF specification version
  final String version = '1.7';

  /// These map the page modes just defined to the pagemodes setting of Pdf.
  static const List<String> _PdfPageModes = <String>[
    '/UseNone',
    '/UseOutlines',
    '/UseThumbs',
    '/FullScreen'
  ];

  /// This holds the current fonts
  final Set<PdfFont> fonts = <PdfFont>{};

  /// Generates the document ID
  List<int> _documentID;
  List<int> get documentID {
    if (_documentID == null) {
      final math.Random rnd = math.Random();
      _documentID = sha256
          .convert(DateTime.now().toIso8601String().codeUnits +
              List<int>.generate(32, (_) => rnd.nextInt(256)))
          .bytes;
    }

    return _documentID;
  }

  /// Creates a new serial number
  int _genSerial() => _objser++;

  /// This returns a specific page. It's used mainly when using a
  /// Serialized template file.
  ///
  /// ?? How does a serialized template file work ???
  ///
  /// @param page page number to return
  /// @return [PdfPage] at that position
  PdfPage page(int page) {
    return pdfPageList.getPage(page);
  }

  /// @return the root outline
  PdfOutline get outline {
    if (_outline == null) {
      _outline = PdfOutline(this);
      catalog.outlines = _outline;
    }
    return _outline;
  }

  /// This writes the document to an OutputStream.
  ///
  /// Note: You can call this as many times as you wish, as long as
  /// the calls are not running at the same time.
  ///
  /// Also, objects can be added or amended between these calls.
  ///
  /// Also, the OutputStream is not closed, but will be flushed on
  /// completion. It is up to the caller to close the stream.
  ///
  /// @param os OutputStream to write the document to
  void _write(PdfStream os) {
    final PdfOutput pos = PdfOutput(os);

    // Write each object to the [PdfStream]. We call via the output
    // as that builds the xref table
    objects.forEach(pos.write);

    // Finally close the output, which writes the xref table.
    pos.close();
  }

  List<int> save() {
    final PdfStream os = PdfStream();
    _write(os);
    return os.output();
  }
}

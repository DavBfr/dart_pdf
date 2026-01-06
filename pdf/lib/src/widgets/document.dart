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

import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../../pdf.dart';
import '../pdf/io/event_loop_balancer.dart';
import 'page.dart';
import 'theme.dart';

class Document {
  Document({
    PdfPageMode pageMode = PdfPageMode.none,
    DeflateCallback? deflate,
    bool compress = true,
    bool verbose = false,
    PdfVersion version = PdfVersion.pdf_1_5,
    this.theme,
    String? title,
    String? author,
    String? creator,
    String? subject,
    String? keywords,
    String? producer,
    XmlDocument? metadata,
  }) : document = PdfDocument(
          pageMode: pageMode,
          deflate: deflate,
          compress: compress,
          verbose: verbose,
          version: version,
        ) {
    if (title != null ||
        author != null ||
        creator != null ||
        subject != null ||
        keywords != null ||
        producer != null) {
      PdfInfo(
        document,
        title: title,
        author: author,
        creator: creator,
        subject: subject,
        keywords: keywords,
        producer: producer,
      );
    }
    if (metadata != null) {
      PdfMetadata(document, metadata);
    }
  }

  Document.load(
    PdfDocumentParserBase parser, {
    @Deprecated('Not used') PdfPageMode pageMode = PdfPageMode.none,
    DeflateCallback? deflate,
    bool compress = true,
    bool verbose = false,
    this.theme,
    String? title,
    String? author,
    String? creator,
    String? subject,
    String? keywords,
    String? producer,
  }) : document = PdfDocument.load(
          parser,
          deflate: deflate,
          compress: compress,
          verbose: verbose,
        ) {
    if (title != null ||
        author != null ||
        creator != null ||
        subject != null ||
        keywords != null ||
        producer != null) {
      PdfInfo(
        document,
        title: title,
        author: author,
        creator: creator,
        subject: subject,
        keywords: keywords,
        producer: producer,
      );
    }
  }

  static bool debug = false;

  final PdfDocument document;

  final ThemeData? theme;

  final List<Page> _pages = <Page>[];

  bool _paint = false;

  void addPage(Page page, {int? index}) {
    assert(!_paint, 'The document has already been saved.');
    page.generate(this, index: index);
    _pages.add(page);
  }

  void editPage(int index, Page page) {
    assert(!_paint, 'The document has already been saved.');
    page.generate(this, index: index, insert: false);
    _pages.add(page);
  }

  /// Generates the PDF document as a memory file.
  ///
  /// If [enableEventLoopBalancing] is `true`, the method yields periodically
  /// during processing to keep the event loop responsive. This can help
  /// avoid blocking during the processing of large documents.
  ///
  /// Returns a [Uint8List] containing the document data.
  Future<Uint8List> save({bool enableEventLoopBalancing = false}) async {
    if (!_paint) {
      final balancer = enableEventLoopBalancing ? EventLoopBalancer() : null;
      balancer?.start();

      for (final page in _pages) {
        await balancer?.yieldIfNeeded();
        page.postProcess(this);
      }

      balancer?.stop();
      _paint = true;
    }

    return await document.save(
      enableEventLoopBalancing: enableEventLoopBalancing,
    );
  }
}

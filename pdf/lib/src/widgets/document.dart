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

import 'package:pdf/pdf.dart';

import 'page.dart';
import 'theme.dart';

class Document {
  Document({
    PdfPageMode pageMode = PdfPageMode.none,
    DeflateCallback? deflate,
    bool compress = true,
    PdfVersion version = PdfVersion.pdf_1_4,
    this.theme,
    String? title,
    String? author,
    String? creator,
    String? subject,
    String? keywords,
    String? producer,
  }) : document = PdfDocument(
          pageMode: pageMode,
          deflate: deflate,
          compress: compress,
          version: version,
        ) {
    if (title != null ||
        author != null ||
        creator != null ||
        subject != null ||
        keywords != null ||
        producer != null) {
      document.info = PdfInfo(
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

  Document.load(
    PdfDocumentParserBase parser, {
    PdfPageMode pageMode = PdfPageMode.none,
    DeflateCallback? deflate,
    bool compress = true,
    this.theme,
    String? title,
    String? author,
    String? creator,
    String? subject,
    String? keywords,
    String? producer,
  }) : document = PdfDocument.load(
          parser,
          pageMode: pageMode,
          deflate: deflate,
          compress: compress,
        ) {
    if (title != null ||
        author != null ||
        creator != null ||
        subject != null ||
        keywords != null ||
        producer != null) {
      document.info = PdfInfo(
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
    page.generate(this, index: index);
    _pages.add(page);
  }

  void editPage(int index, Page page) {
    page.generate(this, index: index, insert: false);
    _pages.add(page);
  }

  Future<Uint8List> save() async {
    if (!_paint) {
      for (var page in _pages) {
        page.postProcess(this);
      }
      _paint = true;
    }
    return await document.save();
  }
}

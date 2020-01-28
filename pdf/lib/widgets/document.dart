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

part of widget;

class Document {
  Document(
      {PdfPageMode pageMode = PdfPageMode.none,
      DeflateCallback deflate,
      bool compress = true,
      this.theme,
      String title,
      String author,
      String creator,
      String subject,
      String keywords,
      String producer})
      : document = PdfDocument(
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
      document.info = PdfInfo(document,
          title: title,
          author: author,
          creator: creator,
          subject: subject,
          keywords: keywords,
          producer: producer);
    }
  }

  static bool debug = false;

  final PdfDocument document;

  final Theme theme;

  final List<Page> _pages = <Page>[];

  bool _paint = false;

  void addPage(Page page) {
    page.generate(this);
    _pages.add(page);
  }

  List<int> save() {
    if (!_paint) {
      for (Page page in _pages) {
        page.postProcess(this);
      }
      _paint = true;
    }
    return document.save();
  }
}

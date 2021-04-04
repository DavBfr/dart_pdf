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

import 'annotation.dart';
import 'data_types.dart';
import 'document.dart';
import 'names.dart';
import 'object_dict.dart';
import 'outline.dart';
import 'page_list.dart';

/// Pdf Catalog object
class PdfCatalog extends PdfObjectDict {
  /// This constructs a Pdf Catalog object
  PdfCatalog(
    PdfDocument pdfDocument,
    this.pdfPageList,
    this.pageMode,
    this.names,
  ) : super(pdfDocument, type: '/Catalog');

  /// The pages of the document
  final PdfPageList pdfPageList;

  /// The outlines of the document
  PdfOutline? outlines;

  /// The initial page mode
  final PdfPageMode pageMode;

  /// The initial page mode
  final PdfNames names;

  /// These map the page modes just defined to the pagemodes setting of Pdf.
  static const List<String> _PdfPageModes = <String>[
    '/UseNone',
    '/UseOutlines',
    '/UseThumbs',
    '/FullScreen'
  ];

  @override
  void prepare() {
    super.prepare();

    /// the PDF specification version, overrides the header version starting from 1.4
    params['/Version'] = PdfName('/${pdfDocument.versionString}');

    params['/Pages'] = pdfPageList.ref();

    // the Outlines object
    if (outlines != null && outlines!.outlines.isNotEmpty) {
      params['/Outlines'] = outlines!.ref();
    }

    // the Names object
    params['/Names'] = names.ref();

    // the /PageMode setting
    params['/PageMode'] = PdfName(_PdfPageModes[pageMode.index]);

    if (pdfDocument.sign != null) {
      params['/Perms'] = PdfDict({
        '/DocMDP': pdfDocument.sign!.ref(),
      });
    }

    final widgets = <PdfAnnot>[];
    for (var page in pdfDocument.pdfPageList.pages) {
      for (var annot in page.annotations) {
        if (annot.annot.subtype == '/Widget') {
          widgets.add(annot);
        }
      }
    }

    if (widgets.isNotEmpty) {
      params['/AcroForm'] = PdfDict({
        '/SigFlags': PdfNum(pdfDocument.sign?.flagsValue ?? 0),
        '/Fields': PdfArray.fromObjects(widgets),
      });
    }
  }
}

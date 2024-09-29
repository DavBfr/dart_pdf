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

import '../document.dart';
import '../format/array.dart';
import '../format/dict.dart';
import '../format/name.dart';
import '../format/num.dart';
import 'annotation.dart';
import 'metadata.dart';
import 'names.dart';
import 'object.dart';
import 'outline.dart';
import 'page_label.dart';
import 'page_list.dart';
import 'pdfa/pdfa_attached_files.dart';
import 'pdfa/pdfa_color_profile.dart';

/// Pdf Catalog object
class PdfCatalog extends PdfObject<PdfDict> {
  /// This constructs a Pdf Catalog object
  PdfCatalog(
    PdfDocument pdfDocument,
    this.pdfPageList, {
    this.pageMode,
    int objgen = 0,
    int? objser,
  }) : super(
          pdfDocument,
          params: PdfDict.values({
            '/Type': const PdfName('/Catalog'),
          }),
          objser: objser,
          objgen: objgen,
        );

  /// The pages of the document
  final PdfPageList pdfPageList;

  /// The outlines of the document
  PdfOutline? outlines;

  /// The document metadata
  PdfMetadata? metadata;

  /// Colorprofile output intent (Pdf/A)
  PdfaColorProfile? colorProfile;

  /// Attached files (Pdf/A 3b)
  PdfaAttachedFiles? attached;

  /// The initial page mode
  final PdfPageMode? pageMode;

  /// The anchor names
  PdfNames? names;

  /// The page labels of the document
  PdfPageLabels? pageLabels;

  /// These map the page modes just defined to the page modes setting of the Pdf.
  static const List<String> _pdfPageModes = <String>[
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

    if (metadata != null) {
      params['/Metadata'] = metadata!.ref();
    }

    // the Names object
    if (names != null) {
      params['/Names'] = names!.ref();
    }

    // ??? what to do, if /Names is already occupied?
    if (attached != null && attached!.isNotEmpty) {
      params['/Names'] = attached!.catalogNames();
      params['/AF'] = attached!.catalogAF();
    }

    // the PageLabels object
    if (pageLabels != null && pageLabels!.labels.isNotEmpty) {
      params['/PageLabels'] = pageLabels!.ref();
    }

    // the /PageMode setting
    if (pageMode != null) {
      params['/PageMode'] = PdfName(_pdfPageModes[pageMode!.index]);
    }

    if (pdfDocument.sign != null) {
      if (pdfDocument.sign!.value.hasMDP) {
        params['/Perms'] = PdfDict.values({
          '/DocMDP': pdfDocument.sign!.ref(),
        });
      }

      final dss = PdfDict();
      if (pdfDocument.sign!.crl.isNotEmpty) {
        dss['/CRLs'] = PdfArray.fromObjects(pdfDocument.sign!.crl);
      }
      if (pdfDocument.sign!.cert.isNotEmpty) {
        dss['/Certs'] = PdfArray.fromObjects(pdfDocument.sign!.cert);
      }
      if (pdfDocument.sign!.ocsp.isNotEmpty) {
        dss['/OCSPs'] = PdfArray.fromObjects(pdfDocument.sign!.ocsp);
      }

      if (dss.values.isNotEmpty) {
        params['/DSS'] = dss;
      }
    }

    final widgets = <PdfAnnot>[];
    for (final page in pdfDocument.pdfPageList.pages) {
      for (final annot in page.annotations) {
        if (annot.annot.subtype == '/Widget') {
          widgets.add(annot);
        }
      }
    }

    if (widgets.isNotEmpty) {
      final acroForm = (params['/AcroForm'] ??= PdfDict()) as PdfDict;
      acroForm['/SigFlags'] = PdfNum(pdfDocument.sign?.flagsValue ?? 0) |
          (acroForm['/SigFlags'] as PdfNum? ?? const PdfNum(0));
      final fields = (acroForm['/Fields'] ??= PdfArray()) as PdfArray;
      final fontRefs = PdfDict();
      for (final w in widgets) {
        if (w.annot is PdfTextField) {
          // collect textfield font references
          final tf = w.annot as PdfTextField;
          fontRefs.addAll(PdfDict.values({tf.font.name: tf.font.ref()}));
        }
        final ref = w.ref();
        if (!fields.values.contains(ref)) {
          fields.add(ref);
        }
      }
      if (fontRefs.isNotEmpty) {
        acroForm['/DR'] = PdfDict.values(// "Document Resources"
            {'/Font': fontRefs});
      }
    }

    if (colorProfile != null) {
      params['/OutputIntents'] = colorProfile!.outputIntents();
    }
  }
}

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

import 'dart:typed_data';

import '../document.dart';
import '../format/dict.dart';
import '../format/stream.dart';
import 'object.dart';
import 'object_dict.dart';
import 'object_stream.dart';

/// Signature flags
enum PdfSigFlags {
  /// The document contains at least one signature field.

  signaturesExist,

  /// The document contains signatures that may be invalidated if the file is
  /// saved (written) in a way that alters its previous contents, as opposed
  /// to an incremental update.
  appendOnly,
}

class PdfSignature extends PdfObjectDict {
  PdfSignature(
    PdfDocument pdfDocument, {
    required this.value,
    required this.flags,
    List<Uint8List>? crl,
    List<Uint8List>? cert,
    List<Uint8List>? ocsp,
  }) : super(pdfDocument, type: '/Sig') {
    if (crl != null) {
      for (final o in crl) {
        this.crl.add(PdfObjectStream(pdfDocument)..buf.putBytes(o));
      }
    }
    if (cert != null) {
      for (final o in cert) {
        this.cert.add(PdfObjectStream(pdfDocument)..buf.putBytes(o));
      }
    }
    if (ocsp != null) {
      for (final o in ocsp) {
        this.ocsp.add(PdfObjectStream(pdfDocument)..buf.putBytes(o));
      }
    }
  }

  final Set<PdfSigFlags> flags;

  final PdfSignatureBase value;

  int get flagsValue => flags.isEmpty
      ? 0
      : flags
          .map<int>((PdfSigFlags e) => 1 << e.index)
          .reduce((int a, int b) => a | b);

  final crl = <PdfObjectStream>[];

  final cert = <PdfObjectStream>[];

  final ocsp = <PdfObjectStream>[];

  int? _offsetStart;

  int? _offsetEnd;

  @override
  void write(PdfStream os) {
    value.preSign(this, params);

    _offsetStart = os.offset + '$objser $objgen obj\n'.length;
    super.write(os);
    _offsetEnd = os.offset;
  }

  Future<void> writeSignature(PdfStream os) async {
    assert(_offsetStart != null && _offsetEnd != null,
        'Must reserve the object space before signing the document');

    await value.sign(this, os, params, _offsetStart, _offsetEnd);
  }
}

abstract class PdfSignatureBase {
  /// Modification detection and prevention
  bool get hasMDP => false;

  void preSign(PdfObject object, PdfDict params);

  Future<void> sign(PdfObject object, PdfStream os, PdfDict params,
      int? offsetStart, int? offsetEnd);
}

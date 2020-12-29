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

import 'package:meta/meta.dart';

import 'data_types.dart';
import 'document.dart';
import 'object.dart';
import 'stream.dart';

enum PdfSigFlags { signaturesExist, appendOnly }

class PdfSignature extends PdfObject {
  PdfSignature(
    PdfDocument pdfDocument, {
    @required this.crypto,
    Set<PdfSigFlags> flags,
  })  : assert(crypto != null),
        flags = flags ?? const <PdfSigFlags>{PdfSigFlags.signaturesExist},
        super(pdfDocument, type: '/Sig');

  final Set<PdfSigFlags> flags;

  final PdfSignatureBase crypto;

  int get flagsValue => flags
      .map<int>((PdfSigFlags e) => 1 >> e.index)
      .reduce((int a, int b) => a | b);

  int _offsetStart;
  int _offsetEnd;

  @override
  void write(PdfStream os) {
    crypto.preSign(this, params);

    _offsetStart = os.offset + '$objser $objgen obj\n'.length;
    super.write(os);
    _offsetEnd = os.offset;
  }

  Future<void> writeSignature(PdfStream os) async {
    assert(_offsetStart != null && _offsetEnd != null,
        'Must reserve the object space before signing the document');

    await crypto.sign(this, os, params, _offsetStart, _offsetEnd);
  }
}

abstract class PdfSignatureBase {
  void preSign(PdfObject object, PdfDict params);

  Future<void> sign(PdfObject object, PdfStream os, PdfDict params,
      int offsetStart, int offsetEnd);
}

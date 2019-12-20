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

// ignore_for_file: omit_local_variable_types

part of pdf;

@immutable
class PdfSignatureRange {
  const PdfSignatureRange(this.start, this.end);

  final int start;
  final int end;
}

abstract class PdfSignature extends PdfObject {
  PdfSignature(PdfDocument pdfDocument) : super(pdfDocument, '/Sig');

  int _offsetStart;
  int _offsetEnd;

  void preSign();

  void sign(PdfStream os, List<PdfSignatureRange> ranges);

  @override
  void _write(PdfStream os) {
    preSign();

    _offsetStart = os.offset;
    super._write(os);
    _offsetEnd = os.offset;
  }

  void _writeSignature(PdfStream os) {
    assert(_offsetStart != null && _offsetEnd != null,
        'Must reserve the object space before signing the document');

    final List<PdfSignatureRange> ranges = <PdfSignatureRange>[
      PdfSignatureRange(0, _offsetStart),
      PdfSignatureRange(_offsetEnd, os.offset),
    ];

    sign(os, ranges);
    final PdfStream signature = PdfStream();
    super._write(signature);

    assert(signature.offset == _offsetEnd - _offsetStart);
    os.output().replaceRange(_offsetStart, _offsetEnd, signature.output());
  }
}

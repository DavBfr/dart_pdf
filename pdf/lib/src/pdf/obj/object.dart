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

import 'package:meta/meta.dart';

import '../document.dart';
import '../format/base.dart';
import '../format/object_base.dart';
import '../format/stream.dart';
import 'diagnostic.dart';

/// Base Object used in the PDF file
abstract class PdfObject<T extends PdfDataType>
    with PdfDiagnostic, PdfObjectBase {
  /// This is usually called by extensors to this class, and sets the
  /// Pdf Object Type
  PdfObject(
    this.pdfDocument, {
    required this.params,
    this.objgen = 0,
    int? objser,
  }) : objser = objser ?? pdfDocument.genSerial() {
    pdfDocument.objects.add(this);
  }

  /// This is the object parameters.
  final T params;

  @override
  final int objser;

  @override
  final int objgen;

  /// This allows any Pdf object to refer to the document being constructed.
  final PdfDocument pdfDocument;

  var inUse = true;

  @override
  DeflateCallback? get deflate => pdfDocument.deflate;

  @override
  PdfEncryptCallback? get encryptCallback => pdfDocument.encryption?.encrypt;

  @override
  bool get verbose => pdfDocument.verbose;

  @override
  PdfVersion get version => pdfDocument.version;

  /// Writes the object to the output stream.
  void write(PdfStream os) {
    prepare();
    _writeStart(os);
    writeContent(os);
    _writeEnd(os);
  }

  /// Prepare the object to be written to the stream
  @mustCallSuper
  void prepare() {}

  /// The write method should call this before writing anything to the
  /// OutputStream. This will send the standard header for each object.
  void _writeStart(PdfStream os) {
    os.putString('$objser $objgen obj\n');
  }

  void writeContent(PdfStream os) {
    params.output(os, verbose ? 0 : null);
    os.putByte(0x0a);
  }

  /// The write method should call this after writing anything to the
  /// OutputStream. This will send the standard footer for each object.
  void _writeEnd(PdfStream os) {
    os.putString('endobj\n');
  }

  @override
  String toString() => '$runtimeType $params';
}

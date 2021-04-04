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

import 'data_types.dart';
import 'document.dart';
import 'stream.dart';

/// Base Object used in the PDF file
class PdfObject {
  /// This is usually called by extensors to this class, and sets the
  /// Pdf Object Type
  PdfObject(
    this.pdfDocument, {
    // String? type,
    this.objgen = 0,
    int? objser,
  }) : objser = objser ?? pdfDocument.genSerial() {
    pdfDocument.objects.add(this);
  }

  /// This is the object parameters.
  final PdfDict params = PdfDict();

  /// This is the unique serial number for this object.
  final int objser;

  /// This is the generation number for this object.
  final int objgen;

  /// This allows any Pdf object to refer to the document being constructed.
  final PdfDocument pdfDocument;

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
    if (params.isNotEmpty) {
      params.output(os);
      os.putString('\n');
    }
  }

  /// The write method should call this after writing anything to the
  /// OutputStream. This will send the standard footer for each object.
  void _writeEnd(PdfStream os) {
    os.putString('endobj\n');
  }

  /// Returns the unique serial number in Pdf format
  PdfIndirect ref() => PdfIndirect(objser, objgen);

  @override
  String toString() => '$runtimeType $params';
}

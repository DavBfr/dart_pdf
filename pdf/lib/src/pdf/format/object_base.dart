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

import 'indirect.dart';

/// Callback used to compress the data
typedef DeflateCallback = List<int> Function(List<int> data);

/// Callback used to encrypt the value of a [PdfDictStream] or a [PdfEncStream]
typedef PdfEncryptCallback = Uint8List Function(
    Uint8List input, PdfObjectBase object);

/// PDF version to generate
enum PdfVersion {
  /// PDF 1.4
  pdf_1_4,

  /// PDF 1.5 to 1.7
  pdf_1_5,
}

mixin PdfObjectBase {
  /// This is the unique serial number for this object.
  int get objser;

  /// This is the generation number for this object.
  int get objgen => 0;

  /// Callback used to compress the data
  DeflateCallback? get deflate => null;

  /// Callback used to encrypt the value of a [PdfDictStream] or a [PdfEncStream]
  PdfEncryptCallback? get encryptCallback => null;

  /// Output a PDF document with comments and formatted data
  bool get verbose => false;

  PdfVersion get version => PdfVersion.pdf_1_5;

  /// Returns the unique serial number in Pdf format
  PdfIndirect ref() => PdfIndirect(objser, objgen);
}

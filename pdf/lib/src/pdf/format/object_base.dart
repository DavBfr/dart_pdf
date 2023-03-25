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

import 'base.dart';
import 'diagnostic.dart';
import 'indirect.dart';
import 'stream.dart';

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

class PdfSettings {
  const PdfSettings({
    this.deflate,
    this.encryptCallback,
    this.verbose = false,
    this.version = PdfVersion.pdf_1_5,
  });

  /// Callback to compress the streams in the pdf file.
  /// Use `deflate: zlib.encode` if using dart:io
  /// No compression by default
  final DeflateCallback? deflate;

  /// Callback used to encrypt the value of a [PdfDictStream] or a [PdfEncStream]
  final PdfEncryptCallback? encryptCallback;

  /// Output a PDF document with comments and formatted data
  final bool verbose;

  /// PDF version to generate
  final PdfVersion version;

  /// Compress the document
  bool get compress => deflate != null;
}

class PdfObjectBase<T extends PdfDataType> with PdfDiagnostic {
  PdfObjectBase({
    required this.objser,
    this.objgen = 0,
    required this.params,
    required this.settings,
  });

  /// This is the unique serial number for this object.
  final int objser;

  /// This is the generation number for this object.
  final int objgen;

  final T params;

  final PdfSettings settings;

  /// Returns the unique serial number in Pdf format
  PdfIndirect ref() => PdfIndirect(objser, objgen);

  int output(PdfStream s) {
    assert(() {
      if (settings.verbose) {
        setInsertion(s, 160);
        startStopwatch();
      }
      return true;
    }());

    final offset = s.offset;
    s.putString('$objser $objgen obj\n');
    writeContent(s);
    s.putString('endobj\n');

    assert(() {
      if (settings.verbose) {
        stopStopwatch();
        debugFill(
            'Creation time: ${elapsedStopwatch / Duration.microsecondsPerSecond} seconds');
        writeDebug(s);
      }
      return true;
    }());
    return offset;
  }

  void writeContent(PdfStream s) {
    params.output(this, s, settings.verbose ? 0 : null);
    s.putByte(0x0a);
  }
}

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

import 'ascii85.dart';
import 'data_types.dart';
import 'document.dart';
import 'object.dart';
import 'stream.dart';

/// Stream Object
class PdfObjectStream extends PdfObject {
  /// Constructs a stream object to store some data
  PdfObjectStream(
    PdfDocument pdfDocument, {
    String? type,
    this.isBinary = false,
  }) : super(pdfDocument, type: type);

  /// This holds the stream's content.
  final PdfStream buf = PdfStream();

  /// defines if the stream needs to be converted to ascii85
  final bool isBinary;

  Uint8List? _data;

  @override
  void prepare() {
    super.prepare();

    if (params.containsKey('/Filter') && _data == null) {
      // The data is already in the right format
      _data = buf.output();
    } else if (pdfDocument.deflate != null) {
      final original = buf.output();
      final newData = Uint8List.fromList(pdfDocument.deflate!(original));
      if (newData.lengthInBytes < original.lengthInBytes) {
        params['/Filter'] = const PdfName('/FlateDecode');
        _data = newData;
      }
    }

    if (_data == null) {
      if (isBinary) {
        // This is an Ascii85 stream
        final e = Ascii85Encoder();
        _data = e.convert(buf.output());
        params['/Filter'] = const PdfName('/ASCII85Decode');
      } else {
        // This is a non-deflated stream
        _data = buf.output();
      }
    }
    if (pdfDocument.encryption != null) {
      _data = pdfDocument.encryption!.encrypt(_data!, this);
    }
    params['/Length'] = PdfNum(_data!.length);
  }

  @override
  void writeContent(PdfStream os) {
    super.writeContent(os);

    os.putString('stream\n');
    os.putBytes(_data!);
    os.putString('\nendstream\n');
  }
}

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
import 'base.dart';
import 'dict.dart';
import 'name.dart';
import 'num.dart';
import 'object_base.dart';
import 'stream.dart';

class PdfDictStream extends PdfDict<PdfDataType> {
  factory PdfDictStream({
    Map<String, PdfDataType>? values,
    Uint8List? data,
    bool isBinary = false,
    bool encrypt = true,
    bool compress = true,
  }) {
    return PdfDictStream.values(
      values: values ?? {},
      data: data ?? Uint8List(0),
      encrypt: encrypt,
      compress: compress,
      isBinary: isBinary,
    );
  }

  PdfDictStream.values({
    required Map<String, PdfDataType> values,
    required this.data,
    this.isBinary = false,
    this.encrypt = true,
    this.compress = true,
  }) : super.values(values);

  Uint8List data;

  final bool isBinary;

  final bool encrypt;

  final bool compress;

  @override
  void output(PdfObjectBase o, PdfStream s, [int? indent]) {
    final _values = PdfDict(values);

    Uint8List? _data;

    if (_values.containsKey('/Filter')) {
      // The data is already in the right format
      _data = data;
    } else if (compress && o.deflate != null) {
      // Compress the data
      final newData = Uint8List.fromList(o.deflate!(data));
      if (newData.lengthInBytes < data.lengthInBytes) {
        _values['/Filter'] = const PdfName('/FlateDecode');
        _data = newData;
      }
    }

    if (_data == null) {
      if (isBinary) {
        // This is an Ascii85 stream
        final e = Ascii85Encoder();
        _data = e.convert(data);
        _values['/Filter'] = const PdfName('/ASCII85Decode');
      } else {
        // This is a non-deflated stream
        _data = data;
      }
    }

    if (encrypt && o.encryptCallback != null) {
      _data = o.encryptCallback!(_data, o);
    }

    _values['/Length'] = PdfNum(_data.length);

    _values.output(o, s, indent);
    if (indent != null) {
      s.putByte(0x0a);
    }
    s.putString('stream\n');
    s.putBytes(_data);
    s.putString('\nendstream\n');
  }
}

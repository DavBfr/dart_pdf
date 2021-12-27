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

import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../data_types.dart';
import '../document.dart';
import 'object.dart';

/// Pdf Metadata
class PdfMetadata extends PdfObject<PdfDictStream> {
  /// Store an Xml object
  PdfMetadata(
    PdfDocument pdfDocument,
    this.metadata,
  ) : super(
          pdfDocument,
          params: PdfDictStream(
            object: pdfDocument.catalog,
            compress: false,
            encrypt: false,
          ),
        ) {
    pdfDocument.catalog.metadata = this;
  }

  final XmlDocument metadata;

  @override
  void prepare() {
    super.prepare();
    params['/SubType'] = const PdfName('/XML');
    params.data = Uint8List.fromList(utf8.encode(metadata.toString()));
  }
}

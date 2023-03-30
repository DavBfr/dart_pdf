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

/// Base Object used in the PDF file
abstract class PdfObject<T extends PdfDataType> extends PdfObjectBase<T> {
  /// This is usually called by extensors to this class, and sets the
  /// Pdf Object Type
  PdfObject(
    this.pdfDocument, {
    required T params,
    int objgen = 0,
    int? objser,
  }) : super(
          objser: objser ?? pdfDocument.genSerial(),
          objgen: objgen,
          params: params,
          settings: pdfDocument.settings,
        ) {
    pdfDocument.objects.add(this);
  }

  /// This allows any Pdf object to refer to the document being constructed.
  final PdfDocument pdfDocument;

  var inUse = true;

  /// Prepare the object to be written to the stream
  @mustCallSuper
  void prepare() {}

  @override
  String toString() => '$runtimeType $params';
}

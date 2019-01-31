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

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';

class Printing {
  static const MethodChannel _channel = MethodChannel('printing');

  static Future<Null> printPdf({PdfDocument document, List<int> bytes}) async {
    assert(document != null || bytes != null);
    assert(!(document == null && bytes == null));

    if (document != null) bytes = document.save();

    final Map<String, dynamic> params = <String, dynamic>{
      'doc': Uint8List.fromList(bytes),
    };

    await _channel.invokeMethod('printPdf', params);
  }

  static Future<Null> sharePdf(
      {PdfDocument document, List<int> bytes, Rect bounds}) async {
    assert(document != null || bytes != null);
    assert(!(document == null && bytes == null));

    if (document != null) bytes = document.save();

    if (bounds == null) {
      bounds = Rect.fromCircle(center: Offset.zero, radius: 10.0);
    }

    final Map<String, dynamic> params = <String, dynamic>{
      'doc': Uint8List.fromList(bytes),
      'x': bounds.left,
      'y': bounds.top,
      'w': bounds.width,
      'h': bounds.height,
    };
    await _channel.invokeMethod('sharePdf', params);
  }
}

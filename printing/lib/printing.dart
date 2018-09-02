/*
 * Copyright (C) 2018, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General  License for more details.
 *
 * You should have received a copy of the GNU Lesser General
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';

class Printing {
  static const MethodChannel _channel = const MethodChannel('printing');

  static Future<Null> printPdf({PDFDocument document, List<int> bytes}) async {
    assert(document != null || bytes != null);
    assert(!(document == null && bytes == null));

    if (document != null) bytes = document.save();

    final Map<String, dynamic> params = <String, dynamic>{
      'doc': new Uint8List.fromList(bytes),
    };

    await _channel.invokeMethod('printPdf', params);
  }

  static Future<Null> sharePdf(
      {PDFDocument document, List<int> bytes, Rect bounds}) async {
    assert(document != null || bytes != null);
    assert(!(document == null && bytes == null));

    if (document != null) bytes = document.save();

    if (bounds == null) {
      bounds = new Rect.fromCircle(center: Offset.zero, radius: 10.0);
    }

    final Map<String, dynamic> params = <String, dynamic>{
      'doc': new Uint8List.fromList(bytes),
      'x': bounds.left,
      'y': bounds.top,
      'w': bounds.width,
      'h': bounds.height,
    };
    await _channel.invokeMethod('sharePdf', params);
  }
}

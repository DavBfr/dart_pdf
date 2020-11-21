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
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

Future<Uint8List> download(
  String url, {
  bool cache = true,
  String prefix = 'cache_',
  String suffix,
}) async {
  File file;
  if (cache) {
    if (suffix == null) {
      final l = url.lastIndexOf('.');
      if (l >= 0) {
        suffix = url.substring(l);
      }
    }
    file = File('$prefix${url.hashCode}$suffix');
    if (file.existsSync()) {
      return await file.readAsBytes();
    }
  }

  print('Downloading $url');
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse(url));
  final response = await request.close();
  final builder = await response.fold(
      BytesBuilder(), (BytesBuilder b, List<int> d) => b..add(d));
  final List<int> data = builder.takeBytes();

  if (cache) {
    await file.writeAsBytes(data);
  }
  return Uint8List.fromList(data);
}

PdfImage generateBitmap(PdfDocument pdf, int w, int h) {
  final bm = Uint32List(w * h);
  final dw = w.toDouble();
  final dh = h.toDouble();
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      bm[y * w + x] = (math.sin(x / dw) * 256).toInt() |
          (math.sin(y / dh) * 256).toInt() << 8 |
          (math.sin(x / dw * y / dh) * 256).toInt() << 16 |
          0xff000000;
    }
  }

  return PdfImage(
    pdf,
    image: bm.buffer.asUint8List(),
    width: w,
    height: h,
  );
}

Font loadFont(String filename) {
  final data = File(filename).readAsBytesSync();
  return Font.ttf(data.buffer.asByteData());
}

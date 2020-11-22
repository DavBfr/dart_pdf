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

ImageProvider generateBitmap(int w, int h) {
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

  return RawImage(
    bytes: bm.buffer.asUint8List(),
    width: w,
    height: h,
  );
}

Font loadFont(String filename) {
  final data = File(filename).readAsBytesSync();
  return Font.ttf(data.buffer.asByteData());
}

void hexDump(
  ByteData bytes,
  int offset,
  int length, [
  int highlight,
  int highlightLength,
]) {
  const reset = '\x1B[0m';
  const red = '\x1B[1;31m';
  var s = '';
  var t = '';
  var n = 0;
  var hl = false;
  for (var i = 0; i < length; i++) {
    final b = bytes.getUint8(offset + i);
    if (highlight != null && highlightLength != null) {
      if (offset + i >= highlight && offset + i < highlight + highlightLength) {
        if (!hl) {
          hl = true;
          s += red;
          t += red;
        }
      } else {
        if (hl) {
          hl = false;
          s += reset;
          t += reset;
        }
      }
    }
    s += b.toRadixString(16).padLeft(2, '0') + ' ';
    if (b > 31 && b < 128) {
      t += String.fromCharCode(b);
    } else {
      t += '.';
    }

    n++;
    if (n % 16 == 0) {
      if (hl) {
        s += reset;
        t += reset;
        hl = false;
      }
      print('$s   $t');
      s = '';
      t = '';
    }
  }
  print('$s   $t');
}

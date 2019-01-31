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
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import "package:test/test.dart";

Future<Uint8List> download(String url) async {
  var client = HttpClient();
  var request = await client.getUrl(Uri.parse(url));
  var response = await request.close();
  var builder = await response.fold(BytesBuilder(), (b, d) => b..add(d));
  var data = builder.takeBytes();
  return Uint8List.fromList(data);
}

void main() {
  test('Pdf1', () async {
    var pdf = PdfDocument();
    var page = PdfPage(pdf, pageFormat: PdfPageFormat.a4);

    var image = PdfImage(pdf,
        image: await download("https://www.nfet.net/nfet.jpg"),
        width: 472,
        height: 477,
        jpeg: true,
        alpha: false);

    var g = page.getGraphics();
    g.drawImage(image, 30.0, page.pageFormat.height - 507.0);

    var file = File('file4.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}

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
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

Document pdf;

void main() {
  setUpAll(() {
    Document.debug = true;
    pdf = Document();
  });

  test('Pdf Jpeg Download', () async {
    final PdfImage image = PdfImage.jpeg(
      pdf.document,
      image: await download('https://www.nfet.net/nfet.jpg'),
    );

    pdf.addPage(Page(
      build: (Context context) => Center(child: Image(image)),
    ));
  });

  test('Pdf Jpeg Orientation', () {
    pdf.addPage(
      Page(
        build: (Context context) => Wrap(
          spacing: 20,
          runSpacing: 20,
          children: List<Widget>.generate(
            PdfImageOrientation.values.length,
            (int index) => SizedBox(
              width: 230,
              height: 230,
              child: Image(
                PdfImage.jpeg(
                  pdf.document,
                  image: base64.decode(jpegImage),
                  orientation: PdfImageOrientation.values[index],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  });

  tearDownAll(() {
    final File file = File('jpeg.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}

Future<Uint8List> download(String url) async {
  final HttpClient client = HttpClient();
  final HttpClientRequest request = await client.getUrl(Uri.parse(url));
  final HttpClientResponse response = await request.close();
  final BytesBuilder builder = await response.fold(
      BytesBuilder(), (BytesBuilder b, List<int> d) => b..add(d));
  final List<int> data = builder.takeBytes();
  return Uint8List.fromList(data);
}

const String jpegImage =
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAEMuMjoyKkM6NjpLR0NPZKZsZFxcZMySmnmm8dT++u3U6eX//////////+Xp////////////////////////////2wBDAUdLS2RXZMRsbMT//+n/////////////////////////////////////////////////////////////////////wAARCAAUAAgDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAP/xAAbEAACAwEBAQAAAAAAAAAAAAABAgARIQMEQf/EABQBAQAAAAAAAAAAAAAAAAAAAAD/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCvm5joGZi1hj9iPIgIZ7Nhzl5EC3FAikC9N7ERA//Z';

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

// ignore_for_file: omit_local_variable_types

import 'dart:convert';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

import 'utils.dart';

Document pdf;
PdfImage image;

void main() {
  setUpAll(() async {
    Document.debug = true;
    pdf = Document();

    image = PdfImage.jpeg(
      pdf.document,
      image: await download('https://www.nfet.net/nfet.jpg'),
    );
  });

  test('Pdf Jpeg Download', () async {
    pdf.addPage(Page(
      build: (Context context) => Center(child: Image(image)),
    ));
  });

  test('Pdf Jpeg Orientations', () {
    pdf.addPage(
      Page(
        build: (Context context) => GridView(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          children: List<Widget>.generate(
            images.length,
            (int index) => Image(
              PdfImage.jpeg(
                pdf.document,
                image: base64.decode(images[index]),
              ),
            ),
          ),
        ),
      ),
    );
  });

  test('Pdf Image fit', () async {
    pdf.addPage(
      MultiPage(
        build: (Context context) =>
            List<Widget>.generate(BoxFit.values.length, (int index) {
          final BoxFit fit = BoxFit.values[index];
          return SizedBox(
            width: 200,
            height: 100,
            child: Image(
              image,
              fit: fit,
            ),
          );
        }),
      ),
    );
  });

  test('Pdf Image decode', () {
    final Iterable<Widget> imageWidgets = imageFiles.map<Widget>(
      (String image) => SizedBox(
        child: Image(
          PdfImage.file(
            pdf.document,
            bytes: gzip.decode(base64.decode(image)),
          ),
        ),
        width: 200,
        height: 200,
      ),
    );

    pdf.addPage(
      Page(
        build: (Context context) => Center(
          child: Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.spaceEvenly,
            children: imageWidgets.toList(),
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

const List<String> images = <String>[
  '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',
];

const List<String> imageFiles = <String>[
  'H4sIAKx0cl4AA/t/4/8DBgEvN083BkZGRgYPIGT4f5vBmeE/pQBoCCPFhhxgEORgUGQwYmZUYmASZGQWZPx/hEEM7FQUwMgEFBcVQBdmEAQJY6hmAJkiIoguyvD/FgMPMyPQImZBBnuGVU0LGLS1GpoaVqiyCi1lm8gY4iDK4MAYwMDA/v8mAIKohPQ4AQAA',
  'H4sIAAV2cl4AA+sM8HPn5ZLiYmBg4PX0cAkC0kZArMjBBCRF5PMvAylTTxfHkIjDb88ZMjIYcDAoxP5XM9vcsvrBS0bOEy+7quPmLFmKDrZ+Yjx0ienafeXk7UADGDxd/VzWOSU0AQCMWbgebgAAAA==',
  'H4sIAFZ2cl4AA3P3dLMwTzRiUGRoYGDIXCUJRDoMQAASYWBSb+lfefot/+I5W251b7635zd/2yOPac86l706te0d9/FPPte/9T7/de41K4M1ANAWLyFIAAAA'
];

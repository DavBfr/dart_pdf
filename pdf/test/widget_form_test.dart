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

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

late Document pdf;

class Label extends StatelessWidget {
  Label({this.label, this.width});

  final String? label;

  final double? width;

  @override
  Widget build(Context? context) {
    return Container(
      child: Text(label!),
      width: width,
      alignment: Alignment.centerRight,
      margin: const EdgeInsets.only(right: 5),
    );
  }
}

class Decorated extends StatelessWidget {
  Decorated({this.child, this.color});

  final Widget? child;

  final PdfColor? color;

  @override
  Widget build(Context? context) {
    return Container(
      child: child,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color ?? PdfColors.yellow100,
        border: Border.all(color: PdfColors.grey, width: .5),
      ),
    );
  }
}

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();
  });

  test('Form', () {
    pdf.addPage(
      Page(
        build: (Context context) => Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Label(label: 'Given Name:', width: 100),
            Decorated(
              child: TextField(
                name: 'Given Name',
                value: 'David',
                textStyle: const TextStyle(color: PdfColors.amber),
              ),
            ),
            //
            SizedBox(width: double.infinity, height: 10),
            //
            Label(label: 'Family Name:', width: 100),
            Decorated(
              child: TextField(name: 'Family Name', value: 'PHAM-VAN'),
            ),
            //
            SizedBox(width: double.infinity, height: 10),
            //
            Label(label: 'Address:', width: 100),
            Decorated(child: TextField(name: 'Address')),
            //
            SizedBox(width: double.infinity, height: 10),
            Label(label: 'ChoiceField:', width: 100),
            Decorated(
              child: ChoiceField(
                name: 'Test Choice',
                items: ['One', 'Two', 'Blue', 'Yellow', 'Test äöüß'],
              ),
            ),
            //
            SizedBox(width: double.infinity, height: 10),
            //
            Label(label: 'Postcode:', width: 100),
            Decorated(
              child: TextField(name: 'Postcode', width: 60, maxLength: 6),
            ),
            //
            Label(label: 'City:', width: 30),
            Decorated(child: TextField(name: 'City')),
            //
            SizedBox(width: double.infinity, height: 10),
            //
            Label(label: 'Country:', width: 100),
            Decorated(
              child: TextField(name: 'Country', color: PdfColors.blue),
            ),

            //
            SizedBox(width: double.infinity, height: 10),
            //
            Label(label: 'Checkbox:', width: 100),
            Checkbox(name: 'Checkbox', value: true),
            //
            SizedBox(width: 20, height: 10),
            //
            Label(label: 'unchecked:', width: 100),
            Checkbox(name: 'Unchecked', value: false),
            //
            SizedBox(width: double.infinity, height: 10),
            //
            Transform.rotateBox(
              angle: .7,
              child: FlatButton(name: 'submit', child: Text('Submit')),
            ),
          ],
        ),
      ),
    );
  });

  test('form widgets keep their appearance out of the page content', () async {
    // Why the Windows and Linux backends need a pdfium form-fill environment:
    // these widgets emit /Subtype /Widget annotations carrying an /AP stream,
    // and paint nothing into the page's own content stream. FPDF_RenderPage and
    // FPDF_RenderPageBitmap draw every annotation except widget and popup ones,
    // so without FPDF_FFLDraw or a prior FPDFPage_Flatten they are simply
    // missing from the output.
    // Uncompressed, so the object dictionaries are readable here.
    final document = Document(compress: false);
    document.addPage(
      Page(
        build: (Context context) => Column(
          children: <Widget>[
            Checkbox(name: 'checked', value: true),
            TextField(name: 'given', value: 'hello'),
            FlatButton(name: 'submit', child: Text('Submit')),
          ],
        ),
      ),
    );

    final bytes = await document.save();
    final source = String.fromCharCodes(bytes);

    expect(
      RegExp('/Subtype/Widget').allMatches(source).length,
      3,
      reason: 'one annotation per field',
    );
    expect(
      RegExp('/AP<<').allMatches(source).length,
      3,
      reason: 'each carries its appearance in a stream of its own',
    );
    // The text field's value lives only in that appearance stream.
    expect(source, contains('/V(hello)'));
  });

  tearDownAll(() async {
    final file = File('widgets-form.pdf');
    await file.writeAsBytes(await pdf.save());
  });
  test('every appearance /BBox has its corners the right way round', () async {
    final pdf = Document(compress: false);
    pdf.addPage(
      Page(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => Column(
          children: <Widget>[
            TextField(name: 'text', width: 200, height: 20),
            Checkbox(name: 'check', value: true),
            FlatButton(child: Text('press'), name: 'button'),
          ],
        ),
      ),
    );

    final bytes = String.fromCharCodes(await pdf.save());
    final boxes = RegExp(r'/BBox\[([^\]]*)\]').allMatches(bytes);
    expect(boxes, isNotEmpty);

    for (final box in boxes) {
      final numbers = box.group(1)!.split(' ').map(double.parse).toList();
      expect(numbers, hasLength(4));
      expect(numbers[2], greaterThanOrEqualTo(numbers[0]));
      expect(numbers[3], greaterThanOrEqualTo(numbers[1]));
    }
  });
}

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

import 'package:test/test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

Document pdf;

class Label extends StatelessWidget {
  Label({this.label, this.width});

  final String label;

  final double width;

  @override
  Widget build(Context context) {
    return Container(
      child: Text(label),
      width: width,
      alignment: Alignment.centerRight,
      margin: const EdgeInsets.only(right: 5),
    );
  }
}

class Decorated extends StatelessWidget {
  Decorated({this.child, this.color});

  final Widget child;

  final PdfColor color;

  @override
  Widget build(Context context) {
    return Container(
      child: child,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color ?? PdfColors.yellow100,
        border: Border.all(
          color: PdfColors.grey,
          width: .5,
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() {
    // Document.debug = true;
    pdf = Document();
  });

  test(
    'Form',
    () {
      pdf.addPage(
        Page(
          build: (Context context) => Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Label(label: 'Given Name:', width: 100),
              Decorated(
                  child: TextField(
                name: 'Given Name',
                textStyle: const TextStyle(color: PdfColors.amber),
              )),
              //
              SizedBox(width: double.infinity, height: 10),
              //
              Label(label: 'Family Name:', width: 100),
              Decorated(child: TextField(name: 'Family Name')),
              //
              SizedBox(width: double.infinity, height: 10),
              //
              Label(label: 'Address:', width: 100),
              Decorated(child: TextField(name: 'Address')),
              //
              SizedBox(width: double.infinity, height: 10),
              //
              Label(label: 'Postcode:', width: 100),
              Decorated(
                  child: TextField(name: 'Postcode', width: 60, maxLength: 6)),
              //
              Label(label: 'City:', width: 30),
              Decorated(child: TextField(name: 'City')),
              //
              SizedBox(width: double.infinity, height: 10),
              //
              Label(label: 'Country:', width: 100),
              Decorated(
                  child: TextField(
                name: 'Country',
                color: PdfColors.blue,
              )),
              //
              SizedBox(width: double.infinity, height: 10),
              //
              Label(label: 'Checkbox:', width: 100),
              Checkbox(
                name: 'Checkbox',
                value: true,
                defaultValue: true,
              ),
              //
              SizedBox(width: double.infinity, height: 10),
              //
              Transform.rotateBox(
                angle: .7,
                child: FlatButton(
                  name: 'submit',
                  child: Text('Submit'),
                ),
              )
            ],
          ),
        ),
      );
    },
  );

  tearDownAll(() {
    final file = File('widgets-form.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}

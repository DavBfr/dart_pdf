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

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';

void main() {
  test('Page label', () async {
    final pdf = PdfDocument();

    for (var i = 0; i < 5; i++) {
      PdfPage(pdf);
    }

    pdf.pageLabels.labels[0] = PdfPageLabel('Hello');
    pdf.pageLabels.labels[1] = PdfPageLabel.lettersUpper();
    pdf.pageLabels.labels[3] = PdfPageLabel.romanLower(prefix: 'appendix ');

    expect(pdf.pageLabels.pageLabel(0), 'Hello');
    expect(pdf.pageLabels.pageLabel(1), 'A');
    expect(pdf.pageLabels.pageLabel(2), 'B');
    expect(pdf.pageLabels.pageLabel(3), 'appendix i');
    expect(pdf.pageLabels.pageLabel(4), 'appendix ii');
  });

  test('Roman labels', () async {
    final pdf = PdfDocument();

    for (var i = 0; i < 500; i++) {
      PdfPage(pdf);
    }

    pdf.pageLabels.labels[3] = PdfPageLabel.romanLower();

    expect(pdf.pageLabels.pageLabel(0), '1');
    expect(pdf.pageLabels.pageLabel(300), 'ccxcviii');
    expect(pdf.pageLabels.names.toList()[300], 'ccxcviii');
  });

  test('No of labels', () async {
    final pdf = PdfDocument();

    for (var i = 0; i < 500; i++) {
      PdfPage(pdf);
    }

    expect(pdf.pageLabels.pageLabel(0), '1');
    expect(pdf.pageLabels.pageLabel(300), '301');
    expect(pdf.pageLabels.names.toList()[300], '301');
  });

  test('Letter labels', () async {
    final pdf = PdfDocument();

    for (var i = 0; i < 500; i++) {
      PdfPage(pdf);
    }

    pdf.pageLabels.labels[30] = PdfPageLabel.lettersLower();

    expect(pdf.pageLabels.pageLabel(0), '1');
    expect(pdf.pageLabels.pageLabel(30), 'a');
    expect(pdf.pageLabels.names.toList()[30], 'a');
    expect(pdf.pageLabels.pageLabel(40), 'k');
    expect(pdf.pageLabels.names.toList()[40], 'k');
    expect(pdf.pageLabels.pageLabel(60), 'ee');
    expect(pdf.pageLabels.names.toList()[60], 'ee');
  });
}

import 'dart:io';

import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

late Document pdf;

void main() {
  setUpAll(() {
    Document.debug = true;
    pdf = Document();
  });

  test('Pdf Choice Annotation', () async {
    pdf.addPage(
      Page(
        build: (context) => Column(
          children: [
            TextField(name: 'name'),
            ChoiceField(
              name: 'Test Choice',
              value: 'Value 1',
              items: [
                'Value 2',
                'Value 1',
                'Blue',
                'Yellow',
                'Test äöüß',
              ],
            ),
          ],
        ),
      ),
    );
  });
  tearDownAll(() async {
    final file = File('dropdown.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}

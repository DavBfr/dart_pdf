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
import 'dart:math';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

late Document pdf;

final LoremText lorem = LoremText(random: Random(42));

Iterable<Widget> level(int i) sync* {
  final text = lorem.sentence(5);
  var p = 0;
  PdfColor? color;
  var style = PdfOutlineStyle.normal;

  if (i >= 3 && i <= 6) {
    p++;
  }

  if (i >= 5 && i <= 6) {
    p++;
  }

  if (i == 15) {
    p = 10;
    color = PdfColors.amber;
    style = PdfOutlineStyle.bold;
  }

  if (i == 17) {
    color = PdfColors.red;
    style = PdfOutlineStyle.italic;
  }

  if (i == 18) {
    color = PdfColors.blue;
    style = PdfOutlineStyle.italicBold;
  }

  yield Outline(
    child: Text(text),
    name: 'anchor$i',
    title: text,
    level: p,
    color: color,
    style: style,
  );

  yield SizedBox(height: 300);
}

void main() {
  setUpAll(() {
    Document.debug = true;
    pdf = Document(pageMode: PdfPageMode.outlines);
  });

  test('Outline Widget', () {
    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          for (int i = 0; i < 20; i++) ...level(i),
        ],
      ),
    );
  });

  group('Levels', () {
    test('Well-formed', () {
      final generated = _OutlineBuilder()
          .add('Part 1', 0)
          .add('Chapter 1', 1)
          .add('Paragraph 1.1', 2)
          .add('Paragraph 1.2', 2)
          .add('Paragraph 1.3', 2)
          .add('Chapter 2', 1)
          .add('Paragraph 2.1', 2)
          .add('Paragraph 2.2', 2)
          .render()
          .join('\n');
      const expected = '''null
  Part 1
    Chapter 1
      Paragraph 1.1
      Paragraph 1.2
      Paragraph 1.3
    Chapter 2
      Paragraph 2.1
      Paragraph 2.2''';

      expect(generated, expected);
    });

    test('Does not start with level 0', () {
      final generated = _OutlineBuilder()
          .add('Part 1', 1)
          .add('Chapter 1', 2)
          .add('Chapter 2', 2)
          .render()
          .join('\n');
      const expected = '''null
  Part 1
    Chapter 1
    Chapter 2''';

      expect(generated, expected);
    });

    test('Contains non-sequential level increment', () {
      final generated = _OutlineBuilder()
          .add('Part 1', 0)
          .add('Chapter 1', 2)
          .add('Paragraph 1.1', 4)
          .add('Paragraph 1.2', 4)
          .add('Paragraph 1.3', 4)
          .add('Chapter 2', 2)
          .add('Paragraph 2.1', 4)
          .add('Paragraph 2.2', 4)
          .render()
          .join('\n');

      const expected = '''null
  Part 1
    Chapter 1
      Paragraph 1.1
      Paragraph 1.2
      Paragraph 1.3
    Chapter 2
      Paragraph 2.1
      Paragraph 2.2''';

      expect(generated, expected);
    });

    test('Reverse leveling', () {
      final generated = _OutlineBuilder()
          .add('Paragraph 2.2', 2)
          .add('Paragraph 2.1', 2)
          .add('Chapter 2', 1)
          .add('Paragraph 1.3', 2)
          .add('Paragraph 1.2', 2)
          .add('Paragraph 1.1', 2)
          .add('Chapter 1', 1)
          .add('Part 1', 0)
          .render()
          .join('\n');

      const expected = '''null
  Paragraph 2.2
  Paragraph 2.1
  Chapter 2
    Paragraph 1.3
    Paragraph 1.2
    Paragraph 1.1
  Chapter 1
  Part 1''';

      expect(generated, expected);
    });
  });

  tearDownAll(() async {
    final file = File('widgets-outline.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}

class _OutlineBuilder {
  final List<String> _titles = <String>[];
  final List<int> _levels = <int>[];

  _OutlineBuilder add(String text, int level) {
    _titles.add(text);
    _levels.add(level);
    return this;
  }

  List<String> render() {
    final pdf = Document();
    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          for (int i = 0; i < _titles.length; i++)
            Outline(
              name: 'anchor$i',
              title: _titles[i],
              level: _levels[i],
            )
        ],
      ),
    );
    return _collectOutlines(pdf.document.catalog.outlines!);
  }
}

List<String> _collectOutlines(
  PdfOutline outline, [
  List<String>? output,
  int indent = 0,
]) {
  final result = output ?? <String>[];
  final intentation = List.filled(indent, '  ').join();
  result.add('$intentation${outline.title}');
  for (var child in outline.outlines) {
    _collectOutlines(child, result, indent + 1);
  }
  return result;
}

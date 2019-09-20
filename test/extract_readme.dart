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

import 'package:markdown/markdown.dart' as md;

Iterable<String> getCode(List<md.Node> nodes, [bool isCode = false]) sync* {
  if (nodes == null) {
    return;
  }

  for (md.Node node in nodes) {
    if (node is md.Element) {
      // print(node.tag);
      // print(node.attributes);
      yield* getCode(node.children,
          node.tag == 'code' && node.attributes['class'] == 'language-dart');
    } else if (node is md.Text) {
      if (isCode) {
        yield '// ------------';
        yield node.text;
      }
    } else {
      print(node);
    }
  }
}

void main() {
  final md.Document document = md.Document(
    extensionSet: md.ExtensionSet.commonMark,
    encodeHtml: false,
  );

  final output = File('readme.dart');
  final st = output.openWrite();
  st.writeln('import \'dart:io\';');
  st.writeln('import \'dart:typed_data\';');
  st.writeln('import \'package:pdf/pdf.dart\';');
  st.writeln('import \'package:pdf/widgets.dart\';');
  st.writeln('import \'package:image/image.dart\' show decodeImage;');
  st.writeln('import \'package:printing/printing.dart\';');
  st.writeln('import \'package:flutter/services.dart\' show rootBundle;');
  st.writeln('import \'package:flutter/widgets.dart\' show AssetImage;');
  st.writeln('import \'package:path_provider/path_provider.dart\';');

  {
    final data = File('../pdf/README.md').readAsStringSync();
    final List<String> lines = data.replaceAll('\r\n', '\n').split('\n');
    final List<md.Node> parsedLines = document.parseLines(lines);
    final Iterable<String> code = getCode(parsedLines);

    st.writeln('Future pdfReadme() async {');
    st.writeln(code.join('\n'));
    st.writeln('}');
  }
  {
    final data = File('../printing/README.md').readAsStringSync();
    final List<String> lines = data.replaceAll('\r\n', '\n').split('\n');
    final List<md.Node> parsedLines = document.parseLines(lines);
    final Iterable<String> code = getCode(parsedLines);

    st.writeln('Future printingReadme() async {');
    st.writeln(code.join('\n'));
    st.writeln('}');
  }
  st.writeln('Future main() async {');
  st.writeln('await pdfReadme();');
  st.writeln('await printingReadme();');
  st.writeln('}');
  st.close();
}

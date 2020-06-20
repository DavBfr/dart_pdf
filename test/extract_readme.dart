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
      if (isCode && !node.text.startsWith('import')) {
        yield '// ------------';
        yield node.text;
      }
    } else {
      print(node);
    }
  }
}

void buildFile(String src, String dest, bool flutter) {
  final md.Document document = md.Document(
    extensionSet: md.ExtensionSet.commonMark,
    encodeHtml: false,
  );

  final output = File(dest);
  final st = output.openWrite();
  st.writeln('import \'dart:io\';');
  if (flutter) {
    st.writeln('import \'package:flutter/services.dart\' show rootBundle;');
    st.writeln('import \'package:flutter/widgets.dart\' show AssetImage;');
    st.writeln('import \'package:path_provider/path_provider.dart\';');
    st.writeln('import \'package:printing/printing.dart\';');
  } else {
    st.writeln('import \'dart:typed_data\';');
  }
  st.writeln('import \'package:pdf/pdf.dart\';');
  st.writeln('import \'package:pdf/widgets.dart\' as pw;');

  final data = File(src).readAsStringSync();
  final List<String> lines = data.replaceAll('\r\n', '\n').split('\n');
  final List<md.Node> parsedLines = document.parseLines(lines);
  final Iterable<String> code = getCode(parsedLines);

  st.writeln('Future main() async {');
  st.writeln(code.join('\n'));
  st.writeln('}');
  st.close();
}

void main() {
  buildFile('../pdf/README.md', 'readme-pdf.dart', false);
  buildFile('../printing/README.md', 'readme-printing.dart', true);
}

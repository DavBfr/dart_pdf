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

import 'dart:convert';
import 'dart:io';

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

String _uncapitalize(String s) {
  if (s.isEmpty) return s;
  return '${s[0].toLowerCase()}${s.substring(1)}';
}

void main(List<String> args) async {
  final f = File('fonts.json');
  final d = StringBuffer();

  if (f.existsSync()) {
    d.write(await f.readAsString());
  } else {
    final key = args[0];
    final http = HttpClient();
    print('Downloading...');
    final q = await http.getUrl(Uri.parse(
        'https://content-webfonts.googleapis.com/v1/webfonts?key=$key'));
    final r = await q.close();

    await for (final c in r.transform(utf8.decoder)) {
      d.write(c);
    }

    await f.writeAsString(d.toString());
  }

  print('Converting...');
  final Map m = json.decode(d.toString());

  final file = File('../printing/lib/src/fonts/gfonts.dart');
  final output = await file.openWrite();

  output.writeln('/*');
  output.writeln(
      ' * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>');
  output.writeln(' *');
  output.writeln(
      ' * Licensed under the Apache License, Version 2.0 (the "License");');
  output.writeln(
      ' * you may not use this file except in compliance with the License.');
  output.writeln(' * You may obtain a copy of the License at');
  output.writeln(' *');
  output.writeln(' *     http://www.apache.org/licenses/LICENSE-2.0');
  output.writeln(' *');
  output.writeln(
      ' * Unless required by applicable law or agreed to in writing, software');
  output.writeln(
      ' * distributed under the License is distributed on an "AS IS" BASIS,');
  output.writeln(
      ' * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.');
  output.writeln(
      ' * See the License for the specific language governing permissions and');
  output.writeln(' * limitations under the License.');
  output.writeln(' */');
  output.writeln('');
  output.writeln('// Generated file');
  output.writeln('');
  output.writeln('import \'package:pdf/widgets.dart\';');
  output.writeln('');
  output.writeln('import \'font.dart\';');
  output.writeln('');
  output.writeln('/// Google Fonts');
  output.writeln('class PdfGoogleFonts extends DownloadbleFont {');
  output.writeln('');
  output.writeln('/// Create a Google Font');
  output.writeln(
      'const PdfGoogleFonts._(String url, String name) : super(url, name);');

  for (final f in m['items']) {
    final family = _uncapitalize(f['family'].replaceAll(' ', ''));

    for (final s in f['files'].entries) {
      var sub = _capitalize(s.key);

      sub = sub.replaceAll('100', 'Thin ');
      sub = sub.replaceAll('200', 'ExtraLight ');
      sub = sub.replaceAll('300', 'Light ');
      sub = sub.replaceAll('400', 'Regular ');
      sub = sub.replaceAll('500', 'Medium ');
      sub = sub.replaceAll('600', 'SemiBold ');
      sub = sub.replaceAll('700', 'Bold ');
      sub = sub.replaceAll('800', 'ExtraBold ');
      sub = sub.replaceAll('900', 'Black ');
      sub = sub.split(' ').map<String>((String e) => _capitalize(e)).join('');

      final name = _capitalize(family) + '-' + sub;

      var uri = Uri.parse(s.value);
      if (uri.isScheme('http')) {
        uri = uri.replace(scheme: 'https');
      }

      output.writeln('');
      output.writeln('/// ${f['family']} ${s.key}');
      output.writeln('static Future<Font> $family$sub() {');
      output.writeln('const font = PdfGoogleFonts._(\'$uri\', \'$name\',);');
      output.writeln('return font.getFont();');
      output.writeln('}');
    }
  }

  for (final entry in <String, String>{
    'MaterialIcons':
        'https://fonts.gstatic.com/s/materialicons/v90/flUhRq6tzZclQEJ-Vdg-IuiaDsNZ.ttf'
  }.entries) {
    output.writeln('');
    output.writeln('/// ${entry.key}');
    output.writeln('static Future<Font> ${_uncapitalize(entry.key)}() {');
    output.writeln(
        'const font = PdfGoogleFonts._(\'${entry.value}\', \'${entry.key}\',);');
    output.writeln('return font.getFont();');
    output.writeln('}');
  }

  output.writeln('}');

  await output.close();

  await Process.run('dart', ['format', '--fix', file.absolute.path]);
  print('Done');
}

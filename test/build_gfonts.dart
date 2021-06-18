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

  final output =
      await File('../printing/lib/src/fonts/gfonts.dart').openWrite();

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

      output.writeln('');
      output.writeln('/// ${f['family']} ${s.key}');
      output.writeln('static Future<Font> $family$sub() {');
      output.writeln(
          'const font = PdfGoogleFonts._(\'${s.value}\', \'$name\',);');
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
  print('Done');
}

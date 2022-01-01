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

import 'package:pdf/widgets.dart';

import 'fonts/gfonts.dart';
import 'printing.dart';

Future<TtfFont?> _getFont(Set<String> fonts, List<String> names) async {
  for (final name in names) {
    try {
      final filename = fonts.firstWhere((e) => e.contains(name));
      // print('Found $filename for $name');
      final data = (await File(filename).readAsBytes()).buffer.asByteData();
      return TtfFont(data);
    } catch (_) {}
  }
}

Future<void> pdfDefaultTheme() async {
  if (ThemeData.buildThemeData != null) {
    return;
  }

  final fonts = await Printing.systemFonts();

  final base = (await _getFont(fonts, ['Lato-Regular', 'Roboto-Regular'])) ??
      await PdfGoogleFonts.latoRegular();

  final bold =
      (await _getFont(fonts, ['Lato-Bold'])) ?? await PdfGoogleFonts.latoBold();

  final italic = (await _getFont(fonts, ['Lato-Italic'])) ??
      await PdfGoogleFonts.latoItalic();

  final boldItalic = (await _getFont(fonts, ['Lato-BoldItalic'])) ??
      await PdfGoogleFonts.latoBoldItalic();

  final emoji = (await _getFont(fonts, ['NotoColorEmoji.'])) ??
      await PdfGoogleFonts.notoColorEmoji();

  final icons = await PdfGoogleFonts.materialIcons();

  ThemeData.buildThemeData = () {
    return ThemeData.withFont(
      base: base,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
      icons: icons,
      fontFallback: [emoji, base],
    );
  };
}

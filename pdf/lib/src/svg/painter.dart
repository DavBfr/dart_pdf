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

import '../../pdf.dart';
import '../widgets/font.dart';
import 'brush.dart';
import 'color.dart';
import 'group.dart';
import 'parser.dart';

class SvgPainter {
  SvgPainter(
    this.parser,
    this._canvas,
    this.document,
    this.boundingBox,
    Map<String, Font>? fonts,
  ) : fonts = fonts?.map((key, value) => MapEntry(_cleanFontName(key), value));

  final SvgParser parser;

  final PdfGraphics? _canvas;

  final PdfDocument document;

  final PdfRect boundingBox;

  final Map<String, Font>? fonts;

  void paint() {
    final brush = parser.colorFilter == null
        ? SvgBrush.defaultContext
        : SvgBrush.defaultContext
            .copyWith(fill: SvgColor(color: parser.colorFilter));

    SvgGroup.fromXml(parser.root, this, brush).paint(_canvas!);
  }

  final _fontCache = <String, Font>{};

  Font? getFontCache(String fontFamily, String fontStyle, String fontWeight) {
    final cache = '$fontFamily-$fontStyle-$fontWeight';

    if (!_fontCache.containsKey(cache)) {
      _fontCache[cache] = getFont(fontFamily, fontStyle, fontWeight);
    }

    return _fontCache[cache];
  }

  static String _cleanFontName(String fontName) =>
      fontName.toLowerCase().replaceAll(RegExp(r'''("|'|\s)'''), '');

  Font getFont(String fontFamily, String fontStyle, String fontWeight) {
    final localFonts = fonts;
    if (localFonts != null) {
      // We perform a lose matching because quotes are not always present in the fontFamily
      final cleanFontFamily = _cleanFontName(fontFamily);
      final fontKeys = localFonts.keys
          .where((key) => key.toLowerCase() == cleanFontFamily.toLowerCase());
      if (fontKeys.isNotEmpty) {
        return localFonts[fontKeys.first]!;
      }
    }

    switch (fontFamily) {
      case 'serif':
        switch (fontStyle) {
          case 'normal':
            switch (fontWeight) {
              case 'normal':
              case 'lighter':
                return Font.times();
            }
            return Font.timesBold();
        }
        switch (fontWeight) {
          case 'normal':
          case 'lighter':
            return Font.timesItalic();
        }
        return Font.timesBoldItalic();

      case 'monospace':
        switch (fontStyle) {
          case 'normal':
            switch (fontWeight) {
              case 'normal':
              case 'lighter':
                return Font.courier();
            }
            return Font.courierBold();
        }
        switch (fontWeight) {
          case 'normal':
          case 'lighter':
            return Font.courierOblique();
        }
        return Font.courierBoldOblique();
    }

    switch (fontStyle) {
      case 'normal':
        switch (fontWeight) {
          case 'normal':
          case 'lighter':
            return Font.helvetica();
        }
        return Font.helveticaBold();
    }
    switch (fontWeight) {
      case 'normal':
      case 'lighter':
        return Font.helveticaOblique();
    }
    return Font.helveticaBoldOblique();
  }
}

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

import 'package:pdf/widgets.dart';

import 'src/fonts/gfonts.dart';

export 'src/asset_utils.dart';
export 'src/cache.dart';
export 'src/callback.dart';
export 'src/fonts/gfonts.dart';
export 'src/preview/actions.dart';
export 'src/preview/pdf_preview.dart';
export 'src/printer.dart';
export 'src/printing.dart';
export 'src/printing_info.dart';
export 'src/raster.dart';
export 'src/widget_wrapper.dart';

Future<void> pdfDefaultTheme() async {
  if (ThemeData.buildThemeData != null) {
    return;
  }

  final base = await PdfGoogleFonts.openSansRegular();
  final bold = await PdfGoogleFonts.openSansBold();
  final italic = await PdfGoogleFonts.openSansItalic();
  final boldItalic = await PdfGoogleFonts.openSansBoldItalic();
  final emoji = await PdfGoogleFonts.notoColorEmoji();
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

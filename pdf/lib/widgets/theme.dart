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

part of widget;

class Theme extends Inherited {
  Theme(this.document);

  final PdfDocument document;

  static Theme of(Context context) {
    return context.inherited[Theme];
  }

  TextStyle _defaultTextStyle;

  TextStyle get defaultTextStyle {
    _defaultTextStyle ??= TextStyle(font: PdfFont.helvetica(document));
    return _defaultTextStyle;
  }

  TextStyle _defaultTextStyleBold;

  TextStyle get defaultTextStyleBold {
    _defaultTextStyleBold ??=
        defaultTextStyle.copyWith(font: PdfFont.helveticaBold(document));
    return _defaultTextStyleBold;
  }

  TextStyle _paragraphStyle;

  TextStyle get paragraphStyle {
    _paragraphStyle ??= defaultTextStyle.copyWith(lineSpacing: 5.0);
    return _paragraphStyle;
  }

  TextStyle _bulletStyle;

  TextStyle get bulletStyle {
    _bulletStyle ??= defaultTextStyle.copyWith(lineSpacing: 5.0);
    return _bulletStyle;
  }

  TextStyle _tableHeader;

  TextStyle get tableHeader {
    _tableHeader ??= defaultTextStyleBold;
    return _tableHeader;
  }

  TextStyle _tableCell;

  TextStyle get tableCell {
    _tableCell ??= defaultTextStyle;
    return _tableCell;
  }
}

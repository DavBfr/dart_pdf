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
  final PdfDocument document;

  Theme(this.document);

  static Theme of(Context context) {
    return context.inherited[Theme];
  }

  TextStyle _defaultTextStyle;

  TextStyle get defaultTextStyle {
    if (_defaultTextStyle == null) {
      _defaultTextStyle = TextStyle(font: PdfFont.helvetica(document));
    }
    return _defaultTextStyle;
  }

  TextStyle _defaultTextStyleBold;

  TextStyle get defaultTextStyleBold {
    if (_defaultTextStyleBold == null) {
      _defaultTextStyleBold =
          defaultTextStyle.copyWith(font: PdfFont.helveticaBold(document));
    }
    return _defaultTextStyleBold;
  }

  TextStyle _paragraphStyle;

  TextStyle get paragraphStyle {
    if (_paragraphStyle == null) {
      _paragraphStyle = defaultTextStyle.copyWith(lineSpacing: 5.0);
    }
    return _paragraphStyle;
  }

  TextStyle _bulletStyle;

  TextStyle get bulletStyle {
    if (_bulletStyle == null) {
      _bulletStyle = defaultTextStyle.copyWith(lineSpacing: 5.0);
    }
    return _bulletStyle;
  }

  TextStyle _tableHeader;

  TextStyle get tableHeader {
    if (_tableHeader == null) {
      _tableHeader = defaultTextStyleBold;
    }
    return _tableHeader;
  }

  TextStyle _tableCell;

  TextStyle get tableCell {
    if (_tableCell == null) {
      _tableCell = defaultTextStyle;
    }
    return _tableCell;
  }
}

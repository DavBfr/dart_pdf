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

@immutable
class Theme extends Inherited {
  factory Theme({
    TextStyle defaultTextStyle,
    TextStyle paragraphStyle,
    TextStyle header0,
    TextStyle header1,
    TextStyle header2,
    TextStyle header3,
    TextStyle header4,
    TextStyle header5,
    TextStyle bulletStyle,
    TextStyle tableHeader,
    TextStyle tableCell,
  }) {
    final Theme base = Theme.base();
    return base.copyWith(
      defaultTextStyle: defaultTextStyle,
      paragraphStyle: paragraphStyle,
      bulletStyle: bulletStyle,
      header0: header0,
      header1: header1,
      header2: header2,
      header3: header3,
      header4: header4,
      header5: header5,
      tableHeader: tableHeader,
      tableCell: tableCell,
    );
  }

  Theme._({
    @required this.defaultTextStyle,
    @required this.paragraphStyle,
    @required this.header0,
    @required this.header1,
    @required this.header2,
    @required this.header3,
    @required this.header4,
    @required this.header5,
    @required this.bulletStyle,
    @required this.tableHeader,
    @required this.tableCell,
  })  : assert(defaultTextStyle.inherit == false),
        assert(paragraphStyle.inherit == false),
        assert(header0.inherit == false),
        assert(header1.inherit == false),
        assert(header2.inherit == false),
        assert(header3.inherit == false),
        assert(header4.inherit == false),
        assert(header5.inherit == false),
        assert(bulletStyle.inherit == false),
        assert(tableHeader.inherit == false),
        assert(tableCell.inherit == false);

  factory Theme.withFont({Font base, Font bold, Font italic, Font boldItalic}) {
    final TextStyle defaultStyle = TextStyle.defaultStyle().copyWith(
        font: base,
        fontNormal: base,
        fontBold: bold,
        fontItalic: italic,
        fontBoldItalic: boldItalic);
    final double fontSize = defaultStyle.fontSize;

    return Theme._(
      defaultTextStyle: defaultStyle,
      paragraphStyle: defaultStyle.copyWith(lineSpacing: 5),
      bulletStyle: defaultStyle.copyWith(lineSpacing: 5),
      header0: defaultStyle.copyWith(fontSize: fontSize * 2.0),
      header1: defaultStyle.copyWith(fontSize: fontSize * 1.5),
      header2: defaultStyle.copyWith(fontSize: fontSize * 1.4),
      header3: defaultStyle.copyWith(fontSize: fontSize * 1.3),
      header4: defaultStyle.copyWith(fontSize: fontSize * 1.2),
      header5: defaultStyle.copyWith(fontSize: fontSize * 1.1),
      tableHeader: defaultStyle.copyWith(
          fontSize: fontSize * 0.8, fontWeight: FontWeight.bold),
      tableCell: defaultStyle.copyWith(fontSize: fontSize * 0.8),
    );
  }

  factory Theme.base() => Theme.withFont();

  Theme copyWith({
    TextStyle defaultTextStyle,
    TextStyle paragraphStyle,
    TextStyle header0,
    TextStyle header1,
    TextStyle header2,
    TextStyle header3,
    TextStyle header4,
    TextStyle header5,
    TextStyle bulletStyle,
    TextStyle tableHeader,
    TextStyle tableCell,
  }) =>
      Theme._(
        defaultTextStyle: this.defaultTextStyle.merge(defaultTextStyle),
        paragraphStyle: this.paragraphStyle.merge(paragraphStyle),
        bulletStyle: this.bulletStyle.merge(bulletStyle),
        header0: this.header0.merge(header0),
        header1: this.header1.merge(header1),
        header2: this.header2.merge(header2),
        header3: this.header3.merge(header3),
        header4: this.header4.merge(header4),
        header5: this.header5.merge(header5),
        tableHeader: this.tableHeader.merge(tableHeader),
        tableCell: this.tableCell.merge(tableCell),
      );

  static Theme of(Context context) {
    return context.inherited[Theme];
  }

  final TextStyle defaultTextStyle;

  final TextStyle paragraphStyle;

  final TextStyle header0;
  final TextStyle header1;
  final TextStyle header2;
  final TextStyle header3;
  final TextStyle header4;
  final TextStyle header5;

  final TextStyle bulletStyle;

  final TextStyle tableHeader;

  final TextStyle tableCell;
}

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

class Header extends StatelessWidget {
  Header(
      {this.level = 1,
      this.text,
      this.child,
      this.decoration,
      this.margin,
      this.padding,
      this.textStyle})
      : assert(level >= 0 && level <= 5);

  final String text;

  final Widget child;

  final int level;

  final BoxDecoration decoration;

  final EdgeInsets margin;

  final EdgeInsets padding;

  final TextStyle textStyle;

  @override
  Widget build(Context context) {
    BoxDecoration _decoration = decoration;
    EdgeInsets _margin = margin;
    EdgeInsets _padding = padding;
    TextStyle _textStyle = textStyle;
    switch (level) {
      case 0:
        _margin ??= const EdgeInsets.only(bottom: 5.0 * PdfPageFormat.mm);
        _padding ??= const EdgeInsets.only(bottom: 1.0 * PdfPageFormat.mm);
        _decoration ??=
            const BoxDecoration(border: BoxBorder(bottom: true, width: 1));
        _textStyle ??= Theme.of(context).header0;
        break;
      case 1:
        _margin ??= const EdgeInsets.only(
            top: 3.0 * PdfPageFormat.mm, bottom: 5.0 * PdfPageFormat.mm);
        _decoration ??=
            const BoxDecoration(border: BoxBorder(bottom: true, width: 0.2));
        _textStyle ??= Theme.of(context).header1;
        break;
      case 2:
        _margin ??= const EdgeInsets.only(
            top: 2.0 * PdfPageFormat.mm, bottom: 4.0 * PdfPageFormat.mm);
        _textStyle ??= Theme.of(context).header2;
        break;
      case 3:
        _margin ??= const EdgeInsets.only(
            top: 2.0 * PdfPageFormat.mm, bottom: 4.0 * PdfPageFormat.mm);
        _textStyle ??= Theme.of(context).header3;
        break;
      case 4:
        _margin ??= const EdgeInsets.only(
            top: 2.0 * PdfPageFormat.mm, bottom: 4.0 * PdfPageFormat.mm);
        _textStyle ??= Theme.of(context).header4;
        break;
      case 5:
        _margin ??= const EdgeInsets.only(
            top: 2.0 * PdfPageFormat.mm, bottom: 4.0 * PdfPageFormat.mm);
        _textStyle ??= Theme.of(context).header5;
        break;
    }
    return Container(
      alignment: Alignment.topLeft,
      margin: _margin,
      padding: _padding,
      decoration: _decoration,
      child: child ?? Text(text, style: _textStyle),
    );
  }
}

class Paragraph extends StatelessWidget {
  Paragraph(
      {this.text,
      this.textAlign = TextAlign.justify,
      this.style,
      this.margin = const EdgeInsets.only(bottom: 5.0 * PdfPageFormat.mm),
      this.padding});

  final String text;

  final TextAlign textAlign;

  final TextStyle style;

  final EdgeInsets margin;

  final EdgeInsets padding;

  @override
  Widget build(Context context) {
    return Container(
      margin: margin,
      padding: padding,
      child: Text(
        text,
        textAlign: textAlign,
        style: style ?? Theme.of(context).paragraphStyle,
      ),
    );
  }
}

class Bullet extends StatelessWidget {
  Bullet(
      {this.text,
      this.textAlign = TextAlign.left,
      this.style,
      this.margin = const EdgeInsets.only(bottom: 2.0 * PdfPageFormat.mm),
      this.padding,
      this.bulletSize = 2.0 * PdfPageFormat.mm,
      this.bulletMargin = const EdgeInsets.only(
        top: 1.5 * PdfPageFormat.mm,
        left: 5.0 * PdfPageFormat.mm,
        right: 2.0 * PdfPageFormat.mm,
      ),
      this.bulletShape = BoxShape.circle,
      this.bulletColor = PdfColors.black});

  final String text;

  final TextAlign textAlign;

  final TextStyle style;

  final EdgeInsets margin;

  final EdgeInsets padding;

  final EdgeInsets bulletMargin;

  final double bulletSize;

  final BoxShape bulletShape;

  final PdfColor bulletColor;

  @override
  Widget build(Context context) {
    return Container(
        margin: margin,
        padding: padding,
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: bulletSize,
                height: bulletSize,
                margin: bulletMargin,
                decoration:
                    BoxDecoration(color: bulletColor, shape: bulletShape),
              ),
              Expanded(
                  child: Text(text,
                      textAlign: textAlign,
                      style: Theme.of(context).bulletStyle))
            ]));
  }
}

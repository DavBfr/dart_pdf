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

import 'dart:math' as math;

import 'package:pdf/pdf.dart';

import 'annotations.dart';
import 'basic.dart';
import 'box_border.dart';
import 'container.dart';
import 'decoration.dart';
import 'flex.dart';
import 'geometry.dart';
import 'multi_page.dart';
import 'text.dart';
import 'text_style.dart';
import 'theme.dart';
import 'widget.dart';

class Header extends StatelessWidget {
  Header({
    this.level = 1,
    this.text,
    this.child,
    this.decoration,
    this.margin,
    this.padding,
    this.textStyle,
    String? title,
    this.outlineColor,
    this.outlineStyle = PdfOutlineStyle.normal,
  })  : assert(level >= 0 && level <= 5),
        assert(child != null || text != null),
        title = title ?? text;

  final String? title;

  final String? text;

  final Widget? child;

  final int level;

  final BoxDecoration? decoration;

  final EdgeInsets? margin;

  final EdgeInsets? padding;

  final TextStyle? textStyle;

  final PdfColor? outlineColor;

  final PdfOutlineStyle outlineStyle;

  @override
  Widget build(Context context) {
    var _decoration = decoration;
    var _margin = margin;
    var _padding = padding;
    var _textStyle = textStyle;
    switch (level) {
      case 0:
        _margin ??= const EdgeInsets.only(bottom: 5.0 * PdfPageFormat.mm);
        _padding ??= const EdgeInsets.only(bottom: 1.0 * PdfPageFormat.mm);
        _decoration ??=
            const BoxDecoration(border: Border(bottom: BorderSide()));
        _textStyle ??= Theme.of(context).header0;
        break;
      case 1:
        _margin ??= const EdgeInsets.only(
            top: 3.0 * PdfPageFormat.mm, bottom: 5.0 * PdfPageFormat.mm);
        _decoration ??=
            const BoxDecoration(border: Border(bottom: BorderSide(width: 0.2)));
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

    final Widget container = Container(
      alignment: Alignment.topLeft,
      margin: _margin,
      padding: _padding,
      decoration: _decoration,
      child: child ?? Text(text!, style: _textStyle),
    );

    if (title == null) {
      return container;
    }

    return Outline(
      name: text.hashCode.toString(),
      title: title!,
      child: container,
      level: level,
      color: outlineColor,
      style: outlineStyle,
    );
  }
}

class TableOfContent extends StatelessWidget {
  Iterable<Widget> _buildToc(PdfOutline o, int l) sync* {
    for (final c in o.outlines) {
      if (c.title != null) {
        yield Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Link(
            destination: c.anchor!,
            child: Row(
              children: [
                SizedBox(width: 10.0 * l),
                Text('${c.title}'),
                SizedBox(width: 8),
                Expanded(
                    child: Divider(
                  borderStyle: BorderStyle.dotted,
                  thickness: 0.2,
                )),
                SizedBox(width: 8),
                Text('${c.page}'),
              ],
            ),
          ),
        );
        yield* _buildToc(c, l + 1);
      }
    }
  }

  @override
  Widget build(Context context) {
    assert(context.page is! MultiPage,
        '$runtimeType will not work with MultiPage');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._buildToc(context.document.outline, 0),
      ],
    );
  }
}

class Paragraph extends StatelessWidget {
  Paragraph({
    this.text,
    this.textAlign = TextAlign.justify,
    this.style,
    this.margin = const EdgeInsets.only(bottom: 5.0 * PdfPageFormat.mm),
    this.padding,
  });

  final String? text;

  final TextAlign textAlign;

  final TextStyle? style;

  final EdgeInsets margin;

  final EdgeInsets? padding;

  @override
  Widget build(Context context) {
    return Container(
      margin: margin,
      padding: padding,
      child: Text(
        text!,
        textAlign: textAlign,
        style: style ?? Theme.of(context).paragraphStyle,
        overflow: TextOverflow.span,
      ),
    );
  }
}

class Bullet extends StatelessWidget {
  Bullet({
    this.text,
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
    this.bulletColor = PdfColors.black,
  });

  final String? text;

  final TextAlign textAlign;

  final TextStyle? style;

  final EdgeInsets margin;

  final EdgeInsets? padding;

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
            decoration: BoxDecoration(color: bulletColor, shape: bulletShape),
          ),
          Expanded(
            child: text == null
                ? SizedBox()
                : Text(
                    text!,
                    textAlign: textAlign,
                    style: Theme.of(context).bulletStyle.merge(style),
                  ),
          )
        ],
      ),
    );
  }
}

class Watermark extends StatelessWidget {
  Watermark({
    required this.child,
    this.fit = BoxFit.contain,
    this.angle = 0,
  });

  Watermark.text(
    String text, {
    TextStyle? style,
    this.fit = BoxFit.contain,
    this.angle = math.pi / 4,
  }) : child = Text(
          text,
          style: style ??
              TextStyle(
                color: PdfColors.grey200,
                fontWeight: FontWeight.bold,
              ),
        );

  final Widget child;

  final double angle;

  final BoxFit fit;

  @override
  Widget build(Context context) {
    return SizedBox.expand(
      child: FittedBox(
        fit: fit,
        child: Transform.rotateBox(
          angle: angle,
          child: child,
        ),
      ),
    );
  }
}

class Footer extends StatelessWidget {
  Footer({
    this.leading,
    this.title,
    this.trailing,
    this.margin,
    this.padding,
    this.decoration,
  });

  final Widget? leading;

  final Widget? title;

  final Widget? trailing;

  final EdgeInsets? margin;

  final EdgeInsets? padding;

  final BoxDecoration? decoration;

  @override
  Widget build(Context context) {
    return Container(
        margin: margin,
        padding: padding,
        decoration: decoration,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            leading ?? SizedBox(),
            title ?? SizedBox(),
            trailing ?? SizedBox(),
          ],
        ));
  }
}

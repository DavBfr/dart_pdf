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

import 'package:pdf/pdf.dart';
import 'package:vector_math/vector_math_64.dart';

import 'geometry.dart';
import 'text_style.dart';
import 'theme.dart';
import 'widget.dart';

class Anchor extends SingleChildWidget {
  Anchor({
    Widget? child,
    required this.name,
    this.description,
    this.zoom,
    this.setX = false,
  }) : super(child: child);

  final String name;

  final String? description;

  final double? zoom;

  final bool setX;

  @override
  void paint(Context context) {
    super.paint(context);
    paintChild(context);

    final mat = context.canvas.getTransform();
    final lt = mat.transform3(Vector3(box!.left, box!.top, 0));
    context.document.pdfNames.addDest(
      name,
      context.page,
      posX: setX ? lt.x : null,
      posY: lt.y,
      posZ: zoom,
    );

    if (description != null) {
      final rb = mat.transform3(Vector3(box!.right, box!.top, 0));
      final ibox = PdfRect.fromLTRB(lt.x, lt.y, rb.x, rb.y);
      PdfAnnot(context.page, PdfAnnotText(rect: ibox, content: description!));
    }
  }
}

abstract class AnnotationBuilder {
  void build(Context context, PdfRect? box);
}

class AnnotationLink extends AnnotationBuilder {
  AnnotationLink(this.destination);

  final String destination;

  @override
  void build(Context context, PdfRect? box) {
    PdfAnnot(
      context.page,
      PdfAnnotNamedLink(
        rect: context.localToGlobal(box!),
        dest: destination,
      ),
    );
  }
}

class AnnotationUrl extends AnnotationBuilder {
  AnnotationUrl(this.destination);

  final String destination;

  @override
  void build(Context context, PdfRect? box) {
    PdfAnnot(
      context.page,
      PdfAnnotUrlLink(
        rect: context.localToGlobal(box!),
        url: destination,
      ),
    );
  }
}

class AnnotationTextField extends AnnotationBuilder {
  AnnotationTextField({
    this.name,
    this.border,
    this.flags,
    this.date,
    this.color,
    this.backgroundColor,
    this.highlighting,
    this.maxLength,
    this.alternateName,
    this.mappingName,
    this.fieldFlags,
    this.value,
    this.defaultValue,
    this.textStyle,
  });

  final String? name;

  final PdfBorder? border;

  final Set<PdfAnnotFlags>? flags;

  final DateTime? date;

  final PdfColor? color;

  final PdfColor? backgroundColor;

  final PdfAnnotHighlighting? highlighting;

  final int? maxLength;

  final String? value;

  final String? defaultValue;

  final TextStyle? textStyle;

  final String? alternateName;

  final String? mappingName;

  final Set<PdfFieldFlags>? fieldFlags;

  @override
  void build(Context context, PdfRect? box) {
    final _textStyle = Theme.of(context).defaultTextStyle.merge(textStyle);

    PdfAnnot(
      context.page,
      PdfTextField(
        rect: context.localToGlobal(box!),
        fieldName: name,
        border: border,
        flags: flags,
        date: date,
        color: color,
        backgroundColor: backgroundColor,
        highlighting: highlighting,
        maxLength: maxLength,
        alternateName: alternateName,
        mappingName: mappingName,
        fieldFlags: fieldFlags,
        value: value,
        defaultValue: defaultValue,
        font: _textStyle.font!.getFont(context)!,
        fontSize: _textStyle.fontSize!,
        textColor: _textStyle.color!,
      ),
    );
  }
}

class Annotation extends SingleChildWidget {
  Annotation({Widget? child, this.builder}) : super(child: child);

  final AnnotationBuilder? builder;

  @override
  void debugPaint(Context context) {
    context.canvas
      ..setFillColor(PdfColors.pink)
      ..drawBox(box!)
      ..fillPath();
  }

  @override
  void paint(Context context) {
    super.paint(context);
    paintChild(context);
    builder?.build(context, box);
  }
}

class Link extends Annotation {
  Link({required Widget child, required String destination})
      : super(child: child, builder: AnnotationLink(destination));
}

class UrlLink extends Annotation {
  UrlLink({
    required Widget child,
    required String destination,
  }) : super(child: child, builder: AnnotationUrl(destination));
}

class Outline extends Anchor {
  Outline({
    Widget? child,
    required String name,
    required this.title,
    this.level = 0,
    this.color,
    this.style = PdfOutlineStyle.normal,
  })  : assert(level >= 0),
        super(child: child, name: name, setX: true);

  final String title;

  final int level;

  final PdfColor? color;

  final PdfOutlineStyle style;

  PdfOutline? _outline;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    super.layout(context, constraints, parentUsesSize: parentUsesSize);
    _buildOutline(context);
  }

  @override
  void debugPaint(Context context) {
    context.canvas
      ..setFillColor(PdfColors.pink100)
      ..drawBox(box!)
      ..fillPath();
  }

  void _buildOutline(Context context) {
    if (_outline != null) {
      return;
    }

    _outline = PdfOutline(
      context.document,
      title: title,
      anchor: name,
      color: color,
      style: style,
      page: context.pageNumber,
    );

    var parent = context.document.outline;
    var l = level;

    while (l > 0) {
      if (parent.effectiveLevel == l) {
        break;
      }

      if (parent.outlines.isEmpty) {
        parent.effectiveLevel = level;
        break;
      }
      parent = parent.outlines.last;
      l--;
    }

    parent.add(_outline!);
  }
}

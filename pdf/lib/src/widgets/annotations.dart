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

import 'dart:math';

import 'package:vector_math/vector_math_64.dart';

import '../../pdf.dart';
import '../pdf/format/indirect.dart';
import 'geometry.dart';
import 'shape.dart';
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
    this.replaces,
  }) : super(child: child);

  final String name;

  final String? description;

  final double? zoom;

  final bool setX;

  final PdfIndirect? replaces;

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
      final iBox = PdfRect.fromLTRB(lt.x, lt.y, rb.x, rb.y);
      PdfAnnot(
        context.page,
        PdfAnnotText(rect: iBox, content: description!),
        objser: replaces?.ser,
        objgen: replaces?.gen ?? 0,
      );
    }
  }
}

abstract class AnnotationBuilder {
  PdfAnnot build(Context context, PdfRect? box);
}

class AnnotationLink extends AnnotationBuilder {
  AnnotationLink(this.destination, {this.replaces});

  final String destination;

  final PdfIndirect? replaces;

  @override
  PdfAnnot build(Context context, PdfRect? box) {
    return PdfAnnot(
      context.page,
      PdfAnnotNamedLink(
        rect: context.localToGlobal(box!),
        dest: destination,
      ),
      objser: replaces?.ser,
      objgen: replaces?.gen ?? 0,
    );
  }
}

class AnnotationUrl extends AnnotationBuilder {
  AnnotationUrl(
    this.destination, {
    this.date,
    this.subject,
    this.author,
    this.replaces,
  });

  final String destination;

  final DateTime? date;

  final String? author;

  final String? subject;

  final PdfIndirect? replaces;

  @override
  PdfAnnot build(Context context, PdfRect? box) {
    return PdfAnnot(
      context.page,
      PdfAnnotUrlLink(
        rect: context.localToGlobal(box!),
        url: destination,
        date: date,
        author: author,
        subject: subject,
      ),
      objser: replaces?.ser,
      objgen: replaces?.gen ?? 0,
    );
  }
}

class AnnotationSquare extends AnnotationBuilder {
  AnnotationSquare({
    this.color,
    this.interiorColor,
    this.border,
    this.author,
    this.date,
    this.subject,
    this.content,
    this.replaces,
  });

  final PdfColor? color;

  final PdfColor? interiorColor;

  final PdfBorder? border;

  final String? author;

  final DateTime? date;

  final String? subject;

  final String? content;

  final PdfIndirect? replaces;

  @override
  PdfAnnot build(Context context, PdfRect? box) {
    return PdfAnnot(
      context.page,
      PdfAnnotSquare(
        rect: context.localToGlobal(box!),
        border: border,
        color: color,
        interiorColor: interiorColor,
        date: date,
        author: author,
        subject: subject,
      ),
      objser: replaces?.ser,
      objgen: replaces?.gen ?? 0,
    );
  }
}

class AnnotationCircle extends AnnotationBuilder {
  AnnotationCircle({
    this.color,
    this.interiorColor,
    this.border,
    this.author,
    this.date,
    this.subject,
    this.content,
    this.replaces,
  });

  final PdfColor? color;

  final PdfColor? interiorColor;

  final PdfBorder? border;

  final String? author;

  final DateTime? date;

  final String? subject;

  final String? content;

  final PdfIndirect? replaces;

  @override
  PdfAnnot build(Context context, PdfRect? box) {
    return PdfAnnot(
      context.page,
      PdfAnnotCircle(
        rect: context.localToGlobal(box!),
        border: border,
        color: color,
        interiorColor: interiorColor,
        date: date,
        author: author,
        subject: subject,
      ),
      objser: replaces?.ser,
      objgen: replaces?.gen ?? 0,
    );
  }
}

class AnnotationPolygon extends AnnotationBuilder {
  AnnotationPolygon(
    this.points, {
    this.color,
    this.interiorColor,
    this.border,
    this.author,
    this.date,
    this.subject,
    this.content,
    this.replaces,
  });

  final List<PdfPoint> points;

  final PdfColor? color;

  final PdfColor? interiorColor;

  final PdfBorder? border;

  final String? author;

  final DateTime? date;

  final String? subject;

  final String? content;

  final PdfIndirect? replaces;

  @override
  PdfAnnot build(Context context, PdfRect? box) {
    final globalPoints =
        points.map((e) => context.localToGlobalPoint(e)).toList();

    final rect = context.localToGlobal(PdfRect(
        points.map((point) => point.x).reduce(min),
        points.map((point) => point.y).reduce(min),
        points.map((point) => point.x).reduce(max) -
            points.map((point) => point.x).reduce(min),
        points.map((point) => point.y).reduce(max) -
            points.map((point) => point.y).reduce(min)));

    final pdfAnnotPolygon = PdfAnnotPolygon(
      context.document,
      globalPoints,
      rect: rect,
      border: border,
      color: color,
      interiorColor: interiorColor,
      date: date,
      author: author,
      subject: subject,
    );

    return PdfAnnot(
      context.page,
      pdfAnnotPolygon,
      objser: replaces?.ser,
      objgen: replaces?.gen ?? 0,
    );
  }
}

class AnnotationInk extends AnnotationBuilder {
  AnnotationInk(
    this.points, {
    this.color,
    this.border,
    this.author,
    this.date,
    this.subject,
    this.content,
    this.replaces,
  });

  final List<List<PdfPoint>> points;

  final PdfColor? color;

  final PdfBorder? border;

  final String? author;

  final DateTime? date;

  final String? subject;

  final String? content;

  final PdfIndirect? replaces;

  @override
  PdfAnnot build(Context context, PdfRect? box) {
    final globalPoints = points
        .map((pList) => pList
            .map((e) => context.localToGlobalPoint(e))
            .toList(growable: false))
        .toList(growable: false);

    final allPoints =
        points.expand((pointList) => pointList).toList(growable: false);

    final minX = allPoints.map((point) => point.x).reduce(min);
    final minY = allPoints.map((point) => point.y).reduce(min);
    final maxX = allPoints.map((point) => point.x).reduce(max);
    final maxY = allPoints.map((point) => point.y).reduce(max);
    final rect =
        context.localToGlobal(PdfRect(minX, minY, maxX - minX, maxY - minY));

    final pdfAnnotInk = PdfAnnotInk(
      context.document,
      globalPoints,
      rect: rect,
      border: border,
      color: color,
      date: date,
      author: author,
      subject: subject,
      content: content,
    );

    return PdfAnnot(
      context.page,
      pdfAnnotInk,
      objser: replaces?.ser,
      objgen: replaces?.gen ?? 0,
    );
  }
}

class AnnotationTextField extends AnnotationBuilder {
  AnnotationTextField({
    this.name,
    this.border,
    this.flags,
    this.date,
    this.subject,
    this.author,
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
    this.replaces,
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

  final String? author;

  final String? subject;

  final PdfIndirect? replaces;

  @override
  PdfAnnot build(Context context, PdfRect? box) {
    final _textStyle = Theme.of(context).defaultTextStyle.merge(textStyle);

    return PdfAnnot(
      context.page,
      PdfTextField(
        rect: context.localToGlobal(box!),
        fieldName: name,
        border: border,
        flags: flags,
        date: date,
        author: author,
        subject: subject,
        color: color,
        backgroundColor: backgroundColor,
        highlighting: highlighting,
        maxLength: maxLength,
        alternateName: alternateName,
        mappingName: mappingName,
        fieldFlags: fieldFlags,
        value: value,
        defaultValue: defaultValue,
        font: _textStyle.font!.getFont(context),
        fontSize: _textStyle.fontSize!,
        textColor: _textStyle.color!,
      ),
      objser: replaces?.ser,
      objgen: replaces?.gen ?? 0,
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

class SquareAnnotation extends Annotation {
  SquareAnnotation({
    Widget? child,
    PdfColor? color,
    PdfColor? interiorColor,
    PdfBorder? border,
    String? author,
    DateTime? date,
    String? subject,
    String? content,
  }) : super(
          child: child ??
              Rectangle(
                  fillColor: interiorColor,
                  strokeWidth: border?.width ?? 1.0,
                  strokeColor: color),
          builder: AnnotationSquare(
            color: color,
            interiorColor: interiorColor,
            border: border,
            author: author,
            date: date,
            content: content,
            subject: subject,
          ),
        );
}

class CircleAnnotation extends Annotation {
  CircleAnnotation({
    Widget? child,
    PdfColor? color,
    PdfColor? interiorColor,
    PdfBorder? border,
    String? author,
    DateTime? date,
    String? subject,
    String? content,
  }) : super(
          child: child ??
              Circle(
                  fillColor: interiorColor,
                  strokeWidth: border?.width ?? 1.0,
                  strokeColor: color),
          builder: AnnotationCircle(
            color: color,
            interiorColor: interiorColor,
            border: border,
            author: author,
            date: date,
            content: content,
            subject: subject,
          ),
        );
}

class PolygonAnnotation extends Annotation {
  PolygonAnnotation({
    required List<PdfPoint> points,
    Widget? child,
    PdfColor? color,
    PdfColor? interiorColor,
    PdfBorder? border,
    String? author,
    DateTime? date,
    String? subject,
    String? content,
  }) : super(
          child: child ??
              Polygon(
                  points: points,
                  strokeColor: color,
                  fillColor: interiorColor,
                  strokeWidth: border?.width ?? 1.0),
          builder: AnnotationPolygon(
            points,
            color: color,
            interiorColor: interiorColor,
            border: border,
            author: author,
            date: date,
            content: content,
            subject: subject,
          ),
        );
}

class PolyLineAnnotation extends Annotation {
  PolyLineAnnotation({
    required List<PdfPoint> points,
    PdfColor? color,
    PdfBorder? border,
    String? author,
    DateTime? date,
    String? content,
    String? subject,
  }) : super(
          child: Polygon(
              points: points,
              strokeColor: color,
              close: false,
              strokeWidth: border?.width ?? 1.0),
          builder: AnnotationPolygon(
            points,
            color: color,
            border: border,
            author: author,
            date: date,
            content: content,
            subject: subject,
          ),
        );
}

class InkAnnotation extends Annotation {
  InkAnnotation({
    required List<List<PdfPoint>> points,
    Widget? child,
    PdfColor? color,
    PdfBorder? border,
    String? author,
    DateTime? date,
    String? content,
    String? subject,
  }) : super(
          child: child ??
              InkList(
                  points: points,
                  strokeColor: color,
                  strokeWidth: border?.width ?? 1.0),
          builder: AnnotationInk(
            points,
            color: color,
            border: border,
            author: author,
            date: date,
            content: content,
            subject: subject,
          ),
        );
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
      page: context.page,
    )..effectiveLevel = level;

    final root = context.document.outline;

    // find the most recently added outline
    var actualLevel = -1;
    var candidate = root;
    while (candidate.outlines.isNotEmpty) {
      candidate = candidate.outlines.last;
      actualLevel++;
    }

    // find the latest added outline with a level lower than ours
    while (candidate != root) {
      final candidateLevel = candidate.effectiveLevel ?? actualLevel;
      if (candidateLevel < level) {
        break;
      }
      candidate = candidate.parent!;
      actualLevel--;
    }

    candidate.add(_outline!);
  }
}

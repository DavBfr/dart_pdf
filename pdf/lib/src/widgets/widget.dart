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

import 'dart:collection';
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:vector_math/vector_math_64.dart';

import 'document.dart';
import 'geometry.dart';
import 'page.dart';
import 'theme.dart';

@immutable
class Context {
  factory Context({
    required PdfDocument document,
    PdfPage? page,
    PdfGraphics? canvas,
  }) =>
      Context._(
        document: document,
        page: page,
        canvas: canvas,
        inherited: HashMap<Type, Inherited>(),
      );

  const Context._({
    required this.document,
    PdfPage? page,
    PdfGraphics? canvas,
    required HashMap<Type, Inherited> inherited,
  })  : _page = page,
        _canvas = canvas,
        _inherited = inherited;

  final PdfPage? _page;

  PdfPage get page => _page!;

  final PdfGraphics? _canvas;

  PdfGraphics get canvas => _canvas!;

  final HashMap<Type, Inherited> _inherited;

  final PdfDocument document;

  int get pageNumber => document.pdfPageList.pages.indexOf(page) + 1;

  /// Number of pages in the document.
  /// This value is not available in a MultiPage body and will be equal to pageNumber.
  /// But can be used in Header and Footer.
  int get pagesCount => document.pdfPageList.pages.length;

  Context copyWith(
      {PdfPage? page,
      PdfGraphics? canvas,
      Matrix4? ctm,
      HashMap<Type, Inherited>? inherited}) {
    return Context._(
        document: document,
        page: page ?? _page,
        canvas: canvas ?? _canvas,
        inherited: inherited ?? _inherited);
  }

  T? dependsOn<T>() {
    return _inherited[T] as T?;
  }

  Context inheritFrom(Inherited object) {
    return inheritFromAll(<Inherited>[object]);
  }

  Context inheritFromAll(Iterable<Inherited> objects) {
    final inherited = HashMap<Type, Inherited>.of(_inherited);
    for (final object in objects) {
      inherited[object.runtimeType] = object;
    }
    return copyWith(inherited: inherited);
  }

  PdfRect localToGlobal(PdfRect box) {
    final mat = canvas.getTransform();
    final lt = mat.transform3(Vector3(box.left, box.bottom, 0));
    final lb = mat.transform3(Vector3(box.left, box.top, 0));
    final rt = mat.transform3(Vector3(box.right, box.bottom, 0));
    final rb = mat.transform3(Vector3(box.right, box.top, 0));
    final x = <double>[lt.x, lb.x, rt.x, rb.x];
    final y = <double>[lt.y, lb.y, rt.y, rb.y];
    return PdfRect.fromLTRB(
      x.reduce(math.min),
      y.reduce(math.min),
      x.reduce(math.max),
      y.reduce(math.max),
    );
  }

  PdfPoint localToGlobalPoint(PdfPoint point) {
    final mat = canvas.getTransform();
    final xy = mat.transform3(Vector3(point.x, point.y, 0));
    return PdfPoint(xy.x, xy.y);
  }
}

class Inherited {
  const Inherited();
}

abstract class Widget {
  Widget();

  /// The bounding box of this widget, calculated at layout time
  PdfRect? box;

  /// Draw a widget to a page canvas.
  static void draw(
    Widget widget, {
    PdfPage? page,
    PdfGraphics? canvas,
    BoxConstraints? constraints,
    required PdfPoint offset,
    Alignment? alignment,
    Context? context,
  }) {
    context ??= Context(
      document: page!.pdfDocument,
      page: page,
      canvas: canvas!,
    ).inheritFromAll(<Inherited>[
      ThemeData.base(),
    ]);

    widget.layout(
      context,
      constraints ?? const BoxConstraints(),
    );

    assert(widget.box != null);

    if (alignment != null) {
      final d = alignment.withinRect(widget.box!);
      offset = PdfPoint(offset.x - d.x, offset.y - d.y);
    }

    widget.box = PdfRect.fromPoints(offset, widget.box!.size);

    widget.paint(context);
  }

  /// Measure the size of a widget to a page canvas.
  static PdfPoint measure(
    Widget widget, {
    PdfPage? page,
    PdfGraphics? canvas,
    BoxConstraints? constraints,
    Context? context,
  }) {
    context ??= Context(
      document: page!.pdfDocument,
      page: page,
      canvas: canvas!,
    ).inheritFromAll(<Inherited>[
      ThemeData.base(),
    ]);

    widget.layout(
      context,
      constraints ?? const BoxConstraints(),
    );

    assert(widget.box != null);
    return widget.box!.size;
  }

  /// First widget pass to calculate the children layout and
  /// bounding [box]
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false});

  /// Draw itself and its children, according to the calculated
  /// [box.offset]
  @mustCallSuper
  void paint(Context context) {
    assert(() {
      if (Document.debug) {
        debugPaint(context);
      }
      return true;
    }());
  }

  @protected
  void debugPaint(Context context) {
    context.canvas
      ..setStrokeColor(PdfColors.purple)
      ..setLineWidth(1)
      ..drawBox(box!)
      ..strokePath();
  }
}

abstract class StatelessWidget extends Widget with SpanningWidget {
  StatelessWidget() : super();

  Widget? _child;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    _child ??= build(context);

    if (_child != null) {
      _child!.layout(context, constraints, parentUsesSize: parentUsesSize);
      assert(_child!.box != null);
      box = _child!.box;
    } else {
      box = PdfRect.fromPoints(PdfPoint.zero, constraints.smallest);
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);

    if (_child != null) {
      final mat = Matrix4.identity();
      mat.translate(box!.x, box!.y);
      context.canvas
        ..saveContext()
        ..setTransform(mat);
      _child!.paint(context);
      context.canvas.restoreContext();
    }
  }

  @protected
  Widget build(Context context);

  @override
  bool get canSpan =>
      _child is SpanningWidget && (_child as SpanningWidget).canSpan;

  @override
  bool get hasMoreWidgets =>
      _child is SpanningWidget && (_child as SpanningWidget).hasMoreWidgets;

  @override
  void restoreContext(covariant WidgetContext context) {
    if (_child is SpanningWidget) {
      (_child as SpanningWidget).restoreContext(context);
    }
  }

  @override
  WidgetContext saveContext() {
    if (_child is SpanningWidget) {
      return (_child as SpanningWidget).saveContext();
    }

    throw UnimplementedError();
  }
}

abstract class SingleChildWidget extends Widget with SpanningWidget {
  SingleChildWidget({this.child}) : super();

  final Widget? child;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    if (child != null) {
      child!.layout(context, constraints, parentUsesSize: parentUsesSize);
      assert(child!.box != null);
      box = child!.box;
    } else {
      box = PdfRect.fromPoints(PdfPoint.zero, constraints.smallest);
    }
  }

  @protected
  void paintChild(Context context) {
    if (child != null) {
      final mat = Matrix4.identity();
      mat.translate(box!.x, box!.y);
      context.canvas
        ..saveContext()
        ..setTransform(mat);
      child!.paint(context);
      context.canvas.restoreContext();
    }
  }

  @override
  bool get canSpan =>
      child is SpanningWidget && (child as SpanningWidget).canSpan;

  @override
  bool get hasMoreWidgets =>
      child is SpanningWidget && (child as SpanningWidget).hasMoreWidgets;

  @override
  void restoreContext(covariant WidgetContext context) {
    if (child is SpanningWidget) {
      (child as SpanningWidget).restoreContext(context);
    }
  }

  @override
  WidgetContext saveContext() {
    if (child is SpanningWidget) {
      return (child as SpanningWidget).saveContext();
    }

    throw UnimplementedError();
  }
}

abstract class MultiChildWidget extends Widget {
  MultiChildWidget({this.children = const <Widget>[]}) : super();

  final List<Widget> children;
}

class InheritedWidget extends SingleChildWidget {
  InheritedWidget({this.build, this.inherited}) : super();

  final BuildCallback? build;

  final Inherited? inherited;

  Context? _context;

  @override
  Widget? get child => _child;

  Widget? _child;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    _context = inherited != null ? context.inheritFrom(inherited!) : context;
    _child = build!(_context!);
    super.layout(_context!, constraints);
  }

  @override
  void paint(Context context) {
    assert(_context != null);
    super.paint(_context!);
    paintChild(_context!);
  }
}

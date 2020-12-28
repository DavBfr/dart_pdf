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
import 'package:vector_math/vector_math_64.dart';

import 'document.dart';
import 'geometry.dart';
import 'page.dart';

@immutable
class Context {
  factory Context({
    @required PdfDocument document,
    PdfPage page,
    PdfGraphics canvas,
  }) =>
      Context._(
        document: document,
        page: page,
        canvas: canvas,
        inherited: HashMap<Type, Inherited>(),
      );

  const Context._({
    @required this.document,
    this.page,
    this.canvas,
    @required this.inherited,
  })  : assert(document != null),
        assert(inherited != null);

  final PdfPage page;

  final PdfGraphics canvas;

  final HashMap<Type, Inherited> inherited;

  final PdfDocument document;

  int get pageNumber => document.pdfPageList.pages.indexOf(page) + 1;

  /// Number of pages in the document.
  /// This value is not available in a MultiPage body and will be equal to pageNumber.
  /// But can be used in Header and Footer.
  int get pagesCount => document.pdfPageList.pages.length;

  Context copyWith(
      {PdfPage page,
      PdfGraphics canvas,
      Matrix4 ctm,
      HashMap<Type, Inherited> inherited}) {
    return Context._(
        document: document,
        page: page ?? this.page,
        canvas: canvas ?? this.canvas,
        inherited: inherited ?? this.inherited);
  }

  Context inheritFrom(Inherited object) {
    return inheritFromAll(<Inherited>[object]);
  }

  Context inheritFromAll(Iterable<Inherited> objects) {
    final inherited = HashMap<Type, Inherited>.of(this.inherited);
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
}

class Inherited {
  const Inherited();
}

abstract class Widget {
  Widget();

  /// The bounding box of this widget, calculated at layout time
  PdfRect box;

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
      ..drawBox(box)
      ..strokePath();
  }
}

abstract class StatelessWidget extends Widget {
  StatelessWidget() : super();

  Widget _child;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    _child ??= build(context);

    if (_child != null) {
      _child.layout(context, constraints, parentUsesSize: parentUsesSize);
      assert(_child.box != null);
      box = _child.box;
    } else {
      box = PdfRect.fromPoints(PdfPoint.zero, constraints.smallest);
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);

    if (_child != null) {
      final mat = Matrix4.identity();
      mat.translate(box.x, box.y);
      context.canvas
        ..saveContext()
        ..setTransform(mat);
      _child.paint(context);
      context.canvas.restoreContext();
    }
  }

  @protected
  Widget build(Context context);
}

abstract class SingleChildWidget extends Widget {
  SingleChildWidget({this.child}) : super();

  final Widget child;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    if (child != null) {
      child.layout(context, constraints, parentUsesSize: parentUsesSize);
      assert(child.box != null);
      box = child.box;
    } else {
      box = PdfRect.fromPoints(PdfPoint.zero, constraints.smallest);
    }
  }

  @protected
  void paintChild(Context context) {
    if (child != null) {
      final mat = Matrix4.identity();
      mat.translate(box.x, box.y);
      context.canvas
        ..saveContext()
        ..setTransform(mat);
      child.paint(context);
      context.canvas.restoreContext();
    }
  }
}

abstract class MultiChildWidget extends Widget {
  MultiChildWidget({this.children = const <Widget>[]}) : super();

  final List<Widget> children;
}

class InheritedWidget extends Widget {
  InheritedWidget({this.build, this.inherited});

  final BuildCallback build;

  final Inherited inherited;

  Context _context;

  Widget _child;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    _context = inherited != null ? context.inheritFrom(inherited) : context;
    _child = build(_context);

    if (_child != null) {
      _child.layout(_context, constraints, parentUsesSize: parentUsesSize);
      assert(_child.box != null);
      box = _child.box;
    } else {
      box = PdfRect.fromPoints(PdfPoint.zero, constraints.smallest);
    }
  }

  @override
  void paint(Context context) {
    assert(_context != null);
    super.paint(_context);

    if (_child != null) {
      final mat = Matrix4.identity();
      mat.translate(box.x, box.y);
      context.canvas
        ..saveContext()
        ..setTransform(mat);
      _child.paint(_context);
      context.canvas.restoreContext();
    }
  }
}

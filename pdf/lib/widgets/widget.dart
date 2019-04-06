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
class Context {
  const Context({
    @required this.document,
    this.page,
    this.canvas,
    @required this.inherited,
  })  : assert(document != null),
        assert(inherited != null);

  final PdfPage page;

  final PdfGraphics canvas;

  final Map<Type, Inherited> inherited;

  final PdfDocument document;

  int get pageNumber => document.pdfPageList.pages.indexOf(page) + 1;

  int get pagesCount => document.pdfPageList.pages.length;

  Context copyWith(
      {PdfPage page,
      PdfGraphics canvas,
      Matrix4 ctm,
      Map<Type, Inherited> inherited}) {
    return Context(
        document: document,
        page: page ?? this.page,
        canvas: canvas ?? this.canvas,
        inherited: inherited ?? this.inherited);
  }

  Context inheritFrom(Inherited object) {
    final Map<Type, Inherited> inherited = this.inherited;
    inherited[object.runtimeType] = object;
    return copyWith(inherited: inherited);
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
  @protected
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false});

  /// Draw itself and its children, according to the calculated
  /// [box.offset]
  @protected
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
      ..drawRect(box.x, box.y, box.width, box.height)
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
      final Matrix4 mat = Matrix4.identity();
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
      final Matrix4 mat = Matrix4.identity();
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

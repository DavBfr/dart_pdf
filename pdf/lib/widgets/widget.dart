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
  const Context({this.page, this.canvas, this.inherited});

  final PdfPage page;

  final PdfGraphics canvas;

  final Map<Type, Inherited> inherited;

  int get pageNumber => page.pdfDocument.pdfPageList.pages.indexOf(page) + 1;

  Context copyWith(
      {PdfPage page, PdfGraphics canvas, Map<Type, Inherited> inherited}) {
    return Context(
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

class Inherited {}

abstract class Widget {
  Widget();

  PdfRect box;

  @protected
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false});

  @protected
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
      ..setStrokeColor(PdfColor.purple)
      ..drawRect(box.x, box.y, box.width, box.height)
      ..strokePath();
  }
}

class WidgetContext {}

abstract class SpanningWidget extends Widget {
  bool get canSpan => false;

  @protected
  WidgetContext saveContext();

  @protected
  void restoreContext(WidgetContext context);
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
      box = child.box;
    } else {
      box = PdfRect.fromPoints(PdfPoint.zero, constraints.smallest);
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);

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

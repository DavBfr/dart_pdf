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

class _GridViewContext extends WidgetContext {
  int firstChild = 0;
  int lastChild = 0;

  double childCrossAxis;
  double childMainAxis;

  @override
  String toString() =>
      'GridViewContext first:$firstChild last:$lastChild size:${childCrossAxis}x$childMainAxis';
}

class GridView extends MultiChildWidget implements SpanningWidget {
  GridView(
      {this.direction = Axis.vertical,
      this.padding = EdgeInsets.zero,
      @required this.crossAxisCount,
      this.mainAxisSpacing = 0.0,
      this.crossAxisSpacing = 0.0,
      this.childAspectRatio = double.infinity,
      List<Widget> children = const <Widget>[]})
      : assert(padding != null),
        super(children: children);

  final Axis direction;
  final EdgeInsets padding;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;

  final _GridViewContext _context = _GridViewContext();

  int _mainAxisCount;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    assert(() {
      if (constraints.maxHeight.isInfinite && childAspectRatio.isInfinite) {
        print(
            'Unable to calculate the GridView dimensions. Please set one the height constraints or childAspectRatio.');
        return false;
      }
      return true;
    }());

    double mainAxisExtent;
    double crossAxisExtent;
    switch (direction) {
      case Axis.vertical:
        mainAxisExtent = constraints.maxHeight - padding.vertical;
        crossAxisExtent = constraints.maxWidth - padding.horizontal;
        break;
      case Axis.horizontal:
        mainAxisExtent = constraints.maxWidth - padding.horizontal;
        crossAxisExtent = constraints.maxHeight - padding.vertical;
        break;
    }

    if (constraints.maxHeight.isInfinite || _mainAxisCount == null) {
      _mainAxisCount =
          ((children.length - _context.firstChild) / crossAxisCount).ceil();

      _context.childCrossAxis = crossAxisExtent / crossAxisCount -
          (crossAxisSpacing * (crossAxisCount - 1) / crossAxisCount);

      _context.childMainAxis = math.min(
          _context.childCrossAxis * childAspectRatio,
          mainAxisExtent / _mainAxisCount -
              (mainAxisSpacing * (_mainAxisCount - 1) / _mainAxisCount));

      if (_context.childCrossAxis.isInfinite) {
        throw Exception(
            'Unable to calculate child height as the height constraint is infinite.');
      }
    } else {
      _mainAxisCount = ((mainAxisExtent + mainAxisSpacing) /
              (mainAxisSpacing + _context.childMainAxis))
          .floor();

      if (_mainAxisCount < 0) {
        // Not enough space to put one line, try to ask for more space.
        _mainAxisCount = 0;
      }
    }

    final double totalMain =
        (_context.childMainAxis + mainAxisSpacing) * _mainAxisCount -
            mainAxisSpacing;
    final double totalCross =
        (_context.childCrossAxis + crossAxisSpacing) * crossAxisCount -
            crossAxisSpacing;

    final double startX = padding.left;
    const double startY = 0;
    double mainAxis;
    double crossAxis;
    BoxConstraints innerConstraints;
    switch (direction) {
      case Axis.vertical:
        innerConstraints = BoxConstraints.tightFor(
            width: _context.childCrossAxis, height: _context.childMainAxis);
        crossAxis = startX;
        mainAxis = startY;
        break;
      case Axis.horizontal:
        innerConstraints = BoxConstraints.tightFor(
            width: _context.childMainAxis, height: _context.childCrossAxis);
        mainAxis = startX;
        crossAxis = startY;
        break;
    }

    int c = 0;
    _context.lastChild = _context.firstChild;

    for (Widget child in children.sublist(
        _context.firstChild,
        math.min(children.length,
            _context.firstChild + crossAxisCount * _mainAxisCount))) {
      child.layout(context, innerConstraints);
      assert(child.box != null);

      switch (direction) {
        case Axis.vertical:
          child.box = PdfRect.fromPoints(
              PdfPoint(
                  (_context.childCrossAxis - child.box.width) / 2.0 + crossAxis,
                  totalMain +
                      padding.bottom -
                      (_context.childMainAxis - child.box.height) / 2.0 -
                      mainAxis -
                      child.box.height),
              child.box.size);
          break;
        case Axis.horizontal:
          child.box = PdfRect.fromPoints(
              PdfPoint(
                  (_context.childMainAxis - child.box.width) / 2.0 + mainAxis,
                  totalCross +
                      padding.bottom -
                      (_context.childCrossAxis - child.box.height) / 2.0 -
                      crossAxis -
                      child.box.height),
              child.box.size);
          break;
      }

      if (++c >= crossAxisCount) {
        mainAxis += _context.childMainAxis + mainAxisSpacing;
        switch (direction) {
          case Axis.vertical:
            crossAxis = startX;
            break;
          case Axis.horizontal:
            crossAxis = startY;
            break;
        }
        c = 0;

        if (mainAxis > mainAxisExtent) {
          _context.lastChild++;

          break;
        }
      } else {
        crossAxis += _context.childCrossAxis + crossAxisSpacing;
      }
      _context.lastChild++;
    }

    switch (direction) {
      case Axis.vertical:
        box = constraints.constrainRect(
            width: totalCross + padding.horizontal,
            height: totalMain + padding.vertical);
        break;
      case Axis.horizontal:
        box = constraints.constrainRect(
            width: totalMain + padding.horizontal,
            height: totalCross + padding.vertical);
        break;
    }
  }

  @override
  void debugPaint(Context context) {
    super.debugPaint(context);

    context.canvas
      ..setFillColor(PdfColors.lime)
      ..moveTo(box.left, box.bottom)
      ..lineTo(box.right, box.bottom)
      ..lineTo(box.right, box.top)
      ..lineTo(box.left, box.top)
      ..moveTo(box.left + padding.left, box.bottom + padding.bottom)
      ..lineTo(box.left + padding.left, box.top - padding.top)
      ..lineTo(box.right - padding.right, box.top - padding.top)
      ..lineTo(box.right - padding.right, box.bottom + padding.bottom)
      ..fillPath();

    for (int c = 1; c < crossAxisCount; c++) {
      switch (direction) {
        case Axis.vertical:
          context.canvas
            ..drawRect(
                box.left +
                    padding.left +
                    (_context.childCrossAxis + crossAxisSpacing) * c -
                    crossAxisSpacing,
                box.bottom + padding.bottom,
                math.max(crossAxisSpacing, 1),
                box.height - padding.vertical)
            ..fillPath();
          break;
        case Axis.horizontal:
          context.canvas
            ..drawRect(
                box.left + padding.left,
                box.bottom +
                    padding.bottom +
                    (_context.childCrossAxis + crossAxisSpacing) * c -
                    crossAxisSpacing,
                box.width - padding.horizontal,
                math.max(crossAxisSpacing, 1))
            ..fillPath();
          break;
      }
    }

    for (int c = 1; c < _mainAxisCount; c++) {
      switch (direction) {
        case Axis.vertical:
          context.canvas
            ..drawRect(
                box.left + padding.left,
                box.bottom +
                    padding.bottom +
                    (_context.childMainAxis + mainAxisSpacing) * c -
                    mainAxisSpacing,
                box.width - padding.horizontal,
                math.max(mainAxisSpacing, 1))
            ..fillPath();
          break;
        case Axis.horizontal:
          context.canvas
            ..drawRect(
                box.left +
                    padding.left +
                    (_context.childMainAxis + mainAxisSpacing) * c -
                    mainAxisSpacing,
                box.bottom + padding.bottom,
                math.max(mainAxisSpacing, 1),
                box.height - padding.vertical)
            ..fillPath();
          break;
      }
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final Matrix4 mat = Matrix4.identity();
    mat.translate(box.x, box.y);
    context.canvas
      ..saveContext()
      ..setTransform(mat);

    for (Widget child
        in children.sublist(_context.firstChild, _context.lastChild)) {
      child.paint(context);
    }
    context.canvas.restoreContext();
  }

  @override
  bool get canSpan => true;

  @override
  void restoreContext(WidgetContext context) {
    if (context is _GridViewContext) {
      _context.firstChild = context.lastChild;
    }
  }

  @override
  WidgetContext saveContext() {
    return _context;
  }
}

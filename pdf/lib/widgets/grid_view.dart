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

class GridView extends MultiChildWidget {
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

  double _childCrossAxis;
  double _childMainAxis;
  double _totalMain;
  double _totalCross;
  int _mainAxisCount;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
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

    _mainAxisCount = (children.length / crossAxisCount).ceil();
    _childCrossAxis = crossAxisExtent / crossAxisCount -
        (crossAxisSpacing * (crossAxisCount - 1) / crossAxisCount);
    _childMainAxis = math.min(
        _childCrossAxis * childAspectRatio,
        mainAxisExtent / _mainAxisCount -
            (mainAxisSpacing * (_mainAxisCount - 1) / _mainAxisCount));
    _totalMain =
        (_childMainAxis + mainAxisSpacing) * _mainAxisCount - mainAxisSpacing;
    _totalCross = (_childCrossAxis + crossAxisSpacing) * crossAxisCount -
        crossAxisSpacing;

    final double startX = padding.left;
    const double startY = 0;
    double mainAxis;
    double crossAxis;
    BoxConstraints innerConstraints;
    switch (direction) {
      case Axis.vertical:
        innerConstraints = BoxConstraints.tightFor(
            width: _childCrossAxis, height: _childMainAxis);
        crossAxis = startX;
        mainAxis = startY;
        break;
      case Axis.horizontal:
        innerConstraints = BoxConstraints.tightFor(
            width: _childMainAxis, height: _childCrossAxis);
        mainAxis = startX;
        crossAxis = startY;
        break;
    }

    int c = 0;
    for (Widget child in children) {
      child.layout(context, innerConstraints);

      switch (direction) {
        case Axis.vertical:
          child.box = PdfRect.fromPoints(
              PdfPoint(
                  (_childCrossAxis - child.box.width) / 2.0 + crossAxis,
                  _totalMain +
                      padding.bottom -
                      (_childMainAxis - child.box.height) / 2.0 -
                      mainAxis -
                      child.box.height),
              child.box.size);
          break;
        case Axis.horizontal:
          child.box = PdfRect.fromPoints(
              PdfPoint(
                  (_childMainAxis - child.box.width) / 2.0 + mainAxis,
                  _totalCross +
                      padding.bottom -
                      (_childCrossAxis - child.box.height) / 2.0 -
                      crossAxis -
                      child.box.height),
              child.box.size);
          break;
      }

      if (++c >= crossAxisCount) {
        mainAxis += _childMainAxis + mainAxisSpacing;
        crossAxis = startX;
        c = 0;
      } else {
        crossAxis += _childCrossAxis + crossAxisSpacing;
      }
    }

    switch (direction) {
      case Axis.vertical:
        box = constraints.constrainRect(
            width: _totalCross + padding.horizontal,
            height: _totalMain + padding.vertical);
        break;
      case Axis.horizontal:
        box = constraints.constrainRect(
            width: _totalMain + padding.horizontal,
            height: _totalCross + padding.vertical);
        break;
    }
  }

  @override
  void debugPaint(Context context) {
    super.debugPaint(context);

    context.canvas
      ..setFillColor(PdfColor.lime)
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
                    (_childCrossAxis + crossAxisSpacing) * c -
                    crossAxisSpacing,
                box.bottom + padding.bottom,
                math.max(crossAxisSpacing, 1),
                box.height - padding.vertical)
            ..fillPath();
          break;
        case Axis.horizontal:
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
                    (_childMainAxis + mainAxisSpacing) * c -
                    mainAxisSpacing,
                box.width - padding.horizontal,
                math.max(mainAxisSpacing, 1))
            ..fillPath();
          break;
        case Axis.horizontal:
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
    for (Widget child in children) {
      child.paint(context);
    }
    context.canvas.restoreContext();
  }
}

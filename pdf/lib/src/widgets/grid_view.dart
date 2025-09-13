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

import 'package:vector_math/vector_math_64.dart';

import '../../pdf.dart';
import 'flex.dart';
import 'geometry.dart';
import 'multi_page.dart';
import 'text.dart';
import 'text_style.dart';
import 'widget.dart';

class GridViewContext extends WidgetContext {
  int firstChild = 0;
  int lastChild = 0;

  double? childCrossAxis;
  double? childMainAxis;

  @override
  void apply(GridViewContext other) {
    firstChild = other.firstChild;
    lastChild = other.lastChild;
    childCrossAxis = other.childCrossAxis ?? childCrossAxis;
    childMainAxis = other.childMainAxis ?? childMainAxis;
  }

  @override
  WidgetContext clone() {
    return GridViewContext()..apply(this);
  }

  @override
  String toString() =>
      '$runtimeType first:$firstChild last:$lastChild size:${childCrossAxis}x$childMainAxis';
}

class GridView extends MultiChildWidget with SpanningWidget {
  GridView(
      {this.direction = Axis.vertical,
      this.padding = EdgeInsets.zero,
      required this.crossAxisCount,
      this.mainAxisSpacing = 0.0,
      this.crossAxisSpacing = 0.0,
      this.childAspectRatio = double.infinity,
      List<Widget> children = const <Widget>[]})
      : super(children: children);

  final Axis direction;
  final EdgeInsetsGeometry padding;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;

  final GridViewContext _context = GridViewContext();

  int? _mainAxisCount;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    if (children.isEmpty) {
      box = PdfRect.zero;
      return;
    }

    assert(() {
      if (constraints.maxHeight.isInfinite && childAspectRatio.isInfinite) {
        print(
            'Unable to calculate the GridView dimensions. Please set the height constraints or childAspectRatio.');
        return false;
      }
      return true;
    }());
    final textDirection = Directionality.of(context);
    final resolvedPadding = padding.resolve(textDirection);
    late double mainAxisExtent;
    late double crossAxisExtent;
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
          _context.childCrossAxis! * childAspectRatio,
          mainAxisExtent / _mainAxisCount! -
              (mainAxisSpacing * (_mainAxisCount! - 1) / _mainAxisCount!));

      if (_context.childCrossAxis!.isInfinite) {
        throw Exception(
            'Unable to calculate child height as the height constraint is infinite.');
      }
    } else {
      _mainAxisCount = ((mainAxisExtent + mainAxisSpacing) /
              (mainAxisSpacing + _context.childMainAxis!))
          .floor();

      if (_mainAxisCount! < 0) {
        // Not enough space to put one line, try to ask for more space.
        _mainAxisCount = 0;
      }
    }

    final totalMain =
        (_context.childMainAxis! + mainAxisSpacing) * _mainAxisCount! -
            mainAxisSpacing;
    final totalCross =
        (_context.childCrossAxis! + crossAxisSpacing) * crossAxisCount -
            crossAxisSpacing;

    final startX = resolvedPadding.left;
    const startY = 0.0;
    late double mainAxis;
    late double crossAxis;
    BoxConstraints? innerConstraints;
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

    var c = 0;
    _context.lastChild = _context.firstChild;

    final isRtl = textDirection == TextDirection.rtl;
    for (final child in children.sublist(
        _context.firstChild,
        math.min(children.length,
            _context.firstChild + crossAxisCount * _mainAxisCount!))) {
      child.layout(context, innerConstraints);
      assert(child.box != null);

      switch (direction) {
        case Axis.vertical:
          child.box = PdfRect.fromPoints(
              PdfPoint(
                isRtl
                    ? (_context.childCrossAxis! + child.box!.width - crossAxis)
                    : (_context.childCrossAxis! - child.box!.width) / 2.0 +
                        crossAxis,
                totalMain +
                    resolvedPadding.bottom -
                    (_context.childMainAxis! - child.box!.height) / 2.0 -
                    mainAxis -
                    child.box!.height,
              ),
              child.box!.size);

          break;
        case Axis.horizontal:
          child.box = PdfRect.fromPoints(
              PdfPoint(
                  isRtl
                      ? totalMain - (child.box!.width + mainAxis)
                      : (_context.childMainAxis! - child.box!.width) / 2.0 +
                          mainAxis,
                  totalCross +
                      resolvedPadding.bottom -
                      (_context.childCrossAxis! - child.box!.height) / 2.0 -
                      crossAxis -
                      child.box!.height),
              child.box!.size);
          break;
      }

      if (++c >= crossAxisCount) {
        mainAxis += _context.childMainAxis! + mainAxisSpacing;
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
        crossAxis += _context.childCrossAxis! + crossAxisSpacing;
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

    if (children.isEmpty) {
      return;
    }
    final resolvedPadding = padding.resolve(Directionality.of(context));

    context.canvas
      ..setFillColor(PdfColors.lime)
      ..moveTo(box!.left, box!.bottom)
      ..lineTo(box!.right, box!.bottom)
      ..lineTo(box!.right, box!.top)
      ..lineTo(box!.left, box!.top)
      ..moveTo(box!.left + resolvedPadding.left,
          box!.bottom + resolvedPadding.bottom)
      ..lineTo(box!.left + resolvedPadding.left, box!.top - resolvedPadding.top)
      ..lineTo(
          box!.right - resolvedPadding.right, box!.top - resolvedPadding.top)
      ..lineTo(box!.right - resolvedPadding.right,
          box!.bottom + resolvedPadding.bottom)
      ..fillPath();

    for (var c = 1; c < crossAxisCount; c++) {
      switch (direction) {
        case Axis.vertical:
          context.canvas
            ..drawRect(
                box!.left +
                    resolvedPadding.left +
                    (_context.childCrossAxis! + crossAxisSpacing) * c -
                    crossAxisSpacing,
                box!.bottom + resolvedPadding.bottom,
                math.max(crossAxisSpacing, 1),
                box!.height - resolvedPadding.vertical)
            ..fillPath();
          break;
        case Axis.horizontal:
          context.canvas
            ..drawRect(
                box!.left + resolvedPadding.left,
                box!.bottom +
                    resolvedPadding.bottom +
                    (_context.childCrossAxis! + crossAxisSpacing) * c -
                    crossAxisSpacing,
                box!.width - resolvedPadding.horizontal,
                math.max(crossAxisSpacing, 1))
            ..fillPath();
          break;
      }
    }

    for (var c = 1; c < _mainAxisCount!; c++) {
      switch (direction) {
        case Axis.vertical:
          context.canvas
            ..drawRect(
                box!.left + resolvedPadding.left,
                box!.bottom +
                    resolvedPadding.bottom +
                    (_context.childMainAxis! + mainAxisSpacing) * c -
                    mainAxisSpacing,
                box!.width - resolvedPadding.horizontal,
                math.max(mainAxisSpacing, 1))
            ..fillPath();
          break;
        case Axis.horizontal:
          context.canvas
            ..drawRect(
                box!.left +
                    resolvedPadding.left +
                    (_context.childMainAxis! + mainAxisSpacing) * c -
                    mainAxisSpacing,
                box!.bottom + resolvedPadding.bottom,
                math.max(mainAxisSpacing, 1),
                box!.height - resolvedPadding.vertical)
            ..fillPath();
          break;
      }
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final mat = Matrix4.identity();
    mat.translate(box!.left, box!.bottom);
    context.canvas
      ..saveContext()
      ..setTransform(mat);

    for (var child
        in children.sublist(_context.firstChild, _context.lastChild)) {
      child.paint(context);
    }
    context.canvas.restoreContext();
  }

  @override
  bool get canSpan => true;

  @override
  bool get hasMoreWidgets => true;

  @override
  void restoreContext(GridViewContext context) {
    _context.apply(context);
    _context.firstChild = context.lastChild;
  }

  @override
  WidgetContext saveContext() {
    return _context;
  }
}

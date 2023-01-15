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
import 'widget.dart';

/// How [Wrap] should align objects.
enum WrapAlignment {
  start,
  end,
  center,
  spaceBetween,
  spaceAround,
  spaceEvenly
}

/// Who [Wrap] should align children within a run in the cross axis.
enum WrapCrossAlignment { start, end, center }

class _RunMetrics {
  _RunMetrics(this.mainAxisExtent, this.crossAxisExtent, this.childCount);

  final double mainAxisExtent;
  final double crossAxisExtent;
  final int childCount;
}

class WrapContext extends WidgetContext {
  int firstChild = 0;
  int lastChild = 0;

  @override
  void apply(WrapContext other) {
    firstChild = other.firstChild;
    lastChild = other.lastChild;
  }

  @override
  WidgetContext clone() {
    return WrapContext()..apply(this);
  }

  @override
  String toString() => '$runtimeType first:$firstChild last:$lastChild';
}

/// A widget that displays its children in multiple horizontal or vertical runs.
class Wrap extends MultiChildWidget with SpanningWidget {
  /// Creates a wrap layout.

  Wrap({
    this.direction = Axis.horizontal,
    this.alignment = WrapAlignment.start,
    this.spacing = 0.0,
    this.runAlignment = WrapAlignment.start,
    this.runSpacing = 0.0,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.verticalDirection = VerticalDirection.down,
    List<Widget> children = const <Widget>[],
  }) : super(children: children);

  /// The direction to use as the main axis.
  final Axis direction;

  /// How the children within a run should be placed in the main axis.
  final WrapAlignment alignment;

  /// How much space to place between children in a run in the main axis.
  final double spacing;

  /// How the runs themselves should be placed in the cross axis.
  final WrapAlignment runAlignment;

  /// How much space to place between the runs themselves in the cross axis.
  final double runSpacing;

  /// How the children within a run should be aligned relative to each other in
  /// the cross axis.
  final WrapCrossAlignment crossAxisAlignment;

  /// Determines the order to lay children out vertically and how to interpret
  /// `start` and `end` in the vertical direction.
  final VerticalDirection verticalDirection;

  bool get textDirection => false;

  @override
  bool get canSpan => true;

  @override
  bool get hasMoreWidgets => _context.lastChild < children.length;

  final WrapContext _context = WrapContext();

  double? _getMainAxisExtent(Widget child) {
    switch (direction) {
      case Axis.horizontal:
        return child.box!.width;
      case Axis.vertical:
        return child.box!.height;
    }
  }

  double? _getCrossAxisExtent(Widget child) {
    switch (direction) {
      case Axis.horizontal:
        return child.box!.height;
      case Axis.vertical:
        return child.box!.width;
    }
  }

  PdfPoint _getOffset(double mainAxisOffset, double crossAxisOffset) {
    switch (direction) {
      case Axis.horizontal:
        return PdfPoint(mainAxisOffset, crossAxisOffset);
      case Axis.vertical:
        return PdfPoint(crossAxisOffset, mainAxisOffset);
    }
  }

  double _getChildCrossAxisOffset(bool flipCrossAxis, double runCrossAxisExtent,
      double childCrossAxisExtent) {
    final freeSpace = runCrossAxisExtent - childCrossAxisExtent;
    switch (crossAxisAlignment) {
      case WrapCrossAlignment.start:
        return flipCrossAxis ? freeSpace : 0.0;
      case WrapCrossAlignment.end:
        return flipCrossAxis ? 0.0 : freeSpace;
      case WrapCrossAlignment.center:
        return freeSpace / 2.0;
    }
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    if (children.isEmpty || _context.firstChild >= children.length) {
      box = PdfRect.fromPoints(PdfPoint.zero, constraints.smallest);
      return;
    }

    BoxConstraints? childConstraints;
    double? mainAxisLimit = 0.0;
    var flipMainAxis = false;
    var flipCrossAxis = false;

    switch (direction) {
      case Axis.horizontal:
        childConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
        mainAxisLimit = constraints.maxWidth;
        if (verticalDirection == VerticalDirection.down) {
          flipCrossAxis = true;
        }
        break;
      case Axis.vertical:
        childConstraints = BoxConstraints(maxHeight: constraints.maxHeight);
        mainAxisLimit = constraints.maxHeight;
        if (verticalDirection == VerticalDirection.down) {
          flipMainAxis = true;
        }
        break;
    }

    final runMetrics = <_RunMetrics>[];
    final childRunMetrics = <Widget, int>{};
    var mainAxisExtent = 0.0;
    var crossAxisExtent = 0.0;
    var runMainAxisExtent = 0.0;
    var runCrossAxisExtent = 0.0;
    var childCount = 0;

    for (final child in children.sublist(_context.firstChild)) {
      child.layout(context, childConstraints, parentUsesSize: true);

      final childMainAxisExtent = _getMainAxisExtent(child)!;
      final childCrossAxisExtent = _getCrossAxisExtent(child)!;

      if (childCount > 0 &&
          runMainAxisExtent + spacing + childMainAxisExtent > mainAxisLimit) {
        mainAxisExtent = math.max(mainAxisExtent, runMainAxisExtent);
        crossAxisExtent += runCrossAxisExtent;
        if (runMetrics.isNotEmpty) {
          crossAxisExtent += runSpacing;
        }
        runMetrics.add(
            _RunMetrics(runMainAxisExtent, runCrossAxisExtent, childCount));
        runMainAxisExtent = 0.0;
        runCrossAxisExtent = 0.0;
        childCount = 0;
      }

      runMainAxisExtent += childMainAxisExtent;

      if (childCount > 0) {
        runMainAxisExtent += spacing;
      }

      runCrossAxisExtent = math.max(runCrossAxisExtent, childCrossAxisExtent);
      childCount += 1;

      childRunMetrics[child] = runMetrics.length;
    }

    if (childCount > 0) {
      mainAxisExtent = math.max(mainAxisExtent, runMainAxisExtent);
      crossAxisExtent += runCrossAxisExtent;
      if (runMetrics.isNotEmpty) {
        crossAxisExtent += runSpacing;
      }
      runMetrics
          .add(_RunMetrics(runMainAxisExtent, runCrossAxisExtent, childCount));
    }

    final runCount = runMetrics.length;
    assert(runCount > 0);

    double? containerMainAxisExtent = 0.0;
    double? containerCrossAxisExtent = 0.0;

    switch (direction) {
      case Axis.horizontal:
        box = PdfRect.fromPoints(PdfPoint.zero,
            constraints.constrain(PdfPoint(mainAxisExtent, crossAxisExtent)));
        containerMainAxisExtent = box!.width;
        containerCrossAxisExtent = box!.height;
        break;
      case Axis.vertical:
        box = PdfRect.fromPoints(PdfPoint.zero,
            constraints.constrain(PdfPoint(crossAxisExtent, mainAxisExtent)));
        containerMainAxisExtent = box!.height;
        containerCrossAxisExtent = box!.width;
        break;
    }

    final crossAxisFreeSpace =
        math.max(0.0, containerCrossAxisExtent - crossAxisExtent);
    var runLeadingSpace = 0.0;
    var runBetweenSpace = 0.0;

    switch (runAlignment) {
      case WrapAlignment.start:
        break;
      case WrapAlignment.end:
        runLeadingSpace = crossAxisFreeSpace;
        break;
      case WrapAlignment.center:
        runLeadingSpace = crossAxisFreeSpace / 2.0;
        break;
      case WrapAlignment.spaceBetween:
        runBetweenSpace =
            runCount > 1 ? crossAxisFreeSpace / (runCount - 1) : 0.0;
        break;
      case WrapAlignment.spaceAround:
        runBetweenSpace = crossAxisFreeSpace / runCount;
        runLeadingSpace = runBetweenSpace / 2.0;
        break;
      case WrapAlignment.spaceEvenly:
        runBetweenSpace = crossAxisFreeSpace / (runCount + 1);
        runLeadingSpace = runBetweenSpace;
        break;
    }

    runBetweenSpace += runSpacing;
    var crossAxisOffset = flipCrossAxis
        ? containerCrossAxisExtent - runLeadingSpace
        : runLeadingSpace;

    _context.lastChild = _context.firstChild;
    for (var i = 0; i < runCount; ++i) {
      final metrics = runMetrics[i];
      final runMainAxisExtent = metrics.mainAxisExtent;
      final runCrossAxisExtent = metrics.crossAxisExtent;
      final childCount = metrics.childCount;

      final mainAxisFreeSpace =
          math.max(0.0, containerMainAxisExtent - runMainAxisExtent);
      var childLeadingSpace = 0.0;
      var childBetweenSpace = 0.0;

      switch (alignment) {
        case WrapAlignment.start:
          break;
        case WrapAlignment.end:
          childLeadingSpace = mainAxisFreeSpace;
          break;
        case WrapAlignment.center:
          childLeadingSpace = mainAxisFreeSpace / 2.0;
          break;
        case WrapAlignment.spaceBetween:
          childBetweenSpace =
              childCount > 1 ? mainAxisFreeSpace / (childCount - 1) : 0.0;
          break;
        case WrapAlignment.spaceAround:
          childBetweenSpace = mainAxisFreeSpace / childCount;
          childLeadingSpace = childBetweenSpace / 2.0;
          break;
        case WrapAlignment.spaceEvenly:
          childBetweenSpace = mainAxisFreeSpace / (childCount + 1);
          childLeadingSpace = childBetweenSpace;
          break;
      }

      childBetweenSpace += spacing;
      var childMainPosition = flipMainAxis
          ? containerMainAxisExtent - childLeadingSpace
          : childLeadingSpace;

      if (flipCrossAxis) {
        crossAxisOffset -= runCrossAxisExtent;
      }

      if (crossAxisOffset < -.01 ||
          crossAxisOffset + runCrossAxisExtent >
              containerCrossAxisExtent + .01) {
        break;
      }

      var currentWidget = _context.lastChild;
      for (final child in children.sublist(currentWidget)) {
        final runIndex = childRunMetrics[child];
        if (runIndex != i) {
          break;
        }

        currentWidget++;
        final childMainAxisExtent = _getMainAxisExtent(child);
        final childCrossAxisExtent = _getCrossAxisExtent(child)!;
        final childCrossAxisOffset = _getChildCrossAxisOffset(
            flipCrossAxis, runCrossAxisExtent, childCrossAxisExtent);
        if (flipMainAxis) {
          childMainPosition -= childMainAxisExtent!;
        }
        child.box = PdfRect.fromPoints(
            _getOffset(
                childMainPosition, crossAxisOffset + childCrossAxisOffset),
            child.box!.size);
        if (flipMainAxis) {
          childMainPosition -= childBetweenSpace;
        } else {
          childMainPosition += childMainAxisExtent! + childBetweenSpace;
        }
      }

      if (flipCrossAxis) {
        crossAxisOffset -= runBetweenSpace;
      } else {
        crossAxisOffset += runCrossAxisExtent + runBetweenSpace;
      }

      _context.lastChild = currentWidget;
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);

    context.canvas.saveContext();

    final mat = Matrix4.identity();
    mat.translate(box!.x, box!.y);
    context.canvas.setTransform(mat);
    for (var child
        in children.sublist(_context.firstChild, _context.lastChild)) {
      child.paint(context);
    }

    context.canvas.restoreContext();
  }

  @override
  void restoreContext(WrapContext context) {
    _context.apply(context);
    _context.firstChild = context.lastChild;
  }

  @override
  WidgetContext saveContext() {
    return _context;
  }
}

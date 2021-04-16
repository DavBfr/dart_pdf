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

import 'package:pdf/pdf.dart';
import 'package:vector_math/vector_math_64.dart';

import 'basic.dart';
import 'geometry.dart';
import 'multi_page.dart';
import 'widget.dart';

enum FlexFit {
  tight,
  loose,
}

enum Axis {
  horizontal,
  vertical,
}

enum MainAxisSize {
  min,
  max,
}

enum MainAxisAlignment {
  start,
  end,
  center,
  spaceBetween,
  spaceAround,
  spaceEvenly,
}

enum CrossAxisAlignment {
  start,
  end,
  center,
  stretch,
}

enum VerticalDirection {
  up,
  down,
}

typedef _ChildSizingFunction = double? Function(Widget child, double? extent);

class _FlexContext extends WidgetContext {
  int firstChild = 0;
  int lastChild = 0;

  @override
  void apply(_FlexContext other) {
    firstChild = other.firstChild;
    lastChild = other.lastChild;
  }

  @override
  WidgetContext clone() {
    return _FlexContext()..apply(this);
  }

  @override
  String toString() => '$runtimeType first:$firstChild last:$lastChild';
}

class Flex extends MultiChildWidget implements SpanningWidget {
  Flex({
    required this.direction,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.verticalDirection = VerticalDirection.down,
    List<Widget> children = const <Widget>[],
  }) : super(children: children);

  final Axis direction;

  final MainAxisAlignment mainAxisAlignment;

  final MainAxisSize mainAxisSize;

  final CrossAxisAlignment crossAxisAlignment;

  final VerticalDirection verticalDirection;

  final _FlexContext _context = _FlexContext();

  double _getIntrinsicSize(
      {Axis? sizingDirection,
      double?
          extent, // the extent in the direction that isn't the sizing direction
      _ChildSizingFunction?
          childSize // a method to find the size in the sizing direction
      }) {
    if (direction == sizingDirection) {
      // INTRINSIC MAIN SIZE
      // Intrinsic main size is the smallest size the flex container can take
      // while maintaining the min/max-content contributions of its flex items.
      var totalFlex = 0.0;
      var inflexibleSpace = 0.0;
      var maxFlexFractionSoFar = 0.0;

      for (var child in children) {
        final flex = child is Flexible ? child.flex : 0;
        totalFlex += flex;
        if (flex > 0) {
          final flexFraction = childSize!(child, extent)! / flex;
          maxFlexFractionSoFar = math.max(maxFlexFractionSoFar, flexFraction);
        } else {
          inflexibleSpace += childSize!(child, extent)!;
        }
      }
      return maxFlexFractionSoFar * totalFlex + inflexibleSpace;
    } else {
      // INTRINSIC CROSS SIZE
      // Intrinsic cross size is the max of the intrinsic cross sizes of the
      // children, after the flexible children are fit into the available space,
      // with the children sized using their max intrinsic dimensions.

      // Get inflexible space using the max intrinsic dimensions of fixed children in the main direction.
      final availableMainSpace = extent;
      var totalFlex = 0;
      var inflexibleSpace = 0.0;
      var maxCrossSize = 0.0;
      for (var child in children) {
        final flex = child is Flexible ? child.flex : 0;
        totalFlex += flex;
        double? mainSize;
        double? crossSize;
        if (flex == 0) {
          switch (direction) {
            case Axis.horizontal:
              mainSize = child.box!.width;
              crossSize = childSize!(child, mainSize);
              break;
            case Axis.vertical:
              mainSize = child.box!.height;
              crossSize = childSize!(child, mainSize);
              break;
          }
          inflexibleSpace += mainSize;
          maxCrossSize = math.max(maxCrossSize, crossSize!);
        }
      }

      // Determine the spacePerFlex by allocating the remaining available space.
      // When you're over-constrained spacePerFlex can be negative.
      final spacePerFlex =
          math.max(0.0, (availableMainSpace! - inflexibleSpace) / totalFlex);

      // Size remaining (flexible) items, find the maximum cross size.
      for (var child in children) {
        final flex = child is Flexible ? child.flex : 0;
        if (flex > 0) {
          maxCrossSize =
              math.max(maxCrossSize, childSize!(child, spacePerFlex * flex)!);
        }
      }

      return maxCrossSize;
    }
  }

  double computeMinIntrinsicWidth(double height) {
    return _getIntrinsicSize(
        sizingDirection: Axis.horizontal,
        extent: height,
        childSize: (Widget child, double? extent) => child.box!.width);
  }

  double computeMaxIntrinsicWidth(double height) {
    return _getIntrinsicSize(
        sizingDirection: Axis.horizontal,
        extent: height,
        childSize: (Widget child, double? extent) => child.box!.width);
  }

  double computeMinIntrinsicHeight(double width) {
    return _getIntrinsicSize(
        sizingDirection: Axis.vertical,
        extent: width,
        childSize: (Widget child, double? extent) => child.box!.height);
  }

  double computeMaxIntrinsicHeight(double width) {
    return _getIntrinsicSize(
        sizingDirection: Axis.vertical,
        extent: width,
        childSize: (Widget child, double? extent) => child.box!.height);
  }

  double _getCrossSize(Widget child) {
    switch (direction) {
      case Axis.horizontal:
        return child.box!.height;
      case Axis.vertical:
        return child.box!.width;
    }
  }

  double _getMainSize(Widget child) {
    switch (direction) {
      case Axis.horizontal:
        return child.box!.width;
      case Axis.vertical:
        return child.box!.height;
    }
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    // Determine used flex factor, size inflexible items, calculate free space.
    var totalFlex = 0;
    Widget? lastFlexChild;

    final maxMainSize = direction == Axis.horizontal
        ? constraints.maxWidth
        : constraints.maxHeight;
    final canFlex = maxMainSize < double.infinity;

    var crossSize = 0.0;
    var allocatedSize = 0.0; // Sum of the sizes of the non-flexible children.
    var index = _context.firstChild;

    for (var child in children.sublist(_context.firstChild)) {
      final flex = child is Flexible ? child.flex : 0;
      final fit = child is Flexible ? child.fit : FlexFit.loose;
      if (flex > 0) {
        assert(() {
          final dimension = direction == Axis.horizontal ? 'width' : 'height';
          if (!canFlex &&
              (mainAxisSize == MainAxisSize.max || fit == FlexFit.tight)) {
            throw Exception(
                'Flex children have non-zero flex but incoming $dimension constraints are unbounded.');
          } else {
            return true;
          }
        }());
        totalFlex += flex;
      } else {
        BoxConstraints? innerConstraints;
        if (crossAxisAlignment == CrossAxisAlignment.stretch) {
          switch (direction) {
            case Axis.horizontal:
              innerConstraints = BoxConstraints(
                  minHeight: constraints.maxHeight,
                  maxHeight: constraints.maxHeight);
              break;
            case Axis.vertical:
              innerConstraints = BoxConstraints(
                  minWidth: constraints.maxWidth,
                  maxWidth: constraints.maxWidth);
              break;
          }
        } else {
          switch (direction) {
            case Axis.horizontal:
              innerConstraints =
                  BoxConstraints(maxHeight: constraints.maxHeight);
              break;
            case Axis.vertical:
              innerConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
              break;
          }
        }
        child.layout(context, innerConstraints, parentUsesSize: true);
        assert(child.box != null);
        allocatedSize += _getMainSize(child);
        crossSize = math.max(crossSize, _getCrossSize(child));
        if (direction == Axis.vertical &&
            allocatedSize > constraints.maxHeight) {
          break;
        }
      }
      lastFlexChild = child;
      index++;
    }
    _context.lastChild = index;
    final totalChildren = _context.lastChild - _context.firstChild;

    // Distribute free space to flexible children, and determine baseline.
    final freeSpace =
        math.max(0.0, (canFlex ? maxMainSize : 0.0) - allocatedSize);
    var allocatedFlexSpace = 0.0;
    if (totalFlex > 0) {
      final spacePerFlex =
          canFlex && totalFlex > 0 ? (freeSpace / totalFlex) : double.nan;

      for (var child in children) {
        final flex = child is Flexible ? child.flex : 0;
        final fit = child is Flexible ? child.fit : FlexFit.loose;
        if (flex > 0) {
          final maxChildExtent = canFlex
              ? (child == lastFlexChild
                  ? (freeSpace - allocatedFlexSpace)
                  : spacePerFlex * flex)
              : double.infinity;
          double? minChildExtent;
          switch (fit) {
            case FlexFit.tight:
              assert(maxChildExtent < double.infinity);
              minChildExtent = maxChildExtent;
              break;
            case FlexFit.loose:
              minChildExtent = 0.0;
              break;
          }

          BoxConstraints? innerConstraints;
          if (crossAxisAlignment == CrossAxisAlignment.stretch) {
            switch (direction) {
              case Axis.horizontal:
                innerConstraints = BoxConstraints(
                    minWidth: minChildExtent,
                    maxWidth: maxChildExtent,
                    minHeight: constraints.maxHeight,
                    maxHeight: constraints.maxHeight);
                break;
              case Axis.vertical:
                innerConstraints = BoxConstraints(
                    minWidth: constraints.maxWidth,
                    maxWidth: constraints.maxWidth,
                    minHeight: minChildExtent,
                    maxHeight: maxChildExtent);
                break;
            }
          } else {
            switch (direction) {
              case Axis.horizontal:
                innerConstraints = BoxConstraints(
                    minWidth: minChildExtent,
                    maxWidth: maxChildExtent,
                    maxHeight: constraints.maxHeight);
                break;
              case Axis.vertical:
                innerConstraints = BoxConstraints(
                    maxWidth: constraints.maxWidth,
                    minHeight: minChildExtent,
                    maxHeight: maxChildExtent);
                break;
            }
          }
          child.layout(context, innerConstraints, parentUsesSize: true);
          assert(child.box != null);
          final childSize = _getMainSize(child);
          assert(childSize <= maxChildExtent);
          allocatedSize += childSize;
          allocatedFlexSpace += maxChildExtent;
          crossSize = math.max(crossSize, _getCrossSize(child));
        }
      }
    }

    // Align items along the main axis.
    final idealSize = canFlex && mainAxisSize == MainAxisSize.max
        ? maxMainSize
        : allocatedSize;
    double? actualSize;
    double actualSizeDelta;
    late PdfPoint size;
    switch (direction) {
      case Axis.horizontal:
        size = constraints.constrain(PdfPoint(idealSize, crossSize));
        actualSize = size.x;
        crossSize = size.y;
        break;
      case Axis.vertical:
        size = constraints.constrain(PdfPoint(crossSize, idealSize));
        actualSize = size.y;
        crossSize = size.x;
        break;
    }

    box = PdfRect.fromPoints(PdfPoint.zero, size);
    actualSizeDelta = actualSize - allocatedSize;

    final remainingSpace = math.max(0.0, actualSizeDelta);
    double? leadingSpace;
    late double betweenSpace;
    final flipMainAxis = (verticalDirection == VerticalDirection.down &&
            direction == Axis.vertical) ||
        (verticalDirection == VerticalDirection.up &&
            direction == Axis.horizontal);
    switch (mainAxisAlignment) {
      case MainAxisAlignment.start:
        leadingSpace = 0.0;
        betweenSpace = 0.0;
        break;
      case MainAxisAlignment.end:
        leadingSpace = remainingSpace;
        betweenSpace = 0.0;
        break;
      case MainAxisAlignment.center:
        leadingSpace = remainingSpace / 2.0;
        betweenSpace = 0.0;
        break;
      case MainAxisAlignment.spaceBetween:
        leadingSpace = 0.0;
        betweenSpace =
            totalChildren > 1 ? remainingSpace / (totalChildren - 1) : 0.0;
        break;
      case MainAxisAlignment.spaceAround:
        betweenSpace = totalChildren > 0 ? remainingSpace / totalChildren : 0.0;
        leadingSpace = betweenSpace / 2.0;
        break;
      case MainAxisAlignment.spaceEvenly:
        betweenSpace =
            totalChildren > 0 ? remainingSpace / (totalChildren + 1) : 0.0;
        leadingSpace = betweenSpace;
        break;
    }

    // Position elements
    final flipCrossAxis = (verticalDirection == VerticalDirection.down &&
            direction == Axis.horizontal) ||
        (verticalDirection == VerticalDirection.up &&
            direction == Axis.vertical);
    var childMainPosition =
        flipMainAxis ? actualSize - leadingSpace : leadingSpace;

    for (var child
        in children.sublist(_context.firstChild, _context.lastChild)) {
      double? childCrossPosition;
      switch (crossAxisAlignment) {
        case CrossAxisAlignment.start:
          childCrossPosition =
              flipCrossAxis ? crossSize - _getCrossSize(child) : 0.0;
          break;
        case CrossAxisAlignment.end:
          childCrossPosition =
              !flipCrossAxis ? crossSize - _getCrossSize(child) : 0.0;
          break;
        case CrossAxisAlignment.center:
          childCrossPosition = crossSize / 2.0 - _getCrossSize(child) / 2.0;
          break;
        case CrossAxisAlignment.stretch:
          childCrossPosition = 0.0;
          break;
      }

      if (flipMainAxis) {
        childMainPosition -= _getMainSize(child);
      }
      switch (direction) {
        case Axis.horizontal:
          child.box = PdfRect(box!.x + childMainPosition,
              box!.y + childCrossPosition, child.box!.width, child.box!.height);
          break;
        case Axis.vertical:
          child.box = PdfRect(childCrossPosition, childMainPosition,
              child.box!.width, child.box!.height);
          break;
      }
      if (flipMainAxis) {
        childMainPosition -= betweenSpace;
      } else {
        childMainPosition += _getMainSize(child) + betweenSpace;
      }
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final mat = Matrix4.identity();
    mat.translate(box!.x, box!.y);
    context.canvas
      ..saveContext()
      ..setTransform(mat);

    for (final child
        in children.sublist(_context.firstChild, _context.lastChild)) {
      child.paint(context);
    }
    context.canvas.restoreContext();
  }

  @override
  bool get canSpan => direction == Axis.vertical;

  @override
  bool get hasMoreWidgets => true;

  @override
  void restoreContext(_FlexContext context) {
    _context.firstChild = context.lastChild;
  }

  @override
  WidgetContext saveContext() {
    return _context;
  }
}

class Row extends Flex {
  Row({
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    MainAxisSize mainAxisSize = MainAxisSize.max,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    VerticalDirection verticalDirection = VerticalDirection.down,
    List<Widget> children = const <Widget>[],
  }) : super(
          children: children,
          direction: Axis.horizontal,
          mainAxisAlignment: mainAxisAlignment,
          mainAxisSize: mainAxisSize,
          crossAxisAlignment: crossAxisAlignment,
          verticalDirection: verticalDirection,
        );
}

class Column extends Flex {
  Column({
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    MainAxisSize mainAxisSize = MainAxisSize.max,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    VerticalDirection verticalDirection = VerticalDirection.down,
    List<Widget> children = const <Widget>[],
  }) : super(
          children: children,
          direction: Axis.vertical,
          mainAxisAlignment: mainAxisAlignment,
          mainAxisSize: mainAxisSize,
          crossAxisAlignment: crossAxisAlignment,
          verticalDirection: verticalDirection,
        );
}

/// A widget that controls how a child of a [Row], [Column], or [Flex] flexes.
class Flexible extends SingleChildWidget {
  Flexible({
    this.flex = 1,
    this.fit = FlexFit.loose,
    required Widget child,
  }) : super(child: child);

  /// The flex factor to use for this child
  final int flex;

  /// How a flexible child is inscribed into the available space.
  final FlexFit fit;

  @override
  void paint(Context context) {
    super.paint(context);
    paintChild(context);
  }
}

class Expanded extends Flexible {
  Expanded({
    int flex = 1,
    FlexFit fit = FlexFit.tight,
    required Widget child,
  }) : super(child: child, flex: flex, fit: fit);
}

/// Spacer creates an adjustable, empty spacer that can be used to tune the
/// spacing between widgets in a [Flex] container, like [Row] or [Column].
class Spacer extends Flexible {
  Spacer({int flex = 1})
      : assert(flex > 0),
        super(
          flex: flex,
          fit: FlexFit.tight,
          child: SizedBox.shrink(),
        );
}

typedef IndexedWidgetBuilder = Widget Function(Context context, int index);

class ListView extends StatelessWidget {
  ListView({
    this.direction = Axis.vertical,
    this.reverse = false,
    this.spacing = 0,
    this.padding,
    List<Widget> this.children = const <Widget>[],
  })  : itemBuilder = null,
        separatorBuilder = null,
        itemCount = children.length,
        super();

  ListView.builder({
    this.direction = Axis.vertical,
    this.reverse = false,
    this.spacing = 0,
    this.padding,
    required this.itemBuilder,
    required this.itemCount,
  })   : children = null,
        separatorBuilder = null,
        super();

  ListView.separated({
    this.direction = Axis.vertical,
    this.reverse = false,
    this.padding,
    required this.itemBuilder,
    required this.separatorBuilder,
    required this.itemCount,
  })   : children = null,
        spacing = null,
        super();

  final Axis direction;
  final EdgeInsets? padding;
  final double? spacing;
  final bool reverse;
  final IndexedWidgetBuilder? itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final List<Widget>? children;
  final int itemCount;

  Widget _getItem(Context context, int index) {
    return children == null ? itemBuilder!(context, index) : children![index];
  }

  Widget _getSeparator(Context context, int index) {
    return spacing == null
        ? separatorBuilder!(context, index)
        : direction == Axis.vertical
            ? SizedBox(height: spacing)
            : SizedBox(width: spacing);
  }

  @override
  Widget build(Context context) {
    final _children = <Widget>[];

    if (reverse) {
      for (var index = itemCount - 1; index >= 0; index--) {
        _children.add(_getItem(context, index));
        if (spacing != 0 && index > 0) {
          _children.add(_getSeparator(context, index));
        }
      }
    } else {
      for (var index = 0; index < itemCount; index++) {
        _children.add(_getItem(context, index));
        if (spacing != 0 && index < itemCount - 1) {
          _children.add(_getSeparator(context, index));
        }
      }
    }

    final Widget widget = Flex(
      direction: direction,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      verticalDirection: VerticalDirection.down,
      children: _children,
    );

    if (padding != null) {
      return Padding(
        padding: padding!,
        child: widget,
      );
    }

    return widget;
  }
}

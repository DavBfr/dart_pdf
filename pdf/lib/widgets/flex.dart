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

typedef _ChildSizingFunction = double Function(Widget child, double extent);

class Flex extends MultiChildWidget {
  Flex({
    @required this.direction,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.verticalDirection = VerticalDirection.down,
    List<Widget> children = const <Widget>[],
  })  : assert(direction != null),
        assert(mainAxisAlignment != null),
        assert(mainAxisSize != null),
        assert(crossAxisAlignment != null),
        super(children: children);

  final Axis direction;

  final MainAxisAlignment mainAxisAlignment;

  final MainAxisSize mainAxisSize;

  final CrossAxisAlignment crossAxisAlignment;

  final VerticalDirection verticalDirection;

  double _getIntrinsicSize(
      {Axis sizingDirection,
      double
          extent, // the extent in the direction that isn't the sizing direction
      _ChildSizingFunction
          childSize // a method to find the size in the sizing direction
      }) {
    if (direction == sizingDirection) {
      // INTRINSIC MAIN SIZE
      // Intrinsic main size is the smallest size the flex container can take
      // while maintaining the min/max-content contributions of its flex items.
      double totalFlex = 0;
      double inflexibleSpace = 0;
      double maxFlexFractionSoFar = 0;

      for (Widget child in children) {
        final int flex = child is Expanded ? child.flex : 0;
        totalFlex += flex;
        if (flex > 0) {
          final double flexFraction = childSize(child, extent) / flex;
          maxFlexFractionSoFar = math.max(maxFlexFractionSoFar, flexFraction);
        } else {
          inflexibleSpace += childSize(child, extent);
        }
      }
      return maxFlexFractionSoFar * totalFlex + inflexibleSpace;
    } else {
      // INTRINSIC CROSS SIZE
      // Intrinsic cross size is the max of the intrinsic cross sizes of the
      // children, after the flexible children are fit into the available space,
      // with the children sized using their max intrinsic dimensions.

      // Get inflexible space using the max intrinsic dimensions of fixed children in the main direction.
      final double availableMainSpace = extent;
      int totalFlex = 0;
      double inflexibleSpace = 0;
      double maxCrossSize = 0;
      for (Widget child in children) {
        final int flex = child is Expanded ? child.flex : 0;
        totalFlex += flex;
        double mainSize;
        double crossSize;
        if (flex == 0) {
          switch (direction) {
            case Axis.horizontal:
              mainSize = child.box.width;
              crossSize = childSize(child, mainSize);
              break;
            case Axis.vertical:
              mainSize = child.box.height;
              crossSize = childSize(child, mainSize);
              break;
          }
          inflexibleSpace += mainSize;
          maxCrossSize = math.max(maxCrossSize, crossSize);
        }
      }

      // Determine the spacePerFlex by allocating the remaining available space.
      // When you're over-constrained spacePerFlex can be negative.
      final double spacePerFlex =
          math.max(0, (availableMainSpace - inflexibleSpace) / totalFlex);

      // Size remaining (flexible) items, find the maximum cross size.
      for (Widget child in children) {
        final int flex = child is Expanded ? child.flex : 0;
        if (flex > 0)
          maxCrossSize =
              math.max(maxCrossSize, childSize(child, spacePerFlex * flex));
      }

      return maxCrossSize;
    }
  }

  double computeMinIntrinsicWidth(double height) {
    return _getIntrinsicSize(
        sizingDirection: Axis.horizontal,
        extent: height,
        childSize: (Widget child, double extent) => child.box.width);
  }

  double computeMaxIntrinsicWidth(double height) {
    return _getIntrinsicSize(
        sizingDirection: Axis.horizontal,
        extent: height,
        childSize: (Widget child, double extent) => child.box.width);
  }

  double computeMinIntrinsicHeight(double width) {
    return _getIntrinsicSize(
        sizingDirection: Axis.vertical,
        extent: width,
        childSize: (Widget child, double extent) => child.box.height);
  }

  double computeMaxIntrinsicHeight(double width) {
    return _getIntrinsicSize(
        sizingDirection: Axis.vertical,
        extent: width,
        childSize: (Widget child, double extent) => child.box.height);
  }

  double _getCrossSize(Widget child) {
    switch (direction) {
      case Axis.horizontal:
        return child.box.height;
      case Axis.vertical:
        return child.box.width;
    }
    return null;
  }

  double _getMainSize(Widget child) {
    switch (direction) {
      case Axis.horizontal:
        return child.box.width;
      case Axis.vertical:
        return child.box.height;
    }
    return null;
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    // Determine used flex factor, size inflexible items, calculate free space.
    int totalFlex = 0;
    final int totalChildren = children.length;
    Widget lastFlexChild;
    assert(constraints != null);
    final double maxMainSize = direction == Axis.horizontal
        ? constraints.maxWidth
        : constraints.maxHeight;
    final bool canFlex = maxMainSize < double.infinity;

    double crossSize = 0;
    double allocatedSize = 0; // Sum of the sizes of the non-flexible children.

    for (Widget child in children) {
      final int flex = child is Expanded ? child.flex : 0;
      final FlexFit fit = child is Expanded ? child.fit : FlexFit.loose;
      if (flex > 0) {
        assert(() {
          final String dimension =
              direction == Axis.horizontal ? 'width' : 'height';
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
        BoxConstraints innerConstraints;
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
      }
      lastFlexChild = child;
    }

    // Distribute free space to flexible children, and determine baseline.
    final double freeSpace =
        math.max(0, (canFlex ? maxMainSize : 0.0) - allocatedSize);
    double allocatedFlexSpace = 0;
    if (totalFlex > 0) {
      final double spacePerFlex =
          canFlex && totalFlex > 0 ? (freeSpace / totalFlex) : double.nan;

      for (Widget child in children) {
        final int flex = child is Expanded ? child.flex : 0;
        final FlexFit fit = child is Expanded ? child.fit : FlexFit.loose;
        if (flex > 0) {
          final double maxChildExtent = canFlex
              ? (child == lastFlexChild
                  ? (freeSpace - allocatedFlexSpace)
                  : spacePerFlex * flex)
              : double.infinity;
          double minChildExtent;
          switch (fit) {
            case FlexFit.tight:
              assert(maxChildExtent < double.infinity);
              minChildExtent = maxChildExtent;
              break;
            case FlexFit.loose:
              minChildExtent = 0.0;
              break;
          }
          assert(minChildExtent != null);
          BoxConstraints innerConstraints;
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
          final double childSize = _getMainSize(child);
          assert(childSize <= maxChildExtent);
          allocatedSize += childSize;
          allocatedFlexSpace += maxChildExtent;
          crossSize = math.max(crossSize, _getCrossSize(child));
        }
      }
    }

    // Align items along the main axis.
    final double idealSize = canFlex && mainAxisSize == MainAxisSize.max
        ? maxMainSize
        : allocatedSize;
    double actualSize;
    double actualSizeDelta;
    PdfPoint size;
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

    final double remainingSpace = math.max(0, actualSizeDelta);
    double leadingSpace;
    double betweenSpace;
    final bool flipMainAxis = (verticalDirection == VerticalDirection.down &&
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
    final bool flipCrossAxis = (verticalDirection == VerticalDirection.down &&
            direction == Axis.horizontal) ||
        (verticalDirection == VerticalDirection.up &&
            direction == Axis.vertical);
    double childMainPosition =
        flipMainAxis ? actualSize - leadingSpace : leadingSpace;
    for (Widget child in children) {
      double childCrossPosition;
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
          child.box = PdfRect(box.x + childMainPosition,
              box.y + childCrossPosition, child.box.width, child.box.height);
          break;
        case Axis.vertical:
          child.box = PdfRect(childCrossPosition, childMainPosition,
              child.box.width, child.box.height);
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

class Expanded extends SingleChildWidget {
  Expanded({
    this.flex = 1,
    this.fit = FlexFit.tight,
    @required Widget child,
  }) : super(child: child);

  final int flex;

  final FlexFit fit;

  @override
  void paint(Context context) {
    super.paint(context);
    paintChild(context);
  }
}

class ListView extends Flex {
  ListView(
      {Axis direction = Axis.vertical,
      // EdgeInsets padding,
      // double spacing = 0.0,
      List<Widget> children = const <Widget>[]})
      : super(
            direction: direction,
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            verticalDirection: VerticalDirection.down,
            children: children);
}

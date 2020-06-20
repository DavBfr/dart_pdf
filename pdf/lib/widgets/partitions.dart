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

// ignore_for_file: omit_local_variable_types

part of widget;

class Partition implements SpanningWidget {
  Partition({
    @required this.child,
    this.width,
    int flex = 1,
  })  : flex = width == null ? flex : 0,
        assert(flex != null),
        assert(child != null);

  final double width;

  final int flex;

  final SpanningWidget child;

  @override
  PdfRect get box => child.box;

  @override
  set box(PdfRect value) => child.box = value;

  @override
  bool get canSpan => child.canSpan;

  @override
  void debugPaint(Context context) {
    child.debugPaint(context);
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    child.layout(context, constraints, parentUsesSize: parentUsesSize);
  }

  @override
  void paint(Context context) {
    child.paint(context);
  }

  @override
  void restoreContext(WidgetContext context) {
    child.restoreContext(context);
  }

  @override
  WidgetContext saveContext() {
    return child.saveContext();
  }

  @override
  bool get hasMoreWidgets => child.hasMoreWidgets;
}

class _PartitionsContext extends WidgetContext {
  _PartitionsContext(int count) : partitionContext = List<WidgetContext>(count);

  final List<WidgetContext> partitionContext;

  @override
  void apply(WidgetContext other) {
    if (other is _PartitionsContext) {
      for (int index = 0; index < partitionContext.length; index++) {
        partitionContext[index]?.apply(other.partitionContext[index]);
      }
    }
  }

  @override
  WidgetContext clone() {
    final _PartitionsContext context =
        _PartitionsContext(partitionContext.length);
    for (int index = 0; index < partitionContext.length; index++) {
      context.partitionContext[index] = partitionContext[index].clone();
    }

    return context;
  }
}

class Partitions extends Widget implements SpanningWidget {
  Partitions({
    this.children,
    this.mainAxisSize = MainAxisSize.max,
  })  : _context = _PartitionsContext(children.length),
        super();

  final List<Partition> children;

  final _PartitionsContext _context;

  final MainAxisSize mainAxisSize;

  @override
  bool get canSpan => children.any((Partition part) => part.canSpan);

  @override
  bool get hasMoreWidgets =>
      !children.any((Partition part) => !part.hasMoreWidgets);

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    assert(constraints != null);

    // Determine used flex factor, size inflexible items, calculate free space.
    final double maxMainSize = constraints.maxWidth;
    final bool canFlex = maxMainSize < double.infinity;
    double allocatedSize = 0; // Sum of the sizes of the non-flexible children.
    int totalFlex = 0;
    final List<double> widths = List<double>.filled(children.length, 0);

    // Calculate fixed width columns
    int index = 0;
    for (Partition child in children) {
      if (child.flex > 0) {
        assert(() {
          if (!canFlex) {
            throw Exception(
                'Partition children have non-zero flex but incoming width constraints are unbounded.');
          } else {
            return true;
          }
        }());
        totalFlex += child.flex;
      } else {
        allocatedSize += child.width;
        widths[index] = child.width;
      }
      index++;
    }

    // Distribute free space to flexible children, and determine baseline.
    if (totalFlex > 0 && canFlex) {
      final double freeSpace =
          math.max(0, (canFlex ? maxMainSize : 0.0) - allocatedSize);
      final double spacePerFlex = freeSpace / totalFlex;

      index = 0;
      for (Partition child in children) {
        if (child.flex > 0) {
          final double childExtent = spacePerFlex * child.flex;
          allocatedSize += childExtent;
          widths[index] = childExtent;
        }
        index++;
      }
    }

    // Layout the columns and compute the total height
    double totalHeight = 0;
    index = 0;
    for (Partition child in children) {
      if (widths[index] > 0) {
        final BoxConstraints innerConstraints = BoxConstraints(
            minWidth: widths[index],
            maxWidth: widths[index],
            maxHeight: constraints.maxHeight);

        child.layout(context, innerConstraints);
        assert(child.box != null);
        totalHeight = math.max(totalHeight, child.box.height);
      }
      index++;
    }

    // Update Y positions
    index = 0;
    allocatedSize = 0;
    for (Partition child in children) {
      if (widths[index] > 0) {
        final double offsetY = totalHeight - child.box.height;
        child.box = PdfRect.fromPoints(
            PdfPoint(allocatedSize, offsetY), child.box.size);
        totalHeight = math.max(totalHeight, child.box.height);
        allocatedSize += widths[index];
      }
      index++;
    }

    box = PdfRect(0, 0, allocatedSize, totalHeight);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final Matrix4 mat = Matrix4.identity();
    mat.translate(box.x, box.y);
    context.canvas
      ..saveContext()
      ..setTransform(mat);
    for (Partition child in children) {
      child.paint(context);
    }
    context.canvas.restoreContext();
  }

  @override
  void restoreContext(WidgetContext context) {
    _context.apply(context);
    int index = 0;
    for (final Partition child in children) {
      child.restoreContext(_context.partitionContext[index]);
      index++;
    }
  }

  @override
  WidgetContext saveContext() {
    int index = 0;
    for (final Partition child in children) {
      _context.partitionContext[index] = child.saveContext();
      index++;
    }
    return _context;
  }
}

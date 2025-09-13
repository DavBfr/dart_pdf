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
import '../../widgets.dart';

/// How to size the non-positioned children of a [Stack].
enum StackFit { loose, expand, passthrough }

/// Whether overflowing children should be clipped, or their overflow be
/// visible.
enum Overflow { visible, clip }

/// A widget that controls where a child of a [Stack] is positioned.
class Positioned extends SingleChildWidget {
  Positioned({
    double? left,
    this.top,
    double? right,
    this.bottom,
    required Widget child,
  })  : _left = left,
        _right = right,
        super(child: child);

  /// Creates a Positioned object with left, top, right, and bottom set to 0.0
  /// unless a value for them is passed.
  Positioned.fill({
    double? left = 0.0,
    this.top = 0.0,
    double? right = 0.0,
    this.bottom = 0.0,
    required Widget child,
  })  : _left = left,
        _right = right,
        super(child: child);

  /// Creates a widget that controls where a child of a [Stack] is positioned.
  factory Positioned.directional({
    required TextDirection textDirection,
    double? start,
    double? top,
    double? end,
    double? bottom,
    required Widget child,
  }) {
    double? left;
    double? right;
    switch (textDirection) {
      case TextDirection.rtl:
        left = end;
        right = start;
        break;
      case TextDirection.ltr:
        left = start;
        right = end;
        break;
    }
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: child,
    );
  }

  double? get left => _left;

  double? get right => _right;

  final double? _left;
  final double? _right;

  final double? top;

  final double? bottom;

  double? get width => box?.width;

  double? get height => box?.height;

  @override
  void paint(Context context) {
    super.paint(context);
    paintChild(context);
  }
}

/// A widget that controls where a child of a [Stack] is positioned without
/// committing to a specific [TextDirection].
class PositionedDirectional extends Positioned {
  PositionedDirectional({
    this.start,
    this.end,
    double? top,
    double? bottom,
    required Widget child,
  }) : super(
          child: child,
          top: top,
          bottom: bottom,
        );

  PositionedDirectional.fill({
    this.start = 0.0,
    this.end = 0.0,
    double? top = 0.0,
    double? bottom = 0.0,
    required Widget child,
  }) : super(
          child: child,
          top: top,
          bottom: bottom,
        );

  final double? start;

  double? _resolvedLeft;

  double? _resolvedRight;

  @override
  double? get left => _resolvedLeft;

  @override
  double? get right => _resolvedRight;

  final double? end;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    super.layout(context, constraints, parentUsesSize: parentUsesSize);
    switch (Directionality.of(context)) {
      case TextDirection.rtl:
        _resolvedLeft = end;
        _resolvedRight = start;
        break;
      case TextDirection.ltr:
        _resolvedLeft = start;
        _resolvedRight = end;
        break;
    }
  }
}

/// A widget that positions its children relative to the edges of its box.
class Stack extends MultiChildWidget {
  Stack({
    this.alignment = Alignment.topLeft,
    this.fit = StackFit.loose,
    this.overflow = Overflow.clip,
    List<Widget> children = const <Widget>[],
  }) : super(children: children);

  /// How to align the non-positioned and partially-positioned children in the
  /// stack.
  final AlignmentGeometry alignment;

  /// How to size the non-positioned children in the stack.
  final StackFit fit;

  /// Whether overflowing children should be clipped.
  final Overflow overflow;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final childCount = children.length;

    var hasNonPositionedChildren = false;

    if (childCount == 0) {
      box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
      return;
    }

    var width = constraints.minWidth;
    var height = constraints.minHeight;

    BoxConstraints? nonPositionedConstraints;

    switch (fit) {
      case StackFit.loose:
        nonPositionedConstraints = constraints.loosen();
        break;
      case StackFit.expand:
        nonPositionedConstraints = BoxConstraints.tight(constraints.biggest);
        break;
      case StackFit.passthrough:
        nonPositionedConstraints = constraints;
        break;
    }

    for (final child in children) {
      if (child is! Positioned) {
        hasNonPositionedChildren = true;
        child.layout(context, nonPositionedConstraints, parentUsesSize: true);
        assert(child.box != null);

        final childSize = child.box!;
        width = math.max(width, childSize.width);
        height = math.max(height, childSize.height);
      }
    }

    if (hasNonPositionedChildren) {
      box = PdfRect.fromPoints(PdfPoint.zero, PdfPoint(width, height));
      assert(box!.width == constraints.constrainWidth(width));
      assert(box!.height == constraints.constrainHeight(height));
    } else {
      box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
    }
    final resolvedAlignment = alignment.resolve(Directionality.of(context));
    for (final child in children) {
      if (child is! Positioned) {
        child.box = PdfRect.fromPoints(
            resolvedAlignment.inscribe(child.box!.size, box!).offset,
            child.box!.size);
      } else {
        final positioned = child;

        var childConstraints = const BoxConstraints();

        if (positioned.left != null && positioned.right != null) {
          childConstraints = childConstraints.tighten(
              width: box!.width - positioned.right! - positioned.left!);
        } else if (positioned.width != null) {
          childConstraints = childConstraints.tighten(width: positioned.width);
        }

        if (positioned.top != null && positioned.bottom != null) {
          childConstraints = childConstraints.tighten(
              height: box!.height - positioned.bottom! - positioned.top!);
        } else if (positioned.height != null) {
          childConstraints =
              childConstraints.tighten(height: positioned.height);
        }

        positioned.layout(context, childConstraints, parentUsesSize: true);
        assert(positioned.box != null);

        double? x;
        if (positioned.left != null) {
          x = positioned.left;
        } else if (positioned.right != null) {
          x = box!.width - positioned.right! - positioned.width!;
        } else {
          x = resolvedAlignment.inscribe(positioned.box!.size, box!).left;
        }

        double? y;
        if (positioned.bottom != null) {
          y = positioned.bottom;
        } else if (positioned.top != null) {
          y = box!.height - positioned.top! - positioned.height!;
        } else {
          y = resolvedAlignment.inscribe(positioned.box!.size, box!).bottom;
        }

        positioned.box =
            PdfRect.fromPoints(PdfPoint(x!, y!), positioned.box!.size);
      }
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final mat = Matrix4.identity();
    mat.translateByDouble(box!.left, box!.bottom, 0, 1);
    context.canvas
      ..saveContext()
      ..setTransform(mat);
    if (overflow == Overflow.clip) {
      context.canvas
        ..drawRect(0, 0, box!.width, box!.height)
        ..clipPath();
    }
    for (final child in children) {
      child.paint(context);
    }
    context.canvas.restoreContext();
  }
}

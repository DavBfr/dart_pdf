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

import 'geometry.dart';
import 'widget.dart';

/// How to size the non-positioned children of a [Stack].
enum StackFit { loose, expand, passthrough }

/// Whether overflowing children should be clipped, or their overflow be
/// visible.
enum Overflow { visible, clip }

/// A widget that controls where a child of a [Stack] is positioned.
class Positioned extends SingleChildWidget {
  Positioned({
    this.left,
    this.top,
    this.right,
    this.bottom,
    required Widget child,
  }) : super(child: child);

  final double? left;

  final double? top;

  final double? right;

  final double? bottom;

  double? get width => box?.width;

  double? get height => box?.height;

  @override
  void paint(Context context) {
    super.paint(context);
    paintChild(context);
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
  final Alignment alignment;

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

    for (var child in children) {
      if (!(child is Positioned)) {
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

    for (var child in children) {
      if (!(child is Positioned)) {
        child.box = PdfRect.fromPoints(
            alignment.inscribe(child.box!.size, box!).offset, child.box!.size);
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
          x = alignment.inscribe(positioned.box!.size, box!).x;
        }

        double? y;
        if (positioned.bottom != null) {
          y = positioned.bottom;
        } else if (positioned.top != null) {
          y = box!.height - positioned.top! - positioned.height!;
        } else {
          y = alignment.inscribe(positioned.box!.size, box!).y;
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
    mat.translate(box!.x, box!.y);
    context.canvas
      ..saveContext()
      ..setTransform(mat);
    if (overflow == Overflow.clip) {
      context.canvas
        ..drawRect(0, 0, box!.width, box!.height)
        ..clipPath();
    }
    for (var child in children) {
      child.paint(context);
    }
    context.canvas.restoreContext();
  }
}

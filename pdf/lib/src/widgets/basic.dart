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

import 'package:pdf/widgets.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../pdf.dart';
import 'box_border.dart';
import 'container.dart';
import 'decoration.dart';
import 'geometry.dart';
import 'widget.dart';

enum BoxFit { fill, contain, cover, fitWidth, fitHeight, none, scaleDown }

class LimitedBox extends SingleChildWidget {
  LimitedBox({
    this.maxWidth = double.infinity,
    this.maxHeight = double.infinity,
    Widget? child,
  })  : assert(maxWidth >= 0.0),
        assert(maxHeight >= 0.0),
        super(child: child);

  final double maxWidth;

  final double maxHeight;

  BoxConstraints _limitConstraints(BoxConstraints constraints) {
    return BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: constraints.hasBoundedWidth
            ? constraints.maxWidth
            : constraints.constrainWidth(maxWidth),
        minHeight: constraints.minHeight,
        maxHeight: constraints.hasBoundedHeight
            ? constraints.maxHeight
            : constraints.constrainHeight(maxHeight));
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    PdfPoint size;
    if (child != null) {
      child!.layout(context, _limitConstraints(constraints),
          parentUsesSize: true);
      assert(child!.box != null);
      size = constraints.constrain(child!.box!.size);
    } else {
      size = _limitConstraints(constraints).smallest;
    }
    box = PdfRect.fromPoints(PdfPoint.zero, size);
  }

  @override
  void paint(Context context) {
    super.paint(context);
    paintChild(context);
  }
}

class Padding extends SingleChildWidget {
  Padding({
    required this.padding,
    Widget? child,
  }) : super(child: child);

  final EdgeInsetsGeometry padding;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
      final effectivePadding = padding.resolve(Directionality.of(context));
    if (child != null) {
      final childConstraints = constraints.deflate(effectivePadding);
      child!.layout(context, childConstraints, parentUsesSize: parentUsesSize);
      assert(child!.box != null);
      box = constraints.constrainRect(
          width: child!.box!.width + effectivePadding.horizontal,
          height: child!.box!.height + effectivePadding.vertical);
    } else {
      box = constraints.constrainRect(
          width: effectivePadding.horizontal, height: effectivePadding.vertical);
    }
  }

  @override
  void debugPaint(Context context) {
    final effectivePadding = padding.resolve(Directionality.of(context));
    context.canvas
      ..setFillColor(PdfColors.lime)
      ..moveTo(box!.x, box!.y)
      ..lineTo(box!.right, box!.y)
      ..lineTo(box!.right, box!.top)
      ..lineTo(box!.x, box!.top)
      ..moveTo(box!.x + effectivePadding.left, box!.y + effectivePadding.bottom)
      ..lineTo(box!.x + effectivePadding.left, box!.top - effectivePadding.top)
      ..lineTo(box!.right - effectivePadding.right, box!.top - effectivePadding.top)
      ..lineTo(box!.right - effectivePadding.right, box!.y + effectivePadding.bottom)
      ..fillPath();
  }

  @override
  void paint(Context context) {
    super.paint(context);
  final effectivePadding = padding.resolve(Directionality.of(context));
    if (child != null) {
      final mat = Matrix4.identity();
      mat.translate(box!.x + effectivePadding.left, box!.y + effectivePadding.bottom);
      context.canvas
        ..saveContext()
        ..setTransform(mat);
      child!.paint(context);
      context.canvas.restoreContext();
    }
  }
}

class Transform extends SingleChildWidget {
  Transform({
    required this.transform,
    this.origin,
    this.alignment,
    this.adjustLayout = false,
    this.unconstrained = false,
    Widget? child,
  }) : super(child: child);

  /// Creates a widget that transforms its child using a rotation around the
  /// center.
  Transform.rotate({
    required double angle,
    this.origin,
    this.alignment = Alignment.center,
    Widget? child,
  })  : transform = Matrix4.rotationZ(angle),
        adjustLayout = false,
        unconstrained = false,
        super(child: child);

  /// Creates a widget that transforms its child using a rotation around the
  /// center and relayout the bounding box.
  Transform.rotateBox({
    required double angle,
    Widget? child,
    this.unconstrained = false,
  })  : transform = Matrix4.rotationZ(angle),
        adjustLayout = true,
        alignment = null,
        origin = null,
        super(child: child);

  /// Creates a widget that transforms its child using a translation.
  Transform.translate({
    required PdfPoint offset,
    Widget? child,
  })  : transform = Matrix4.translationValues(offset.x, offset.y, 0),
        origin = null,
        alignment = null,
        adjustLayout = false,
        unconstrained = false,
        super(child: child);

  /// Creates a widget that scales its child uniformly.
  Transform.scale({
    required double scale,
    this.origin,
    this.alignment = Alignment.center,
    Widget? child,
  })  : transform = Matrix4.diagonal3Values(scale, scale, 1),
        adjustLayout = false,
        unconstrained = false,
        super(child: child);

  /// The matrix to transform the child by during painting.
  final Matrix4 transform;

  /// The origin of the coordinate system
  final PdfPoint? origin;

  /// The alignment of the origin, relative to the size of the box.
  final Alignment? alignment;

  final bool adjustLayout;

  final bool unconstrained;

  Matrix4 get _effectiveTransform {
    final result = Matrix4.identity();
    if (origin != null) {
      result.translate(origin!.x, origin!.y);
    }
    result.translate(box!.x, box!.y);
    late PdfPoint translation;
    if (alignment != null) {
      translation = alignment!.alongSize(box!.size);
      result.translate(translation.x, translation.y);
    }
    result.multiply(transform);
    if (alignment != null) {
      result.translate(-translation.x, -translation.y);
    }
    if (origin != null) {
      result.translate(-origin!.x, -origin!.y);
    }
    return result;
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    if (!adjustLayout) {
      return super.layout(context, constraints, parentUsesSize: parentUsesSize);
    }

    if (child != null) {
      child!.layout(
        context,
        unconstrained ? const BoxConstraints() : constraints,
        parentUsesSize: parentUsesSize,
      );
      assert(child!.box != null);

      final mat = transform;
      final values = mat.applyToVector3Array(<double>[
        child!.box!.left,
        child!.box!.top,
        0,
        child!.box!.right,
        child!.box!.top,
        0,
        child!.box!.right,
        child!.box!.bottom,
        0,
        child!.box!.left,
        child!.box!.bottom,
        0,
      ]);

      final dx = -math.min(
          math.min(math.min(values[0], values[3]), values[6]), values[9]);
      final dy = -math.min(
          math.min(math.min(values[1], values[4]), values[7]), values[10]);

      box = PdfRect.fromLTRB(
        0,
        0,
        math.max(math.max(math.max(values[0], values[3]), values[6]),
                values[9]) +
            dx,
        math.max(math.max(math.max(values[1], values[4]), values[7]),
                values[10]) +
            dy,
      );

      transform.leftTranslate(dx, dy);
    } else {
      box = PdfRect.fromPoints(PdfPoint.zero, constraints.smallest);
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);

    if (child != null) {
      final mat = _effectiveTransform;
      context.canvas
        ..saveContext()
        ..setTransform(mat);
      child!.paint(context);
      context.canvas.restoreContext();
    }
  }
}

/// A widget that aligns its child within itself and optionally sizes itself
/// based on the child's size.
class Align extends SingleChildWidget {
  Align(
      {this.alignment = Alignment.center,
      this.widthFactor,
      this.heightFactor,
      Widget? child})
      : assert(widthFactor == null || widthFactor >= 0.0),
        assert(heightFactor == null || heightFactor >= 0.0),
        super(child: child);

  /// How to align the child.
  final Alignment alignment;

  /// If non-null, sets its width to the child's width multiplied by this factor.
  final double? widthFactor;

  /// If non-null, sets its height to the child's height multiplied by this factor.
  final double? heightFactor;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final shrinkWrapWidth =
        widthFactor != null || constraints.maxWidth == double.infinity;
    final shrinkWrapHeight =
        heightFactor != null || constraints.maxHeight == double.infinity;

    if (child != null) {
      child!.layout(context, constraints.loosen(), parentUsesSize: true);
      assert(child!.box != null);

      box = constraints.constrainRect(
          width: shrinkWrapWidth
              ? child!.box!.width * (widthFactor ?? 1.0)
              : double.infinity,
          height: shrinkWrapHeight
              ? child!.box!.height * (heightFactor ?? 1.0)
              : double.infinity);

      child!.box = alignment.inscribe(child!.box!.size, box!);
    } else {
      box = constraints.constrainRect(
          width: shrinkWrapWidth ? 0.0 : double.infinity,
          height: shrinkWrapHeight ? 0.0 : double.infinity);
    }
  }

  @override
  void debugPaint(Context context) {
    context.canvas
      ..setStrokeColor(PdfColors.green)
      ..setLineWidth(1)
      ..drawBox(box!);

    if (child == null) {
      context.canvas.strokePath();
      return;
    }

    if (child!.box!.bottom > 0) {
      final headSize = math.min(child!.box!.bottom * 0.2, 10);
      context.canvas
        ..moveTo(
          box!.left + child!.box!.horizontalCenter,
          box!.bottom,
        )
        ..lineTo(box!.left + child!.box!.horizontalCenter,
            box!.bottom + child!.box!.bottom)
        ..lineTo(box!.left + child!.box!.horizontalCenter - headSize,
            box!.bottom + child!.box!.bottom - headSize)
        ..moveTo(box!.left + child!.box!.horizontalCenter,
            box!.bottom + child!.box!.bottom)
        ..lineTo(box!.left + child!.box!.horizontalCenter + headSize,
            box!.bottom + child!.box!.bottom - headSize);
    }

    if (box!.bottom + child!.box!.top < box!.top) {
      final headSize =
          math.min((box!.top - child!.box!.top - box!.bottom) * 0.2, 10);
      context.canvas
        ..moveTo(box!.left + child!.box!.horizontalCenter, box!.top)
        ..lineTo(box!.left + child!.box!.horizontalCenter,
            box!.bottom + child!.box!.top)
        ..lineTo(box!.left + child!.box!.horizontalCenter - headSize,
            box!.bottom + child!.box!.top + headSize)
        ..moveTo(box!.left + child!.box!.horizontalCenter,
            box!.bottom + child!.box!.top)
        ..lineTo(box!.left + child!.box!.horizontalCenter + headSize,
            box!.bottom + child!.box!.top + headSize);
    }

    if (child!.box!.left > 0) {
      final headSize = math.min(child!.box!.left * 0.2, 10);
      context.canvas
        ..moveTo(box!.left, box!.bottom + child!.box!.verticalCenter)
        ..lineTo(box!.left + child!.box!.left,
            box!.bottom + child!.box!.verticalCenter)
        ..lineTo(box!.left + child!.box!.left - headSize,
            box!.bottom + child!.box!.verticalCenter - headSize)
        ..moveTo(box!.left + child!.box!.left,
            box!.bottom + child!.box!.verticalCenter)
        ..lineTo(box!.left + child!.box!.left - headSize,
            box!.bottom + child!.box!.verticalCenter + headSize);
    }

    if (box!.left + child!.box!.right < box!.right) {
      final headSize =
          math.min((box!.right - child!.box!.right - box!.left) * 0.2, 10);
      context.canvas
        ..moveTo(box!.right, box!.bottom + child!.box!.verticalCenter)
        ..lineTo(box!.left + child!.box!.right,
            box!.bottom + child!.box!.verticalCenter)
        ..lineTo(box!.left + child!.box!.right + headSize,
            box!.bottom + child!.box!.verticalCenter - headSize)
        ..moveTo(box!.left + child!.box!.right,
            box!.bottom + child!.box!.verticalCenter)
        ..lineTo(box!.left + child!.box!.right + headSize,
            box!.bottom + child!.box!.verticalCenter + headSize);
    }

    context.canvas.strokePath();
  }

  @override
  void paint(Context context) {
    super.paint(context);
    paintChild(context);
  }
}

/// A widget that imposes additional constraints on its child.
class ConstrainedBox extends SingleChildWidget {
  ConstrainedBox({required this.constraints, Widget? child})
      : super(child: child);

  /// The additional constraints to impose on the child.
  final BoxConstraints constraints;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    if (child != null) {
      child!.layout(context, this.constraints.enforce(constraints),
          parentUsesSize: true);
      assert(child!.box != null);
      box = child!.box;
    } else {
      box = PdfRect.fromPoints(
          PdfPoint.zero, this.constraints.enforce(constraints).smallest);
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);
    paintChild(context);
  }
}

class Center extends Align {
  Center({double? widthFactor, double? heightFactor, Widget? child})
      : super(
            widthFactor: widthFactor, heightFactor: heightFactor, child: child);
}

/// Scales and positions its child within itself according to [fit].
class FittedBox extends SingleChildWidget {
  FittedBox({
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    Widget? child,
  }) : super(child: child);

  /// How to inscribe the child into the space allocated during layout.
  final BoxFit fit;

  /// How to align the child within its parent's bounds.
  final Alignment alignment;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    PdfPoint size;
    if (child != null) {
      child!.layout(context, const BoxConstraints(), parentUsesSize: true);
      assert(child!.box != null);
      size = constraints
          .constrainSizeAndAttemptToPreserveAspectRatio(child!.box!.size);
    } else {
      size = constraints.smallest;
    }
    box = PdfRect.fromPoints(PdfPoint.zero, size);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    if (child != null) {
      final childSize = child!.box!.size;
      final sizes = applyBoxFit(fit, childSize, box!.size);
      final scaleX = sizes.destination!.x / sizes.source!.x;
      final scaleY = sizes.destination!.y / sizes.source!.y;
      final sourceRect = alignment.inscribe(
          sizes.source!, PdfRect.fromPoints(PdfPoint.zero, childSize));
      final destinationRect = alignment.inscribe(sizes.destination!, box!);

      final mat =
          Matrix4.translationValues(destinationRect.x, destinationRect.y, 0)
            ..scale(scaleX, scaleY, 1)
            ..translate(-sourceRect.x, -sourceRect.y);

      context.canvas
        ..saveContext()
        ..drawBox(box!)
        ..clipPath()
        ..setTransform(mat);
      child!.paint(context);
      context.canvas.restoreContext();
    }
  }
}

class AspectRatio extends SingleChildWidget {
  AspectRatio({required this.aspectRatio, Widget? child}) : super(child: child);

  /// The aspect ratio to attempt to use.
  final double aspectRatio;

  PdfPoint _applyAspectRatio(BoxConstraints constraints) {
    if (constraints.isTight) {
      return constraints.smallest;
    }

    var width = constraints.maxWidth;
    double? height;

    if (width.isFinite) {
      height = width / aspectRatio;
    } else {
      height = constraints.maxHeight;
      width = height * aspectRatio;
    }

    if (width > constraints.maxWidth) {
      width = constraints.maxWidth;
      height = width / aspectRatio;
    }

    if (height > constraints.maxHeight) {
      height = constraints.maxHeight;
      width = height * aspectRatio;
    }

    if (width < constraints.minWidth) {
      width = constraints.minWidth;
      height = width / aspectRatio;
    }

    if (height < constraints.minHeight) {
      height = constraints.minHeight;
      width = height * aspectRatio;
    }

    return constraints.constrain(PdfPoint(width, height));
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, _applyAspectRatio(constraints));
    if (child != null) {
      child!.layout(context,
          BoxConstraints.tightFor(width: box!.width, height: box!.height));
    }
    assert(child!.box != null);
  }

  @override
  void paint(Context context) {
    super.paint(context);
    paintChild(context);
  }
}

typedef CustomPainter = Function(PdfGraphics canvas, PdfPoint size);

class CustomPaint extends SingleChildWidget {
  CustomPaint({
    this.painter,
    this.foregroundPainter,
    this.size = PdfPoint.zero,
    Widget? child,
  }) : super(child: child);

  final CustomPainter? painter;
  final CustomPainter? foregroundPainter;
  final PdfPoint size;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    if (child != null) {
      child!.layout(context, constraints, parentUsesSize: parentUsesSize);
      assert(child!.box != null);
      box = child!.box;
    } else {
      box = PdfRect.fromPoints(PdfPoint.zero, constraints.constrain(size));
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
    if (painter != null) {
      painter!(context.canvas, box!.size);
    }
    if (child != null) {
      child!.paint(context);
    }
    if (foregroundPainter != null) {
      foregroundPainter!(context.canvas, box!.size);
    }
    context.canvas.restoreContext();
  }
}

/// A box with a specified size.
class SizedBox extends StatelessWidget {
  /// Creates a fixed size box.
  SizedBox({this.width, this.height, this.child});

  /// Creates a box that will become as large as its parent allows.
  SizedBox.expand({this.child})
      : width = double.infinity,
        height = double.infinity;

  /// Creates a box that will become as small as its parent allows.
  SizedBox.shrink({this.child})
      : width = 0.0,
        height = 0.0;

  /// Creates a box with the specified size.
  SizedBox.fromSize({this.child, PdfPoint? size})
      : width = size?.x,
        height = size?.y;

  /// Creates a box whose width and height are equal.
  SizedBox.square({this.child, double? dimension})
      : width = dimension,
        height = dimension;

  /// If non-null, requires the child to have exactly this width.
  final double? width;

  /// If non-null, requires the child to have exactly this height.
  final double? height;

  final Widget? child;

  @override
  Widget build(Context context) {
    return ConstrainedBox(
        child: child,
        constraints: BoxConstraints.tightFor(width: width, height: height));
  }
}

typedef WidgetBuilder = Widget Function(Context context);

/// A platonic widget that calls a closure to obtain its child widget.
class Builder extends StatelessWidget {
  /// Creates a widget that delegates its build to a callback.
  ///
  /// The [builder] argument must not be null.
  Builder({
    required this.builder,
  }) : super();

  /// Called to obtain the child widget.
  final WidgetBuilder builder;

  @override
  Widget build(Context context) => builder(context);
}

/// The signature of the [LayoutBuilder] builder function.
typedef LayoutWidgetBuilder = Widget Function(
    Context context, BoxConstraints? constraints);

/// Builds a widget tree that can depend on the parent widget's size.
class LayoutBuilder extends StatelessWidget {
  /// Creates a widget that defers its building until layout.
  LayoutBuilder({
    required this.builder,
  });

  /// Called at layout time to construct the widget tree.
  final LayoutWidgetBuilder builder;

  BoxConstraints? _constraints;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    _constraints = constraints;
    super.layout(context, constraints);
  }

  @override
  Widget build(Context context) => builder(context, _constraints);
}

class FullPage extends SingleChildWidget {
  FullPage({
    required this.ignoreMargins,
    Widget? child,
  }) : super(child: child);

  final bool ignoreMargins;

  BoxConstraints _getConstraints(Context context) {
    assert(context.page.pageFormat.width != double.infinity);
    assert(context.page.pageFormat.height != double.infinity);

    return ignoreMargins
        ? BoxConstraints.tightFor(
            width: context.page.pageFormat.width,
            height: context.page.pageFormat.height,
          )
        : BoxConstraints.tightFor(
            width: context.page.pageFormat.availableWidth,
            height: context.page.pageFormat.availableHeight,
          );
  }

  PdfRect _getBox(Context context) {
    final box = _getConstraints(context).constrainRect();
    if (ignoreMargins) {
      return box;
    }

    return PdfRect.fromPoints(
        PdfPoint(
          context.page.pageFormat.marginLeft,
          context.page.pageFormat.marginTop,
        ),
        box.size);
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final constraints = _getConstraints(context);

    if (child != null) {
      child!.layout(context, constraints, parentUsesSize: false);
      assert(child!.box != null);
    }

    box = _getBox(context);
  }

  @override
  void debugPaint(Context context) {}

  @override
  void paint(Context context) {
    super.paint(context);

    if (child == null) {
      return;
    }

    final box = _getBox(context);
    final mat = Matrix4.tryInvert(context.canvas.getTransform())!;
    mat.translate(box.x, box.y);
    context.canvas
      ..saveContext()
      ..setTransform(mat);
    child!.paint(context);
    context.canvas.restoreContext();
  }
}

class Opacity extends SingleChildWidget {
  Opacity({
    required this.opacity,
    Widget? child,
  }) : super(child: child);

  final double opacity;

  @override
  void paint(Context context) {
    super.paint(context);

    if (child != null) {
      final mat = Matrix4.identity();
      mat.translate(box!.x, box!.y);
      context.canvas
        ..saveContext()
        ..setTransform(mat)
        ..setGraphicState(PdfGraphicState(opacity: opacity));
      child!.paint(context);
      context.canvas.restoreContext();
    }
  }
}

class Divider extends StatelessWidget {
  Divider({
    this.height,
    this.thickness,
    this.indent,
    this.endIndent,
    this.color,
    this.borderStyle,
  })  : assert(height == null || height >= 0.0),
        assert(thickness == null || thickness >= 0.0),
        assert(indent == null || indent >= 0.0),
        assert(endIndent == null || endIndent >= 0.0);

  /// The color to use when painting the line.
  final PdfColor? color;

  /// The amount of empty space to the trailing edge of the divider.
  final double? endIndent;

  /// The divider's height extent.
  final double? height;

  /// The amount of empty space to the leading edge of the divider.
  final double? indent;

  /// The thickness of the line drawn within the divider.
  final double? thickness;

  /// The border style of the divider
  final BorderStyle? borderStyle;

  @override
  Widget build(Context context) {
    final height = this.height ?? 16;
    final thickness = this.thickness ?? 1;
    final indent = this.indent ?? 0;
    final endIndent = this.endIndent ?? 0;
    final color = this.color ?? PdfColors.black;
    final borderStyle = this.borderStyle ?? BorderStyle.solid;

    return SizedBox(
      height: height,
      child: Center(
        child: Container(
          height: thickness,
          margin: EdgeInsets.only(left: indent, right: endIndent),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: color,
                width: thickness,
                style: borderStyle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VerticalDivider extends StatelessWidget {
  VerticalDivider({
    this.width,
    this.thickness,
    this.indent,
    this.endIndent,
    this.color,
    this.borderStyle,
  })  : assert(width == null || width >= 0.0),
        assert(thickness == null || thickness >= 0.0),
        assert(indent == null || indent >= 0.0),
        assert(endIndent == null || endIndent >= 0.0);

  /// The color to use when painting the line.
  final PdfColor? color;

  /// The amount of empty space to the trailing edge of the divider.
  final double? endIndent;

  /// The divider's width extent.
  final double? width;

  /// The amount of empty space to the leading edge of the divider.
  final double? indent;

  /// The thickness of the line drawn within the divider.
  final double? thickness;

  /// The border style of the divider
  final BorderStyle? borderStyle;

  @override
  Widget build(Context context) {
    final width = this.width ?? 16;
    final thickness = this.thickness ?? 1;
    final indent = this.indent ?? 0;
    final endIndent = this.endIndent ?? 0;
    final color = this.color ?? PdfColors.black;
    final borderStyle = this.borderStyle ?? BorderStyle.solid;

    return SizedBox(
      width: width,
      child: Center(
        child: Container(
          width: thickness,
          margin: EdgeInsets.only(top: indent, bottom: endIndent),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: color,
                width: thickness,
                style: borderStyle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OverflowBox extends SingleChildWidget {
  /// Creates a widget that lets its child overflow itself.
  OverflowBox({
    this.alignment = Alignment.center,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    Widget? child,
  }) : super(child: child);

  /// How to align the child.
  final Alignment alignment;

  /// The minimum width constraint to give the child. Set this to null (the
  /// default) to use the constraint from the parent instead.
  final double? minWidth;

  /// The maximum width constraint to give the child. Set this to null (the
  /// default) to use the constraint from the parent instead.
  final double? maxWidth;

  /// The minimum height constraint to give the child. Set this to null (the
  /// default) to use the constraint from the parent instead.
  final double? minHeight;

  /// The maximum height constraint to give the child. Set this to null (the
  /// default) to use the constraint from the parent instead.
  final double? maxHeight;

  BoxConstraints _getInnerConstraints(BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: minWidth ?? constraints.minWidth,
      maxWidth: maxWidth ?? constraints.maxWidth,
      minHeight: minHeight ?? constraints.minHeight,
      maxHeight: maxHeight ?? constraints.maxHeight,
    );
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, constraints.smallest);

    if (child != null) {
      child!.layout(context, _getInnerConstraints(constraints),
          parentUsesSize: true);
      assert(child!.box != null);
      child!.box = alignment.inscribe(child!.box!.size, box!);
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);
    paintChild(context);
  }
}

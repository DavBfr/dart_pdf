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

import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';

import 'border_radius.dart';
import 'decoration.dart';
import 'widget.dart';

enum BorderStyle { none, solid, dashed, dotted }

@immutable
abstract class BoxBorder {
  @Deprecated('Use Border instead')
  factory BoxBorder({
    bool left = false,
    bool top = false,
    bool right = false,
    bool bottom = false,
    PdfColor color = PdfColors.black,
    double width = 1.0,
    BorderStyle style = BorderStyle.solid,
  }) {
    assert(color != null);
    assert(width != null);
    assert(width >= 0.0);
    assert(style != null);

    return Border(
        top: BorderSide(
            color: color, width: width, style: top ? style : BorderStyle.none),
        bottom: BorderSide(
            color: color,
            width: width,
            style: bottom ? style : BorderStyle.none),
        left: BorderSide(
            color: color, width: width, style: left ? style : BorderStyle.none),
        right: BorderSide(
            color: color,
            width: width,
            style: right ? style : BorderStyle.none));
  }

  const BoxBorder.P();

  BorderSide get top;
  BorderSide get bottom;
  BorderSide get left;
  BorderSide get right;

  bool get isUniform;

  void paint(
    Context context,
    PdfRect box, {
    BoxShape shape = BoxShape.rectangle,
    BorderRadius borderRadius,
  });

  static void _setStyle(Context context, BorderStyle style) {
    switch (style) {
      case BorderStyle.none:
      case BorderStyle.solid:
        break;
      case BorderStyle.dashed:
        context.canvas
          ..saveContext()
          ..setLineDashPattern(const <int>[3, 3]);
        break;
      case BorderStyle.dotted:
        context.canvas
          ..saveContext()
          ..setLineDashPattern(const <int>[1, 1]);
        break;
    }
  }

  static void _unsetStyle(Context context, BorderStyle style) {
    switch (style) {
      case BorderStyle.none:
      case BorderStyle.solid:
        break;
      case BorderStyle.dashed:
      case BorderStyle.dotted:
        context.canvas.restoreContext();
        break;
    }
  }

  static void _paintUniformBorderWithCircle(
      Context context, PdfRect box, BorderSide side) {
    _setStyle(context, side.style);
    context.canvas
      ..setStrokeColor(side.color)
      ..setLineWidth(side.width)
      ..drawEllipse(box.x + box.width / 2.0, box.y + box.height / 2.0,
          box.width / 2.0, box.height / 2.0)
      ..strokePath();
    _unsetStyle(context, side.style);
  }

  static void _paintUniformBorderWithRadius(Context context, PdfRect box,
      BorderSide side, BorderRadius borderRadius) {
    _setStyle(context, side.style);
    context.canvas
      ..setStrokeColor(side.color)
      ..setLineWidth(side.width);
    borderRadius.paint(context, box);
    context.canvas.strokePath();
    _unsetStyle(context, side.style);
  }

  static void _paintUniformBorderWithRectangle(
      Context context, PdfRect box, BorderSide side) {
    _setStyle(context, side.style);
    context.canvas
      ..setStrokeColor(side.color)
      ..setLineWidth(side.width)
      ..drawBox(box)
      ..strokePath();
    _unsetStyle(context, side.style);
  }
}

/// A side of a border of a box.
class BorderSide {
  /// Creates the side of a border.
  const BorderSide({
    this.color = PdfColors.black,
    this.width = 1.0,
    this.style = BorderStyle.solid,
  });

  /// A hairline black border that is not rendered.
  static const BorderSide none =
      BorderSide(width: 0.0, style: BorderStyle.none);

  /// The color of this side of the border.
  final PdfColor color;

  /// The width of this side of the border.
  final double width;

  /// The style of this side of the border.
  final BorderStyle style;

  BorderSide copyWith({
    PdfColor color,
    double width,
    BorderStyle style,
  }) =>
      BorderSide(
        color: color,
        width: width,
        style: style,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is BorderSide &&
        other.color == color &&
        other.width == width &&
        other.style == style;
  }

  @override
  int get hashCode => color.hashCode + width.hashCode + style.hashCode;
}

/// A border of a box, comprised of four sides: top, right, bottom, left.
class Border extends BoxBorder {
  const Border({
    this.top = BorderSide.none,
    this.right = BorderSide.none,
    this.bottom = BorderSide.none,
    this.left = BorderSide.none,
  })  : assert(top != null),
        assert(right != null),
        assert(bottom != null),
        assert(left != null),
        super.P();

  /// A uniform border with all sides the same color and width.
  factory Border.all({
    PdfColor color = PdfColors.black,
    double width = 1.0,
    BorderStyle style = BorderStyle.solid,
  }) =>
      Border.fromBorderSide(
        BorderSide(color: color, width: width, style: style),
      );

  /// Creates a border whose sides are all the same.
  const Border.fromBorderSide(BorderSide side)
      : assert(side != null),
        top = side,
        right = side,
        bottom = side,
        left = side,
        super.P();

  /// Creates a border with symmetrical vertical and horizontal sides.
  const Border.symmetric({
    BorderSide vertical = BorderSide.none,
    BorderSide horizontal = BorderSide.none,
  })  : assert(vertical != null),
        assert(horizontal != null),
        left = vertical,
        top = horizontal,
        right = vertical,
        bottom = horizontal,
        super.P();

  @override
  final BorderSide top;

  @override
  final BorderSide bottom;

  @override
  final BorderSide left;

  @override
  final BorderSide right;

  @override
  bool get isUniform => top == bottom && bottom == left && left == right;

  @override
  void paint(
    Context context,
    PdfRect box, {
    BoxShape shape = BoxShape.rectangle,
    BorderRadius borderRadius,
  }) {
    assert(box.x != null);
    assert(box.y != null);
    assert(box.width != null);
    assert(box.height != null);

    if (isUniform) {
      if (top.style == BorderStyle.none) {
        return;
      }

      switch (shape) {
        case BoxShape.circle:
          assert(borderRadius == null,
              'A borderRadius can only be given for rectangular boxes.');
          BoxBorder._paintUniformBorderWithCircle(context, box, top);
          break;
        case BoxShape.rectangle:
          if (borderRadius != null) {
            BoxBorder._paintUniformBorderWithRadius(
                context, box, top, borderRadius);
            return;
          }
          BoxBorder._paintUniformBorderWithRectangle(context, box, top);
          break;
      }
      return;
    }

    context.canvas..setLineCap(PdfLineCap.square);

    if (top.style != BorderStyle.none) {
      BoxBorder._setStyle(context, top.style);
      context.canvas
        ..setStrokeColor(top.color)
        ..setLineWidth(top.width)
        ..drawLine(box.left, box.top, box.right, box.top)
        ..strokePath();
      BoxBorder._unsetStyle(context, top.style);
    }

    if (right.style != BorderStyle.none) {
      BoxBorder._setStyle(context, right.style);
      context.canvas
        ..setStrokeColor(right.color)
        ..setLineWidth(right.width)
        ..drawLine(box.right, box.top, box.right, box.bottom)
        ..strokePath();
      BoxBorder._unsetStyle(context, right.style);
    }

    if (bottom.style != BorderStyle.none) {
      BoxBorder._setStyle(context, bottom.style);
      context.canvas
        ..setStrokeColor(bottom.color)
        ..setLineWidth(bottom.width)
        ..drawLine(box.right, box.bottom, box.left, box.bottom)
        ..strokePath();
      BoxBorder._unsetStyle(context, bottom.style);
    }

    if (left.style != BorderStyle.none) {
      BoxBorder._setStyle(context, left.style);
      context.canvas
        ..setStrokeColor(left.color)
        ..setLineWidth(left.width)
        ..drawLine(box.left, box.top, box.left, box.bottom)
        ..strokePath();
      BoxBorder._unsetStyle(context, left.style);
    }
  }
}

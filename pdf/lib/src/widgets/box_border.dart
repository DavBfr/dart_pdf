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

class BorderStyle {
  const BorderStyle({
    this.paint = true,
    this.pattern,
    this.phase = 0,
  });

  static const none = BorderStyle(paint: false);
  static const solid = BorderStyle();
  static const dashed = BorderStyle(pattern: <int>[3, 3]);
  static const dotted = BorderStyle(pattern: <int>[1, 1]);

  /// Paint this line
  final bool paint;

  /// Lengths of alternating dashes and gaps. The numbers shall be nonnegative
  /// and not all zero.
  final List<num>? pattern;

  /// Specify the distance into the dash pattern at which to start the dash.
  final int phase;

  void setStyle(Context context) {
    if (paint && pattern != null) {
      context.canvas
        ..saveContext()
        ..setLineCap(PdfLineCap.butt)
        ..setLineDashPattern(pattern!, phase);
    }
  }

  void unsetStyle(Context context) {
    if (paint && pattern != null) {
      context.canvas.restoreContext();
    }
  }
}

@immutable
abstract class BoxBorder {
  const BoxBorder();

  BorderSide get top;
  BorderSide get bottom;
  BorderSide get left;
  BorderSide get right;

  bool get isUniform;

  void paint(
    Context context,
    PdfRect box, {
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  });

  static void _paintUniformBorderWithCircle(
      Context context, PdfRect box, BorderSide side) {
    side.style.setStyle(context);
    context.canvas
      ..setStrokeColor(side.color)
      ..setLineWidth(side.width)
      ..drawEllipse(box.x + box.width / 2.0, box.y + box.height / 2.0,
          box.width / 2.0, box.height / 2.0)
      ..strokePath();
    side.style.unsetStyle(context);
  }

  static void _paintUniformBorderWithRadius(Context context, PdfRect box,
      BorderSide side, BorderRadius borderRadius) {
    side.style.setStyle(context);
    context.canvas
      ..setLineJoin(PdfLineJoin.miter)
      ..setMiterLimit(4)
      ..setStrokeColor(side.color)
      ..setLineWidth(side.width);
    borderRadius.paint(context, box);
    context.canvas.strokePath();
    side.style.unsetStyle(context);
  }

  static void _paintUniformBorderWithRectangle(
      Context context, PdfRect box, BorderSide side) {
    side.style.setStyle(context);
    context.canvas
      ..setLineJoin(PdfLineJoin.miter)
      ..setMiterLimit(4)
      ..setStrokeColor(side.color)
      ..setLineWidth(side.width)
      ..drawBox(box)
      ..strokePath();
    side.style.unsetStyle(context);
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
    PdfColor? color,
    double? width,
    BorderStyle? style,
  }) =>
      BorderSide(
        color: color ?? this.color,
        width: width ?? this.width,
        style: style ?? this.style,
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
  }) : super();

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
      : top = side,
        right = side,
        bottom = side,
        left = side,
        super();

  /// Creates a border with symmetrical vertical and horizontal sides.
  const Border.symmetric({
    BorderSide vertical = BorderSide.none,
    BorderSide horizontal = BorderSide.none,
  })  : left = vertical,
        top = horizontal,
        right = vertical,
        bottom = horizontal,
        super();

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
    BorderRadius? borderRadius,
  }) {
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

    assert(borderRadius == null,
        'A borderRadius can only be given for a uniform Border.');

    context.canvas
      ..setLineCap(PdfLineCap.square)
      ..setMiterLimit(4)
      ..setLineJoin(PdfLineJoin.miter);

    if (top.style.paint) {
      top.style.setStyle(context);
      context.canvas
        ..setStrokeColor(top.color)
        ..setLineWidth(top.width)
        ..drawLine(box.left, box.top, box.right, box.top)
        ..strokePath();
      top.style.unsetStyle(context);
    }

    if (right.style.paint) {
      right.style.setStyle(context);
      context.canvas
        ..setStrokeColor(right.color)
        ..setLineWidth(right.width)
        ..drawLine(box.right, box.top, box.right, box.bottom)
        ..strokePath();
      right.style.unsetStyle(context);
    }

    if (bottom.style.paint) {
      bottom.style.setStyle(context);
      context.canvas
        ..setStrokeColor(bottom.color)
        ..setLineWidth(bottom.width)
        ..drawLine(box.right, box.bottom, box.left, box.bottom)
        ..strokePath();
      bottom.style.unsetStyle(context);
    }

    if (left.style.paint) {
      left.style.setStyle(context);
      context.canvas
        ..setStrokeColor(left.color)
        ..setLineWidth(left.width)
        ..drawLine(box.left, box.top, box.left, box.bottom)
        ..strokePath();
      left.style.unsetStyle(context);
    }
  }
}

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

import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../pdf.dart';
import '../../widgets.dart';

@immutable
class BoxConstraints {
  /// Creates box constraints with the given constraints.
  const BoxConstraints(
      {this.minWidth = 0.0, this.maxWidth = double.infinity, this.minHeight = 0.0, this.maxHeight = double.infinity});

  /// Creates box constraints that require the given width or height.
  const BoxConstraints.tightFor({double? width, double? height})
      : minWidth = width ?? 0.0,
        maxWidth = width ?? double.infinity,
        minHeight = height ?? 0.0,
        maxHeight = height ?? double.infinity;

  /// Creates box constraints that is respected only by the given size.
  BoxConstraints.tight(PdfPoint size)
      : minWidth = size.x,
        maxWidth = size.x,
        minHeight = size.y,
        maxHeight = size.y;

  /// Creates box constraints that expand to fill another box constraints.
  const BoxConstraints.expand({double? width, double? height})
      : minWidth = width ?? double.infinity,
        maxWidth = width ?? double.infinity,
        minHeight = height ?? double.infinity,
        maxHeight = height ?? double.infinity;

  const BoxConstraints.tightForFinite({
    double width = double.infinity,
    double height = double.infinity,
  })  : minWidth = width != double.infinity ? width : 0.0,
        maxWidth = width != double.infinity ? width : double.infinity,
        minHeight = height != double.infinity ? height : 0.0,
        maxHeight = height != double.infinity ? height : double.infinity;

  /// The minimum width that satisfies the constraints.
  final double minWidth;

  /// The maximum width that satisfies the constraints.
  ///
  /// Might be [double.infinity].
  final double maxWidth;

  /// The minimum height that satisfies the constraints.
  final double minHeight;

  /// The maximum height that satisfies the constraints.
  ///
  /// Might be [double.infinity].
  final double maxHeight;

  bool get hasBoundedWidth => maxWidth < double.infinity;

  bool get hasBoundedHeight => maxHeight < double.infinity;

  bool get hasInfiniteWidth => minWidth >= double.infinity;

  bool get hasInfiniteHeight => minHeight >= double.infinity;

  /// The biggest size that satisfies the constraints.
  PdfPoint get biggest => PdfPoint(constrainWidth(), constrainHeight());

  /// The smallest size that satisfies the constraints.
  PdfPoint get smallest => PdfPoint(constrainWidth(0), constrainHeight(0));

  /// Whether there is exactly one width value that satisfies the constraints.
  bool get hasTightWidth => minWidth >= maxWidth;

  /// Whether there is exactly one height value that satisfies the constraints.
  bool get hasTightHeight => minHeight >= maxHeight;

  /// Whether there is exactly one size that satisfies the constraints.
  bool get isTight => hasTightWidth && hasTightHeight;

  PdfPoint constrain(PdfPoint size) {
    final result = PdfPoint(constrainWidth(size.x), constrainHeight(size.y));
    return result;
  }

  PdfRect constrainRect({double width = double.infinity, double height = double.infinity}) {
    final result = PdfPoint(constrainWidth(width), constrainHeight(height));
    return PdfRect.fromPoints(PdfPoint.zero, result);
  }

  double constrainWidth([double width = double.infinity]) {
    return width.clamp(minWidth, maxWidth);
  }

  double constrainHeight([double height = double.infinity]) {
    return height.clamp(minHeight, maxHeight);
  }

  /// Returns a size that attempts to meet the conditions
  PdfPoint constrainSizeAndAttemptToPreserveAspectRatio(PdfPoint size) {
    if (isTight) {
      final result = smallest;
      return result;
    }

    var width = size.x;
    var height = size.y;
    assert(width > 0.0);
    assert(height > 0.0);
    final aspectRatio = width / height;

    if (width > maxWidth) {
      width = maxWidth;
      height = width / aspectRatio;
    }

    if (height > maxHeight) {
      height = maxHeight;
      width = height * aspectRatio;
    }

    if (width < minWidth) {
      width = minWidth;
      height = width / aspectRatio;
    }

    if (height < minHeight) {
      height = minHeight;
      width = height * aspectRatio;
    }

    final result = PdfPoint(constrainWidth(width), constrainHeight(height));
    return result;
  }

  /// Returns new box constraints with a tight width and/or height as close to
  /// the given width and height as possible while still respecting the original
  /// box constraints.
  BoxConstraints tighten({double? width, double? height}) {
    return BoxConstraints(
        minWidth: width == null ? minWidth : width.clamp(minWidth, maxWidth),
        maxWidth: width == null ? maxWidth : width.clamp(minWidth, maxWidth),
        minHeight: height == null ? minHeight : height.clamp(minHeight, maxHeight),
        maxHeight: height == null ? maxHeight : height.clamp(minHeight, maxHeight));
  }

  /// Returns new box constraints that are smaller by the given edge dimensions.
  BoxConstraints deflate(EdgeInsets edges) {
    final horizontal = edges.horizontal;
    final vertical = edges.vertical;
    final deflatedMinWidth = math.max(0.0, minWidth - horizontal);
    final deflatedMinHeight = math.max(0.0, minHeight - vertical);
    return BoxConstraints(
        minWidth: deflatedMinWidth,
        maxWidth: math.max(deflatedMinWidth, maxWidth - horizontal),
        minHeight: deflatedMinHeight,
        maxHeight: math.max(deflatedMinHeight, maxHeight - vertical));
  }

  /// Returns new box constraints that remove the minimum width and height requirements.
  BoxConstraints loosen() {
    return BoxConstraints(
      minWidth: 0,
      maxWidth: maxWidth,
      minHeight: 0,
      maxHeight: maxHeight,
    );
  }

  /// Returns new box constraints that respect the given constraints while being
  /// as close as possible to the original constraints.
  BoxConstraints enforce(BoxConstraints constraints) {
    return BoxConstraints(
        minWidth: minWidth.clamp(constraints.minWidth, constraints.maxWidth),
        maxWidth: maxWidth.clamp(constraints.minWidth, constraints.maxWidth),
        minHeight: minHeight.clamp(constraints.minHeight, constraints.maxHeight),
        maxHeight: maxHeight.clamp(constraints.minHeight, constraints.maxHeight));
  }

  BoxConstraints copyWith({double? minWidth, double? maxWidth, double? minHeight, double? maxHeight}) {
    return BoxConstraints(
        minWidth: minWidth ?? this.minWidth,
        maxWidth: maxWidth ?? this.maxWidth,
        minHeight: minHeight ?? this.minHeight,
        maxHeight: maxHeight ?? this.maxHeight);
  }

  @override
  String toString() {
    return 'BoxConstraint <$minWidth, $maxWidth> <$minHeight, $maxHeight>';
  }
}

@immutable
abstract class EdgeInsetsGeometry {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const EdgeInsetsGeometry();

  double get _bottom;

  double get _end;

  double get _left;

  double get _right;

  double get _start;

  double get _top;

  /// The total offset in the horizontal direction.
  double get horizontal => _left + _right + _start + _end;

  /// The total offset in the vertical direction.
  double get vertical => _top + _bottom;

  /// Convert this instance into an [EdgeInsets], which uses literal coordinates
  /// (i.e. the `left` coordinate being explicitly a distance from the left, and
  /// the `right` coordinate being explicitly a distance from the right).
  ///
  /// See also:
  ///
  ///  * [EdgeInsets], for which this is a no-op (returns itself).
  ///  * [EdgeInsetsDirectional], which flips the horizontal direction
  ///    based on the `direction` argument.
  EdgeInsets resolve(TextDirection? direction);

  /// Returns the sum of two [EdgeInsetsGeometry] objects.
  ///
  /// If you know you are adding two [EdgeInsets] or two [EdgeInsetsDirectional]
  /// objects, consider using the `+` operator instead, which always returns an
  /// object of the same type as the operands, and is typed accordingly.
  ///
  /// If [add] is applied to two objects of the same type ([EdgeInsets] or
  /// [EdgeInsetsDirectional]), an object of that type will be returned (though
  /// this is not reflected in the type system). Otherwise, an object
  /// representing a combination of both is returned. That object can be turned
  /// into a concrete [EdgeInsets] using [resolve].
  EdgeInsetsGeometry add(EdgeInsetsGeometry other) {
    return _MixedEdgeInsets.fromLRSETB(
      _left + other._left,
      _right + other._right,
      _start + other._start,
      _end + other._end,
      _top + other._top,
      _bottom + other._bottom,
    );
  }

  @override
  String toString() {
    if (_start == 0.0 && _end == 0.0) {
      if (_left == 0.0 && _right == 0.0 && _top == 0.0 && _bottom == 0.0) {
        return 'EdgeInsets.zero';
      }
      if (_left == _right && _right == _top && _top == _bottom) {
        return 'EdgeInsets.all(${_left.toStringAsFixed(1)})';
      }
      return 'EdgeInsets(${_left.toStringAsFixed(1)}, '
          '${_top.toStringAsFixed(1)}, '
          '${_right.toStringAsFixed(1)}, '
          '${_bottom.toStringAsFixed(1)})';
    }
    if (_left == 0.0 && _right == 0.0) {
      return 'EdgeInsetsDirectional(${_start.toStringAsFixed(1)}, '
          '${_top.toStringAsFixed(1)}, '
          '${_end.toStringAsFixed(1)}, '
          '${_bottom.toStringAsFixed(1)})';
    }
    return 'EdgeInsets(${_left.toStringAsFixed(1)}, '
        '${_top.toStringAsFixed(1)}, '
        '${_right.toStringAsFixed(1)}, '
        '${_bottom.toStringAsFixed(1)})'
        ' + '
        'EdgeInsetsDirectional(${_start.toStringAsFixed(1)}, '
        '0.0, '
        '${_end.toStringAsFixed(1)}, '
        '0.0)';
  }
}

@immutable
class EdgeInsets extends EdgeInsetsGeometry {
  const EdgeInsets.fromLTRB(this.left, this.top, this.right, this.bottom);

  const EdgeInsets.all(double value)
      : left = value,
        top = value,
        right = value,
        bottom = value;

  const EdgeInsets.only({this.left = 0.0, this.top = 0.0, this.right = 0.0, this.bottom = 0.0});

  const EdgeInsets.symmetric({double vertical = 0.0, double horizontal = 0.0})
      : left = horizontal,
        top = vertical,
        right = horizontal,
        bottom = vertical;

  static const EdgeInsets zero = EdgeInsets.only();

  /// The offset from the left.
  final double left;

  @override
  double get _left => left;

  /// The offset from the top.
  final double top;

  @override
  double get _top => top;

  /// The offset from the right.
  final double right;

  @override
  double get _right => right;

  /// The offset from the bottom.
  final double bottom;

  @override
  double get _bottom => bottom;

  @override
  double get _start => 0.0;

  @override
  double get _end => 0.0;

  /// Returns the sum of two [EdgeInsets].
  EdgeInsets operator +(EdgeInsets other) {
    return EdgeInsets.fromLTRB(
      left + other.left,
      top + other.top,
      right + other.right,
      bottom + other.bottom,
    );
  }

  EdgeInsets copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    return EdgeInsets.only(
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
    );
  }

  @override
  EdgeInsetsGeometry add(EdgeInsetsGeometry other) {
    if (other is EdgeInsets) {
      return this + other;
    }
    return super.add(other);
  }

  @override
  EdgeInsets resolve(TextDirection? direction) => this;
}

class _MixedEdgeInsets extends EdgeInsetsGeometry {
  const _MixedEdgeInsets.fromLRSETB(this._left, this._right, this._start, this._end, this._top, this._bottom);

  @override
  final double _left;

  @override
  final double _right;

  @override
  final double _start;

  @override
  final double _end;

  @override
  final double _top;

  @override
  final double _bottom;

  @override
  EdgeInsets resolve(TextDirection? direction) {
    assert(direction != null);
    switch (direction!) {
      case TextDirection.rtl:
        return EdgeInsets.fromLTRB(_end + _left, _top, _start + _right, _bottom);
      case TextDirection.ltr:
        return EdgeInsets.fromLTRB(_start + _left, _top, _end + _right, _bottom);
    }
  }
}

/// An immutable set of offsets in each of the four cardinal directions, but
/// whose horizontal components are dependent on the writing direction.
///
/// This can be used to indicate padding from the left in [TextDirection.ltr]
/// text and padding from the right in [TextDirection.rtl] text without having
/// to be aware of the current text direction.
///
/// See also:
///
///  * [EdgeInsets], a variant that uses physical labels (left and right instead
///    of start and end).
class EdgeInsetsDirectional extends EdgeInsetsGeometry {
  /// Creates insets from offsets from the start, top, end, and bottom.
  const EdgeInsetsDirectional.fromSTEB(this.start, this.top, this.end, this.bottom);

  /// Creates insets with only the given values non-zero.
  ///
  /// {@tool snippet}
  ///
  /// A margin indent of 40 pixels on the leading side:
  ///
  /// ```dart
  /// const EdgeInsetsDirectional.only(start: 40.0)
  /// ```
  /// {@end-tool}
  const EdgeInsetsDirectional.only({
    this.start = 0.0,
    this.top = 0.0,
    this.end = 0.0,
    this.bottom = 0.0,
  });

  /// Creates insets with symmetric vertical and horizontal offsets.
  ///
  /// This is equivalent to [EdgeInsets.symmetric], since the inset is the same
  /// with either [TextDirection]. This constructor is just a convenience for
  /// type compatibility.
  ///
  /// {@tool snippet}
  /// Eight pixel margin above and below, no horizontal margins:
  ///
  /// ```dart
  /// const EdgeInsetsDirectional.symmetric(vertical: 8.0)
  /// ```
  /// {@end-tool}
  const EdgeInsetsDirectional.symmetric({
    double horizontal = 0.0,
    double vertical = 0.0,
  })  : start = horizontal,
        end = horizontal,
        top = vertical,
        bottom = vertical;

  /// Creates insets where all the offsets are `value`.
  ///
  /// {@tool snippet}
  ///
  /// Typical eight-pixel margin on all sides:
  ///
  /// ```dart
  /// const EdgeInsetsDirectional.all(8.0)
  /// ```
  /// {@end-tool}
  const EdgeInsetsDirectional.all(double value)
      : start = value,
        top = value,
        end = value,
        bottom = value;

  /// An [EdgeInsetsDirectional] with zero offsets in each direction.
  ///
  /// Consider using [EdgeInsets.zero] instead, since that object has the same
  /// effect, but will be cheaper to [resolve].
  static const EdgeInsetsDirectional zero = EdgeInsetsDirectional.only();

  /// The offset from the start side, the side from which the user will start
  /// reading text.
  ///
  /// This value is normalized into an [EdgeInsets.left] or [EdgeInsets.right]
  /// value by the [resolve] method.
  final double start;

  @override
  double get _start => start;

  /// The offset from the top.
  ///
  /// This value is passed through to [EdgeInsets.top] unmodified by the
  /// [resolve] method.
  final double top;

  @override
  double get _top => top;

  /// The offset from the end side, the side on which the user ends reading
  /// text.
  ///
  /// This value is normalized into an [EdgeInsets.left] or [EdgeInsets.right]
  /// value by the [resolve] method.
  final double end;

  @override
  double get _end => end;

  /// The offset from the bottom.
  ///
  /// This value is passed through to [EdgeInsets.bottom] unmodified by the
  /// [resolve] method.
  final double bottom;

  @override
  double get _bottom => bottom;

  @override
  double get _left => 0.0;

  @override
  double get _right => 0.0;

  @override
  EdgeInsetsGeometry add(EdgeInsetsGeometry other) {
    if (other is EdgeInsetsDirectional) {
      return this + other;
    }
    return super.add(other);
  }

  /// Returns the sum of two [EdgeInsetsDirectional] objects.
  EdgeInsetsDirectional operator +(EdgeInsetsDirectional other) {
    return EdgeInsetsDirectional.fromSTEB(
      start + other.start,
      top + other.top,
      end + other.end,
      bottom + other.bottom,
    );
  }

  @override
  EdgeInsets resolve(TextDirection? direction) {
    assert(direction != null);
    switch (direction!) {
      case TextDirection.rtl:
        return EdgeInsets.fromLTRB(end, top, start, bottom);
      case TextDirection.ltr:
        return EdgeInsets.fromLTRB(start, top, end, bottom);
    }
  }
}

class Alignment {
  const Alignment(this.x, this.y);

  /// The distance fraction in the horizontal direction.
  final double x;

  /// The distance fraction in the vertical direction.
  final double y;

  /// The top left corner.
  static const Alignment topLeft = Alignment(-1, 1);

  /// The center point along the top edge.
  static const Alignment topCenter = Alignment(0, 1);

  /// The top right corner.
  static const Alignment topRight = Alignment(1, 1);

  /// The center point along the left edge.
  static const Alignment centerLeft = Alignment(-1, 0);

  /// The center point, both horizontally and vertically.
  static const Alignment center = Alignment(0, 0);

  /// The center point along the right edge.
  static const Alignment centerRight = Alignment(1, 0);

  /// The bottom left corner.
  static const Alignment bottomLeft = Alignment(-1, -1);

  /// The center point along the bottom edge.
  static const Alignment bottomCenter = Alignment(0, -1);

  /// The bottom right corner.
  static const Alignment bottomRight = Alignment(1, -1);

  /// Returns the offset that is this fraction within the given size.
  PdfPoint alongSize(PdfPoint other) {
    final centerX = other.x / 2.0;
    final centerY = other.y / 2.0;
    return PdfPoint(centerX + x * centerX, centerY + y * centerY);
  }

  /// Returns the point that is this fraction within the given rect.
  PdfPoint withinRect(PdfRect rect) {
    final halfWidth = rect.width / 2.0;
    final halfHeight = rect.height / 2.0;
    return PdfPoint(
      rect.left + halfWidth + x * halfWidth,
      rect.bottom + halfHeight + y * halfHeight,
    );
  }

  /// Returns a rect of the given size, aligned within given rect as specified
  /// by this alignment.
  PdfRect inscribe(PdfPoint size, PdfRect rect) {
    final halfWidthDelta = (rect.width - size.x) / 2.0;
    final halfHeightDelta = (rect.height - size.y) / 2.0;
    return PdfRect(
      rect.x + halfWidthDelta + x * halfWidthDelta,
      rect.y + halfHeightDelta + y * halfHeightDelta,
      size.x,
      size.y,
    );
  }

  @override
  String toString() => '($x, $y)';
}

/// An offset that's expressed as a fraction of a [PdfPoint].
@immutable
class FractionalOffset extends Alignment {
  /// Creates a fractional offset.
  const FractionalOffset(double dx, double dy) : super(dx * 2 - 1, 1 - dy * 2);
}

/// The pair of sizes returned by [applyBoxFit].
@immutable
class FittedSizes {
  const FittedSizes(this.source, this.destination);

  /// The size of the part of the input to show on the output.
  final PdfPoint? source;

  /// The size of the part of the output on which to show the input.
  final PdfPoint? destination;
}

FittedSizes applyBoxFit(BoxFit fit, PdfPoint inputSize, PdfPoint outputSize) {
  if (inputSize.y <= 0.0 || inputSize.x <= 0.0 || outputSize.y <= 0.0 || outputSize.x <= 0.0) {
    return const FittedSizes(PdfPoint.zero, PdfPoint.zero);
  }

  PdfPoint? sourceSize, destinationSize;
  switch (fit) {
    case BoxFit.fill:
      sourceSize = inputSize;
      destinationSize = outputSize;
      break;
    case BoxFit.contain:
      sourceSize = inputSize;
      if (outputSize.x / outputSize.y > sourceSize.x / sourceSize.y) {
        destinationSize = PdfPoint(sourceSize.x * outputSize.y / sourceSize.y, outputSize.y);
      } else {
        destinationSize = PdfPoint(outputSize.x, sourceSize.y * outputSize.x / sourceSize.x);
      }
      break;
    case BoxFit.cover:
      if (outputSize.x / outputSize.y > inputSize.x / inputSize.y) {
        sourceSize = PdfPoint(inputSize.x, inputSize.x * outputSize.y / outputSize.x);
      } else {
        sourceSize = PdfPoint(inputSize.y * outputSize.x / outputSize.y, inputSize.y);
      }
      destinationSize = outputSize;
      break;
    case BoxFit.fitWidth:
      sourceSize = PdfPoint(inputSize.x, inputSize.x * outputSize.y / outputSize.x);
      destinationSize = PdfPoint(outputSize.x, sourceSize.y * outputSize.x / sourceSize.x);
      break;
    case BoxFit.fitHeight:
      sourceSize = PdfPoint(inputSize.y * outputSize.x / outputSize.y, inputSize.y);
      destinationSize = PdfPoint(sourceSize.x * outputSize.y / sourceSize.y, outputSize.y);
      break;
    case BoxFit.none:
      sourceSize = PdfPoint(math.min(inputSize.x, outputSize.x), math.min(inputSize.y, outputSize.y));
      destinationSize = sourceSize;
      break;
    case BoxFit.scaleDown:
      sourceSize = inputSize;
      destinationSize = inputSize;
      final aspectRatio = inputSize.x / inputSize.y;
      if (destinationSize.y > outputSize.y) {
        destinationSize = PdfPoint(outputSize.y * aspectRatio, outputSize.y);
      }
      if (destinationSize.x > outputSize.x) {
        destinationSize = PdfPoint(outputSize.x, outputSize.x / aspectRatio);
      }
      break;
  }
  return FittedSizes(sourceSize, destinationSize);
}

PdfPoint transformPoint(Matrix4 transform, PdfPoint point) {
  final position3 = Vector3(point.x, point.y, 0);
  final transformed3 = transform.perspectiveTransform(position3);
  return PdfPoint(transformed3.x, transformed3.y);
}

PdfRect transformRect(Matrix4 transform, PdfRect rect) {
  final point1 = transformPoint(transform, rect.topLeft);
  final point2 = transformPoint(transform, rect.topRight);
  final point3 = transformPoint(transform, rect.bottomLeft);
  final point4 = transformPoint(transform, rect.bottomRight);
  return PdfRect.fromLTRB(
      math.min(point1.x, math.min(point2.x, math.min(point3.x, point4.x))),
      math.min(point1.y, math.min(point2.y, math.min(point3.y, point4.y))),
      math.max(point1.x, math.max(point2.x, math.max(point3.x, point4.x))),
      math.max(point1.y, math.max(point2.y, math.max(point3.y, point4.y))));
}

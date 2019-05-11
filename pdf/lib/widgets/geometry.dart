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

@immutable
class BoxConstraints {
  /// Creates box constraints with the given constraints.
  const BoxConstraints(
      {this.minWidth = 0.0,
      this.maxWidth = double.infinity,
      this.minHeight = 0.0,
      this.maxHeight = double.infinity});

  /// Creates box constraints that require the given width or height.
  const BoxConstraints.tightFor({double width, double height})
      : minWidth = width != null ? width : 0.0,
        maxWidth = width != null ? width : double.infinity,
        minHeight = height != null ? height : 0.0,
        maxHeight = height != null ? height : double.infinity;

  /// Creates box constraints that is respected only by the given size.
  BoxConstraints.tight(PdfPoint size)
      : minWidth = size.x,
        maxWidth = size.x,
        minHeight = size.y,
        maxHeight = size.y;

  /// Creates box constraints that expand to fill another box constraints.
  const BoxConstraints.expand({double width, double height})
      : minWidth = width != null ? width : double.infinity,
        maxWidth = width != null ? width : double.infinity,
        minHeight = height != null ? height : double.infinity,
        maxHeight = height != null ? height : double.infinity;

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
    final PdfPoint result =
        PdfPoint(constrainWidth(size.x), constrainHeight(size.y));
    return result;
  }

  PdfRect constrainRect(
      {double width = double.infinity, double height = double.infinity}) {
    final PdfPoint result =
        PdfPoint(constrainWidth(width), constrainHeight(height));
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
      final PdfPoint result = smallest;
      return result;
    }

    double width = size.x;
    double height = size.y;
    assert(width > 0.0);
    assert(height > 0.0);
    final double aspectRatio = width / height;

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

    final PdfPoint result =
        PdfPoint(constrainWidth(width), constrainHeight(height));
    return result;
  }

  /// Returns new box constraints with a tight width and/or height as close to
  /// the given width and height as possible while still respecting the original
  /// box constraints.
  BoxConstraints tighten({double width, double height}) {
    return BoxConstraints(
        minWidth: width == null ? minWidth : width.clamp(minWidth, maxWidth),
        maxWidth: width == null ? maxWidth : width.clamp(minWidth, maxWidth),
        minHeight:
            height == null ? minHeight : height.clamp(minHeight, maxHeight),
        maxHeight:
            height == null ? maxHeight : height.clamp(minHeight, maxHeight));
  }

  /// Returns new box constraints that are smaller by the given edge dimensions.
  BoxConstraints deflate(EdgeInsets edges) {
    assert(edges != null);
    final double horizontal = edges.horizontal;
    final double vertical = edges.vertical;
    final double deflatedMinWidth = math.max(0, minWidth - horizontal);
    final double deflatedMinHeight = math.max(0, minHeight - vertical);
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
        minHeight:
            minHeight.clamp(constraints.minHeight, constraints.maxHeight),
        maxHeight:
            maxHeight.clamp(constraints.minHeight, constraints.maxHeight));
  }

  BoxConstraints copyWith(
      {double minWidth, double maxWidth, double minHeight, double maxHeight}) {
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
class EdgeInsets {
  const EdgeInsets.fromLTRB(this.left, this.top, this.right, this.bottom);

  const EdgeInsets.all(double value)
      : left = value,
        top = value,
        right = value,
        bottom = value;

  const EdgeInsets.only(
      {this.left = 0.0, this.top = 0.0, this.right = 0.0, this.bottom = 0.0});

  const EdgeInsets.symmetric({double vertical = 0.0, double horizontal = 0.0})
      : left = horizontal,
        top = vertical,
        right = horizontal,
        bottom = vertical;

  static const EdgeInsets zero = EdgeInsets.only();

  final double left;

  final double top;

  final double right;

  final double bottom;

  /// The total offset in the horizontal direction.
  double get horizontal => left + right;

  /// The total offset in the vertical direction.
  double get vertical => top + bottom;

  EdgeInsets copyWith({
    double left,
    double top,
    double right,
    double bottom,
  }) {
    return EdgeInsets.only(
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
    );
  }

  /// Returns the sum of two [EdgeInsets] objects.
  EdgeInsets add(EdgeInsets other) {
    return EdgeInsets.fromLTRB(
      left + other.left,
      top + other.top,
      right + other.right,
      bottom + other.bottom,
    );
  }

  @override
  String toString() => 'EdgeInsets $left, $top, $right, $bottom';
}

class Alignment {
  const Alignment(this.x, this.y)
      : assert(x != null),
        assert(y != null);

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
    final double centerX = other.x / 2.0;
    final double centerY = other.y / 2.0;
    return PdfPoint(centerX + x * centerX, centerY + y * centerY);
  }

  /// Returns the point that is this fraction within the given rect.
  PdfPoint withinRect(PdfRect rect) {
    final double halfWidth = rect.width / 2.0;
    final double halfHeight = rect.height / 2.0;
    return PdfPoint(
      rect.left + halfWidth + x * halfWidth,
      rect.top + halfHeight + y * halfHeight,
    );
  }

  /// Returns a rect of the given size, aligned within given rect as specified
  /// by this alignment.
  PdfRect inscribe(PdfPoint size, PdfRect rect) {
    final double halfWidthDelta = (rect.width - size.x) / 2.0;
    final double halfHeightDelta = (rect.height - size.y) / 2.0;
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

/// The pair of sizes returned by [applyBoxFit].
@immutable
class FittedSizes {
  const FittedSizes(this.source, this.destination);

  /// The size of the part of the input to show on the output.
  final PdfPoint source;

  /// The size of the part of the output on which to show the input.
  final PdfPoint destination;
}

FittedSizes applyBoxFit(BoxFit fit, PdfPoint inputSize, PdfPoint outputSize) {
  if (inputSize.y <= 0.0 ||
      inputSize.x <= 0.0 ||
      outputSize.y <= 0.0 ||
      outputSize.x <= 0.0) {
    return const FittedSizes(PdfPoint.zero, PdfPoint.zero);
  }

  PdfPoint sourceSize, destinationSize;
  switch (fit) {
    case BoxFit.fill:
      sourceSize = inputSize;
      destinationSize = outputSize;
      break;
    case BoxFit.contain:
      sourceSize = inputSize;
      if (outputSize.x / outputSize.y > sourceSize.x / sourceSize.y) {
        destinationSize =
            PdfPoint(sourceSize.x * outputSize.y / sourceSize.y, outputSize.y);
      } else {
        destinationSize =
            PdfPoint(outputSize.x, sourceSize.y * outputSize.x / sourceSize.x);
      }
      break;
    case BoxFit.cover:
      if (outputSize.x / outputSize.y > inputSize.x / inputSize.y) {
        sourceSize =
            PdfPoint(inputSize.x, inputSize.x * outputSize.y / outputSize.x);
      } else {
        sourceSize =
            PdfPoint(inputSize.y * outputSize.x / outputSize.y, inputSize.y);
      }
      destinationSize = outputSize;
      break;
    case BoxFit.fitWidth:
      sourceSize =
          PdfPoint(inputSize.x, inputSize.x * outputSize.y / outputSize.x);
      destinationSize =
          PdfPoint(outputSize.x, sourceSize.y * outputSize.x / sourceSize.x);
      break;
    case BoxFit.fitHeight:
      sourceSize =
          PdfPoint(inputSize.y * outputSize.x / outputSize.y, inputSize.y);
      destinationSize =
          PdfPoint(sourceSize.x * outputSize.y / sourceSize.y, outputSize.y);
      break;
    case BoxFit.none:
      sourceSize = PdfPoint(math.min(inputSize.x, outputSize.x),
          math.min(inputSize.y, outputSize.y));
      destinationSize = sourceSize;
      break;
    case BoxFit.scaleDown:
      sourceSize = inputSize;
      destinationSize = inputSize;
      final double aspectRatio = inputSize.x / inputSize.y;
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
  final Vector3 position3 = Vector3(point.x, point.y, 0);
  final Vector3 transformed3 = transform.perspectiveTransform(position3);
  return PdfPoint(transformed3.x, transformed3.y);
}

PdfRect transformRect(Matrix4 transform, PdfRect rect) {
  final PdfPoint point1 = transformPoint(transform, rect.topLeft);
  final PdfPoint point2 = transformPoint(transform, rect.topRight);
  final PdfPoint point3 = transformPoint(transform, rect.bottomLeft);
  final PdfPoint point4 = transformPoint(transform, rect.bottomRight);
  return PdfRect.fromLTRB(
      math.min(point1.x, math.min(point2.x, math.min(point3.x, point4.x))),
      math.min(point1.y, math.min(point2.y, math.min(point3.y, point4.y))),
      math.max(point1.x, math.max(point2.x, math.max(point3.x, point4.x))),
      math.max(point1.y, math.max(point2.y, math.max(point3.y, point4.y))));
}

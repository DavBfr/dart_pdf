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

import '../../pdf.dart';
import '../../widgets.dart';

/// A radius for either circular or elliptical shapes.
class Radius {
  /// Constructs a circular radius. [x] and [y] will have the same radius value.
  const Radius.circular(double radius) : this.elliptical(radius, radius);

  /// Constructs an elliptical radius with the given radii.
  const Radius.elliptical(this.x, this.y);

  /// The radius value on the horizontal axis.
  final double x;

  /// The radius value on the vertical axis.
  final double y;

  /// A radius with [x] and [y] values set to zero.
  static const Radius zero = Radius.circular(0.0);
}

/// Base class for [BorderRadius] that allows for text-direction aware resolution.
///
/// A property or argument of this type accepts classes created either with [
/// BorderRadius.only] and its variants, or [BorderRadiusDirectional.only]
/// and its variants.
///
/// To convert a [BorderRadiusGeometry] object of indeterminate type into a
/// [BorderRadius] object, call the [resolve] method.
@immutable
abstract class BorderRadiusGeometry {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const BorderRadiusGeometry();

  Radius get _topLeft;

  Radius get _topRight;

  Radius get _bottomLeft;

  Radius get _bottomRight;

  Radius get _topStart;

  Radius get _topEnd;

  Radius get _bottomStart;

  Radius get _bottomEnd;

  Radius get uniform;

  bool get isUniform;

  /// Convert this instance into a [BorderRadius], so that the radii are
  /// expressed for specific physical corners (top-left, top-right, etc) rather
  /// than in a direction-dependent manner.
  ///
  /// See also:
  ///
  ///  * [BorderRadius], for which this is a no-op (returns itself).
  ///  * [BorderRadiusDirectional], which flips the horizontal direction
  ///    based on the `direction` argument.
  BorderRadius resolve(TextDirection? direction);

  @override
  String toString() {
    String? visual, logical;
    if (_topLeft == _topRight &&
        _topRight == _bottomLeft &&
        _bottomLeft == _bottomRight) {
      if (_topLeft != Radius.zero) {
        if (_topLeft.x == _topLeft.y) {
          visual = 'BorderRadius.circular(${_topLeft.x.toStringAsFixed(1)})';
        } else {
          visual = 'BorderRadius.all($_topLeft)';
        }
      }
    } else {
      // visuals aren't the same and at least one isn't zero
      final result = StringBuffer();
      result.write('BorderRadius.only(');
      var comma = false;
      if (_topLeft != Radius.zero) {
        result.write('topLeft: $_topLeft');
        comma = true;
      }
      if (_topRight != Radius.zero) {
        if (comma) {
          result.write(', ');
        }
        result.write('topRight: $_topRight');
        comma = true;
      }
      if (_bottomLeft != Radius.zero) {
        if (comma) {
          result.write(', ');
        }
        result.write('bottomLeft: $_bottomLeft');
        comma = true;
      }
      if (_bottomRight != Radius.zero) {
        if (comma) {
          result.write(', ');
        }
        result.write('bottomRight: $_bottomRight');
      }
      result.write(')');
      visual = result.toString();
    }
    if (_topStart == _topEnd &&
        _topEnd == _bottomEnd &&
        _bottomEnd == _bottomStart) {
      if (_topStart != Radius.zero) {
        if (_topStart.x == _topStart.y) {
          logical =
              'BorderRadiusDirectional.circular(${_topStart.x.toStringAsFixed(1)})';
        } else {
          logical = 'BorderRadiusDirectional.all($_topStart)';
        }
      }
    } else {
      // logical aren't the same and at least one isn't zero
      final result = StringBuffer();
      result.write('BorderRadiusDirectional.only(');
      var comma = false;
      if (_topStart != Radius.zero) {
        result.write('topStart: $_topStart');
        comma = true;
      }
      if (_topEnd != Radius.zero) {
        if (comma) {
          result.write(', ');
        }
        result.write('topEnd: $_topEnd');
        comma = true;
      }
      if (_bottomStart != Radius.zero) {
        if (comma) {
          result.write(', ');
        }
        result.write('bottomStart: $_bottomStart');
        comma = true;
      }
      if (_bottomEnd != Radius.zero) {
        if (comma) {
          result.write(', ');
        }
        result.write('bottomEnd: $_bottomEnd');
      }
      result.write(')');
      logical = result.toString();
    }
    if (visual != null && logical != null) {
      return '$visual + $logical';
    }
    if (visual != null) {
      return visual;
    }
    if (logical != null) {
      return logical;
    }
    return 'BorderRadius.zero';
  }
}

/// An immutable set of radii for each corner of a rectangle.
class BorderRadius extends BorderRadiusGeometry {
  /// Creates a border radius where all radii are [radius].
  const BorderRadius.all(Radius radius)
      : this.only(
          topLeft: radius,
          topRight: radius,
          bottomLeft: radius,
          bottomRight: radius,
        );

  /// Creates a border radius where all radii are [Radius.circular(radius)].
  BorderRadius.circular(double radius)
      : this.all(
          Radius.circular(radius),
        );

  /// Creates a vertically symmetric border radius where the top and bottom
  /// sides of the rectangle have the same radii.
  const BorderRadius.vertical({
    Radius top = Radius.zero,
    Radius bottom = Radius.zero,
  }) : this.only(
          topLeft: top,
          topRight: top,
          bottomLeft: bottom,
          bottomRight: bottom,
        );

  /// Creates a horizontally symmetrical border radius where the left and right
  /// sides of the rectangle have the same radii.
  const BorderRadius.horizontal({
    Radius left = Radius.zero,
    Radius right = Radius.zero,
  }) : this.only(
          topLeft: left,
          topRight: right,
          bottomLeft: left,
          bottomRight: right,
        );

  /// Creates a border radius with only the given non-zero values. The other
  /// corners will be right angles.
  const BorderRadius.only({
    this.topLeft = Radius.zero,
    this.topRight = Radius.zero,
    this.bottomLeft = Radius.zero,
    this.bottomRight = Radius.zero,
  });

  /// A border radius with all zero radii.
  static const BorderRadius zero = BorderRadius.all(Radius.zero);

  /// The top-left [Radius].
  final Radius topLeft;

  /// The top-right [Radius].
  final Radius topRight;

  /// The bottom-left [Radius].
  final Radius bottomLeft;

  /// The bottom-right [Radius].
  final Radius bottomRight;

  @override
  bool get isUniform =>
      topLeft == topRight && topLeft == bottomLeft && topLeft == bottomRight;

  @override
  Radius get uniform => isUniform ? topLeft : Radius.zero;

  void paint(Context context, PdfRect box) {
    // Ellipse 4-spline magic number
    const _m4 = 0.551784;

    context.canvas
      // Start
      ..moveTo(box.x, box.y + bottomLeft.y)
      // bottomLeft
      ..curveTo(
          box.x,
          box.y - _m4 * bottomLeft.y + bottomLeft.y,
          box.x - _m4 * bottomLeft.x + bottomLeft.x,
          box.y,
          box.x + bottomLeft.x,
          box.y)
      // bottom
      ..lineTo(box.x + box.width - bottomRight.x, box.y)
      // bottomRight
      ..curveTo(
          box.x + _m4 * bottomRight.x + box.width - bottomRight.x,
          box.y,
          box.x + box.width,
          box.y - _m4 * bottomRight.y + bottomRight.y,
          box.x + box.width,
          box.y + bottomRight.y)
      // right
      ..lineTo(box.x + box.width, box.y + box.height - topRight.y)
      // topRight
      ..curveTo(
          box.x + box.width,
          box.y + _m4 * topRight.y + box.height - topRight.y,
          box.x + _m4 * topRight.x + box.width - topRight.x,
          box.y + box.height,
          box.x + box.width - topRight.x,
          box.y + box.height)
      // top
      ..lineTo(box.x + topLeft.x, box.y + box.height)
      // topLeft
      ..curveTo(
          box.x - _m4 * topLeft.x + topLeft.x,
          box.y + box.height,
          box.x,
          box.y + _m4 * topLeft.y + box.height - topLeft.y,
          box.x,
          box.y + box.height - topLeft.y)
      // left
      ..lineTo(box.x, box.y + bottomLeft.y);
  }

  @override
  Radius get _topLeft => topLeft;

  @override
  Radius get _topRight => topRight;

  @override
  Radius get _bottomLeft => bottomLeft;

  @override
  Radius get _bottomRight => bottomRight;

  @override
  Radius get _topStart => Radius.zero;

  @override
  Radius get _topEnd => Radius.zero;

  @override
  Radius get _bottomStart => Radius.zero;

  @override
  Radius get _bottomEnd => Radius.zero;

  @override
  BorderRadius resolve(TextDirection? direction) => this;
}

/// An immutable set of radii for each corner of a rectangle, but with the
/// corners specified in a manner dependent on the writing direction.
///
/// This can be used to specify a corner radius on the leading or trailing edge
/// of a box, so that it flips to the other side when the text alignment flips
/// (e.g. being on the top right in English text but the top left in Arabic
/// text).
///
/// See also:
///
///  * [BorderRadius], a variant that uses physical labels (`topLeft` and
///    `topRight` instead of `topStart` and `topEnd`).
class BorderRadiusDirectional extends BorderRadiusGeometry {
  /// Creates a border radius where all radii are [radius].
  const BorderRadiusDirectional.all(Radius radius)
      : this.only(
          topStart: radius,
          topEnd: radius,
          bottomStart: radius,
          bottomEnd: radius,
        );

  /// Creates a border radius where all radii are [Radius.circular(radius)].
  BorderRadiusDirectional.circular(double radius)
      : this.all(
          Radius.circular(radius),
        );

  /// Creates a vertically symmetric border radius where the top and bottom
  /// sides of the rectangle have the same radii.
  const BorderRadiusDirectional.vertical({
    Radius top = Radius.zero,
    Radius bottom = Radius.zero,
  }) : this.only(
          topStart: top,
          topEnd: top,
          bottomStart: bottom,
          bottomEnd: bottom,
        );

  /// Creates a horizontally symmetrical border radius where the start and end
  /// sides of the rectangle have the same radii.
  const BorderRadiusDirectional.horizontal({
    Radius start = Radius.zero,
    Radius end = Radius.zero,
  }) : this.only(
          topStart: start,
          topEnd: end,
          bottomStart: start,
          bottomEnd: end,
        );

  /// Creates a border radius with only the given non-zero values. The other
  /// corners will be right angles.
  const BorderRadiusDirectional.only({
    this.topStart = Radius.zero,
    this.topEnd = Radius.zero,
    this.bottomStart = Radius.zero,
    this.bottomEnd = Radius.zero,
  });

  /// A border radius with all zero radii.
  ///
  /// Consider using [BorderRadius.zero] instead, since that object has the same
  /// effect, but will be cheaper to [resolve].
  static const BorderRadiusDirectional zero =
      BorderRadiusDirectional.all(Radius.zero);

  /// The top-start [Radius].
  final Radius topStart;

  @override
  Radius get _topStart => topStart;

  /// The top-end [Radius].
  final Radius topEnd;

  @override
  Radius get _topEnd => topEnd;

  /// The bottom-start [Radius].
  final Radius bottomStart;

  @override
  Radius get _bottomStart => bottomStart;

  /// The bottom-end [Radius].
  final Radius bottomEnd;

  @override
  Radius get _bottomEnd => bottomEnd;

  @override
  Radius get _topLeft => Radius.zero;

  @override
  Radius get _topRight => Radius.zero;

  @override
  Radius get _bottomLeft => Radius.zero;

  @override
  Radius get _bottomRight => Radius.zero;

  @override
  bool get isUniform =>
      topStart == topEnd && topStart == bottomStart && topStart == bottomEnd;

  @override
  Radius get uniform => isUniform ? topStart : Radius.zero;

  @override
  BorderRadius resolve(TextDirection? direction) {
    assert(direction != null);
    switch (direction!) {
      case TextDirection.rtl:
        return BorderRadius.only(
          topLeft: topEnd,
          topRight: topStart,
          bottomLeft: bottomEnd,
          bottomRight: bottomStart,
        );
      case TextDirection.ltr:
        return BorderRadius.only(
          topLeft: topStart,
          topRight: topEnd,
          bottomLeft: bottomStart,
          bottomRight: bottomEnd,
        );
    }
  }
}

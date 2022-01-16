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

import '../../pdf.dart';
import 'widget.dart';

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

/// An immutable set of radii for each corner of a rectangle.
class BorderRadius {
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
}

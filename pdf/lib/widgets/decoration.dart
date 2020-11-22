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

enum DecorationPosition { background, foreground }

enum BorderStyle { none, solid, dashed, dotted }

@immutable
class BoxBorder {
  const BoxBorder({
    this.left = false,
    this.top = false,
    this.right = false,
    this.bottom = false,
    this.color = PdfColors.black,
    this.width = 1.0,
    this.style = BorderStyle.solid,
  })  : assert(color != null),
        assert(width != null),
        assert(width >= 0.0),
        assert(style != null);

  final bool top;
  final bool bottom;
  final bool left;
  final bool right;

  final BorderStyle style;

  /// The color of the
  final PdfColor color;

  /// The width of the
  final double width;

  void paintRect(Context context, PdfRect box) {
    assert(box.x != null);
    assert(box.y != null);
    assert(box.width != null);
    assert(box.height != null);

    if (!(top || bottom || left || right)) {
      return;
    }

    switch (style) {
      case BorderStyle.none:
        return;
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

    context.canvas
      ..setStrokeColor(color)
      ..setLineWidth(width);

    if (top) {
      context.canvas.drawLine(box.x, box.top, box.right, box.top);
    }

    if (right) {
      if (!top) {
        context.canvas.moveTo(box.right, box.top);
      }
      context.canvas.lineTo(box.right, box.y);
    }

    if (bottom) {
      if (!right) {
        context.canvas.moveTo(box.right, box.y);
      }
      context.canvas.lineTo(box.x, box.y);
    }

    if (left) {
      if (!bottom) {
        context.canvas.moveTo(box.x, box.y);
        context.canvas.lineTo(box.x, box.top);
      } else if (right && top) {
        context.canvas.closePath();
      } else {
        context.canvas.lineTo(box.x, box.top);
      }
    }

    context.canvas.strokePath();
    if (style != BorderStyle.solid) {
      context.canvas.restoreContext();
    }
  }

  void paintEllipse(Context context, PdfRect box) {
    assert(box.x != null);
    assert(box.y != null);
    assert(box.width != null);
    assert(box.height != null);

    context.canvas
      ..setStrokeColor(color)
      ..setLineWidth(width)
      ..drawEllipse(box.x + box.width / 2.0, box.y + box.height / 2.0,
          box.width / 2.0, box.height / 2.0)
      ..strokePath();
  }

  void paintRRect(Context context, PdfRect box, BorderRadius borderRadius) {
    assert(box.x != null);
    assert(box.y != null);
    assert(box.width != null);
    assert(box.height != null);

    context.canvas
      ..setStrokeColor(color)
      ..setLineWidth(width);
    borderRadius.paint(context, box);
    context.canvas.strokePath();
  }
}

@immutable
class DecorationImage {
  @Deprecated('Use DecorationImage.provider()')
  DecorationImage({
    @required PdfImage image,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  })  : assert(image != null),
        assert(fit != null),
        assert(alignment != null),
        image = ImageProxy(image),
        dpi = null;

  const DecorationImage.provider({
    @required this.image,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.dpi,
  })  : assert(image != null),
        assert(fit != null),
        assert(alignment != null);

  final ImageProvider image;
  final BoxFit fit;
  final Alignment alignment;
  final double dpi;

  void paint(Context context, PdfRect box) {
    final _image = image.resolve(context, box.size, dpi: dpi);

    final imageSize =
        PdfPoint(_image.width.toDouble(), _image.height.toDouble());
    final sizes = applyBoxFit(fit, imageSize, box.size);
    final scaleX = sizes.destination.x / sizes.source.x;
    final scaleY = sizes.destination.y / sizes.source.y;
    final sourceRect = alignment.inscribe(
        sizes.source, PdfRect.fromPoints(PdfPoint.zero, imageSize));
    final destinationRect = alignment.inscribe(sizes.destination, box);
    final mat =
        Matrix4.translationValues(destinationRect.x, destinationRect.y, 0)
          ..scale(scaleX, scaleY, 1)
          ..translate(-sourceRect.x, -sourceRect.y);

    context.canvas
      ..saveContext()
      ..drawRect(box.x, box.y, box.width, box.height)
      ..clipPath()
      ..setTransform(mat)
      ..drawImage(_image, 0, 0, imageSize.x, imageSize.y)
      ..restoreContext();
  }
}

/// Defines what happens at the edge of the gradient.
enum TileMode {
  /// Edge is clamped to the final color.
  clamp,

  /// Edge is repeated from first color to last.
  // repeated,

  /// Edge is mirrored from last color to first.
  // mirror,
}

/// A 2D gradient.
@immutable
abstract class Gradient {
  /// Initialize the gradient's colors and stops.
  const Gradient({
    @required this.colors,
    this.stops,
  }) : assert(colors != null);

  final List<PdfColor> colors;

  /// A list of values from 0.0 to 1.0 that denote fractions along the gradient.
  final List<double> stops;

  PdfBaseFunction _buildFunction(
    Context context,
    List<PdfColor> colors,
    List<double> stops,
  ) {
    if (stops == null) {
      return PdfFunction(
        context.document,
        colors: colors,
      );
    }

    final fn = <PdfFunction>[];

    var lc = colors.first;
    for (final c in colors.sublist(1)) {
      fn.add(PdfFunction(
        context.document,
        colors: <PdfColor>[lc, c],
      ));
      lc = c;
    }

    return PdfStitchingFunction(
      context.document,
      functions: fn,
      bounds: stops.sublist(1, stops.length - 1),
      domainStart: stops.first,
      domainEnd: stops.last,
    );
  }

  void paint(Context context, PdfRect box);
}

/// A 2D linear gradient.
class LinearGradient extends Gradient {
  /// Creates a linear gradient.
  const LinearGradient({
    this.begin = Alignment.centerLeft,
    this.end = Alignment.centerRight,
    @required List<PdfColor> colors,
    List<double> stops,
    this.tileMode = TileMode.clamp,
  })  : assert(begin != null),
        assert(end != null),
        assert(tileMode != null),
        super(colors: colors, stops: stops);

  /// The offset at which stop 0.0 of the gradient is placed.
  final Alignment begin;

  /// The offset at which stop 1.0 of the gradient is placed.
  final Alignment end;

  /// How this gradient should tile the plane beyond in the region before
  final TileMode tileMode;

  @override
  void paint(Context context, PdfRect box) {
    if (colors.isEmpty) {
      return;
    }

    if (colors.length == 1) {
      context.canvas
        ..setFillColor(colors.first)
        ..fillPath();
    }

    assert(stops == null || stops.length == colors.length);

    context.canvas
      ..saveContext()
      ..clipPath()
      ..applyShader(
        PdfShading(
          context.document,
          shadingType: PdfShadingType.axial,
          boundingBox: box,
          function: _buildFunction(context, colors, stops),
          start: begin.withinRect(box),
          end: end.withinRect(box),
          extendStart: true,
          extendEnd: true,
        ),
      )
      ..restoreContext();
  }
}

/// A 2D radial gradient.
class RadialGradient extends Gradient {
  /// Creates a radial gradient.
  ///
  /// The [colors] argument must not be null. If [stops] is non-null, it must
  /// have the same length as [colors].
  const RadialGradient({
    this.center = Alignment.center,
    this.radius = 0.5,
    @required List<PdfColor> colors,
    List<double> stops,
    this.tileMode = TileMode.clamp,
    this.focal,
    this.focalRadius = 0.0,
  })  : assert(center != null),
        assert(radius != null),
        assert(tileMode != null),
        assert(focalRadius != null),
        super(colors: colors, stops: stops);

  /// The center of the gradient
  final Alignment center;

  /// The radius of the gradient
  final double radius;

  /// How this gradient should tile the plane beyond the outer ring at [radius]
  /// pixels from the [center].
  final TileMode tileMode;

  /// The focal point of the gradient.
  final Alignment focal;

  /// The radius of the focal point of the gradient.
  final double focalRadius;

  @override
  void paint(Context context, PdfRect box) {
    if (colors.isEmpty) {
      return;
    }

    if (colors.length == 1) {
      context.canvas
        ..setFillColor(colors.first)
        ..fillPath();
    }

    assert(stops == null || stops.length == colors.length);

    final _focal = focal ?? center;

    final _radius = math.min(box.width, box.height);

    context.canvas
      ..saveContext()
      ..clipPath()
      ..applyShader(
        PdfShading(
          context.document,
          shadingType: PdfShadingType.radial,
          boundingBox: box,
          function: _buildFunction(context, colors, stops),
          start: _focal.withinRect(box),
          end: center.withinRect(box),
          radius0: focalRadius * _radius,
          radius1: radius * _radius,
          extendStart: true,
          extendEnd: true,
        ),
      )
      ..restoreContext();
  }
}

class BoxShadow {
  const BoxShadow({
    this.color = PdfColors.black,
    this.offset = PdfPoint.zero,
    this.blurRadius = 0.0,
    this.spreadRadius = 0.0,
  });

  final PdfColor color;
  final PdfPoint offset;
  final double blurRadius;
  final double spreadRadius;

  im.Image _rect(double width, double height) {
    final shadow = im.Image(
      (width + spreadRadius * 2).round(),
      (height + spreadRadius * 2).round(),
    );

    im.fillRect(
      shadow,
      spreadRadius.round(),
      spreadRadius.round(),
      (spreadRadius + width).round(),
      (spreadRadius + height).round(),
      color.toInt(),
    );

    im.gaussianBlur(shadow, blurRadius.round());

    return shadow;
  }

  im.Image _ellipse(double width, double height) {
    final shadow = im.Image(
      (width + spreadRadius * 2).round(),
      (height + spreadRadius * 2).round(),
    );

    im.fillCircle(
      shadow,
      (spreadRadius + width / 2).round(),
      (spreadRadius + height / 2).round(),
      (width / 2).round(),
      color.toInt(),
    );

    im.gaussianBlur(shadow, blurRadius.round());

    return shadow;
  }
}

enum BoxShape { circle, rectangle }

enum PaintPhase { all, background, foreground }

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

@immutable
class BoxDecoration {
  const BoxDecoration({
    this.color,
    this.border,
    @Deprecated('Use borderRadiusEx with `BorderRadius.all(Radius.circular(20))`')
        double borderRadius,
    BorderRadius borderRadiusEx,
    this.boxShadow,
    this.gradient,
    this.image,
    this.shape = BoxShape.rectangle,
  })  : assert(shape != null),
        assert(!(borderRadius != null && borderRadiusEx != null),
            'Don\'t set both borderRadius and borderRadiusEx'),
        _borderRadius = borderRadiusEx,
        _radius = borderRadius;

  /// The color to fill in the background of the box.
  final PdfColor color;
  final BoxBorder border;
  final BorderRadius _borderRadius;
  final double _radius;
  final BoxShape shape;
  final DecorationImage image;
  final Gradient gradient;
  final List<BoxShadow> boxShadow;

  BorderRadius get borderRadius =>
      _borderRadius ??
      (_radius == null ? null : BorderRadius.all(Radius.circular(_radius)));

  void paint(
    Context context,
    PdfRect box, [
    PaintPhase phase = PaintPhase.all,
  ]) {
    assert(box.x != null);
    assert(box.y != null);
    assert(box.width != null);
    assert(box.height != null);

    if (phase == PaintPhase.all || phase == PaintPhase.background) {
      if (color != null) {
        switch (shape) {
          case BoxShape.rectangle:
            if (borderRadius == null) {
              if (boxShadow != null) {
                for (final s in boxShadow) {
                  final i = s._rect(box.width, box.height);
                  final m = PdfImage.fromImage(context.document, image: i);
                  context.canvas.drawImage(
                    m,
                    box.x + s.offset.x - s.spreadRadius,
                    box.y - s.offset.y - s.spreadRadius,
                  );
                }
              }
              context.canvas.drawRect(box.x, box.y, box.width, box.height);
            } else {
              if (boxShadow != null) {
                for (final s in boxShadow) {
                  final i = s._rect(box.width, box.height);
                  final m = PdfImage.fromImage(context.document, image: i);
                  context.canvas.drawImage(
                    m,
                    box.x + s.offset.x - s.spreadRadius,
                    box.y - s.offset.y - s.spreadRadius,
                  );
                }
              }
              borderRadius.paint(context, box);
            }
            break;
          case BoxShape.circle:
            if (boxShadow != null && box.width == box.height) {
              for (final s in boxShadow) {
                final i = s._ellipse(box.width, box.height);
                final m = PdfImage.fromImage(context.document, image: i);
                context.canvas.drawImage(
                  m,
                  box.x + s.offset.x - s.spreadRadius,
                  box.y - s.offset.y - s.spreadRadius,
                );
              }
            }
            context.canvas.drawEllipse(box.x + box.width / 2.0,
                box.y + box.height / 2.0, box.width / 2.0, box.height / 2.0);
            break;
        }
        context.canvas
          ..setFillColor(color)
          ..fillPath();
      }

      if (gradient != null) {
        switch (shape) {
          case BoxShape.rectangle:
            if (borderRadius == null) {
              context.canvas.drawRect(box.x, box.y, box.width, box.height);
            } else {
              borderRadius.paint(context, box);
            }
            break;
          case BoxShape.circle:
            context.canvas.drawEllipse(box.x + box.width / 2.0,
                box.y + box.height / 2.0, box.width / 2.0, box.height / 2.0);
            break;
        }

        gradient.paint(context, box);
      }

      if (image != null) {
        context.canvas.saveContext();
        switch (shape) {
          case BoxShape.circle:
            context.canvas
              ..drawEllipse(box.x + box.width / 2.0, box.y + box.height / 2.0,
                  box.width / 2.0, box.height / 2.0)
              ..clipPath();

            break;
          case BoxShape.rectangle:
            if (borderRadius != null) {
              borderRadius.paint(context, box);
              context.canvas.clipPath();
            }
            break;
        }
        image.paint(context, box);
        context.canvas.restoreContext();
      }
    }

    if (phase == PaintPhase.all || phase == PaintPhase.foreground) {
      if (border != null) {
        switch (shape) {
          case BoxShape.circle:
            border.paintEllipse(context, box);
            break;
          case BoxShape.rectangle:
            if (borderRadius != null) {
              border.paintRRect(context, box, borderRadius);
            } else {
              border.paintRect(context, box);
            }
            break;
        }
      }
    }
  }
}

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

import 'package:image/image.dart' as im;
import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';
import 'package:vector_math/vector_math_64.dart';

import 'basic.dart';
import 'border_radius.dart';
import 'box_border.dart';
import 'geometry.dart';
import 'image_provider.dart';
import 'widget.dart';

enum DecorationPosition { background, foreground }

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
      ..drawBox(box)
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
          function: PdfBaseFunction.colorsAndStops(
            context.document,
            colors,
            stops,
          ),
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
          function: PdfBaseFunction.colorsAndStops(
            context.document,
            colors,
            stops,
          ),
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
              context.canvas.drawBox(box);
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
              context.canvas.drawBox(box);
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
        border.paint(
          context,
          box,
          shape: shape,
          borderRadius: borderRadius,
        );
      }
    }
  }
}

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

enum DecorationPosition { background, foreground }

@immutable
abstract class DecorationGraphic {
  const DecorationGraphic();

  void paint(Context context, PdfRect box);
}

@immutable
class DecorationImage extends DecorationGraphic {
  const DecorationImage({
    required this.image,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.dpi,
  });

  final ImageProvider image;
  final BoxFit fit;
  final Alignment alignment;
  final double? dpi;

  @override
  void paint(Context context, PdfRect box) {
    final _image = image.resolve(context, box.size, dpi: dpi);

    final imageSize =
        PdfPoint(_image.width.toDouble(), _image.height.toDouble());
    final sizes = applyBoxFit(fit, imageSize, box.size);
    final scaleX = sizes.destination!.x / sizes.source!.x;
    final scaleY = sizes.destination!.y / sizes.source!.y;
    final sourceRect = alignment.inscribe(
        sizes.source!, PdfRect.fromPoints(PdfPoint.zero, imageSize));
    final destinationRect = alignment.inscribe(sizes.destination!, box);
    final mat = Matrix4.translationValues(
        destinationRect.left, destinationRect.bottom, 0)
      ..scale(scaleX, scaleY, 1)
      ..translate(-sourceRect.left, -sourceRect.bottom);

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
    required this.colors,
    this.stops,
  });

  final List<PdfColor> colors;

  /// A list of values from 0.0 to 1.0 that denote fractions along the gradient.
  final List<double>? stops;

  void paint(Context context, PdfRect box);
}

/// A 2D linear gradient.
class LinearGradient extends Gradient {
  /// Creates a linear gradient.
  const LinearGradient({
    this.begin = Alignment.centerLeft,
    this.end = Alignment.centerRight,
    required List<PdfColor> colors,
    List<double>? stops,
    this.tileMode = TileMode.clamp,
  }) : super(colors: colors, stops: stops);

  /// The offset at which stop 0.0 of the gradient is placed.
  final AlignmentGeometry begin;

  /// The offset at which stop 1.0 of the gradient is placed.
  final AlignmentGeometry end;

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

    assert(stops == null || stops!.length == colors.length);
    final textDirection = Directionality.of(context);
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
          start: begin.resolve(textDirection).withinRect(box),
          end: end.resolve(textDirection).withinRect(box),
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
    required List<PdfColor> colors,
    List<double>? stops,
    this.tileMode = TileMode.clamp,
    this.focal,
    this.focalRadius = 0.0,
  }) : super(colors: colors, stops: stops);

  /// The center of the gradient
  final AlignmentGeometry center;

  /// The radius of the gradient
  final double radius;

  /// How this gradient should tile the plane beyond the outer ring at [radius]
  /// pixels from the [center].
  final TileMode tileMode;

  /// The focal point of the gradient.
  final AlignmentGeometry? focal;

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

    assert(stops == null || stops!.length == colors.length);

    final _focal = focal ?? center;

    final _radius = math.min(box.width, box.height);
    final textDirection = Directionality.of(context);
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
          start: _focal.resolve(textDirection).withinRect(box),
          end: center.resolve(textDirection).withinRect(box),
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
}

enum BoxShape { circle, rectangle }

enum PaintPhase { all, background, foreground }

@immutable
class BoxDecoration {
  const BoxDecoration({
    this.color,
    this.border,
    this.borderRadius,
    this.boxShadow,
    this.gradient,
    this.image,
    this.shape = BoxShape.rectangle,
  });

  /// The color to fill in the background of the box.
  final PdfColor? color;
  final BoxBorder? border;
  final BorderRadiusGeometry? borderRadius;
  final BoxShape shape;
  final DecorationGraphic? image;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;

  void paint(
    Context context,
    PdfRect box, [
    PaintPhase phase = PaintPhase.all,
  ]) {
    final resolvedBorderRadius =
        borderRadius?.resolve(Directionality.of(context));
    if (phase == PaintPhase.all || phase == PaintPhase.background) {
      if (color != null) {
        switch (shape) {
          case BoxShape.rectangle:
            if (resolvedBorderRadius == null) {
              if (boxShadow != null) {
                for (final s in boxShadow!) {
                  final i = PdfRasterBase.shadowRect(box.width, box.height,
                      s.spreadRadius, s.blurRadius, s.color);
                  final m = PdfImage.fromImage(context.document, image: i);
                  context.canvas.drawImage(
                    m,
                    box.left + s.offset.x - s.spreadRadius,
                    box.bottom - s.offset.y - s.spreadRadius,
                  );
                }
              }
              context.canvas.drawBox(box);
            } else {
              if (boxShadow != null) {
                for (final s in boxShadow!) {
                  final i = PdfRasterBase.shadowRect(box.width, box.height,
                      s.spreadRadius, s.blurRadius, s.color);
                  final m = PdfImage.fromImage(context.document, image: i);
                  context.canvas.drawImage(
                    m,
                    box.left + s.offset.x - s.spreadRadius,
                    box.bottom - s.offset.y - s.spreadRadius,
                  );
                }
              }
              resolvedBorderRadius.paint(context, box);
            }
            break;
          case BoxShape.circle:
            if (boxShadow != null && box.width == box.height) {
              for (final s in boxShadow!) {
                final i = PdfRasterBase.shadowEllipse(box.width, box.height,
                    s.spreadRadius, s.blurRadius, s.color);
                final m = PdfImage.fromImage(context.document, image: i);
                context.canvas.drawImage(
                  m,
                  box.left + s.offset.x - s.spreadRadius,
                  box.bottom - s.offset.y - s.spreadRadius,
                );
              }
            }
            context.canvas.drawEllipse(
                box.left + box.width / 2.0,
                box.bottom + box.height / 2.0,
                box.width / 2.0,
                box.height / 2.0);
            break;
        }
        context.canvas
          ..setFillColor(color)
          ..fillPath();
      }

      if (gradient != null) {
        switch (shape) {
          case BoxShape.rectangle:
            if (resolvedBorderRadius == null) {
              context.canvas.drawBox(box);
            } else {
              resolvedBorderRadius.paint(context, box);
            }
            break;
          case BoxShape.circle:
            context.canvas.drawEllipse(
                box.left + box.width / 2.0,
                box.bottom + box.height / 2.0,
                box.width / 2.0,
                box.height / 2.0);
            break;
        }

        gradient!.paint(context, box);
      }

      if (image != null) {
        context.canvas.saveContext();
        switch (shape) {
          case BoxShape.circle:
            context.canvas
              ..drawEllipse(
                  box.left + box.width / 2.0,
                  box.bottom + box.height / 2.0,
                  box.width / 2.0,
                  box.height / 2.0)
              ..clipPath();

            break;
          case BoxShape.rectangle:
            if (resolvedBorderRadius != null) {
              resolvedBorderRadius.paint(context, box);
              context.canvas.clipPath();
            }
            break;
        }
        image!.paint(context, box);
        context.canvas.restoreContext();
      }
    }

    if (phase == PaintPhase.all || phase == PaintPhase.foreground) {
      if (border != null) {
        border!.paint(
          context,
          box,
          shape: shape,
          borderRadius: resolvedBorderRadius,
        );
      }
    }
  }
}

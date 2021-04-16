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

import 'package:pdf/pdf.dart';
import 'package:vector_math/vector_math_64.dart';

import 'basic.dart';
import 'geometry.dart';
import 'image_provider.dart';
import 'widget.dart';

void _paintImage({
  required PdfGraphics canvas,
  required PdfRect rect,
  required PdfImage image,
  double scale = 1.0,
  BoxFit? fit,
  Alignment alignment = Alignment.center,
}) {
  final outputSize = rect.size;
  final inputSize = PdfPoint(image.width.toDouble(), image.height.toDouble());
  fit ??= BoxFit.scaleDown;
  final fittedSizes = applyBoxFit(
      fit, PdfPoint(inputSize.x / scale, inputSize.y / scale), outputSize);
  final sourceSize =
      PdfPoint(fittedSizes.source!.x * scale, fittedSizes.source!.y * scale);
  final destinationSize = fittedSizes.destination!;
  final halfWidthDelta = (outputSize.x - destinationSize.x) / 2.0;
  final halfHeightDelta = (outputSize.y - destinationSize.y) / 2.0;
  final dx = halfWidthDelta + alignment.x * halfWidthDelta;
  final dy = halfHeightDelta + alignment.y * halfHeightDelta;

  final destinationPosition = rect.topLeft.translate(dx, dy);
  final destinationRect =
      PdfRect.fromPoints(destinationPosition, destinationSize);
  final sourceRect = alignment.inscribe(
    sourceSize,
    PdfRect.fromPoints(PdfPoint.zero, inputSize),
  );
  _drawImageRect(canvas, image, sourceRect, destinationRect);
}

void _drawImageRect(PdfGraphics canvas, PdfImage image, PdfRect sourceRect,
    PdfRect destinationRect) {
  final fw = destinationRect.width / sourceRect.width;
  final fh = destinationRect.height / sourceRect.height;

  canvas.saveContext();
  canvas
    ..drawBox(destinationRect)
    ..clipPath()
    ..drawImage(
      image,
      destinationRect.x - sourceRect.x * fw,
      destinationRect.y - sourceRect.y * fh,
      image.width.toDouble() * fw,
      image.height.toDouble() * fh,
    )
    ..restoreContext();
}

class Image extends Widget {
  Image(
    this.image, {
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.dpi,
  });

  final ImageProvider image;

  final BoxFit fit;

  final Alignment alignment;

  final double? width;

  final double? height;

  final double? dpi;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final w = width ??
        (constraints.hasBoundedWidth
            ? constraints.maxWidth
            : constraints.constrainWidth(image.width!.toDouble()));
    final h = height ??
        (constraints.hasBoundedHeight
            ? constraints.maxHeight
            : constraints.constrainHeight(image.height!.toDouble()));

    final sizes = applyBoxFit(
        fit,
        PdfPoint(image.width!.toDouble(), image.height!.toDouble()),
        PdfPoint(w, h));
    box = PdfRect.fromPoints(PdfPoint.zero, sizes.destination!);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final rect = context.localToGlobal(box!);

    _paintImage(
      canvas: context.canvas,
      image: image.resolve(context, rect.size, dpi: dpi),
      rect: box!,
      alignment: alignment,
      fit: fit,
    );
  }
}

class Shape extends Widget {
  Shape(
    this.shape, {
    this.strokeColor,
    this.fillColor,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  })  : assert(width == null || width > 0.0),
        assert(height == null || height > 0.0);

  final String shape;

  final PdfColor? strokeColor;

  final PdfColor? fillColor;

  final double? width;

  final double? height;

  final BoxFit fit;

  late PdfRect _boundingBox;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    if (width == null || height == null) {
      // Compute the bounding box
      _boundingBox = PdfGraphics.shapeBoundingBox(shape);
    } else {
      _boundingBox = PdfRect(0, 0, width!, height!);
    }

    final w = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth(_boundingBox.width);
    final h = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : constraints.constrainHeight(_boundingBox.height);

    final sizes = applyBoxFit(fit, _boundingBox.size, PdfPoint(w, h));
    box = PdfRect.fromPoints(
      PdfPoint.zero,
      sizes.destination!,
    );
  }

  @override
  void paint(Context context) {
    super.paint(context);

    context.canvas
      ..saveContext()
      ..setTransform(
        Matrix4.identity()
          ..translate(box!.x, box!.y + box!.height)
          ..scale(
            box!.width / _boundingBox.width,
            -box!.height / _boundingBox.height,
          )
          ..translate(-_boundingBox.x, -_boundingBox.y),
      );

    if (fillColor != null) {
      context.canvas
        ..setFillColor(fillColor)
        ..drawShape(shape)
        ..fillPath();
    }

    if (strokeColor != null) {
      context.canvas
        ..setStrokeColor(strokeColor)
        ..drawShape(shape)
        ..strokePath();
    }

    context.canvas.restoreContext();
  }
}

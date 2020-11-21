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

void _paintImage({
  @required PdfGraphics canvas,
  @required PdfRect rect,
  @required PdfImage image,
  double scale = 1.0,
  BoxFit fit,
  Alignment alignment = Alignment.center,
}) {
  assert(canvas != null);
  assert(image != null);
  assert(alignment != null);
  final outputSize = rect.size;
  final inputSize = PdfPoint(image.width.toDouble(), image.height.toDouble());
  fit ??= BoxFit.scaleDown;
  final fittedSizes = applyBoxFit(
      fit, PdfPoint(inputSize.x / scale, inputSize.y / scale), outputSize);
  final sourceSize =
      PdfPoint(fittedSizes.source.x * scale, fittedSizes.source.y * scale);
  final destinationSize = fittedSizes.destination;
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
    ..drawRect(
      destinationRect.x,
      destinationRect.y,
      destinationRect.width,
      destinationRect.height,
    )
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
  })  : assert(image != null),
        aspectRatio = image.height.toDouble() / image.width.toDouble();

  final PdfImage image;

  final double aspectRatio;

  final BoxFit fit;

  final Alignment alignment;

  final double width;

  final double height;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final w = width ??
        (constraints.hasBoundedWidth
            ? constraints.maxWidth
            : constraints.constrainWidth(image.width.toDouble()));
    final h = height ??
        (constraints.hasBoundedHeight
            ? constraints.maxHeight
            : constraints.constrainHeight(image.height.toDouble()));

    final sizes = applyBoxFit(
        fit,
        PdfPoint(image.width.toDouble(), image.height.toDouble()),
        PdfPoint(w, h));
    box = PdfRect.fromPoints(PdfPoint.zero, sizes.destination);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    _paintImage(
      canvas: context.canvas,
      image: image,
      rect: box,
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
    this.width = 1.0,
    this.height = 1.0,
    this.fit = BoxFit.contain,
  })  : assert(width != null && width > 0.0),
        assert(height != null && height > 0.0),
        aspectRatio = height / width;

  final String shape;

  final PdfColor strokeColor;

  final PdfColor fillColor;

  final double width;

  final double height;

  final double aspectRatio;

  final BoxFit fit;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final w = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth(width);
    final h = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : constraints.constrainHeight(height);

    final sizes = applyBoxFit(fit, PdfPoint(width, height), PdfPoint(w, h));
    box = PdfRect.fromPoints(PdfPoint.zero, sizes.destination);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final mat = Matrix4.identity();
    mat.translate(box.x, box.y + box.height);
    mat.scale(box.width / width, -box.height / height);
    context.canvas
      ..saveContext()
      ..setTransform(mat);

    if (fillColor != null) {
      context.canvas
        ..setFillColor(fillColor)
        ..drawShape(shape, stroke: false)
        ..fillPath();
    }

    if (strokeColor != null) {
      context.canvas
        ..setStrokeColor(strokeColor)
        ..drawShape(shape, stroke: true);
    }

    context.canvas.restoreContext();
  }
}

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

// ignore_for_file: omit_local_variable_types

part of widget;

class Image extends Widget {
  Image(this.image, {this.fit = BoxFit.contain})
      : assert(image != null),
        aspectRatio = image.height.toDouble() / image.width.toDouble();

  final PdfImage image;

  final double aspectRatio;

  final BoxFit fit;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final double w = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth(image.width.toDouble());
    final double h = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : constraints.constrainHeight(image.height.toDouble());

    final FittedSizes sizes = applyBoxFit(
        fit,
        PdfPoint(image.width.toDouble(), image.height.toDouble()),
        PdfPoint(w, h));
    box = PdfRect.fromPoints(PdfPoint.zero, sizes.destination);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    context.canvas.drawImage(image, box.x, box.y, box.width, box.height);
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
    final double w = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth(width);
    final double h = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : constraints.constrainHeight(height);

    final FittedSizes sizes =
        applyBoxFit(fit, PdfPoint(width, height), PdfPoint(w, h));
    box = PdfRect.fromPoints(PdfPoint.zero, sizes.destination);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final Matrix4 mat = Matrix4.identity();
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

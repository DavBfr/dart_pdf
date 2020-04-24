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

enum DecorationPosition { background, foreground }

@immutable
class BoxBorder {
  const BoxBorder(
      {this.left = false,
      this.top = false,
      this.right = false,
      this.bottom = false,
      this.color = PdfColors.black,
      this.width = 1.0})
      : assert(color != null),
        assert(width != null),
        assert(width >= 0.0);

  final bool top;
  final bool bottom;
  final bool left;
  final bool right;

  /// The color of the
  final PdfColor color;

  /// The width of the
  final double width;

  void paintRect(Context context, PdfRect box) {
    assert(box.x != null);
    assert(box.y != null);
    assert(box.width != null);
    assert(box.height != null);

    if (top || bottom || left || right) {
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

  void paintRRect(Context context, PdfRect box, double borderRadius) {
    assert(box.x != null);
    assert(box.y != null);
    assert(box.width != null);
    assert(box.height != null);

    context.canvas
      ..setStrokeColor(color)
      ..setLineWidth(width)
      ..drawRRect(
          box.x, box.y, box.width, box.height, borderRadius, borderRadius)
      ..strokePath();
  }
}

@immutable
class DecorationImage {
  const DecorationImage(
      {@required this.image,
      this.fit = BoxFit.cover,
      this.alignment = Alignment.center})
      : assert(image != null),
        assert(fit != null),
        assert(alignment != null);

  final PdfImage image;
  final BoxFit fit;
  final Alignment alignment;

  void paint(Context context, PdfRect box) {
    final PdfPoint imageSize =
        PdfPoint(image.width.toDouble(), image.height.toDouble());
    final FittedSizes sizes = applyBoxFit(fit, imageSize, box.size);
    final double scaleX = sizes.destination.x / sizes.source.x;
    final double scaleY = sizes.destination.y / sizes.source.y;
    final PdfRect sourceRect = alignment.inscribe(
        sizes.source, PdfRect.fromPoints(PdfPoint.zero, imageSize));
    final PdfRect destinationRect = alignment.inscribe(sizes.destination, box);
    final Matrix4 mat =
        Matrix4.translationValues(destinationRect.x, destinationRect.y, 0)
          ..scale(scaleX, scaleY, 1)
          ..translate(-sourceRect.x, -sourceRect.y);

    context.canvas
      ..saveContext()
      ..drawRect(box.x, box.y, box.width, box.height)
      ..clipPath()
      ..setTransform(mat)
      ..drawImage(image, 0, 0, imageSize.x, imageSize.y)
      ..restoreContext();
  }
}

enum BoxShape { circle, rectangle }

@immutable
class BoxDecoration {
  const BoxDecoration(
      {this.color,
      this.border,
      this.borderRadius,
      this.image,
      this.shape = BoxShape.rectangle})
      : assert(shape != null);

  /// The color to fill in the background of the box.
  final PdfColor color;
  final BoxBorder border;
  final double borderRadius;
  final BoxShape shape;
  final DecorationImage image;

  void paint(Context context, PdfRect box) {
    assert(box.x != null);
    assert(box.y != null);
    assert(box.width != null);
    assert(box.height != null);

    if (color != null) {
      switch (shape) {
        case BoxShape.rectangle:
          if (borderRadius == null) {
            context.canvas.drawRect(box.x, box.y, box.width, box.height);
          } else {
            context.canvas.drawRRect(box.x, box.y, box.width, box.height,
                borderRadius, borderRadius);
          }
          break;
        case BoxShape.circle:
          context.canvas.drawEllipse(box.x + box.width / 2.0,
              box.y + box.height / 2.0, box.width / 2.0, box.height / 2.0);
          break;
      }
      context.canvas
        ..setFillColor(color)
        ..fillPath();
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
            context.canvas
              ..drawRRect(box.x, box.y, box.width, box.height, borderRadius,
                  borderRadius)
              ..clipPath();
          }
          break;
      }
      image.paint(context, box);
      context.canvas.restoreContext();
    }

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

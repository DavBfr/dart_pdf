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

class ClipRect extends SingleChildWidget {
  ClipRect({Widget child}) : super(child: child);

  @override
  void debugPaint(Context context) {
    context.canvas
      ..setStrokeColor(PdfColors.deepPurple)
      ..drawRect(box.x, box.y, box.width, box.height)
      ..strokePath();
  }

  @override
  void paint(Context context) {
    super.paint(context);

    if (child != null) {
      final Matrix4 mat = Matrix4.identity();
      mat.translate(box.x, box.y);
      context.canvas
        ..saveContext()
        ..drawRect(box.x, box.y, box.width, box.height)
        ..clipPath()
        ..setTransform(mat);
      child.paint(context);
      context.canvas.restoreContext();
    }
  }
}

class ClipRRect extends SingleChildWidget {
  ClipRRect({
    Widget child,
    this.horizontalRadius,
    this.verticalRadius,
  }) : super(child: child);

  final double horizontalRadius;
  final double verticalRadius;

  @override
  void debugPaint(Context context) {
    context.canvas
      ..setStrokeColor(PdfColors.deepPurple)
      ..drawRRect(
          box.x, box.y, box.width, box.height, horizontalRadius, verticalRadius)
      ..strokePath();
  }

  @override
  void paint(Context context) {
    super.paint(context);

    if (child != null) {
      final Matrix4 mat = Matrix4.identity();
      mat.translate(box.x, box.y);
      context.canvas
        ..saveContext()
        ..drawRRect(box.x, box.y, box.width, box.height, horizontalRadius,
            verticalRadius)
        ..clipPath()
        ..setTransform(mat);
      child.paint(context);
      context.canvas.restoreContext();
    }
  }
}

class ClipOval extends SingleChildWidget {
  ClipOval({Widget child}) : super(child: child);

  @override
  void debugPaint(Context context) {
    final double rx = box.width / 2.0;
    final double ry = box.height / 2.0;

    context.canvas
      ..setStrokeColor(PdfColors.deepPurple)
      ..drawEllipse(box.x + rx, box.y + ry, rx, ry)
      ..strokePath();
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final double rx = box.width / 2.0;
    final double ry = box.height / 2.0;

    if (child != null) {
      final Matrix4 mat = Matrix4.identity();
      mat.translate(box.x, box.y);
      context.canvas
        ..saveContext()
        ..drawEllipse(box.x + rx, box.y + ry, rx, ry)
        ..clipPath()
        ..setTransform(mat);
      child.paint(context);
      context.canvas.restoreContext();
    }
  }
}

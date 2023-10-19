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

import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as im;
import 'package:vector_math/vector_math_64.dart';
import 'package:xml/xml.dart';

import '../../pdf.dart';
import 'brush.dart';
import 'clip_path.dart';
import 'operation.dart';
import 'painter.dart';
import 'parser.dart';
import 'transform.dart';

class SvgImg extends SvgOperation {
  SvgImg(
    this.x,
    this.y,
    this.width,
    this.height,
    this.image,
    SvgBrush brush,
    SvgClipPath clip,
    SvgTransform transform,
    SvgPainter painter,
  ) : super(brush, clip, transform, painter);

  factory SvgImg.fromXml(
    XmlElement element,
    SvgPainter painter,
    SvgBrush brush,
  ) {
    final _brush = SvgBrush.fromXml(element, brush, painter);

    final width =
        SvgParser.getNumeric(element, 'width', _brush, defaultValue: 0)!
            .sizeValue;
    final height =
        SvgParser.getNumeric(element, 'height', _brush, defaultValue: 0)!
            .sizeValue;
    final x =
        SvgParser.getNumeric(element, 'x', _brush, defaultValue: 0)!.sizeValue;
    final y =
        SvgParser.getNumeric(element, 'y', _brush, defaultValue: 0)!.sizeValue;

    PdfImage? image;

    final hrefAttr = element.getAttribute('href') ??
        element.getAttribute('href', namespace: 'http://www.w3.org/1999/xlink');

    if (hrefAttr != null) {
      if (hrefAttr.startsWith('data:')) {
        final px = hrefAttr.substring(hrefAttr.indexOf(';') + 1);
        if (px.startsWith('base64,')) {
          final b = px.substring(7).replaceAll(RegExp(r'\s'), '');
          final bytes = base64.decode(b);

          final img = im.decodeImage(bytes);
          if (img == null) {
            throw Exception('Unable to decode image: $px');
          }

          image = PdfImage(
            painter.document,
            image: img.data?.buffer.asUint8List() ?? Uint8List(0),
            width: img.width,
            height: img.height,
          );
        }
      }
    }

    return SvgImg(
      x,
      y,
      width,
      height,
      image,
      _brush,
      SvgClipPath.fromXml(element, painter, _brush),
      SvgTransform.fromXml(element),
      painter,
    );
  }

  final double x;

  final double y;

  final double width;

  final double height;

  final PdfImage? image;

  @override
  void paintShape(PdfGraphics canvas) {
    if (image == null) {
      return;
    }

    final sx = width / image!.width;
    final sy = height / image!.height;

    canvas
      ..setTransform(
        Matrix4.identity()
          ..translate(x, y + height, 0)
          ..scale(sx, -sy),
      )
      ..drawImage(image!, 0, 0);
  }

  @override
  void drawShape(PdfGraphics canvas) {}

  @override
  PdfRect boundingBox() => PdfRect(x, y, width, height);
}

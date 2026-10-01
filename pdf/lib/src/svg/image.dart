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

    final width = SvgParser.getNumeric(
      element,
      'width',
      _brush,
      defaultValue: 0,
    )!.sizeIn(painter.viewport, SvgAxis.horizontal);
    final height = SvgParser.getNumeric(
      element,
      'height',
      _brush,
      defaultValue: 0,
    )!.sizeIn(painter.viewport, SvgAxis.vertical);
    final x = SvgParser.getNumeric(
      element,
      'x',
      _brush,
      defaultValue: 0,
    )!.sizeIn(painter.viewport, SvgAxis.horizontal);
    final y = SvgParser.getNumeric(
      element,
      'y',
      _brush,
      defaultValue: 0,
    )!.sizeIn(painter.viewport, SvgAxis.vertical);

    PdfImage? image;

    final hrefAttr =
        element.getAttribute('href') ??
        element.getAttribute(
          'href',
          namespaceUri: 'http://www.w3.org/1999/xlink',
        );

    if (hrefAttr != null && hrefAttr.startsWith('data:')) {
      // An <image> is a sub-resource: whatever is wrong with it costs that one
      // element, never the document. base64.decode throws on malformed input,
      // im.decodeImage returns null for a format it does not know - a nested
      // image/svg+xml payload, say - and throws outright on empty or truncated
      // data, and none of that was guarded.
      try {
        final comma = hrefAttr.indexOf(',');
        if (comma < 0) {
          throw const FormatException('A data URI needs a comma');
        }

        // Any header ending in ';base64', so 'data:image/png;charset=utf-8;
        // base64,...' is read rather than dropped: only the part right after the
        // first ';' used to be looked at.
        final header = hrefAttr.substring(5, comma);
        if (!header.endsWith(';base64')) {
          throw FormatException('Not a base64 data URI: $header');
        }

        final bytes = base64.decode(
          hrefAttr.substring(comma + 1).replaceAll(RegExp(r'\s'), ''),
        );

        // PdfImage.file sends a JPEG to /DCTDecode and everything else through
        // PdfRasterBase.fromImage, which converts to the tightly packed uint8
        // RGBA this used to assume it already had. package:image keeps 1 byte a
        // pixel for grayscale and palette images, 3 for RGB, and packed bits for
        // a 1-bit palette, so handing its own storage straight over overran the
        // alpha loop with a RangeError - or, at equal length, permuted the
        // colours.
        image = PdfImage.file(painter.document, bytes: bytes);
      } catch (e) {
        assert(() {
          if (painter.document.settings.verbose) {
            print('Unable to decode the <image> data URI: $e');
          }
          return true;
        }());
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
          ..translateByDouble(x, y + height, 0, 1)
          ..scaleByDouble(sx, -sy, 1, 1),
      )
      ..drawImage(image!, 0, 0);
  }

  @override
  void drawShape(PdfGraphics canvas) {}

  @override
  PdfRect boundingBox() => PdfRect(x, y, width, height);
}

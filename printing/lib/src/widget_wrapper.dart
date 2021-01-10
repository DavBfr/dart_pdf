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

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Wrap a Flutter Widget identified by a GlobalKey to a PdfImage.
@Deprecated('Use WidgetWraper.fromKey() instead')
Future<PdfImage> wrapWidget(
  PdfDocument document, {
  @required GlobalKey key,
  int width,
  int height,
  double pixelRatio = 1.0,
}) async {
  assert(key != null);
  assert(pixelRatio != null && pixelRatio > 0);

  final RenderRepaintBoundary wrappedWidget =
      key.currentContext.findRenderObject();
  final image = await wrappedWidget.toImage(pixelRatio: pixelRatio);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final imageData = byteData.buffer.asUint8List();
  return PdfImage(document,
      image: imageData, width: image.width, height: image.height);
}

/// ImageProvider that draws a Flutter Widget on a PDF document
class WidgetWraper extends pw.ImageProvider {
  WidgetWraper._(
    this.bytes,
    int width,
    int height,
    PdfImageOrientation orientation,
    double dpi,
  ) : super(width, height, orientation, dpi);

  /// Wrap a Flutter Widget identified by a GlobalKey to an ImageProvider.
  ///
  /// Use it with a RepaintBoundary:
  /// ```
  /// final rb = GlobalKey();
  ///
  /// @override
  /// Widget build(BuildContext context) {
  ///   return RepaintBoundary(
  ///       key: rb,
  ///       child: FlutterLogo()
  ///   );
  /// }
  ///
  /// Future<Uint8List> _generatePdf(PdfPageFormat format) async {
  ///   final pdf = pw.Document();
  ///
  ///   final image = await WidgetWraper.fromKey(key: rb);
  ///
  ///   pdf.addPage(
  ///     pw.Page(
  ///       build: (context) {
  ///         return pw.Center(
  ///           child: pw.Image(image),
  ///         );
  ///       },
  ///     ),
  ///   );
  ///
  ///   return pdf.save();
  /// }
  /// ```
  static Future<WidgetWraper> fromKey({
    @required GlobalKey key,
    int width,
    int height,
    double pixelRatio = 1.0,
    PdfImageOrientation orientation,
    double dpi,
  }) async {
    assert(key != null);
    assert(pixelRatio != null && pixelRatio > 0);

    final RenderRepaintBoundary wrappedWidget =
        key.currentContext.findRenderObject();
    final image = await wrappedWidget.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final imageData = byteData.buffer.asUint8List();
    return WidgetWraper._(
      imageData,
      image.width,
      image.height,
      orientation ?? PdfImageOrientation.topLeft,
      dpi,
    );
  }

  /// The image data
  final Uint8List bytes;

  @override
  PdfImage buildImage(pw.Context context, {int width, int height}) {
    return PdfImage(
      context.document,
      image: bytes,
      width: width ?? this.width,
      height: height ?? this.height,
      orientation: orientation,
    );
  }
}

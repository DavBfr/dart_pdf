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
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// ImageProvider that draws a Flutter Widget on a PDF document
class WidgetWrapper extends pw.ImageProvider {
  WidgetWrapper._(
    this.bytes,
    int width,
    int height,
    PdfImageOrientation orientation,
    double? dpi,
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
  ///   final image = await WidgetWrapper.fromKey(key: rb);
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
  static Future<WidgetWrapper> fromKey({
    required GlobalKey key,
    int? width,
    int? height,
    double pixelRatio = 1.0,
    PdfImageOrientation? orientation,
    double? dpi,
  }) async {
    assert(pixelRatio > 0);

    final wrappedWidget =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await wrappedWidget.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) {
      return WidgetWrapper._(
        Uint8List(0),
        0,
        0,
        PdfImageOrientation.topLeft,
        dpi,
      );
    }

    final imageData = byteData.buffer.asUint8List();
    return WidgetWrapper._(
      imageData,
      image.width,
      image.height,
      orientation ?? PdfImageOrientation.topLeft,
      dpi,
    );
  }

  /// Wrap a Flutter Widget to an ImageProvider.
  ///
  /// ```
  /// final wrapped = await WidgetWrapper.fromWidget(
  ///   widget: Container(
  ///     color: Colors.white,
  ///     child: Text(
  ///       'Hello world !',
  ///       style: TextStyle(color: Colors.amber),
  ///     ),
  ///   ),
  ///   constraints: BoxConstraints(maxWidth: 100, maxHeight: 400),
  ///   pixelRatio: 3,
  /// );
  ///
  /// pdf.addPage(
  ///   pw.Page(
  ///     pageFormat: format,
  ///     build: (context) {
  ///       return pw.Image(wrapped, width: 100);
  ///     },
  ///   ),
  /// );
  /// ```
  static Future<WidgetWrapper> fromWidget({
    required BuildContext context,
    required Widget widget,
    required BoxConstraints constraints,
    double pixelRatio = 1.0,
    PdfImageOrientation? orientation,
    double? dpi,
  }) async {
    assert(pixelRatio > 0);

    if (!constraints.hasBoundedHeight || !constraints.hasBoundedHeight) {
      throw Exception(
          'Unable to convert an unbounded widget. Add maxWidth and maxHeight to the constraints.');
    }

    widget = ConstrainedBox(
      constraints: constraints,
      child: widget,
    );

    final prop = DiagnosticPropertiesBuilder();
    widget.debugFillProperties(prop);

    if (prop.properties.isEmpty) {
      throw ErrorDescription('Unable to get the widget properties');
    }

    final computedConstraints = prop.properties
        .whereType<DiagnosticsProperty<BoxConstraints>>()
        .first
        .value;

    if (computedConstraints == null ||
        !computedConstraints.hasBoundedWidth ||
        !computedConstraints.hasBoundedWidth) {
      throw Exception('Unable to convert an unbounded widget.');
    }

    final repaintBoundary = RenderRepaintBoundary();
    final view = View.of(context);

    final renderView = RenderView(
      child: RenderPositionedBox(
          alignment: Alignment.center, child: repaintBoundary),
      configuration: ViewConfiguration.fromView(view),
      view: view,
    );

    final pipelineOwner = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();

    final buildOwner = BuildOwner(focusManager: FocusManager());
    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: IntrinsicHeight(child: IntrinsicWidth(child: widget)),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner
      ..buildScope(rootElement)
      ..finalizeTree();

    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();

    final image = await repaintBoundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) {
      throw Exception('Unable to read image data');
    }

    return WidgetWrapper._(
      bytes.buffer.asUint8List(),
      image.width,
      image.height,
      orientation ?? PdfImageOrientation.topLeft,
      dpi,
    );
  }

  /// The image data
  final Uint8List bytes;

  @override
  PdfImage buildImage(pw.Context context, {int? width, int? height}) {
    return PdfImage(
      context.document,
      image: bytes,
      width: width ?? this.width!,
      height: height ?? this.height!,
      orientation: orientation,
    );
  }
}

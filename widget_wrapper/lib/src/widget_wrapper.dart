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

    try {
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData == null) {
        return WidgetWrapper._(
          Uint8List(0),
          0,
          0,
          PdfImageOrientation.topLeft,
          dpi,
        );
      }

      // A copy of the pixels, so it stays valid once the image is gone.
      final imageData = byteData.buffer.asUint8List();
      return WidgetWrapper._(
        imageData,
        image.width,
        image.height,
        orientation ?? PdfImageOrientation.topLeft,
        dpi,
      );
    } finally {
      // The full-resolution image was never released.
      image.dispose();
    }
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

    // Both axes, not hasBoundedHeight twice: an unbounded width used to reach
    // the block below and be reported as something else entirely.
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      throw Exception(
        'Unable to convert an unbounded widget. Add maxWidth and maxHeight to the constraints.',
      );
    }

    widget = ConstrainedBox(constraints: constraints, child: widget);

    // What stood here read the constraints back out of debug diagnostics -
    // widget.debugFillProperties, then a throw when the property list came back
    // empty. DiagnosticPropertiesBuilder.add is assert-guarded, so in any
    // release or profile build that list is always empty and this always threw
    // ErrorDescription('Unable to get the widget properties') before rendering
    // anything. The value it recovered was provably the ConstrainedBox argument
    // applied on the line above, which the check at the top of this method has
    // already validated.

    final repaintBoundary = RenderRepaintBoundary();
    final positionedBox = RenderPositionedBox(
      alignment: Alignment.center,
      child: repaintBoundary,
    );
    final view = View.of(context);

    final renderView = RenderView(
      child: positionedBox,
      configuration: ViewConfiguration.fromView(view),
      view: view,
    );

    final pipelineOwner = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();

    // FocusManager's constructor registers a WidgetsBinding observer on web and
    // on every desktop platform, which only its dispose() removes, so every
    // call used to add one permanently.
    final focusManager = FocusManager();
    final buildOwner = BuildOwner(focusManager: focusManager);
    final adapter = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: IntrinsicHeight(child: IntrinsicWidth(child: widget)),
      ),
    );
    final rootElement = adapter.attachToRenderTree(buildOwner);

    ui.Image? image;

    try {
      buildOwner
        ..buildScope(rootElement)
        ..finalizeTree();

      pipelineOwner
        ..flushLayout()
        ..flushCompositingBits()
        ..flushPaint();

      image = await repaintBoundary.toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) {
        throw Exception('Unable to read image data');
      }

      return WidgetWrapper._(
        // A copy, so it stays valid once the image is gone.
        bytes.buffer.asUint8List(),
        image.width,
        image.height,
        orientation ?? PdfImageOrientation.topLeft,
        dpi,
      );
    } finally {
      // Nothing created here outlives this call, including when the capture
      // throws - a widget that lays out to zero size makes toImage throw.
      image?.dispose();

      // Unmount the elements before disposing the render objects they point at:
      // re-attach the adapter with no child, then let the build owner finish.
      RenderObjectToWidgetAdapter<RenderBox>(
        container: repaintBoundary,
      ).attachToRenderTree(buildOwner, rootElement);
      buildOwner
        ..buildScope(rootElement)
        ..finalizeTree();

      pipelineOwner.rootNode = null;
      renderView.child = null;
      positionedBox.child = null;

      repaintBoundary.dispose();
      positionedBox.dispose();
      renderView.dispose();
      pipelineOwner.dispose();
      focusManager.dispose();
    }
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

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' as material;
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';


class WidgetWrapper {
  static Future<Image> from(
      PdfDocument document, {@material.required material.GlobalKey key, int width, int height}) async {

    final RenderRepaintBoundary wrappedWidget =
    key.currentContext.findRenderObject();
    ui.Image image = await wrappedWidget.toImage();

    image = await image.resize(width: width, height: height);

    final ByteData byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final Uint8List imageData = byteData.buffer.asUint8List();
    final PdfImage img = PdfImage(document, image: imageData, width: image.width, height: image.height);
    return Image(img);
  }
}


extension Resizing on ui.Image {
  Future<ui.Image> resize(
      {int width,
        int height,}) async {

    if (width == null && height == null) { return this; }
    width ??= (height/this.height * this.width).toInt();
    height ??= (width/this.width * this.height).toInt();

    final Completer<ui.Image> ptr = Completer<ui.Image>();
    final Uint8List data =
    (await toByteData(format: ui.ImageByteFormat.rawRgba)).buffer.asUint8List();
    ui.decodeImageFromPixels(
      data,
      this.width,
      this.height,
      ui.PixelFormat.rgba8888,
          (ui.Image result) {
        ptr.complete(result);
      },
      targetWidth: width,
      targetHeight: height,
    );
    return ptr.future;
  }
}

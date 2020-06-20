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
import 'dart:convert';
import 'dart:html' as html;
import 'dart:html';
import 'dart:io';
import 'dart:js' as js;
import 'dart:js_util';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/rendering.dart' show Rect;
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:image/image.dart' as im;
import 'package:pdf/pdf.dart';
import 'package:printing/src/pdfjs.dart';
import 'package:printing/src/printer.dart';
import 'package:printing/src/raster.dart';

import 'callback.dart';
import 'interface.dart';
import 'printing_info.dart';

/// Print plugin targetting Flutter on the Web
class PrintingPlugin extends PrintingPlatform {
  /// Registers this class as the default instance of [PrintingPlugin].
  static void registerWith(Registrar registrar) {
    PrintingPlatform.instance = PrintingPlugin();
  }

  static const String _frameId = '__net_nfet_printing__';

  @override
  Future<PrintingInfo> info() async {
    final dynamic workerSrc = js.context.callMethod('eval', <String>[
      'typeof pdfjsLib !== "undefined" && pdfjsLib.GlobalWorkerOptions.workerSrc!="";'
    ]);

    return PrintingInfo(
      directPrint: false,
      dynamicLayout: false,
      canPrint: true,
      canConvertHtml: false,
      canShare: true,
      canRaster: workerSrc,
    );
  }

  @override
  Future<bool> layoutPdf(
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
  ) async {
    final result = await onLayout(format);

    if (result == null || result.isEmpty) {
      return false;
    }

    final isChrome = js.context['chrome'] != null;
    final isSafari = js.context['safari'] != null;
    // Maybe Firefox 75 will support iframe printing
    // https://bugzilla.mozilla.org/show_bug.cgi?id=911444

    if (!isChrome && !isSafari) {
      final pr = 'data:application/pdf;base64,${base64.encode(result)}';
      final html.Window win = js.context['window'];
      win.open(pr, name);

      return true;
    }

    final completer = Completer<bool>();
    final pdfFile = html.Blob(
      <Uint8List>[Uint8List.fromList(result)],
      'application/pdf',
    );
    final pdfUrl = html.Url.createObjectUrl(pdfFile);
    final html.HtmlDocument doc = js.context['document'];

    final frame = doc.getElementById(_frameId) ?? doc.createElement('iframe');
    frame.setAttribute(
      'style',
      'visibility: hidden; height: 0; width: 0; position: absolute;',
      // 'height: 400px; width: 600px; position: absolute; z-index: 1000',
    );

    frame.setAttribute('id', _frameId);
    frame.setAttribute('src', pdfUrl);

    html.EventListener load;
    load = (html.Event event) {
      frame.removeEventListener('load', load);
      final js.JsObject win =
          js.JsObject.fromBrowserObject(frame)['contentWindow'];
      frame.focus();
      win.callMethod('print');
      completer.complete(true);
    };

    frame.addEventListener('load', load);

    doc.body.append(frame);
    return completer.future;
  }

  @override
  Future<bool> sharePdf(
    Uint8List bytes,
    String filename,
    Rect bounds,
  ) async {
    final pdfFile = html.Blob(
      <Uint8List>[Uint8List.fromList(bytes)],
      'application/pdf',
    );
    final pdfUrl = html.Url.createObjectUrl(pdfFile);
    final html.HtmlDocument doc = js.context['document'];
    final html.AnchorElement link = doc.createElement('a');
    link.href = pdfUrl;
    link.download = filename;
    link.click();
    return true;
  }

  @override
  Future<Uint8List> convertHtml(
    String html,
    String baseUrl,
    PdfPageFormat format,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<bool> directPrintPdf(
    Printer printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Printer> pickPrinter(
    Rect bounds,
  ) {
    throw UnimplementedError();
  }

  @override
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int> pages,
    double dpi,
  ) async* {
    final t = PdfJs.getDocument(Settings()..data = document);

    final d = await promiseToFuture<PdfJsDoc>(t.promise);
    final numPages = d.numPages;

    final html.CanvasElement canvas =
        js.context['document'].createElement('canvas');
    final html.CanvasRenderingContext2D context = canvas.getContext('2d');

    for (var i = 0; i < numPages; i++) {
      final page = await promiseToFuture<PdfJsPage>(d.getPage(i + 1));
      final viewport = page.getViewport(Settings()..scale = 1.5);

      canvas.height = viewport.height.toInt();
      canvas.width = viewport.width.toInt();

      final renderContext = Settings()
        ..canvasContext = context
        ..viewport = viewport;

      await promiseToFuture<void>(page.render(renderContext).promise);

      // final Uint8ClampedList data =
      // context.getImageData(0, 0, canvas.width, canvas.height).data;

      // Convert the image to PNG
      final completer = Completer<void>();
      final blob = await canvas.toBlob();
      final data = BytesBuilder();
      final r = FileReader();
      r.readAsArrayBuffer(blob);
      r.onLoadEnd.listen(
        (ProgressEvent e) {
          data.add(r.result);
          completer.complete();
        },
      );
      await completer.future;

      yield _WebPdfRaster(
        canvas.width,
        canvas.height,
        data.toBytes(),
      );
    }
  }
}

class _WebPdfRaster extends PdfRaster {
  _WebPdfRaster(
    int width,
    int height,
    this.png,
  ) : super(width, height, null);

  final Uint8List png;

  Uint8List _pixels;

  @override
  Uint8List get pixels {
    if (_pixels == null) {
      final img = asImage();
      _pixels = img.data.buffer.asUint8List();
    }

    return _pixels;
  }

  @override
  Future<Image> toImage() {
    final comp = Completer<Image>();
    decodeImageFromPixels(
      png,
      width,
      height,
      PixelFormat.rgba8888,
      (Image image) => comp.complete(image),
    );
    return comp.future;
  }

  @override
  Future<Uint8List> toPng() async {
    return png;
  }

  @override
  im.Image asImage() {
    if (_pixels != null) {
      return super.asImage();
    }
    return im.PngDecoder().decodeImage(png);
  }
}

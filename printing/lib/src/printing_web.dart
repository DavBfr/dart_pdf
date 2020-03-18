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
import 'dart:js' as js;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/rendering.dart' show Rect;
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/src/printer.dart';
import 'package:printing/src/raster.dart';

import 'callback.dart';
import 'interface.dart';
import 'printing_info.dart';

class PrintingPlugin extends PrintingPlatform {
  /// Registers this class as the default instance of [PrintingPlugin].
  static void registerWith(Registrar registrar) {
    PrintingPlatform.instance = PrintingPlugin();
  }

  static const String _frameId = '__net_nfet_printing__';

  @override
  Future<PrintingInfo> info() async {
    return const PrintingInfo(
      directPrint: false,
      dynamicLayout: false,
      canPrint: true,
      canConvertHtml: false,
      canShare: true,
    );
  }

  @override
  Future<bool> layoutPdf(
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
  ) async {
    final Uint8List result = await onLayout(format);

    if (result == null || result.isEmpty) {
      return false;
    }

    final bool isChrome = js.context['chrome'] != null;
    final bool isSafari = js.context['safari'] != null;
    // Maybe Firefox 75 will support iframe printing
    // https://bugzilla.mozilla.org/show_bug.cgi?id=911444

    if (!isChrome && !isSafari) {
      final String pr = 'data:application/pdf;base64,${base64.encode(result)}';
      final html.Window win = js.context['window'];
      win.open(pr, name);

      return true;
    }

    final Completer<bool> completer = Completer<bool>();
    final html.Blob pdfFile = html.Blob(
      <Uint8List>[Uint8List.fromList(result)],
      'application/pdf',
    );
    final String pdfUrl = html.Url.createObjectUrl(pdfFile);
    final html.HtmlDocument doc = js.context['document'];

    final html.Element frame =
        doc.getElementById(_frameId) ?? doc.createElement('iframe');
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
    final html.Blob pdfFile = html.Blob(
      <Uint8List>[Uint8List.fromList(bytes)],
      'application/pdf',
    );
    final String pdfUrl = html.Url.createObjectUrl(pdfFile);
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
  ) {
    throw UnimplementedError();
  }
}

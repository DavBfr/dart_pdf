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
import 'dart:js_interop' as js;
import 'dart:js_interop_unsafe' as js;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:pdf/pdf.dart';
import 'package:web/web.dart' as web;

import 'src/callback.dart';
import 'src/interface.dart';
import 'src/mutex.dart';
import 'src/output_type.dart';
import 'src/pdfjs.dart';
import 'src/pdfjs_urls.dart';
import 'src/printer.dart';
import 'src/printing_info.dart';
import 'src/raster.dart';

const _dartPdfJsVersion = 'dartPdfJsVersion';
const _dartPdfJsBaseUrl = 'dartPdfJsBaseUrl';
const _dartPdfJsCMapUrl = 'dartPdfJsCMapUrl';

/// Print plugin targeting Flutter on the Web
class PrintingPlugin extends PrintingPlatform {
  /// Registers this class as the default instance of [PrintingPlugin].
  static void registerWith(Registrar registrar) {
    PrintingPlatform.instance = PrintingPlugin();
  }

  static const String _scriptId = '__net_nfet_printing_s__';

  static const String _frameId = '__net_nfet_printing__';

  final _loading = Mutex();

  bool get _hasPdfJsLib => web.window
      .callMethod<js.JSBoolean>(
        'eval'.toJS,
        'typeof pdfjsLib !== "undefined" && pdfjsLib.GlobalWorkerOptions.workerSrc != "";'
            .toJS,
      )
      .toDart;

  /// The URLs this plugin resolved for pdf.js.
  ///
  /// Null when the host page supplied the library itself and configured no
  /// cmaps URL: the plugin then has no idea where that copy keeps its cmaps.
  /// This used to be a `late String` assigned only on the loading path, so
  /// reading it in [raster] would have thrown a LateInitializationError - which
  /// the dead guard there hid.
  PdfJsUrls? _pdfJsUrls;

  /// Set once pdf.js is available, so the queued callers woken by one load do
  /// not each import it again.
  bool _pdfJsLoaded = false;

  /// The last load failure, reported to further callers for
  /// [_pdfJsRetryCooldown] instead of having all of them retry at once.
  Object? _pdfJsError;

  DateTime? _pdfJsErrorAt;

  static const _pdfJsRetryCooldown = Duration(seconds: 10);

  static const _pdfJsLoadTimeout = Duration(seconds: 30);

  Future<void> _initPlugin() => _loading.protect(_loadPdfJs);

  Future<void> _loadPdfJs() async {
    final failedAt = _pdfJsErrorAt;
    if (_pdfJsError != null &&
        failedAt != null &&
        DateTime.now().difference(failedAt) < _pdfJsRetryCooldown) {
      // Report the same failure rather than letting every queued caller
      // re-issue an import that just failed.
      throw _pdfJsError!;
    }

    if (_pdfJsLoaded) {
      return;
    }

    try {
      await _importPdfJs();
      _pdfJsLoaded = true;
      _pdfJsError = null;
      _pdfJsErrorAt = null;
    } catch (e) {
      _pdfJsError = e;
      _pdfJsErrorAt = DateTime.now();
      rethrow;
    }
  }

  /// A string set on `window` by the app, or null when unset or empty.
  String? _configured(String name) {
    if (!web.window.hasProperty(name.toJS).toDart) {
      return null;
    }

    final value = web.window.getProperty<js.JSString?>(name.toJS)?.toDart;
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> _importPdfJs() async {
    final hostProvided = _hasPdfJsLib;
    final configuredCMapUrl = _configured(_dartPdfJsCMapUrl);

    // A library this plugin did not load says nothing about where its cmaps
    // are, so only an explicit override applies in that case.
    if (!hostProvided || configuredCMapUrl != null) {
      _pdfJsUrls = PdfJsUrls.resolve(
        documentBaseUri: web.window.document.baseURI,
        configuredBase: _configured(_dartPdfJsBaseUrl),
        configuredCMapUrl: configuredCMapUrl,
        version: _configured(_dartPdfJsVersion) ?? PdfJsUrls.defaultVersion,
      );
    }

    if (hostProvided) {
      return;
    }

    final urls = _pdfJsUrls!;

    // pdf.js 4+ ships ES modules only (.mjs), so load it with a dynamic
    // import() instead of a classic <script> tag. The URLs are JSON-encoded:
    // they come from the page, and a quote in one of them used to be a syntax
    // error in this script.
    await web.window
        .callMethod<js.JSPromise>(
          'eval'.toJS,
          '''
(async function() {
  var m = await import(${jsonEncode(urls.module)});
  window.pdfjsLib = m;
  m.GlobalWorkerOptions.workerSrc = ${jsonEncode(urls.worker)};
})()'''
              .toJS,
        )
        .toDart
        // A proxy that black-holes the request would otherwise leave every
        // caller waiting forever.
        .timeout(_pdfJsLoadTimeout);
  }

  @override
  Future<PrintingInfo> info() async {
    await _initPlugin();
    return PrintingInfo(
      canPrint: true,
      canShare: true,
      canRaster: _hasPdfJsLib,
    );
  }

  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
    bool forceCustomPrintPaper,
    bool windowsModernDialog,
  ) async {
    late Uint8List result;
    try {
      result = await onLayout(format);
    } catch (e, s) {
      InformationCollector? collector;

      assert(() {
        collector = () sync* {
          yield StringProperty('PageFormat', format.toString());
        };
        return true;
      }());

      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: s,
          stackFilter: (input) => input,
          library: 'printing',
          context: ErrorDescription('while generating a PDF'),
          informationCollector: collector,
        ),
      );

      rethrow;
    }

    if (result.isEmpty) {
      return false;
    }

    // UserAgent can contain both Chrome and Safari for Chrome browser.
    // UserAgent contains only Safari for Safari browser.
    final userAgent = web.window.navigator.userAgent;
    final isChrome = userAgent.contains('Chrome');
    final isSafari = userAgent.contains('Safari') && !isChrome;
    final isFirefox = userAgent.contains('Firefox');
    final isMobile = userAgent.contains('Mobile');

    // Chrome, Safari, and Firefox on a desktop computer
    if ((isChrome || isSafari || isFirefox) && !isMobile) {
      final completer = Completer<bool>();
      final pdfFile = web.Blob(
        [result.toJS].toJS,
        web.BlobPropertyBag(type: 'application/pdf'),
      );
      final pdfUrl = web.URL.createObjectURL(pdfFile);
      final doc = web.window.document;

      final script =
          doc.getElementById(_scriptId) ?? doc.createElement('script');
      script.setAttribute('id', _scriptId);
      script.setAttribute('type', 'text/javascript');
      script.innerHTML =
          '''function ${_frameId}_print(){var f=document.getElementById('$_frameId');f.focus();f.contentWindow.print();}'''
              .toJS;
      doc.body!.append(script);

      final frame = doc.getElementById(_frameId) ?? doc.createElement('iframe');
      if (isFirefox) {
        // Set the iframe to be is visible on the page (guaranteed by fixed position) but hidden using opacity 0, because
        // this works in Firefox. The height needs to be sufficient for some part of the document other than the PDF
        // viewer's toolbar to be visible in the page
        frame.setAttribute(
          'style',
          'width: 1px; height: 100px; position: fixed; left: 0; top: 0; opacity: 0; border-width: 0; margin: 0; padding: 0',
        );
      } else {
        // Hide the iframe in other browsers
        frame.setAttribute(
          'style',
          'visibility: hidden; height: 0; width: 0; position: absolute;',
          // 'height: 400px; width: 600px; position: absolute; z-index: 1000',
        );
      }

      frame.setAttribute('id', _frameId);
      frame.setAttribute('src', pdfUrl);
      final stopWatch = Stopwatch();

      web.EventListener? load;
      load = (web.Event event) {
        frame.removeEventListener('load', load);
        Timer(Duration(milliseconds: isSafari ? 500 : 0), () {
          try {
            stopWatch.start();
            web.window.callMethod('${_frameId}_print'.toJS);
            stopWatch.stop();
            completer.complete(true);
          } catch (e) {
            assert(() {
              // ignore: avoid_print
              print('Error: $e');
              return true;
            }());
            completer.complete(_getPdf(result));
          }
        });
      }.toJS;

      frame.addEventListener('load', load);

      doc.body!.append(frame);

      final res = await completer.future;
      // If print() is synchronous
      if (stopWatch.elapsedMilliseconds > 1000) {
        frame.remove();
        script.remove();
      }
      return res;
    }

    return _getPdf(result);
  }

  @override
  Future<bool> sharePdf(
    Uint8List bytes,
    String filename,
    Rect bounds,
    String? subject,
    String? body,
    List<String>? emails,
  ) async {
    return _getPdf(bytes, filename: filename);
  }

  Future<bool> _getPdf(Uint8List bytes, {String? filename}) async {
    final pdfFile = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final pdfUrl = web.URL.createObjectURL(pdfFile);
    final doc = web.window.document;
    final link = web.HTMLAnchorElement()..href = pdfUrl;
    if (filename != null) {
      link.download = filename;
    } else {
      link.target = '_blank';
    }
    doc.body?.append(link);
    link.click();
    link.remove();
    return true;
  }

  @override
  Future<Uint8List> convertHtml(
    String html,
    String? baseUrl,
    PdfPageFormat format,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<Printer>> listPrinters() {
    throw UnimplementedError();
  }

  @override
  Future<Printer> pickPrinter(Rect bounds) {
    throw UnimplementedError();
  }

  @override
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int>? pages,
    double dpi,
  ) async* {
    await _initPlugin();

    // pdf.js 4+ transfers TypedArrays to the worker and takes ownership of the
    // buffer, which neuters the caller's Uint8List. Copy first so the app can
    // still download/share the same document bytes after preview rasterization.
    final settings = Settings()..data = Uint8List.fromList(document).toJS;

    // This used to test !_hasPdfJsLib, which _initPlugin() above has just made
    // true, so the CMap configuration was never applied and text using a
    // predefined CMap silently disappeared.
    final cMapUrl = _pdfJsUrls?.cMap;
    if (cMapUrl != null) {
      settings
        ..cMapUrl = cMapUrl
        ..cMapPacked = true;
    }

    final jsDoc = getDocument(settings);
    try {
      final doc = await jsDoc.promise.toDart;
      final numPages = doc.numPages;

      final canvas =
          web.window.document.createElement('canvas') as web.HTMLCanvasElement;

      final context = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
      final computedPages =
          pages ?? Iterable<int>.generate(numPages, (index) => index);

      for (final pageIndex in computedPages) {
        final page = await doc.getPage(pageIndex + 1).toDart;
        try {
          final viewport = page.getViewport(
            Settings()..scale = dpi / PdfPageFormat.inch,
          );

          canvas.height = viewport.height.toInt();
          canvas.width = viewport.width.toInt();

          final renderContext = Settings()
            ..canvasContext = context
            ..viewport = viewport;

          await page.render(renderContext).promise.toDart;

          // Convert the image to PNG
          final completer = Completer<void>();
          final blobCompleter = Completer<web.Blob?>();
          canvas.toBlob(
            // ignore: unnecessary_lambdas
            (web.Blob? blob) {
              blobCompleter.complete(blob);
            }.toJS,
          );
          final blob = await blobCompleter.future;
          if (blob == null) {
            continue;
          }
          final data = BytesBuilder();
          final r = web.FileReader();
          r.readAsArrayBuffer(blob);

          r.onLoadEnd.listen((web.ProgressEvent e) {
            data.add((r.result! as js.JSArrayBuffer).toDart.asInt8List());
            completer.complete();
          });
          await completer.future;

          yield _WebPdfRaster(canvas.width, canvas.height, data.toBytes());
        } finally {
          page.cleanup();
        }
      }
    } finally {
      jsDoc.destroy();
    }
  }
}

class _WebPdfRaster extends PdfRaster {
  _WebPdfRaster(int width, int height, this.png)
    : super(width, height, Uint8List(0));

  final Uint8List png;

  Uint8List? _pixels;

  @override
  Uint8List get pixels {
    _pixels ??= PdfRasterBase.fromPng(png).pixels;
    return _pixels!;
  }

  @override
  Future<Image> toImage() async {
    final codec = await instantiateImageCodec(png);
    final frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  @override
  Future<Uint8List> toPng() async {
    return png;
  }
}

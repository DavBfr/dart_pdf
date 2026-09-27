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

import 'package:flutter/foundation.dart'
    show
        ErrorDescription,
        FlutterError,
        FlutterErrorDetails,
        InformationCollector,
        StringProperty,
        visibleForTesting;
import 'package:flutter/rendering.dart' show Rect;
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:pdf/pdf.dart';

import 'callback.dart';
import 'interface.dart';
import 'output_type.dart';
import 'print_job.dart';
import 'printer.dart';
import 'printing_info.dart';
import 'raster.dart';

const MethodChannel _channel = MethodChannel('net.nfet.printing');

/// An implementation of [PrintingPlatform] that uses method channels.
class MethodChannelPrinting extends PrintingPlatform {
  /// Create a [PrintingPlatform] object for method channels.
  MethodChannelPrinting() : super() {
    _channel.setMethodCallHandler(_handleMethod);
  }

  static final _printJobs = PrintJobs();

  /// Number of print jobs still waiting for a platform callback.
  @visibleForTesting
  static int get pendingJobs => _printJobs.pending;

  /// Callbacks from platform plugin
  static Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onLayout':
        final job = _printJobs.getJob(call.arguments['job']);
        if (job == null) {
          return;
        }
        final format = PdfPageFormat(
          call.arguments['width'],
          call.arguments['height'],
          marginLeft: call.arguments['marginLeft'],
          marginTop: call.arguments['marginTop'],
          marginRight: call.arguments['marginRight'],
          marginBottom: call.arguments['marginBottom'],
        );

        Uint8List bytes;
        try {
          bytes = await job.onLayout!(format);
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

        return Uint8List.fromList(bytes);
      case 'onCompleted':
        final bool? completed = call.arguments['completed'];
        final String? error = call.arguments['error'];
        final job = _printJobs.getJob(call.arguments['job']);
        // A native backend may report a result twice; the second one must be
        // ignored rather than raise 'Bad state: Future already completed'.
        if (job != null && !job.onCompleted!.isCompleted) {
          if (completed == false && error != null) {
            job.onCompleted!.completeError(error);
          } else {
            job.onCompleted!.complete(completed);
          }
        }
        break;
      case 'onHtmlRendered':
        final job = _printJobs.getJob(call.arguments['job']);
        if (job != null && !job.onHtmlRendered!.isCompleted) {
          job.onHtmlRendered!.complete(call.arguments['doc']);
        }
        break;
      case 'onHtmlError':
        final job = _printJobs.getJob(call.arguments['job']);
        if (job != null && !job.onHtmlRendered!.isCompleted) {
          job.onHtmlRendered!.completeError(call.arguments['error']);
        }
        break;
      case 'onPageRasterized':
        final job = _printJobs.getJob(call.arguments['job']);
        if (job != null && !job.onPageRasterized!.isClosed) {
          final raster = PdfRaster(
            call.arguments['width'],
            call.arguments['height'],
            call.arguments['image'],
          );
          job.onPageRasterized!.add(raster);
        }
        break;
      case 'onPageRasterEnd':
        final job = _printJobs.getJob(call.arguments['job']);
        if (job != null) {
          // Unregister first: close() is not awaited, so the job must not
          // outlive this callback even if nobody ever listened.
          _printJobs.remove(job.index);
          final controller = job.onPageRasterized!;
          if (!controller.isClosed) {
            final dynamic error = call.arguments['error'];
            if (error != null) {
              controller.addError(error);
            }
            unawaited(controller.close());
          }
        }
        break;
    }
  }

  @override
  Future<PrintingInfo> info() async {
    _channel.setMethodCallHandler(_handleMethod);
    Map<dynamic, dynamic>? result;

    try {
      result = await _channel.invokeMethod('printingInfo', <String, dynamic>{});
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('Error getting printing info: $e');
        return true;
      }());

      return PrintingInfo.unavailable;
    }

    return PrintingInfo.fromMap(result!);
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
    final job = _printJobs.add(
      onCompleted: Completer<bool>(),
      onLayout: onLayout,
    );

    final params = <String, dynamic>{
      if (printer != null) 'printer': printer.url,
      'name': name,
      'job': job.index,
      'width': format.width,
      'height': format.height,
      'marginLeft': format.marginLeft,
      'marginTop': format.marginTop,
      'marginRight': format.marginRight,
      'marginBottom': format.marginBottom,
      'dynamic': dynamicLayout,
      'usePrinterSettings': usePrinterSettings,
      'outputType': outputType.index,
      'forceCustomPrintPaper': forceCustomPrintPaper,
      if (windowsModernDialog) 'windowsModernDialog': windowsModernDialog,
    };

    try {
      await _channel.invokeMethod<int>('printPdf', params);
      return await job.onCompleted!.future;
    } finally {
      _printJobs.remove(job.index);
    }
  }

  @override
  Future<List<Printer>> listPrinters() async {
    final params = <String, dynamic>{};
    final list = await _channel.invokeMethod<List<dynamic>>(
      'listPrinters',
      params,
    );

    final printers = <Printer>[];

    for (final printer in list!) {
      printers.add(Printer.fromMap(printer));
    }

    return printers;
  }

  @override
  Future<Printer?> pickPrinter(Rect bounds) async {
    final params = <String, dynamic>{
      'x': bounds.left,
      'y': bounds.top,
      'w': bounds.width,
      'h': bounds.height,
    };
    final printer = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'pickPrinter',
      params,
    );
    if (printer == null) {
      return null;
    }
    return Printer.fromMap(printer);
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
    final params = <String, dynamic>{
      'doc': Uint8List.fromList(bytes),
      'name': filename,
      'subject': subject,
      'body': body,
      'emails': emails,
      'x': bounds.left,
      'y': bounds.top,
      'w': bounds.width,
      'h': bounds.height,
    };
    return await _channel.invokeMethod<int>('sharePdf', params) != 0;
  }

  @override
  Future<Uint8List> convertHtml(
    String html,
    String? baseUrl,
    PdfPageFormat format,
  ) async {
    final job = _printJobs.add(onHtmlRendered: Completer<Uint8List>());

    final params = <String, dynamic>{
      'html': html,
      'baseUrl': baseUrl,
      'width': format.width,
      'height': format.height,
      'marginLeft': format.marginLeft,
      'marginTop': format.marginTop,
      'marginRight': format.marginRight,
      'marginBottom': format.marginBottom,
      'job': job.index,
    };

    try {
      await _channel.invokeMethod<void>('convertHtml', params);
      return await job.onHtmlRendered!.future;
    } finally {
      _printJobs.remove(job.index);
    }
  }

  @override
  Stream<PdfRaster> raster(Uint8List document, List<int>? pages, double dpi) {
    final controller = StreamController<PdfRaster>();
    final job = _printJobs.add(onPageRasterized: controller);

    // A consumer that stops listening early unregisters the job, so later
    // platform callbacks for it are dropped instead of leaking the entry.
    controller.onCancel = () => _printJobs.remove(job.index);

    final params = <String, dynamic>{
      'doc': Uint8List.fromList(document),
      'pages': pages,
      'scale': dpi / PdfPageFormat.inch,
      'job': job.index,
    };

    unawaited(_startRaster(job, params));
    return controller.stream;
  }

  /// Ask the platform to rasterize the document.
  ///
  /// A successful call does not terminate the stream: the pages arrive later
  /// through `onPageRasterized` and the stream is closed by
  /// `onPageRasterEnd`. Only a failure of the platform call itself is
  /// reported here, so a consumer can never wait forever on a rasterizer
  /// that never started.
  static Future<void> _startRaster(
    PrintJob job,
    Map<String, dynamic> params,
  ) async {
    try {
      await _channel.invokeMethod<void>('rasterPdf', params);
    } catch (e, s) {
      final controller = job.onPageRasterized!;
      if (!controller.isClosed) {
        controller.addError(e, s);
        // Never awaited: close() on a controller nobody listens to yet does
        // not complete until it is subscribed.
        unawaited(controller.close());
      }
      _printJobs.remove(job.index);
    }
  }
}

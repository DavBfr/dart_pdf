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
        StringProperty;
import 'package:flutter/rendering.dart' show Rect;
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:pdf/pdf.dart';

import 'callback.dart';
import 'interface.dart';
import 'method_channel_ffi.dart' if (dart.library.js) 'method_channel_js.dart';
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

          if (job.useFFI) {
            return setErrorFfi(job, e.toString());
          }

          rethrow;
        }

        if (job.useFFI) {
          return setDocumentFfi(job, bytes);
        }

        return Uint8List.fromList(bytes);
      case 'onCompleted':
        final bool? completed = call.arguments['completed'];
        final String? error = call.arguments['error'];
        final job = _printJobs.getJob(call.arguments['job']);
        if (job != null) {
          if (completed == false && error != null) {
            job.onCompleted!.completeError(error);
          } else {
            job.onCompleted!.complete(completed);
          }
        }
        break;
      case 'onHtmlRendered':
        final job = _printJobs.getJob(call.arguments['job']);
        if (job != null) {
          job.onHtmlRendered!.complete(call.arguments['doc']);
        }
        break;
      case 'onHtmlError':
        final job = _printJobs.getJob(call.arguments['job']);
        if (job != null) {
          job.onHtmlRendered!.completeError(call.arguments['error']);
        }
        break;
      case 'onPageRasterized':
        final job = _printJobs.getJob(call.arguments['job']);
        if (job != null) {
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
          final dynamic error = call.arguments['error'];
          if (error != null) {
            job.onPageRasterized!.addError(error);
          }
          await job.onPageRasterized!.close();
          _printJobs.remove(job.index);
        }
        break;
    }
  }

  @override
  Future<PrintingInfo> info() async {
    _channel.setMethodCallHandler(_handleMethod);
    Map<dynamic, dynamic>? result;

    try {
      result = await _channel.invokeMethod(
        'printingInfo',
        <String, dynamic>{},
      );
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
    };

    await _channel.invokeMethod<int>('printPdf', params);
    try {
      return await job.onCompleted!.future;
    } finally {
      _printJobs.remove(job.index);
    }
  }

  @override
  Future<List<Printer>> listPrinters() async {
    final params = <String, dynamic>{};
    final list =
        await _channel.invokeMethod<List<dynamic>>('listPrinters', params);

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
    final job = _printJobs.add(
      onHtmlRendered: Completer<Uint8List>(),
    );

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

    await _channel.invokeMethod<void>('convertHtml', params);
    final result = await job.onHtmlRendered!.future;
    _printJobs.remove(job.index);
    return result;
  }

  @override
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int>? pages,
    double dpi,
  ) {
    final job = _printJobs.add(
      onPageRasterized: StreamController<PdfRaster>(),
    );

    final params = <String, dynamic>{
      'doc': Uint8List.fromList(document),
      'pages': pages,
      'scale': dpi / PdfPageFormat.inch,
      'job': job.index,
    };

    _channel.invokeMethod<void>('rasterPdf', params);
    return job.onPageRasterized!.stream;
  }
}

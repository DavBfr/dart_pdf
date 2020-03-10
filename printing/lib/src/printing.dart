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

part of printing;

typedef LayoutCallback = FutureOr<List<int>> Function(PdfPageFormat format);

mixin Printing {
  static const MethodChannel _channel = MethodChannel('net.nfet.printing');
  static final Map<int, _PrintJob> _printJobs = <int, _PrintJob>{};
  static int _jobIndex = 0;

  /// Callbacks from platform plugins
  static Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onLayout':
        final _PrintJob job = _printJobs[call.arguments['job']];
        try {
          final PdfPageFormat format = PdfPageFormat(
            call.arguments['width'],
            call.arguments['height'],
            marginLeft: call.arguments['marginLeft'],
            marginTop: call.arguments['marginTop'],
            marginRight: call.arguments['marginRight'],
            marginBottom: call.arguments['marginBottom'],
          );

          final List<int> bytes = await job.onLayout(format);

          if (bytes == null) {
            return false;
          }

          return Uint8List.fromList(bytes);
        } catch (e) {
          print('Unable to print: $e');
          return false;
        }
        break;
      case 'onCompleted':
        final bool completed = call.arguments['completed'];
        final String error = call.arguments['error'];
        final _PrintJob job = _printJobs[call.arguments['job']];
        if (completed == false && error != null) {
          job.onCompleted.completeError(error);
        } else {
          job.onCompleted.complete(completed);
        }
        break;
      case 'onHtmlRendered':
        final _PrintJob job = _printJobs[call.arguments['job']];
        job.onHtmlRendered.complete(call.arguments['doc']);
        break;
      case 'onHtmlError':
        final _PrintJob job = _printJobs[call.arguments['job']];
        job.onHtmlRendered.completeError(call.arguments['error']);
        break;
      case 'onPageRasterized':
        final _PrintJob job = _printJobs[call.arguments['job']];
        final PdfRaster raster = PdfRaster._(
          call.arguments['width'],
          call.arguments['height'],
          call.arguments['image'],
        );
        job.onPageRasterized.add(raster);
        break;
      case 'onPageRasterEnd':
        final _PrintJob job = _printJobs[call.arguments['job']];
        job.onPageRasterized.close();
        _printJobs.remove(job.index);
        break;
    }
  }

  static _PrintJob _newPrintJob(_PrintJob job) {
    job.index = _jobIndex++;
    _printJobs[job.index] = job;
    return job;
  }

  /// Prints a Pdf document to a local printer using the platform UI
  /// the Pdf document is re-built in a [LayoutCallback] each time the
  /// user changes a setting like the page format or orientation.
  ///
  /// returns a future with a `bool` set to true if the document is printed
  /// and false if it is canceled.
  /// throws an exception in case of error
  static Future<bool> layoutPdf({
    @required LayoutCallback onLayout,
    String name = 'Document',
    PdfPageFormat format = PdfPageFormat.standard,
  }) async {
    _channel.setMethodCallHandler(_handleMethod);

    final _PrintJob job = _newPrintJob(_PrintJob(
      onCompleted: Completer<bool>(),
      onLayout: onLayout,
    ));

    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      'job': job.index,
      'width': format.width,
      'height': format.height,
      'marginLeft': format.marginLeft,
      'marginTop': format.marginTop,
      'marginRight': format.marginRight,
      'marginBottom': format.marginBottom,
    };

    await _channel.invokeMethod<int>('printPdf', params);
    try {
      return await job.onCompleted.future;
    } finally {
      _printJobs.remove(job.index);
    }
  }

  static Future<Map<dynamic, dynamic>> printingInfo() async {
    return await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'printingInfo',
      <String, dynamic>{},
    );
  }

  /// Opens the native printer picker interface, and returns the URL of the selected printer.
  static Future<Printer> pickPrinter({Rect bounds}) async {
    _channel.setMethodCallHandler(_handleMethod);
    bounds ??= Rect.fromCircle(center: Offset.zero, radius: 10);
    final Map<String, dynamic> params = <String, dynamic>{
      'x': bounds.left,
      'y': bounds.top,
      'w': bounds.width,
      'h': bounds.height,
    };
    final Map<dynamic, dynamic> printer = await _channel
        .invokeMethod<Map<dynamic, dynamic>>('pickPrinter', params);
    if (printer == null) {
      return null;
    }
    return Printer(
      url: printer['url'],
      name: printer['name'],
      model: printer['model'],
      location: printer['location'],
    );
  }

  /// Prints a Pdf document to a specific local printer with no UI
  ///
  /// returns a future with a `bool` set to true if the document is printed
  /// and false if it is canceled.
  /// throws an exception in case of error
  static Future<bool> directPrintPdf({
    @required Printer printer,
    @required LayoutCallback onLayout,
    String name = 'Document',
    PdfPageFormat format = PdfPageFormat.standard,
  }) async {
    if (printer == null) {
      return false;
    }

    _channel.setMethodCallHandler(_handleMethod);

    final _PrintJob job = _newPrintJob(_PrintJob(
      onCompleted: Completer<bool>(),
    ));

    final List<int> bytes = await onLayout(format);
    if (bytes == null) {
      return false;
    }

    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      'printer': printer.url,
      'doc': Uint8List.fromList(bytes),
      'job': job.index,
    };
    await _channel.invokeMethod<int>('directPrintPdf', params);
    final bool result = await job.onCompleted.future;
    _printJobs.remove(job.index);
    return result;
  }

  /// Prints a [PdfDocument] or a pdf stream to a local printer using the platform UI
  @Deprecated('use Printing.layoutPdf(onLayout: (_) => document.save());')
  static Future<void> printPdf({
    @Deprecated('use bytes with document.save()') PdfDocument document,
    List<int> bytes,
  }) async {
    assert(document != null || bytes != null);
    assert(!(document == null && bytes == null));

    layoutPdf(
        onLayout: (PdfPageFormat format) =>
            document != null ? document.save() : bytes);
  }

  /// Displays a platform popup to share the Pdf document to another application
  static Future<void> sharePdf({
    @Deprecated('use bytes with document.save()') PdfDocument document,
    List<int> bytes,
    String filename = 'document.pdf',
    Rect bounds,
  }) async {
    assert(document != null || bytes != null);
    assert(!(document == null && bytes == null));
    assert(filename != null);

    if (document != null) {
      bytes = document.save();
    }

    bounds ??= Rect.fromCircle(center: Offset.zero, radius: 10);

    final Map<String, dynamic> params = <String, dynamic>{
      'doc': Uint8List.fromList(bytes),
      'name': filename,
      'x': bounds.left,
      'y': bounds.top,
      'w': bounds.width,
      'h': bounds.height,
    };
    return await _channel.invokeMethod('sharePdf', params);
  }

  /// Convert an html document to a pdf data
  static Future<List<int>> convertHtml(
      {@required String html,
      String baseUrl,
      PdfPageFormat format = PdfPageFormat.a4}) async {
    _channel.setMethodCallHandler(_handleMethod);

    final _PrintJob job = _newPrintJob(_PrintJob(
      onHtmlRendered: Completer<List<int>>(),
    ));

    final Map<String, dynamic> params = <String, dynamic>{
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
    final List<int> result = await job.onHtmlRendered.future;
    _printJobs.remove(job.index);
    return result;
  }

  static Future<PrintingInfo> info() async {
    _channel.setMethodCallHandler(_handleMethod);
    Map<dynamic, dynamic> result;

    try {
      result = await _channel.invokeMethod(
        'printingInfo',
        <String, dynamic>{},
      );
    } catch (e) {
      print('Error getting printing info: $e');
      return PrintingInfo.unavailable;
    }

    return PrintingInfo.fromMap(result);
  }

  static Stream<PdfRaster> raster(
    List<int> document, {
    List<int> pages,
    double dpi = PdfPageFormat.inch,
  }) {
    _channel.setMethodCallHandler(_handleMethod);

    final _PrintJob job = _newPrintJob(_PrintJob(
      onPageRasterized: StreamController<PdfRaster>(),
    ));

    final Map<String, dynamic> params = <String, dynamic>{
      'doc': Uint8List.fromList(document),
      'pages': pages,
      'scale': dpi / PdfPageFormat.inch,
      'job': job.index,
    };

    _channel.invokeMethod<void>('rasterPdf', params);
    return job.onPageRasterized.stream;
  }
}

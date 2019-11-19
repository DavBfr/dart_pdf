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

@immutable
class Printer {
  const Printer({
    @required this.url,
    this.name,
    this.model,
    this.location,
  }) : assert(url != null);

  final String url;
  final String name;
  final String model;
  final String location;

  @override
  String toString() => name ?? url;
}

mixin Printing {
  static const MethodChannel _channel = MethodChannel('net.nfet.printing');
  static LayoutCallback _onLayout;
  static Completer<List<int>> _onHtmlRendered;
  static Completer<bool> _onCompleted;

  /// Callbacks from platform plugins
  static Future<void> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onLayout':
        try {
          final List<int> bytes = await _onLayout(PdfPageFormat(
            call.arguments['width'],
            call.arguments['height'],
            marginLeft: call.arguments['marginLeft'],
            marginTop: call.arguments['marginTop'],
            marginRight: call.arguments['marginRight'],
            marginBottom: call.arguments['marginBottom'],
          ));
          if (bytes == null) {
            await _channel.invokeMethod<void>('cancelJob', <String, dynamic>{});
            break;
          }
          final Map<String, dynamic> params = <String, dynamic>{
            'doc': Uint8List.fromList(bytes),
          };
          await _channel.invokeMethod<void>('writePdf', params);
        } catch (e) {
          print('Unable to print: $e');
          await _channel.invokeMethod<void>('cancelJob', <String, dynamic>{});
        }
        break;
      case 'onCompleted':
        final bool completed = call.arguments['completed'];
        final String error = call.arguments['error'];
        if (completed == false && error != null) {
          _onCompleted.completeError(error);
        } else {
          _onCompleted.complete(completed);
        }
        break;
      case 'onHtmlRendered':
        _onHtmlRendered.complete(call.arguments);
        break;
      case 'onHtmlError':
        _onHtmlRendered.completeError(call.arguments);
        break;
    }
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
    _onCompleted = Completer<bool>();
    _onLayout = onLayout;
    _channel.setMethodCallHandler(_handleMethod);
    final Map<String, dynamic> params = <String, dynamic>{'name': name};
    try {
      final Map<dynamic, dynamic> info = await printingInfo();
      if (int.parse(info['iosVersion'].toString().split('.').first) >= 13) {
        final List<int> bytes = await onLayout(format);
        if (bytes == null) {
          return false;
        }
        params['doc'] = Uint8List.fromList(bytes);
      }
    } catch (e) {
      e.toString();
    }
    await _channel.invokeMethod<int>('printPdf', params);
    return _onCompleted.future;
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
    _onCompleted = Completer<bool>();
    _channel.setMethodCallHandler(_handleMethod);
    final List<int> bytes = await onLayout(format);
    if (bytes == null) {
      return false;
    }
    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      'printer': printer.url,
      'doc': Uint8List.fromList(bytes),
    };
    await _channel.invokeMethod<int>('directPrintPdf', params);
    return _onCompleted.future;
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
    String filename,
    Rect bounds,
  }) async {
    assert(document != null || bytes != null);
    assert(!(document == null && bytes == null));

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
    final Map<String, dynamic> params = <String, dynamic>{
      'html': html,
      'baseUrl': baseUrl,
      'width': format.width,
      'height': format.height,
      'marginLeft': format.marginLeft,
      'marginTop': format.marginTop,
      'marginRight': format.marginRight,
      'marginBottom': format.marginBottom,
    };

    _channel.setMethodCallHandler(_handleMethod);
    _onHtmlRendered = Completer<List<int>>();
    await _channel.invokeMethod<void>('convertHtml', params);
    return _onHtmlRendered.future;
  }
}

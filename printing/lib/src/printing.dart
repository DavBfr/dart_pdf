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
  static const MethodChannel _channel = MethodChannel('printing');
  static LayoutCallback _onLayout;
  static Completer<List<int>> _onHtmlRendered;
  static Completer<bool> _onCompleted;

  static Future<void> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onLayout':
        final List<int> bytes = await _onLayout(PdfPageFormat(
          call.arguments['width'],
          call.arguments['height'],
          marginLeft: call.arguments['marginLeft'],
          marginTop: call.arguments['marginTop'],
          marginRight: call.arguments['marginRight'],
          marginBottom: call.arguments['marginBottom'],
        ));
        final Map<String, dynamic> params = <String, dynamic>{
          'doc': Uint8List.fromList(bytes),
        };
        return await _channel.invokeMethod('writePdf', params);
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
  }) async {
    _onCompleted = Completer<bool>();
    _onLayout = onLayout;
    _channel.setMethodCallHandler(_handleMethod);
    final Map<String, dynamic> params = <String, dynamic>{'name': name};
    await _channel.invokeMethod<int>('printPdf', params);
    return _onCompleted.future;
  }

  /// Prints a [PdfDocument] or a pdf stream to a local printer using the platform UI
  @Deprecated('use Printing.layoutPdf(onLayout: (_) => document.save());')
  static Future<void> printPdf(
      {@Deprecated('use bytes with document.save()') PdfDocument document,
      List<int> bytes}) async {
    assert(document != null || bytes != null);
    assert(!(document == null && bytes == null));

    layoutPdf(
        onLayout: (PdfPageFormat format) =>
            document != null ? document.save() : bytes);
  }

  /// Displays a platform popup to share the Pdf document to another application
  static Future<void> sharePdf(
      {@Deprecated('use bytes with document.save()') PdfDocument document,
      List<int> bytes,
      String filename,
      Rect bounds}) async {
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

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
    }
  }

  /// Prints a Pdf document to a local printer using the platform UI
  /// the Pdf document is re-built in a [LayoutCallback] each time the
  /// user changes a setting like the page format or orientation.
  static Future<void> layoutPdf(
      {@required LayoutCallback onLayout, String name = 'Document'}) async {
    _onLayout = onLayout;
    _channel.setMethodCallHandler(_handleMethod);
    final Map<String, dynamic> params = <String, dynamic>{'name': name};
    return await _channel.invokeMethod('printPdf', params);
  }

  /// Prints a [PdfDocument] or a pdf stream to a local printer using the platform UI
  @deprecated
  static Future<void> printPdf({PdfDocument document, List<int> bytes}) async {
    assert(document != null || bytes != null);
    assert(!(document == null && bytes == null));

    layoutPdf(
        onLayout: (PdfPageFormat format) =>
            document != null ? document.save() : bytes);
  }

  /// Displays a platform popup to share the Pdf document to another application
  static Future<void> sharePdf(
      {PdfDocument document,
      List<int> bytes,
      String filename,
      Rect bounds}) async {
    assert(document != null || bytes != null);
    assert(!(document == null && bytes == null));

    if (document != null) {
      bytes = document.save();
    }

    bounds ??= Rect.fromCircle(center: Offset.zero, radius: 10.0);

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
}

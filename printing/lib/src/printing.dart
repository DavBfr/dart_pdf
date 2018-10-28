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

class Printing {
  static const MethodChannel _channel = MethodChannel('printing');
  static LayoutCallback _onLayout;

  static Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case "onLayout":
        final bytes = await _onLayout(PdfPageFormat(
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
        await _channel.invokeMethod('writePdf', params);
        return Future.value("");
    }
  }

  static Future<Null> layoutPdf(
      {@required LayoutCallback onLayout, String name = "Document"}) async {
    _onLayout = onLayout;
    _channel.setMethodCallHandler(_handleMethod);
    final Map<String, dynamic> params = <String, dynamic>{'name': name};
    await _channel.invokeMethod('printPdf', params);
  }

  @deprecated
  static Future<Null> printPdf({PdfDocument document, List<int> bytes}) async {
    assert(document != null || bytes != null);
    assert(!(document == null && bytes == null));

    layoutPdf(
        onLayout: (PdfPageFormat format) =>
            document != null ? document.save() : bytes);
  }

  static Future<Null> sharePdf(
      {PdfDocument document, List<int> bytes, Rect bounds}) async {
    assert(document != null || bytes != null);
    assert(!(document == null && bytes == null));

    if (document != null) bytes = document.save();

    if (bounds == null) {
      bounds = Rect.fromCircle(center: Offset.zero, radius: 10.0);
    }

    final Map<String, dynamic> params = <String, dynamic>{
      'doc': Uint8List.fromList(bytes),
      'x': bounds.left,
      'y': bounds.top,
      'w': bounds.width,
      'h': bounds.height,
    };
    await _channel.invokeMethod('sharePdf', params);
  }
}

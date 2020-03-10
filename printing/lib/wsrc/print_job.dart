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

part of printing_web;

class _PrintJob {
  _PrintJob(this.printing, this.index);

  final PrintingPlugin printing;
  final int index;

  String _jobName;

  Future<int> printPdf(
      String name,
      double width,
      double height,
      double marginLeft,
      double marginTop,
      double marginRight,
      double marginBottom) async {
    _jobName = name;
    await printing.onLayout(
        this, width, height, marginLeft, marginTop, marginRight, marginBottom);
    return 1;
  }

  static Future<int> sharePdf(List<int> data, double x, double y, double width,
      double height, String name) async {
    final html.Blob pdfFile = html.Blob(<dynamic>[data], 'application/pdf');
    final String pdfUrl = html.Url.createObjectUrl(pdfFile);
    final html.HtmlDocument doc = js.context['document'];
    final html.AnchorElement link = doc.createElement('a');
    link.href = pdfUrl;
    link.download = name;
    link.click();
    return 1;
  }

  static Map<String, dynamic> printingInfo() {
    return <String, dynamic>{
      'directPrint': false,
      'dynamicLayout': false,
      'canPrint': true,
      'canConvertHtml': false,
      'canShare': true,
    };
  }

  void setDocument(List<int> result) {
    final bool isChrome = js.context['chrome'] != null;

    if (!isChrome) {
      sharePdf(result, 0, 0, 0, 0, _jobName + '.pdf');
      printing.onCompleted(this, true);
      return;
    }

    final html.Blob pdfFile = html.Blob(<dynamic>[result], 'application/pdf');
    final String pdfUrl = html.Url.createObjectUrl(pdfFile);
    final html.HtmlDocument doc = js.context['document'];
    final html.IFrameElement frame = doc.createElement('iframe');
    frame.setAttribute('style',
        'visibility: hidden; height: 0; width: 0; position: absolute;');
    frame.setAttribute('src', pdfUrl);
    doc.body.append(frame);

    frame.addEventListener('load', (html.Event event) {
      final js.JsObject win =
          js.JsObject.fromBrowserObject(frame)['contentWindow'];

      win.callMethod('addEventListener', <dynamic>[
        'afterprint',
        js.allowInterop<html.EventListener>((html.Event event) {
          frame.remove();
          printing.onCompleted(this, true);
        }),
      ]);

      frame.focus();
      win.callMethod('print');
      printing.onCompleted(this, true);
    });
  }

  /// Cancels this job with the applicable error if there is one
  Future<void> cancelJob([dynamic error]) async {
    await printing.onCompleted(this, false, error?.toString());
  }
}

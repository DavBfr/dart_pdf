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

/// How the web backend gets a document in front of the user.
enum WebPrintStrategy {
  /// Load the document into a hidden iframe and call `print()` on it.
  ///
  /// The only strategy that reaches a print dialog.
  iframe,

  /// Hand the document to the browser as a download.
  ///
  /// Not a print: `layoutPdf` reports false, because nothing was printed.
  download,
}

/// Choose how to present a document for printing in this browser.
///
/// Keyed on the engine rather than on the `Mobile` user-agent token. That token
/// made an iPad print through the iframe and an iPhone fall through to a
/// `target=_blank` link that iOS Safari blocks - for the same browser - because
/// iPadOS sends a desktop user agent. [maxTouchPoints] is what tells an iPad
/// with that user agent from a Mac.
///
/// Conservative by design: anything not known to bring up a print dialog gets
/// the download, so the document always reaches the user.
WebPrintStrategy webPrintStrategy({
  required String userAgent,
  int maxTouchPoints = 0,
}) {
  // Chrome's user agent contains Safari, and Edge's and Opera's contain Chrome.
  final isChrome = userAgent.contains('Chrome') || userAgent.contains('CriOS');
  final isFirefox =
      userAgent.contains('Firefox') || userAgent.contains('FxiOS');
  final isSafari =
      userAgent.contains('Safari') &&
      userAgent.contains('Version/') &&
      !isChrome &&
      !isFirefox;

  if (userAgent.contains('Android')) {
    // Android Chrome renders a PDF in an iframe with its own viewer, and
    // print() there prints the viewer chrome rather than the document.
    return WebPrintStrategy.download;
  }

  if (isIosWebKit(userAgent: userAgent, maxTouchPoints: maxTouchPoints)) {
    // Safari drives the iOS print sheet from an iframe. Chrome and Firefox on
    // iOS are WKWebView wrappers, and an embedded WKWebView has no print UI at
    // all, so neither gets the iframe.
    return isSafari ? WebPrintStrategy.iframe : WebPrintStrategy.download;
  }

  return isChrome || isSafari || isFirefox
      ? WebPrintStrategy.iframe
      : WebPrintStrategy.download;
}

/// Whether this is an iOS or iPadOS browser.
///
/// iPadOS Safari sends a Macintosh user agent, which is indistinguishable from
/// a Mac by user agent alone; a touch-point count above one is what separates
/// them.
bool isIosWebKit({required String userAgent, int maxTouchPoints = 0}) {
  if (userAgent.contains('iPhone') ||
      userAgent.contains('iPad') ||
      userAgent.contains('iPod')) {
    return true;
  }

  return userAgent.contains('Macintosh') && maxTouchPoints > 1;
}

/// A file name for the download the web backend offers.
///
/// Given to the anchor's `download` attribute, which no popup blocker stops,
/// instead of the `target=_blank` the fallback used to rely on.
String webPdfFilename(String jobName) {
  final name = jobName.split(RegExp(r'[/\\]')).last.trim();

  if (name.isEmpty || name == '.' || name == '..') {
    return 'document.pdf';
  }

  return name.toLowerCase().endsWith('.pdf') ? name : '$name.pdf';
}

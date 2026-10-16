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

import 'package:flutter_test/flutter_test.dart';
import 'package:printing/src/web_print_policy.dart';

const _desktopChrome =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

const _desktopSafari =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
    '(KHTML, like Gecko) Version/17.0 Safari/605.1.15';

const _desktopFirefox =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:121.0) '
    'Gecko/20100101 Firefox/121.0';

const _iphoneSafari =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 '
    'Safari/604.1';

/// iPadOS sends a Macintosh user agent, identical to desktop Safari's.
const _ipadSafari = _desktopSafari;

const _androidChrome =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

const _iosChrome =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/120.0.0.0 Mobile/15E148 '
    'Safari/604.1';

/// An embedded WKWebView: WebKit, but no Safari and no Version token.
const _iosWebView =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

const _androidWebView =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/UQ1A) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Version/4.0 Chrome/120.0.0.0 Mobile Safari/537.36 wv';

void main() {
  group('webPrintStrategy', () {
    test('desktop browsers print through the frame', () {
      for (final agent in <String>[
        _desktopChrome,
        _desktopSafari,
        _desktopFirefox,
      ]) {
        expect(
          webPrintStrategy(userAgent: agent),
          WebPrintStrategy.iframe,
          reason: agent,
        );
      }
    });

    test('an iPhone and an iPad agree', () {
      // The whole point: the old 'Mobile' token made these two disagree, so an
      // iPad printed and an iPhone silently did nothing, in the same browser.
      expect(
        webPrintStrategy(userAgent: _iphoneSafari),
        webPrintStrategy(userAgent: _ipadSafari, maxTouchPoints: 5),
      );
      expect(
        webPrintStrategy(userAgent: _iphoneSafari),
        WebPrintStrategy.iframe,
      );
    });

    test('a Mac is not mistaken for an iPad', () {
      expect(
        webPrintStrategy(userAgent: _desktopSafari),
        WebPrintStrategy.iframe,
      );
      expect(
        isIosWebKit(userAgent: _desktopSafari),
        isFalse,
        reason: 'no touch points means no iPad',
      );
      expect(isIosWebKit(userAgent: _desktopSafari, maxTouchPoints: 5), isTrue);
    });

    test('Android Chrome takes the download', () {
      expect(
        webPrintStrategy(userAgent: _androidChrome),
        WebPrintStrategy.download,
      );
    });

    test('a web view takes the download, having no print UI', () {
      expect(
        webPrintStrategy(userAgent: _iosWebView),
        WebPrintStrategy.download,
      );
      expect(
        webPrintStrategy(userAgent: _androidWebView),
        WebPrintStrategy.download,
      );
    });

    test('a WebKit wrapper browser on iOS takes the download', () {
      // CriOS and FxiOS are WKWebView wrappers, not Safari.
      expect(
        webPrintStrategy(userAgent: _iosChrome),
        WebPrintStrategy.download,
      );
    });

    test('an unknown browser takes the download', () {
      expect(
        webPrintStrategy(userAgent: 'Mozilla/5.0 (Unknown) SomeEngine/1.0'),
        WebPrintStrategy.download,
      );
    });
  });

  group('webPdfFilename', () {
    test('adds the extension a job name has no reason to carry', () {
      expect(webPdfFilename('Document'), 'Document.pdf');
    });

    test('does not double an extension it already has', () {
      expect(webPdfFilename('report.pdf'), 'report.pdf');
      expect(webPdfFilename('report.PDF'), 'report.PDF');
    });

    test('drops a directory', () {
      expect(webPdfFilename('a/b/report'), 'report.pdf');
      expect(webPdfFilename(r'a\b\report'), 'report.pdf');
    });

    test('falls back for a name that names no file', () {
      expect(webPdfFilename(''), 'document.pdf');
      expect(webPdfFilename('   '), 'document.pdf');
      expect(webPdfFilename('.'), 'document.pdf');
      expect(webPdfFilename('..'), 'document.pdf');
      expect(webPdfFilename('a/'), 'document.pdf');
    });
  });
}

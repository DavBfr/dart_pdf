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

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../callback.dart';

mixin PdfPreviewData implements ChangeNotifier {
  // PdfPreviewData(this.build);

  LayoutCallback get buildDocument;

  PdfPageFormat? _pageFormat;

  PdfPageFormat get initialPageFormat;

  PdfPageFormat get pageFormat => _pageFormat ?? initialPageFormat;

  set pageFormat(PdfPageFormat value) {
    if (_pageFormat == value) {
      return;
    }
    _pageFormat = value;
    notifyListeners();
  }

  bool? _horizontal;

  /// Is the print horizontal
  bool get horizontal => _horizontal ?? pageFormat.width > pageFormat.height;

  set horizontal(bool value) {
    if (_horizontal == value) {
      return;
    }
    _horizontal = value;
    notifyListeners();
  }

  /// Computed page format
  PdfPageFormat get computedPageFormat =>
      horizontal ? pageFormat.landscape : pageFormat.portrait;

  String get localPageFormat {
    final locale = WidgetsBinding.instance!.window.locale;
    // ignore: unnecessary_cast
    final cc = (locale as Locale?)?.countryCode ?? 'US';

    if (cc == 'US' || cc == 'CA' || cc == 'MX') {
      return 'Letter';
    }
    return 'A4';
  }

  PdfPageFormat get actualPageFormat => pageFormat;
}

class PdfPreviewController extends InheritedNotifier {
  const PdfPreviewController({
    Key? key,
    required this.data,
    required Widget child,
  }) : super(key: key, child: child, notifier: data);

  final PdfPreviewData data;

  static PdfPreviewData of(BuildContext context) {
    final result =
        context.findAncestorWidgetOfExactType<PdfPreviewController>();
    assert(result != null, 'No PdfPreview found in context');
    return result!.data;
  }

  static PdfPreviewData listen(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<PdfPreviewController>();
    assert(result != null, 'No PdfPreview found in context');
    return result!.data;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }
}

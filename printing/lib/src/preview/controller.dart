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

typedef ComputePageFormat = PdfPageFormat Function();

class PdfPreviewData extends ChangeNotifier {
  PdfPreviewData({
    PdfPageFormat? initialPageFormat,
    required this.buildDocument,
    required Map<String, PdfPageFormat> pageFormats,
    required ComputePageFormat onComputeActualPageFormat,
  })  : assert(pageFormats.isNotEmpty),
        _onComputeActualPageFormat = onComputeActualPageFormat {
    _pageFormat = initialPageFormat ??
        (pageFormats[localPageFormat] ?? pageFormats.values.first);
  }

  late PdfPageFormat _pageFormat;

  final LayoutCallback buildDocument;

  final ComputePageFormat _onComputeActualPageFormat;

  PdfPageFormat get pageFormat => _pageFormat;

  set pageFormat(PdfPageFormat value) {
    if (_pageFormat != value) {
      _pageFormat = value;
      notifyListeners();
    }
  }

  /// Is the print horizontal
  bool get horizontal => _pageFormat.width > _pageFormat.height;

  set horizontal(bool value) {
    final format = value ? _pageFormat.landscape : _pageFormat.portrait;
    if (format != _pageFormat) {
      _pageFormat = format;
      notifyListeners();
    }
  }

  /// Computed page format
  @Deprecated('Use pageFormat instead')
  PdfPageFormat get computedPageFormat => _pageFormat;

  /// The page format of the document
  PdfPageFormat get actualPageFormat => _onComputeActualPageFormat();

  String get localPageFormat {
    final locale = WidgetsBinding.instance!.window.locale;
    // ignore: unnecessary_cast
    final cc = (locale as Locale?)?.countryCode ?? 'US';

    if (cc == 'US' || cc == 'CA' || cc == 'MX') {
      return 'Letter';
    }
    return 'A4';
  }
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

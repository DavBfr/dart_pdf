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

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/rendering.dart' show Rect, Offset;
import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';

import 'callback.dart';
import 'interface.dart';
import 'printer.dart';
import 'printing_info.dart';
import 'raster.dart';

mixin Printing {
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
  }) {
    assert(onLayout != null);
    assert(name != null);
    assert(format != null);

    return PrintingPlatform.instance.layoutPdf(onLayout, name, format);
  }

  /// Opens the native printer picker interface, and returns the URL of the
  /// selected printer.
  ///
  /// This is not supported on all platforms. Check the result of [info] to
  /// find at runtime if this feature is available or not.
  static Future<Printer> pickPrinter({Rect bounds}) {
    bounds ??= Rect.fromCircle(center: Offset.zero, radius: 10);

    return PrintingPlatform.instance.pickPrinter(bounds);
  }

  /// Prints a Pdf document to a specific local printer with no UI
  ///
  /// returns a future with a `bool` set to true if the document is printed
  /// and false if it is canceled.
  /// throws an exception in case of error
  ///
  /// This is not supported on all platforms. Check the result of [info] to
  /// find at runtime if this feature is available or not.
  static FutureOr<bool> directPrintPdf({
    @required Printer printer,
    @required LayoutCallback onLayout,
    String name = 'Document',
    PdfPageFormat format = PdfPageFormat.standard,
  }) {
    if (printer == null) {
      return false;
    }

    assert(onLayout != null);
    assert(name != null);
    assert(format != null);

    return PrintingPlatform.instance.directPrintPdf(
      printer,
      onLayout,
      name,
      format,
    );
  }

  /// Displays a platform popup to share the Pdf document to another application
  static Future<bool> sharePdf({
    @Deprecated('use bytes with document.save()') PdfDocument document,
    Uint8List bytes,
    String filename = 'document.pdf',
    Rect bounds,
  }) {
    assert(document != null || bytes != null);
    assert(!(document == null && bytes == null));
    assert(filename != null);

    if (document != null) {
      bytes = document.save();
    }

    bounds ??= Rect.fromCircle(center: Offset.zero, radius: 10);

    return PrintingPlatform.instance.sharePdf(
      bytes,
      filename,
      bounds,
    );
  }

  /// Convert an html document to a pdf data
  ///
  /// This is not supported on all platforms. Check the result of [info] to
  /// find at runtime if this feature is available or not.
  static Future<Uint8List> convertHtml({
    @required String html,
    String baseUrl,
    PdfPageFormat format = PdfPageFormat.standard,
  }) {
    assert(html != null);
    assert(format != null);

    return PrintingPlatform.instance.convertHtml(
      html,
      baseUrl,
      format,
    );
  }

  /// Returns a [PrintingInfo] object representing the capabilities
  /// supported for the current platform
  static Future<PrintingInfo> info() {
    return PrintingPlatform.instance.info();
  }

  /// Returns a [PrintingInfo] object representing the capabilities
  /// supported for the current platform as a map
  @Deprecated('Use Printing.info()')
  static Future<Map<dynamic, dynamic>> printingInfo() async {
    return (await info()).asMap();
  }

  /// Convert a PDF to a list of images.
  /// ```dart
  /// await for (final page in Printing.raster(content)) {
  ///   final image = page.asImage();
  /// }
  /// ```
  ///
  /// This is not supported on all platforms. Check the result of [info] to
  /// find at runtime if this feature is available or not.
  static Stream<PdfRaster> raster(
    Uint8List document, {
    List<int> pages,
    double dpi = PdfPageFormat.inch,
  }) {
    assert(document != null);
    assert(dpi != null);
    assert(dpi > 0);

    return PrintingPlatform.instance.raster(document, pages, dpi);
  }

  /// Prints a [PdfDocument] or a pdf stream to a local printer
  /// using the platform UI
  @Deprecated('use Printing.layoutPdf(onLayout: (_) => document.save());')
  static Future<void> printPdf({
    @Deprecated('use bytes with document.save()') PdfDocument document,
    Uint8List bytes,
  }) async {
    assert(document != null || bytes != null);
    assert(!(document == null && bytes == null));

    layoutPdf(
        onLayout: (PdfPageFormat format) =>
            document != null ? document.save() : bytes);
  }
}

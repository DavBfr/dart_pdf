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

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show Rect, Offset;
import 'package:pdf/pdf.dart';

import 'callback.dart';
import 'interface.dart';
import 'printer.dart';
import 'printing_info.dart';
import 'raster.dart';

/// Flutter pdf printing library
mixin Printing {
  /// Prints a Pdf document to a local printer using the platform UI
  /// the Pdf document is re-built in a [LayoutCallback] each time the
  /// user changes a setting like the page format or orientation.
  ///
  /// returns a future with a `bool` set to true if the document is printed
  /// and false if it is canceled.
  /// throws an exception in case of error
  static Future<bool> layoutPdf({
    required LayoutCallback onLayout,
    String name = 'Document',
    PdfPageFormat format = PdfPageFormat.standard,
  }) {
    return PrintingPlatform.instance.layoutPdf(onLayout, name, format);
  }

  /// Enumerate the available printers on the system.
  ///
  /// This is not supported on all platforms. Check the result of [info] to
  /// find at runtime if this feature is available or not.
  static Future<List<Printer>> listPrinters() {
    return PrintingPlatform.instance.listPrinters();
  }

  /// Opens the native printer picker interface, and returns the URL of the
  /// selected printer.
  ///
  /// This is not supported on all platforms. Check the result of [info] to
  /// find at runtime if this feature is available or not.
  static Future<Printer?> pickPrinter({
    required BuildContext context,
    Rect? bounds,
    String? title,
  }) async {
    final _info = await info();

    if (_info.canListPrinters) {
      final printers = await listPrinters();
      printers.sort((a, b) {
        if (a.isDefault) {
          return -1;
        }
        if (b.isDefault) {
          return 1;
        }
        return a.name.compareTo(b.name);
      });

      return await showDialog<Printer>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(title ?? 'Select Printer'),
          children: [
            for (final printer in printers)
              if (printer.isAvailable)
                SimpleDialogOption(
                  child: Text(
                    printer.name,
                    style: TextStyle(
                      fontStyle: printer.isDefault
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(printer),
                ),
          ],
        ),
      );
    }

    bounds ??= Rect.fromCircle(center: Offset.zero, radius: 10);

    return await PrintingPlatform.instance.pickPrinter(bounds);
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
    required Printer printer,
    required LayoutCallback onLayout,
    String name = 'Document',
    PdfPageFormat format = PdfPageFormat.standard,
  }) {
    return PrintingPlatform.instance.directPrintPdf(
      printer,
      onLayout,
      name,
      format,
    );
  }

  /// Displays a platform popup to share the Pdf document to another application
  static Future<bool> sharePdf({
    required Uint8List bytes,
    String filename = 'document.pdf',
    Rect? bounds,
  }) {
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
    required String html,
    String? baseUrl,
    PdfPageFormat format = PdfPageFormat.standard,
  }) {
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
    List<int>? pages,
    double dpi = PdfPageFormat.inch,
  }) {
    assert(dpi > 0);

    return PrintingPlatform.instance.raster(document, pages, dpi);
  }
}

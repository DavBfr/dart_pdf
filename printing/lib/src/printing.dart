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
  ///
  /// Set [usePrinterSettings] to true to use the configuration defined by
  /// the printer. May not work for all the printers and can depend on the
  /// drivers. (Supported platforms: Windows)
  static Future<bool> layoutPdf({
    required LayoutCallback onLayout,
    String name = 'Document',
    PdfPageFormat format = PdfPageFormat.standard,
    bool dynamicLayout = true,
    bool usePrinterSettings = false,
  }) {
    return PrintingPlatform.instance.layoutPdf(
      null,
      onLayout,
      name,
      format,
      dynamicLayout,
      usePrinterSettings,
    );
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
    final printingInfo = await info();

    if (printingInfo.canListPrinters) {
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

      // ignore: use_build_context_synchronously
      return await showDialog<Printer>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(title ?? 'Select Printer'),
          children: [
            for (final printer in printers)
              if (printer.isAvailable)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(printer),
                  child: Text(
                    printer.name,
                    style: TextStyle(
                      fontStyle: printer.isDefault
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
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
  ///
  /// Set [usePrinterSettings] to true to use the configuration defined by
  /// the printer. May not work for all the printers and can depend on the
  /// drivers. (Supported platforms: Windows)
  static FutureOr<bool> directPrintPdf({
    required Printer printer,
    required LayoutCallback onLayout,
    String name = 'Document',
    PdfPageFormat format = PdfPageFormat.standard,
    bool dynamicLayout = true,
    bool usePrinterSettings = false,
  }) {
    return PrintingPlatform.instance.layoutPdf(
      printer,
      onLayout,
      name,
      format,
      dynamicLayout,
      usePrinterSettings,
    );
  }

  /// Displays a platform popup to share the Pdf document to another application.
  ///
  /// [subject] will be the email subject if selected application is email.
  ///
  /// [body] will be the extra text that can be shared along with the Pdf document.
  /// For email application [body] will be the email body text.
  ///
  /// [emails] will be the list of emails to which you want to share the Pdf document.
  /// If the selected application is email application then the these [emails] will be
  /// filled in the to address.
  ///
  /// [subject] and [body] will only work for Android and iOS platforms.
  /// [emails] will only work for Android Platform.
  static Future<bool> sharePdf({
    required Uint8List bytes,
    String filename = 'document.pdf',
    Rect? bounds,
    String? subject,
    String? body,
    List<String>? emails,
  }) {
    bounds ??= Rect.fromCircle(center: Offset.zero, radius: 10);

    return PrintingPlatform.instance.sharePdf(
      bytes,
      filename,
      bounds,
      subject,
      body,
      emails,
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

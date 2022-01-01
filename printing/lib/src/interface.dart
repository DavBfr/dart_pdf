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

import 'package:flutter/rendering.dart' show Rect;
import 'package:pdf/pdf.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'callback.dart';
import 'method_channel.dart';
import 'printer.dart';
import 'printing_info.dart';
import 'raster.dart';

/// The interface that implementations of printing must implement.
abstract class PrintingPlatform extends PlatformInterface {
  /// Constructs a PrintingPlatform.
  PrintingPlatform() : super(token: _token);

  static final Object _token = Object();

  static PrintingPlatform _instance = MethodChannelPrinting();

  /// The default instance of [PrintingPlatform] to use.
  ///
  /// Defaults to [MethodChannelPrinting].
  static PrintingPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [PrintingPlatform] when they register themselves.
  static set instance(PrintingPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns a [PrintingInfo] object representing the capabilities
  /// supported for the current platform
  Future<PrintingInfo> info();

  /// Returns a list of the available system fonts
  Future<List<String>> systemFonts();

  /// Prints a Pdf document to a local printer using the platform UI
  /// the Pdf document is re-built in a [LayoutCallback] each time the
  /// user changes a setting like the page format or orientation.
  ///
  /// returns a future with a `bool` set to true if the document is printed
  /// and false if it is canceled.
  /// throws an exception in case of error
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
  );

  /// Enumerate the available printers on the system.
  Future<List<Printer>> listPrinters();

  /// Opens the native printer picker interface, and returns the URL of the selected printer.
  Future<Printer?> pickPrinter(Rect bounds);

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
  Future<bool> sharePdf(
    Uint8List bytes,
    String filename,
    Rect bounds,
    String? subject,
    String? body,
    List<String>? emails,
  );

  /// Convert an html document to a pdf data
  Future<Uint8List> convertHtml(
    String html,
    String? baseUrl,
    PdfPageFormat format,
  );

  /// Convert a Pdf document to bitmap images
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int>? pages,
    double dpi,
  );
}

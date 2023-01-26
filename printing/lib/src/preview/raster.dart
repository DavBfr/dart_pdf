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
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show InformationCollector, StringProperty, kIsWeb;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../printing.dart';
import '../printing_info.dart';
import '../raster.dart';
import 'custom.dart';
import 'page.dart';

/// Raster PDF documents
mixin PdfPreviewRaster on State<PdfPreviewCustom> {
  static const _updateTime = Duration(milliseconds: 300);

  /// Configured page format
  PdfPageFormat get pageFormat => widget.pageFormat;

  /// Resulting pages
  final pages = <PdfPreviewPageData>[];

  /// Printing subsystem information
  PrintingInfo? info;

  /// Error message
  Object? error;

  /// Dots per inch
  double dpi = PdfPageFormat.inch;

  double? get forcedDpi;

  var _rastering = false;

  Timer? _previewUpdate;

  @override
  void dispose() {
    _previewUpdate?.cancel();
    for (final e in pages) {
      e.image.evict();
    }
    pages.clear();
    super.dispose();
  }

  /// Rasterize the document
  void raster() {
    _previewUpdate?.cancel();
    _previewUpdate = Timer(_updateTime, () {
      if (forcedDpi != null) {
        dpi = forcedDpi!;
      } else {
        final mq = MediaQuery.of(context);
        final double dpr;
        if (!kIsWeb && Platform.isAndroid) {
          if (mq.size.shortestSide * mq.devicePixelRatio < 800) {
            dpr = 2 * mq.devicePixelRatio;
          } else {
            dpr = mq.devicePixelRatio;
          }
        } else {
          dpr = mq.devicePixelRatio;
        }
        dpi =
            (min(mq.size.width - 16, widget.maxPageWidth ?? double.infinity)) *
                dpr /
                pageFormat.width *
                PdfPageFormat.inch;
      }

      _raster();
    });
  }

  Future<void> _raster() async {
    if (_rastering) {
      return;
    }
    _rastering = true;

    Uint8List doc;

    final printingInfo = info;
    if (printingInfo != null && !printingInfo.canRaster) {
      assert(() {
        if (kIsWeb) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: Exception(
                'Unable to find the `pdf.js` library.\nPlease follow the installation instructions at https://github.com/DavBfr/dart_pdf/tree/master/printing#installing'),
            library: 'printing',
            context: ErrorDescription('while rendering a PDF'),
          ));
        }

        return true;
      }());

      _rastering = false;
      return;
    }

    try {
      doc = await widget.build(pageFormat);
    } catch (exception, stack) {
      InformationCollector? collector;

      assert(() {
        collector = () sync* {
          yield StringProperty('PageFormat', pageFormat.toString());
        };
        return true;
      }());

      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'printing',
        context: ErrorDescription('while generating a PDF'),
        informationCollector: collector,
      ));
      if (mounted) {
        setState(() {
          error = exception;
          _rastering = false;
        });
      }

      return;
    }

    if (error != null && mounted) {
      setState(() {
        error = null;
      });
    }

    try {
      var pageNum = 0;
      await for (final PdfRaster page in Printing.raster(
        doc,
        dpi: dpi,
        pages: widget.pages,
      )) {
        if (!mounted) {
          _rastering = false;
          return;
        }
        if (pages.length <= pageNum) {
          pages.add(PdfPreviewPageData(
            image: MemoryImage(await page.toPng()),
            width: page.width,
            height: page.height,
          ));
        } else {
          pages[pageNum].image.evict();
          pages[pageNum] = PdfPreviewPageData(
            image: MemoryImage(await page.toPng()),
            width: page.width,
            height: page.height,
          );
        }

        if (mounted) {
          setState(() {});
        }

        pageNum++;
      }

      for (var index = pageNum; index < pages.length; index++) {
        pages[index].image.evict();
      }
      pages.removeRange(pageNum, pages.length);
      if (mounted) {
        setState(() {});
      }
    } catch (exception, stack) {
      InformationCollector? collector;

      assert(() {
        collector = () sync* {
          yield StringProperty('PageFormat', pageFormat.toString());
        };
        return true;
      }());

      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'printing',
        context: ErrorDescription('while rastering a PDF'),
        informationCollector: collector,
      ));

      if (mounted) {
        setState(() {
          error = exception;
        });
      }
    }

    _rastering = false;
  }
}

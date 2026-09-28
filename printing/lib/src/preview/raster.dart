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
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show InformationCollector, StringProperty, kIsWeb;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../platform_js.dart' if (dart.library.io) '../platform_os.dart';
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

  /// Set when a raster was asked for while one was already running.
  ///
  /// A depth-one queue: the catch-up pass reads live widget state, so it renders
  /// the newest request and never an intermediate one. Without it a page format
  /// or orientation change made while pages were still streaming was simply
  /// dropped, and the preview stayed on the old rendering while the action bar
  /// showed the new setting.
  var _rasterPending = false;

  Timer? _previewUpdate;

  /// The dpi the last raster was requested at, or null before the first one.
  double? _requestedDpi;

  @override
  void dispose() {
    _previewUpdate?.cancel();
    _rasterPending = false;
    for (final e in pages) {
      e.image.evict();
    }
    pages.clear();
    super.dispose();
  }

  /// The resolution to rasterize at, from the current widget and media query.
  ///
  /// Only the size and the device pixel ratio feed this, so a MediaQuery change
  /// that touches anything else leaves it untouched.
  @protected
  double computeDpi() {
    final forced = forcedDpi;
    if (forced != null) {
      return forced;
    }

    final mq = MediaQuery.of(context);
    final double dpr;
    if (isAndroid) {
      if (mq.size.shortestSide * mq.devicePixelRatio < 800) {
        dpr = 2 * mq.devicePixelRatio;
      } else {
        dpr = mq.devicePixelRatio;
      }
    } else {
      dpr = mq.devicePixelRatio;
    }

    return (min(mq.size.width - 16, widget.maxPageWidth ?? double.infinity)) *
        dpr /
        pageFormat.width *
        PdfPageFormat.inch;
  }

  /// Whether a raster at the current dpi would render anything new.
  ///
  /// Used to keep a dependency change that cannot have moved the dpi from
  /// re-running the app's document build.
  bool get needsRasterForDpi {
    // Read unconditionally, and before the null check: this is what registers
    // the MediaQuery dependency, so short-circuiting past it would leave the
    // state depending on nothing and never hearing about a resize at all.
    final current = computeDpi();

    return _requestedDpi == null || _requestedDpi != current;
  }

  /// Rasterize the document
  void raster() {
    _previewUpdate?.cancel();
    _previewUpdate = Timer(_updateTime, () {
      dpi = computeDpi();
      _requestedDpi = dpi;
      _raster();
    });
  }

  Future<void> _raster() async {
    if (_rastering) {
      // Queued rather than dropped, and run from the finally below.
      _rasterPending = true;
      return;
    }
    _rastering = true;

    try {
      await _rasterOnce();
    } finally {
      _rastering = false;

      // Set before the await above completed, so it asked for a render of state
      // that is newer than what was just drawn.
      if (_rasterPending && mounted) {
        _rasterPending = false;
        dpi = computeDpi();
        _requestedDpi = dpi;
        unawaited(_raster());
      } else {
        _rasterPending = false;
      }
    }
  }

  Future<void> _rasterOnce() async {
    Uint8List doc;

    final printingInfo = info;
    if (printingInfo != null && !printingInfo.canRaster) {
      assert(() {
        if (kIsWeb) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: Exception(
                'Unable to find the `pdf.js` library.\nPlease follow the installation instructions at https://github.com/DavBfr/dart_pdf/tree/master/printing#installing',
              ),
              library: 'printing',
              context: ErrorDescription('while rendering a PDF'),
            ),
          );
        }

        return true;
      }());

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

      FlutterError.reportError(
        FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'printing',
          context: ErrorDescription('while generating a PDF'),
          informationCollector: collector,
        ),
      );
      if (mounted) {
        setState(() {
          error = exception;
        });
      }

      // The flag used to be cleared only on this branch, so a build that threw
      // while the widget was unmounted wedged the preview for good.
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
        final png = await page.toPng();

        // `dispose()` clears `pages`, and this resumes after the await above:
        // `pageNum` may no longer be a valid index by the time it does.
        if (!mounted) {
          return;
        }

        if (pages.length <= pageNum) {
          pages.add(
            PdfPreviewPageData(
              image: MemoryImage(png),
              width: page.width,
              height: page.height,
            ),
          );
        } else {
          pages[pageNum].image.evict();
          pages[pageNum] = PdfPreviewPageData(
            image: MemoryImage(png),
            width: page.width,
            height: page.height,
          );
        }

        if (mounted) {
          setState(() {});
        }

        pageNum++;
      }

      if (pageNum < pages.length) {
        for (var index = pageNum; index < pages.length; index++) {
          pages[index].image.evict();
        }
        pages.removeRange(pageNum, pages.length);
      }
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

      FlutterError.reportError(
        FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'printing',
          context: ErrorDescription('while rastering a PDF'),
          informationCollector: collector,
        ),
      );

      if (mounted) {
        setState(() {
          error = exception;
        });
      }
    }
  }
}

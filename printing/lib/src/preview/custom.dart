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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../callback.dart';
import '../printing.dart';
import 'page.dart';
import 'raster.dart';

/// Custom widget builder that's used for custom
/// rasterized pdf pages rendering
typedef CustomPdfPagesBuilder =
    Widget Function(BuildContext context, List<PdfPreviewPageData> pages);

/// Flutter widget that uses the rasterized pdf pages to display a document.
class PdfPreviewCustom extends StatefulWidget {
  /// Show a pdf document built on demand
  const PdfPreviewCustom({
    super.key,
    this.pageFormat = PdfPageFormat.a4,
    required this.build,
    this.maxPageWidth,
    this.onError,
    this.scrollViewDecoration,
    this.pdfPreviewPageDecoration,
    this.pages,
    this.previewPageMargin,
    this.padding,
    this.shouldRepaint = false,
    this.loadingWidget,
    this.dpi,
    this.scrollPhysics,
    this.shrinkWrap = false,
    this.pagesBuilder,
    this.enableScrollToPage = false,
    this.onZoomChanged,
  });

  /// Pdf paper page format
  final PdfPageFormat pageFormat;

  /// Called when a pdf document is needed
  final LayoutCallback build;

  /// Maximum width of the pdf document on screen
  final double? maxPageWidth;

  /// Widget to display if the PDF document cannot be displayed
  final Widget Function(BuildContext context, Object error)? onError;

  /// Decoration of scrollView
  final Decoration? scrollViewDecoration;

  /// Whether the scrollView should be shrinkwrapped
  final bool shrinkWrap;

  /// The physics for the scrollView - e.g. use this to disable scrolling inside a scrollable
  final ScrollPhysics? scrollPhysics;

  /// Decoration of PdfPreviewPage
  final Decoration? pdfPreviewPageDecoration;

  /// Pages to display. Default will display all the pages.
  final List<int>? pages;

  /// margin for the document preview page
  ///
  /// defaults to [EdgeInsets.only(left: 20, top: 8, right: 20, bottom: 12)],
  final EdgeInsets? previewPageMargin;

  /// padding for the pdf_preview widget
  final EdgeInsets? padding;

  /// Force repainting the PDF document
  final bool shouldRepaint;

  /// Custom loading widget to use that is shown while PDF is being generated.
  /// If null, a [CircularProgressIndicator] is used instead.
  final Widget? loadingWidget;

  /// The rendering dots per inch resolution
  /// If not provided, this value is calculated.
  final double? dpi;

  /// clients can pass this builder to render
  /// their own pages.
  final CustomPdfPagesBuilder? pagesBuilder;

  /// Whether scroll to page functionality enabled.
  final bool enableScrollToPage;

  /// The zoom mode has changed
  final ValueChanged<bool>? onZoomChanged;

  @override
  PdfPreviewCustomState createState() => PdfPreviewCustomState();
}

class PdfPreviewCustomState extends State<PdfPreviewCustom>
    with PdfPreviewRaster {
  final listView = GlobalKey();

  List<GlobalKey> _pageGlobalKeys = <GlobalKey>[];

  bool infoLoaded = false;

  int? preview;

  double? updatePosition;

  final scrollController = ScrollController();

  final transformationController = TransformationController();

  Timer? previewUpdate;

  MouseCursor _mouseCursor = MouseCursor.defer;

  static const _errorMessage = 'Unable to display the document';

  @override
  double? get forcedDpi => widget.dpi;

  @override
  void dispose() {
    transformationController.dispose();
    previewUpdate?.cancel();
    super.dispose();
  }

  @override
  void reassemble() {
    raster();
    super.reassemble();
  }

  @override
  void didUpdateWidget(covariant PdfPreviewCustom oldWidget) {
    if (oldWidget.enableScrollToPage != widget.enableScrollToPage) {
      _syncPageGlobalKeys();
    }

    if (oldWidget.build != widget.build ||
        widget.shouldRepaint ||
        widget.pageFormat != oldWidget.pageFormat) {
      preview = null;
      updatePosition = null;
      raster();
      _zoomChanged();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeDependencies() {
    if (!infoLoaded) {
      infoLoaded = true;
      unawaited(_loadPrintingInfo());
    }

    // Gated on the dpi: the state depends on MediaQuery only because the dpi is
    // computed from it, but MediaQueryData equality also covers viewInsets,
    // padding, platformBrightness, textScaler and the accessibility flags. So
    // opening the keyboard or toggling dark mode used to re-run the app's whole
    // document build and a full raster pass for an identical result.
    if (needsRasterForDpi) {
      raster();
    }
    super.didChangeDependencies();
  }

  /// Read the platform capabilities before the first raster pass.
  ///
  /// A failure here must be shown: on the web a pdf.js that cannot be loaded
  /// makes this throw, and without an error the preview would sit on its
  /// loading indicator forever.
  Future<void> _loadPrintingInfo() async {
    try {
      final printingInfo = await Printing.info();
      if (!mounted) {
        return;
      }
      setState(() {
        info = printingInfo;
        raster();
      });
    } catch (exception, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'printing',
          context: ErrorDescription('while reading the printing capabilities'),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        error = exception;
      });
    }
  }

  @override
  void onPagesChanged() {
    _syncPageGlobalKeys();
    _clampPreview();
    super.onPagesChanged();
  }

  /// Keep exactly one key per page, the same object for that page's lifetime.
  ///
  /// These used to be reallocated inside build. Fresh keys make
  /// `Widget.canUpdate` false for every page child, so each rebuild
  /// deactivated and re-inflated every page - and with a setState per
  /// rasterized page, streaming a document cost O(N^2) - while a key handed out
  /// by [getPageKey] was dead one frame later.
  void _syncPageGlobalKeys() {
    if (!widget.enableScrollToPage) {
      if (_pageGlobalKeys.isNotEmpty) {
        _pageGlobalKeys = <GlobalKey>[];
      }
      return;
    }

    if (_pageGlobalKeys.length > pages.length) {
      // Shrunk: the keys for the pages that remain are untouched.
      _pageGlobalKeys = _pageGlobalKeys.sublist(0, pages.length);
      return;
    }

    while (_pageGlobalKeys.length < pages.length) {
      _pageGlobalKeys.add(GlobalKey());
    }
  }

  /// Reconcile the zoomed page with a page list that may have shrunk.
  ///
  /// `preview` used to index `pages` unguarded, and only didUpdateWidget reset
  /// it - while rasters also start from didChangeDependencies, reassemble and
  /// the debug switch. So zooming a page and then resizing threw a RangeError
  /// out of build: a red error widget, and a preview the user could not
  /// recover.
  void _clampPreview() {
    final zoomed = preview;
    if (zoomed == null || zoomed < pages.length) {
      return;
    }

    if (pages.isEmpty) {
      preview = null;
      updatePosition = null;
      // The zoom state really changed, so the callback is owed exactly one
      // call.
      _zoomChanged();
      return;
    }

    // Stay zoomed, on the last page there is.
    preview = pages.length - 1;
  }

  /// The number of rasterized pages.
  ///
  /// [scrollToPage] and [getPageKey] are meaningful only for an index below
  /// this, which is zero until the first raster has delivered a page.
  int get pageCount => pages.length;

  /// Ensures that page with [index] is become visible.
  Future<void> scrollToPage(
    int index, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.ease,
    ScrollPositionAlignmentPolicy alignmentPolicy =
        ScrollPositionAlignmentPolicy.explicit,
  }) {
    assert(index >= 0, 'Index of page cannot be negative');
    assert(
      widget.enableScrollToPage,
      'scrollToPage needs PdfPreview(enableScrollToPage: true)',
    );
    assert(
      index < _pageGlobalKeys.length,
      'Page $index is out of range: the preview has ${_pageGlobalKeys.length} '
      'page(s). scrollToPage is meaningful only once a page has been '
      'rasterized.',
    );

    if (index >= _pageGlobalKeys.length) {
      // Nothing to scroll to: no page has been rasterized yet, or the document
      // shrank. This used to throw a RangeError out of a public method.
      return Future<void>.value();
    }

    final pageContext = _pageGlobalKeys[index].currentContext;
    if (pageContext == null) {
      // The page exists but is not on screen: the preview is zoomed, or the
      // list has not laid that page out.
      return Future<void>.value();
    }

    return Scrollable.ensureVisible(
      pageContext,
      duration: duration,
      curve: curve,
      alignmentPolicy: alignmentPolicy,
    );
  }

  /// Returns the global key for page with [index].
  ///
  /// The same object for as long as that page exists, so it can be held across
  /// frames. Meaningful only for an index below [pageCount], and only with
  /// `enableScrollToPage: true`.
  Key getPageKey(int index) {
    assert(index >= 0, 'Index of page cannot be negative');
    assert(
      index < _pageGlobalKeys.length,
      'Page $index is out of range: the preview has ${_pageGlobalKeys.length} '
      'page(s).',
    );

    return _pageGlobalKeys[index];
  }

  Widget _showError(Object error) {
    if (widget.onError != null) {
      return widget.onError!(context, error);
    }

    return ErrorWidget(error);
  }

  Widget _createPreview() {
    if (error != null) {
      return _showError(error!);
    }

    final printingInfo = info;
    if (printingInfo != null && !printingInfo.canRaster) {
      return _showError(_errorMessage);
    }

    if (pages.isEmpty) {
      return widget.loadingWidget ??
          const Center(child: CircularProgressIndicator());
    }

    if (widget.pagesBuilder != null) {
      return widget.pagesBuilder!(context, pages);
    }

    Widget pageWidget(int index, {Key? key}) => GestureDetector(
      onDoubleTap: () {
        setState(() {
          updatePosition = scrollController.position.pixels;
          preview = index;
          transformationController.value.setIdentity();
          _updateCursor(SystemMouseCursors.grab);
        });
        _zoomChanged();
      },
      child: PdfPreviewPage(
        key: key,
        pageData: pages[index],
        pdfPreviewPageDecoration: widget.pdfPreviewPageDecoration,
        pageMargin: widget.previewPageMargin,
      ),
    );

    return widget.enableScrollToPage
        ? Scrollbar(
            controller: scrollController,
            child: SingleChildScrollView(
              controller: scrollController,
              physics: widget.scrollPhysics,
              padding: widget.padding,
              child: Column(
                children: List.generate(
                  pages.length,
                  (index) => pageWidget(index, key: getPageKey(index)),
                ),
              ),
            ),
          )
        : ListView.builder(
            controller: scrollController,
            shrinkWrap: widget.shrinkWrap,
            physics: widget.scrollPhysics,
            padding: widget.padding,
            itemCount: pages.length,
            itemBuilder: (BuildContext context, int index) => pageWidget(index),
          );
  }

  Widget _zoomPreview(int index) {
    final zoomPreview = GestureDetector(
      onDoubleTap: () {
        setState(() {
          preview = null;
          _updateCursor(MouseCursor.defer);
        });
        _zoomChanged();
      },
      onLongPressCancel: kIsWeb
          ? () => _updateCursor(SystemMouseCursors.grab)
          : null,
      onLongPressDown: kIsWeb
          ? (_) => _updateCursor(SystemMouseCursors.grabbing)
          : null,
      child: InteractiveViewer(
        transformationController: transformationController,
        maxScale: 5,
        onInteractionEnd: kIsWeb
            ? (_) => _updateCursor(SystemMouseCursors.grab)
            : null,
        child: Center(
          child: PdfPreviewPage(
            pageData: pages[index],
            pdfPreviewPageDecoration: widget.pdfPreviewPageDecoration,
            pageMargin: widget.previewPageMargin,
          ),
        ),
      ),
    );
    return MouseRegion(cursor: _mouseCursor, child: zoomPreview);
  }

  void _zoomChanged() => widget.onZoomChanged?.call(preview != null);

  void _updateCursor(MouseCursor mouseCursor) {
    if (mouseCursor != _mouseCursor) {
      setState(() {
        _mouseCursor = mouseCursor;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget page;

    // Guarded, and build never writes to `preview`: onPagesChanged reconciles
    // it, and this is what keeps a stale index from reaching `pages`.
    final zoomed = preview;
    if (zoomed != null && zoomed < pages.length) {
      page = _zoomPreview(zoomed);
    } else {
      page = Container(
        constraints: widget.maxPageWidth != null
            ? BoxConstraints(maxWidth: widget.maxPageWidth!)
            : null,
        child: _createPreview(),
      );

      if (updatePosition != null) {
        Timer.run(() {
          scrollController.jumpTo(updatePosition!);
          updatePosition = null;
        });
      }
    }

    return Container(
      decoration:
          widget.scrollViewDecoration ??
          BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[Colors.grey.shade400, Colors.grey.shade200],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
      width: double.infinity,
      alignment: Alignment.center,
      child: page,
    );
  }
}

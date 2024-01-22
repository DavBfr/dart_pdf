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

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../callback.dart';
import '../printing.dart';
import '../printing_info.dart';
import 'page.dart';
import 'raster.dart';

/// Custom widget builder that's used for custom
/// rasterized pdf pages rendering
typedef CustomPdfPagesBuilder = Widget Function(
    BuildContext context, List<PdfPreviewPageData> pages);

/// Flutter widget that uses the rasterized pdf pages to display a document.
class PdfPreviewCustom extends StatefulWidget {
  /// Show a pdf document built on demand
  const PdfPreviewCustom({
    Key? key,
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
  }) : super(key: key);

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

  final scrollController = ScrollController(
    keepScrollOffset: true,
  );

  final transformationController = TransformationController();

  Timer? previewUpdate;

  static const _errorMessage = 'Unable to display the document';

  @override
  double? get forcedDpi => widget.dpi;

  @override
  void dispose() {
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
    if (oldWidget.build != widget.build ||
        widget.shouldRepaint ||
        widget.pageFormat != oldWidget.pageFormat) {
      preview = null;
      updatePosition = null;
      raster();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeDependencies() {
    if (!infoLoaded) {
      infoLoaded = true;
      Printing.info().then((PrintingInfo printingInfo) {
        if (!mounted) {
          return;
        }
        setState(() {
          info = printingInfo;
          raster();
        });
      });
    }

    raster();
    super.didChangeDependencies();
  }

  /// Ensures that page with [index] is become visible.
  Future<void> scrollToPage(
    int index, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.ease,
    ScrollPositionAlignmentPolicy alignmentPolicy =
        ScrollPositionAlignmentPolicy.explicit,
  }) {
    assert(index >= 0, 'Index of page cannot be negative');
    final pageContext = _pageGlobalKeys[index].currentContext;
    assert(pageContext != null, 'Context of GlobalKey cannot be null');
    return Scrollable.ensureVisible(pageContext!,
        duration: duration, curve: curve, alignmentPolicy: alignmentPolicy);
  }

  /// Returns the global key for page with [index].
  Key getPageKey(int index) => _pageGlobalKeys[index];

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
          const Center(
            child: CircularProgressIndicator(),
          );
    }

    if (widget.enableScrollToPage) {
      _pageGlobalKeys = List.generate(pages.length, (_) => GlobalKey());
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
            });
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

  Widget _zoomPreview() {
    return GestureDetector(
      onDoubleTap: () {
        setState(() {
          preview = null;
        });
      },
      child: InteractiveViewer(
        transformationController: transformationController,
        maxScale: 5,
        child: Center(
          child: PdfPreviewPage(
            pageData: pages[preview!],
            pdfPreviewPageDecoration: widget.pdfPreviewPageDecoration,
            pageMargin: widget.previewPageMargin,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget page;

    if (preview != null) {
      page = _zoomPreview();
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
      decoration: widget.scrollViewDecoration ??
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

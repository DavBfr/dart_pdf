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
import 'raster.dart';

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

  @override
  PdfPreviewCustomState createState() => PdfPreviewCustomState();
}

class PdfPreviewCustomState extends State<PdfPreviewCustom>
    with PdfPreviewRaster {
  final listView = GlobalKey();

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
      Printing.info().then((PrintingInfo _info) {
        setState(() {
          info = _info;
          raster();
        });
      });
    }

    raster();
    super.didChangeDependencies();
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

    final _info = info;
    if (_info != null && !_info.canRaster) {
      return _showError(_errorMessage);
    }

    if (pages.isEmpty) {
      return widget.loadingWidget ??
          const Center(
            child: CircularProgressIndicator(),
          );
    }

    return ListView.builder(
      controller: scrollController,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.scrollPhysics,
      padding: widget.padding,
      itemCount: pages.length,
      itemBuilder: (BuildContext context, int index) => GestureDetector(
        onDoubleTap: () {
          setState(() {
            updatePosition = scrollController.position.pixels;
            preview = index;
            transformationController.value.setIdentity();
          });
        },
        child: pages[index],
      ),
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
        child: Center(child: pages[preview!]),
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

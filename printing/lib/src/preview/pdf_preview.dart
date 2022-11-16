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
import 'package:pdf/widgets.dart' as pw;

import '../callback.dart';
import '../printing.dart';
import '../printing_info.dart';
import 'actions.dart';
import 'controller.dart';
import 'custom.dart';

export 'custom.dart';

/// Flutter widget that uses the rasterized pdf pages to display a document.
class PdfPreview extends StatefulWidget {
  /// Show a pdf document built on demand
  const PdfPreview({
    Key? key,
    required this.build,
    this.initialPageFormat,
    this.allowPrinting = true,
    this.allowSharing = true,
    this.maxPageWidth,
    this.canChangePageFormat = true,
    this.canChangeOrientation = true,
    this.canDebug = true,
    this.actions,
    this.pageFormats = _defaultPageFormats,
    this.onError,
    this.onPrinted,
    this.onPrintError,
    this.onShared,
    this.scrollViewDecoration,
    this.pdfPreviewPageDecoration,
    this.pdfFileName,
    this.useActions = true,
    this.pages,
    this.dynamicLayout = true,
    this.shareActionExtraBody,
    this.shareActionExtraSubject,
    this.shareActionExtraEmails,
    this.previewPageMargin,
    this.padding,
    this.shouldRepaint = false,
    this.loadingWidget,
    this.onPageFormatChanged,
    this.dpi,
  })  : _pagesBuilder = null,
        super(key: key);

  const PdfPreview.builder({
    Key? key,
    required this.build,
    this.initialPageFormat,
    this.allowPrinting = true,
    this.allowSharing = true,
    this.maxPageWidth,
    this.canChangePageFormat = true,
    this.canChangeOrientation = true,
    this.canDebug = true,
    this.actions,
    this.pageFormats = _defaultPageFormats,
    this.onError,
    this.onPrinted,
    this.onPrintError,
    this.onShared,
    this.scrollViewDecoration,
    this.pdfPreviewPageDecoration,
    this.pdfFileName,
    this.useActions = true,
    this.pages,
    this.dynamicLayout = true,
    this.shareActionExtraBody,
    this.shareActionExtraSubject,
    this.shareActionExtraEmails,
    this.previewPageMargin,
    this.padding,
    this.shouldRepaint = false,
    this.loadingWidget,
    this.onPageFormatChanged,
    this.dpi,
    required CustomPdfPagesBuilder pagesBuilder,
  })  : _pagesBuilder = pagesBuilder,
        super(key: key);

  static const _defaultPageFormats = <String, PdfPageFormat>{
    'A4': PdfPageFormat.a4,
    'Letter': PdfPageFormat.letter,
  };

  /// Called when a pdf document is needed
  final LayoutCallback build;

  /// Pdf page format asked for the first display
  final PdfPageFormat? initialPageFormat;

  /// Add a button to print the pdf document
  final bool allowPrinting;

  /// Add a button to share the pdf document
  final bool allowSharing;

  /// Allow disable actions
  final bool useActions;

  /// Maximum width of the pdf document on screen
  final double? maxPageWidth;

  /// Add a drop-down menu to choose the page format
  final bool canChangePageFormat;

  /// Add a switch to change the page orientation
  final bool canChangeOrientation;

  /// Add a switch to show debug view
  final bool canDebug;

  /// Additional actions to add to the widget
  final List<Widget>? actions;

  /// List of page formats the user can choose
  final Map<String, PdfPageFormat> pageFormats;

  /// Widget to display if the PDF document cannot be displayed
  final Widget Function(BuildContext context, Object error)? onError;

  /// Called if the user prints the pdf document
  final void Function(BuildContext context)? onPrinted;

  /// Called if an error creating the Pdf occurred
  final void Function(BuildContext context, dynamic error)? onPrintError;

  /// Called if the user shares the pdf document
  final void Function(BuildContext context)? onShared;

  /// Decoration of scrollView
  final Decoration? scrollViewDecoration;

  /// Decoration of PdfPreviewPage
  final Decoration? pdfPreviewPageDecoration;

  /// Name of the PDF when sharing. It must include the extension.
  final String? pdfFileName;

  /// Pages to display. Default will display all the pages.
  final List<int>? pages;

  /// Request page re-layout to match the printer paper and margins.
  /// Mitigate an issue with iOS and macOS print dialog that prevent any
  /// channel message while opened.
  final bool dynamicLayout;

  /// email subject when email application is selected from the share dialog
  final String? shareActionExtraSubject;

  /// extra text to share with Pdf document
  final String? shareActionExtraBody;

  /// list of email addresses which will be filled automatically if the email application
  /// is selected from the share dialog.
  /// This will work only for Android platform.
  final List<String>? shareActionExtraEmails;

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

  /// The page format has changed
  final ValueChanged<PdfPageFormat>? onPageFormatChanged;

  /// The rendering dots per inch resolution
  /// If not provided, this value is calculated.
  final double? dpi;

  /// clients can pass this builder to render
  /// their own pages.
  final CustomPdfPagesBuilder? _pagesBuilder;

  @override
  _PdfPreviewState createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<PdfPreview> {
  final previewWidget = GlobalKey<PdfPreviewCustomState>();
  late PdfPreviewData previewData;

  /// Printing subsystem information
  PrintingInfo? info;

  var infoLoaded = false;

  PdfPageFormat computeActualPageFormat() {
    var format = previewData.pageFormat;
    final pages = previewWidget.currentState?.pages ?? const [];
    final dpi = previewWidget.currentState?.dpi ?? PdfPageFormat.inch;

    if (!widget.canChangePageFormat && pages.isNotEmpty) {
      format = PdfPageFormat(
        pages.first.width * PdfPageFormat.inch / dpi,
        pages.first.height * PdfPageFormat.inch / dpi,
        marginAll: 5 * PdfPageFormat.mm,
      );
    }

    return format;
  }

  @override
  void initState() {
    previewData = PdfPreviewData(
      buildDocument: widget.build,
      pageFormats: widget.pageFormats.isNotEmpty
          ? widget.pageFormats
          : PdfPreview._defaultPageFormats,
      initialPageFormat: widget.initialPageFormat,
      onComputeActualPageFormat: computeActualPageFormat,
    );

    previewData.addListener(() {
      if (mounted) {
        setState(() {});
      }
      widget.onPageFormatChanged?.call(previewData.pageFormat);
    });

    super.initState();
  }

  @override
  void dispose() {
    previewData.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PdfPreview oldWidget) {
    if (oldWidget.build != widget.build ||
        widget.shouldRepaint ||
        widget.pageFormats != oldWidget.pageFormats) {
      previewData = PdfPreviewData(
        buildDocument: widget.build,
        pageFormats: widget.pageFormats.isNotEmpty
            ? widget.pageFormats
            : PdfPreview._defaultPageFormats,
        initialPageFormat: previewData.pageFormat,
        onComputeActualPageFormat: computeActualPageFormat,
      );
      setState(() {});
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
        });
      });
    }

    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.primaryIconTheme.color ?? Colors.white;

    final actions = <Widget>[];

    if (widget.useActions && widget.allowPrinting && info?.canPrint == true) {
      actions.add(PdfPrintAction(
        jobName: widget.pdfFileName,
        dynamicLayout: widget.dynamicLayout,
        onPrinted:
            widget.onPrinted == null ? null : () => widget.onPrinted!(context),
        onPrintError: widget.onPrintError == null
            ? null
            : (dynamic error) => widget.onPrintError!(context, error),
      ));
    }

    if (widget.useActions && widget.allowSharing && info?.canShare == true) {
      actions.add(PdfShareAction(
        filename: widget.pdfFileName,
        onShared:
            widget.onPrinted == null ? null : () => widget.onPrinted!(context),
      ));
    }

    if (widget.useActions && widget.canChangePageFormat) {
      actions.add(PdfPageFormatAction(
        pageFormats: widget.pageFormats,
      ));

      if (widget.useActions && widget.canChangeOrientation) {
        // ignore: prefer_const_constructors
        actions.add(PdfPageOrientationAction());
      }
    }

    widget.actions?.forEach(actions.add);

    assert(() {
      if (actions.isNotEmpty && widget.canDebug) {
        actions.add(
          Switch(
            activeColor: Colors.red,
            value: pw.Document.debug,
            onChanged: (bool value) {
              setState(() {
                pw.Document.debug = value;
              });
              previewWidget.currentState?.raster();
            },
          ),
        );
      }

      return true;
    }());

    return PdfPreviewController(
      data: previewData,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Builder(builder: (context) {
              final controller = PdfPreviewController.listen(context);
              return PdfPreviewCustom(
                key: previewWidget,
                build: controller.buildDocument,
                loadingWidget: widget.loadingWidget,
                maxPageWidth: widget.maxPageWidth,
                onError: widget.onError,
                padding: widget.padding,
                pageFormat: controller.pageFormat,
                pages: widget.pages,
                pdfPreviewPageDecoration: widget.pdfPreviewPageDecoration,
                previewPageMargin: widget.previewPageMargin,
                scrollViewDecoration: widget.scrollViewDecoration,
                shouldRepaint: widget.shouldRepaint,
                pagesBuilder: widget._pagesBuilder,
                dpi: widget.dpi,
              );
            }),
          ),
          if (actions.isNotEmpty)
            IconTheme.merge(
              data: IconThemeData(
                color: iconColor,
              ),
              child: Material(
                elevation: 4,
                color: theme.primaryColor,
                child: SizedBox(
                  width: double.infinity,
                  child: SafeArea(
                    child: Wrap(
                      alignment: WrapAlignment.spaceAround,
                      children: actions,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../callback.dart';
import '../printing.dart';
import '../printing_info.dart';
import 'pdf_preview_action.dart';
import 'pdf_preview_raster.dart';

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
  }) : super(key: key);

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

  /// Additionnal actions to add to the widget
  final List<PdfPreviewAction>? actions;

  /// List of page formats the user can choose
  final Map<String, PdfPageFormat> pageFormats;

  /// Widget to display if the PDF document cannot be displayed
  final Widget Function(BuildContext context, Object error)? onError;

  /// Called if the user prints the pdf document
  final void Function(BuildContext context)? onPrinted;

  /// Called if an error creating the Pdf occured
  final void Function(BuildContext context, dynamic error)? onPrintError;

  /// Called if the user shares the pdf document
  final void Function(BuildContext context)? onShared;

  /// Decoration of scrollView
  final Decoration? scrollViewDecoration;

  /// Decoration of _PdfPreviewPage
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

  @override
  _PdfPreviewState createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<PdfPreview> with PdfPreviewRaster {
  final GlobalKey<State<StatefulWidget>> shareWidget = GlobalKey();
  final GlobalKey<State<StatefulWidget>> listView = GlobalKey();

  PdfPageFormat? _pageFormat;

  String get localPageFormat {
    final locale = WidgetsBinding.instance!.window.locale;
    // ignore: unnecessary_cast
    final cc = (locale as Locale?)?.countryCode ?? 'US';

    if (cc == 'US' || cc == 'CA' || cc == 'MX') {
      return 'Letter';
    }
    return 'A4';
  }

  @override
  PdfPageFormat get pageFormat {
    _pageFormat ??= widget.initialPageFormat == null
        ? widget.pageFormats[localPageFormat]
        : _pageFormat = widget.initialPageFormat!;

    if (!widget.pageFormats.containsValue(_pageFormat)) {
      _pageFormat = widget.initialPageFormat ??
          (widget.pageFormats.isNotEmpty
              ? widget.pageFormats.values.first
              : PdfPreview._defaultPageFormats[localPageFormat]);
    }

    return _pageFormat!;
  }

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
  void initState() {
    if (widget.initialPageFormat == null) {
      final locale = WidgetsBinding.instance!.window.locale;
      // ignore: unnecessary_cast
      final cc = (locale as Locale?)?.countryCode ?? 'US';

      if (cc == 'US' || cc == 'CA' || cc == 'MX') {
        _pageFormat = PdfPageFormat.letter;
      } else {
        _pageFormat = PdfPageFormat.a4;
      }
    } else {
      _pageFormat = widget.initialPageFormat!;
    }

    final _pageFormats = widget.pageFormats;
    if (!_pageFormats.containsValue(pageFormat)) {
      _pageFormat = _pageFormats.values.first;
    }

    super.initState();
  }

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
  void didUpdateWidget(covariant PdfPreview oldWidget) {
    if (oldWidget.build != widget.build ||
        widget.shouldRepaint ||
        widget.pageFormats != oldWidget.pageFormats) {
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
    final theme = Theme.of(context);
    final iconColor = theme.primaryIconTheme.color ?? Colors.white;

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

    final Widget scrollView = Container(
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

    final actions = <Widget>[];

    if (widget.allowPrinting && info?.canPrint == true) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.print),
          onPressed: _print,
        ),
      );
    }

    if (widget.allowSharing && info?.canShare == true) {
      actions.add(
        IconButton(
          key: shareWidget,
          icon: const Icon(Icons.share),
          onPressed: _share,
        ),
      );
    }

    if (widget.canChangePageFormat) {
      final keys = widget.pageFormats.keys.toList();
      actions.add(
        DropdownButton<PdfPageFormat>(
          dropdownColor: theme.primaryColor,
          icon: Icon(
            Icons.arrow_drop_down,
            color: iconColor,
          ),
          value: pageFormat,
          items: List<DropdownMenuItem<PdfPageFormat>>.generate(
            widget.pageFormats.length,
            (int index) {
              final key = keys[index];
              final val = widget.pageFormats[key];
              return DropdownMenuItem<PdfPageFormat>(
                value: val,
                child: Text(key, style: TextStyle(color: iconColor)),
              );
            },
          ),
          onChanged: (PdfPageFormat? pageFormat) {
            setState(() {
              if (pageFormat != null) {
                _pageFormat = pageFormat;
                raster();
              }
            });
          },
        ),
      );

      if (widget.canChangeOrientation) {
        horizontal ??= pageFormat.width > pageFormat.height;

        final disabledColor = iconColor.withAlpha(120);
        actions.add(
          ToggleButtons(
            renderBorder: false,
            borderColor: disabledColor,
            color: disabledColor,
            selectedBorderColor: iconColor,
            selectedColor: iconColor,
            onPressed: (int index) {
              setState(() {
                horizontal = index == 1;
                raster();
              });
            },
            isSelected: <bool>[horizontal == false, horizontal == true],
            children: <Widget>[
              Transform.rotate(
                  angle: -pi / 2, child: const Icon(Icons.note_outlined)),
              const Icon(Icons.note_outlined),
            ],
          ),
        );
      }
    }

    if (widget.actions != null) {
      for (final action in widget.actions!) {
        actions.add(
          IconButton(
            icon: action.icon,
            onPressed: action.onPressed == null
                ? null
                : () => action.onPressed!(
                      context,
                      widget.build,
                      computedPageFormat,
                    ),
          ),
        );
      }
    }

    assert(() {
      if (actions.isNotEmpty && widget.canDebug) {
        actions.add(
          Switch(
            activeColor: Colors.red,
            value: pw.Document.debug,
            onChanged: (bool value) {
              setState(
                () {
                  pw.Document.debug = value;
                  raster();
                },
              );
            },
          ),
        );
      }

      return true;
    }());

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Expanded(child: scrollView),
        if (actions.isNotEmpty && widget.useActions)
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
          )
      ],
    );
  }

  Future<void> _print() async {
    var format = computedPageFormat;

    if (!widget.canChangePageFormat && pages.isNotEmpty) {
      format = PdfPageFormat(
        pages.first.page!.width * 72 / dpi,
        pages.first.page!.height * 72 / dpi,
        marginAll: 5 * PdfPageFormat.mm,
      );
    }

    try {
      final result = await Printing.layoutPdf(
        onLayout: widget.build,
        name: widget.pdfFileName ?? 'Document',
        format: format,
        dynamicLayout: widget.dynamicLayout,
      );

      if (result && widget.onPrinted != null) {
        widget.onPrinted!(context);
      }
    } catch (exception, stack) {
      InformationCollector? collector;

      assert(() {
        collector = () sync* {
          yield StringProperty('PageFormat', computedPageFormat.toString());
        };
        return true;
      }());

      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'printing',
        context: ErrorDescription('while printing a PDF'),
        informationCollector: collector,
      ));

      if (widget.onPrintError != null) {
        widget.onPrintError!(context, exception);
      }
    }
  }

  Future<void> _share() async {
    // Calculate the widget center for iPad sharing popup position
    final referenceBox =
        shareWidget.currentContext!.findRenderObject() as RenderBox;
    final topLeft =
        referenceBox.localToGlobal(referenceBox.paintBounds.topLeft);
    final bottomRight =
        referenceBox.localToGlobal(referenceBox.paintBounds.bottomRight);
    final bounds = Rect.fromPoints(topLeft, bottomRight);

    final bytes = await widget.build(computedPageFormat);
    final result = await Printing.sharePdf(
      bytes: bytes,
      bounds: bounds,
      filename: widget.pdfFileName ?? 'document.pdf',
      body: widget.shareActionExtraBody,
      subject: widget.shareActionExtraSubject,
      emails: widget.shareActionExtraEmails,
    );

    if (result && widget.onShared != null) {
      widget.onShared!(context);
    }
  }
}

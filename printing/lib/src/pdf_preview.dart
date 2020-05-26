import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'callback.dart';
import 'printing.dart';
import 'printing_info.dart';
import 'raster.dart';

/// Flutter widget that uses the rasterized pdf pages to display a document.
class PdfPreview extends StatefulWidget {
  /// Show a pdf document built on demand
  const PdfPreview(
      {Key key,
      @required this.build,
      this.initialPageFormat,
      this.allowPrinting = true,
      this.allowSharing = true,
      this.maxPageWidth,
      this.canChangePageFormat = true,
      this.actions,
      this.pageFormats,
      this.onError,
      this.onPrinted,
      this.onShared,
      this.scrollViewDecoration,
      this.pdfPreviewPageDecoration})
      : super(key: key);

  /// Called when a pdf document is needed
  final LayoutCallback build;

  /// Pdf page format asked for the first display
  final PdfPageFormat initialPageFormat;

  /// Add a button to print the pdf document
  final bool allowPrinting;

  /// Add a button to share the pdf document
  final bool allowSharing;

  /// Maximum width of the pdf document on screen
  final double maxPageWidth;

  /// Add a drop-down menu to choose the page format
  final bool canChangePageFormat;

  /// Additionnal actions to add to the widget
  final List<PdfPreviewAction> actions;

  /// List of page formats the user can choose
  final Map<String, PdfPageFormat> pageFormats;

  /// Called if an error creating the Pdf occured
  final Widget Function(BuildContext context) onError;

  /// Called if the user prints the pdf document
  final void Function(BuildContext context) onPrinted;

  /// Called if the user shares the pdf document
  final void Function(BuildContext context) onShared;

  /// Decoration of scrollView
  final Decoration scrollViewDecoration;

  /// Decoration of _PdfPreviewPage
  final Decoration pdfPreviewPageDecoration;

  @override
  _PdfPreviewState createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<PdfPreview> {
  final GlobalKey<State<StatefulWidget>> shareWidget = GlobalKey();
  final GlobalKey<State<StatefulWidget>> listView = GlobalKey();

  final List<_PdfPreviewPage> pages = <_PdfPreviewPage>[];

  PdfPageFormat pageFormat;

  PrintingInfo info = PrintingInfo.unavailable;
  bool infoLoaded = false;

  double dpi = 10;

  Object error;

  static const Map<String, PdfPageFormat> defaultPageFormats =
      <String, PdfPageFormat>{
    'A4': PdfPageFormat.a4,
    'Letter': PdfPageFormat.letter,
  };

  Future<void> _raster() async {
    Uint8List _doc;

    if (!info.canRaster) {
      return;
    }

    try {
      _doc = await widget.build(pageFormat);
    } catch (e) {
      error = e;
      return;
    }

    if (error != null) {
      setState(() {
        error = null;
      });
    }

    var pageNum = 0;
    await for (final PdfRaster page in Printing.raster(_doc, dpi: dpi)) {
      setState(() {
        if (pages.length <= pageNum) {
          pages.add(_PdfPreviewPage(
            page: page,
            pdfPreviewPageDecoration: widget.pdfPreviewPageDecoration,
          ));
        } else {
          pages[pageNum] = _PdfPreviewPage(
            page: page,
            pdfPreviewPageDecoration: widget.pdfPreviewPageDecoration,
          );
        }
      });

      pageNum++;
    }

    pages.removeRange(pageNum, pages.length);
  }

  @override
  void initState() {
    final locale =
        WidgetsBinding.instance.window.locale ?? const Locale('en', 'US');
    final cc = locale.countryCode;
    if (cc == 'US' || cc == 'CA' || cc == 'MX') {
      pageFormat = widget.initialPageFormat ?? PdfPageFormat.letter;
    } else {
      pageFormat = widget.initialPageFormat ?? PdfPageFormat.a4;
    }

    super.initState();
  }

  @override
  void reassemble() {
    _raster();
    super.reassemble();
  }

  @override
  void didUpdateWidget(covariant PdfPreview oldWidget) {
    if (oldWidget.build != widget.build) {
      pages.clear();
      _raster();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeDependencies() {
    if (!infoLoaded) {
      Printing.info().then((PrintingInfo _info) {
        setState(() {
          infoLoaded = true;
          info = _info;
          _raster();
        });
      });
    }

    final mq = MediaQuery.of(context);
    dpi = (min(mq.size.width - 16, widget.maxPageWidth ?? double.infinity)) *
        mq.devicePixelRatio /
        pageFormat.width *
        72;

    _raster();
    super.didChangeDependencies();
  }

  Widget _showError() {
    if (widget.onError != null) {
      return widget.onError(context);
    }

    return const Center(
      child: Text(
        'Unable to display the document',
        style: TextStyle(
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _createPreview() {
    if (error != null) {
      var content = _showError();
      assert(() {
        print(error);
        content = ErrorWidget(error);
        return true;
      }());
      return content;
    }

    if (!info.canRaster) {
      return _showError();
    }

    if (pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scrollbar(
      child: ListView.builder(
        itemCount: pages.length,
        itemBuilder: (BuildContext context, int index) => pages[index],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
      child: Container(
        constraints: widget.maxPageWidth != null
            ? BoxConstraints(maxWidth: widget.maxPageWidth)
            : null,
        child: _createPreview(),
      ),
    );

    final actions = <Widget>[];

    if (widget.allowPrinting && info.canPrint) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.print),
          color: theme.accentIconTheme.color,
          onPressed: _print,
        ),
      );
    }

    if (widget.allowSharing && info.canShare) {
      actions.add(
        IconButton(
          key: shareWidget,
          icon: const Icon(Icons.share),
          color: theme.accentIconTheme.color,
          onPressed: _share,
        ),
      );
    }

    if (widget.canChangePageFormat) {
      final _pageFormats = widget.pageFormats ?? defaultPageFormats;
      final keys = _pageFormats.keys.toList();
      actions.add(
        DropdownButton<PdfPageFormat>(
          icon: Icon(
            Icons.arrow_drop_down,
            color: theme.accentIconTheme.color,
          ),
          value: pageFormat,
          items: List<DropdownMenuItem<PdfPageFormat>>.generate(
            _pageFormats.length,
            (int index) {
              final key = keys[index];
              final val = _pageFormats[key];
              return DropdownMenuItem<PdfPageFormat>(
                child: Text(key),
                value: val,
              );
            },
          ),
          onChanged: (PdfPageFormat _pageFormat) {
            setState(() {
              pageFormat = _pageFormat;
              _raster();
            });
          },
        ),
      );
    }

    if (widget.actions != null) {
      for (final action in widget.actions) {
        actions.add(
          IconButton(
            icon: action.icon,
            color: theme.accentIconTheme.color,
            onPressed: action.onPressed == null
                ? null
                : () => action.onPressed(
                      context,
                      widget.build,
                      pageFormat,
                    ),
          ),
        );
      }
    }

    assert(() {
      if (actions.isNotEmpty) {
        actions.add(
          Switch(
            activeColor: Colors.red,
            value: pw.Document.debug,
            onChanged: (bool value) {
              setState(
                () {
                  pw.Document.debug = value;
                  _raster();
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
        if (actions.isNotEmpty)
          Material(
            elevation: 4,
            color: theme.primaryColor,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: actions,
              ),
            ),
          )
      ],
    );
  }

  Future<void> _print() async {
    final result = await Printing.layoutPdf(onLayout: widget.build);

    if (result && widget.onPrinted != null) {
      widget.onPrinted(context);
    }
  }

  Future<void> _share() async {
    // Calculate the widget center for iPad sharing popup position
    final RenderBox referenceBox =
        shareWidget.currentContext.findRenderObject();
    final topLeft =
        referenceBox.localToGlobal(referenceBox.paintBounds.topLeft);
    final bottomRight =
        referenceBox.localToGlobal(referenceBox.paintBounds.bottomRight);
    final bounds = Rect.fromPoints(topLeft, bottomRight);

    final bytes = await widget.build(pageFormat);
    final result = await Printing.sharePdf(bytes: bytes, bounds: bounds);

    if (result && widget.onShared != null) {
      widget.onShared(context);
    }
  }
}

class _PdfPreviewPage extends StatelessWidget {
  const _PdfPreviewPage({
    Key key,
    this.page,
    this.pdfPreviewPageDecoration,
  }) : super(key: key);

  final PdfRaster page;
  final Decoration pdfPreviewPageDecoration;

  @override
  Widget build(BuildContext context) {
    final im = PdfRasterImage(page);

    return Container(
      margin: const EdgeInsets.only(
        left: 8,
        top: 8,
        right: 8,
        bottom: 12,
      ),
      decoration: pdfPreviewPageDecoration ??
          const BoxDecoration(
            color: Colors.white,
            boxShadow: <BoxShadow>[
              BoxShadow(
                offset: Offset(0, 3),
                blurRadius: 5,
                color: Color(0xFF000000),
              ),
            ],
          ),
      child: AspectRatio(
        aspectRatio: page.width / page.height,
        child: Image(
          image: im,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

typedef OnPdfPreviewActionPressed = void Function(
  BuildContext context,
  LayoutCallback build,
  PdfPageFormat pageFormat,
);

/// Action to add the the [PdfPreview] widget
class PdfPreviewAction {
  /// Represents an icon to add to [PdfPreview]
  const PdfPreviewAction({
    @required this.icon,
    @required this.onPressed,
  }) : assert(icon != null);

  /// The icon to display
  final Icon icon;

  /// The callback called when the user tap on the icon
  final OnPdfPreviewActionPressed onPressed;
}

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

part of widget;

class Document {
  Document(
      {PdfPageMode pageMode = PdfPageMode.none,
      DeflateCallback deflate,
      this.theme,
      String title,
      String author,
      String creator,
      String subject,
      String keywords,
      String producer})
      : document = PdfDocument(pageMode: pageMode, deflate: deflate) {
    document.info = PdfInfo(document,
        title: title,
        author: author,
        creator: creator,
        subject: subject,
        keywords: keywords,
        producer: producer);
  }

  static bool debug = false;

  final PdfDocument document;

  final Theme theme;

  void addPage(Page page) {
    page.generate(this);
  }

  List<int> save() => document.save();
}

typedef BuildCallback = Widget Function(Context context);
typedef BuildListCallback = List<Widget> Function(Context context);

enum PageOrientation { natural, landscape, portrait }

class Page {
  const Page(
      {this.pageFormat = PdfPageFormat.standard,
      BuildCallback build,
      this.theme,
      this.orientation = PageOrientation.natural,
      EdgeInsets margin})
      : assert(pageFormat != null),
        _margin = margin,
        _build = build;

  final PdfPageFormat pageFormat;

  final PageOrientation orientation;

  final EdgeInsets _margin;

  final BuildCallback _build;

  final Theme theme;

  bool get mustRotate =>
      (orientation == PageOrientation.landscape &&
          pageFormat.height > pageFormat.width) ||
      (orientation == PageOrientation.portrait &&
          pageFormat.width > pageFormat.height);

  EdgeInsets get margin {
    if (_margin != null) {
      if (mustRotate) {
        return EdgeInsets.fromLTRB(
            _margin.bottom, _margin.left, _margin.top, _margin.right);
      } else {
        return _margin;
      }
    }

    if (mustRotate) {
      return EdgeInsets.fromLTRB(pageFormat.marginBottom, pageFormat.marginLeft,
          pageFormat.marginTop, pageFormat.marginRight);
    } else {
      return EdgeInsets.fromLTRB(pageFormat.marginLeft, pageFormat.marginTop,
          pageFormat.marginRight, pageFormat.marginBottom);
    }
  }

  @protected
  void debugPaint(Context context) {
    final EdgeInsets _margin = margin;
    context.canvas
      ..setFillColor(PdfColor.lightGreen)
      ..moveTo(0, 0)
      ..lineTo(pageFormat.width, 0)
      ..lineTo(pageFormat.width, pageFormat.height)
      ..lineTo(0, pageFormat.height)
      ..moveTo(_margin.left, _margin.bottom)
      ..lineTo(_margin.left, pageFormat.height - _margin.top)
      ..lineTo(
          pageFormat.width - _margin.right, pageFormat.height - _margin.top)
      ..lineTo(pageFormat.width - _margin.right, _margin.bottom)
      ..fillPath();
  }

  @protected
  void generate(Document document) {
    final PdfPage pdfPage = PdfPage(document.document, pageFormat: pageFormat);
    final PdfGraphics canvas = pdfPage.getGraphics();
    final EdgeInsets _margin = margin;
    final BoxConstraints constraints = mustRotate
        ? BoxConstraints(
            maxWidth: pageFormat.height - _margin.vertical,
            maxHeight: pageFormat.width - _margin.horizontal)
        : BoxConstraints(
            maxWidth: pageFormat.width - _margin.horizontal,
            maxHeight: pageFormat.height - _margin.vertical);

    final Theme calculatedTheme = theme ?? document.theme ?? Theme.base();
    final Map<Type, Inherited> inherited = <Type, Inherited>{};
    inherited[calculatedTheme.runtimeType] = calculatedTheme;
    final Context context = Context(
        document: document.document,
        page: pdfPage,
        canvas: canvas,
        inherited: inherited);
    if (_build != null) {
      final Widget child = _build(context);
      layout(child, context, constraints);
      paint(child, context);
    }
  }

  @protected
  void layout(Widget child, Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    if (child != null) {
      final EdgeInsets _margin = margin;
      child.layout(context, constraints, parentUsesSize: parentUsesSize);
      child.box = PdfRect(
          _margin.left,
          pageFormat.height - child.box.height - _margin.top,
          child.box.width,
          child.box.height);
    }
  }

  @protected
  void paint(Widget child, Context context) {
    assert(() {
      if (Document.debug) {
        debugPaint(context);
      }
      return true;
    }());

    if (child == null) {
      return;
    }

    if (mustRotate) {
      final EdgeInsets _margin = margin;
      final Matrix4 mat = Matrix4.identity();
      mat
        ..rotateZ(-math.pi / 2)
        ..translate(-pageFormat.height - _margin.left + _margin.top,
            child.box.height - child.box.width + _margin.left - _margin.bottom);
      context.canvas
        ..saveContext()
        ..setTransform(mat);
      child.paint(context);
      context.canvas.restoreContext();
    } else {
      child.paint(context);
    }
  }
}

class MultiPage extends Page {
  const MultiPage(
      {PdfPageFormat pageFormat = PdfPageFormat.a4,
      BuildListCallback build,
      this.crossAxisAlignment = CrossAxisAlignment.start,
      this.header,
      this.footer,
      Theme theme,
      PageOrientation orientation = PageOrientation.natural,
      EdgeInsets margin})
      : _buildList = build,
        super(
            pageFormat: pageFormat,
            margin: margin,
            theme: theme,
            orientation: orientation);

  final BuildListCallback _buildList;

  final CrossAxisAlignment crossAxisAlignment;

  final BuildCallback header;

  final BuildCallback footer;

  void paintChild(
      Context context, Widget child, double x, double y, double pageHeight) {
    if (mustRotate) {
      final EdgeInsets _margin = margin;
      context.canvas
        ..saveContext()
        ..setTransform(Matrix4.identity()
          ..rotateZ(-math.pi / 2)
          ..translate(x - pageHeight + _margin.top - _margin.left,
              y + _margin.left - _margin.bottom));
      child.paint(context);
      context.canvas.restoreContext();
    } else {
      child.box = PdfRect(x, y, child.box.width, child.box.height);
      child.paint(context);
    }
  }

  @override
  void generate(Document document) {
    if (_buildList == null) {
      return;
    }

    final EdgeInsets _margin = margin;
    final bool _mustRotate = mustRotate;
    final double pageHeight =
        _mustRotate ? pageFormat.width : pageFormat.height;
    final double pageHeightMargin =
        _mustRotate ? _margin.horizontal : _margin.vertical;
    final BoxConstraints constraints = BoxConstraints(
        maxWidth: _mustRotate
            ? (pageFormat.height - _margin.vertical)
            : (pageFormat.width - _margin.horizontal));
    final Theme calculatedTheme = theme ?? document.theme ?? Theme.base();
    final Map<Type, Inherited> inherited = <Type, Inherited>{};
    inherited[calculatedTheme.runtimeType] = calculatedTheme;
    Context context;
    double offsetEnd;
    double offsetStart;
    int index = 0;
    final Context baseContext =
        Context(document: document.document, inherited: inherited);
    final List<Widget> children = _buildList(baseContext);
    WidgetContext widgetContext;

    while (index < children.length) {
      final Widget child = children[index];

      if (context == null) {
        final PdfPage pdfPage =
            PdfPage(document.document, pageFormat: pageFormat);
        final PdfGraphics canvas = pdfPage.getGraphics();
        context = baseContext.copyWith(page: pdfPage, canvas: canvas);
        assert(() {
          if (Document.debug) {
            debugPaint(context);
          }
          return true;
        }());
        offsetStart = pageHeight -
            (_mustRotate ? pageHeightMargin - margin.bottom : _margin.top);
        offsetEnd =
            _mustRotate ? pageHeightMargin - _margin.left : _margin.bottom;
        if (header != null) {
          final Widget headerWidget = header(context);
          if (headerWidget != null) {
            headerWidget.layout(context, constraints, parentUsesSize: false);
            paintChild(context, headerWidget, _margin.left,
                offsetStart - headerWidget.box.height, pageFormat.height);
            offsetStart -= headerWidget.box.height;
          }
        }

        if (footer != null) {
          final Widget footerWidget = footer(context);
          if (footerWidget != null) {
            footerWidget.layout(context, constraints, parentUsesSize: false);
            paintChild(context, footerWidget, _margin.left, _margin.bottom,
                pageFormat.height);
            offsetEnd += footerWidget.box.height;
          }
        }
      }

      if (widgetContext != null && child is SpanningWidget) {
        child.restoreContext(widgetContext);
        widgetContext = null;
      }

      child.layout(context, constraints, parentUsesSize: false);

      if (offsetStart - child.box.height < offsetEnd) {
        if (child.box.height <= pageHeight - pageHeightMargin &&
            !(child is SpanningWidget)) {
          context = null;
          continue;
        }

        if (!(child is SpanningWidget)) {
          throw Exception(
              'Widget won\'t fit into the page as its height (${child.box.height}) '
              'exceed a page height (${pageHeight - pageHeightMargin}). '
              'You probably need a SpanningWidget or use a single page layout');
        }

        final SpanningWidget span = child;

        child.layout(
            context, constraints.copyWith(maxHeight: offsetStart - offsetEnd),
            parentUsesSize: false);
        paintChild(context, child, _margin.left, offsetStart - child.box.height,
            pageFormat.height);

        if (span.canSpan) {
          widgetContext = span.saveContext();
        } else {
          index++;
        }

        context = null;
        continue;
      }

      paintChild(context, child, _margin.left, offsetStart - child.box.height,
          pageFormat.height);
      offsetStart -= child.box.height;
      index++;
    }
  }
}

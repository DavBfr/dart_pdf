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

abstract class BasePage {
  BasePage({@required this.pageFormat}) : assert(pageFormat != null);

  final PdfPageFormat pageFormat;

  @protected
  void generate(Document document);
}

class Document {
  Document(
      {PdfPageMode pageMode = PdfPageMode.none,
      DeflateCallback deflate,
      this.theme})
      : document = PdfDocument(pageMode: pageMode, deflate: deflate);

  static bool debug = false;

  final PdfDocument document;

  final Theme theme;

  void addPage(BasePage page) {
    page.generate(this);
  }
}

typedef BuildCallback = Widget Function(Context context);
typedef BuildListCallback = List<Widget> Function(Context context);

class Page extends BasePage {
  Page(
      {PdfPageFormat pageFormat = PdfPageFormat.a4,
      BuildCallback build,
      this.theme,
      EdgeInsets margin})
      : margin = margin ??
            EdgeInsets.fromLTRB(pageFormat.marginLeft, pageFormat.marginTop,
                pageFormat.marginRight, pageFormat.marginBottom),
        _build = build,
        super(pageFormat: pageFormat);

  final EdgeInsets margin;

  final BuildCallback _build;

  final Theme theme;

  void debugPaint(Context context) {
    context.canvas
      ..setFillColor(PdfColor.lightGreen)
      ..moveTo(0.0, 0.0)
      ..lineTo(pageFormat.width, 0.0)
      ..lineTo(pageFormat.width, pageFormat.height)
      ..lineTo(0.0, pageFormat.height)
      ..moveTo(margin.left, margin.bottom)
      ..lineTo(margin.left, pageFormat.height - margin.top)
      ..lineTo(pageFormat.width - margin.right, pageFormat.height - margin.top)
      ..lineTo(pageFormat.width - margin.right, margin.bottom)
      ..fillPath();
  }

  @override
  void generate(Document document) {
    final PdfPage pdfPage = PdfPage(document.document, pageFormat: pageFormat);
    final PdfGraphics canvas = pdfPage.getGraphics();
    final BoxConstraints constraints = BoxConstraints(
        maxWidth: pageFormat.width, maxHeight: pageFormat.height);

    final Theme calculatedTheme =
        theme ?? document.theme ?? Theme(document.document);
    final Map<Type, Inherited> inherited = <Type, Inherited>{};
    inherited[calculatedTheme.runtimeType] = calculatedTheme;
    final Context context =
        Context(page: pdfPage, canvas: canvas, inherited: inherited);
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
      final BoxConstraints childConstraints = BoxConstraints(
          minWidth: constraints.minWidth,
          minHeight: constraints.minHeight,
          maxWidth: constraints.hasBoundedWidth
              ? constraints.maxWidth - margin.horizontal
              : margin.horizontal,
          maxHeight: constraints.hasBoundedHeight
              ? constraints.maxHeight - margin.vertical
              : margin.vertical);
      child.layout(context, childConstraints, parentUsesSize: parentUsesSize);
      child.box = PdfRect(
          margin.left,
          pageFormat.height - child.box.height - margin.top,
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

    if (child != null) {
      child.paint(context);
    }
  }
}

class MultiPage extends Page {
  MultiPage(
      {PdfPageFormat pageFormat = PdfPageFormat.a4,
      BuildListCallback build,
      this.crossAxisAlignment = CrossAxisAlignment.start,
      this.header,
      this.footer,
      EdgeInsets margin})
      : _buildList = build,
        super(pageFormat: pageFormat, margin: margin);

  final BuildListCallback _buildList;

  final CrossAxisAlignment crossAxisAlignment;

  final BuildCallback header;

  final BuildCallback footer;

  @override
  void generate(Document document) {
    if (_buildList == null) {
      return;
    }

    final BoxConstraints constraints = BoxConstraints(
        maxWidth: pageFormat.width, maxHeight: pageFormat.height);
    final BoxConstraints childConstraints =
        BoxConstraints(maxWidth: constraints.maxWidth - margin.horizontal);
    final Theme calculatedTheme =
        theme ?? document.theme ?? Theme(document.document);
    final Map<Type, Inherited> inherited = <Type, Inherited>{};
    inherited[calculatedTheme.runtimeType] = calculatedTheme;
    Context context;
    double offsetEnd;
    double offsetStart;
    int index = 0;
    final List<Widget> children = _buildList(Context(inherited: inherited));
    WidgetContext widgetContext;

    while (index < children.length) {
      final Widget child = children[index];

      if (context == null) {
        final PdfPage pdfPage =
            PdfPage(document.document, pageFormat: pageFormat);
        final PdfGraphics canvas = pdfPage.getGraphics();
        context = Context(page: pdfPage, canvas: canvas, inherited: inherited);
        assert(() {
          if (Document.debug) {
            debugPaint(context);
          }
          return true;
        }());
        offsetStart = pageFormat.height - margin.top;
        offsetEnd = margin.bottom;
        if (header != null) {
          final Widget headerWidget = header(context);
          if (headerWidget != null) {
            headerWidget.layout(context, childConstraints,
                parentUsesSize: false);
            headerWidget.box = PdfRect(
                margin.left,
                offsetStart - headerWidget.box.height,
                headerWidget.box.width,
                headerWidget.box.height);
            headerWidget.paint(context);
            offsetStart -= headerWidget.box.height;
          }
        }

        if (footer != null) {
          final Widget footerWidget = footer(context);
          if (footerWidget != null) {
            footerWidget.layout(context, childConstraints,
                parentUsesSize: false);
            footerWidget.box = PdfRect(margin.left, margin.bottom,
                footerWidget.box.width, footerWidget.box.height);
            footerWidget.paint(context);
            offsetEnd += footerWidget.box.height;
          }
        }
      }

      if (widgetContext != null && child is SpanningWidget) {
        child.restoreContext(widgetContext);
        widgetContext = null;
      }

      child.layout(context, childConstraints, parentUsesSize: false);

      if (offsetStart - child.box.height < offsetEnd) {
        if (child.box.height < pageFormat.height - margin.vertical) {
          context = null;
          continue;
        }

        if (!(child is SpanningWidget)) {
          throw Exception("Widget won't fit into the page");
        }

        final SpanningWidget span = child;

        child.layout(context,
            childConstraints.copyWith(maxHeight: offsetStart - offsetEnd),
            parentUsesSize: false);
        child.box = PdfRect(margin.left, offsetStart - child.box.height,
            child.box.width, child.box.height);
        child.paint(context);

        if (span.canSpan) {
          widgetContext = span.saveContext();
        } else {
          index++;
        }

        context = null;
        continue;
      }

      child.box = PdfRect(margin.left, offsetStart - child.box.height,
          child.box.width, child.box.height);
      child.paint(context);
      offsetStart -= child.box.height;
      index++;
    }
  }
}

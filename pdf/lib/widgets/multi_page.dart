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

class WidgetContext {}

abstract class SpanningWidget extends Widget {
  bool get canSpan => false;

  @protected
  WidgetContext saveContext();

  @protected
  void restoreContext(WidgetContext context);
}

class NewPage extends Widget {
  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.zero;
  }
}

class _MultiPageInstance {
  const _MultiPageInstance(
      {@required this.context,
      @required this.constraints,
      @required this.offsetStart});

  final Context context;
  final BoxConstraints constraints;
  final double offsetStart;
}

class MultiPage extends Page {
  MultiPage(
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

  final List<_MultiPageInstance> _pages = <_MultiPageInstance>[];

  void _paintChild(
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
    int sameCount = 0;
    final Context baseContext =
        Context(document: document.document, inherited: inherited);
    final List<Widget> children = _buildList(baseContext);
    WidgetContext widgetContext;

    while (index < children.length) {
      final Widget child = children[index];

      assert(() {
        // Detect too big widgets
        if (sameCount++ > 20) {
          throw Exception(
              'This widget created more than 20 pages. This may be an issue in the widget or the document.');
        }
        return true;
      }());

      // Create a new page if we don't already have one
      if (context == null || child is NewPage) {
        final PdfPage pdfPage =
            PdfPage(document.document, pageFormat: pageFormat);
        context =
            baseContext.copyWith(page: pdfPage, canvas: pdfPage.getGraphics());

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

        _pages.add(_MultiPageInstance(
          context: context,
          constraints: constraints,
          offsetStart: offsetStart,
        ));

        if (header != null) {
          final Widget headerWidget = header(context);
          if (headerWidget != null) {
            headerWidget.layout(context, constraints, parentUsesSize: false);
            assert(headerWidget.box != null);
            offsetStart -= headerWidget.box.height;
          }
        }

        if (footer != null) {
          final Widget footerWidget = footer(context);
          if (footerWidget != null) {
            footerWidget.layout(context, constraints, parentUsesSize: false);
            assert(footerWidget.box != null);
            offsetEnd += footerWidget.box.height;
          }
        }
      }

      // If we are processing a multi-page widget, we restore its context
      if (widgetContext != null && child is SpanningWidget) {
        child.restoreContext(widgetContext);
        widgetContext = null;
      }

      child.layout(context, constraints, parentUsesSize: false);
      assert(child.box != null);

      // What to do if the widget is too big for the page?
      if (offsetStart - child.box.height < offsetEnd) {
        // If it is not a multi=page widget and its height
        // is smaller than a full new page, we schedule a new page creation
        if (child.box.height <= pageHeight - pageHeightMargin &&
            !(child is SpanningWidget)) {
          context = null;
          continue;
        }

        // Else we crash if the widget is too big and cannot be splitted
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
        assert(child.box != null);
        _paintChild(context, child, _margin.left,
            offsetStart - child.box.height, pageFormat.height);

        // Has it finished spanning?
        if (span.canSpan) {
          widgetContext = span.saveContext();
        } else {
          sameCount = 0;
          index++;
        }

        // Schedule a new page
        context = null;
        continue;
      }

      _paintChild(context, child, _margin.left, offsetStart - child.box.height,
          pageFormat.height);
      offsetStart -= child.box.height;
      sameCount = 0;
      index++;
    }
  }

  @override
  void postProcess(Document document) {
    final EdgeInsets _margin = margin;

    for (_MultiPageInstance page in _pages) {
      if (header != null) {
        final Widget headerWidget = header(page.context);
        if (headerWidget != null) {
          headerWidget.layout(page.context, page.constraints,
              parentUsesSize: false);
          assert(headerWidget.box != null);
          _paintChild(page.context, headerWidget, _margin.left,
              page.offsetStart - headerWidget.box.height, pageFormat.height);
        }
      }

      if (footer != null) {
        final Widget footerWidget = footer(page.context);
        if (footerWidget != null) {
          footerWidget.layout(page.context, page.constraints,
              parentUsesSize: false);
          assert(footerWidget.box != null);
          _paintChild(page.context, footerWidget, _margin.left, _margin.bottom,
              pageFormat.height);
        }
      }
    }
  }
}

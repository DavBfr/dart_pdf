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

// ignore_for_file: omit_local_variable_types

part of widget;

abstract class WidgetContext {
  WidgetContext clone();

  void apply(WidgetContext other);
}

abstract class SpanningWidget extends Widget {
  bool get canSpan;

  bool get hasMoreWidgets;

  /// Get unmodified mutable context object
  @protected
  WidgetContext saveContext();

  /// Aplpy the context for next layout
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

@immutable
class _MultiPageWidget {
  const _MultiPageWidget({
    @required this.child,
    @required this.x,
    @required this.y,
    @required this.constraints,
    @required this.widgetContext,
  });

  final Widget child;
  final double x;
  final double y;
  final BoxConstraints constraints;
  final WidgetContext widgetContext;
}

@immutable
class _MultiPageInstance {
  _MultiPageInstance({
    @required this.context,
    @required this.constraints,
    @required this.fullConstraints,
    @required this.offsetStart,
  });

  final Context context;
  final BoxConstraints constraints;
  final BoxConstraints fullConstraints;
  final double offsetStart;
  final List<_MultiPageWidget> widgets = <_MultiPageWidget>[];
}

class MultiPage extends Page {
  MultiPage(
      {PageTheme pageTheme,
      PdfPageFormat pageFormat,
      BuildListCallback build,
      this.crossAxisAlignment = CrossAxisAlignment.start,
      this.header,
      this.footer,
      Theme theme,
      this.maxPages = 20,
      PageOrientation orientation,
      EdgeInsets margin})
      : _buildList = build,
        assert(maxPages != null && maxPages > 0),
        super(
            pageTheme: pageTheme,
            pageFormat: pageFormat,
            margin: margin,
            theme: theme,
            orientation: orientation);

  final BuildListCallback _buildList;

  final CrossAxisAlignment crossAxisAlignment;

  final BuildCallback header;

  final BuildCallback footer;

  final List<_MultiPageInstance> _pages = <_MultiPageInstance>[];

  final int maxPages;

  void _paintChild(
      Context context, Widget child, double x, double y, double pageHeight) {
    if (mustRotate) {
      final EdgeInsets _margin = margin;
      context.canvas
        ..saveContext()
        ..setTransform(Matrix4.identity()
          ..rotateZ(-math.pi / 2)
          ..translate(
            x - pageHeight + _margin.top - _margin.left,
            y + _margin.left - _margin.bottom,
          ));

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

    assert(pageFormat.width > 0 && pageFormat.width < double.infinity);
    assert(pageFormat.height > 0 && pageFormat.height < double.infinity);

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
    final BoxConstraints fullConstraints = mustRotate
        ? BoxConstraints(
            maxWidth: pageFormat.height - _margin.vertical,
            maxHeight: pageFormat.width - _margin.horizontal)
        : BoxConstraints(
            maxWidth: pageFormat.width - _margin.horizontal,
            maxHeight: pageFormat.height - _margin.vertical);
    final Theme calculatedTheme = theme ?? document.theme ?? Theme.base();
    Context context;
    double offsetEnd;
    double offsetStart;
    int index = 0;
    int sameCount = 0;
    final Context baseContext =
        Context(document: document.document).inheritFrom(calculatedTheme);
    final List<Widget> children = _buildList(baseContext);
    WidgetContext widgetContext;

    while (index < children.length) {
      final Widget child = children[index];
      bool canSpan = false;
      if (child is SpanningWidget) {
        canSpan = child.canSpan;
      }

      assert(() {
        // Detect too big widgets
        if (sameCount++ > maxPages) {
          throw Exception(
              'This widget created more than $maxPages pages. This may be an issue in the widget or the document.');
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
          fullConstraints: fullConstraints,
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
      if (widgetContext != null && canSpan && child is SpanningWidget) {
        child.restoreContext(widgetContext);
        widgetContext = null;
      }

      child.layout(context, constraints, parentUsesSize: false);
      assert(child.box != null);

      // What to do if the widget is too big for the page?
      if (offsetStart - child.box.height < offsetEnd) {
        // If it is not a multi-page widget and its height
        // is smaller than a full new page, we schedule a new page creation
        if (child.box.height <= pageHeight - pageHeightMargin && !canSpan) {
          context = null;
          continue;
        }

        // Else we crash if the widget is too big and cannot be splitted
        if (!canSpan) {
          throw Exception(
              'Widget won\'t fit into the page as its height (${child.box.height}) '
              'exceed a page height (${pageHeight - pageHeightMargin}). '
              'You probably need a SpanningWidget or use a single page layout');
        }

        final SpanningWidget span = child;

        final BoxConstraints localConstraints =
            constraints.copyWith(maxHeight: offsetStart - offsetEnd);
        child.layout(context, localConstraints, parentUsesSize: false);
        assert(child.box != null);
        widgetContext = span.saveContext();
        _pages.last.widgets.add(
          _MultiPageWidget(
            child: child,
            x: _margin.left,
            y: offsetStart - child.box.height,
            constraints: localConstraints,
            widgetContext: widgetContext?.clone(),
          ),
        );

        // Has it finished spanning?
        if (!span.hasMoreWidgets) {
          sameCount = 0;
          index++;
        }

        // Schedule a new page
        context = null;
        continue;
      }

      _pages.last.widgets.add(
        _MultiPageWidget(
          child: child,
          x: _margin.left,
          y: offsetStart - child.box.height,
          constraints: constraints,
          widgetContext: child is SpanningWidget && canSpan
              ? child.saveContext().clone()
              : null,
        ),
      );

      offsetStart -= child.box.height;
      sameCount = 0;
      index++;
    }
  }

  @override
  void postProcess(Document document) {
    final EdgeInsets _margin = margin;

    for (_MultiPageInstance page in _pages) {
      if (pageTheme.buildBackground != null) {
        final Widget child = pageTheme.buildBackground(page.context);
        if (child != null) {
          child.layout(page.context, page.fullConstraints,
              parentUsesSize: false);
          assert(child.box != null);
          _paintChild(page.context, child, _margin.left, _margin.bottom,
              pageFormat.height);
        }
      }

      for (_MultiPageWidget widget in page.widgets) {
        final Widget child = widget.child;
        if (child is SpanningWidget && child.canSpan) {
          final WidgetContext context = child.saveContext();
          context.apply(widget.widgetContext);
        }
        child.layout(page.context, widget.constraints, parentUsesSize: false);
        assert(child.box != null);
        _paintChild(
            page.context, widget.child, widget.x, widget.y, pageFormat.height);
      }

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

      if (pageTheme.buildForeground != null) {
        final Widget child = pageTheme.buildForeground(page.context);
        if (child != null) {
          child.layout(page.context, page.fullConstraints,
              parentUsesSize: false);
          assert(child.box != null);
          _paintChild(page.context, child, _margin.left, _margin.bottom,
              pageFormat.height);
        }
      }
    }
  }
}

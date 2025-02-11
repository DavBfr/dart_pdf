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

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../pdf.dart';
import 'basic.dart';
import 'document.dart';
import 'flex.dart';
import 'geometry.dart';
import 'page.dart';
import 'page_theme.dart';
import 'text.dart';
import 'text_style.dart';
import 'theme.dart';
import 'widget.dart';

abstract class WidgetContext {
  /// Called after layout to save the state
  WidgetContext clone();

  /// Called before relayout to restore the saved state and
  /// restart the layout in the same conditions
  void apply(covariant WidgetContext other);
}

mixin SpanningWidget on Widget {
  bool get canSpan;

  bool get hasMoreWidgets;

  /// Get unmodified mutable context object
  @protected
  WidgetContext saveContext();

  /// Apply the context for next page layout.
  /// Called before layout to prepare for next page
  @protected
  void restoreContext(covariant WidgetContext context);

  /// Called after layout to save the state
  @protected
  WidgetContext cloneContext() => saveContext().clone();

  /// Called before relayout to restore the saved state and
  /// restart the layout in the same conditions
  @protected
  void applyContext(covariant WidgetContext context) =>
      saveContext().apply(context);
}

/// Trigger a page break if there is not enough free space.
/// If freeSpace is null, a page break is always performed.
class NewPage extends Widget {
  NewPage({this.freeSpace});
  final double? freeSpace;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.zero;
  }

  bool newPageNeeded(double availableSpace) =>
      (freeSpace == null) || (availableSpace < freeSpace!);
}

@immutable
class _MultiPageWidget {
  const _MultiPageWidget({
    required this.child,
    required this.constraints,
    required this.widgetContext,
  });

  final Widget child;
  final BoxConstraints constraints;
  final WidgetContext? widgetContext;
}

@immutable
class _MultiPageInstance {
  _MultiPageInstance({
    required this.context,
    required this.constraints,
    required this.fullConstraints,
    required this.offsetStart,
  });

  final Context context;
  final BoxConstraints constraints;
  final BoxConstraints fullConstraints;
  final double? offsetStart;
  final List<_MultiPageWidget> widgets = <_MultiPageWidget>[];
}

/// Create a multi-page section, with automatic overflow from one page to another
///
/// ```dart
/// final pdf = Document();
/// pdf.addPage(MultiPage(build: (context) {
///   return [
///     Text('Hello'),
///     Text('World'),
///   ];
/// }));
/// ```
///
/// An inner widget tree cannot be bigger than a page: A [Widget] cannot be drawn
/// partially on one page and the remaining on another page: It's unbreakable.
///
/// A small set of [Widget] can automatically span over multiple pages, and can
/// be used as a direct child of the build method: [Flex], [Partition], [Table], [Wrap],
/// [GridView], and [Column].
///
/// ```dart
/// final pdf = Document();
/// pdf.addPage(MultiPage(build: (context) {
///   return [
///     Text('Hello'),
///     Wrap(
///       children: [
///         Text('One'),
///         Text('Two'),
///         Text('Three'),
///       ]
///     ),
///   ];
/// }));
/// ```
///
/// The [Wrap] [Widget] here is able to rearrange its children to span them across
/// multiple pages. But a child of [Wrap] must fit in a page, or an error will raise.
class MultiPage extends Page {
  MultiPage({
    PageTheme? pageTheme,
    PdfPageFormat? pageFormat,
    required BuildListCallback build,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.header,
    this.footer,
    ThemeData? theme,
    this.maxPages = 20,
    PageOrientation? orientation,
    EdgeInsetsGeometry? margin,
    TextDirection? textDirection,
  })  : _buildList = build,
        assert(maxPages > 0),
        super(
          pageTheme: pageTheme,
          pageFormat: pageFormat,
          build: (_) => SizedBox(),
          margin: margin,
          theme: theme,
          orientation: orientation,
          textDirection: textDirection,
        );

  final BuildListCallback _buildList;

  /// How the children should be placed along the cross axis.
  final CrossAxisAlignment crossAxisAlignment;

  /// A builder for the page header.
  final BuildCallback? header;

  /// A builder for the page footer.
  final BuildCallback? footer;

  /// How the children should be placed along the main axis.
  final MainAxisAlignment mainAxisAlignment;

  final List<_MultiPageInstance> _pages = <_MultiPageInstance>[];

  /// The maximum number of pages allowed before raising an error.
  /// This is not checked with a Release build.
  final int maxPages;

  void _paintChild(
      Context context, Widget child, double x, double y, double pageHeight) {
    if (mustRotate) {
      final _margin = resolvedMargin!;
      context.canvas
        ..saveContext()
        ..setTransform(
          Matrix4.identity()
            ..rotateZ(-math.pi / 2)
            ..translate(
              x - pageHeight + _margin.top - _margin.left,
              y + _margin.left - _margin.bottom,
            ),
        );
      child.paint(context);
      context.canvas.restoreContext();
    } else {
      child.box = child.box!.copyWith(x: x, y: y);
      child.paint(context);
    }
  }

  @override
  void generate(Document document, {bool insert = true, int? index}) {
    assert(pageFormat.width > 0 && pageFormat.width < double.infinity);
    assert(pageFormat.height > 0 && pageFormat.height < double.infinity);

    final _margin = resolvedMargin!;
    final _mustRotate = mustRotate;
    final pageHeight = _mustRotate ? pageFormat.width : pageFormat.height;
    final pageHeightMargin =
        _mustRotate ? _margin.horizontal : _margin.vertical;
    final constraints = BoxConstraints(
        maxWidth: _mustRotate
            ? (pageFormat.height - _margin.vertical)
            : (pageFormat.width - _margin.horizontal));
    final fullConstraints = mustRotate
        ? BoxConstraints(
            maxWidth: pageFormat.height - _margin.vertical,
            maxHeight: pageFormat.width - _margin.horizontal)
        : BoxConstraints(
            maxWidth: pageFormat.width - _margin.horizontal,
            maxHeight: pageFormat.height - _margin.vertical);
    final calculatedTheme = theme ?? document.theme ?? ThemeData.base();
    Context? context;
    var offsetEnd = 0.0;
    double? offsetStart;
    var _index = 0;
    var sameCount = 0;
    final baseContext =
        Context(document: document.document).inheritFromAll(<Inherited>[
      calculatedTheme,
      if (pageTheme.textDirection != null)
        InheritedDirectionality(pageTheme.textDirection),
    ]);
    final children = _buildList(baseContext);
    WidgetContext? widgetContext;

    while (_index < children.length) {
      final child = children[_index];

      assert(() {
        // Detect too big widgets
        if (sameCount++ > maxPages) {
          throw TooManyPagesException(
              'This widget created more than $maxPages pages. This may be an issue in the widget or the document. See https://pub.dev/documentation/pdf/latest/widgets/MultiPage-class.html');
        }
        return true;
      }());

      // Calculate available space of the current page
      final freeSpace = (offsetStart == null)
          ? fullConstraints.maxHeight
          : offsetStart - offsetEnd;

      // Create a new page if we don't already have one
      if (context == null ||
          (child is NewPage) && child.newPageNeeded(freeSpace)) {
        final pdfPage = PdfPage(
          document.document,
          pageFormat: pageFormat,
          index: index == null ? null : (index++),
        );
        final canvas = pdfPage.getGraphics();
        canvas.reset();
        context = baseContext.copyWith(page: pdfPage, canvas: canvas);

        assert(() {
          if (Document.debug) {
            debugPaint(context!);
          }
          return true;
        }());

        offsetStart = pageHeight -
            (_mustRotate ? pageHeightMargin - _margin.bottom : _margin.top);
        offsetEnd =
            _mustRotate ? pageHeightMargin - _margin.left : _margin.bottom;

        _pages.add(_MultiPageInstance(
          context: context,
          constraints: constraints,
          fullConstraints: fullConstraints,
          offsetStart: offsetStart,
        ));

        if (header != null) {
          final headerWidget = header!(context);

          headerWidget.layout(context, constraints, parentUsesSize: false);
          assert(headerWidget.box != null);
          offsetStart -= headerWidget.box!.height;
        }

        if (footer != null) {
          final footerWidget = footer!(context);

          footerWidget.layout(context, constraints, parentUsesSize: false);
          assert(footerWidget.box != null);
          offsetEnd += footerWidget.box!.height;
        }
      }

      // If we are processing a multi-page widget, we restore its context
      WidgetContext? savedContext;
      if (child is SpanningWidget && child.canSpan) {
        if (widgetContext != null) {
          child.restoreContext(widgetContext);
          widgetContext = null;
        }
        savedContext = child.cloneContext();
      }

      child.layout(context, constraints, parentUsesSize: false);
      assert(child.box != null);

      final canSpan = child is SpanningWidget && child.canSpan;

      // What to do if the widget is too big for the page?
      if (offsetStart! - child.box!.height < offsetEnd) {
        // If it is not a multi-page widget and its height
        // is smaller than a full new page, we schedule a new page creation
        if (child.box!.height <= pageHeight - pageHeightMargin && !canSpan) {
          context = null;
          continue;
        }

        // Else we crash if the widget is too big and cannot be separated
        if (!canSpan) {
          throw Exception(
              'Widget won\'t fit into the page as its height (${child.box!.height}) '
              'exceed a page height (${pageHeight - pageHeightMargin}). '
              'You probably need a SpanningWidget or use a single page layout');
        }

        final span = child;

        if (savedContext != null) {
          // Restore saved context
          span.applyContext(savedContext);
        }

        final localConstraints =
            constraints.copyWith(maxHeight: offsetStart - offsetEnd);
        span.layout(context, localConstraints, parentUsesSize: false);
        assert(span.box != null);
        widgetContext = span.saveContext();
        _pages.last.widgets.add(
          _MultiPageWidget(
            child: span,
            constraints: localConstraints,
            widgetContext: widgetContext.clone(),
          ),
        );

        // Has it finished spanning?
        if (!span.hasMoreWidgets) {
          sameCount = 0;
          _index++;
        }

        // Schedule a new page
        context = null;
        continue;
      }

      _pages.last.widgets.add(
        _MultiPageWidget(
          child: child,
          constraints: constraints,
          widgetContext:
              child is SpanningWidget && canSpan ? child.cloneContext() : null,
        ),
      );

      offsetStart -= child.box!.height;
      sameCount = 0;
      _index++;
    }
  }

  @override
  void postProcess(Document document) {
    final _margin = resolvedMargin!;
    final _mustRotate = mustRotate;
    final pageHeight = _mustRotate ? pageFormat.width : pageFormat.height;
    final pageWidth = _mustRotate ? pageFormat.height : pageFormat.width;
    final pageHeightMargin =
        _mustRotate ? _margin.horizontal : _margin.vertical;
    final pageWidthMargin = _mustRotate ? _margin.vertical : _margin.horizontal;
    final availableWidth = pageWidth - pageWidthMargin;
    final isRTL = pageTheme.textDirection == TextDirection.rtl;
    for (final page in _pages) {
      var offsetStart = pageHeight -
          (_mustRotate ? pageHeightMargin - _margin.bottom : _margin.top);
      var offsetEnd =
          _mustRotate ? pageHeightMargin - _margin.left : _margin.bottom;

      if (pageTheme.buildBackground != null) {
        final child = pageTheme.buildBackground!(page.context);

        child.layout(page.context, page.fullConstraints, parentUsesSize: false);
        assert(child.box != null);
        final xPos = isRTL
            ? _margin.left + (availableWidth - child.box!.width)
            : _margin.left;
        _paintChild(
            page.context, child, xPos, _margin.bottom, pageFormat.height);
      }

      var totalFlex = 0;
      var allocatedSize = 0.0;
      Widget? lastFlexChild;
      for (final widget in page.widgets) {
        final child = widget.child;
        final flex = child is Flexible ? child.flex : 0;
        if (flex > 0) {
          totalFlex += flex;
          lastFlexChild = child;
        } else {
          if (child is SpanningWidget && child.canSpan) {
            child.applyContext(widget.widgetContext!);
          }

          child.layout(page.context, widget.constraints, parentUsesSize: false);
          assert(child.box != null);
          allocatedSize += child.box!.height;
        }
      }

      if (header != null) {
        final headerWidget = header!(page.context);
        headerWidget.layout(page.context, page.constraints,
            parentUsesSize: false);
        assert(headerWidget.box != null);
        offsetStart -= headerWidget.box!.height;
        final xPos = isRTL
            ? _margin.left + (availableWidth - headerWidget.box!.width)
            : _margin.left;
        _paintChild(page.context, headerWidget, xPos,
            page.offsetStart! - headerWidget.box!.height, pageFormat.height);
      }

      if (footer != null) {
        final footerWidget = footer!(page.context);
        footerWidget.layout(page.context, page.constraints,
            parentUsesSize: false);
        assert(footerWidget.box != null);
        final xPos = isRTL
            ? _margin.left + (availableWidth - footerWidget.box!.width)
            : _margin.left;
        offsetEnd += footerWidget.box!.height;
        _paintChild(page.context, footerWidget, xPos, _margin.bottom,
            pageFormat.height);
      }

      final freeSpace = math.max(0.0, offsetStart - offsetEnd - allocatedSize);

      final spacePerFlex = totalFlex > 0 ? (freeSpace / totalFlex) : double.nan;
      var allocatedFlexSpace = 0.0;

      var leadingSpace = 0.0;
      var betweenSpace = 0.0;

      if (totalFlex == 0) {
        final totalChildren = page.widgets.length;

        switch (mainAxisAlignment) {
          case MainAxisAlignment.start:
            leadingSpace = 0.0;
            betweenSpace = 0.0;
            break;
          case MainAxisAlignment.end:
            leadingSpace = freeSpace;
            betweenSpace = 0.0;
            break;
          case MainAxisAlignment.center:
            leadingSpace = freeSpace / 2.0;
            betweenSpace = 0.0;
            break;
          case MainAxisAlignment.spaceBetween:
            leadingSpace = 0.0;
            betweenSpace =
                totalChildren > 1 ? freeSpace / (totalChildren - 1) : 0.0;
            break;
          case MainAxisAlignment.spaceAround:
            betweenSpace = totalChildren > 0 ? freeSpace / totalChildren : 0.0;
            leadingSpace = betweenSpace / 2.0;
            break;
          case MainAxisAlignment.spaceEvenly:
            betweenSpace =
                totalChildren > 0 ? freeSpace / (totalChildren + 1) : 0.0;
            leadingSpace = betweenSpace;
            break;
        }
      }

      for (final widget in page.widgets) {
        final child = widget.child;

        final flex = child is Flexible ? child.flex : 0;
        final fit = child is Flexible ? child.fit : FlexFit.loose;
        if (flex > 0) {
          assert(child is! SpanningWidget || child.canSpan == false,
              'Cannot have a spanning widget flexible');
          final maxChildExtent = child == lastFlexChild
              ? (freeSpace - allocatedFlexSpace)
              : spacePerFlex * flex;
          late double minChildExtent;
          switch (fit) {
            case FlexFit.tight:
              assert(maxChildExtent < double.infinity);
              minChildExtent = maxChildExtent;
              break;
            case FlexFit.loose:
              minChildExtent = 0.0;
              break;
          }

          final innerConstraints = BoxConstraints(
              minWidth: widget.constraints.maxWidth,
              maxWidth: widget.constraints.maxWidth,
              minHeight: minChildExtent,
              maxHeight: maxChildExtent);

          child.layout(page.context, innerConstraints, parentUsesSize: false);
          assert(child.box != null);
          final childSize = child.box!.height;
          assert(childSize <= maxChildExtent);
          allocatedSize += childSize;
          allocatedFlexSpace += maxChildExtent;
        }
      }
      var pos = offsetStart - leadingSpace;
      for (final widget in page.widgets) {
        pos -= widget.child.box!.height;
        late double x;
        switch (crossAxisAlignment) {
          case CrossAxisAlignment.stretch:
          case CrossAxisAlignment.start:
            if (isRTL) {
              x = availableWidth - widget.child.box!.width;
            } else {
              x = 0;
            }
            break;
          case CrossAxisAlignment.end:
            if (isRTL) {
              x = 0;
            } else {
              x = availableWidth - widget.child.box!.width;
            }
            break;
          case CrossAxisAlignment.center:
            x = availableWidth / 2 - widget.child.box!.width / 2;
            break;
        }
        final child = widget.child;
        if (child is SpanningWidget && child.canSpan) {
          child.applyContext(widget.widgetContext!);
        }
        _paintChild(page.context, widget.child, _margin.left + x, pos,
            pageFormat.height);
        pos -= betweenSpace;
      }

      if (pageTheme.buildForeground != null) {
        final child = pageTheme.buildForeground!(page.context);

        child.layout(page.context, page.fullConstraints, parentUsesSize: false);
        assert(child.box != null);
        final xPos = isRTL
            ? _margin.left + (availableWidth - child.box!.width)
            : _margin.left;
        _paintChild(
            page.context, child, xPos, _margin.bottom, pageFormat.height);
      }
    }
  }
}

/// Exception thrown when generator populates more pages than [maxPages].
class TooManyPagesException implements Exception {
  TooManyPagesException(this.message);

  final String message;
}

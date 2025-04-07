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
import 'document.dart';
import 'geometry.dart';
import 'page_theme.dart';
import 'text.dart';
import 'text_style.dart';
import 'theme.dart';
import 'widget.dart';

typedef BuildCallback = Widget Function(Context context);
typedef BuildListCallback = List<Widget> Function(Context context);

enum PageOrientation { natural, landscape, portrait }

class Page {
  Page({
    PageTheme? pageTheme,
    PdfPageFormat? pageFormat,
    required BuildCallback build,
    ThemeData? theme,
    PageOrientation? orientation,
    EdgeInsetsGeometry? margin,
    bool clip = false,
    TextDirection? textDirection,
  })  : assert(
            pageTheme == null ||
                (pageFormat == null &&
                    theme == null &&
                    orientation == null &&
                    margin == null &&
                    clip == false &&
                    textDirection == null),
            'Don\'t set both pageTheme and other settings'),
        pageTheme = pageTheme ??
            PageTheme(
              pageFormat: pageFormat,
              orientation: orientation,
              margin: margin,
              theme: theme,
              clip: clip,
              textDirection: textDirection,
            ),
        _build = build;

  final PageTheme pageTheme;

  PdfPageFormat get pageFormat => _pdfPage?.pageFormat ?? pageTheme.pageFormat;

  PageOrientation get orientation => pageTheme.orientation;

  BuildCallback? _build;

  ThemeData? get theme => pageTheme.theme;

  bool get mustRotate => pageTheme.mustRotate;

  PdfPage? _pdfPage;

  EdgeInsetsGeometry? get margin => pageTheme.margin;

  EdgeInsets? get resolvedMargin => margin?.resolve(pageTheme.textDirection);

  bool processed = false;

  @protected
  void debugPaint(Context context) {
    final _margin = resolvedMargin!;

    context.canvas
      ..setFillColor(PdfColors.lightGreen)
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

  void generate(Document document, {bool insert = true, int? index}) {
    if (index != null) {
      if (insert) {
        _pdfPage =
            PdfPage(document.document, pageFormat: pageFormat, index: index);
      } else {
        _pdfPage = document.document.page(index);
      }
    } else {
      _pdfPage = PdfPage(document.document, pageFormat: pageFormat);
    }
  }

  void postProcess(Document document) {
    if (processed) {
      return;
    }
    assert(_build != null);

    final canvas = _pdfPage!.getGraphics();
    canvas.reset();
    final _margin = resolvedMargin;
    var constraints = mustRotate
        ? BoxConstraints(
            maxWidth: pageFormat.height - _margin!.vertical,
            maxHeight: pageFormat.width - _margin.horizontal)
        : BoxConstraints(
            maxWidth: pageFormat.width - _margin!.horizontal,
            maxHeight: pageFormat.height - _margin.vertical);

    final calculatedTheme = theme ?? document.theme ?? ThemeData.base();
    final context = Context(
      document: document.document,
      page: _pdfPage!,
      canvas: canvas,
    ).inheritFromAll(<Inherited>[
      calculatedTheme,
      if (pageTheme.textDirection != null)
        InheritedDirectionality(pageTheme.textDirection),
    ]);

    Widget? background;
    Widget? content;
    Widget? foreground;

    content = _build!(context);

    final size = layout(content, context, constraints);

    if (_pdfPage!.pageFormat.height == double.infinity) {
      _pdfPage!.pageFormat =
          _pdfPage!.pageFormat.copyWith(width: size.x, height: size.y);
      constraints = mustRotate
          ? BoxConstraints(
              maxWidth: _pdfPage!.pageFormat.height - _margin.vertical,
              maxHeight: _pdfPage!.pageFormat.width - _margin.horizontal)
          : BoxConstraints(
              maxWidth: _pdfPage!.pageFormat.width - _margin.horizontal,
              maxHeight: _pdfPage!.pageFormat.height - _margin.vertical);
    }

    if (pageTheme.buildBackground != null) {
      background = pageTheme.buildBackground!(context);
      layout(background, context, constraints);
    }

    if (pageTheme.buildForeground != null) {
      foreground = pageTheme.buildForeground!(context);
      layout(foreground, context, constraints);
    }

    assert(() {
      if (Document.debug) {
        debugPaint(context);
      }
      return true;
    }());

    if (background != null) {
      paint(background, context);
    }

    paint(content, context);

    if (foreground != null) {
      paint(foreground, context);
    }
    processed = true;
    _build = null;
  }

  @protected
  PdfPoint layout(Widget child, Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final _margin = resolvedMargin!;
    child.layout(context, constraints, parentUsesSize: parentUsesSize);
    assert(child.box != null);

    final width = pageFormat.width == double.infinity
        ? child.box!.width + _margin.left + _margin.right
        : pageFormat.width;

    final height = pageFormat.height == double.infinity
        ? child.box!.height + _margin.top + _margin.bottom
        : pageFormat.height;

    child.box = PdfRect(_margin.left, height - child.box!.height - _margin.top,
        child.box!.width, child.box!.height);

    return PdfPoint(width, height);
  }

  @protected
  void paint(Widget child, Context context) {
    final _margin = resolvedMargin!;
    final box = PdfRect(
      _margin.left,
      _margin.bottom,
      pageFormat.width - _margin.horizontal,
      pageFormat.height - _margin.vertical,
    );
    if (pageTheme.clip) {
      context.canvas
        ..saveContext()
        ..drawRect(box.x, box.y, box.width, box.height)
        ..clipPath();
    }

    if (pageTheme.textDirection == TextDirection.rtl) {
      child.box = PdfRect(
        ((mustRotate ? box.height : box.width) - child.box!.width) +
            child.box!.x,
        child.box!.y,
        child.box!.width,
        child.box!.height,
      );
    }

    if (mustRotate) {
      final _margin = resolvedMargin!;
      context.canvas
        ..saveContext()
        ..setTransform(Matrix4.identity()
          ..rotateZ(-math.pi / 2)
          ..translate(
            -pageFormat.height - _margin.left + _margin.top,
            -pageFormat.height + pageFormat.width + _margin.top - _margin.right,
          ));
      child.paint(context);
      context.canvas.restoreContext();
    } else {
      child.paint(context);
    }

    if (pageTheme.clip) {
      context.canvas.restoreContext();
    }
  }
}

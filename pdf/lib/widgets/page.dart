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

typedef BuildCallback = Widget Function(Context context);
typedef BuildListCallback = List<Widget> Function(Context context);

enum PageOrientation { natural, landscape, portrait }

class Page {
  Page(
      {PageTheme pageTheme,
      PdfPageFormat pageFormat,
      BuildCallback build,
      Theme theme,
      PageOrientation orientation,
      EdgeInsets margin})
      : assert(
            pageTheme == null ||
                (pageFormat == null &&
                    theme == null &&
                    orientation == null &&
                    margin == null),
            'Don\'t set both pageTheme and other settings'),
        pageTheme = pageTheme ??
            PageTheme(
              pageFormat: pageFormat,
              orientation: orientation,
              margin: margin,
              theme: theme,
            ),
        _build = build;

  final PageTheme pageTheme;

  PdfPageFormat get pageFormat => pageTheme.pageFormat;

  PageOrientation get orientation => pageTheme.orientation;

  final BuildCallback _build;

  Theme get theme => pageTheme.theme;

  bool get mustRotate => pageTheme.mustRotate;

  PdfPage _pdfPage;

  EdgeInsets get margin => pageTheme.margin;

  @protected
  void debugPaint(Context context) {
    final EdgeInsets _margin = margin;
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

  @protected
  void generate(Document document) {
    _pdfPage = PdfPage(document.document, pageFormat: pageFormat);
  }

  @protected
  void postProcess(Document document) {
    final PdfGraphics canvas = _pdfPage.getGraphics();
    final EdgeInsets _margin = margin;
    final BoxConstraints constraints = mustRotate
        ? BoxConstraints(
            maxWidth: pageFormat.height - _margin.vertical,
            maxHeight: pageFormat.width - _margin.horizontal)
        : BoxConstraints(
            maxWidth: pageFormat.width - _margin.horizontal,
            maxHeight: pageFormat.height - _margin.vertical);

    final Theme calculatedTheme = theme ?? document.theme ?? Theme.base();
    final Context context = Context(
      document: document.document,
      page: _pdfPage,
      canvas: canvas,
    ).inheritFrom(calculatedTheme);
    if (pageTheme.buildBackground != null) {
      final Widget child = pageTheme.buildBackground(context);
      if (child != null) {
        layout(child, context, constraints);
        paint(child, context);
      }
    }
    if (_build != null) {
      final Widget child = _build(context);
      if (child != null) {
        layout(child, context, constraints);
        paint(child, context);
      }
    }
    if (pageTheme.buildForeground != null) {
      final Widget child = pageTheme.buildForeground(context);
      if (child != null) {
        layout(child, context, constraints);
        paint(child, context);
      }
    }
  }

  @protected
  void layout(Widget child, Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    if (child != null) {
      final EdgeInsets _margin = margin;
      child.layout(context, constraints, parentUsesSize: parentUsesSize);
      assert(child.box != null);
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

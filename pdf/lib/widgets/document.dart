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

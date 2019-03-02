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

class Anchor extends SingleChildWidget {
  Anchor({Widget child, @required this.name, this.description})
      : assert(name != null),
        super(child: child);

  final String name;

  final String description;

  @override
  void paint(Context context) {
    super.paint(context);
    paintChild(context);

    final Matrix4 mat = context.canvas.getTransform();
    final Vector3 lt = mat.transform3(Vector3(box.left, box.bottom, 0));
    context.document.pdfNames.addDest(name, context.page, posY: lt.y);

    if (description != null) {
      final Vector3 rb = mat.transform3(Vector3(box.right, box.top, 0));
      final PdfRect ibox = PdfRect.fromLTRB(lt.x, lt.y, rb.x, rb.y);
      PdfAnnot.text(context.page, content: description, rect: ibox);
    }
  }
}

class _Annotation extends SingleChildWidget {
  _Annotation({Widget child}) : super(child: child);

  @override
  void debugPaint(Context context) {
    context.canvas
      ..setFillColor(PdfColors.pink)
      ..drawRect(box.x, box.y, box.width, box.height)
      ..fillPath();
  }

  @override
  void paint(Context context) {
    super.paint(context);
    paintChild(context);
  }
}

class Link extends _Annotation {
  Link({@required Widget child, this.destination})
      : assert(child != null),
        super(child: child);

  final String destination;

  @override
  void paint(Context context) {
    super.paint(context);

    if (destination != null) {
      final Matrix4 mat = context.canvas.getTransform();
      final Vector3 lt = mat.transform3(Vector3(box.left, box.bottom, 0));
      final Vector3 rb = mat.transform3(Vector3(box.right, box.top, 0));
      final PdfRect ibox = PdfRect.fromLTRB(lt.x, lt.y, rb.x, rb.y);
      PdfAnnot.namedLink(
        context.page,
        rect: ibox,
        dest: destination,
      );
    }
  }
}

class UrlLink extends _Annotation {
  UrlLink({@required Widget child, @required this.destination})
      : assert(child != null),
        assert(destination != null),
        super(child: child);

  final String destination;

  @override
  void paint(Context context) {
    super.paint(context);

    final Matrix4 mat = context.canvas.getTransform();
    final Vector3 lt = mat.transform3(Vector3(box.left, box.bottom, 0));
    final Vector3 rb = mat.transform3(Vector3(box.right, box.top, 0));
    final PdfRect ibox = PdfRect.fromLTRB(lt.x, lt.y, rb.x, rb.y);
    PdfAnnot.urlLink(
      context.page,
      rect: ibox,
      dest: destination,
    );
  }
}

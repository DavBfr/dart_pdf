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
      PdfAnnot(context.page, PdfAnnotText(rect: ibox, content: description));
    }
  }
}

abstract class AnnotationBuilder {
  PdfRect localToGlobal(Context context, PdfRect box) {
    final Matrix4 mat = context.canvas.getTransform();
    final Vector3 lt = mat.transform3(Vector3(box.left, box.bottom, 0));
    final Vector3 rb = mat.transform3(Vector3(box.right, box.top, 0));
    return PdfRect.fromLTRB(lt.x, lt.y, rb.x, rb.y);
  }

  void build(Context context, PdfRect box);
}

class AnnotationLink extends AnnotationBuilder {
  AnnotationLink(this.destination) : assert(destination != null);

  final String destination;

  @override
  void build(Context context, PdfRect box) {
    PdfAnnot(
      context.page,
      PdfAnnotNamedLink(
        rect: localToGlobal(context, box),
        dest: destination,
      ),
    );
  }
}

class AnnotationUrl extends AnnotationBuilder {
  AnnotationUrl(this.destination) : assert(destination != null);

  final String destination;

  @override
  void build(Context context, PdfRect box) {
    PdfAnnot(
      context.page,
      PdfAnnotUrlLink(
        rect: localToGlobal(context, box),
        url: destination,
      ),
    );
  }
}

class AnnotationSignature extends AnnotationBuilder {
  AnnotationSignature(
    this.crypto, {
    this.name,
    this.signFlags,
    this.border,
    this.flags,
    this.date,
    this.color,
    this.highlighting,
  }) : assert(crypto != null);

  final Set<PdfSigFlags> signFlags;

  final PdfSignatureBase crypto;

  final String name;

  final PdfBorder border;

  final Set<PdfAnnotFlags> flags;

  final DateTime date;

  final PdfColor color;

  final PdfAnnotHighlighting highlighting;

  @override
  void build(Context context, PdfRect box) {
    context.document.sign ??= PdfSignature(
      context.document,
      crypto: crypto,
      flags: signFlags,
    );

    PdfAnnot(
      context.page,
      PdfAnnotSign(
        localToGlobal(context, box),
        fieldName: name,
        border: border,
        flags: flags,
        date: date,
        color: color,
        highlighting: highlighting,
      ),
    );
  }
}

class Annotation extends SingleChildWidget {
  Annotation({Widget child, this.builder}) : super(child: child);

  final AnnotationBuilder builder;

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
    builder?.build(context, box);
  }
}

class Link extends Annotation {
  Link({@required Widget child, String destination})
      : assert(child != null),
        super(child: child, builder: AnnotationLink(destination));
}

class UrlLink extends Annotation {
  UrlLink({@required Widget child, String destination})
      : assert(child != null),
        super(child: child, builder: AnnotationUrl(destination));
}

class Signature extends Annotation {
  Signature({
    @required Widget child,
    @required PdfSignatureBase crypto,
    @required String name,
    Set<PdfSigFlags> signFlags,
    PdfBorder border,
    Set<PdfAnnotFlags> flags,
    DateTime date,
    PdfColor color,
    PdfAnnotHighlighting highlighting,
  })  : assert(child != null),
        assert(crypto != null),
        super(
            child: child,
            builder: AnnotationSignature(
              crypto,
              signFlags: signFlags,
              name: name,
              border: border,
              flags: flags,
              date: date,
              color: color,
              highlighting: highlighting,
            ));
}

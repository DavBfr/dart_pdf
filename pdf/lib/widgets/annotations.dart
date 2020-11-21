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
  Anchor({
    Widget child,
    @required this.name,
    this.description,
    this.zoom,
    this.setX = false,
  })  : assert(name != null),
        assert(setX != null),
        super(child: child);

  final String name;

  final String description;

  final double zoom;

  final bool setX;

  @override
  void paint(Context context) {
    super.paint(context);
    paintChild(context);

    final Matrix4 mat = context.canvas.getTransform();
    final Vector3 lt = mat.transform3(Vector3(box.left, box.top, 0));
    context.document.pdfNames.addDest(
      name,
      context.page,
      posX: setX ? lt.x : null,
      posY: lt.y,
      posZ: zoom,
    );

    if (description != null) {
      final Vector3 rb = mat.transform3(Vector3(box.right, box.top, 0));
      final PdfRect ibox = PdfRect.fromLTRB(lt.x, lt.y, rb.x, rb.y);
      PdfAnnot(context.page, PdfAnnotText(rect: ibox, content: description));
    }
  }
}

abstract class AnnotationBuilder {
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
        rect: context.localToGlobal(box),
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
        rect: context.localToGlobal(box),
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
        rect: context.localToGlobal(box),
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

class AnnotationTextField extends AnnotationBuilder {
  AnnotationTextField({
    this.name,
    this.border,
    this.flags,
    this.date,
    this.color,
    this.backgroundColor,
    this.highlighting,
    this.maxLength,
    this.alternateName,
    this.mappingName,
    this.fieldFlags,
    this.value,
    this.defaultValue,
    this.textStyle,
  });

  final String name;

  final PdfBorder border;

  final Set<PdfAnnotFlags> flags;

  final DateTime date;

  final PdfColor color;

  final PdfColor backgroundColor;

  final PdfAnnotHighlighting highlighting;

  final int maxLength;

  final String value;

  final String defaultValue;

  final TextStyle textStyle;

  final String alternateName;

  final String mappingName;

  final Set<PdfFieldFlags> fieldFlags;

  @override
  void build(Context context, PdfRect box) {
    final TextStyle _textStyle =
        Theme.of(context).defaultTextStyle.merge(textStyle);

    PdfAnnot(
      context.page,
      PdfTextField(
        rect: context.localToGlobal(box),
        fieldName: name,
        border: border,
        flags: flags,
        date: date,
        color: color,
        backgroundColor: backgroundColor,
        highlighting: highlighting,
        maxLength: maxLength,
        alternateName: alternateName,
        mappingName: mappingName,
        fieldFlags: fieldFlags,
        value: value,
        defaultValue: defaultValue,
        font: _textStyle.font.getFont(context),
        fontSize: _textStyle.fontSize,
        textColor: _textStyle.color,
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

class TextField extends Annotation {
  TextField({
    Widget child,
    double width = 120,
    double height = 13,
    String name,
    PdfBorder border,
    Set<PdfAnnotFlags> flags,
    DateTime date,
    PdfColor color,
    PdfColor backgroundColor,
    PdfAnnotHighlighting highlighting,
    int maxLength,
    String alternateName,
    String mappingName,
    Set<PdfFieldFlags> fieldFlags,
    String value,
    String defaultValue,
    TextStyle textStyle,
  }) : super(
            child: child ?? SizedBox(width: width, height: height),
            builder: AnnotationTextField(
              name: name,
              border: border,
              flags: flags,
              date: date,
              color: color,
              backgroundColor: backgroundColor,
              highlighting: highlighting,
              maxLength: maxLength,
              alternateName: alternateName,
              mappingName: mappingName,
              fieldFlags: fieldFlags,
              value: value,
              defaultValue: defaultValue,
              textStyle: textStyle,
            ));
}

class Outline extends Anchor {
  Outline({
    Widget child,
    @required String name,
    @required this.title,
    this.level = 0,
    this.color,
    this.style = PdfOutlineStyle.normal,
  })  : assert(title != null),
        assert(level != null && level >= 0),
        assert(style != null),
        super(child: child, name: name, setX: true);

  final String title;

  final int level;

  final PdfColor color;

  final PdfOutlineStyle style;

  PdfOutline _outline;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    super.layout(context, constraints, parentUsesSize: parentUsesSize);
    _buildOutline(context);
  }

  @override
  void debugPaint(Context context) {
    context.canvas
      ..setFillColor(PdfColors.pink100)
      ..drawRect(box.x, box.y, box.width, box.height)
      ..fillPath();
  }

  void _buildOutline(Context context) {
    if (_outline != null) {
      return;
    }

    _outline = PdfOutline(
      context.document,
      title: title,
      anchor: name,
      color: color,
      style: style,
    );

    PdfOutline parent = context.document.outline;
    int l = level;

    while (l > 0) {
      if (parent.effectiveLevel == l) {
        break;
      }

      if (parent.outlines.isEmpty) {
        parent.effectiveLevel = level;
        break;
      }
      parent = parent.outlines.last;
      l--;
    }

    parent.add(_outline);
  }
}

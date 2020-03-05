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

part of pdf;

class PdfAnnot extends PdfObject {
  PdfAnnot(this.pdfPage, this.annot)
      : assert(annot != null),
        super(pdfPage.pdfDocument, '/Annot') {
    pdfPage.annotations.add(this);
  }

  /// Create a text annotation
  @deprecated
  factory PdfAnnot.text(
    PdfPage pdfPage, {
    @required PdfRect rect,
    @required String content,
    PdfBorder border,
  }) =>
      PdfAnnot(
          pdfPage,
          PdfAnnotText(
            rect: rect,
            content: content,
            border: border,
          ));

  /// Creates an external link annotation
  @deprecated
  factory PdfAnnot.urlLink(
    PdfPage pdfPage, {
    @required PdfRect rect,
    @required String dest,
    PdfBorder border,
  }) =>
      PdfAnnot(
          pdfPage,
          PdfAnnotUrlLink(
            rect: rect,
            url: dest,
            border: border,
          ));

  /// Creates a link annotation to a named destination
  @deprecated
  factory PdfAnnot.namedLink(
    PdfPage pdfPage, {
    @required PdfRect rect,
    @required String dest,
    PdfBorder border,
  }) =>
      PdfAnnot(
        pdfPage,
        PdfAnnotNamedLink(
          rect: rect,
          dest: dest,
          border: border,
        ),
      );

  /// The annotation content
  final PdfAnnotBase annot;

  /// The page where the annotation will display
  final PdfPage pdfPage;

  /// Output the annotation
  ///
  /// @param os OutputStream to send the object to
  @override
  void _prepare() {
    super._prepare();
    annot.build(pdfPage, params);
  }
}

enum PdfAnnotFlags {
  invisible,
  hidden,
  print,
  noZoom,
  noRotate,
  noView,
  readOnly,
  locked,
  toggleNoView,
  lockedContent
}

abstract class PdfAnnotBase {
  const PdfAnnotBase({
    @required this.subtype,
    @required this.rect,
    this.border,
    this.content,
    this.name,
    this.flags,
    this.date,
    this.color,
  })  : assert(subtype != null),
        assert(rect != null);

  /// The subtype of the outline, ie text, note, etc
  final String subtype;

  final PdfRect rect;

  /// the border for this annotation
  final PdfBorder border;

  /// The text of a text annotation
  final String content;

  /// The internal name for a link
  final String name;

  /// Flags specifying various characteristics of the annotation
  final Set<PdfAnnotFlags> flags;

  /// Last modification date
  final DateTime date;

  /// Color
  final PdfColor color;

  int get flagValue => flags
      ?.map<int>((PdfAnnotFlags e) => 1 >> e.index)
      ?.reduce((int a, int b) => a | b);

  @protected
  @mustCallSuper
  void build(PdfPage page, Map<String, PdfStream> params) {
    params['/Subtype'] = PdfStream.string(subtype);
    params['/Rect'] = PdfStream()
      ..putNumArray(<double>[rect.left, rect.bottom, rect.right, rect.top]);

    params['/P'] = page.ref();

    // handle the border
    if (border == null) {
      params['/Border'] = PdfStream.string('[0 0 0]');
    } else {
      params['/BS'] = border.ref();
    }

    if (content != null) {
      params['/Contents'] = PdfStream()..putLiteral(content);
    }

    if (name != null) {
      params['/NM'] = PdfStream()..putLiteral(name);
    }

    if (flags != null) {
      params['/F'] = PdfStream.intNum(flagValue);
    }

    if (date != null) {
      params['/M'] = PdfStream()..putDate(date);
    }

    if (color != null) {
      if (color is PdfColorCmyk) {
        final PdfColorCmyk k = color;
        params['/C'] = PdfStream()
          ..putNumList(<double>[k.cyan, k.magenta, k.yellow, k.black]);
      } else {
        params['/C'] = PdfStream()
          ..putNumList(<double>[color.red, color.green, color.blue]);
      }
    }
  }
}

class PdfAnnotText extends PdfAnnotBase {
  /// Create a text annotation
  const PdfAnnotText({
    @required PdfRect rect,
    @required String content,
    PdfBorder border,
    String name,
    Set<PdfAnnotFlags> flags,
    DateTime date,
    PdfColor color,
  }) : super(
          subtype: '/Text',
          rect: rect,
          border: border,
          content: content,
          name: name,
          flags: flags,
          date: date,
          color: color,
        );
}

class PdfAnnotNamedLink extends PdfAnnotBase {
  /// Create a named link annotation
  const PdfAnnotNamedLink({
    @required PdfRect rect,
    @required this.dest,
    PdfBorder border,
    Set<PdfAnnotFlags> flags,
    DateTime date,
    PdfColor color,
  }) : super(
          subtype: '/Link',
          rect: rect,
          border: border,
          flags: flags,
          date: date,
          color: color,
        );

  final String dest;

  @override
  void build(PdfPage page, Map<String, PdfStream> params) {
    super.build(page, params);
    params['/A'] = PdfStream()
      ..putDictionary(
        <String, PdfStream>{
          '/S': PdfStream()..putString('/GoTo'),
          '/D': PdfStream()..putText(dest),
        },
      );
  }
}

class PdfAnnotUrlLink extends PdfAnnotBase {
  /// Create an url link annotation
  const PdfAnnotUrlLink({
    @required PdfRect rect,
    @required this.url,
    PdfBorder border,
    Set<PdfAnnotFlags> flags,
    DateTime date,
    PdfColor color,
  }) : super(
          subtype: '/Link',
          rect: rect,
          border: border,
          flags: flags,
          date: date,
          color: color,
        );

  final String url;

  @override
  void build(PdfPage page, Map<String, PdfStream> params) {
    super.build(page, params);
    params['/A'] = PdfStream()
      ..putDictionary(
        <String, PdfStream>{
          '/S': PdfStream()..putString('/URI'),
          '/URI': PdfStream()..putText(url),
        },
      );
  }
}

enum PdfAnnotHighlighting { none, invert, outline, push, toggle }

abstract class PdfAnnotWidget extends PdfAnnotBase {
  /// Create an url link annotation
  const PdfAnnotWidget(
    PdfRect rect,
    this.fieldType, {
    this.fieldName,
    PdfBorder border,
    Set<PdfAnnotFlags> flags,
    DateTime date,
    PdfColor color,
    this.highlighting,
    this.value,
  }) : super(
          subtype: '/Widget',
          rect: rect,
          border: border,
          flags: flags,
          date: date,
          color: color,
        );

  final String fieldType;

  final String fieldName;

  final PdfAnnotHighlighting highlighting;

  final PdfStream value;

  @override
  void build(PdfPage page, Map<String, PdfStream> params) {
    super.build(page, params);

    params['/FT'] = PdfStream.string(fieldType);

    if (fieldName != null) {
      params['/T'] = PdfStream()..putLiteral(fieldName);
    }

    if (value != null) {
      params['/V'] = value;
    }
  }
}

class PdfAnnotSign extends PdfAnnotWidget {
  const PdfAnnotSign(
    PdfRect rect, {
    String fieldName,
    PdfBorder border,
    Set<PdfAnnotFlags> flags,
    DateTime date,
    PdfColor color,
    PdfAnnotHighlighting highlighting,
  }) : super(
          rect,
          '/Sig',
          fieldName: fieldName,
          border: border,
          flags: flags,
          date: date,
          color: color,
          highlighting: highlighting,
        );

  @override
  void build(PdfPage page, Map<String, PdfStream> params) {
    super.build(page, params);
    assert(page.pdfDocument.sign != null);
    params['/V'] = page.pdfDocument.sign.ref();
  }
}

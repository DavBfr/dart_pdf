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

import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';

import '../color.dart';
import '../document.dart';
import '../format/array.dart';
import '../format/base.dart';
import '../format/dict.dart';
import '../format/name.dart';
import '../format/null_value.dart';
import '../format/num.dart';
import '../format/stream.dart';
import '../format/string.dart';
import '../graphics.dart';
import '../point.dart';
import '../rect.dart';
import 'acroform_field.dart';
import 'border.dart';
import 'font.dart';
import 'graphic_stream.dart';
import 'object.dart';
import 'page.dart';

class PdfChoiceField extends PdfAnnotWidget {
  PdfChoiceField({
    required PdfRect rect,
    required this.textColor,
    required this.font,
    required this.fontSize,
    required this.items,
    String? fieldName,
    this.value,
    this.defaultValue,
  }) : super(rect: rect, fieldType: '/Ch', fieldName: fieldName);

  final List<String> items;
  final PdfColor textColor;
  final String? value;
  final String? defaultValue;
  final Set<PdfFieldFlags>? fieldFlags = {PdfFieldFlags.combo};
  final PdfFont font;

  final double fontSize;

  @override
  Iterable<PdfFont> get defaultAppearanceFonts => <PdfFont>[font];

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);
    // What is /F?
    //params['/F'] = const PdfNum(4);
    final field = fieldParams(params);
    field['/Ff'] = PdfNum(fieldFlagsValue);
    field['/Opt'] = PdfArray<PdfString>(
      items.map((e) => PdfString.fromString(e)).toList(),
    );

    if (defaultValue != null) {
      field['/DV'] = PdfString.fromString(defaultValue!);
    }

    if (value != null) {
      field['/V'] = PdfString.fromString(value!);
    } else {
      field['/V'] = const PdfNull();
    }

    final buf = PdfStream();
    final g = PdfGraphics(page, buf);
    g.setFillColor(textColor);
    g.setFont(font, fontSize);

    field['/DA'] = PdfString.fromStream(buf);

    // What is /TU? Tooltip?
    //params['/TU'] = PdfString.fromString('Select from list');
  }

  int get fieldFlagsValue {
    if (fieldFlags == null || fieldFlags!.isEmpty) {
      return 0;
    }

    return fieldFlags!
        .map<int>((PdfFieldFlags e) => 1 << e.index)
        .reduce((int a, int b) => a | b);
  }
}

class PdfAnnot extends PdfObject<PdfDict> {
  PdfAnnot(this.pdfPage, this.annot, {int? objser, int objgen = 0})
    : super(
        pdfPage.pdfDocument,
        objser: objser,
        objgen: objgen,
        params: PdfDict.values({'/Type': const PdfName('/Annot')}),
      ) {
    pdfPage.annotations.add(this);
  }

  /// The annotation content
  final PdfAnnotBase annot;

  /// The page where the annotation will display
  final PdfPage pdfPage;

  /// Output the annotation
  @override
  void prepare() {
    super.prepare();
    annot.build(pdfPage, this, params);
  }
}

enum PdfAnnotFlags {
  /// 1
  invisible,

  /// 2
  hidden,

  /// 3
  print,

  /// 4
  noZoom,

  /// 5
  noRotate,

  /// 6
  noView,

  /// 7
  readOnly,

  /// 8
  locked,

  /// 9
  toggleNoView,

  /// 10
  lockedContent,
}

enum PdfAnnotAppearance { normal, rollover, down }

abstract class PdfAnnotBase {
  PdfAnnotBase({
    required this.subtype,
    required this.rect,
    this.border,
    this.content,
    this.name,
    Set<PdfAnnotFlags>? flags,
    this.date,
    this.color,
    this.subject,
    this.author,
  }) {
    this.flags = flags ?? {PdfAnnotFlags.print};
  }

  /// The subtype of the outline, ie text, note, etc
  final String subtype;

  final PdfRect rect;

  /// the border for this annotation
  final PdfBorder? border;

  /// The text of a text annotation
  final String? content;

  /// The internal name for a link
  final String? name;

  /// The author of the annotation
  final String? author;

  /// Whether this is a markup annotation, which is what `/T`, `/Subj` and the
  /// other text-markup keys belong to.
  bool get isMarkup => true;

  /// The fonts this annotation names in its `/DA` string.
  ///
  /// ISO 32000-1 12.7.3.3 requires every font a `/DA` names to be a key of the
  /// form's `/DR` `/Font` dictionary. The collector only recognised a
  /// PdfTextField, so a ChoiceField's `/DA` named a font declared nowhere -
  /// Acrobat then regenerated the appearance with Helvetica and CJK or Arabic
  /// option text came out as boxes.
  Iterable<PdfFont> get defaultAppearanceFonts => const <PdfFont>[];

  /// The subject of the annotation
  final String? subject;

  /// Flags specifying various characteristics of the annotation
  late final Set<PdfAnnotFlags> flags;

  /// Last modification date
  final DateTime? date;

  /// Color
  final PdfColor? color;

  final _appearances = <String, PdfDataType>{};

  PdfName? _as;

  int get flagValue {
    if (flags.isEmpty) {
      return 0;
    }

    return flags
        .map<int>((PdfAnnotFlags e) => 1 << e.index)
        .reduce((int a, int b) => a | b);
  }

  PdfGraphics appearance(
    PdfDocument pdfDocument,
    PdfAnnotAppearance type, {
    String? name,
    Matrix4? matrix,
    PdfRect? boundingBox,
    bool selected = false,
  }) {
    final s = PdfGraphicXObject(pdfDocument, '/Form');
    String? n;
    switch (type) {
      case PdfAnnotAppearance.normal:
        n = '/N';
        break;
      case PdfAnnotAppearance.rollover:
        n = '/R';
        break;
      case PdfAnnotAppearance.down:
        n = '/D';
        break;
    }
    if (name == null) {
      _appearances[n] = s.ref();
    } else {
      if (_appearances[n] is! PdfDict) {
        _appearances[n] = PdfDict();
      }
      final d = _appearances[n];
      if (d is PdfDict) {
        d[name] = s.ref();
      }
    }

    if (matrix != null) {
      s.params['/Matrix'] = PdfArray.fromNum([
        matrix[0],
        matrix[1],
        matrix[4],
        matrix[5],
        matrix[12],
        matrix[13],
      ]);
    }

    final bBox = boundingBox ?? PdfRect.fromPoints(PdfPoint.zero, rect.size);
    s.params['/BBox'] = PdfArray.fromRect(bBox);
    final g = PdfGraphics(s, s.buf);

    if (selected && name != null) {
      _as = PdfName(name);
    }
    return g;
  }

  @protected
  @mustCallSuper
  void build(PdfPage page, PdfObject object, PdfDict params) {
    params['/Subtype'] = PdfName(subtype);
    params['/Rect'] = PdfArray.fromRect(rect);

    params['/P'] = page.ref();

    // handle the border
    if (border == null) {
      params['/Border'] = PdfArray.fromNum(const [0, 0, 0]);
    } else {
      params['/BS'] = border!.ref();
    }

    if (content != null) {
      params['/Contents'] = PdfString.fromString(content!);
    }

    if (name != null) {
      params['/NM'] = PdfString.fromString(name!);
    }

    if (flags.isNotEmpty) {
      params['/F'] = PdfNum(flagValue);
    }

    if (date != null) {
      params['/M'] = PdfString.fromDate(date!);
    }

    if (color != null) {
      params['/C'] = PdfArray.fromColor(color!);
    }

    if (subject != null) {
      params['/Subj'] = PdfString.fromString(subject!);
    }

    // /T is only defined for a markup annotation - ISO 32000-1 12.5.6.4 - and on
    // a merged field-and-widget dictionary it is the partial field name instead.
    // Writing the author there made a widget given an author and no fieldName a
    // form field named after the author, so an FDF export carried
    // 'Jane Doe=hello'; with both set, the author silently won or lost depending
    // on the order.
    if (author != null && isMarkup) {
      params['/T'] = PdfString.fromString(author!);
    }

    if (_appearances.isNotEmpty) {
      params['/AP'] = PdfDict.values(_appearances);
      if (_as != null) {
        params['/AS'] = _as!;
      }
    }
  }
}

class PdfAnnotText extends PdfAnnotBase {
  /// Create a text annotation
  PdfAnnotText({
    required PdfRect rect,
    required String content,
    PdfBorder? border,
    String? name,
    Set<PdfAnnotFlags>? flags,
    DateTime? date,
    PdfColor? color,
    String? subject,
    String? author,
  }) : super(
         subtype: '/Text',
         rect: rect,
         border: border,
         content: content,
         name: name,
         flags: flags,
         date: date,
         color: color,
         subject: subject,
         author: author,
       );
}

class PdfAnnotNamedLink extends PdfAnnotBase {
  /// Create a named link annotation
  PdfAnnotNamedLink({
    required PdfRect rect,
    required this.dest,
    PdfBorder? border,
    Set<PdfAnnotFlags>? flags,
    DateTime? date,
    PdfColor? color,
    String? subject,
    String? author,
  }) : super(
         subtype: '/Link',
         rect: rect,
         border: border,
         flags: flags,
         date: date,
         color: color,
         subject: subject,
         author: author,
       );

  final String dest;

  /// A link is not a markup annotation either.
  @override
  bool get isMarkup => false;

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);
    params['/A'] = PdfDict.values({
      '/S': const PdfName('/GoTo'),
      '/D': PdfString.fromString(dest),
    });
  }
}

class PdfAnnotUrlLink extends PdfAnnotBase {
  /// Create an url link annotation
  PdfAnnotUrlLink({
    required PdfRect rect,
    required this.url,
    PdfBorder? border,
    Set<PdfAnnotFlags>? flags,
    DateTime? date,
    PdfColor? color,
    String? subject,
    String? author,
  }) : super(
         subtype: '/Link',
         rect: rect,
         border: border,
         flags: flags,
         date: date,
         color: color,
         subject: subject,
         author: author,
       );

  final String url;

  /// A link is not a markup annotation either.
  @override
  bool get isMarkup => false;

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);
    params['/A'] = PdfDict.values({
      '/S': const PdfName('/URI'),
      '/URI': PdfString.fromString(url),
    });
  }
}

class PdfAnnotSquare extends PdfAnnotBase {
  /// Create an Square annotation
  PdfAnnotSquare({
    required PdfRect rect,
    PdfBorder? border,
    Set<PdfAnnotFlags>? flags,
    DateTime? date,
    PdfColor? color,
    this.interiorColor,
    String? subject,
    String? author,
  }) : super(
         subtype: '/Square',
         rect: rect,
         border: border,
         flags: flags,
         date: date,
         color: color,
         subject: subject,
         author: author,
       );

  final PdfColor? interiorColor;

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);
    if (interiorColor != null) {
      params['/IC'] = PdfArray.fromColor(interiorColor!);
    }
  }
}

class PdfAnnotCircle extends PdfAnnotBase {
  /// Create an Circle annotation
  PdfAnnotCircle({
    required PdfRect rect,
    PdfBorder? border,
    Set<PdfAnnotFlags>? flags,
    DateTime? date,
    PdfColor? color,
    this.interiorColor,
    String? subject,
    String? author,
  }) : super(
         subtype: '/Circle',
         rect: rect,
         border: border,
         flags: flags,
         date: date,
         color: color,
         subject: subject,
         author: author,
       );

  final PdfColor? interiorColor;

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);
    if (interiorColor != null) {
      params['/IC'] = PdfArray.fromColor(interiorColor!);
    }
  }
}

class PdfAnnotPolygon extends PdfAnnotBase {
  /// Create an Polygon annotation
  PdfAnnotPolygon(
    this.document,
    this.points, {
    required PdfRect rect,
    PdfBorder? border,
    Set<PdfAnnotFlags>? flags,
    DateTime? date,
    PdfColor? color,
    this.interiorColor,
    String? subject,
    String? author,
    this.closed = true,
  }) : super(
         // ISO 32000-1 12.5.6.9: a closed polygon is /Polygon and an open run of
         // segments is /PolyLine. These two names were the wrong way round, so
         // both widgets emitted /PolyLine - a polygon was drawn open, missing its
         // last edge, and never filled, which made interiorColor inert.
         subtype: closed ? '/Polygon' : '/PolyLine',
         rect: rect,
         border: border,
         flags: flags,
         date: date,
         color: color,
         subject: subject,
         author: author,
       );

  final PdfDocument document;

  final List<PdfPoint> points;

  final PdfColor? interiorColor;

  /// Whether the last point joins back to the first.
  final bool closed;

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);

    // [points] are in default user space, as /Vertices has to be. This used to
    // flip them against rect.height - on points the widget layer had already put
    // in page space - which sent every vertex to about -pageY, below the
    // MediaBox, where the annotation is dead even though the page still paints.
    final vertices = <num>[];
    for (final point in points) {
      vertices
        ..add(point.x)
        ..add(point.y);
    }

    params['/Vertices'] = PdfArray.fromNum(vertices);

    if (interiorColor != null) {
      params['/IC'] = PdfArray.fromColor(interiorColor!);
    }
  }
}

class PdfAnnotInk extends PdfAnnotBase {
  /// Create an Ink List annotation
  PdfAnnotInk(
    this.document,
    this.points, {
    required PdfRect rect,
    PdfBorder? border,
    Set<PdfAnnotFlags>? flags,
    DateTime? date,
    PdfColor? color,
    String? subject,
    String? author,
    String? content,
  }) : super(
         subtype: '/Ink',
         rect: rect,
         border: border,
         flags: flags,
         date: date,
         color: color,
         subject: subject,
         author: author,
         content: content,
       );

  final PdfDocument document;

  final List<List<PdfPoint>> points;

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);

    // One array per stroke. List.filled puts the *same* growable list in every
    // slot, so every stroke was appended to one shared list and /InkList came out
    // as N references to all the points at once: a captured signature was drawn
    // N times with spurious lines joining the strokes. With a single stroke it
    // was invisible.
    //
    // The points are in default user space, as /InkList has to be; they used to
    // be flipped here as well, see /Vertices above.
    params['/InkList'] = PdfArray(<PdfDataType>[
      for (final stroke in points)
        PdfArray.fromNum(<num>[
          for (final point in stroke) ...<num>[point.x, point.y],
        ]),
    ]);
  }
}

enum PdfAnnotHighlighting { none, invert, outline, push, toggle }

abstract class PdfAnnotWidget extends PdfAnnotBase {
  /// Create a widget annotation
  PdfAnnotWidget({
    required PdfRect rect,
    required this.fieldType,
    this.fieldName,
    PdfBorder? border,
    Set<PdfAnnotFlags>? flags,
    DateTime? date,
    PdfColor? color,
    this.backgroundColor,
    this.highlighting,
    String? subject,
    @Deprecated(
      'A widget annotation has no author: /T is its field name. '
      'Use fieldName instead.',
    )
    String? author,
  }) : super(
         subtype: '/Widget',
         rect: rect,
         border: border,
         flags: flags,
         date: date,
         color: color,
         subject: subject,
         author: author,
       );

  final String fieldType;

  final String? fieldName;

  /// The form field this widget displays, when several widgets share one.
  ///
  /// Set by [PdfDocument.prepareAcroForm] before anything is written. When it is
  /// null this widget is a field in its own right, which is the merged form
  /// ISO 32000-1 12.7.3.1 allows for a single-widget field, and what this
  /// package has always produced.
  PdfAcroFormField? fieldParent;

  /// Where the field keys go: the parent when there is one, this widget's own
  /// dictionary otherwise.
  PdfDict fieldParams(PdfDict params) => fieldParent?.params ?? params;

  /// A widget is not a markup annotation: its `/T` is the field name.
  @override
  bool get isMarkup => false;

  final PdfAnnotHighlighting? highlighting;

  final PdfColor? backgroundColor;

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);

    final field = fieldParams(params);
    field['/FT'] = PdfName(fieldType);

    if (fieldParent != null) {
      // The kid keeps /Rect, /AP, /AS and /P, and names its field.
      params['/Parent'] = fieldParent!.ref();
    } else if (fieldName != null) {
      params['/T'] = PdfString.fromString(fieldName!);
    }

    final mk = PdfDict();
    if (color != null) {
      mk.values['/BC'] = PdfArray.fromColor(color!);
    }

    if (backgroundColor != null) {
      mk.values['/BG'] = PdfArray.fromColor(backgroundColor!);
    }

    if (mk.values.isNotEmpty) {
      params['/MK'] = mk;
    }

    if (highlighting != null) {
      switch (highlighting!) {
        case PdfAnnotHighlighting.none:
          params['/H'] = const PdfName('/N');
          break;
        case PdfAnnotHighlighting.invert:
          params['/H'] = const PdfName('/I');
          break;
        case PdfAnnotHighlighting.outline:
          params['/H'] = const PdfName('/O');
          break;
        case PdfAnnotHighlighting.push:
          params['/H'] = const PdfName('/P');
          break;
        case PdfAnnotHighlighting.toggle:
          params['/H'] = const PdfName('/T');
          break;
      }
    }
  }
}

class PdfAnnotSign extends PdfAnnotWidget {
  PdfAnnotSign({
    required PdfRect rect,
    String? fieldName,
    PdfBorder? border,
    Set<PdfAnnotFlags>? flags,
    DateTime? date,
    PdfColor? color,
    PdfAnnotHighlighting? highlighting,
  }) : super(
         rect: rect,
         fieldType: '/Sig',
         fieldName: fieldName,
         border: border,
         flags: flags,
         date: date,
         color: color,
         highlighting: highlighting,
       );

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);
    if (page.pdfDocument.sign != null) {
      params['/V'] = page.pdfDocument.sign!.ref();
    }
  }
}

enum PdfFieldFlags {
  /// 1 - If set, the user may not change the value of the field.
  readOnly,

  /// 2 - If set, the field shall have a value at the time it is exported by
  /// a submit-form action.
  mandatory,

  /// 3 - If set, the field shall not be exported by a submit-form action.
  noExport,

  /// 4
  reserved4,

  /// 5
  reserved5,

  /// 6
  reserved6,

  /// 7
  reserved7,

  /// 8
  reserved8,

  /// 9
  reserved9,

  /// 10
  reserved10,

  /// 11
  reserved11,

  /// 12
  reserved12,

  /// 13 - If set, the field may contain multiple lines of text; if clear,
  /// the field’s text shall be restricted to a single line.
  multiline,

  /// 14 - If set, the field is intended for entering a secure password that
  /// should not be echoed visibly to the screen. Characters typed from
  /// the keyboard shall instead be echoed in some unreadable form, such
  /// as asterisks or bullet characters.
  password,

  /// 15 - If set, exactly one radio button shall be selected at all times.
  noToggleToOff,

  /// 16 - If set, the field is a set of radio buttons; if clear,
  /// the field is a check box.
  radio,

  /// 17 - If set, the field is a pushbutton that does not retain
  /// a permanent value.
  pushButton,

  /// 18 - If set, the field is a combo box; if clear, the field is a list box.
  combo,

  /// 19 - If set, the combo box shall include an editable text box as well
  /// as a drop-down list
  edit,

  /// 20 - If set, the field’s option items shall be sorted alphabetically.
  sort,

  /// 21 - If set, the text entered in the field represents the pathname
  /// of a file whose contents shall be submitted as the value of the field.
  fileSelect,

  /// 22 - If set, more than one of the field’s option items may be selected
  /// simultaneously
  multiSelect,

  /// 23 - If set, text entered in the field shall not be spell-checked.
  doNotSpellCheck,

  /// 24 - If set, the field shall not scroll to accommodate more text
  /// than fits within its annotation rectangle.
  doNotScroll,

  /// 25 - If set, the field shall be automatically divided into as many
  /// equally spaced positions, or combs, as the value of MaxLen,
  /// and the text is laid out into those combs.
  comb,

  /// 26 - If set, a group of radio buttons within a radio button field
  /// that use the same value for the on state will turn on and off in unison.
  radiosInUnison,

  /// 27 - If set, the new value shall be committed as soon as a selection
  /// is made.
  commitOnSelChange,
}

class PdfFormField extends PdfAnnotWidget {
  PdfFormField({
    required String fieldType,
    required PdfRect rect,
    String? fieldName,
    this.alternateName,
    this.mappingName,
    PdfBorder? border,
    Set<PdfAnnotFlags>? flags,
    DateTime? date,
    String? subject,
    @Deprecated(
      'A widget annotation has no author: /T is its field name. '
      'Use fieldName instead.',
    )
    String? author,
    PdfColor? color,
    PdfColor? backgroundColor,
    PdfAnnotHighlighting? highlighting,
    this.fieldFlags,
  }) : super(
         rect: rect,
         fieldType: fieldType,
         fieldName: fieldName,
         border: border,
         flags: flags,
         date: date,
         subject: subject,
         author: author,
         backgroundColor: backgroundColor,
         color: color,
         highlighting: highlighting,
       );

  final String? alternateName;

  final String? mappingName;

  final Set<PdfFieldFlags>? fieldFlags;

  int get fieldFlagsValue {
    if (fieldFlags == null || fieldFlags!.isEmpty) {
      return 0;
    }

    return fieldFlags!
        .map<int>((PdfFieldFlags e) => 1 << e.index)
        .reduce((int a, int b) => a | b);
  }

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);

    final field = fieldParams(params);
    if (alternateName != null) {
      field['/TU'] = PdfString.fromString(alternateName!);
    }
    if (mappingName != null) {
      field['/TM'] = PdfString.fromString(mappingName!);
    }

    field['/Ff'] = PdfNum(fieldFlagsValue);
  }
}

enum PdfTextFieldAlign { left, center, right }

class PdfTextField extends PdfFormField {
  PdfTextField({
    required PdfRect rect,
    String? fieldName,
    String? alternateName,
    String? mappingName,
    PdfBorder? border,
    Set<PdfAnnotFlags>? flags,
    DateTime? date,
    String? subject,
    @Deprecated(
      'A widget annotation has no author: /T is its field name. '
      'Use fieldName instead.',
    )
    String? author,
    PdfColor? color,
    PdfColor? backgroundColor,
    PdfAnnotHighlighting? highlighting,
    Set<PdfFieldFlags>? fieldFlags,
    this.value,
    this.defaultValue,
    this.maxLength,
    required this.font,
    required this.fontSize,
    required this.textColor,
    this.textAlign,
  }) : super(
         rect: rect,
         fieldType: '/Tx',
         fieldName: fieldName,
         border: border,
         flags: flags,
         date: date,
         subject: subject,
         author: author,
         color: color,
         backgroundColor: backgroundColor,
         highlighting: highlighting,
         alternateName: alternateName,
         mappingName: mappingName,
         fieldFlags: fieldFlags,
       );

  final int? maxLength;

  final String? value;

  final String? defaultValue;

  final PdfFont font;

  final double fontSize;

  final PdfColor textColor;

  final PdfTextFieldAlign? textAlign;

  @override
  Iterable<PdfFont> get defaultAppearanceFonts => <PdfFont>[font];

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);
    final field = fieldParams(params);
    if (maxLength != null) {
      field['/MaxLen'] = PdfNum(maxLength!);
    }

    final buf = PdfStream();
    final g = PdfGraphics(page, buf);
    g.setFillColor(textColor);
    g.setFont(font, fontSize);
    field['/DA'] = PdfString.fromStream(buf);

    if (value != null) {
      field['/V'] = PdfString.fromString(value!);
    }
    if (defaultValue != null) {
      field['/DV'] = PdfString.fromString(defaultValue!);
    }
    if (textAlign != null) {
      field['/Q'] = PdfNum(textAlign!.index);
    }
  }
}

class PdfButtonField extends PdfFormField {
  PdfButtonField({
    required PdfRect rect,
    required String fieldName,
    String? alternateName,
    String? mappingName,
    PdfBorder? border,
    Set<PdfAnnotFlags>? flags,
    DateTime? date,
    PdfColor? color,
    PdfColor? backgroundColor,
    PdfAnnotHighlighting? highlighting,
    Set<PdfFieldFlags>? fieldFlags,
    this.value,
    this.defaultValue,
  }) : super(
         rect: rect,
         fieldType: '/Btn',
         fieldName: fieldName,
         border: border,
         flags: flags,
         date: date,
         color: color,
         backgroundColor: backgroundColor,
         highlighting: highlighting,
         alternateName: alternateName,
         mappingName: mappingName,
         fieldFlags: fieldFlags,
       );

  final String? value;

  final String? defaultValue;

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);

    final field = fieldParams(params);
    if (value != null) {
      field['/V'] = PdfName(value!);
    }

    if (defaultValue != null) {
      field['/DV'] = PdfName(defaultValue!);
    }
  }
}

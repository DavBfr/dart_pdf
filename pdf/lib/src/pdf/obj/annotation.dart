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
  }) : super(
          rect: rect,
          fieldType: '/Ch',
          fieldName: fieldName,
        );

  final List<String> items;
  final PdfColor textColor;
  final String? value;
  final String? defaultValue;
  final Set<PdfFieldFlags>? fieldFlags = {
    PdfFieldFlags.combo,
  };
  final PdfFont font;

  final double fontSize;
  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);
    // What is /F?
    //params['/F'] = const PdfNum(4);
    params['/Ff'] = PdfNum(fieldFlagsValue);
    params['/Opt'] =
        PdfArray<PdfString>(items.map((e) => PdfString.fromString(e)).toList());

    if (defaultValue != null) {
      params['/DV'] = PdfString.fromString(defaultValue!);
    }

    if (value != null) {
      params['/V'] = PdfString.fromString(value!);
    } else {
      params['/V'] = const PdfNull();
    }

    final buf = PdfStreamBuffer();
    final g = PdfGraphics(page, buf);
    g.setFillColor(textColor);
    g.setFont(font, fontSize);

    params['/DA'] = PdfString.fromStream(buf);

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
      : super(pdfPage.pdfDocument,
            objser: objser,
            objgen: objgen,
            params: PdfDict.values({
              '/Type': const PdfName('/Annot'),
            })) {
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

enum PdfAnnotAppearance {
  normal,
  rollover,
  down,
}

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
    this.flags = flags ??
        {
          PdfAnnotFlags.print,
        };
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
      s.params['/Matrix'] = PdfArray.fromNum(
          [matrix[0], matrix[1], matrix[4], matrix[5], matrix[12], matrix[13]]);
    }

    final bBox = boundingBox ?? PdfRect.fromPoints(PdfPoint.zero, rect.size);
    s.params['/BBox'] =
        PdfArray.fromNum([bBox.x, bBox.y, bBox.width, bBox.height]);
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
    params['/Rect'] =
        PdfArray.fromNum([rect.left, rect.bottom, rect.right, rect.top]);

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

    if (author != null) {
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

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);
    params['/A'] = PdfDict.values(
      {
        '/S': const PdfName('/GoTo'),
        '/D': PdfString.fromString(dest),
      },
    );
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

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);
    params['/A'] = PdfDict.values(
      {
        '/S': const PdfName('/URI'),
        '/URI': PdfString.fromString(url),
      },
    );
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
  PdfAnnotPolygon(this.document, this.points,
      {required PdfRect rect,
      PdfBorder? border,
      Set<PdfAnnotFlags>? flags,
      DateTime? date,
      PdfColor? color,
      this.interiorColor,
      String? subject,
      String? author,
      bool closed = true})
      : super(
          subtype: closed ? '/PolyLine' : '/Polygon',
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

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);

    // Flip the points on the Y axis.
    final flippedPoints =
        points.map((e) => PdfPoint(e.x, rect.height - e.y)).toList();

    final vertices = <num>[];
    for (var i = 0; i < flippedPoints.length; i++) {
      vertices.add(flippedPoints[i].x);
      vertices.add(flippedPoints[i].y);
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
  void build(
    PdfPage page,
    PdfObject object,
    PdfDict params,
  ) {
    super.build(page, object, params);

    final vertices = List<List<num>>.filled(points.length, <num>[]);
    for (var listIndex = 0; listIndex < points.length; listIndex++) {
      // Flip the points on the Y axis.
      final flippedPoints = points[listIndex]
          .map((e) => PdfPoint(e.x, rect.height - e.y))
          .toList();
      for (var i = 0; i < flippedPoints.length; i++) {
        vertices[listIndex].add(flippedPoints[i].x);
        vertices[listIndex].add(flippedPoints[i].y);
      }
    }

    params['/InkList'] =
        PdfArray(vertices.map((v) => PdfArray.fromNum(v)).toList());
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

  final PdfAnnotHighlighting? highlighting;

  final PdfColor? backgroundColor;

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);

    params['/FT'] = PdfName(fieldType);

    if (fieldName != null) {
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
    if (alternateName != null) {
      params['/TU'] = PdfString.fromString(alternateName!);
    }
    if (mappingName != null) {
      params['/TM'] = PdfString.fromString(mappingName!);
    }

    params['/Ff'] = PdfNum(fieldFlagsValue);
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
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);
    if (maxLength != null) {
      params['/MaxLen'] = PdfNum(maxLength!);
    }

    final buf = PdfStreamBuffer();
    final g = PdfGraphics(page, buf);
    g.setFillColor(textColor);
    g.setFont(font, fontSize);
    params['/DA'] = PdfString.fromStream(buf);

    if (value != null) {
      params['/V'] = PdfString.fromString(value!);
    }
    if (defaultValue != null) {
      params['/DV'] = PdfString.fromString(defaultValue!);
    }
    if (textAlign != null) {
      params['/Q'] = PdfNum(textAlign!.index);
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

    if (value != null) {
      params['/V'] = PdfName(value!);
    }

    if (defaultValue != null) {
      params['/DV'] = PdfName(defaultValue!);
    }
  }
}

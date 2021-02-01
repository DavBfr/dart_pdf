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

import 'border.dart';
import 'color.dart';
import 'data_types.dart';
import 'document.dart';
import 'font.dart';
import 'graphic_stream.dart';
import 'graphics.dart';
import 'object.dart';
import 'page.dart';
import 'point.dart';
import 'rect.dart';
import 'stream.dart';

class PdfAnnot extends PdfObject {
  PdfAnnot(this.pdfPage, this.annot)
      : super(pdfPage.pdfDocument, type: '/Annot') {
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

enum PdfAnnotApparence {
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
    this.flags,
    this.date,
    this.color,
  });

  /// The subtype of the outline, ie text, note, etc
  final String subtype;

  final PdfRect rect;

  /// the border for this annotation
  final PdfBorder? border;

  /// The text of a text annotation
  final String? content;

  /// The internal name for a link
  final String? name;

  /// Flags specifying various characteristics of the annotation
  final Set<PdfAnnotFlags>? flags;

  /// Last modification date
  final DateTime? date;

  /// Color
  final PdfColor? color;

  final Map<String?, PdfDataType> _appearances = <String?, PdfDataType>{};

  int get flagValue {
    if (flags == null || flags!.isEmpty) {
      return 0;
    }

    return flags!
        .map<int>((PdfAnnotFlags e) => 1 << e.index)
        .reduce((int a, int b) => a | b);
  }

  PdfGraphics appearance(
    PdfDocument pdfDocument,
    PdfAnnotApparence type, {
    String? name,
    Matrix4? matrix,
    PdfRect? boundingBox,
  }) {
    final s = PdfGraphicXObject(pdfDocument, '/Form');
    String? n;
    switch (type) {
      case PdfAnnotApparence.normal:
        n = '/N';
        break;
      case PdfAnnotApparence.rollover:
        n = '/R';
        break;
      case PdfAnnotApparence.down:
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
      s.params['/Matrix'] = PdfArray.fromNum(<double>[
        matrix[0],
        matrix[1],
        matrix[4],
        matrix[5],
        matrix[12],
        matrix[13]
      ]);
    }

    final bbox = boundingBox ?? PdfRect.fromPoints(PdfPoint.zero, rect.size);
    s.params['/BBox'] =
        PdfArray.fromNum(<double?>[bbox.x, bbox.y, bbox.width, bbox.height]);
    final g = PdfGraphics(s, s.buf);
    return g;
  }

  @protected
  @mustCallSuper
  void build(PdfPage page, PdfObject object, PdfDict params) {
    params['/Subtype'] = PdfName(subtype);
    params['/Rect'] = PdfArray.fromNum(
        <double?>[rect.left, rect.bottom, rect.right, rect.top]);

    params['/P'] = page.ref();

    // handle the border
    if (border == null) {
      params['/Border'] = PdfArray.fromNum(const <int>[0, 0, 0]);
    } else {
      params['/BS'] = border!.ref();
    }

    if (content != null) {
      params['/Contents'] = PdfSecString.fromString(object, content!);
    }

    if (name != null) {
      params['/NM'] = PdfSecString.fromString(object, name!);
    }

    if (flags != null && flags!.isNotEmpty) {
      params['/F'] = PdfNum(flagValue);
    }

    if (date != null) {
      params['/M'] = PdfSecString.fromDate(object, date!);
    }

    if (color != null) {
      params['/C'] = PdfColorType(color!);
    }

    if (_appearances.isNotEmpty) {
      params['/AP'] = PdfDict(_appearances);
      if (_appearances['/N'] is PdfDict) {
        final n = _appearances['/N'];
        if (n is PdfDict) {
          params['/AS'] = PdfName(n.values.keys.first!);
        }
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
  PdfAnnotNamedLink({
    required PdfRect rect,
    required this.dest,
    PdfBorder? border,
    Set<PdfAnnotFlags>? flags,
    DateTime? date,
    PdfColor? color,
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
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);
    params['/A'] = PdfDict(
      <String, PdfDataType>{
        '/S': const PdfName('/GoTo'),
        '/D': PdfSecString.fromString(object, dest),
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
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);
    params['/A'] = PdfDict(
      <String, PdfDataType>{
        '/S': const PdfName('/URI'),
        '/URI': PdfSecString.fromString(object, url),
      },
    );
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
  }) : super(
          subtype: '/Widget',
          rect: rect,
          border: border,
          flags: flags,
          date: date,
          color: color,
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
      params['/T'] = PdfSecString.fromString(object, fieldName!);
    }

    final mk = PdfDict();
    if (color != null) {
      mk.values['/BC'] = PdfColorType(color!);
    }

    if (backgroundColor != null) {
      mk.values['/BG'] = PdfColorType(backgroundColor!);
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
    assert(page.pdfDocument.sign != null);
    params['/V'] = page.pdfDocument.sign!.ref();
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
      params['/TU'] = PdfSecString.fromString(object, alternateName!);
    }
    if (mappingName != null) {
      params['/TM'] = PdfSecString.fromString(object, mappingName!);
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

    final buf = PdfStream();
    final g = PdfGraphics(page, buf);
    g.setFillColor(textColor);
    g.setFont(font, fontSize);
    params['/DA'] = PdfSecString.fromStream(object, buf);

    if (value != null) {
      params['/V'] = PdfSecString.fromString(object, value!);
    }
    if (defaultValue != null) {
      params['/DV'] = PdfSecString.fromString(object, defaultValue!);
    }
    if (textAlign != null) {
      params['/Q'] = PdfNum(textAlign!.index);
    }
  }
}

class PdfButtonField extends PdfFormField {
  PdfButtonField({
    required PdfRect rect,
    String? fieldName,
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

  final bool? value;

  final bool? defaultValue;

  @override
  void build(PdfPage page, PdfObject object, PdfDict params) {
    super.build(page, object, params);

    if (value != null) {
      params['/V'] = value! ? const PdfName('/Yes') : const PdfName('/Off');
    }
    if (defaultValue != null) {
      params['/DV'] =
          defaultValue! ? const PdfName('/Yes') : const PdfName('/Off');
    }
  }
}

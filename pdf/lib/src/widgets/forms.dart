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
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../../pdf.dart';
import 'basic.dart';
import 'border_radius.dart';
import 'box_border.dart';
import 'container.dart';
import 'decoration.dart';
import 'geometry.dart';
import 'text.dart';
import 'text_style.dart';
import 'theme.dart';
import 'widget.dart';

mixin AnnotationAppearance on Widget {
  void drawAppearance(
    Context context,
    PdfAnnotBase bf,
    Matrix4 mat,
    Widget child, {
    PdfAnnotAppearance type = PdfAnnotAppearance.normal,
    PdfName? tag,
    String? name,
    bool selected = false,
  }) {
    final canvas = bf.appearance(
      context.document,
      type,
      matrix: mat,
      boundingBox: PdfRect(0, 0, box!.width, box!.height),
      name: name,
      selected: selected,
    );

    if (tag != null) {
      canvas.markContentBegin(tag);
    }

    Widget.draw(
      child,
      offset: PdfPoint.zero,
      canvas: canvas,
      page: context.page,
      constraints:
          BoxConstraints.tightFor(width: box!.width, height: box!.height),
    );

    if (tag != null) {
      canvas.markContentEnd();
    }
  }

  Matrix4 getAppearanceMatrix(Context context) {
    final translation = Vector3(0, 0, 0);
    final rotation = Quaternion(0, 0, 0, 0);
    final scale = Vector3(0, 0, 0);

    return context.canvas.getTransform()
      ..decompose(translation, rotation, scale)
      ..leftTranslate(-translation.x, -translation.y)
      ..translate(box!.x, box!.y);
  }
}

class ChoiceField extends StatelessWidget with AnnotationAppearance {
  ChoiceField({
    this.width = 120,
    this.height = 13,
    this.textStyle,
    required this.name,
    required this.items,
    this.value,
  });
  final String name;
  final TextStyle? textStyle;
  final double width;
  final double height;
  final List<String> items;
  final String? value;

  @override
  void paint(Context context) {
    super.paint(context);
    final _textStyle = Theme.of(context).defaultTextStyle.merge(textStyle);
    final pdfRect = context.localToGlobal(box!);

    final bf = PdfChoiceField(
      textColor: _textStyle.color!,
      fieldName: name,
      value: value,
      font: _textStyle.font!.getFont(context),
      fontSize: _textStyle.fontSize!,
      items: items,
      rect: pdfRect,
    );

    if (value != null) {
      final mat = getAppearanceMatrix(context);

      drawAppearance(
        context,
        bf,
        mat,
        Text(value!, style: _textStyle),
        tag: const PdfName('/Tx'),
      );
    }

    PdfAnnot(context.page, bf);
  }

  @override
  Widget build(Context context) {
    return SizedBox(width: width, height: height);
  }
}

class Checkbox extends SingleChildWidget with AnnotationAppearance {
  Checkbox({
    required this.value,
    this.tristate = false,
    this.activeColor = PdfColors.blue,
    this.checkColor = PdfColors.white,
    required this.name,
    double width = 13,
    double height = 13,
    BoxDecoration? decoration,
  })  : radius = decoration?.shape == BoxShape.circle
            ? Radius.circular(math.max(height, width) / 2)
            : decoration?.borderRadius?.topLeft ?? Radius.zero,
        super(
            child: Container(
                width: width,
                height: height,
                margin: const EdgeInsets.all(1),
                decoration: decoration ??
                    BoxDecoration(
                        border: Border.all(
                      color: PdfColors.grey600,
                      width: 2,
                    ))));

  final bool value;

  final bool tristate;

  final PdfColor activeColor;

  final PdfColor checkColor;

  final String name;

  final Radius radius;

  @override
  void paint(Context context) {
    super.paint(context);

    final bf = PdfButtonField(
      rect: context.localToGlobal(box!),
      fieldName: name,
      value: value ? '/Yes' : null,
      defaultValue: value ? '/Yes' : null,
      flags: <PdfAnnotFlags>{PdfAnnotFlags.print},
    );

    final mat = getAppearanceMatrix(context);

    drawAppearance(
      context,
      bf,
      mat,
      name: '/Yes',
      selected: value,
      CustomPaint(
        size: bf.rect.size,
        painter: (canvas, size) {
          canvas.drawRRect(
              0, 0, bf.rect.width, bf.rect.height, radius.y, radius.x);
          canvas.setFillColor(activeColor);
          canvas.fillPath();
          canvas.moveTo(2, bf.rect.height / 2);
          canvas.lineTo(bf.rect.width / 3, bf.rect.height / 4);
          canvas.lineTo(bf.rect.width - 2, bf.rect.height / 4 * 3);
          canvas.setStrokeColor(checkColor);
          canvas.setLineWidth(2);
          canvas.strokePath();
        },
      ),
    );

    drawAppearance(
      context,
      bf,
      mat,
      name: '/Off',
      selected: !value,
      child!,
    );

    PdfAnnot(context.page, bf);
  }
}

class FlatButton extends SingleChildWidget with AnnotationAppearance {
  FlatButton({
    PdfColor textColor = PdfColors.white,
    PdfColor color = PdfColors.blue,
    PdfColor colorDown = PdfColors.red,
    PdfColor colorRollover = PdfColors.blueAccent,
    EdgeInsets? padding,
    BoxDecoration? decoration,
    this.flags,
    required Widget child,
    required this.name,
  })  : _childDown = Container(
          child: DefaultTextStyle(
            style: TextStyle(color: textColor),
            child: child,
          ),
          decoration: decoration ??
              BoxDecoration(
                color: colorDown,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        ),
        _childRollover = Container(
          child: DefaultTextStyle(
            style: TextStyle(color: textColor),
            child: child,
          ),
          decoration: decoration ??
              BoxDecoration(
                color: colorRollover,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        ),
        super(
          child: Container(
            child: DefaultTextStyle(
              style: TextStyle(color: textColor),
              child: child,
            ),
            decoration: decoration ??
                BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          ),
        );

  final String name;

  final Widget _childDown;

  final Widget _childRollover;

  final Set<PdfAnnotFlags>? flags;

  @override
  void paint(Context context) {
    super.paint(context);

    final bf = PdfButtonField(
      rect: context.localToGlobal(box!),
      fieldName: name,
      flags: flags,
      fieldFlags: <PdfFieldFlags>{PdfFieldFlags.pushButton},
    );

    final mat = getAppearanceMatrix(context);

    drawAppearance(context, bf, mat, child!);
    drawAppearance(context, bf, mat, _childDown, type: PdfAnnotAppearance.down);
    drawAppearance(context, bf, mat, _childRollover,
        type: PdfAnnotAppearance.rollover);

    PdfAnnot(context.page, bf);
  }
}

class TextField extends StatelessWidget with AnnotationAppearance {
  TextField({
    this.child,
    this.width = 120,
    this.height = 13,
    required this.name,
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

  final Widget? child;
  final double width;
  final double height;
  final String name;
  final PdfBorder? border;
  final Set<PdfAnnotFlags>? flags;
  final DateTime? date;
  final PdfColor? color;
  final PdfColor? backgroundColor;
  final PdfAnnotHighlighting? highlighting;
  final int? maxLength;
  final String? alternateName;
  final String? mappingName;
  final Set<PdfFieldFlags>? fieldFlags;
  final String? value;
  final String? defaultValue;
  final TextStyle? textStyle;

  @override
  Widget build(Context context) {
    return child ?? SizedBox(width: width, height: height);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final _textStyle = Theme.of(context).defaultTextStyle.merge(textStyle);

    final tf = PdfTextField(
      rect: context.localToGlobal(box!),
      fieldName: name,
      border: border,
      flags: flags ?? const {PdfAnnotFlags.print},
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
      font: _textStyle.font!.getFont(context),
      fontSize: _textStyle.fontSize!,
      textColor: _textStyle.color!,
    );

    if (value != null) {
      final mat = getAppearanceMatrix(context);

      drawAppearance(
        context,
        tf,
        mat,
        Text(value!, style: _textStyle),
        tag: const PdfName('/Tx'),
      );
    }

    PdfAnnot(context.page, tf);
  }
}

class Signature extends SingleChildWidget with AnnotationAppearance {
  Signature({
    Widget? child,
    @Deprecated('Use value instead') PdfSignatureBase? crypto,
    PdfSignatureBase? value,
    required this.name,
    this.appendOnly = false,
    this.border,
    this.flags,
    this.date,
    this.color,
    this.highlighting,
    this.crl,
    this.cert,
    this.ocsp,
  })  : value = value ?? crypto,
        super(child: child);

  /// Field name
  final String name;

  /// Digital signature
  final PdfSignatureBase? value;

  /// Append
  final bool appendOnly;

  final PdfBorder? border;

  /// Flags for this field
  final Set<PdfAnnotFlags>? flags;

  /// Date metadata
  final DateTime? date;

  /// Field color
  final PdfColor? color;

  /// Field highlighting
  final PdfAnnotHighlighting? highlighting;

  /// Certificate revocation lists
  final List<Uint8List>? crl;

  /// Additional X509 certificates
  final List<Uint8List>? cert;

  /// Online Certificate Status Protocol
  final List<Uint8List>? ocsp;

  @override
  void paint(Context context) {
    super.paint(context);

    if (value != null) {
      context.document.sign ??= PdfSignature(
        context.document,
        value: value!,
        flags: {
          PdfSigFlags.signaturesExist,
          if (appendOnly) PdfSigFlags.appendOnly,
        },
        crl: crl,
        cert: cert,
        ocsp: ocsp,
      );
    } else {
      paintChild(context);
    }

    final bf = PdfAnnotSign(
      rect: context.localToGlobal(box!),
      fieldName: name,
      border: border,
      flags: flags,
      date: date,
      color: color,
      highlighting: highlighting,
    );

    if (child != null && value != null) {
      final mat = getAppearanceMatrix(context);
      drawAppearance(context, bf, mat, child!);
    }

    PdfAnnot(context.page, bf);
  }
}

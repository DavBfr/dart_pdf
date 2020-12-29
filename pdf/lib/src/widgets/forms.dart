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
import 'package:pdf/pdf.dart';
import 'package:vector_math/vector_math_64.dart';

import 'border_radius.dart';
import 'box_border.dart';
import 'container.dart';
import 'decoration.dart';
import 'geometry.dart';
import 'text_style.dart';
import 'theme.dart';
import 'widget.dart';

class Checkbox extends SingleChildWidget {
  Checkbox({
    @required this.value,
    this.defaultValue,
    this.tristate = false,
    this.activeColor = PdfColors.blue,
    this.checkColor = PdfColors.white,
    @required this.name,
    double width = 13,
    double height = 13,
    BoxDecoration decoration,
  }) : super(
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

  final bool defaultValue;

  final bool tristate;

  final PdfColor activeColor;

  final PdfColor checkColor;

  final String name;

  @override
  void paint(Context context) {
    super.paint(context);
    paintChild(context);

    final bf = PdfButtonField(
      rect: context.localToGlobal(box),
      fieldName: name,
      value: value,
      defaultValue: value,
      flags: <PdfAnnotFlags>{PdfAnnotFlags.print},
    );

    final g =
        bf.appearance(context.document, PdfAnnotApparence.normal, name: '/Yes');
    g.drawRect(0, 0, bf.rect.width, bf.rect.height);
    g.setFillColor(activeColor);
    g.fillPath();
    g.moveTo(2, bf.rect.height / 2);
    g.lineTo(bf.rect.width / 3, bf.rect.height / 4);
    g.lineTo(bf.rect.width - 2, bf.rect.height / 4 * 3);
    g.setStrokeColor(checkColor);
    g.setLineWidth(2);
    g.strokePath();

    bf.appearance(context.document, PdfAnnotApparence.normal, name: '/Off');

    PdfAnnot(context.page, bf);
  }
}

class FlatButton extends SingleChildWidget {
  FlatButton({
    PdfColor textColor = PdfColors.white,
    PdfColor color = PdfColors.blue,
    PdfColor colorDown = PdfColors.red,
    PdfColor colorRollover = PdfColors.blueAccent,
    EdgeInsets padding,
    BoxDecoration decoration,
    Widget child,
    @required this.name,
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

  // final PdfColor textColor;

  // final PdfColor color;

  // final EdgeInsets padding;

  final String name;

  final Widget _childDown;

  final Widget _childRollover;

  @override
  void paint(Context context) {
    super.paint(context);

    final bf = PdfButtonField(
      rect: context.localToGlobal(box),
      fieldName: name,
      flags: <PdfAnnotFlags>{PdfAnnotFlags.print},
      fieldFlags: <PdfFieldFlags>{PdfFieldFlags.pushButton},
    );

    final mat = context.canvas.getTransform();
    final translation = Vector3(0, 0, 0);
    final rotation = Quaternion(0, 0, 0, 0);
    final scale = Vector3(0, 0, 0);
    mat
      ..decompose(translation, rotation, scale)
      ..leftTranslate(-translation.x, -translation.y)
      ..translate(box.x, box.y);

    final cn = context.copyWith(
        canvas: bf.appearance(context.document, PdfAnnotApparence.normal,
            matrix: mat, boundingBox: box));
    child.layout(
        cn, BoxConstraints.tightFor(width: box.width, height: box.height));
    child.paint(cn);

    final cd = context.copyWith(
        canvas: bf.appearance(context.document, PdfAnnotApparence.down,
            matrix: mat, boundingBox: box));
    _childDown.layout(
        cd, BoxConstraints.tightFor(width: box.width, height: box.height));
    _childDown.paint(cd);

    final cr = context.copyWith(
        canvas: bf.appearance(context.document, PdfAnnotApparence.rollover,
            matrix: mat, boundingBox: box));
    _childRollover.layout(
        cr, BoxConstraints.tightFor(width: box.width, height: box.height));
    _childRollover.paint(cr);

    PdfAnnot(context.page, bf);
  }
}

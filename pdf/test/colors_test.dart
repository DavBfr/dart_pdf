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

import 'dart:io';
import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

class Color extends StatelessWidget {
  Color(this.color, this.name, [this.varient]);
  final PdfColor color;
  final String name;
  final String? varient;

  @override
  Widget build(Context context) {
    final style = Theme.of(context).defaultTextStyle.copyWith(
        color: color.luminance < 0.2 ? PdfColors.white : PdfColors.black,
        fontSize: 14);
    final hexStyle = style.copyWith(font: Font.courier(), fontSize: 10);
    return Container(
        color: color,
        padding: const EdgeInsets.all(2 * PdfPageFormat.mm),
        // child: FittedBox(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(name, style: style),
            Text(varient ?? '', style: style),
            SizedBox(height: 4 * PdfPageFormat.mm),
            Text(color.toHex(), style: hexStyle),
            Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: color.monochromatic
                    .map<Widget>((PdfColor color) =>
                        Container(width: 30, height: 30, color: color))
                    .toList())
          ],
          // )
        ));
  }
}

enum ColorSpace { rgb, ryb, cmy }

class ColorWheel extends Widget {
  ColorWheel({
    this.colorSpace = ColorSpace.rgb,
    this.divisions = 12,
    this.rings = 5,
    this.brightness = .5,
  }) : assert(brightness >= 0 && brightness <= 1);

  final int divisions;
  final int rings;
  final double brightness;
  final ColorSpace colorSpace;

  @override
  void layout(Context context, BoxConstraints? constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, constraints!.biggest);
  }

  void drawFilledArc(Context context, double centerX, double centerY,
      double angleStart, double angleEnd, double radius1, double radius2) {
    assert(radius1 > radius2);

    final startTop = PdfPoint(
      box!.left + centerX + math.cos(angleStart) * radius1,
      box!.bottom + centerY + math.sin(angleStart) * radius1,
    );
    final endTop = PdfPoint(
      box!.left + centerX + math.cos(angleEnd) * radius1,
      box!.bottom + centerY + math.sin(angleEnd) * radius1,
    );
    final startBottom = PdfPoint(
      box!.left + centerX + math.cos(angleStart) * radius2,
      box!.bottom + centerY + math.sin(angleStart) * radius2,
    );
    final endBottom = PdfPoint(
      box!.left + centerX + math.cos(angleEnd) * radius2,
      box!.bottom + centerY + math.sin(angleEnd) * radius2,
    );

    context.canvas
      ..moveTo(startTop.x, startTop.y)
      ..bezierArc(startTop.x, startTop.y, radius1, radius1, endTop.x, endTop.y,
          large: false, sweep: true)
      ..lineTo(endBottom.x, endBottom.y)
      ..bezierArc(endBottom.x, endBottom.y, radius2, radius2, startBottom.x,
          startBottom.y,
          large: false)
      ..lineTo(startTop.x, startTop.y)
      ..fillPath()
      ..moveTo(startTop.x, startTop.y)
      ..bezierArc(startTop.x, startTop.y, radius1, radius1, endTop.x, endTop.y,
          large: false, sweep: true)
      ..lineTo(endBottom.x, endBottom.y)
      ..bezierArc(endBottom.x, endBottom.y, radius2, radius2, startBottom.x,
          startBottom.y,
          large: false)
      ..lineTo(startTop.x, startTop.y)
      ..strokePath();
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final centerX = box!.width / 2;
    final centerY = box!.height / 2;
    final step = math.pi * 2 / divisions;
    final angleStart = math.pi / 2 - step;

    final ringStep = math.min(centerX, centerY) / rings;

    context.canvas.setStrokeColor(PdfColors.black);

    for (var ring = 0; ring <= rings; ring++) {
      final radius1 = ringStep * ring;
      final radius2 = ringStep * (ring - 1);
      for (var angle = 0.0; angle < math.pi * 2; angle += step) {
        final PdfColor ic =
            PdfColorHsl(angle / math.pi * 180, ring / rings, brightness);

        switch (colorSpace) {
          case ColorSpace.rgb:
            context.canvas.setFillColor(ic);
            break;
          case ColorSpace.ryb:
            context.canvas
                .setFillColor(PdfColor.fromRYB(ic.red, ic.green, ic.blue));
            break;
          case ColorSpace.cmy:
            context.canvas
                .setFillColor(PdfColorCmyk(ic.red, ic.green, ic.blue, 0));
            break;
        }

        drawFilledArc(
          context,
          centerX,
          centerY,
          angleStart + angle,
          angleStart + angle + step,
          radius1,
          radius2,
        );
      }
    }
  }
}

late Document pdf;

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document(pageMode: PdfPageMode.outlines);
  });

  test('Pdf Colors', () {
    pdf.addPage(MultiPage(
        pageFormat: PdfPageFormat.standard,
        build: (Context context) => <Widget>[
              Header(text: 'Red', outlineColor: PdfColors.red),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.red50, 'Red', '50'),
                    Color(PdfColors.red100, 'Red', '100'),
                    Color(PdfColors.red200, 'Red', '200'),
                    Color(PdfColors.red300, 'Red', '300'),
                    Color(PdfColors.red400, 'Red', '400'),
                    Color(PdfColors.red500, 'Red', '500'),
                    Color(PdfColors.red600, 'Red', '600'),
                    Color(PdfColors.red700, 'Red', '700'),
                    Color(PdfColors.red800, 'Red', '800'),
                    Color(PdfColors.red900, 'Red', '900'),
                    Color(PdfColors.redAccent100, 'Red', 'Accent 100'),
                    Color(PdfColors.redAccent200, 'Red', 'Accent 200'),
                    Color(PdfColors.redAccent400, 'Red', 'Accent 400'),
                    Color(PdfColors.redAccent700, 'Red', 'Accent 700'),
                  ]),
              NewPage(),
              Header(text: 'Pink', outlineColor: PdfColors.pink),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.pink50, 'Pink', '50'),
                    Color(PdfColors.pink100, 'Pink', '100'),
                    Color(PdfColors.pink200, 'Pink', '200'),
                    Color(PdfColors.pink300, 'Pink', '300'),
                    Color(PdfColors.pink400, 'Pink', '400'),
                    Color(PdfColors.pink500, 'Pink', '500'),
                    Color(PdfColors.pink600, 'Pink', '600'),
                    Color(PdfColors.pink700, 'Pink', '700'),
                    Color(PdfColors.pink800, 'Pink', '800'),
                    Color(PdfColors.pink900, 'Pink', '900'),
                    Color(PdfColors.pinkAccent100, 'Pink', 'Accent 100'),
                    Color(PdfColors.pinkAccent200, 'Pink', 'Accent 200'),
                    Color(PdfColors.pinkAccent400, 'Pink', 'Accent 400'),
                    Color(PdfColors.pinkAccent700, 'Pink', 'Accent 700'),
                  ]),
              NewPage(),
              Header(text: 'Purple', outlineColor: PdfColors.purple),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.purple50, 'Purple', '50'),
                    Color(PdfColors.purple100, 'Purple', '100'),
                    Color(PdfColors.purple200, 'Purple', '200'),
                    Color(PdfColors.purple300, 'Purple', '300'),
                    Color(PdfColors.purple400, 'Purple', '400'),
                    Color(PdfColors.purple500, 'Purple', '500'),
                    Color(PdfColors.purple600, 'Purple', '600'),
                    Color(PdfColors.purple700, 'Purple', '700'),
                    Color(PdfColors.purple800, 'Purple', '800'),
                    Color(PdfColors.purple900, 'Purple', '900'),
                    Color(PdfColors.purpleAccent100, 'Purple', 'Accent 100'),
                    Color(PdfColors.purpleAccent200, 'Purple', 'Accent 200'),
                    Color(PdfColors.purpleAccent400, 'Purple', 'Accent 400'),
                    Color(PdfColors.purpleAccent700, 'Purple', 'Accent 700'),
                  ]),
              NewPage(),
              Header(text: 'Deep Purple', outlineColor: PdfColors.deepPurple),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.deepPurple50, 'Deep Purple', '50'),
                    Color(PdfColors.deepPurple100, 'Deep Purple', '100'),
                    Color(PdfColors.deepPurple200, 'Deep Purple', '200'),
                    Color(PdfColors.deepPurple300, 'Deep Purple', '300'),
                    Color(PdfColors.deepPurple400, 'Deep Purple', '400'),
                    Color(PdfColors.deepPurple500, 'Deep Purple', '500'),
                    Color(PdfColors.deepPurple600, 'Deep Purple', '600'),
                    Color(PdfColors.deepPurple700, 'Deep Purple', '700'),
                    Color(PdfColors.deepPurple800, 'Deep Purple', '800'),
                    Color(PdfColors.deepPurple900, 'Deep Purple', '900'),
                    Color(PdfColors.deepPurpleAccent100, 'Deep Purple',
                        'Accent 100'),
                    Color(PdfColors.deepPurpleAccent200, 'Deep Purple',
                        'Accent 200'),
                    Color(PdfColors.deepPurpleAccent400, 'Deep Purple',
                        'Accent 400'),
                    Color(PdfColors.deepPurpleAccent700, 'Deep Purple',
                        'Accent 700'),
                  ]),
              NewPage(),
              Header(text: 'Indigo', outlineColor: PdfColors.indigo),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.indigo50, 'Indigo', '50'),
                    Color(PdfColors.indigo100, 'Indigo', '100'),
                    Color(PdfColors.indigo200, 'Indigo', '200'),
                    Color(PdfColors.indigo300, 'Indigo', '300'),
                    Color(PdfColors.indigo400, 'Indigo', '400'),
                    Color(PdfColors.indigo500, 'Indigo', '500'),
                    Color(PdfColors.indigo600, 'Indigo', '600'),
                    Color(PdfColors.indigo700, 'Indigo', '700'),
                    Color(PdfColors.indigo800, 'Indigo', '800'),
                    Color(PdfColors.indigo900, 'Indigo', '900'),
                    Color(PdfColors.indigoAccent100, 'Indigo', 'Accent 100'),
                    Color(PdfColors.indigoAccent200, 'Indigo', 'Accent 200'),
                    Color(PdfColors.indigoAccent400, 'Indigo', 'Accent 400'),
                    Color(PdfColors.indigoAccent700, 'Indigo', 'Accent 700'),
                  ]),
              NewPage(),
              Header(text: 'Blue', outlineColor: PdfColors.blue),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.blue50, 'Blue', '50'),
                    Color(PdfColors.blue100, 'Blue', '100'),
                    Color(PdfColors.blue200, 'Blue', '200'),
                    Color(PdfColors.blue300, 'Blue', '300'),
                    Color(PdfColors.blue400, 'Blue', '400'),
                    Color(PdfColors.blue500, 'Blue', '500'),
                    Color(PdfColors.blue600, 'Blue', '600'),
                    Color(PdfColors.blue700, 'Blue', '700'),
                    Color(PdfColors.blue800, 'Blue', '800'),
                    Color(PdfColors.blue900, 'Blue', '900'),
                    Color(PdfColors.blueAccent100, 'Blue', 'Accent 100'),
                    Color(PdfColors.blueAccent200, 'Blue', 'Accent 200'),
                    Color(PdfColors.blueAccent400, 'Blue', 'Accent 400'),
                    Color(PdfColors.blueAccent700, 'Blue', 'Accent 700'),
                  ]),
              NewPage(),
              Header(text: 'Light Blue', outlineColor: PdfColors.lightBlue),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.lightBlue50, 'Light Blue', '50'),
                    Color(PdfColors.lightBlue100, 'Light Blue', '100'),
                    Color(PdfColors.lightBlue200, 'Light Blue', '200'),
                    Color(PdfColors.lightBlue300, 'Light Blue', '300'),
                    Color(PdfColors.lightBlue400, 'Light Blue', '400'),
                    Color(PdfColors.lightBlue500, 'Light Blue', '500'),
                    Color(PdfColors.lightBlue600, 'Light Blue', '600'),
                    Color(PdfColors.lightBlue700, 'Light Blue', '700'),
                    Color(PdfColors.lightBlue800, 'Light Blue', '800'),
                    Color(PdfColors.lightBlue900, 'Light Blue', '900'),
                    Color(PdfColors.lightBlueAccent100, 'Light Blue',
                        'Accent 100'),
                    Color(PdfColors.lightBlueAccent200, 'Light Blue',
                        'Accent 200'),
                    Color(PdfColors.lightBlueAccent400, 'Light Blue',
                        'Accent 400'),
                    Color(PdfColors.lightBlueAccent700, 'Light Blue',
                        'Accent 700'),
                  ]),
              NewPage(),
              Header(text: 'Cyan', outlineColor: PdfColors.cyan),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.cyan50, 'Cyan', '50'),
                    Color(PdfColors.cyan100, 'Cyan', '100'),
                    Color(PdfColors.cyan200, 'Cyan', '200'),
                    Color(PdfColors.cyan300, 'Cyan', '300'),
                    Color(PdfColors.cyan400, 'Cyan', '400'),
                    Color(PdfColors.cyan500, 'Cyan', '500'),
                    Color(PdfColors.cyan600, 'Cyan', '600'),
                    Color(PdfColors.cyan700, 'Cyan', '700'),
                    Color(PdfColors.cyan800, 'Cyan', '800'),
                    Color(PdfColors.cyan900, 'Cyan', '900'),
                    Color(PdfColors.cyanAccent100, 'Cyan', 'Accent 100'),
                    Color(PdfColors.cyanAccent200, 'Cyan', 'Accent 200'),
                    Color(PdfColors.cyanAccent400, 'Cyan', 'Accent 400'),
                    Color(PdfColors.cyanAccent700, 'Cyan', 'Accent 700'),
                  ]),
              NewPage(),
              Header(text: 'Teal', outlineColor: PdfColors.teal),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.teal50, 'Teal', '50'),
                    Color(PdfColors.teal100, 'Teal', '100'),
                    Color(PdfColors.teal200, 'Teal', '200'),
                    Color(PdfColors.teal300, 'Teal', '300'),
                    Color(PdfColors.teal400, 'Teal', '400'),
                    Color(PdfColors.teal500, 'Teal', '500'),
                    Color(PdfColors.teal600, 'Teal', '600'),
                    Color(PdfColors.teal700, 'Teal', '700'),
                    Color(PdfColors.teal800, 'Teal', '800'),
                    Color(PdfColors.teal900, 'Teal', '900'),
                    Color(PdfColors.tealAccent100, 'Teal', 'Accent 100'),
                    Color(PdfColors.tealAccent200, 'Teal', 'Accent 200'),
                    Color(PdfColors.tealAccent400, 'Teal', 'Accent 400'),
                    Color(PdfColors.tealAccent700, 'Teal', 'Accent 700'),
                  ]),
              NewPage(),
              Header(text: 'Green', outlineColor: PdfColors.green),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.green50, 'Green', '50'),
                    Color(PdfColors.green100, 'Green', '100'),
                    Color(PdfColors.green200, 'Green', '200'),
                    Color(PdfColors.green300, 'Green', '300'),
                    Color(PdfColors.green400, 'Green', '400'),
                    Color(PdfColors.green500, 'Green', '500'),
                    Color(PdfColors.green600, 'Green', '600'),
                    Color(PdfColors.green700, 'Green', '700'),
                    Color(PdfColors.green800, 'Green', '800'),
                    Color(PdfColors.green900, 'Green', '900'),
                    Color(PdfColors.greenAccent100, 'Green', 'Accent 100'),
                    Color(PdfColors.greenAccent200, 'Green', 'Accent 200'),
                    Color(PdfColors.greenAccent400, 'Green', 'Accent 400'),
                    Color(PdfColors.greenAccent700, 'Green', 'Accent 700'),
                  ]),
              NewPage(),
              Header(text: 'Light Green', outlineColor: PdfColors.lightGreen),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.lightGreen50, 'Light Green', '50'),
                    Color(PdfColors.lightGreen100, 'Light Green', '100'),
                    Color(PdfColors.lightGreen200, 'Light Green', '200'),
                    Color(PdfColors.lightGreen300, 'Light Green', '300'),
                    Color(PdfColors.lightGreen400, 'Light Green', '400'),
                    Color(PdfColors.lightGreen500, 'Light Green', '500'),
                    Color(PdfColors.lightGreen600, 'Light Green', '600'),
                    Color(PdfColors.lightGreen700, 'Light Green', '700'),
                    Color(PdfColors.lightGreen800, 'Light Green', '800'),
                    Color(PdfColors.lightGreen900, 'Light Green', '900'),
                    Color(PdfColors.lightGreenAccent100, 'Light Green',
                        'Accent100'),
                    Color(PdfColors.lightGreenAccent200, 'Light Green',
                        'Accent200'),
                    Color(PdfColors.lightGreenAccent400, 'Light Green',
                        'Accent400'),
                    Color(PdfColors.lightGreenAccent700, 'Light Green',
                        'Accent700'),
                  ]),
              NewPage(),
              Header(text: 'Lime', outlineColor: PdfColors.lime),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.lime50, 'Lime', '50'),
                    Color(PdfColors.lime100, 'Lime', '100'),
                    Color(PdfColors.lime200, 'Lime', '200'),
                    Color(PdfColors.lime300, 'Lime', '300'),
                    Color(PdfColors.lime400, 'Lime', '400'),
                    Color(PdfColors.lime500, 'Lime', '500'),
                    Color(PdfColors.lime600, 'Lime', '600'),
                    Color(PdfColors.lime700, 'Lime', '700'),
                    Color(PdfColors.lime800, 'Lime', '800'),
                    Color(PdfColors.lime900, 'Lime', '900'),
                    Color(PdfColors.limeAccent100, 'Lime', 'Accent 100'),
                    Color(PdfColors.limeAccent200, 'Lime', 'Accent 200'),
                    Color(PdfColors.limeAccent400, 'Lime', 'Accent 400'),
                    Color(PdfColors.limeAccent700, 'Lime', 'Accent 700'),
                  ]),
              NewPage(),
              Header(text: 'Yellow', outlineColor: PdfColors.yellow),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.yellow50, 'Yellow', '50'),
                    Color(PdfColors.yellow100, 'Yellow', '100'),
                    Color(PdfColors.yellow200, 'Yellow', '200'),
                    Color(PdfColors.yellow300, 'Yellow', '300'),
                    Color(PdfColors.yellow400, 'Yellow', '400'),
                    Color(PdfColors.yellow500, 'Yellow', '500'),
                    Color(PdfColors.yellow600, 'Yellow', '600'),
                    Color(PdfColors.yellow700, 'Yellow', '700'),
                    Color(PdfColors.yellow800, 'Yellow', '800'),
                    Color(PdfColors.yellow900, 'Yellow', '900'),
                    Color(PdfColors.yellowAccent100, 'Yellow', 'Accent 100'),
                    Color(PdfColors.yellowAccent200, 'Yellow', 'Accent 200'),
                    Color(PdfColors.yellowAccent400, 'Yellow', 'Accent 400'),
                    Color(PdfColors.yellowAccent700, 'Yellow', 'Accent 700'),
                  ]),
              NewPage(),
              Header(text: 'Amber', outlineColor: PdfColors.amber),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.amber50, 'Amber', '50'),
                    Color(PdfColors.amber100, 'Amber', '100'),
                    Color(PdfColors.amber200, 'Amber', '200'),
                    Color(PdfColors.amber300, 'Amber', '300'),
                    Color(PdfColors.amber400, 'Amber', '400'),
                    Color(PdfColors.amber500, 'Amber', '500'),
                    Color(PdfColors.amber600, 'Amber', '600'),
                    Color(PdfColors.amber700, 'Amber', '700'),
                    Color(PdfColors.amber800, 'Amber', '800'),
                    Color(PdfColors.amber900, 'Amber', '900'),
                    Color(PdfColors.amberAccent100, 'Amber', 'Accent 100'),
                    Color(PdfColors.amberAccent200, 'Amber', 'Accent 200'),
                    Color(PdfColors.amberAccent400, 'Amber', 'Accent 400'),
                    Color(PdfColors.amberAccent700, 'Amber', 'Accent 700'),
                  ]),
              NewPage(),
              Header(text: 'Orange', outlineColor: PdfColors.orange),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.orange50, 'Orange', '50'),
                    Color(PdfColors.orange100, 'Orange', '100'),
                    Color(PdfColors.orange200, 'Orange', '200'),
                    Color(PdfColors.orange300, 'Orange', '300'),
                    Color(PdfColors.orange400, 'Orange', '400'),
                    Color(PdfColors.orange500, 'Orange', '500'),
                    Color(PdfColors.orange600, 'Orange', '600'),
                    Color(PdfColors.orange700, 'Orange', '700'),
                    Color(PdfColors.orange800, 'Orange', '800'),
                    Color(PdfColors.orange900, 'Orange', '900'),
                    Color(PdfColors.orangeAccent100, 'Orange', 'Accent 100'),
                    Color(PdfColors.orangeAccent200, 'Orange', 'Accent 200'),
                    Color(PdfColors.orangeAccent400, 'Orange', 'Accent 400'),
                    Color(PdfColors.orangeAccent700, 'Orange', 'Accent 700'),
                  ]),
              NewPage(),
              Header(text: 'Deep Orange', outlineColor: PdfColors.deepOrange),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.deepOrange50, 'Deep Orange', '50'),
                    Color(PdfColors.deepOrange100, 'Deep Orange', '100'),
                    Color(PdfColors.deepOrange200, 'Deep Orange', '200'),
                    Color(PdfColors.deepOrange300, 'Deep Orange', '300'),
                    Color(PdfColors.deepOrange400, 'Deep Orange', '400'),
                    Color(PdfColors.deepOrange500, 'Deep Orange', '500'),
                    Color(PdfColors.deepOrange600, 'Deep Orange', '600'),
                    Color(PdfColors.deepOrange700, 'Deep Orange', '700'),
                    Color(PdfColors.deepOrange800, 'Deep Orange', '800'),
                    Color(PdfColors.deepOrange900, 'Deep Orange', '900'),
                    Color(PdfColors.deepOrangeAccent100, 'Deep Orange',
                        'Accent 100'),
                    Color(PdfColors.deepOrangeAccent200, 'Deep Orange',
                        'Accent 200'),
                    Color(PdfColors.deepOrangeAccent400, 'Deep Orange',
                        'Accent 400'),
                    Color(PdfColors.deepOrangeAccent700, 'Deep Orange',
                        'Accent 700'),
                  ]),
              NewPage(),
              Header(text: 'Brown', outlineColor: PdfColors.brown),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.brown50, 'Brown', '50'),
                    Color(PdfColors.brown100, 'Brown', '100'),
                    Color(PdfColors.brown200, 'Brown', '200'),
                    Color(PdfColors.brown300, 'Brown', '300'),
                    Color(PdfColors.brown400, 'Brown', '400'),
                    Color(PdfColors.brown500, 'Brown', '500'),
                    Color(PdfColors.brown600, 'Brown', '600'),
                    Color(PdfColors.brown700, 'Brown', '700'),
                    Color(PdfColors.brown800, 'Brown', '800'),
                    Color(PdfColors.brown900, 'Brown', '900'),
                  ]),
              NewPage(),
              Header(text: 'Blue Grey', outlineColor: PdfColors.blueGrey),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.blueGrey50, 'Blue Grey', '50'),
                    Color(PdfColors.blueGrey100, 'Blue Grey', '100'),
                    Color(PdfColors.blueGrey200, 'Blue Grey', '200'),
                    Color(PdfColors.blueGrey300, 'Blue Grey', '300'),
                    Color(PdfColors.blueGrey400, 'Blue Grey', '400'),
                    Color(PdfColors.blueGrey500, 'Blue Grey', '500'),
                    Color(PdfColors.blueGrey600, 'Blue Grey', '600'),
                    Color(PdfColors.blueGrey700, 'Blue Grey', '700'),
                    Color(PdfColors.blueGrey800, 'Blue Grey', '800'),
                    Color(PdfColors.blueGrey900, 'Blue Grey', '900'),
                  ]),
              NewPage(),
              Header(text: 'Grey', outlineColor: PdfColors.grey),
              GridView(
                  crossAxisCount: 4,
                  direction: Axis.vertical,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(10),
                  children: <Widget>[
                    Color(PdfColors.white, 'White'),
                    Color(PdfColors.grey50, 'Grey', '50'),
                    Color(PdfColors.grey100, 'Grey', '100'),
                    Color(PdfColors.grey200, 'Grey', '200'),
                    Color(PdfColors.grey300, 'Grey', '300'),
                    Color(PdfColors.grey400, 'Grey', '400'),
                    Color(PdfColors.grey400, 'Grey', '400'),
                    Color(PdfColors.grey500, 'Grey', '500'),
                    Color(PdfColors.grey600, 'Grey', '600'),
                    Color(PdfColors.grey700, 'Grey', '700'),
                    Color(PdfColors.grey800, 'Grey', '800'),
                    Color(PdfColors.grey900, 'Grey', '900'),
                    Color(PdfColors.black, 'Black'),
                  ]),
            ]));
  });

  test('Pdf Colors Wheel', () {
    const wheels = <ColorSpace, String>{
      ColorSpace.rgb: 'Red Green Blue',
      ColorSpace.ryb: 'Red Yellow Blue',
      ColorSpace.cmy: 'Cyan Magenta Yellow',
    };

    wheels.forEach((ColorSpace colorSpace, String name) {
      pdf.addPage(Page(
          build: (Context context) => Column(
                children: <Widget>[
                  Header(text: name, outlineStyle: PdfOutlineStyle.italic),
                  SizedBox(
                    height: context.page.pageFormat.availableWidth,
                    child: ColorWheel(
                      colorSpace: colorSpace,
                    ),
                  ),
                ],
              )));
    });
  });

  test('Pdf Colors Generator', () {
    const widthCount = 26;
    const format = PdfPageFormat(400, 400);
    final w = (format.width - 1) / widthCount;
    final count = widthCount * (format.height - 1) ~/ w;

    pdf.addPage(MultiPage(
        pageFormat: format,
        build: (Context context) => <Widget>[
              Wrap(
                  children: List<Widget>.generate(count, (int i) {
                return Container(
                  width: w,
                  height: w,
                  color: PdfColors.getColor(i),
                );
              })),
            ]));
  });

  group('Pdf Colors Conversions', () {
    test('fromHex #RRGGBBAA', () {
      final c = PdfColor.fromHex('#12345678');
      expect(c.red, 0x12 / 255);
      expect(c.green, 0x34 / 255);
      expect(c.blue, 0x56 / 255);
      expect(c.alpha, 0x78 / 255);
    });

    test('fromHex RRGGBBAA', () {
      final c = PdfColor.fromHex('12345678');
      expect(c.red, 0x12 / 255);
      expect(c.green, 0x34 / 255);
      expect(c.blue, 0x56 / 255);
      expect(c.alpha, 0x78 / 255);
    });

    test('fromHex RRGGBB', () {
      final c = PdfColor.fromHex('123456');
      expect(c.red, 0x12 / 255);
      expect(c.green, 0x34 / 255);
      expect(c.blue, 0x56 / 255);
      expect(c.alpha, 1);
    });

    test('fromHex RGB', () {
      final c = PdfColor.fromHex('18f');
      expect(c.red, 0x11 / 255);
      expect(c.green, 0x88 / 255);
      expect(c.blue, 0xff / 255);
      expect(c.alpha, 1);
    });

    test('toHex RGB', () {
      expect(PdfColor.fromHex('#12345678').toHex(), '#12345678');
    });
  });

  tearDownAll(() async {
    final file = File('colors.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}

import 'dart:async';

import 'package:flutter/widgets.dart' as fw;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:printing/printing.dart';

const PdfColor green = PdfColor.fromInt(0xff9ce5d0);
const PdfColor lightGreen = PdfColor.fromInt(0xffcdf1e7);

class MyPage extends Page {
  MyPage(
      {PdfPageFormat pageFormat = PdfPageFormat.a4,
      BuildCallback build,
      EdgeInsets margin})
      : super(pageFormat: pageFormat, margin: margin, build: build);

  @override
  void paint(Widget child, Context context) {
    context.canvas
      ..setColor(lightGreen)
      ..moveTo(0, pageFormat.height)
      ..lineTo(0, pageFormat.height - 230)
      ..lineTo(60, pageFormat.height)
      ..fillPath()
      ..setColor(green)
      ..moveTo(0, pageFormat.height)
      ..lineTo(0, pageFormat.height - 100)
      ..lineTo(100, pageFormat.height)
      ..fillPath()
      ..setColor(lightGreen)
      ..moveTo(30, pageFormat.height)
      ..lineTo(110, pageFormat.height - 50)
      ..lineTo(150, pageFormat.height)
      ..fillPath()
      ..moveTo(pageFormat.width, 0)
      ..lineTo(pageFormat.width, 230)
      ..lineTo(pageFormat.width - 60, 0)
      ..fillPath()
      ..setColor(green)
      ..moveTo(pageFormat.width, 0)
      ..lineTo(pageFormat.width, 100)
      ..lineTo(pageFormat.width - 100, 0)
      ..fillPath()
      ..setColor(lightGreen)
      ..moveTo(pageFormat.width - 30, 0)
      ..lineTo(pageFormat.width - 110, 50)
      ..lineTo(pageFormat.width - 150, 0)
      ..fillPath();

    super.paint(child, context);
  }
}

class Block extends StatelessWidget {
  Block({this.title});

  final String title;

  @override
  Widget build(Context context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 2.5, left: 2, right: 5),
              decoration:
                  const BoxDecoration(color: green, shape: BoxShape.circle),
            ),
            Text(title, style: Theme.of(context).defaultTextStyleBold),
          ]),
          Container(
            decoration: const BoxDecoration(
                border: BoxBorder(left: true, color: green, width: 2)),
            padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
            margin: const EdgeInsets.only(left: 5),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Lorem(length: 20),
                ]),
          ),
        ]);
  }
}

class Category extends StatelessWidget {
  Category({this.title});

  final String title;

  @override
  Widget build(Context context) {
    return Container(
        decoration: const BoxDecoration(color: lightGreen, borderRadius: 6),
        margin: const EdgeInsets.only(bottom: 10, top: 20),
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 4),
        child: Text(title, textScaleFactor: 1.5));
  }
}

Future<PdfDocument> generateDocument(PdfPageFormat format) async {
  final PdfDoc pdf = PdfDoc(title: 'My Résumé', author: 'David PHAM-VAN');

  final PdfImage profileImage = await pdfImageFromImageProvider(
      pdf: pdf.document,
      image: const fw.NetworkImage(
          'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&s=200'),
      onError: (dynamic exception, StackTrace stackTrace) {
        print('Unable to download image');
      });

  pdf.addPage(MyPage(
    pageFormat: format.applyMargin(
        left: 2.0 * PdfPageFormat.cm,
        top: 4.0 * PdfPageFormat.cm,
        right: 2.0 * PdfPageFormat.cm,
        bottom: 2.0 * PdfPageFormat.cm),
    build: (Context context) => Row(children: <Widget>[
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                Container(
                    padding: const EdgeInsets.only(left: 30, bottom: 20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Parnella Charlesbois',
                              textScaleFactor: 2,
                              style: Theme.of(context).defaultTextStyleBold),
                          Padding(padding: const EdgeInsets.only(top: 10)),
                          Text('Electrotyper',
                              textScaleFactor: 1.2,
                              style: Theme.of(context)
                                  .defaultTextStyleBold
                                  .copyWith(color: green)),
                          Padding(padding: const EdgeInsets.only(top: 20)),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text('568 Port Washington Road'),
                                      Text('Nordegg, AB T0M 2H0'),
                                      Text('Canada, ON'),
                                    ]),
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text('+1 403-721-6898'),
                                      Text('p.charlesbois@yahoo.com'),
                                      Text('wholeprices.ca')
                                    ]),
                                Padding(padding: EdgeInsets.zero)
                              ]),
                        ])),
                Category(title: 'Work Experience'),
                Block(title: 'Tour bus driver'),
                Block(title: 'Logging equipment operator'),
                Block(title: 'Foot doctor'),
                Category(title: 'Education'),
                Block(title: 'Bachelor Of Commerce'),
                Block(title: 'Bachelor Interior Design'),
              ])),
          Container(
            height: double.infinity,
            width: 10,
            decoration: const BoxDecoration(
                border: BoxBorder(left: true, color: green, width: 2)),
          ),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipOval(
                    child: Container(
                        width: 100,
                        height: 100,
                        color: lightGreen,
                        child: profileImage == null
                            ? Container()
                            : Image(profileImage)))
              ])
        ]),
  ));
  return pdf.document;
}

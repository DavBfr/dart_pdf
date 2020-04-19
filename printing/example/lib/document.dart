import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'example_widgets.dart';

Future<pw.Document> generateDocument(PdfPageFormat format) async {
  final pw.Document doc =
      pw.Document(title: 'My Résumé', author: 'David PHAM-VAN');

  final PdfImage profileImage = kIsWeb
      ? null
      : await pdfImageFromImageProvider(
          pdf: doc.document,
          image: const NetworkImage(
              'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&s=200'),
          onError: (dynamic exception, StackTrace stackTrace) {
            print('Unable to download image');
          });

  final pw.PageTheme pageTheme = myPageTheme(format);

  doc.addPage(pw.Page(
    pageTheme: pageTheme,
    build: (pw.Context context) => pw.Row(children: <pw.Widget>[
      pw.Expanded(
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
            pw.Container(
                padding: const pw.EdgeInsets.only(left: 30, bottom: 20),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text('Parnella Charlesbois',
                          textScaleFactor: 2,
                          style: pw.Theme.of(context)
                              .defaultTextStyle
                              .copyWith(fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.only(top: 10)),
                      pw.Text('Electrotyper',
                          textScaleFactor: 1.2,
                          style: pw.Theme.of(context).defaultTextStyle.copyWith(
                              fontWeight: pw.FontWeight.bold, color: green)),
                      pw.Padding(padding: const pw.EdgeInsets.only(top: 20)),
                      pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: <pw.Widget>[
                            pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: <pw.Widget>[
                                  pw.Text('568 Port Washington Road'),
                                  pw.Text('Nordegg, AB T0M 2H0'),
                                  pw.Text('Canada, ON'),
                                ]),
                            pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: <pw.Widget>[
                                  pw.Text('+1 403-721-6898'),
                                  UrlText('p.charlesbois@yahoo.com',
                                      'mailto:p.charlesbois@yahoo.com'),
                                  UrlText('wholeprices.ca',
                                      'https://wholeprices.ca'),
                                ]),
                            pw.Padding(padding: pw.EdgeInsets.zero)
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
      pw.Container(
        height: double.infinity,
        width: 2,
        margin: const pw.EdgeInsets.symmetric(horizontal: 5),
        color: green,
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.ClipOval(
              child: pw.Container(
                  width: 100,
                  height: 100,
                  color: lightGreen,
                  child: profileImage == null
                      ? pw.Container()
                      : pw.Image(profileImage))),
          pw.Column(children: <pw.Widget>[
            Percent(size: 60, value: .7, title: pw.Text('Word')),
            Percent(size: 60, value: .4, title: pw.Text('Excel')),
          ]),
          pw.BarcodeWidget(
            data: 'Parnella Charlesbois',
            width: 60,
            height: 60,
            barcode: pw.Barcode.qrCode(),
          ),
        ],
      )
    ]),
  ));
  return doc;
}

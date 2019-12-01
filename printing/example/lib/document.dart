import 'dart:async';

import 'package:flutter/widgets.dart' as fw;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:printing/printing.dart';

import 'example_widgets.dart';

Future<Document> generateDocument(PdfPageFormat format) async {
  final Document pdf = Document(title: 'My Résumé', author: 'David PHAM-VAN');

  final PdfImage profileImage = await pdfImageFromImageProvider(
      pdf: pdf.document,
      image: const fw.NetworkImage(
          'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&s=200'),
      onError: (dynamic exception, StackTrace stackTrace) {
        print('Unable to download image');
      });

  final PageTheme pageTheme = myPageTheme(format);

  pdf.addPage(Page(
    pageTheme: pageTheme,
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
                          style: Theme.of(context)
                              .defaultTextStyle
                              .copyWith(fontWeight: FontWeight.bold)),
                      Padding(padding: const EdgeInsets.only(top: 10)),
                      Text('Electrotyper',
                          textScaleFactor: 1.2,
                          style: Theme.of(context).defaultTextStyle.copyWith(
                              fontWeight: FontWeight.bold, color: green)),
                      Padding(padding: const EdgeInsets.only(top: 20)),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text('568 Port Washington Road'),
                                  Text('Nordegg, AB T0M 2H0'),
                                  Text('Canada, ON'),
                                ]),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text('+1 403-721-6898'),
                                  UrlText('p.charlesbois@yahoo.com',
                                      'mailto:p.charlesbois@yahoo.com'),
                                  UrlText('wholeprices.ca',
                                      'https://wholeprices.ca'),
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
        width: 2,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        color: green,
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          ClipOval(
              child: Container(
                  width: 100,
                  height: 100,
                  color: lightGreen,
                  child: profileImage == null
                      ? Container()
                      : Image(profileImage))),
          Column(children: <Widget>[
            Percent(size: 60, value: .7, title: Text('Word')),
            Percent(size: 60, value: .4, title: Text('Excel')),
          ]),
          QrCodeWidget(data: 'Parnella Charlesbois', size: 60),
        ],
      )
    ]),
  ));
  return pdf;
}

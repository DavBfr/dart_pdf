// ignore_for_file: omit_local_variable_types

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  final pw.Document doc = pw.Document();

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    build: (pw.Context context) => pw.Container(
      color: PdfColor.fromRYB(0.2, 0.2, 0.2),
      alignment: pw.Alignment.topCenter,
      child: pw.ScatterChart(
        data: <double>[0, 2, 1, 8, 5, 3],
//        separatorEvery: 1,
//        gridTextSize: 8,
//        font: PdfFont.courier(doc.document),
      ),
//      child:
//          pw.Table.fromTextArray(context: context, data: const <List<String>>[
//        <String>['Date', 'PDF Version', 'Acrobat Version'],
//        <String>['1993', 'PDF 1.0', 'Acrobat 1'],
//        <String>['1994', 'PDF 1.1', 'Acrobat 2'],
//        <String>['1996', 'PDF 1.2', 'Acrobat 3'],
//        <String>['1999', 'PDF 1.3', 'Acrobat 4'],
//        <String>['2001', 'PDF 1.4', 'Acrobat 5'],
//        <String>['2003', 'PDF 1.5', 'Acrobat 6'],
//        <String>['2005', 'PDF 1.6', 'Acrobat 7'],
//        <String>['2006', 'PDF 1.7', 'Acrobat 8'],
//        <String>['2008', 'PDF 1.7', 'Acrobat 9'],
//        <String>['2009', 'PDF 1.7', 'Acrobat 9.1'],
//        <String>['2010', 'PDF 1.7', 'Acrobat X'],
//        <String>['2012', 'PDF 1.7', 'Acrobat XI'],
//        <String>['2017', 'PDF 2.0', 'Acrobat DC'],
//      ]),
    ),
  ));

  final File file = File('example.pdf');
  file.writeAsBytesSync(doc.save());
}

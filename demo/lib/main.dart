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

// ignore_for_file: always_specify_types

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

import 'calendar.dart';
import 'document.dart';
import 'invoice.dart';
import 'report.dart';
import 'resume.dart';

void main() {
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() {
    return MyAppState();
  }
}

class MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  List<Tab> _myTabs;
  List<LayoutCallback> _tabGen;
  List<String> _tabUrl;
  int _tab = 0;
  TabController _tabController;

  PrintingInfo printingInfo;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final PrintingInfo info = await Printing.info();

    _myTabs = const <Tab>[
      Tab(text: 'RÉSUMÉ'),
      Tab(text: 'DOCUMENT'),
      Tab(text: 'INVOICE'),
      Tab(text: 'REPORT'),
      Tab(text: 'CALENDAR'),
    ];

    _tabGen = const <LayoutCallback>[
      generateResume,
      generateDocument,
      generateInvoice,
      generateReport,
      generateCalendar,
    ];

    _tabUrl = const <String>[
      'resume.dart',
      'document.dart',
      'invoice.dart',
      'report.dart',
      'calendar.dart',
    ];

    _tabController = TabController(
      vsync: this,
      length: _myTabs.length,
      initialIndex: _tab,
    );
    _tabController.addListener(() {
      setState(() {
        _tab = _tabController.index;
      });
    });

    setState(() {
      printingInfo = info;
    });
  }

  void _showPrintedToast(BuildContext context) {
    final ScaffoldState scaffold = Scaffold.of(context);

    scaffold.showSnackBar(
      const SnackBar(
        content: Text('Document printed successfully'),
      ),
    );
  }

  void _showSharedToast(BuildContext context) {
    final ScaffoldState scaffold = Scaffold.of(context);

    scaffold.showSnackBar(
      const SnackBar(
        content: Text('Document shared successfully'),
      ),
    );
  }

  Future<void> _saveAsFile(
    BuildContext context,
    LayoutCallback build,
    PdfPageFormat pageFormat,
  ) async {
    final Uint8List bytes = await build(pageFormat);

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String appDocPath = appDocDir.path;
    final File file = File(appDocPath + '/' + 'document.pdf');
    print('Save as file ${file.path} ...');
    await file.writeAsBytes(bytes);
    OpenFile.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    pw.RichText.debug = true;

    if (_tabController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final actions = <PdfPreviewAction>[
      if (!kIsWeb)
        PdfPreviewAction(
          icon: const Icon(Icons.save),
          onPressed: _saveAsFile,
        )
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pdf Printing Example'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _myTabs,
        ),
      ),
      body: PdfPreview(
        maxPageWidth: 700,
        build: _tabGen[_tab],
        actions: actions,
        onPrinted: _showPrintedToast,
        onShared: _showSharedToast,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepOrange,
        onPressed: _showSources,
        child: Icon(Icons.code),
      ),
    );
  }

  void _showSources() {
    ul.launch(
      'https://github.com/DavBfr/dart_pdf/blob/master/demo/lib/${_tabUrl[_tab]}',
    );
  }
}

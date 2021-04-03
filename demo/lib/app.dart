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

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

import 'data.dart';
import 'examples.dart';

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() {
    return MyAppState();
  }
}

class MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  int _tab = 0;
  TabController? _tabController;

  PrintingInfo? printingInfo;

  var _data = CustomData();
  var _hasData = false;
  var _pending = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _init() async {
    final info = await Printing.info();

    _tabController = TabController(
      vsync: this,
      length: examples.length,
      initialIndex: _tab,
    );
    _tabController!.addListener(() {
      if (_tab != _tabController!.index) {
        setState(() {
          _tab = _tabController!.index;
        });
      }
      if (examples[_tab].needsData && !_hasData && !_pending) {
        _pending = true;
        askName(context).then((value) {
          if (value != null) {
            setState(() {
              _data = CustomData(name: value);
              _hasData = true;
              _pending = false;
            });
          }
        });
      }
    });

    setState(() {
      printingInfo = info;
    });
  }

  void _showPrintedToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document printed successfully'),
      ),
    );
  }

  void _showSharedToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
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
    final bytes = await build(pageFormat);

    final appDocDir = await getApplicationDocumentsDirectory();
    final appDocPath = appDocDir.path;
    final file = File(appDocPath + '/' + 'document.pdf');
    print('Save as file ${file.path} ...');
    await file.writeAsBytes(bytes);
    await OpenFile.open(file.path);
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
        title: const Text('Flutter PDF Demo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: examples.map<Tab>((e) => Tab(text: e.name)).toList(),
          isScrollable: true,
        ),
      ),
      body: PdfPreview(
        maxPageWidth: 700,
        build: (format) => examples[_tab].builder(format, _data),
        actions: actions,
        onPrinted: _showPrintedToast,
        onShared: _showSharedToast,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepOrange,
        onPressed: _showSources,
        child: const Icon(Icons.code),
      ),
    );
  }

  void _showSources() {
    ul.launch(
      'https://github.com/DavBfr/dart_pdf/blob/master/demo/lib/examples/${examples[_tab].file}',
    );
  }

  Future<String?> askName(BuildContext context) {
    return showDialog<String>(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          final controller = TextEditingController();

          return AlertDialog(
            title: Text('Please type your name:'),
            contentPadding: EdgeInsets.symmetric(horizontal: 20),
            content: TextField(
              decoration: InputDecoration(hintText: '[your name]'),
              controller: controller,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (controller.text != '') {
                    Navigator.pop(context, controller.text);
                  }
                },
                child: Text('OK'),
              ),
            ],
          );
        });
  }
}

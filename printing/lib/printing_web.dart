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

library printing_web;

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

part 'wsrc/print_job.dart';

class PrintingPlugin {
  PrintingPlugin(this._channel);

  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'net.nfet.printing',
      const StandardMethodCodec(),
      registrar.messenger,
    );
    final PrintingPlugin instance = PrintingPlugin(channel);
    channel.setMethodCallHandler(instance.handleMethodCall);
  }

  final MethodChannel _channel;

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'printPdf':
        final String name = call.arguments['name'];
        final double width = call.arguments['width'];
        final double height = call.arguments['height'];
        final double marginLeft = call.arguments['marginLeft'];
        final double marginTop = call.arguments['marginTop'];
        final double marginRight = call.arguments['marginRight'];
        final double marginBottom = call.arguments['marginBottom'];

        final _PrintJob printJob = _PrintJob(this, call.arguments['job']);
        return printJob.printPdf(name, width, height, marginLeft, marginTop,
            marginRight, marginBottom);
      case 'sharePdf':
        final List<int> data = call.arguments['doc'];
        final double x = call.arguments['x'];
        final double y = call.arguments['y'];
        final double width = call.arguments['w'];
        final double height = call.arguments['h'];
        final String name = call.arguments['name'];
        return _PrintJob.sharePdf(data, x, y, width, height, name);
      case 'printingInfo':
        return _PrintJob.printingInfo();
    }
    throw UnimplementedError('Method "${call.method}" not implemented');
  }

  /// Request the Pdf document from flutter
  Future<void> onLayout(
      _PrintJob printJob,
      double width,
      double height,
      double marginLeft,
      double marginTop,
      double marginRight,
      double marginBottom) async {
    final Map<String, dynamic> args = <String, dynamic>{
      'width': width,
      'height': height,
      'marginLeft': marginLeft,
      'marginTop': marginTop,
      'marginRight': marginRight,
      'marginBottom': marginBottom,
      'job': printJob.index,
    };

    final dynamic result =
        await _channel.invokeMethod<dynamic>('onLayout', args);

    if (result is List<int>) {
      printJob.setDocument(result);
    } else {
      printJob.cancelJob();
    }
  }

  /// send completion status to flutter
  Future<void> onCompleted(_PrintJob printJob, bool completed,
      [String error = '']) async {
    final Map<String, dynamic> data = <String, dynamic>{
      'completed': completed,
      'error': error,
      'job': printJob.index,
    };

    await _channel.invokeMethod<dynamic>('onCompleted', data);
  }
}

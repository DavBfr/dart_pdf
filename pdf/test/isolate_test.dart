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
import 'dart:isolate';
import 'dart:typed_data';

import 'package:pdf/widgets.dart';

import 'utils.dart';

class Message {
  Message(this.image, this.sendPort);

  final Uint8List image;
  final SendPort sendPort;
}

void compute(Message message) {
  final pdf = Document();

  final image = MemoryImage(
    message.image,
  );

  pdf.addPage(Page(build: (Context context) => Center(child: Image(image))));

  message.sendPort.send(pdf.save());
}

void main() {
  noTest('Pdf Isolate', () async {
    final completer = Completer<void>();
    final receivePort = ReceivePort();

    receivePort.listen((dynamic data) async {
      if (data is Uint8List) {
        print('Received a ${data.length} bytes PDF');
        final file = File('isolate.pdf');
        await file.writeAsBytes(data);
        print('File saved');
        completer.complete();
      }
    });

    print('Download image');
    final imageBytes = await download('https://www.nfet.net/nfet.jpg');

    print('Generate PDF');
    await Isolate.spawn<Message>(
      compute,
      Message(imageBytes, receivePort.sendPort),
    );

    print('Wait PDF to be generated');
    await completer.future;
    receivePort.close();
    print('Done');
  });
}

void noTest(String s, Future<void> Function() param1) {}

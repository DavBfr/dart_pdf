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
import 'dart:isolate';

import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  test('Pdf Isolate', () async {
    print('Download image');
    final imageBytes = await download('https://www.nfet.net/nfet.jpg');

    print('Generate PDF');
    // ignore: sdk_version_since
    final data = await Isolate.run(() async {
      final pdf = Document();
      final image = MemoryImage(imageBytes);
      pdf.addPage(
          Page(build: (Context context) => Center(child: Image(image))));
      return await pdf.save();
    });

    print('Generated a ${data.length} bytes PDF');
    final file = File('isolate.pdf');
    await file.writeAsBytes(data);
    print('File saved');
  });
}

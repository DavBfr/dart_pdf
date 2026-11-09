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

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_widget_wrapper/pdf_widget_wrapper.dart';

void main() {
  testWidgets('fromKey captures a widget that embeds in a PDF', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          key: key,
          child: const SizedBox(
            width: 20,
            height: 12,
            child: ColoredBox(color: Color(0xffff0000)),
          ),
        ),
      ),
    );

    final image = await tester.runAsync(() => WidgetWrapper.fromKey(key: key));
    expect(image!.width, 20);
    expect(image.height, 12);
    expect(image.bytes.length, 20 * 12 * 4);

    final pdf = pw.Document()
      ..addPage(pw.Page(build: (context) => pw.Image(image)));
    expect(await pdf.save(), isNotEmpty);
  });
}

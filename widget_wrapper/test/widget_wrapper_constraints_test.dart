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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_widget_wrapper/pdf_widget_wrapper.dart';

void main() {
  testWidgets('fromWidget rejects an unbounded width or height', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));

    for (final constraints in const [
      BoxConstraints(maxHeight: 100),
      BoxConstraints(maxWidth: 100),
    ]) {
      await expectLater(
        WidgetWrapper.fromWidget(
          context: context,
          widget: const SizedBox(width: 20, height: 20),
          constraints: constraints,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Add maxWidth and maxHeight'),
          ),
        ),
      );
    }
  });
}

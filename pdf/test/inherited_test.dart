/*
 * Copyright (C) 2025, Kamil Szczęk <kamil@szczek.dev>
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

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

class Locale extends Inherited {
  Locale({required this.languageCode});

  final String languageCode;

  static String of(final Context context) {
    return context.dependsOn<Locale>()!.languageCode;
  }
}

class ColorScheme extends Inherited {
  ColorScheme({
    required this.primary,
    required this.secondary,
  });

  final PdfColor primary;
  final PdfColor secondary;

  static ColorScheme of(final Context context) {
    return context.dependsOn<ColorScheme>()!;
  }
}

class Greeting extends StatelessWidget {
  @override
  Widget build(final Context context) {
    final languageCode = Locale.of(context);
    final colorScheme = ColorScheme.of(context);
    return Text(
      languageCode == 'pl' ? 'Witaj' : 'Welcome',
      style: TextStyle(
        color: colorScheme.primary,
        background: BoxDecoration(color: colorScheme.secondary),
      ),
      textAlign: TextAlign.center,
    );
  }
}

void main() {
  late Document pdf;

  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();
  });

  test('Page should pass inherited data down the widget tree', () {
    pdf.addPage(
      Page(
        inherited: <Inherited>[
          Locale(languageCode: 'en'),
          ColorScheme(primary: PdfColors.red, secondary: PdfColors.yellow),
        ],
        build: (final Context context) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Greeting(),
            InheritedWidget(
              inherited: ColorScheme(
                primary: PdfColors.green,
                secondary: PdfColors.black,
              ),
              build: (final Context context) => Greeting(),
            ),
            InheritedWidget(
              inherited: Locale(languageCode: 'pl'),
              build: (final Context context) => Greeting(),
            ),
          ],
        ),
      ),
    );
  });

  test('MultiPage should pass inherited data down the widget tree', () {
    pdf.addPage(
      MultiPage(
        crossAxisAlignment: CrossAxisAlignment.center,
        inherited: <Inherited>[
          Locale(languageCode: 'en'),
          ColorScheme(primary: PdfColors.red, secondary: PdfColors.yellow),
        ],
        build: (final Context context) => <Widget>[
          Greeting(),
          InheritedWidget(
            inherited: ColorScheme(
              primary: PdfColors.green,
              secondary: PdfColors.black,
            ),
            build: (final Context context) => Greeting(),
          ),
          InheritedWidget(
            inherited: Locale(languageCode: 'pl'),
            build: (final Context context) => Greeting(),
          ),
        ],
      ),
    );
  });

  tearDownAll(() async {
    final file = File('inherited.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}

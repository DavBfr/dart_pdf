import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

import 'theme.dart';
import 'widgets/home_page.dart';

/// PDF Document generator for {{name}}
class {{name.pascalCase()}} with {{name.pascalCase()}}Theme {
  /// Create a PDF document for {{name}}
  const {{name.pascalCase()}}({
    required this.title,
    required this.data,
  });

  /// Some test data to build {{name}}
  static const {{name.pascalCase()}} demo = {{name.pascalCase()}}(
    title: '{{name}}',
    data: [
      ['Phone', 80, 95],
      ['Internet', 250, 230],
      ['Electricity', 300, 375],
      ['Movies', 85, 80],
      ['Food', 300, 350],
      ['Fuel', 650, 550],
      ['Insurance', 250, 310],
    ],
  );

  /// The page title
  final String title;

  /// Some data to display
  final List<List<dynamic>> data;

  List<String> get tableHeaders => ['Category', 'Budget', 'Expense', 'Result'];

  /// The total budget
  num get budget =>
      data.map((e) => e[1] as num).reduce((value, element) => value + element);

  /// The total expense
  num get expense =>
      data.map((e) => e[2] as num).reduce((value, element) => value + element);

  // Create {{name}} PDF document.
  Future<Uint8List> buildPdf(PdfPageFormat pageFormat) async {
    final doc = Document();

    // Generate the theme
    final pageTheme = await buildPageTheme(
      pageFormat: pageFormat,
    );

    // Add a page to the PDF
    doc.addPage(
      Page(
        pageTheme: pageTheme,
        build: (context) => HomePage(this),
      ),
    );

    // Return the PDF file content
    return doc.save();
  }
}

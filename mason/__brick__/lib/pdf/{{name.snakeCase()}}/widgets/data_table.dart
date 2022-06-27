import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

import '../document.dart';

class DataTable extends StatelessWidget {
  DataTable(
    this.{{name.snakeCase()}},
  );

  final {{name.pascalCase()}} {{name.snakeCase()}};

  @override
  Widget build(Context context) {
    return Table.fromTextArray(
      border: null,
      headers: {{name.snakeCase()}}.tableHeaders,
      data: List<List<dynamic>>.generate(
        {{name.snakeCase()}}.data.length,
        (index) => [
          {{name.snakeCase()}}.data[index][0],
          {{name.snakeCase()}}.data[index][1],
          {{name.snakeCase()}}.data[index][2],
          ({{name.snakeCase()}}.data[index][1] as num) - ({{name.snakeCase()}}.data[index][2] as num),
        ],
      ),
      headerStyle: TextStyle(
        color: PdfColors.white,
        fontWeight: FontWeight.bold,
      ),
      headerDecoration: BoxDecoration(
        color: {{name.snakeCase()}}.baseColor,
      ),
      rowDecoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: {{name.snakeCase()}}.baseColor,
            width: .5,
          ),
        ),
      ),
      cellAlignment: Alignment.centerRight,
      cellAlignments: {0: Alignment.centerLeft},
    );
  }
}

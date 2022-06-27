import 'package:pdf/widgets.dart';

import '../document.dart';
import 'data_chart.dart';
import 'data_table.dart';

class HomePage extends StatelessWidget {
  HomePage(
    this.{{name.snakeCase()}},
  );

  final {{name.pascalCase()}} {{name.snakeCase()}};

  @override
  Widget build(Context context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: Text({{name.snakeCase()}}.title, style: Theme.of(context).header0),
        ),
        SizedBox(height: 20),
        DataTable({{name.snakeCase()}}),
        SizedBox(height: 20),
        Flexible(child: DataChart({{name.snakeCase()}}))
      ],
    );
  }
}

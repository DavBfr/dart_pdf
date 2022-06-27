import 'package:pdf/widgets.dart';

import '../document.dart';

class DataChart extends StatelessWidget {
  DataChart(
    this.{{name.snakeCase()}},
  );

  final {{name.pascalCase()}} {{name.snakeCase()}};

  @override
  Widget build(Context context) {
    return Chart(
      title: Text(
        'Expense breakdown',
        style: TextStyle(
          color: {{name.snakeCase()}}.baseColor,
          fontSize: 20,
        ),
      ),
      grid: PieGrid(),
      datasets: List<Dataset>.generate({{name.snakeCase()}}.data.length, (index) {
        final data = {{name.snakeCase()}}.data[index];
        final color = {{name.snakeCase()}}.chartColors[index % {{name.snakeCase()}}.chartColors.length];
        final value = (data[2] as num).toDouble();
        final pct = (value / {{name.snakeCase()}}.expense * 100).round();
        return PieDataSet(
          legend: '${data[0]}\n$pct%',
          value: value,
          color: color,
          legendStyle: const TextStyle(fontSize: 10),
        );
      }),
    );
  }
}

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

// ignore_for_file: omit_local_variable_types

part of widget;

class ChartLegend extends StatelessWidget {
  ChartLegend({
    this.textStyle,
    this.position = Alignment.topRight,
    this.direction = Axis.vertical,
    this.decoration,
    this.padding = const EdgeInsets.all(5),
  }) : assert(position != null);

  final TextStyle textStyle;

  final Alignment position;

  final Axis direction;

  final BoxDecoration decoration;

  final EdgeInsets padding;

  Widget _buildLegend(Context context, Dataset dataset) {
    final TextStyle style = Theme.of(context).defaultTextStyle.merge(textStyle);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: style.fontSize,
          height: style.fontSize,
          margin: const EdgeInsets.only(right: 5),
          child: dataset.legendeShape(),
        ),
        Text(
          dataset.legend,
          style: textStyle,
        )
      ],
    );
  }

  @override
  Widget build(Context context) {
    assert(Chart.of(context) != null,
        '$runtimeType cannot be used without a Chart widget');

    final List<Dataset> datasets = Chart.of(context).datasets;

    final Widget wrap = Wrap(
      direction: direction,
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        for (final Dataset dataset in datasets)
          if (dataset.legend != null) _buildLegend(context, dataset)
      ],
    );

    return Align(
      alignment: position,
      child: Container(
        decoration: decoration ?? const BoxDecoration(color: PdfColors.white),
        padding: padding,
        child: wrap,
      ),
    );
  }
}

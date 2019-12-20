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

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

class Calendar extends StatelessWidget {
  Calendar({
    this.date,
    this.month,
    this.year,
  });

  final DateTime date;

  final int month;

  final int year;

  Widget title(
    Context context,
    DateTime date,
  ) {
    return Container(
      width: double.infinity,
      child: Text(
        DateFormat.yMMMM().format(date),
        style: const TextStyle(
          color: PdfColors.deepPurple,
          fontSize: 40,
        ),
      ),
    );
  }

  Widget header(
    Context context,
    DateTime date,
  ) {
    return Container(
      color: PdfColors.blue200,
      padding: const EdgeInsets.all(8.0),
      child: Text(
        DateFormat.EEEE().format(date),
        style: const TextStyle(
          fontSize: 15,
        ),
      ),
    );
  }

  Widget day(
    Context context,
    DateTime date,
    bool currentMonth,
    bool currentDay,
  ) {
    String text = '${date.day}';
    TextStyle style = const TextStyle();
    PdfColor color = PdfColors.grey300;

    if (currentDay) {
      style = TextStyle(color: PdfColors.red);
      color = PdfColors.lightBlue50;
    }

    if (!currentMonth) {
      style = TextStyle(color: PdfColors.grey);
      color = PdfColors.grey100;
    }

    if (date.day == 1) {
      text += ' ' + DateFormat.MMM().format(date);
    }

    return Container(
      padding: const EdgeInsets.all(4),
      color: color,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: style,
      ),
    );
  }

  @override
  Widget build(Context context) {
    final DateTime _date = date ?? DateTime.now();
    final int _year = year ?? _date.year;
    final int _month = month ?? _date.month;

    final DateTime start = DateTime(_year, _month, 1, 12);
    final DateTime end = DateTime(_year, _month + 1, 1, 12).subtract(
      const Duration(days: 1),
    );

    final int startId = start.weekday - 1;
    final int endId = end.difference(start).inDays + startId + 1;

    final Row head = Row(
      mainAxisSize: MainAxisSize.max,
      children: List<Widget>.generate(7, (int index) {
        final DateTime d = start.add(Duration(days: index - startId));
        return Expanded(
          child: Container(
            foregroundDecoration: BoxDecoration(
              border: BoxBorder(
                color: PdfColors.black,
                top: true,
                left: true,
                right: index % 7 == 6,
                bottom: true,
              ),
            ),
            child: header(context, d),
          ),
        );
      }),
    );

    final GridView body = GridView(
      crossAxisCount: 7,
      children: List<Widget>.generate(42, (int index) {
        final DateTime d = start.add(Duration(days: index - startId));
        final bool currentMonth = index >= startId && index < endId;
        final bool currentDay = d.year == _date.year &&
            d.month == _date.month &&
            d.day == _date.day;
        return Container(
          foregroundDecoration: BoxDecoration(
            border: BoxBorder(
              color: PdfColors.black,
              left: true,
              right: index % 7 == 6,
              bottom: true,
            ),
          ),
          child: day(context, d, currentMonth, currentDay),
        );
      }),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          title(context, DateTime(_year, _month)),
          head,
          Flexible(flex: 1, child: body),
        ],
      ),
    );
  }
}

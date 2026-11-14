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

import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';

/// A paper size supported by a printer, as reported by its driver
@immutable
class PrinterPaper {
  /// Create a paper size information
  const PrinterPaper({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
  });

  /// Create a paper size information object from a dictionary
  factory PrinterPaper.fromMap(Map<dynamic, dynamic> map) => PrinterPaper(
    id: map['id'],
    name: map['name'],
    width: (map['width'] as num).toDouble(),
    height: (map['height'] as num).toDouble(),
  );

  /// The platform specific identification of the paper.
  /// On Windows, this is the paper size number of the printer driver.
  final String id;

  /// The display name of the paper, as given by the printer driver
  final String name;

  /// The width of the paper in points (1/72 inch), as reported by the driver
  final double width;

  /// The height of the paper in points (1/72 inch), as reported by the driver
  final double height;

  /// The paper as a page format without margins
  PdfPageFormat get format => PdfPageFormat(width, height);

  /// The paper as a dictionary, the counterpart of [PrinterPaper.fromMap]
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'width': width,
    'height': height,
  };

  @override
  bool operator ==(Object other) =>
      other is PrinterPaper &&
      other.id == id &&
      other.name == name &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(id, name, width, height);

  @override
  String toString() =>
      '$runtimeType $name ($id): ${width.toStringAsFixed(1)} x ${height.toStringAsFixed(1)} pt';
}

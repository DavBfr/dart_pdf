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

part of pdf;

@immutable
class PdfPoint {
  final double x, y;

  @deprecated
  double get w => x;

  @deprecated
  double get h => y;

  const PdfPoint(this.x, this.y);

  static const zero = PdfPoint(0.0, 0.0);

  @override
  String toString() => "PdfPoint($x, $y)";
}

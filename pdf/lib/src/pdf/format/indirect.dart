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

import 'base.dart';
import 'stream.dart';

class PdfIndirect extends PdfDataType {
  const PdfIndirect(this.ser, this.gen);

  final int ser;

  final int gen;

  @override
  void output(PdfStream s, [int? indent]) {
    s.putString('$ser $gen R');
  }

  @override
  bool operator ==(Object other) {
    if (other is PdfIndirect) {
      return ser == other.ser && gen == other.gen;
    }

    return false;
  }

  @override
  int get hashCode => ser.hashCode + gen.hashCode;
}

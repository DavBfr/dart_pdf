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
import 'object_base.dart';
import 'stream.dart';

class PdfBool extends PdfDataType {
  const PdfBool(this.value);

  final bool value;

  @override
  void output(PdfObjectBase o, PdfStream s, [int? indent]) {
    s.putString(value ? 'true' : 'false');
  }

  @override
  bool operator ==(Object other) {
    if (other is PdfBool) {
      return value == other.value;
    }

    return false;
  }

  @override
  int get hashCode => value.hashCode;
}

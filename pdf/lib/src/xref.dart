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

class PdfXref {
  /// Creates a cross-reference for a Pdf Object
  /// @param id The object's ID
  /// @param offset The object's position in the file
  /// @param generation The object's generation, usually 0
  PdfXref(this.id, this.offset, {this.generation = 0});

  /// The id of a Pdf Object
  int id;

  /// The offset within the Pdf file
  int offset;

  /// The generation of the object, usually 0
  int generation = 0;

  /// @return The xref in the format of the xref section in the Pdf file
  String ref() {
    final rs = offset.toString().padLeft(10, '0') +
        ' ' +
        generation.toString().padLeft(5, '0');

    if (generation == 65535) {
      return rs + ' f ';
    }
    return rs + ' n ';
  }
}

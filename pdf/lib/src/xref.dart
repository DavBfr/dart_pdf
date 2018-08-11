/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General  License for more details.
 *
 * You should have received a copy of the GNU Lesser General
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

part of pdf;

class PDFXref {
  /// The id of a PDF Object
  int id;

  /// The offset within the PDF file
  int offset;

  /// The generation of the object, usually 0
  int generation = 0;

  /// Creates a crossreference for a PDF Object
  /// @param id The object's ID
  /// @param offset The object's position in the file
  /// @param generation The object's generation, usually 0
  PDFXref(this.id, this.offset, {this.generation = 0});

  /// @return The xref in the format of the xref section in the PDF file
  String ref() {
    String rs =
        offset.toString().padLeft(10, '0') + " " + generation.toString().padLeft(5, '0');

    if (generation == 65535) return rs + " f ";
    return rs + " n ";
  }
}

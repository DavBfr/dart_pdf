/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

part of pdf;

class PdfObject {
  /// This is the object parameters.
  final params = Map<String, PdfStream>();

  /// This is the unique serial number for this object.
  final int objser;

  /// This is the generation number for this object.
  final int objgen = 0;

  /// This allows any Pdf object to refer to the document being constructed.
  final PdfDocument pdfDocument;

  /// This is usually called by extensors to this class, and sets the
  /// Pdf Object Type
  /// @param type the Pdf Object Type
  PdfObject(this.pdfDocument, [String type])
      : objser = pdfDocument._genSerial() {
    if (type != null) {
      params["/Type"] = PdfStream.string(type);
    }

    pdfDocument.objects.add(this);
  }

  /// Writes the object to the output stream.
  /// This method must be overidden.
  ///
  /// Note: It should not write any other objects, even if they are
  /// it's Kids, as they will be written by the calling routine.
  ///
  /// @param os OutputStream to send the object to
  void write(PdfStream os) {
    prepare();
    writeStart(os);
    writeContent(os);
    writeEnd(os);
  }

  /// Prepare the object to be written to the stream
  @mustCallSuper
  void prepare() {}

  /// The write method should call this before writing anything to the
  /// OutputStream. This will send the standard header for each object.
  ///
  /// Note: There are a few rare cases where this method is not called.
  ///
  /// @param os OutputStream to write to
  void writeStart(PdfStream os) {
    os.putString("$objser $objgen obj\n");
  }

  void writeContent(PdfStream os) {
    if (params.length > 0) {
      os.putDictionary(params);
      os.putString("\n");
    }
  }

  /// The write method should call this after writing anything to the
  /// OutputStream. This will send the standard footer for each object.
  ///
  /// Note: There are a few rare cases where this method is not called.
  ///
  /// @param os OutputStream to write to
  void writeEnd(PdfStream os) {
    os.putString("endobj\n");
  }

  /// Returns the unique serial number in Pdf format
  /// @return the serial number in Pdf format
  PdfStream ref() => PdfStream.string("$objser $objgen R");
}

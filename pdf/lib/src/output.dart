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

class PdfOutput {
  /// This creates a Pdf [PdfStream]
  ///
  /// @param os The output stream to write the Pdf file to.
  PdfOutput(this.os) {
    os.putString('%PDF-1.4\n');
    os.putBytes(const <int>[0x25, 0xC2, 0xA5, 0xC2, 0xB1, 0xC3, 0xAB, 0x0A]);
  }

  /// This is the actual [PdfStream] used to write to.
  final PdfStream os;

  /// This vector contains offsets of each object
  List<PdfXref> offsets = <PdfXref>[];

  /// This is used to track the /Root object (catalog)
  PdfObject rootID;

  /// This is used to track the /Info object (info)
  PdfObject infoID;

  /// This method writes a [PdfObject] to the stream.
  ///
  /// @param ob [PdfObject] Object to write
  void write(PdfObject ob) {
    // Check the object to see if it's one that is needed in the trailer
    // object
    if (ob is PdfCatalog) {
      rootID = ob;
    }
    if (ob is PdfInfo) {
      infoID = ob;
    }

    offsets.add(PdfXref(ob.objser, os.offset));
    ob._write(os);
  }

  /// This closes the Stream, writing the xref table
  void close() {
    final int xref = os.offset;

    os.putString('xref\n');

    // Now a single subsection for object 0
    //os.write("0 1\n0000000000 65535 f \n");

    // Now scan through the offsets list. The should be in sequence,
    // but just in case:
    int firstid = 0; // First id in block
    int lastid = -1; // The last id used
    final List<PdfXref> block = <PdfXref>[]; // xrefs in this block

    // We need block 0 to exist
    block.add(PdfXref(0, 0, generation: 65535));

    for (PdfXref x in offsets) {
      if (firstid == -1) {
        firstid = x.id;
      }

      // check to see if block is in range (-1 means empty)
      if (lastid > -1 && x.id != (lastid + 1)) {
        // no, so write this block, and reset
        writeblock(firstid, block);
        block.clear();
        firstid = -1;
      }

      // now add to block
      block.add(x);
      lastid = x.id;
    }

    // now write the last block
    if (firstid > -1) {
      writeblock(firstid, block);
    }

    // now the trailer object
    os.putString('trailer\n');

    final Map<String, PdfStream> params = <String, PdfStream>{};

    // the number of entries (REQUIRED)
    params['/Size'] = PdfStream.intNum(offsets.length + 1);

    // the /Root catalog indirect reference (REQUIRED)
    if (rootID != null) {
      params['/Root'] = rootID.ref();
      final PdfStream id = PdfStream.binary(rootID.pdfDocument.documentID);
      params['/ID'] = PdfStream.array(<PdfStream>[id, id]);
    } else {
      throw Exception('Root object is not present in document');
    }

    // the /Info reference (OPTIONAL)
    if (infoID != null) {
      params['/Info'] = infoID.ref();
    }

    // end the trailer object
    os.putDictionary(params);
    os.putString('\nstartxref\n$xref\n%%EOF\n');
  }

  /// Writes a block of references to the Pdf file
  /// @param firstid ID of the first reference in this block
  /// @param block Vector containing the references in this block
  void writeblock(int firstid, List<PdfXref> block) {
    os.putString('$firstid ${block.length}\n');

    for (PdfXref x in block) {
      os.putString(x.ref());
      os.putString('\n');
    }
  }
}

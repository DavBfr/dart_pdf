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

import 'dart:typed_data';

import 'package:pdf/src/pdf/stream.dart';

import 'data_types.dart';
import 'object.dart';

/// Cross-reference for a Pdf Object
class PdfXref {
  /// Creates a cross-reference for a Pdf Object
  PdfXref(this.id, this.offset, {this.generation = 0});

  /// The id of a Pdf Object
  int id;

  /// The offset within the Pdf file
  int offset;

  /// The generation of the object, usually 0
  int generation = 0;

  /// The xref in the format of the xref section in the Pdf file
  String ref() {
    final rs = offset.toString().padLeft(10, '0') +
        ' ' +
        generation.toString().padLeft(5, '0');

    if (generation == 65535) {
      return rs + ' f ';
    }
    return rs + ' n ';
  }

  /// The xref in the format of the compressed xref section in the Pdf file
  int cref(ByteData o, int ofs, List<int> w) {
    assert(w.length >= 3);

    void setVal(int l, int v) {
      for (var n = 0; n < l; n++) {
        o.setUint8(ofs, (v >> (l - n - 1) * 8) & 0xff);
        ofs++;
      }
    }

    setVal(w[0], 1);
    setVal(w[1], offset);
    setVal(w[2], generation);

    return ofs;
  }

  @override
  bool operator ==(Object other) {
    if (other is PdfXref) {
      return offset == other.offset;
    }

    return false;
  }

  @override
  String toString() => '$runtimeType $id $generation $offset';

  @override
  int get hashCode => offset;
}

class PdfXrefTable extends PdfDataType {
  PdfXrefTable();

  /// Contains offsets of each object
  final offsets = <PdfXref>[];

  /// Add a xross reference element to the set
  void add(PdfXref xref) {
    offsets.add(xref);
  }

  /// Writes a block of references to the Pdf file
  void _writeblock(PdfStream s, int firstid, List<PdfXref> block) {
    s.putString('$firstid ${block.length}\n');

    for (var x in block) {
      s.putString(x.ref());
      s.putByte(0x0a);
    }
  }

  @override
  void output(PdfStream s) {
    s.putString('xref\n');

    // Now scan through the offsets list. They should be in sequence.
    offsets.sort((a, b) => a.id.compareTo(b.id));

    var firstid = 0; // First id in block
    var lastid = 0; // The last id used
    final block = <PdfXref>[]; // xrefs in this block

    // We need block 0 to exist
    block.add(PdfXref(0, 0, generation: 65535));

    for (var x in offsets) {
      // check to see if block is in range
      if (x.id != (lastid + 1)) {
        // no, so write this block, and reset
        _writeblock(s, firstid, block);
        block.clear();
        firstid = x.id;
      }

      // now add to block
      block.add(x);
      lastid = x.id;
    }

    // now write the last block
    _writeblock(s, firstid, block);
  }

  /// Output a compressed cross-reference table
  void outputCompressed(PdfObject object, PdfStream s, PdfDict params) {
    // Write this object too
    final id = offsets.last.id + 1;
    final offset = s.offset;
    offsets.add(PdfXref(id, offset));

    // Sort all references
    offsets.sort((a, b) => a.id.compareTo(b.id));

    s.putString('$id 0 obj\n');

    params['/Type'] = const PdfName('/XRef');
    params['/Size'] = PdfNum(id + 1);

    var firstid = 0; // First id in block
    var lastid = 0; // The last id used
    final blocks = <int>[]; // xrefs in this block first, count

    // We need block 0 to exist
    blocks.add(firstid);

    for (var x in offsets) {
      // check to see if block is in range
      if (x.id != (lastid + 1)) {
        // no, so store this block, and reset
        blocks.add(lastid - firstid + 1);
        firstid = x.id;
        blocks.add(firstid);
      }
      lastid = x.id;
    }
    blocks.add(lastid - firstid + 1);

    if (!(blocks.length == 2 && blocks[0] == 0 && blocks[1] == id + 1)) {
      params['/Index'] = PdfArray.fromNum(blocks);
    }

    var bytes = 2; // A pdf less than 256 bytes is unlikely
    while (1 << (bytes * 8) < offset) {
      bytes++;
    }

    final w = [1, bytes, 1];
    params['/W'] = PdfArray.fromNum(w);
    final wl = w.reduce((a, b) => a + b);

    final o = ByteData((offsets.length + 2) * wl);
    var ofs = 0;
    // Write offset zero, all zeros
    ofs += wl;

    for (var x in offsets) {
      ofs = x.cref(o, ofs, w);
    }

    // Write the object
    PdfDictStream(
      object: object,
      data: o.buffer.asUint8List(),
      isBinary: true,
      encrypt: false,
      values: params.values,
    ).output(s);
  }
}

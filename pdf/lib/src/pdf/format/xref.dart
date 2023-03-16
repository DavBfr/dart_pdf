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

import 'dart:math' as math;
import 'dart:typed_data';

import 'array.dart';
import 'base.dart';
import 'dict.dart';
import 'dict_stream.dart';
import 'indirect.dart';
import 'name.dart';
import 'num.dart';
import 'object_base.dart';
import 'stream.dart';

enum PdfCrossRefEntryType { free, inUse, compressed }

/// Cross-reference for a Pdf Object
class PdfXref {
  /// Creates a cross-reference for a Pdf Object
  const PdfXref(
    this.id,
    this.offset, {
    this.generation = 0,
    this.object,
    this.type = PdfCrossRefEntryType.inUse,
  });

  /// The id of a Pdf Object
  final int id;

  /// The offset within the Pdf file
  final int offset;

  /// The object ID containing this compressed object
  final int? object;

  /// The generation of the object, usually 0
  final int generation;

  final PdfCrossRefEntryType type;

  /// The xref in the format of the xref section in the Pdf file
  String _legacyRef() {
    return '${offset.toString().padLeft(10, '0')} ${generation.toString().padLeft(5, '0')}${type == PdfCrossRefEntryType.inUse ? ' n ' : ' f '}';
  }

  PdfIndirect? get container => object == null ? null : PdfIndirect(object!, 0);

  /// The xref in the format of the compressed xref section in the Pdf file
  int _compressedRef(ByteData o, int ofs, List<int> w) {
    assert(w.length >= 3);

    void setVal(int l, int v) {
      for (var n = 0; n < l; n++) {
        o.setUint8(ofs, (v >> (l - n - 1) * 8) & 0xff);
        ofs++;
      }
    }

    setVal(w[0], type == PdfCrossRefEntryType.inUse ? 1 : 0);
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
  String toString() => '$id $generation obj ${type.name} $offset';

  @override
  int get hashCode => offset;
}

class PdfXrefTable extends PdfDataType {
  PdfXrefTable();

  /// Contains offsets of each object
  final offsets = <PdfXref>[];

  /// Add a cross reference element to the set
  void add(PdfXref xref) {
    offsets.add(xref);
  }

  /// Writes a block of references to the Pdf file
  void _writeBlock(PdfStream s, int firstId, List<PdfXref> block) {
    s.putString('$firstId ${block.length}\n');

    for (final x in block) {
      s.putString(x._legacyRef());
      s.putByte(0x0a);
    }
  }

  @override
  void output(PdfStream s, [int? indent]) {}

  @override
  String toString() {
    final s = StringBuffer();
    for (final x in offsets) {
      s.writeln('  $x');
    }
    return s.toString();
  }

  int outputLegacy(PdfObjectBase object, PdfStream s, PdfDict params) {
    // Now scan through the offsets list. They should be in sequence.
    offsets.sort((a, b) => a.id.compareTo(b.id));

    assert(() {
      if (object.verbose) {
        s.putComment('');
        s.putComment('-' * 78);
        s.putComment('$runtimeType ${object.version.name}\n$this');
      }
      return true;
    }());

    var firstId = 0; // First id in block
    var lastId = 0; // The last id used
    final block = <PdfXref>[]; // xrefs in this block

    // We need block 0 to exist
    block.add(const PdfXref(
      0,
      0,
      generation: 65535,
      type: PdfCrossRefEntryType.free,
    ));

    final objOffset = s.offset;
    s.putString('xref\n');

    for (final x in offsets) {
      // check to see if block is in range
      if (x.id != (lastId + 1)) {
        // no, so write this block, and reset
        _writeBlock(s, firstId, block);
        block.clear();
        firstId = x.id;
      }

      // now add to block
      block.add(x);
      lastId = x.id;
    }

    // now write the last block
    _writeBlock(s, firstId, block);

    // the trailer object
    assert(() {
      if (object.verbose) {
        s.putComment('');
      }
      return true;
    }());
    s.putString('trailer\n');
    params.output(s, object.verbose ? 0 : null);
    s.putByte(0x0a);

    return objOffset;
  }

  /// Output a compressed cross-reference table
  int outputCompressed(PdfObjectBase object, PdfStream s, PdfDict params) {
    final offset = s.offset;

    // Sort all references
    offsets.sort((a, b) => a.id.compareTo(b.id));

    // Write this object too
    final id = offsets.last.id + 1;
    offsets.add(PdfXref(id, offset));

    params['/Type'] = const PdfName('/XRef');
    params['/Size'] = PdfNum(id + 1);

    var firstId = 0; // First id in block
    var lastId = 0; // The last id used
    final blocks = <int>[]; // xrefs in this block first, count

    // We need block 0 to exist
    blocks.add(firstId);

    for (final x in offsets) {
      // check to see if block is in range
      if (x.id != (lastId + 1)) {
        // no, so store this block, and reset
        blocks.add(lastId - firstId + 1);
        firstId = x.id;
        blocks.add(firstId);
      }
      lastId = x.id;
    }
    blocks.add(lastId - firstId + 1);

    if (!(blocks.length == 2 && blocks[0] == 0 && blocks[1] == id + 1)) {
      params['/Index'] = PdfArray.fromNum(blocks);
    }

    final bytes = ((math.log(offset) / math.ln2).ceil() / 8).ceil();
    final w = [1, bytes, 1];
    params['/W'] = PdfArray.fromNum(w);
    final wl = w.reduce((a, b) => a + b);

    final o = ByteData((offsets.length + 1) * wl);
    var ofs = 0;
    // Write offset zero, all zeros
    ofs += wl;

    for (final x in offsets) {
      ofs = x._compressedRef(o, ofs, w);
    }

    // Write the object
    assert(() {
      if (object.verbose) {
        s.putComment('');
        s.putComment('-' * 78);
        s.putComment('$runtimeType ${object.version.name}\n$this');
      }
      return true;
    }());

    final objOffset = s.offset;

    s.putString('$id 0 obj\n');

    PdfDictStream(
      object: object,
      data: o.buffer.asUint8List(),
      isBinary: false,
      encrypt: false,
      values: params.values,
    ).output(s, object.verbose ? 0 : null);

    s.putString('endobj\n');
    return objOffset;
  }
}

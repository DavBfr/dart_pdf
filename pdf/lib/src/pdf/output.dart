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

import 'data_types.dart';
import 'document.dart';
import 'obj/catalog.dart';
import 'obj/encryption.dart';
import 'obj/info.dart';
import 'obj/object.dart';
import 'obj/signature.dart';
import 'stream.dart';
import 'xref.dart';

/// PDF document writer
class PdfOutput {
  /// This creates a Pdf [PdfStream]
  PdfOutput(this.os, this.version, this.verbose) {
    String v;
    switch (version) {
      case PdfVersion.pdf_1_4:
        v = '1.4';
        break;
      case PdfVersion.pdf_1_5:
        v = '1.5';
        break;
    }

    os.putString('%PDF-$v\n');
    os.putBytes(const <int>[0x25, 0xC2, 0xA5, 0xC2, 0xB1, 0xC3, 0xAB, 0x0A]);
    assert(() {
      if (verbose) {
        _stopwatch = Stopwatch()..start();
        os.putComment('');
        os.putComment('Verbose dart_pdf');
        os.putComment('Creation date: ${DateTime.now()}');
        _comment = os.offset;
        os.putBytes(List<int>.filled(120, 0x20));
      }
      return true;
    }());
  }

  late final Stopwatch _stopwatch;
  var _comment = 0;

  /// Pdf version to output
  final PdfVersion version;

  /// This is the actual [PdfStream] used to write to.
  final PdfStream os;

  /// Cross reference table
  final xref = PdfXrefTable();

  /// This is used to track the /Root object (catalog)
  PdfCatalog? rootID;

  /// This is used to track the /Info object (info)
  PdfInfo? infoID;

  /// This is used to track the /Encrypt object (encryption)
  PdfEncryption? encryptID;

  /// This is used to track the /Sign object (signature)
  PdfSignature? signatureID;

  /// Generate a compressed cross reference table
  bool get isCompressed => version.index > PdfVersion.pdf_1_4.index;

  /// Verbose output
  final bool verbose;

  /// This method writes a [PdfObject] to the stream.
  void write(PdfObject ob) {
    // Check the object to see if it's one that is needed later
    if (ob is PdfCatalog) {
      rootID = ob;
    } else if (ob is PdfInfo) {
      infoID = ob;
    } else if (ob is PdfEncryption) {
      encryptID = ob;
    } else if (ob is PdfSignature) {
      assert(signatureID == null, 'Only one document signature is allowed');
      signatureID = ob;
    }

    xref.add(PdfXref(ob.objser, os.offset));
    ob.write(os);
  }

  /// This closes the Stream, writing the xref table
  Future<void> close() async {
    if (rootID == null) {
      throw Exception('Root object is not present in document');
    }

    final params = PdfDict();

    // the number of entries (REQUIRED)
    params['/Size'] = PdfNum(rootID!.pdfDocument.objser);

    // the /Root catalog indirect reference (REQUIRED)
    params['/Root'] = rootID!.ref();
    final id =
        PdfString(rootID!.pdfDocument.documentID, PdfStringFormat.binary);
    params['/ID'] = PdfArray([id, id]);

    // the /Info reference (OPTIONAL)
    if (infoID != null) {
      params['/Info'] = infoID!.ref();
    }

    // the /Encrypt reference (OPTIONAL)
    if (encryptID != null) {
      params['/Encrypt'] = encryptID!.ref();
    }

    if (rootID!.pdfDocument.prev != null) {
      params['/Prev'] = PdfNum(rootID!.pdfDocument.prev!.xrefOffset);
    }

    final _xref = os.offset;
    if (isCompressed) {
      xref.outputCompressed(rootID!, os, params);
    } else {
      assert(() {
        os.putComment('');
        os.putComment('-' * 78);
        return true;
      }());
      xref.output(os);

      // the trailer object
      assert(() {
        os.putComment('');
        os.putComment('-' * 78);
        return true;
      }());
      os.putString('trailer\n');
      params.output(os, verbose ? 0 : null);
      os.putByte(0x0a);
    }

    assert(() {
      if (rootID!.pdfDocument.verbose) {
        os.putComment('');
        os.putComment('-' * 78);
      }
      return true;
    }());

    // the reference to the xref object
    os.putString('startxref\n$_xref\n%%EOF\n');

    assert(() {
      if (verbose) {
        _stopwatch.stop();
        final h = PdfStream();
        h.putComment(
            'Creation time: ${_stopwatch.elapsed.inMicroseconds / Duration.microsecondsPerSecond} seconds');
        h.putComment('File size: ${os.offset} bytes');
        h.putComment('Pages: ${rootID!.pdfDocument.pdfPageList.pages.length}');
        h.putComment('Objects: ${xref.offsets.length}');

        os.setBytes(_comment, h.output());
      }
      return true;
    }());

    if (signatureID != null) {
      await signatureID!.writeSignature(os);
    }
  }
}

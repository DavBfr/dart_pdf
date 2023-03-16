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

import 'format/array.dart';
import 'format/dict.dart';
import 'format/num.dart';
import 'format/object_base.dart';
import 'format/stream.dart';
import 'format/string.dart';
import 'format/xref.dart';
import 'obj/catalog.dart';
import 'obj/diagnostic.dart';
import 'obj/encryption.dart';
import 'obj/info.dart';
import 'obj/object.dart';
import 'obj/signature.dart';

/// PDF document writer
class PdfOutput with PdfDiagnostic {
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
        setInsertion(os);
        startStopwatch();
        debugFill('Verbose dart_pdf');
        debugFill('Producer https://github.com/DavBfr/dart_pdf');
        debugFill('Creation date: ${DateTime.now()}');
      }
      return true;
    }());
  }

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

    assert(() {
      if (verbose) {
        ob.setInsertion(os);
        ob.startStopwatch();
      }
      return true;
    }());
    xref.add(PdfXref(ob.objser, os.offset, generation: ob.objgen));
    ob.write(os);
    assert(() {
      if (verbose) {
        ob.stopStopwatch();
        ob.debugFill(
            'Creation time: ${ob.elapsedStopwatch / Duration.microsecondsPerSecond} seconds');
        ob.writeDebug(os);
      }
      return true;
    }());
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
    final id = PdfString(rootID!.pdfDocument.documentID,
        format: PdfStringFormat.binary, encrypted: false);
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

    final _xref = isCompressed
        ? xref.outputCompressed(rootID!, os, params)
        : xref.outputLegacy(rootID!, os, params);

    assert(() {
      if (verbose) {
        os.putComment('');
        os.putComment('-' * 78);
        os.putComment('$runtimeType');
      }
      return true;
    }());

    // the reference to the xref object
    os.putString('startxref\n$_xref\n%%EOF\n');

    assert(() {
      if (verbose) {
        stopStopwatch();
        debugFill(
            'Creation time: ${elapsedStopwatch / Duration.microsecondsPerSecond} seconds');
        debugFill('File size: ${os.offset} bytes');
        debugFill('Pages: ${rootID!.pdfDocument.pdfPageList.pages.length}');
        debugFill('Objects: ${xref.offsets.length}');
        writeDebug(os);
      }
      return true;
    }());

    if (signatureID != null) {
      await signatureID!.writeSignature(os);
    }
  }
}

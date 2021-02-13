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

import 'dart:ffi' as ffi;
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:ffi/ffi.dart' as ffi;

import 'print_job.dart';

/// Load the dynamic library
final ffi.DynamicLibrary _dynamicLibrary = _open();
ffi.DynamicLibrary _open() {
  if (io.Platform.isMacOS || io.Platform.isIOS) {
    return ffi.DynamicLibrary.process();
  }
  throw UnsupportedError('This platform is not supported.');
}

/// Set the Pdf document data
void setDocumentFfi(PrintJob job, Uint8List data) {
  final nativeBytes = ffi.calloc<ffi.Uint8>(data.length);
  nativeBytes.asTypedList(data.length).setAll(0, data);
  _setDocument(job.index, nativeBytes, data.length);
  ffi.calloc.free(nativeBytes);
}

final _SetDocument_Dart _setDocument =
    _dynamicLibrary.lookupFunction<_SetDocument_C, _SetDocument_Dart>(
  'net_nfet_printing_set_document',
);

typedef _SetDocument_C = ffi.Void Function(
  ffi.Uint32 job,
  ffi.Pointer<ffi.Uint8> data,
  ffi.Uint64 size,
);

typedef _SetDocument_Dart = void Function(
  int job,
  ffi.Pointer<ffi.Uint8> data,
  int size,
);

/// Set the Pdf Error message
void setErrorFfi(PrintJob job, String message) {
  _setError(job.index, ffi.StringUtf8Pointer(message).toNativeUtf8());
}

final _SetError_Dart _setError =
    _dynamicLibrary.lookupFunction<_SetError_C, _SetError_Dart>(
  'net_nfet_printing_set_error',
);

typedef _SetError_C = ffi.Void Function(
  ffi.Uint32 job,
  ffi.Pointer<ffi.Utf8> message,
);

typedef _SetError_Dart = void Function(
  int job,
  ffi.Pointer<ffi.Utf8> message,
);

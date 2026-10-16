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

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Read a blob's bytes.
///
/// This replaces a `FileReader` whose `loadend` listener completed a `Completer`
/// only on the success path. An aborted or failed read still fires `loadend`,
/// with `result` null, so the listener threw on the null assertion before
/// completing - and an exception thrown in a `Stream.listen` callback goes to
/// the zone, not to the awaiting code. The completer was never completed, the
/// `await` never returned, and the raster stream neither emitted another page
/// nor closed: a preview stuck on a spinner with no error and no retry.
///
/// `Blob.arrayBuffer()` reports a failed or aborted read as a rejected promise,
/// which arrives here as a Dart error.
Future<Uint8List> blobToBytes(web.Blob blob) async {
  final buffer = await blob.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

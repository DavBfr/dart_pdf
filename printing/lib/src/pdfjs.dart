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

// ignore_for_file: public_member_api_docs

@JS()
library pdf.js;

import 'dart:html';
import 'dart:typed_data';

import 'package:js/js.dart';

// ignore: avoid_classes_with_only_static_members
@JS('pdfjsLib')
class PdfJs {
  external static PdfJsDocLoader getDocument(Settings data);
}

@anonymous
@JS()
class Settings {
  external set data(Uint8List value);
  external set scale(double value);
  external set canvasContext(CanvasRenderingContext2D value);
  external set viewport(PdfJsViewport value);
}

@anonymous
@JS()
class PdfJsDocLoader {
  external Future<PdfJsDoc> get promise;
  external Future<void> destroy();
}

@anonymous
@JS()
class PdfJsDoc {
  external Future<PdfJsPage> getPage(int num);
  external int get numPages;
}

@anonymous
@JS()
class PdfJsPage {
  external PdfJsViewport getViewport(Settings data);
  external PdfJsRender render(Settings data);
  external bool cleanup();
}

@anonymous
@JS()
class PdfJsViewport {
  external num get width;
  external num get height;
}

@anonymous
@JS()
class PdfJsRender {
  external Future<void> get promise;
}

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

@JS('pdfjsLib')
library;

import 'dart:js_interop';

import 'package:web/web.dart';

@JS()
external PdfJsDocLoader getDocument(Settings data);

@anonymous
@JS()
extension type Settings._(JSObject _) implements JSObject {
  external factory Settings({JSUint8Array data});

  external set data(JSUint8Array value);
  external set scale(double value);
  external set canvasContext(CanvasRenderingContext2D value);
  external set viewport(PdfJsViewport value);
  external set cMapUrl(String value);
  external set cMapPacked(bool value);
}

@anonymous
@JS()
extension type PdfJsDocLoader._(JSObject _) implements JSObject {
  external JSPromise<PdfJsDoc> get promise;
  external JSPromise<Null> destroy();
}

@anonymous
@JS()
extension type PdfJsDoc._(JSObject _) implements JSObject {
  external JSPromise<PdfJsPage> getPage(int num);
  external int get numPages;
}

@anonymous
@JS()
extension type PdfJsPage._(JSObject _) implements JSObject {
  external PdfJsViewport getViewport(Settings data);
  external PdfJsRender render(Settings data);
  external bool cleanup();
}

@anonymous
@JS()
extension type PdfJsViewport._(JSObject _) implements JSObject {
  external num get width;
  external num get height;
}

@anonymous
@JS()
extension type PdfJsRender._(JSObject _) implements JSObject {
  external JSPromise<Null> get promise;
}

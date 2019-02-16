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

part of printing;

Future<PdfImage> pdfImageFromImage(
    {@required PdfDocument pdf, @required ui.Image image}) async {
  final ByteData bytes =
      await image.toByteData(format: ui.ImageByteFormat.rawRgba);

  return PdfImage(pdf,
      image: bytes.buffer.asUint8List(),
      width: image.width,
      height: image.height);
}

Future<PdfImage> pdfImageFromImageProvider(
    {@required PdfDocument pdf,
    @required ImageProvider image,
    ImageConfiguration configuration,
    ImageErrorListener onError}) async {
  final Completer<PdfImage> completer = Completer<PdfImage>();
  final ImageStream stream =
      image.resolve(configuration ?? ImageConfiguration.empty);

  Future<void> listener(ImageInfo image, bool sync) async {
    final PdfImage result =
        await pdfImageFromImage(pdf: pdf, image: image.image);
    if (!completer.isCompleted) {
      completer.complete(result);
    }
    stream.removeListener(listener);
  }

  void errorListener(dynamic exception, StackTrace stackTrace) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
    if (onError != null) {
      onError(exception, stackTrace);
    } else {
      FlutterError.reportError(FlutterErrorDetails(
        context: 'image failed to load',
        library: 'printing',
        exception: exception,
        stack: stackTrace,
        silent: true,
      ));
    }
  }

  stream.addListener(listener, onError: errorListener);
  return completer.future;
}

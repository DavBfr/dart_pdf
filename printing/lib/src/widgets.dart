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

@Deprecated('Use `Document` instead')
class PdfDoc extends Document {
  /// Wrapper for a [Document] with zlib compression enabled by default
  PdfDoc(
      {bool compress = true,
      PdfPageMode pageMode = PdfPageMode.none,
      Theme theme,
      String title,
      String author,
      String creator,
      String subject,
      String keywords,
      String producer})
      : super(
          compress: compress,
          pageMode: pageMode,
          theme: theme,
          title: title,
          author: author,
          creator: creator,
          subject: subject,
          keywords: keywords,
          producer: producer,
        ) {
    Document.debug = debugPaintSizeEnabled;
  }
}

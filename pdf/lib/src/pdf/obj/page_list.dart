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

import '../data_types.dart';
import '../document.dart';
import 'object_dict.dart';
import 'page.dart';

/// PdfPageList object
class PdfPageList extends PdfObjectDict {
  /// This constructs a [PdfPageList] object.
  PdfPageList(PdfDocument pdfDocument) : super(pdfDocument, type: '/Pages');

  /// This holds the pages
  final pages = <PdfPage>[];

  @override
  void prepare() {
    super.prepare();

    params['/Kids'] = PdfArray.fromObjects(pages);
    params['/Count'] = PdfNum(pages.length);
  }
}

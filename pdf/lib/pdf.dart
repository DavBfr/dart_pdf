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

library pdf;

import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:utf/utf.dart';
import 'package:vector_math/vector_math_64.dart';

part 'src/annotation.dart';
part 'src/array.dart';
part 'src/ascii85.dart';
part 'src/border.dart';
part 'src/catalog.dart';
part 'src/color.dart';
part 'src/colors.dart';
part 'src/compatibility.dart';
part 'src/document.dart';
part 'src/encryption.dart';
part 'src/font_descriptor.dart';
part 'src/font_metrics.dart';
part 'src/font.dart';
part 'src/formxobject.dart';
part 'src/graphics.dart';
part 'src/image.dart';
part 'src/info.dart';
part 'src/names.dart';
part 'src/object_stream.dart';
part 'src/object.dart';
part 'src/outline.dart';
part 'src/output.dart';
part 'src/page_format.dart';
part 'src/page_list.dart';
part 'src/page.dart';
part 'src/point.dart';
part 'src/polygon.dart';
part 'src/rect.dart';
part 'src/signature.dart';
part 'src/stream.dart';
part 'src/ttf_parser.dart';
part 'src/ttf_writer.dart';
part 'src/ttffont.dart';
part 'src/type1_font.dart';
part 'src/type1_fonts.dart';
part 'src/unicode_cmap.dart';
part 'src/xobject.dart';
part 'src/xref.dart';

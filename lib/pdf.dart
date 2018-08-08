/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

library pdf;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:ttf_parser/ttf_parser.dart';
import 'package:vector_math/vector_math_64.dart';

part 'src/annotation.dart';
part 'src/array.dart';
part 'src/ascii85.dart';
part 'src/border.dart';
part 'src/catalog.dart';
part 'src/color.dart';
part 'src/document.dart';
part 'src/font.dart';
part 'src/font_descriptor.dart';
part 'src/formxobject.dart';
part 'src/graphics.dart';
part 'src/image.dart';
part 'src/info.dart';
part 'src/object.dart';
part 'src/object_stream.dart';
part 'src/outline.dart';
part 'src/output.dart';
part 'src/page.dart';
part 'src/page_format.dart';
part 'src/page_list.dart';
part 'src/point.dart';
part 'src/polygon.dart';
part 'src/rect.dart';
part 'src/stream.dart';
part 'src/ttffont.dart';
part 'src/xobject.dart';
part 'src/xref.dart';

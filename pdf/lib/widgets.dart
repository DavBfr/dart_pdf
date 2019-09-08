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

library widget;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';
import 'package:vector_math/vector_math_64.dart';

part 'widgets/annotations.dart';
part 'widgets/basic.dart';
part 'widgets/clip.dart';
part 'widgets/container.dart';
part 'widgets/content.dart';
part 'widgets/document.dart';
part 'widgets/flex.dart';
part 'widgets/font.dart';
part 'widgets/geometry.dart';
part 'widgets/grid_view.dart';
part 'widgets/image.dart';
part 'widgets/multi_page.dart';
part 'widgets/page.dart';
part 'widgets/page_theme.dart';
part 'widgets/placeholders.dart';
part 'widgets/progress.dart';
part 'widgets/stack.dart';
part 'widgets/table.dart';
part 'widgets/text.dart';
part 'widgets/text_style.dart';
part 'widgets/theme.dart';
part 'widgets/widget.dart';
part 'widgets/wrap.dart';

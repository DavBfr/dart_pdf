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

library pdf.all_tests;

import '../example/main.dart' as example;
import 'annotations_test.dart' as annotations;
import 'colors_test.dart' as colors;
import 'complex_test.dart' as complex;
import 'jpeg_test.dart' as jpeg;
import 'metrics_test.dart' as metrics;
import 'minimal_test.dart' as minimal;
import 'ttf_test.dart' as ttf;
import 'type1_test.dart' as type1;
import 'widget_basic_test.dart' as widget_basic;
import 'widget_clip_test.dart' as widget_clip;
import 'widget_container_test.dart' as widget_container;
import 'widget_multipage_test.dart' as widget_multipage;
import 'widget_table_test.dart' as widget_table;
import 'widget_test.dart' as widget;
import 'widget_text_test.dart' as widget_text;
import 'widget_theme_test.dart' as widget_theme;
import 'widget_wrap_test.dart' as widget_wrap;

void main() {
  annotations.main();
  colors.main();
  complex.main();
  example.main();
  jpeg.main();
  metrics.main();
  minimal.main();
  ttf.main();
  type1.main();
  widget_basic.main();
  widget_clip.main();
  widget_container.main();
  widget_multipage.main();
  widget_table.main();
  widget_text.main();
  widget_theme.main();
  widget_wrap.main();
  widget.main();
}

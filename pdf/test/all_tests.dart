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
import 'isolate_test.dart' as isolate;
import 'jpeg_test.dart' as jpeg;
import 'metrics_test.dart' as metrics;
import 'minimal_test.dart' as minimal;
import 'orientation_test.dart' as orientation;
import 'roll_paper_test.dart' as roll;
import 'ttf_test.dart' as ttf;
import 'type1_test.dart' as type1;
import 'widget_barcode_test.dart' as widget_barcode;
import 'widget_basic_test.dart' as widget_basic;
import 'widget_clip_test.dart' as widget_clip;
import 'widget_container_test.dart' as widget_container;
import 'widget_flex_test.dart' as widget_flex;
import 'widget_grid_view_test.dart' as widget_grid_view;
import 'widget_multipage_test.dart' as widget_multipage;
import 'widget_partitions_test.dart' as widget_partitions;
import 'widget_table_test.dart' as widget_table;
import 'widget_test.dart' as widget;
import 'widget_text_test.dart' as widget_text;
import 'widget_theme_test.dart' as widget_theme;
import 'widget_watermark_test.dart' as widget_watermark;
import 'widget_wrap_test.dart' as widget_wrap;

void main() {
  annotations.main();
  colors.main();
  complex.main();
  example.main();
  isolate.main();
  jpeg.main();
  metrics.main();
  minimal.main();
  orientation.main();
  roll.main();
  ttf.main();
  type1.main();
  widget_basic.main();
  widget_barcode.main();
  widget_clip.main();
  widget_container.main();
  widget_flex.main();
  widget_grid_view.main();
  widget_multipage.main();
  widget_partitions.main();
  widget_table.main();
  widget_text.main();
  widget_theme.main();
  widget_watermark.main();
  widget_wrap.main();
  widget.main();
}

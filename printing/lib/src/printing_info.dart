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

class PrintingInfo {
  factory PrintingInfo.fromMap(Map<dynamic, dynamic> map) => PrintingInfo._(
        directPrint: map['directPrint'] ?? false,
        dynamicLayout: map['dynamicLayout'] ?? false,
        canPrint: map['canPrint'],
        canConvertHtml: map['canConvertHtml'],
        canShare: map['canShare'],
        canRaster: map['canRaster'],
      );

  const PrintingInfo._({
    this.directPrint = false,
    this.dynamicLayout = false,
    this.canPrint = false,
    this.canConvertHtml = false,
    this.canShare = false,
    this.canRaster = false,
  })  : assert(directPrint != null),
        assert(dynamicLayout != null),
        assert(canPrint != null),
        assert(canConvertHtml != null),
        assert(canShare != null),
        assert(canRaster != null);

  static const PrintingInfo unavailable = PrintingInfo._();

  final bool directPrint;
  final bool dynamicLayout;
  final bool canPrint;
  final bool canConvertHtml;
  final bool canShare;
  final bool canRaster;
}

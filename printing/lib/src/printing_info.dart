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

/// Capabilities supported for the current platform
class PrintingInfo {
  /// Create an information object
  const PrintingInfo({
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

  /// Create an information object from a dictionnary
  factory PrintingInfo.fromMap(Map<dynamic, dynamic> map) => PrintingInfo(
        directPrint: map['directPrint'] ?? false,
        dynamicLayout: map['dynamicLayout'] ?? false,
        canPrint: map['canPrint'] ?? false,
        canConvertHtml: map['canConvertHtml'] ?? false,
        canShare: map['canShare'] ?? false,
        canRaster: map['canRaster'] ?? false,
      );

  /// Default information with no feature available
  static const PrintingInfo unavailable = PrintingInfo();

  /// The platform can print directly to a printer
  final bool directPrint;

  /// The platform can request a dynamic layout when the user change
  /// the printer or printer settings
  final bool dynamicLayout;

  /// The platform implementation is able to print a Pdf document
  final bool canPrint;

  /// The platform implementation is able to convert an html document to Pdf
  final bool canConvertHtml;

  /// The platform implementation is able to share a Pdf document
  /// to other applications
  final bool canShare;

  /// The platform implementation is able to convert pages from a Pdf document
  /// to a stream of images
  final bool canRaster;

  @override
  String toString() => '''PrintingInfo:
  canPrint: $canPrint
  directPrint: $directPrint
  dynamicLayout: $dynamicLayout
  canConvertHtml: $canConvertHtml
  canShare: $canShare
  canRaster: $canRaster''';

  /// Returns a map representation of this object
  Map<dynamic, dynamic> asMap() {
    return <dynamic, dynamic>{
      'canPrint': canPrint,
      'directPrint': directPrint,
      'dynamicLayout': dynamicLayout,
      'canConvertHtml': canConvertHtml,
      'canShare': canShare,
      'canRaster': canRaster,
    };
  }
}

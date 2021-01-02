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

import 'package:meta/meta.dart';

/// Information about a printer
@immutable
class Printer {
  /// Create a printer information
  const Printer({
    @required this.url,
    this.name,
    this.model,
    this.location,
    this.comment,
    this.isDefault = false,
    this.available = true,
  }) : assert(url != null);

  /// The platform specific printer identification
  final String url;

  /// The display name of the printer
  final String name;

  /// The printer model
  final String model;

  /// The physical location of the printer
  final String location;

  /// A user comment about the printer
  final String comment;

  /// Is this the default printer on the system
  final bool isDefault;

  /// The printer is available for printing
  final bool available;

  @override
  String toString() => name ?? url;
}

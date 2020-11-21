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

part of pdf;

mixin PdfGraphicStream on PdfObject {
  /// Isolated transparency: If this flag is true, objects within the group
  /// shall be composited against a fully transparent initial backdrop;
  /// if false, they shall be composited against the group’s backdrop
  bool isolatedTransparency = false;

  /// Whether the transparency group is a knockout group.
  /// If this flag is false, later objects within the group shall be composited
  /// with earlier ones with which they overlap; if true, they shall be
  /// composited with the group’s initial backdrop and shall overwrite any
  /// earlier overlapping objects.
  bool knockoutTransparency = false;

  /// The fonts associated with this page
  final Map<String, PdfFont> fonts = <String, PdfFont>{};

  /// The fonts associated with this page
  final Map<String, PdfShading> shading = <String, PdfShading>{};

  /// The xobjects or other images in the pdf
  final Map<String, PdfXObject> xObjects = <String, PdfXObject>{};

  void addFont(PdfFont font) {
    if (!fonts.containsKey(font.name)) {
      fonts[font.name] = font;
    }
  }

  void addShader(PdfShading shader) {
    if (!shading.containsKey(shader.name)) {
      shading[shader.name] = shader;
    }
  }

  void addXObject(PdfXObject object) {
    if (!xObjects.containsKey(object.name)) {
      xObjects[object.name] = object;
    }
  }

  PdfFont getDefaultFont() {
    if (pdfDocument.fonts.isEmpty) {
      PdfFont.helvetica(pdfDocument);
    }

    return pdfDocument.fonts.elementAt(0);
  }

  String stateName(PdfGraphicState state) {
    return pdfDocument.graphicStates.stateName(state);
  }

  @override
  void _prepare() {
    super._prepare();

    // This holds any resources for this page
    final resources = PdfDict();

    resources['/ProcSet'] = PdfArray(const <PdfName>[
      PdfName('/PDF'),
      PdfName('/Text'),
      PdfName('/ImageB'),
      PdfName('/ImageC'),
    ]);

    // fonts
    if (fonts.isNotEmpty) {
      resources['/Font'] = PdfDict.fromObjectMap(fonts);
    }

    // shading
    if (shading.isNotEmpty) {
      resources['/Shading'] = PdfDict.fromObjectMap(shading);
    }

    // Now the XObjects
    if (xObjects.isNotEmpty) {
      resources['/XObject'] = PdfDict.fromObjectMap(xObjects);
    }

    if (pdfDocument.hasGraphicStates) {
      // Declare Transparency Group settings
      params['/Group'] = PdfDict(<String, PdfDataType>{
        '/Type': const PdfName('/Group'),
        '/S': const PdfName('/Transparency'),
        '/CS': const PdfName('/DeviceRGB'),
        '/I': PdfBool(isolatedTransparency),
        '/K': PdfBool(knockoutTransparency),
      });

      resources['/ExtGState'] = pdfDocument.graphicStates.ref();
    }

    params['/Resources'] = resources;
  }
}

class PdfGraphicXObject extends PdfXObject with PdfGraphicStream {
  PdfGraphicXObject(
    PdfDocument pdfDocument, [
    String subtype,
  ]) : super(pdfDocument, subtype);
}

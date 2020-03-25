import 'dart:io';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:flutter_driver/driver_extension.dart';

final material.GlobalKey keyIcons = material.GlobalKey();
final material.GlobalKey keyText = material.GlobalKey();

final material.Widget appForTesting = material.MaterialApp(
  home: material.Scaffold(
    appBar: material.AppBar(
      title: const material.Text("Test for widgetWrapper"),
    ),
    body: material.Column(children: <material.Widget>[
      material.RepaintBoundary(
        key: keyIcons,
        child: material.Row(
          mainAxisAlignment: material.MainAxisAlignment.spaceAround,
          children: const <material.Widget>[
            material.Icon(
              material.Icons.favorite,
              color: material.Colors.pink,
              size: 24.0,
              semanticLabel: 'Text to announce in accessibility modes',
            ),
            material.Icon(
              material.Icons.audiotrack,
              color: material.Colors.green,
              size: 30.0,
            ),
            material.Icon(
              material.Icons.beach_access,
              color: material.Colors.blue,
              size: 36.0,
            ),
          ],
        ),
      ),
      material.RepaintBoundary(
        key: keyText,
        child: const material.MaterialApp(
          home: material.Text("Render this Text in the Pdf as an Image"),
        ),
      )
    ]),
  ),
);

void main() {
  enableFlutterDriverExtension();
  material.runApp(appForTesting);
}
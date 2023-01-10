import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

class RasterCheck extends StatefulWidget {
  const RasterCheck({Key? key}) : super(key: key);

  @override
  State<RasterCheck> createState() => _RasterCheckState();
}

class _RasterCheckState extends State<RasterCheck> {
  /// PDF file's url
  static const _url = '';

  final _futurePdf = http.readBytes(Uri.parse(_url));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raster check'),
      ),
      body: FutureBuilder<Uint8List>(
        future: _futurePdf,
        builder: (context, snapshot) {
          final error = snapshot.error;
          if (error != null) {
            return Center(
              child: Text('$error'),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final image = Printing.raster(data).first.then(
                (value) => value.toImage(),
              );
          return FutureBuilder<ui.Image>(
            future: image,
            builder: (context, snapshot) {
              final error = snapshot.error;
              if (error != null) {
                return Center(
                  child: Text('$error'),
                );
              }

              final data = snapshot.data;
              if (data == null) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              return RawImage(
                image: data,
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';

class ImageViewer extends StatelessWidget {
  const ImageViewer({this.images});

  final List<ImageProvider> images;

  Widget buildImage(BuildContext context, ImageProvider image) {
    return Card(
        margin: const EdgeInsets.all(10),
        child: FittedBox(
          child: Image(image: image),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document as Images'),
      ),
      body: ListView.builder(
        itemCount: images.length,
        itemBuilder: (BuildContext context, int index) =>
            buildImage(context, images[index]),
      ),
    );
  }
}

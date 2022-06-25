# PDF

Create a PDF document

## Getting Started 🚀

1. Add dependencies

```shell
flutter pub add intl pdf printing
```

1. Generate a document

```shell
mason make pdf --name invoice
```

1. Display the document

```dart
import 'package:flutter/material.dart';

import 'pdf/invoice.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PreviewInvoice(),
    );
  }
}
```

import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'stream.dart';

mixin PdfDiagnostic {
  static const _maxSize = 300;

  final _properties = <String>[];

  int? _offset;

  Stopwatch? _stopwatch;

  int get elapsedStopwatch => _stopwatch?.elapsedMicroseconds ?? 0;

  int size = 0;

  @protected
  @mustCallSuper
  void debugFill(String value) {
    assert(() {
      if (_properties.isEmpty) {
        _properties.add('');
        _properties.add('-' * 78);
        _properties.add('$runtimeType');
      }
      _properties.add(value);
      return true;
    }());
  }

  void setInsertion(PdfStream os, [int size = _maxSize]) {
    assert(() {
      this.size = size;
      _offset = os.offset;
      os.putComment(' ' * size);
      return true;
    }());
  }

  void writeDebug(PdfStream os) {
    assert(() {
      if (_offset != null) {
        final o = PdfStreamBuffer();
        _properties.forEach(o.putComment);
        final b = o.output();
        os.setBytes(
          _offset!,
          b.sublist(0, math.min(size + 2, b.lengthInBytes - 1)),
        );
      }
      return true;
    }());
  }

  void startStopwatch() {
    _stopwatch ??= Stopwatch();
    _stopwatch!.start();
  }

  void stopStopwatch() {
    _stopwatch?.stop();
  }
}

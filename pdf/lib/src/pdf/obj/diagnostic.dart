import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../stream.dart';

mixin PdfDiagnostic {
  static const _maxSize = 300;

  final _properties = <String>[];

  int? _offset;

  Stopwatch? _stopwatch;

  int get elapsedStopwatch => _stopwatch?.elapsedMicroseconds ?? 0;

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

  void setInsertion(PdfStream os) {
    assert(() {
      _offset = os.offset;
      os.putComment(' ' * _maxSize);
      return true;
    }());
  }

  void writeDebug(PdfStream os) {
    assert(() {
      if (_offset != null) {
        final o = PdfStream();
        _properties.forEach(o.putComment);
        _properties.forEach(print);
        final b = o.output();
        os.setBytes(
          _offset!,
          b.sublist(0, math.min(_maxSize + 2, b.lengthInBytes - 1)),
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

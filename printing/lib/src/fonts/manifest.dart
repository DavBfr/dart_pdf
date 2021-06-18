import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

/// Application asset manifest.
mixin AssetManifest {
  static final _assets = <String>[];

  static final _mutex = Mutex();

  static bool _ready = false;
  static bool _failed = false;

  /// Does is contains this key?
  static Future<bool> contains(String key) async {
    if (_failed) {
      return false;
    }

    await _mutex.acquire();
    try {
      if (!_ready) {
        try {
          final jsonString = await rootBundle.loadString('AssetManifest.json');
          final jsonData = json.decode(jsonString) as Map<String, dynamic>;
          _assets.addAll(jsonData.keys);
        } catch (e) {
          print('Error loading AssetManifest.json $e');
          rootBundle.evict('AssetManifest.json');
          _failed = true;
          _ready = true;
          return false;
        }
        _ready = true;
      }
    } finally {
      _mutex.release();
    }

    return _assets.contains(key);
  }
}

/// Simple Mutex
class Mutex {
  final _waiting = <Completer>[];

  bool _locked = false;

  /// Lock the mutex
  Future<void> acquire() async {
    if (_locked) {
      final c = Completer<void>();
      _waiting.add(c);
      await c.future;
    }
    _locked = true;
  }

  /// Release the mutex
  void release() {
    _locked = false;
    for (final e in _waiting) {
      e.complete();
    }
  }
}

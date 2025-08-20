// ignore_for_file: non_constant_identifier_names

import 'dart:ffi' as ffi;
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import 'harfbuzz_types.dart';
export 'harfbuzz_types.dart';

// This file needs library `harfbuzz` to be available in the environment.
// OSX: brew install harfbuzz
// Linux: apt-get install libharfbuzz-dev

// Documentation (functions + types): https://harfbuzz.github.io

typedef HarfbuzzBlob = HarfbuzzPointer<_HarfbuzzBlobStruct>;
typedef HarfbuzzFace = HarfbuzzPointer<_HarfbuzzFaceStruct>;
typedef HarfbuzzFont = HarfbuzzPointer<_HarfbuzzFontStruct>;
typedef HarfbuzzBuffer = HarfbuzzPointer<_HarfBuzzBufferStruct>;

@immutable
class HarfbuzzPointer<T extends ffi.NativeType> {
  final ffi.Pointer<T> _pointer;
  HarfbuzzPointer(this._pointer);
}

class HarfbuzzBinding {
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
      _lookup;

  HarfbuzzBinding()
      : _lookup = ffi.DynamicLibrary.open(_getHarfbuzzLibraryPath()).lookup;

  static String _getHarfbuzzLibraryPath() {
    // Check for environment variable override first
    final envPath = io.Platform.environment['HARFBUZZ_LIB_PATH'];
    if (envPath != null && envPath.isNotEmpty) {
      return envPath;
    }

    if (io.Platform.isMacOS) {
      return '/opt/homebrew/opt/harfbuzz/lib/libharfbuzz.dylib';
    }

    // For Linux, try common locations in order
    final commonPaths = [
      '/usr/lib/x86_64-linux-gnu/libharfbuzz.so.0',
      '/usr/lib/x86_64-linux-gnu/libharfbuzz.so',
      '/usr/lib/libharfbuzz.so.0',
      '/usr/lib/libharfbuzz.so',
      '/usr/lib64/libharfbuzz.so.0',
      '/usr/lib64/libharfbuzz.so',
      '/lib/x86_64-linux-gnu/libharfbuzz.so.0',
      '/lib/x86_64-linux-gnu/libharfbuzz.so',
    ];

    for (final path in commonPaths) {
      if (io.File(path).existsSync()) {
        return path;
      }
    }

    // Fallback to the original hardcoded path
    return '/usr/lib/x86_64-linux-gnu/libharfbuzz.so';
  }

  List<String> listLoaders() {
    final loaders = _listLoadersFunction();
    final output = <String>[];

    var index = 0;
    while (index < 10) {
      final current = (loaders + index).value;
      if (current == ffi.nullptr) break;
      output.add(current.toDartString());
      index++;
    }

    return output;
  }

  HarfbuzzFace faceFromFile(String filename, int faceIndex) {
    final blob = _blobFromFileFunction(filename.toNativeUtf8());
    final face = HarfbuzzFace(_faceCreateFunction(blob, faceIndex));
    _blobDestroyFunction(blob);
    return face;
  }

  HarfbuzzFace faceFromData(ByteData data, int faceIndex) {
    final buffer = calloc<ffi.Uint8>(data.lengthInBytes);
    buffer
        .asTypedList(data.buffer.lengthInBytes)
        .setAll(0, data.buffer.asUint8List());
    // 0: HB_MEMORY_MODE_DUPLICATE
    final blob = _blobCreateFunction(
        buffer, data.lengthInBytes, 0, ffi.nullptr, ffi.nullptr);
    final face = HarfbuzzFace(_faceCreateFunction(blob, faceIndex));
    _blobDestroyFunction(blob);
    calloc.free(buffer);
    return face;
  }

  void faceDestroy(HarfbuzzFace face) => _faceDestroyFunction(face._pointer);

  String faceGetName(HarfbuzzFace face, HarfBuzzName name) {
    final count = calloc<ffi.Uint32>();
    count.value = 32;
    final outputString = ('A' * count.value).toNativeUtf8();
    _faceGetNameFunction(face._pointer, name.value, 0, count, outputString);
    return outputString.toDartString(length: count.value);
  }

  List<IntPair> faceGetUnicodes(HarfbuzzFace face) {
    final output = <IntPair>[];

    final codes = _setCreateFunction();
    _faceCollectUnicodesFunction(face._pointer, codes);

    final first = calloc<ffi.Uint32>();
    first.value = -1;

    final last = calloc<ffi.Uint32>();
    last.value = -1;

    while (true) {
      final ret = _setNextRangeFunction(codes, first, last);
      output.add(IntPair(first.value, last.value));
      if (!ret) {
        break;
      }
    }

    _setDestroyFunction(codes);

    return output;
  }

  HarfbuzzFont fontCreate(HarfbuzzFace face) =>
      HarfbuzzFont(_fontCreateFunction(face._pointer));
  void fontDestroy(HarfbuzzFont font) => _fontDestroyFunction(font._pointer);

  double fontStyleGetValue(HarfbuzzFont font, HarfBuzzStyle style) {
    return _fontStyleGetValueFunction(font._pointer, style.value);
  }

  void fontSetScale(HarfbuzzFont font, double xScale, double yScale) =>
      _fontSetScaleFunction(
        font._pointer,
        (xScale * _SCALE).toInt(),
        (yScale * _SCALE).toInt(),
      );
  HarfbuzzFontExtents fontExtentsForDirection(
    HarfbuzzFont font,
    HarfBuzzDirection direction,
  ) {
    final extents = calloc<_HarfBuzzFontExtentsStruct>();
    _fontExtentsForDirectionFunction(font._pointer, direction.value, extents);
    return HarfbuzzFontExtents(
      extents.ref.ascender / _SCALE,
      extents.ref.descender / _SCALE,
      extents.ref.line_gap / _SCALE,
    );
  }

  HarfbuzzBuffer bufferCreate() => HarfbuzzBuffer(_bufferCreateFunction());
  void bufferDestroy(HarfbuzzBuffer buffer) =>
      _bufferDestroyFunction(buffer._pointer);

  void bufferAddString(HarfbuzzBuffer buffer, String str) =>
      _bufferAddStrFunction(buffer._pointer, str.toNativeUtf8(), -1, 0, -1);

  void bufferGuessSegmentProperties(HarfbuzzBuffer buffer) =>
      _bufferGuessSegmentPropertiesFunction(buffer._pointer);

  HarfBuzzDirection bufferGetDirection(HarfbuzzBuffer buffer) =>
      HarfBuzzDirection.values.firstWhere(
          (v) => v.value == _bufferGetDirectionFunction(buffer._pointer),
          orElse: () => HarfBuzzDirection.invalid);

  void shape(HarfbuzzFont font, HarfbuzzBuffer buffer) =>
      _shapeFunction(font._pointer, buffer._pointer, ffi.nullptr, 0);

  List<HarfbuzzGlyphPosition> getGlyphPositions(HarfbuzzBuffer buffer) {
    final count = malloc<ffi.Uint32>();
    final pointer = _getGlyphsPositionsFunction(buffer._pointer, count);
    return [
      for (var i = 0; i < count.value; i++)
        HarfbuzzGlyphPosition(
          pointer[i].x_advance / _SCALE,
          pointer[i].y_advance / _SCALE,
          pointer[i].x_offset / _SCALE,
          pointer[i].y_offset / _SCALE,
        ),
    ];
  }

  List<HarfbuzzGlyphInfo> getGlyphInfos(HarfbuzzBuffer buffer) {
    final count = malloc<ffi.Uint32>();
    final pointer = _getGlyphsInfosFunction(buffer._pointer, count);
    return [
      for (var i = 0; i < count.value; i++)
        HarfbuzzGlyphInfo(pointer[i].codepoint, pointer[i].cluster),
    ];
  }

  // Private

  static const _SCALE = 64.0;

  late final _listLoadersFunctionPtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<ffi.Pointer<Utf8>> Function()>>(
    'hb_face_list_loaders',
  );
  late final _listLoadersFunction = _listLoadersFunctionPtr
      .asFunction<ffi.Pointer<ffi.Pointer<Utf8>> Function()>();

  // Blob

  late final _blobFromFileFunctionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<_HarfbuzzBlobStruct> Function(
              ffi.Pointer<Utf8>)>>('hb_blob_create_from_file');
  late final _blobFromFileFunction = _blobFromFileFunctionPtr
      .asFunction<_HarfbuzzBlob Function(ffi.Pointer<Utf8>)>();

  late final _blobCreateFunctionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<_HarfbuzzBlobStruct> Function(
              ffi.Pointer<ffi.Uint8>,
              ffi.Int,
              ffi.Int,
              ffi.Pointer<ffi.Uint8>,
              ffi.Pointer<ffi.Uint8>)>>('hb_blob_create');
  late final _blobCreateFunction = _blobCreateFunctionPtr.asFunction<
      _HarfbuzzBlob Function(ffi.Pointer<ffi.Uint8>, int, int,
          ffi.Pointer<ffi.Uint8>, ffi.Pointer<ffi.Uint8>)>();

  late final _blobDestroyFunctionPtr = _lookup<
          ffi
          .NativeFunction<ffi.Void Function(ffi.Pointer<_HarfbuzzBlobStruct>)>>(
      'hb_blob_destroy');
  late final _blobDestroyFunction =
      _blobDestroyFunctionPtr.asFunction<void Function(_HarfbuzzBlob)>();

  // Face

  late final _faceCreateFunctionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<_HarfbuzzFaceStruct> Function(
            ffi.Pointer<_HarfbuzzBlobStruct>,
            ffi.Int,
          )>>('hb_face_create');
  late final _faceCreateFunction = _faceCreateFunctionPtr
      .asFunction<_HarfbuzzFace Function(_HarfbuzzBlob, int)>();

  late final _faceDestroyFunctionPtr = _lookup<
          ffi
          .NativeFunction<ffi.Void Function(ffi.Pointer<_HarfbuzzFaceStruct>)>>(
      'hb_face_destroy');
  late final _faceDestroyFunction =
      _faceDestroyFunctionPtr.asFunction<void Function(_HarfbuzzFace)>();

  late final _faceGetNameFunctionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Uint32 Function(
            ffi.Pointer<_HarfbuzzFaceStruct>,
            ffi.Uint32,
            ffi.Uint32,
            ffi.Pointer<ffi.Uint32>,
            ffi.Pointer<Utf8>,
          )>>('hb_ot_name_get_utf8');
  late final _faceGetNameFunction = _faceGetNameFunctionPtr.asFunction<
      int Function(
        _HarfbuzzFace,
        int,
        int,
        ffi.Pointer<ffi.Uint32>,
        ffi.Pointer<Utf8>,
      )>();

  late final _faceCollectUnicodesFunctionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(
            ffi.Pointer<_HarfbuzzFaceStruct>,
            ffi.Pointer<_HarfBuzzSetStruct>,
          )>>('hb_face_collect_unicodes');
  late final _faceCollectUnicodesFunction = _faceCollectUnicodesFunctionPtr
      .asFunction<void Function(_HarfbuzzFace, _HarfbuzzSet)>();

  // Font

  late final _fontCreateFunctionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<_HarfbuzzFontStruct> Function(
            ffi.Pointer<_HarfbuzzFaceStruct>,
          )>>('hb_font_create');
  late final _fontCreateFunction = _fontCreateFunctionPtr
      .asFunction<_HarfbuzzFont Function(_HarfbuzzFace)>();

  late final _fontDestroyFunctionPtr = _lookup<
          ffi
          .NativeFunction<ffi.Void Function(ffi.Pointer<_HarfbuzzFontStruct>)>>(
      'hb_font_destroy');
  late final _fontDestroyFunction =
      _fontDestroyFunctionPtr.asFunction<void Function(_HarfbuzzFont)>();

  late final _fontStyleGetValueFunctionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Float Function(ffi.Pointer<_HarfbuzzFontStruct>,
              ffi.Int32)>>('hb_style_get_value');
  late final _fontStyleGetValueFunction = _fontStyleGetValueFunctionPtr
      .asFunction<double Function(_HarfbuzzFont, int)>();

  late final _fontSetScaleFunctionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(ffi.Pointer<_HarfbuzzFontStruct>, ffi.Int,
              ffi.Int)>>('hb_font_set_scale');
  late final _fontSetScaleFunction = _fontSetScaleFunctionPtr
      .asFunction<void Function(_HarfbuzzFont, int, int)>();

  late final _fontExtentsForDirectionFunctionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Bool Function(
            ffi.Pointer<_HarfbuzzFontStruct>,
            ffi.Int32,
            ffi.Pointer<_HarfBuzzFontExtentsStruct>,
          )>>('hb_font_get_extents_for_direction');
  late final _fontExtentsForDirectionFunction =
      _fontExtentsForDirectionFunctionPtr.asFunction<
          bool Function(_HarfbuzzFont, int, _HarfbuzzFontExtents)>();

  // Buffer

  late final _bufferCreateFunctionPtr = _lookup<
          ffi.NativeFunction<ffi.Pointer<_HarfBuzzBufferStruct> Function()>>(
      'hb_buffer_create');
  late final _bufferCreateFunction =
      _bufferCreateFunctionPtr.asFunction<_HarfbuzzBuffer Function()>();

  late final _bufferDestroyFunctionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(
              ffi.Pointer<_HarfBuzzBufferStruct>)>>('hb_buffer_destroy');
  late final _bufferDestroyFunction =
      _bufferDestroyFunctionPtr.asFunction<void Function(_HarfbuzzBuffer)>();

  late final _bufferAddStrFunctionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(
            ffi.Pointer<_HarfBuzzBufferStruct>,
            ffi.Pointer<Utf8>,
            ffi.Int,
            ffi.UnsignedInt,
            ffi.Int,
          )>>('hb_buffer_add_utf8');
  late final _bufferAddStrFunction = _bufferAddStrFunctionPtr.asFunction<
      void Function(_HarfbuzzBuffer, ffi.Pointer<Utf8>, int, int, int)>();

  late final _bufferGuessSegmentPropertiesFunctionPtr = _lookup<
          ffi.NativeFunction<
              ffi.Void Function(ffi.Pointer<_HarfBuzzBufferStruct>)>>(
      'hb_buffer_guess_segment_properties');
  late final _bufferGuessSegmentPropertiesFunction =
      _bufferGuessSegmentPropertiesFunctionPtr
          .asFunction<void Function(_HarfbuzzBuffer)>();

  late final _bufferGetDirectionFunctionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Int32 Function(
              ffi.Pointer<_HarfBuzzBufferStruct>)>>('hb_buffer_get_direction');
  late final _bufferGetDirectionFunction = _bufferGetDirectionFunctionPtr
      .asFunction<int Function(_HarfbuzzBuffer)>();

  late final _shapeFunctionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(
            ffi.Pointer<_HarfbuzzFontStruct>,
            ffi.Pointer<_HarfBuzzBufferStruct>,
            ffi.Pointer<_HarfBuzzFeatureStruct>,
            ffi.Int,
          )>>('hb_shape');
  late final _shapeFunction = _shapeFunctionPtr.asFunction<
      void Function(_HarfbuzzFont, _HarfbuzzBuffer, _HarfbuzzFeature, int)>();

  late final _getGlyphsPositionsFunctionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<_HarfBuzzGlyphPositionStruct> Function(
            ffi.Pointer<_HarfBuzzBufferStruct>,
            ffi.Pointer<ffi.Uint32>,
          )>>('hb_buffer_get_glyph_positions');
  late final _getGlyphsPositionsFunction =
      _getGlyphsPositionsFunctionPtr.asFunction<
          ffi.Pointer<_HarfBuzzGlyphPositionStruct> Function(
            _HarfbuzzBuffer,
            ffi.Pointer<ffi.Uint32>,
          )>();

  late final _getGlyphsInfosFunctionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<_HarfBuzzGlyphInfoStruct> Function(
            ffi.Pointer<_HarfBuzzBufferStruct>,
            ffi.Pointer<ffi.Uint32>,
          )>>('hb_buffer_get_glyph_infos');
  late final _getGlyphsInfosFunction = _getGlyphsInfosFunctionPtr.asFunction<
      ffi.Pointer<_HarfBuzzGlyphInfoStruct> Function(
        _HarfbuzzBuffer,
        ffi.Pointer<ffi.Uint32>,
      )>();

  // Set

  late final _setCreateFunctionPtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<_HarfBuzzSetStruct> Function()>>(
    'hb_set_create',
  );
  late final _setCreateFunction =
      _setCreateFunctionPtr.asFunction<_HarfbuzzSet Function()>();

  late final _setDestroyFunctionPtr = _lookup<
          ffi
          .NativeFunction<ffi.Void Function(ffi.Pointer<_HarfBuzzSetStruct>)>>(
      'hb_set_destroy');
  late final _setDestroyFunction =
      _setDestroyFunctionPtr.asFunction<void Function(_HarfbuzzSet)>();

  late final _setNextRangeFunctionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Bool Function(
            ffi.Pointer<_HarfBuzzSetStruct>,
            ffi.Pointer<ffi.Uint32>,
            ffi.Pointer<ffi.Uint32>,
          )>>('hb_set_next_range');
  late final _setNextRangeFunction = _setNextRangeFunctionPtr.asFunction<
      bool Function(
        _HarfbuzzSet,
        ffi.Pointer<ffi.Uint32>,
        ffi.Pointer<ffi.Uint32>,
      )>();
}

// Private types

final class _HarfbuzzBlobStruct extends ffi.Opaque {}

final class _HarfbuzzFaceStruct extends ffi.Opaque {}

final class _HarfbuzzFontStruct extends ffi.Opaque {}

final class _HarfBuzzBufferStruct extends ffi.Opaque {}

final class _HarfBuzzSetStruct extends ffi.Opaque {}

final class _HarfBuzzFeatureStruct extends ffi.Struct {
  @ffi.Uint32()
  external int tag;

  @ffi.Uint32()
  external int value;

  @ffi.UnsignedInt()
  external int start;

  @ffi.UnsignedInt()
  external int end;
}

final class _HarfBuzzGlyphPositionStruct extends ffi.Struct {
  @ffi.Int32()
  external int x_advance;

  @ffi.Int32()
  external int y_advance;

  @ffi.Int32()
  external int x_offset;

  @ffi.Int32()
  external int y_offset;

  @ffi.Int32()
  external int reserved;
}

final class _HarfBuzzGlyphInfoStruct extends ffi.Struct {
  @ffi.Int32()
  external int codepoint;

  @ffi.Int32()
  external int mask;

  @ffi.Int32()
  external int cluster;

  @ffi.Int32()
  external int var1;

  @ffi.Int32()
  external int var2;
}

final class _HarfBuzzFontExtentsStruct extends ffi.Struct {
  @ffi.Int32()
  external int ascender;
  @ffi.Int32()
  external int descender;
  @ffi.Int32()
  external int line_gap;
  @ffi.Int32()
  external int reserved9;
  @ffi.Int32()
  external int reserved8;
  @ffi.Int32()
  external int reserved7;
  @ffi.Int32()
  external int reserved6;
  @ffi.Int32()
  external int reserved5;
  @ffi.Int32()
  external int reserved4;
  @ffi.Int32()
  external int reserved3;
  @ffi.Int32()
  external int reserved2;
  @ffi.Int32()
  external int reserved1;
}

typedef _HarfbuzzBlob = ffi.Pointer<_HarfbuzzBlobStruct>;
typedef _HarfbuzzFace = ffi.Pointer<_HarfbuzzFaceStruct>;
typedef _HarfbuzzFont = ffi.Pointer<_HarfbuzzFontStruct>;
typedef _HarfbuzzBuffer = ffi.Pointer<_HarfBuzzBufferStruct>;
typedef _HarfbuzzFeature = ffi.Pointer<_HarfBuzzFeatureStruct>;
typedef _HarfbuzzFontExtents = ffi.Pointer<_HarfBuzzFontExtentsStruct>;
typedef _HarfbuzzSet = ffi.Pointer<_HarfBuzzSetStruct>;

class Pair<T> {
  const Pair(this.first, this.second);
  final T first;
  final T second;
}

typedef IntPair = Pair<int>;

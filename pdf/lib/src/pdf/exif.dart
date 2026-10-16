/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'dart:typed_data';

import '../../pdf.dart' show PdfException;
import 'obj/image.dart';

/// Jpeg metadata extraction
class PdfJpegInfo {
  /// Load a Jpeg image's metadata
  factory PdfJpegInfo(Uint8List image) {
    final buffer = image.buffer.asByteData(
      image.offsetInBytes,
      image.lengthInBytes,
    );
    final length = buffer.lengthInBytes;

    int? width;
    int? height;
    int? color;
    int? adobeColorTransform;
    var hasAdobeMarker = false;
    var offset = 0;

    // Every read below is on bytes someone else wrote, so the walk stops at the
    // end of the buffer rather than reading past it: a truncated upload used to
    // throw a bare RangeError out of PdfImage.jpeg and abort the document.
    while (offset < length) {
      while (offset < length && buffer.getUint8(offset) == 0xff) {
        offset++;
      }
      if (offset >= length) {
        break;
      }

      final mrkr = buffer.getUint8(offset);
      offset++;

      if (mrkr == 0xd8) {
        continue; // SOI
      }

      if (mrkr == 0xd9) {
        break; // EOI
      }

      if (0xd0 <= mrkr && mrkr <= 0xd7) {
        continue;
      }

      if (mrkr == 0x01) {
        continue; // TEM
      }

      if (offset + 2 > length) {
        break;
      }
      final len = buffer.getUint16(offset);
      offset += 2;

      // A declared length of 0 or 1 would move the cursor backwards and spin
      // here for ever.
      if (len < 2) {
        break;
      }

      if (mrkr >= 0xc0 && mrkr <= 0xc2) {
        if (offset + 6 > length) {
          break;
        }
        height = buffer.getUint16(offset + 1);
        width = buffer.getUint16(offset + 3);
        color = buffer.getUint8(offset + 5);
        break;
      }

      // Adobe APP14 marker. Its presence is what says the CMYK samples are
      // inverted; the transform byte says which flavour, and is only there if the
      // segment is long enough to hold it. One field used to mean both, so a
      // transform of 0 was indistinguishable from no marker at all.
      if (mrkr == 0xee && offset + 5 <= length) {
        if (buffer.getUint8(offset) == 0x41 &&
            buffer.getUint8(offset + 1) == 0x64 &&
            buffer.getUint8(offset + 2) == 0x6F &&
            buffer.getUint8(offset + 3) == 0x62 &&
            buffer.getUint8(offset + 4) == 0x65) {
          hasAdobeMarker = true;
          if (len >= 14 && offset + 12 <= length) {
            adobeColorTransform = buffer.getUint8(offset + 11);
          }
        }
      }

      offset += len - 2;
    }

    if (height == null) {
      throw PdfException('Unable to find a Jpeg image in the file');
    }

    // An EXIF block that does not parse means no tags, not a failed image.
    Map<PdfExifTag, dynamic>? tags;
    try {
      tags = _findExifInJpeg(buffer);
    } on RangeError {
      tags = <PdfExifTag, dynamic>{};
    }

    return PdfJpegInfo._(
      width,
      height,
      color,
      adobeColorTransform,
      hasAdobeMarker,
      tags,
    );
  }

  PdfJpegInfo._(
    this.width,
    this.height,
    this._color,
    this._adobeColorTransform,
    this._hasAdobeMarker,
    this.tags,
  );

  /// Width of the image
  final int? width;

  /// Height of the image
  final int height;

  final int? _color;

  final int? _adobeColorTransform;

  /// Whether an APP14 'Adobe' segment is present at all, which is a different
  /// question from what its transform byte says.
  final bool _hasAdobeMarker;

  /// Is the image color or greyscale
  bool get isRGB => _color == 3;

  /// Whether the image uses CMYK color space (4 components)
  bool get isCMYK => _color == 4;

  /// The Adobe APP14 colour transform, if the marker carried one.
  int? get adobeColorTransform => _adobeColorTransform;

  /// Whether an APP14 'Adobe' segment is present.
  bool get hasAdobeMarker => _hasAdobeMarker;

  /// Whether this CMYK JPEG stores inverted sample values.
  ///
  /// Every writer that emits the APP14 'Adobe' marker stores CMYK inverted,
  /// whatever its transform byte says - transform 0 means the components were not
  /// transformed, not that they were not inverted. A four-component JPEG with no
  /// Adobe marker is stored straight.
  bool get isCMYKInverted => isCMYK && _hasAdobeMarker;

  /// Exif tags discovered
  final Map<PdfExifTag, dynamic>? tags;

  /// A tag value as an int, whatever shape the file declared it in.
  ///
  /// _readTagValue hands back an int, a String, a double, a typed integer or
  /// float list, a list of numerator/denominator pairs, or null, depending on the
  /// type and count bytes - all of them attacker-controlled. Every accessor here
  /// used to assume the one shape it wanted.
  int? _asInt(PdfExifTag tag) {
    final dynamic value = tags?[tag];

    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.isFinite ? value.round() : null;
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    if (value is List) {
      if (value.isEmpty) {
        return null;
      }
      final dynamic first = value.first;
      if (first is int) {
        return first;
      }
      if (first is double) {
        return first.isFinite ? first.round() : null;
      }
      if (first is List && first.isNotEmpty && first.first is int) {
        return first.first as int;
      }
    }
    return null;
  }

  /// A tag value as a list of bytes, for the version tags.
  List<int>? _asBytes(PdfExifTag tag) {
    final dynamic value = tags?[tag];

    if (value is List<int>) {
      return value;
    }
    if (value is int) {
      return <int>[value];
    }
    if (value is String) {
      return utf8.encode(value);
    }
    return null;
  }

  /// A rational tag as a double, however it was stored.
  double? _asRational(PdfExifTag tag) {
    final dynamic value = tags?[tag];

    if (value is List && value.length >= 2) {
      final dynamic numerator = value[0];
      final dynamic denominator = value[1];
      if (numerator is num && denominator is num && denominator != 0) {
        return numerator.toDouble() / denominator.toDouble();
      }
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  /// EXIF version
  String? get exifVersion {
    final bytes = _asBytes(PdfExifTag.ExifVersion);
    return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
  }

  /// Flashpix format version
  String? get flashpixVersion {
    final bytes = _asBytes(PdfExifTag.FlashpixVersion);
    return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
  }

  /// Rotation angle of this image
  PdfImageOrientation get orientation {
    final value = _asInt(PdfExifTag.Orientation);
    if (value == null ||
        value < 1 ||
        value > PdfImageOrientation.values.length) {
      return PdfImageOrientation.topLeft;
    }

    return PdfImageOrientation.values[value - 1];
  }

  /// Exif horizontal resolution
  double? get xResolution => _asRational(PdfExifTag.XResolution);

  /// Exif vertical resolution
  double? get yResolution => _asRational(PdfExifTag.YResolution);

  /// Exif horizontal pixel dimension
  int? get pixelXDimension => _asInt(PdfExifTag.PixelXDimension) ?? width;

  /// Exif vertical pixel dimension
  int? get pixelYDimension => _asInt(PdfExifTag.PixelYDimension) ?? height;

  @override
  String toString() =>
      '''width: $width height: $height
exifVersion: $exifVersion flashpixVersion: $flashpixVersion
xResolution: $xResolution yResolution: $yResolution
pixelXDimension: $pixelXDimension pixelYDimension: $pixelYDimension
orientation: $orientation''';

  static Map<PdfExifTag, dynamic>? _findExifInJpeg(ByteData buffer) {
    final length = buffer.lengthInBytes;
    if (length < 4 ||
        buffer.getUint8(0) != 0xFF ||
        buffer.getUint8(1) != 0xD8) {
      return <PdfExifTag, dynamic>{}; // Not a valid JPEG
    }

    var offset = 2;
    int marker;

    while (offset + 4 <= length) {
      final lastValue = buffer.getUint8(offset);
      if (lastValue != 0xFF) {
        return <
          PdfExifTag,
          dynamic
        >{}; // Not a valid marker at offset $offset, found: $lastValue
      }

      marker = buffer.getUint8(offset + 1);

      // we could implement handling for other markers here,
      // but we're only looking for 0xFFE1 for EXIF data
      if (marker == 0xE1) {
        return _readEXIFData(buffer, offset + 4);
      }

      final segment = buffer.getUint16(offset + 2);
      if (segment < 2) {
        break; // Would move the cursor backwards and spin here for ever.
      }
      offset += 2 + segment;
    }

    return <PdfExifTag, dynamic>{};
  }

  static Map<PdfExifTag, dynamic> _readTags(
    ByteData file,
    int tiffStart,
    int dirStart,
    Endian bigEnd,
  ) {
    final tags = <PdfExifTag, dynamic>{};
    if (dirStart < 0 || dirStart + 2 > file.lengthInBytes) {
      return tags;
    }

    final entries = file.getUint16(dirStart, bigEnd);
    int entryOffset;

    for (var i = 0; i < entries; i++) {
      entryOffset = dirStart + i * 12 + 2;
      // The entry count is a uint16 read before any of the entries exist, so
      // 0xffff of them can be declared in a file that holds none.
      if (entryOffset + 12 > file.lengthInBytes) {
        break;
      }
      final tagId = file.getUint16(entryOffset, bigEnd);
      final tag = _exifTags[tagId];
      if (tag != null) {
        tags[tag] = _readTagValue(
          file,
          entryOffset,
          tiffStart,
          dirStart,
          bigEnd,
        );
      }
    }
    return tags;
  }

  /// How many bytes one value of each EXIF type takes.
  static const Map<int, int> _typeSize = <int, int>{
    1: 1, // byte
    2: 1, // ascii
    3: 2, // short
    4: 4, // long
    5: 8, // rational
    6: 1, // signed byte
    7: 1, // undefined
    8: 2, // signed short
    9: 4, // signed long
    10: 8, // signed rational
    11: 4, // float
    12: 8, // double
  };

  static dynamic _readTagValue(
    ByteData file,
    int entryOffset,
    int tiffStart,
    int dirStart,
    Endian bigEnd,
  ) {
    final type = file.getUint16(entryOffset + 2, bigEnd);
    final numValues = file.getUint32(entryOffset + 4, bigEnd);

    // numValues came straight off the wire and was used as the allocation size
    // and the loop bound for every typed list below, so a 60-byte file could ask
    // for 32 GiB or read a gigabyte past its own end. The declared extent has to
    // fit in the buffer before anything is allocated, and a count of zero is not
    // a value at all - it used to underflow the ASCII length to -1.
    final elementSize = _typeSize[type];
    if (elementSize == null || numValues == 0) {
      return null;
    }

    final byteCount = numValues * elementSize;
    if (byteCount > file.lengthInBytes) {
      return null;
    }

    // Four bytes or fewer live in the value field itself; anything larger is out
    // of line. Deciding on the byte count rather than the value count is also
    // what stops a single DOUBLE reading eight bytes from that four-byte field.
    final int offset;
    if (byteCount <= 4) {
      offset = entryOffset + 8;
    } else {
      offset = file.getUint32(entryOffset + 8, bigEnd) + tiffStart;
    }

    if (offset < 0 || offset + byteCount > file.lengthInBytes) {
      return null;
    }

    switch (type) {
      case 1: // byte, 8-bit unsigned int
      case 6: // signed byte
      case 7: // undefined, 8-bit byte, value depending on field
        if (numValues == 1) {
          return file.getUint8(offset);
        }
        final result = Uint8List(numValues);
        for (var i = 0; i < result.length; ++i) {
          result[i] = file.getUint8(offset + i);
        }
        return result;
      case 2: // ascii, 8-bit byte
        // The declared length includes the trailing NUL.
        return _getStringFromDB(file, offset, numValues - 1);
      case 3: // short, 16 bit int
        if (numValues == 1) {
          return file.getUint16(offset, bigEnd);
        }
        final result = Uint16List(numValues);
        for (var i = 0; i < result.length; ++i) {
          result[i] = file.getUint16(offset + i * 2, bigEnd);
        }
        return result;
      case 8: // signed short
        if (numValues == 1) {
          return file.getInt16(offset, bigEnd);
        }
        final result = Int16List(numValues);
        for (var i = 0; i < result.length; ++i) {
          result[i] = file.getInt16(offset + i * 2, bigEnd);
        }
        return result;
      case 4: // long, 32 bit int
        if (numValues == 1) {
          return file.getUint32(offset, bigEnd);
        }
        final result = Uint32List(numValues);
        for (var i = 0; i < result.length; ++i) {
          result[i] = file.getUint32(offset + i * 4, bigEnd);
        }
        return result;
      case 5: // rational: a numerator and a denominator, both long
        if (numValues == 1) {
          return <int>[
            file.getUint32(offset, bigEnd),
            file.getUint32(offset + 4, bigEnd),
          ];
        }
        final result = <List<int>>[];
        for (var i = 0; i < numValues; ++i) {
          result.add(<int>[
            file.getUint32(offset + i * 8, bigEnd),
            file.getUint32(offset + i * 8 + 4, bigEnd),
          ]);
        }
        return result;
      case 9: // slong, 32 bit signed int
        if (numValues == 1) {
          return file.getInt32(offset, bigEnd);
        }
        final result = Int32List(numValues);
        for (var i = 0; i < result.length; ++i) {
          result[i] = file.getInt32(offset + i * 4, bigEnd);
        }
        return result;
      case 10: // signed rational, two slongs
        if (numValues == 1) {
          return <int>[
            file.getInt32(offset, bigEnd),
            file.getInt32(offset + 4, bigEnd),
          ];
        }
        final result = <List<int>>[];
        for (var i = 0; i < numValues; ++i) {
          result.add(<int>[
            file.getInt32(offset + i * 8, bigEnd),
            file.getInt32(offset + i * 8 + 4, bigEnd),
          ]);
        }
        return result;
      case 11: // single float, 32 bit float
        if (numValues == 1) {
          return file.getFloat32(offset, bigEnd);
        }
        final result = Float32List(numValues);
        for (var i = 0; i < result.length; ++i) {
          result[i] = file.getFloat32(offset + i * 4, bigEnd);
        }
        return result;
      case 12: // double float, 64 bit float
        if (numValues == 1) {
          return file.getFloat64(offset, bigEnd);
        }
        final result = Float64List(numValues);
        for (var i = 0; i < result.length; ++i) {
          result[i] = file.getFloat64(offset + i * 8, bigEnd);
        }
        return result;
    }

    return null;
  }

  static String _getStringFromDB(ByteData buffer, int start, int length) {
    // A declared length of 0 used to underflow to -1 here, and nothing stopped a
    // declared length from running off the end of the buffer.
    final from = start.clamp(0, buffer.lengthInBytes);
    final to = (start + length).clamp(from, buffer.lengthInBytes);

    return utf8.decode(
      Uint8List.sublistView(buffer, from, to),
      allowMalformed: true,
    );
  }

  static Map<PdfExifTag, dynamic>? _readEXIFData(ByteData buffer, int start) {
    if (start < 0 || start + 14 > buffer.lengthInBytes) {
      return null;
    }

    final startingString = _getStringFromDB(buffer, start, 4);
    if (startingString != 'Exif') {
      // Not valid EXIF data! $startingString
      return null;
    }

    Endian bigEnd;
    final tiffOffset = start + 6;

    // test for TIFF validity and endianness
    if (buffer.getUint16(tiffOffset) == 0x4949) {
      bigEnd = Endian.little;
    } else if (buffer.getUint16(tiffOffset) == 0x4D4D) {
      bigEnd = Endian.big;
    } else {
      // Not valid TIFF data! (no 0x4949 or 0x4D4D)
      return null;
    }

    if (buffer.getUint16(tiffOffset + 2, bigEnd) != 0x002A) {
      // Not valid TIFF data! (no 0x002A)
      return null;
    }

    final firstIFDOffset = buffer.getUint32(tiffOffset + 4, bigEnd);

    if (firstIFDOffset < 0x00000008) {
      // Not valid TIFF data! (First offset less than 8) $firstIFDOffset
      return null;
    }

    final tags = _readTags(
      buffer,
      tiffOffset,
      tiffOffset + firstIFDOffset,
      bigEnd,
    );

    final pointer = tags[PdfExifTag.ExifIFDPointer];
    if (pointer is int) {
      tags.addAll(_readTags(buffer, tiffOffset, tiffOffset + pointer, bigEnd));
    }

    return tags;
  }

  static const Map<int, PdfExifTag> _exifTags = <int, PdfExifTag>{
    0x9000: PdfExifTag.ExifVersion,
    0xA000: PdfExifTag.FlashpixVersion,
    0xA001: PdfExifTag.ColorSpace,
    0xA002: PdfExifTag.PixelXDimension,
    0xA003: PdfExifTag.PixelYDimension,
    0x9101: PdfExifTag.ComponentsConfiguration,
    0x9102: PdfExifTag.CompressedBitsPerPixel,
    0x927C: PdfExifTag.MakerNote,
    0x9286: PdfExifTag.UserComment,
    0xA004: PdfExifTag.RelatedSoundFile,
    0x9003: PdfExifTag.DateTimeOriginal,
    0x9004: PdfExifTag.DateTimeDigitized,
    0x9290: PdfExifTag.SubsecTime,
    0x9291: PdfExifTag.SubsecTimeOriginal,
    0x9292: PdfExifTag.SubsecTimeDigitized,
    0x829A: PdfExifTag.ExposureTime,
    0x829D: PdfExifTag.FNumber,
    0x8822: PdfExifTag.ExposureProgram,
    0x8824: PdfExifTag.SpectralSensitivity,
    0x8827: PdfExifTag.ISOSpeedRatings,
    0x8828: PdfExifTag.OECF,
    0x9201: PdfExifTag.ShutterSpeedValue,
    0x9202: PdfExifTag.ApertureValue,
    0x9203: PdfExifTag.BrightnessValue,
    0x9204: PdfExifTag.ExposureBias,
    0x9205: PdfExifTag.MaxApertureValue,
    0x9206: PdfExifTag.SubjectDistance,
    0x9207: PdfExifTag.MeteringMode,
    0x9208: PdfExifTag.LightSource,
    0x9209: PdfExifTag.Flash,
    0x9214: PdfExifTag.SubjectArea,
    0x920A: PdfExifTag.FocalLength,
    0xA20B: PdfExifTag.FlashEnergy,
    0xA20C: PdfExifTag.SpatialFrequencyResponse,
    0xA20E: PdfExifTag.FocalPlaneXResolution,
    0xA20F: PdfExifTag.FocalPlaneYResolution,
    0xA210: PdfExifTag.FocalPlaneResolutionUnit,
    0xA214: PdfExifTag.SubjectLocation,
    0xA215: PdfExifTag.ExposureIndex,
    0xA217: PdfExifTag.SensingMethod,
    0xA300: PdfExifTag.FileSource,
    0xA301: PdfExifTag.SceneType,
    0xA302: PdfExifTag.CFAPattern,
    0xA401: PdfExifTag.CustomRendered,
    0xA402: PdfExifTag.ExposureMode,
    0xA403: PdfExifTag.WhiteBalance,
    0xA404: PdfExifTag.DigitalZoomRation,
    0xA405: PdfExifTag.FocalLengthIn35mmFilm,
    0xA406: PdfExifTag.SceneCaptureType,
    0xA407: PdfExifTag.GainControl,
    0xA408: PdfExifTag.Contrast,
    0xA409: PdfExifTag.Saturation,
    0xA40A: PdfExifTag.Sharpness,
    0xA40B: PdfExifTag.DeviceSettingDescription,
    0xA40C: PdfExifTag.SubjectDistanceRange,
    0xA005: PdfExifTag.InteroperabilityIFDPointer,
    0xA420: PdfExifTag.ImageUniqueID,
    0x0100: PdfExifTag.ImageWidth,
    0x0101: PdfExifTag.ImageHeight,
    0x8769: PdfExifTag.ExifIFDPointer,
    0x8825: PdfExifTag.GPSInfoIFDPointer,
    0x0102: PdfExifTag.BitsPerSample,
    0x0103: PdfExifTag.Compression,
    0x0106: PdfExifTag.PhotometricInterpretation,
    0x0112: PdfExifTag.Orientation,
    0x0115: PdfExifTag.SamplesPerPixel,
    0x011C: PdfExifTag.PlanarConfiguration,
    0x0212: PdfExifTag.YCbCrSubSampling,
    0x0213: PdfExifTag.YCbCrPositioning,
    0x011A: PdfExifTag.XResolution,
    0x011B: PdfExifTag.YResolution,
    0x0128: PdfExifTag.ResolutionUnit,
    0x0111: PdfExifTag.StripOffsets,
    0x0116: PdfExifTag.RowsPerStrip,
    0x0117: PdfExifTag.StripByteCounts,
    0x0201: PdfExifTag.JPEGInterchangeFormat,
    0x0202: PdfExifTag.JPEGInterchangeFormatLength,
    0x012D: PdfExifTag.TransferFunction,
    0x013E: PdfExifTag.WhitePoint,
    0x013F: PdfExifTag.PrimaryChromaticities,
    0x0211: PdfExifTag.YCbCrCoefficients,
    0x0214: PdfExifTag.ReferenceBlackWhite,
    0x0132: PdfExifTag.DateTime,
    0x010E: PdfExifTag.ImageDescription,
    0x010F: PdfExifTag.Make,
    0x0110: PdfExifTag.Model,
    0x0131: PdfExifTag.Software,
    0x013B: PdfExifTag.Artist,
    0x8298: PdfExifTag.Copyright,
  };
}

/// Possible Exif tags
enum PdfExifTag {
  // version tags
  /// EXIF version
  ExifVersion,

  /// Flashpix format version
  FlashpixVersion,

  // colorspace tags
  /// Color space information tag
  ColorSpace,

  // image configuration
  /// Valid width of meaningful image
  PixelXDimension,

  /// Valid height of meaningful image
  PixelYDimension,

  /// Information about channels
  ComponentsConfiguration,

  /// Compressed bits per pixel
  CompressedBitsPerPixel,

  // user information
  /// Any desired information written by the manufacturer
  MakerNote,

  /// Comments by user
  UserComment,

  // related file
  /// Name of related sound file
  RelatedSoundFile,

  // date and time
  /// Date and time when the original image was generated
  DateTimeOriginal,

  /// Date and time when the image was stored digitally
  DateTimeDigitized,

  /// Fractions of seconds for DateTime
  SubsecTime,

  /// Fractions of seconds for DateTimeOriginal
  SubsecTimeOriginal,

  /// Fractions of seconds for DateTimeDigitized
  SubsecTimeDigitized,

  // picture-taking conditions
  /// Exposure time (in seconds)
  ExposureTime,

  /// F number
  FNumber,

  /// Exposure program
  ExposureProgram,

  /// Spectral sensitivity
  SpectralSensitivity,

  /// ISO speed rating
  ISOSpeedRatings,

  /// Optoelectric conversion factor
  OECF,

  /// Shutter speed
  ShutterSpeedValue,

  /// Lens aperture
  ApertureValue,

  /// Value of brightness
  BrightnessValue,

  /// Exposure bias
  ExposureBias,

  /// Smallest F number of lens
  MaxApertureValue,

  /// Distance to subject in meters
  SubjectDistance,

  /// Metering mode
  MeteringMode,

  /// Kind of light source
  LightSource,

  /// Flash status
  Flash,

  /// Location and area of main subject
  SubjectArea,

  /// Focal length of the lens in mm
  FocalLength,

  /// Strobe energy in BCPS
  FlashEnergy,

  /// Spatial Frequency Response
  SpatialFrequencyResponse,

  /// Number of pixels in width direction per FocalPlaneResolutionUnit
  FocalPlaneXResolution,

  /// Number of pixels in height direction per FocalPlaneResolutionUnit
  FocalPlaneYResolution,

  /// Unit for measuring FocalPlaneXResolution and FocalPlaneYResolution
  FocalPlaneResolutionUnit,

  /// Location of subject in image
  SubjectLocation,

  /// Exposure index selected on camera
  ExposureIndex,

  /// Image sensor type
  SensingMethod,

  /// Image source (3 == DSC)
  FileSource,

  /// Scene type (1 == directly photographed)
  SceneType,

  /// Color filter array geometric pattern
  CFAPattern,

  /// Special processing
  CustomRendered,

  /// Exposure mode
  ExposureMode,

  /// 1 = auto white balance, 2 = manual
  WhiteBalance,

  /// Digital zoom ratio
  DigitalZoomRation,

  /// Equivalent foacl length assuming 35mm film camera (in mm)
  FocalLengthIn35mmFilm,

  /// Type of scene
  SceneCaptureType,

  /// Degree of overall image gain adjustment
  GainControl,

  /// Direction of contrast processing applied by camera
  Contrast,

  /// Direction of saturation processing applied by camera
  Saturation,

  /// Direction of sharpness processing applied by camera
  Sharpness,

  /// Device Setting Description
  DeviceSettingDescription,

  /// Distance to subject
  SubjectDistanceRange,

  // other tags
  /// Interoperability IFD Pointer
  InteroperabilityIFDPointer,
  //// Identifier assigned uniquely to each image
  ImageUniqueID,

  // tiff Tags
  /// ImageWidth
  ImageWidth,

  /// ImageHeight
  ImageHeight,

  /// ExifIFDPointer
  ExifIFDPointer,

  /// GPSInfoIFDPointer
  GPSInfoIFDPointer,

  /// BitsPerSample
  BitsPerSample,

  /// Compression
  Compression,

  /// PhotometricInterpretation
  PhotometricInterpretation,

  /// Orientation
  Orientation,

  /// SamplesPerPixel
  SamplesPerPixel,

  /// PlanarConfiguration
  PlanarConfiguration,

  /// YCbCrSubSampling
  YCbCrSubSampling,

  /// YCbCrPositioning
  YCbCrPositioning,

  /// XResolution
  XResolution,

  /// YResolution
  YResolution,

  /// ResolutionUnit
  ResolutionUnit,

  /// StripOffsets
  StripOffsets,

  /// RowsPerStrip
  RowsPerStrip,

  /// StripByteCounts
  StripByteCounts,

  /// JPEGInterchangeFormat
  JPEGInterchangeFormat,

  /// JPEGInterchangeFormatLength
  JPEGInterchangeFormatLength,

  /// TransferFunction
  TransferFunction,

  /// WhitePoint
  WhitePoint,

  /// PrimaryChromaticities
  PrimaryChromaticities,

  /// YCbCrCoefficients
  YCbCrCoefficients,

  /// ReferenceBlackWhite
  ReferenceBlackWhite,

  /// DateTime
  DateTime,

  /// ImageDescription
  ImageDescription,

  /// Make
  Make,

  /// Model
  Model,

  /// Software
  Software,

  /// Artist
  Artist,

  /// Copyright
  Copyright,
}

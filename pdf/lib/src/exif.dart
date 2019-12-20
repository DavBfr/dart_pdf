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

// ignore_for_file: omit_local_variable_types

part of pdf;

class PdfJpegInfo {
  factory PdfJpegInfo(Uint8List image) {
    assert(image != null);

    final ByteData buffer = image.buffer.asByteData();

    int width;
    int height;
    int color;
    int offset = 0;
    while (offset < buffer.lengthInBytes) {
      while (buffer.getUint8(offset) == 0xff) {
        offset++;
      }

      final int mrkr = buffer.getUint8(offset);
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

      final int len = buffer.getUint16(offset);
      offset += 2;

      if (mrkr == 0xc0) {
        height = buffer.getUint16(offset + 1);
        width = buffer.getUint16(offset + 3);
        color = buffer.getUint8(offset + 5);
        break;
      }
      offset += len - 2;
    }

    final Map<PdfExifTag, dynamic> tags = _findExifInJpeg(buffer);

    return PdfJpegInfo._(width, height, color, tags);
  }

  PdfJpegInfo._(this.width, this.height, this._color, this.tags);

  final int width;

  final int height;

  final int _color;

  bool get isRGB => _color == 3;

  final Map<PdfExifTag, dynamic> tags;

  /// EXIF version
  String get exifVersion => tags == null || tags[PdfExifTag.ExifVersion] == null
      ? null
      : utf8.decode(tags[PdfExifTag.ExifVersion]);

  /// Flashpix format version
  String get flashpixVersion =>
      tags == null || tags[PdfExifTag.FlashpixVersion] == null
          ? null
          : utf8.decode(tags[PdfExifTag.FlashpixVersion]);

  PdfImageOrientation get orientation =>
      tags == null || tags[PdfExifTag.Orientation] == null
          ? PdfImageOrientation.topLeft
          : PdfImageOrientation.values[tags[PdfExifTag.Orientation] - 1];

  double get xResolution => tags == null || tags[PdfExifTag.XResolution] == null
      ? null
      : tags[PdfExifTag.XResolution][0].toDouble() /
          tags[PdfExifTag.XResolution][1].toDouble();

  double get yResolution => tags == null || tags[PdfExifTag.YResolution] == null
      ? null
      : tags[PdfExifTag.YResolution][0].toDouble() /
          tags[PdfExifTag.YResolution][1].toDouble();

  int get pixelXDimension =>
      tags == null || tags[PdfExifTag.PixelXDimension] == null
          ? width
          : tags[PdfExifTag.PixelXDimension];

  int get pixelYDimension =>
      tags == null || tags[PdfExifTag.PixelYDimension] == null
          ? height
          : tags[PdfExifTag.PixelYDimension];

  @override
  String toString() => '''width: $width height: $height
exifVersion: $exifVersion flashpixVersion: $flashpixVersion
xResolution: $xResolution yResolution: $yResolution
pixelXDimension: $pixelXDimension pixelYDimension: $pixelYDimension
orientation: $orientation''';

  static Map<PdfExifTag, dynamic> _findExifInJpeg(ByteData buffer) {
    if ((buffer.getUint8(0) != 0xFF) || (buffer.getUint8(1) != 0xD8)) {
      return <PdfExifTag, dynamic>{}; // Not a valid JPEG
    }

    int offset = 2;
    final int length = buffer.lengthInBytes;
    int marker;

    while (offset < length) {
      final int lastValue = buffer.getUint8(offset);
      if (lastValue != 0xFF) {
        return <PdfExifTag,
            dynamic>{}; // Not a valid marker at offset $offset, found: $lastValue
      }

      marker = buffer.getUint8(offset + 1);

      // we could implement handling for other markers here,
      // but we're only looking for 0xFFE1 for EXIF data
      if (marker == 0xE1) {
        return _readEXIFData(buffer, offset + 4);
      } else {
        offset += 2 + buffer.getUint16(offset + 2);
      }
    }

    return <PdfExifTag, dynamic>{};
  }

  static Map<PdfExifTag, dynamic> _readTags(
    ByteData file,
    int tiffStart,
    int dirStart,
    Endian bigEnd,
  ) {
    final int entries = file.getUint16(dirStart, bigEnd);
    final Map<PdfExifTag, dynamic> tags = <PdfExifTag, dynamic>{};
    int entryOffset;

    for (int i = 0; i < entries; i++) {
      entryOffset = dirStart + i * 12 + 2;
      final int tagId = file.getUint16(entryOffset, bigEnd);
      final PdfExifTag tag = _exifTags[tagId];
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

  static dynamic _readTagValue(
    ByteData file,
    int entryOffset,
    int tiffStart,
    int dirStart,
    Endian bigEnd,
  ) {
    final int type = file.getUint16(entryOffset + 2, bigEnd);
    final int numValues = file.getUint32(entryOffset + 4, bigEnd);
    final int valueOffset = file.getUint32(entryOffset + 8, bigEnd) + tiffStart;

    switch (type) {
      case 1: // byte, 8-bit unsigned int
      case 7: // undefined, 8-bit byte, value depending on field
        if (numValues == 1) {
          return file.getUint8(entryOffset + 8);
        }
        final int offset = numValues > 4 ? valueOffset : (entryOffset + 8);
        final Uint8List result = Uint8List(numValues);
        for (int i = 0; i < result.length; ++i) {
          result[i] = file.getUint8(offset + i);
        }
        return result;
      case 2: // ascii, 8-bit byte
        final int offset = numValues > 4 ? valueOffset : (entryOffset + 8);
        return _getStringFromDB(file, offset, numValues - 1);
      case 3: // short, 16 bit int
        if (numValues == 1) {
          return file.getUint16(entryOffset + 8, bigEnd);
        }
        final int offset = numValues > 2 ? valueOffset : (entryOffset + 8);
        final Uint16List result = Uint16List(numValues);
        for (int i = 0; i < result.length; ++i) {
          result[i] = file.getUint16(offset + i * 2, bigEnd);
        }
        return result;
      case 4: // long, 32 bit int
        if (numValues == 1) {
          return file.getUint32(entryOffset + 8, bigEnd);
        }
        final int offset = valueOffset;
        final Uint32List result = Uint32List(numValues);
        for (int i = 0; i < result.length; ++i) {
          result[i] = file.getUint32(offset + i * 4, bigEnd);
        }
        return result;
      case 5: // rational = two long values, first is numerator, second is denominator
        if (numValues == 1) {
          final int numerator = file.getUint32(valueOffset, bigEnd);
          final int denominator = file.getUint32(valueOffset + 4, bigEnd);
          return <int>[numerator, denominator];
        }
        final int offset = valueOffset;
        final List<List<int>> result = List<List<int>>(numValues);
        for (int i = 0; i < result.length; ++i) {
          final int numerator = file.getUint32(offset + i * 8, bigEnd);
          final int denominator = file.getUint32(offset + i * 8 + 4, bigEnd);
          result[i] = <int>[numerator, denominator];
        }
        return result;
      case 9: // slong, 32 bit signed int
        if (numValues == 1) {
          return file.getInt32(entryOffset + 8, bigEnd);
        }
        final int offset = valueOffset;
        final Int32List result = Int32List(numValues);
        for (int i = 0; i < result.length; ++i) {
          result[i] = file.getInt32(offset + i * 4, bigEnd);
        }
        return result;
      case 10: // signed rational, two slongs, first is numerator, second is denominator
        if (numValues == 1) {
          final int numerator = file.getInt32(valueOffset, bigEnd);
          final int denominator = file.getInt32(valueOffset + 4, bigEnd);
          return <int>[numerator, denominator];
        }
        final int offset = valueOffset;
        final List<List<int>> result = List<List<int>>(numValues);
        for (int i = 0; i < result.length; ++i) {
          final int numerator = file.getInt32(offset + i * 8, bigEnd);
          final int denominator = file.getInt32(offset + i * 8 + 4, bigEnd);
          result[i] = <int>[numerator, denominator];
        }
        return result;
      case 11: // single float, 32 bit float
        if (numValues == 1) {
          return file.getFloat32(entryOffset + 8, bigEnd);
        }
        final int offset = valueOffset;
        final Float32List result = Float32List(numValues);
        for (int i = 0; i < result.length; ++i) {
          result[i] = file.getFloat32(offset + i * 4, bigEnd);
        }
        return result;
      case 12: // double float, 64 bit float
        if (numValues == 1) {
          return file.getFloat64(entryOffset + 8, bigEnd);
        }
        final int offset = valueOffset;
        final Float64List result = Float64List(numValues);
        for (int i = 0; i < result.length; ++i) {
          result[i] = file.getFloat64(offset + i * 8, bigEnd);
        }
        return result;
    }
  }

  static String _getStringFromDB(ByteData buffer, int start, int length) {
    return utf8.decode(
        List<int>.generate(length, (int i) => buffer.getUint8(start + i)),
        allowMalformed: true);
  }

  static Map<PdfExifTag, dynamic> _readEXIFData(ByteData buffer, int start) {
    final String startingString = _getStringFromDB(buffer, start, 4);
    if (startingString != 'Exif') {
      // Not valid EXIF data! $startingString
      return null;
    }

    Endian bigEnd;
    final int tiffOffset = start + 6;

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

    final int firstIFDOffset = buffer.getUint32(tiffOffset + 4, bigEnd);

    if (firstIFDOffset < 0x00000008) {
      // Not valid TIFF data! (First offset less than 8) $firstIFDOffset
      return null;
    }

    final Map<PdfExifTag, dynamic> tags =
        _readTags(buffer, tiffOffset, tiffOffset + firstIFDOffset, bigEnd);

    if (tags.containsKey(PdfExifTag.ExifIFDPointer)) {
      final Map<PdfExifTag, dynamic> exifData = _readTags(buffer, tiffOffset,
          tiffOffset + tags[PdfExifTag.ExifIFDPointer], bigEnd);
      tags.addAll(exifData);
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

enum PdfExifTag {
  // version tags
  ExifVersion, // EXIF version
  FlashpixVersion, // Flashpix format version

  // colorspace tags
  ColorSpace, // Color space information tag

  // image configuration
  PixelXDimension, // Valid width of meaningful image
  PixelYDimension, // Valid height of meaningful image
  ComponentsConfiguration, // Information about channels
  CompressedBitsPerPixel, // Compressed bits per pixel

  // user information
  MakerNote, // Any desired information written by the manufacturer
  UserComment, // Comments by user

  // related file
  RelatedSoundFile, // Name of related sound file

  // date and time
  DateTimeOriginal, // Date and time when the original image was generated
  DateTimeDigitized, // Date and time when the image was stored digitally
  SubsecTime, // Fractions of seconds for DateTime
  SubsecTimeOriginal, // Fractions of seconds for DateTimeOriginal
  SubsecTimeDigitized, // Fractions of seconds for DateTimeDigitized

  // picture-taking conditions
  ExposureTime, // Exposure time (in seconds)
  FNumber, // F number
  ExposureProgram, // Exposure program
  SpectralSensitivity, // Spectral sensitivity
  ISOSpeedRatings, // ISO speed rating
  OECF, // Optoelectric conversion factor
  ShutterSpeedValue, // Shutter speed
  ApertureValue, // Lens aperture
  BrightnessValue, // Value of brightness
  ExposureBias, // Exposure bias
  MaxApertureValue, // Smallest F number of lens
  SubjectDistance, // Distance to subject in meters
  MeteringMode, // Metering mode
  LightSource, // Kind of light source
  Flash, // Flash status
  SubjectArea, // Location and area of main subject
  FocalLength, // Focal length of the lens in mm
  FlashEnergy, // Strobe energy in BCPS
  SpatialFrequencyResponse, //
  FocalPlaneXResolution, // Number of pixels in width direction per FocalPlaneResolutionUnit
  FocalPlaneYResolution, // Number of pixels in height direction per FocalPlaneResolutionUnit
  FocalPlaneResolutionUnit, // Unit for measuring FocalPlaneXResolution and FocalPlaneYResolution
  SubjectLocation, // Location of subject in image
  ExposureIndex, // Exposure index selected on camera
  SensingMethod, // Image sensor type
  FileSource, // Image source (3 == DSC)
  SceneType, // Scene type (1 == directly photographed)
  CFAPattern, // Color filter array geometric pattern
  CustomRendered, // Special processing
  ExposureMode, // Exposure mode
  WhiteBalance, // 1 = auto white balance, 2 = manual
  DigitalZoomRation, // Digital zoom ratio
  FocalLengthIn35mmFilm, // Equivalent foacl length assuming 35mm film camera (in mm)
  SceneCaptureType, // Type of scene
  GainControl, // Degree of overall image gain adjustment
  Contrast, // Direction of contrast processing applied by camera
  Saturation, // Direction of saturation processing applied by camera
  Sharpness, // Direction of sharpness processing applied by camera
  DeviceSettingDescription, //
  SubjectDistanceRange, // Distance to subject

  // other tags
  InteroperabilityIFDPointer,
  ImageUniqueID, // Identifier assigned uniquely to each image

  // tiff Tags
  ImageWidth,
  ImageHeight,
  ExifIFDPointer,
  GPSInfoIFDPointer,
  BitsPerSample,
  Compression,
  PhotometricInterpretation,
  Orientation,
  SamplesPerPixel,
  PlanarConfiguration,
  YCbCrSubSampling,
  YCbCrPositioning,
  XResolution,
  YResolution,
  ResolutionUnit,
  StripOffsets,
  RowsPerStrip,
  StripByteCounts,
  JPEGInterchangeFormat,
  JPEGInterchangeFormatLength,
  TransferFunction,
  WhitePoint,
  PrimaryChromaticities,
  YCbCrCoefficients,
  ReferenceBlackWhite,
  DateTime,
  ImageDescription,
  Make,
  Model,
  Software,
  Artist,
  Copyright,
}

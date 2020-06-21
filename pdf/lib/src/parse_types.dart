part of pdf;

enum Types {
  BYTE,
  CHAR,
  USHORT,
  SHORT,
  ULONG,
  LONG,
  TAG,
  FIXED,
  OFFSET,
  GLYPHID
}

class Struct {
  final int sizeOf;
  final Function read;

  Struct(this.sizeOf, this.read);
}

Map<Types, dynamic> ReadTyps = {
  Types.BYTE: Struct(
    1,
    (UnmodifiableByteDataView buffer, int offset) {
      return buffer.getUint8(offset ?? 0);
    },
  ),
  Types.CHAR: Struct(
    1,
    (UnmodifiableByteDataView buffer, int offset) {
      return buffer.getInt8(offset ?? 0);
    },
  ),
  Types.USHORT: Struct(
    2,
    (UnmodifiableByteDataView buffer, int offset) {
      return buffer.getUint16(offset ?? 0);
    },
  ),
  Types.OFFSET: Struct(
    2,
    (UnmodifiableByteDataView buffer, int offset) {
      return buffer.getUint16(offset ?? 0);
    },
  ),
  Types.GLYPHID: Struct(
    2,
    (UnmodifiableByteDataView buffer, int offset) {
      return buffer.getUint16(offset ?? 0);
    },
  ),
  Types.SHORT: Struct(
    2,
    (UnmodifiableByteDataView buffer, int offset) {
      return buffer.getInt16(offset ?? 0);
    },
  ),
  Types.ULONG: Struct(
    4,
    (UnmodifiableByteDataView buffer, int offset) {
      return buffer.getUint32(offset ?? 0);
    },
  ),
  Types.LONG: Struct(
    4,
    (UnmodifiableByteDataView buffer, int offset) {
      return buffer.getInt32(offset ?? 0);
    },
  ),
  Types.TAG: Struct(
    4,
    (UnmodifiableByteDataView buffer, int offset) {
      String tag = '';
      for (int i = offset; i < offset + 4; i += 1) {
        tag += String.fromCharCode(buffer.getInt8(i));
      }

      return tag;
    },
  ),
  Types.FIXED: Struct(
    4,
    (UnmodifiableByteDataView buffer, int offset) {
      return buffer.getUint32(offset ?? 0);
    },
  ),
};

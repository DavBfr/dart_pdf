part of pdf;

class ReadBuffer {
  final UnmodifiableByteDataView buffer;
  int byteOffset;
  int origStart;

  // ignore: sort_constructors_first
  ReadBuffer(this.buffer, this.byteOffset);

  /**
   * Jump to an offset in this buffer
   * @param {number} byteOffset
   */
  goto(int byteOffset) {
    this.byteOffset = byteOffset;

  }

  /**
   * Read a struct from the buffer at the next
   * position or if byteOffset is given a specific
   * position.
   *
   * @param {opentype.Struct} type
   * @param {number=} opt_byteOffset
   * @return {?}
   */
  read(Struct type, [int opt_byteOffset]) {
    var data = type.read(this.buffer, opt_byteOffset ?? this.byteOffset);

    if (opt_byteOffset == null) {
      this.byteOffset += type.sizeOf;
    }

    return data;
  }

  /**
   * Read multiple structs from the buffer at the
   * next position or if byteOffset is given a
   * specific position.
   *
   * @param {opentype.Struct} type
   * @param {number} count
   * @param {number=} opt_byteOffset
   * @return {Array.<?>}
   */
  readArray(Struct type, int count, [int offset]) {
    var byteOffset = offset ?? this.byteOffset;
    var data = [];

    for (var i = 0; i < count; i += 1) {
      data.add(type.read(this.buffer, byteOffset));
      byteOffset += type.sizeOf;
    }

    if (offset == null) {
      this.byteOffset += (type.sizeOf * count);
    }

    return data;
  }
}

Struct utilstruct(Map<String, Struct> types) {
  int sizeof = 0;

  types.values.forEach((el) {
    sizeof += el.sizeOf;
  });

  return Struct(
    sizeof,
    (buffer, offset) {
      var byteOffset = offset ?? 0;
      Map<dynamic, dynamic> struct =  Map<dynamic, dynamic>();

      types.keys.forEach((key) {
          struct[key] = types[key].read(buffer, byteOffset);
          byteOffset += types[key].sizeOf;
      });
      

      return struct;
    },
  );
}

part of "../soia.dart";

void _decodeUnused(_ByteStream stream) {
  final wire = stream.readByte() & 0xFF;
  if (wire < 232) {
    return;
  }

  switch (wire - 232) {
    case 0:
    case 4: // uint16, uint16 - 65536
      stream.readBytes(2);
      break;
    case 1:
    case 5:
    case 8: // uint32, int32, float32
      stream.readBytes(4);
      break;
    case 2:
    case 6:
    case 7:
    case 9: // uint64, int64, uint64 timestamp, float64
      stream.readBytes(8);
      break;
    case 3: // uint8 - 256
      stream.readBytes(1);
      break;
    case 11:
    case 13: // string, bytes
      final length = stream.decodeNumber();
      stream.readBytes(length.toInt());
      break;
    case 15:
    case 19:
    case 20:
    case 21:
    case 22: // array length==1, enum value kind==1-4
      _decodeUnused(stream);
      break;
    case 16: // array length==2
      _decodeUnused(stream);
      _decodeUnused(stream);
      break;
    case 17: // array length==3
      _decodeUnused(stream);
      _decodeUnused(stream);
      _decodeUnused(stream);
      break;
    case 18: // array length==N
      final length = stream.decodeNumber();
      for (int i = 0; i < length.toInt(); i++) {
        _decodeUnused(stream);
      }
      break;
  }
}

class _BinaryWriter {
  static void encodeInt32(int value, Uint8Buffer buffer) {
    if (value >= 0 && value < 232) {
      buffer.add(value);
    } else if (value >= -128 && value < 128) {
      buffer.add(235);
      buffer.add(value & 0xFF);
    } else if (value >= -32768 && value < 32768) {
      buffer.add(236);
      writeShortLe(value, buffer);
    } else {
      buffer.add(237);
      writeIntLe(value, buffer);
    }
  }

  static void encodeLengthPrefix(int length, Uint8Buffer buffer) {
    if (length < 232) {
      buffer.add(length & 0xFF);
    } else if (length < 65536) {
      buffer.add(232 & 0xFF);
      writeShortLe(length, buffer);
    } else if (length < 2147483648) {
      buffer.add(233 & 0xFF);
      writeIntLe(length, buffer);
    } else {
      throw ArgumentError("Length overflow: ${length}");
    }
  }

  static void writeShortLe(int value, Uint8Buffer buffer) {
    buffer.add(value & 0xFF);
    buffer.add((value >> 8) & 0xFF);
  }

  static void writeIntLe(int value, Uint8Buffer buffer) {
    buffer.add(value & 0xFF);
    buffer.add((value >> 8) & 0xFF);
    buffer.add((value >> 16) & 0xFF);
    buffer.add((value >> 24) & 0xFF);
  }

  static void writeLongLe(int value, Uint8Buffer buffer) {
    buffer.add(value & 0xFF);
    buffer.add((value >> 8) & 0xFF);
    buffer.add((value >> 16) & 0xFF);
    buffer.add((value >> 24) & 0xFF);
    buffer.add((value >> 32) & 0xFF);
    buffer.add((value >> 40) & 0xFF);
    buffer.add((value >> 48) & 0xFF);
    buffer.add((value >> 56) & 0xFF);
  }

  static void writeFloatLe(double value, Uint8Buffer buffer) {
    final bytes = ByteData(4);
    bytes.setFloat32(0, value, Endian.little);
    buffer.addAll(bytes.buffer.asUint8List());
  }

  static void writeDoubleLe(double value, Uint8Buffer buffer) {
    final bytes = ByteData(8);
    bytes.setFloat64(0, value, Endian.little);
    buffer.addAll(bytes.buffer.asUint8List());
  }
}

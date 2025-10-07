part of "../soia_client.dart";

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
      if (length >= 0) {
        buffer.add(length & 0xFF);
      } else {
        throw ArgumentError("Length overflow: ${length.toUnsigned(32)}");
      }
    } else if (length < 65536) {
      buffer.add(232 & 0xFF);
      writeShortLe(length, buffer);
    } else {
      buffer.add(233 & 0xFF);
      writeIntLe(length, buffer);
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

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
    encodeInt32(length, buffer);
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

class _BinaryReader {
  final Uint8List _buffer;
  int position = 0;

  _BinaryReader(this._buffer);

  int readByte() {
    if (position >= _buffer.length) {
      throw StateError('Buffer underflow');
    }
    return _buffer[position++];
  }

  Uint8List readBytes(int count) {
    if (position + count > _buffer.length) {
      throw StateError('Buffer underflow');
    }
    final result = _buffer.sublist(position, position + count);
    position += count;
    return result;
  }

  Uint8List get remainingBytes {
    return _buffer.sublist(position);
  }

  num decodeNumber() {
    final wire = readByte();

    if (wire < 232) {
      return wire;
    }

    switch (wire) {
      case 232:
        return _readShortLe();
      case 233:
        return _readIntLe();
      case 234:
        return _readLongLe();
      case 235:
        return _readSignedByte();
      case 236:
        return _readSignedShortLe();
      case 237:
        return _readSignedIntLe();
      case 238:
        return _readSignedLongLe();
      case 240:
        return _readFloatLe();
      case 241:
        return _readDoubleLe();
      default:
        throw ArgumentError('Unsupported wire type: $wire');
    }
  }

  int _readShortLe() {
    final b1 = readByte();
    final b2 = readByte();
    return b1 | (b2 << 8);
  }

  int _readIntLe() {
    final b1 = readByte();
    final b2 = readByte();
    final b3 = readByte();
    final b4 = readByte();
    return b1 | (b2 << 8) | (b3 << 16) | (b4 << 24);
  }

  int _readLongLe() {
    final b1 = readByte();
    final b2 = readByte();
    final b3 = readByte();
    final b4 = readByte();
    final b5 = readByte();
    final b6 = readByte();
    final b7 = readByte();
    final b8 = readByte();
    return b1 |
        (b2 << 8) |
        (b3 << 16) |
        (b4 << 24) |
        (b5 << 32) |
        (b6 << 40) |
        (b7 << 48) |
        (b8 << 56);
  }

  int _readSignedByte() {
    final value = readByte();
    return value > 127 ? value - 256 : value;
  }

  int _readSignedShortLe() {
    final value = _readShortLe();
    return value > 32767 ? value - 65536 : value;
  }

  int _readSignedIntLe() {
    final value = _readIntLe();
    return value > 2147483647 ? value - 4294967296 : value;
  }

  int _readSignedLongLe() {
    return _readLongLe(); // Dart's int is already signed
  }

  double _readFloatLe() {
    final bytes = readBytes(4);
    final byteData = ByteData.sublistView(bytes);
    return byteData.getFloat32(0, Endian.little);
  }

  double _readDoubleLe() {
    final bytes = readBytes(8);
    final byteData = ByteData.sublistView(bytes);
    return byteData.getFloat64(0, Endian.little);
  }
}

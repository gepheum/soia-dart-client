part of "../soia_client.dart";

abstract class _PrimitiveSerializer<T> extends _SerializerImpl<T> {
  String get typeName;

  @override
  dynamic get typeSignature => {
        'kind': 'primitive',
        'value': typeName,
      };

  @override
  void addRecordDefinitionsTo(Map<String, dynamic> out) {}
}

class _BoolSerializer extends _PrimitiveSerializer<bool> {
  @override
  bool isDefault(bool value) => !value;

  @override
  void encode(bool input, Uint8Buffer buffer) {
    buffer.add(input ? 1 : 0);
  }

  @override
  bool decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = _BinaryReader(buffer);
    return reader.decodeNumber().toInt() != 0;
  }

  @override
  void appendString(bool input, StringBuffer out, String eolIndent) {
    out.write(input);
  }

  @override
  dynamic toJson(bool input, bool readableFlavor) {
    return readableFlavor ? input : (input ? 1 : 0);
  }

  @override
  bool fromJson(dynamic json, bool keepUnrecognizedFields) {
    if (json is bool) return json;
    if (json is num) return json != 0;
    if (json is String) {
      return json != '0' && json != 'false';
    }
    return true;
  }

  @override
  String get typeName => 'bool';

  @override
  ReflectiveTypeDescriptor get typeDescriptor =>
      PrimitiveDescriptor(PrimitiveType.BOOL);
}

class _Int32Serializer extends _PrimitiveSerializer<int> {
  @override
  bool isDefault(int value) => value == 0;

  @override
  void encode(int input, Uint8Buffer buffer) {
    _BinaryWriter.encodeInt32(input, buffer);
  }

  @override
  int decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = _BinaryReader(buffer);
    return reader.decodeNumber().toInt();
  }

  @override
  dynamic toJson(int input, bool readableFlavor) => input.toSigned(32);

  @override
  int fromJson(dynamic json, bool keepUnrecognizedFields) {
    final int number = switch (json) {
      int() => json,
      String() => int.parse(json),
      _ => (json as num).toInt(),
    };
    return number.toSigned(32);
  }

  @override
  void appendString(int input, StringBuffer out, String eolIndent) {
    out.write(input);
  }

  @override
  String get typeName => 'int32';

  @override
  ReflectiveTypeDescriptor get typeDescriptor =>
      PrimitiveDescriptor(PrimitiveType.INT_32);
}

class _Int64Serializer extends _PrimitiveSerializer<int> {
  static const int minSafeJavaScriptInt = -9007199254740992; // -(2 ^ 53)
  static const int maxSafeJavaScriptInt = 9007199254740992; // 2 ^ 53

  @override
  bool isDefault(int value) => value == 0;

  @override
  void encode(int input, Uint8Buffer buffer) {
    if (input >= -2147483648 && input <= 2147483647) {
      _Int32Serializer().encode(input, buffer);
    } else {
      buffer.add(238);
      _BinaryWriter.writeLongLe(input, buffer);
    }
  }

  @override
  int decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = _BinaryReader(buffer);
    return reader.decodeNumber().toInt();
  }

  @override
  dynamic toJson(int input, bool readableFlavor) {
    return (input >= minSafeJavaScriptInt && input <= maxSafeJavaScriptInt)
        ? input
        : input.toSigned(64).toString();
  }

  @override
  int fromJson(dynamic json, bool keepUnrecognizedFields) {
    final int number = switch (json) {
      int() => json,
      String() => int.parse(json),
      _ => (json as num).toInt(),
    };
    return number.toSigned(64);
  }

  @override
  void appendString(int input, StringBuffer out, String eolIndent) {
    out.write(input);
  }

  @override
  String get typeName => 'int64';

  @override
  ReflectiveTypeDescriptor get typeDescriptor =>
      PrimitiveDescriptor(PrimitiveType.INT_64);
}

class Uint64Serializer extends _PrimitiveSerializer<int> {
  static const int maxSafeJavaScriptInt = 9007199254740992;

  @override
  bool isDefault(int value) => value == 0;

  @override
  void encode(int input, Uint8Buffer buffer) {
    if (input < 232) {
      buffer.add(input);
    } else if (input < 4294967296) {
      if (input < 65536) {
        buffer.add(232);
        _BinaryWriter.writeShortLe(input, buffer);
      } else {
        buffer.add(233);
        _BinaryWriter.writeIntLe(input, buffer);
      }
    } else {
      buffer.add(234);
      _BinaryWriter.writeLongLe(input, buffer);
    }
  }

  @override
  int decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = _BinaryReader(buffer);
    return reader.decodeNumber().toInt();
  }

  @override
  dynamic toJson(int input, bool readableFlavor) {
    if (0 <= input && input <= maxSafeJavaScriptInt) {
      return input;
    } else {
      return input.toUnsigned(64).toString();
    }
  }

  @override
  int fromJson(dynamic json, bool keepUnrecognizedFields) {
    final int number = switch (json) {
      int() => json,
      String() => int.parse(json),
      _ => (json as num).toInt(),
    };
    return number.toUnsigned(64);
  }

  @override
  void appendString(int input, StringBuffer out, String eolIndent) {
    out.write(input);
  }

  @override
  String get typeName => 'uint64';

  @override
  ReflectiveTypeDescriptor get typeDescriptor =>
      PrimitiveDescriptor(PrimitiveType.UINT_64);
}

class _Float32Serializer extends _PrimitiveSerializer<double> {
  @override
  bool isDefault(double value) => value == 0.0;

  @override
  void encode(double input, Uint8Buffer buffer) {
    if (input == 0.0) {
      buffer.add(0);
    } else {
      buffer.add(240);
      _BinaryWriter.writeFloatLe(input, buffer);
    }
  }

  @override
  double decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = _BinaryReader(buffer);
    return reader.decodeNumber().toDouble();
  }

  @override
  dynamic toJson(double input, bool readableFlavor) {
    return input.isFinite ? input : input.toString();
  }

  @override
  double fromJson(dynamic json, bool keepUnrecognizedFields) {
    if (json is double) return json;
    if (json is String) return double.parse(json);
    return (json as num).toDouble();
  }

  @override
  void appendString(double input, StringBuffer out, String eolIndent) {
    if (input.isFinite) {
      out.write(input);
    } else if (input.isNegative && input.isInfinite) {
      out.write('double.negativeInfinity');
    } else if (input.isInfinite) {
      out.write('double.infinity');
    } else {
      out.write('double.nan');
    }
  }

  @override
  String get typeName => 'float32';

  @override
  ReflectiveTypeDescriptor get typeDescriptor =>
      PrimitiveDescriptor(PrimitiveType.FLOAT_32);
}

class _Float64Serializer extends _PrimitiveSerializer<double> {
  @override
  bool isDefault(double value) => value == 0.0;

  @override
  void encode(double input, Uint8Buffer buffer) {
    if (input == 0.0) {
      buffer.add(0);
    } else {
      buffer.add(241);
      _BinaryWriter.writeDoubleLe(input, buffer);
    }
  }

  @override
  double decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = _BinaryReader(buffer);
    return reader.decodeNumber().toDouble();
  }

  @override
  dynamic toJson(double input, bool readableFlavor) {
    return input.isFinite ? input : input.toString();
  }

  @override
  double fromJson(dynamic json, bool keepUnrecognizedFields) {
    if (json is double) return json;
    if (json is String) return double.parse(json);
    return (json as num).toDouble();
  }

  @override
  void appendString(double input, StringBuffer out, String eolIndent) {
    if (input.isFinite) {
      out.write(input);
    } else if (input.isNegative && input.isInfinite) {
      out.write('double.negativeInfinity');
    } else if (input.isInfinite) {
      out.write('double.infinity');
    } else {
      out.write('double.nan');
    }
  }

  @override
  String get typeName => 'float64';

  @override
  ReflectiveTypeDescriptor get typeDescriptor =>
      PrimitiveDescriptor(PrimitiveType.FLOAT_64);
}

class _StringSerializer extends _PrimitiveSerializer<String> {
  @override
  bool isDefault(String value) => value.isEmpty;

  @override
  void encode(String input, Uint8Buffer buffer) {
    if (input.isEmpty) {
      buffer.add(242);
    } else {
      buffer.add(243);
      final bytes = utf8.encode(input);
      _BinaryWriter.encodeLengthPrefix(bytes.length, buffer);
      buffer.addAll(bytes);
    }
  }

  @override
  String decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = _BinaryReader(buffer);
    final wire = reader.readByte();
    if (wire == 242) {
      return '';
    } else {
      final length = reader.decodeNumber().toInt();
      final bytes = reader.readBytes(length);
      return utf8.decode(bytes);
    }
  }

  @override
  dynamic toJson(String input, bool readableFlavor) => input;

  @override
  String fromJson(dynamic json, bool keepUnrecognizedFields) {
    if (json is String) return json;
    if (json is num && json == 0) return '';
    return json.toString();
  }

  @override
  void appendString(String input, StringBuffer out, String eolIndent) {
    out.write('"');
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      switch (char) {
        case '\\':
          out.write('\\\\');
          break;
        case '"':
          out.write('\\"');
          break;
        case '\n':
          out.write('\\n');
          if (i < input.length - 1) {
            out.write('" +$eolIndent$_indentUnit"');
          }
          break;
        case '\r':
          out.write('\\r');
          break;
        case '\t':
          out.write('\\t');
          break;
        case '\b':
          out.write('\\b');
          break;
        case '\f':
          out.write('\\f');
          break;
        default:
          final code = char.codeUnitAt(0);
          if (code < 32 || (code >= 127 && code <= 159)) {
            out.write('\\u${code.toRadixString(16).padLeft(4, '0')}');
          } else {
            out.write(char);
          }
      }
    }
    out.write('"');
  }

  @override
  String get typeName => 'string';

  @override
  ReflectiveTypeDescriptor get typeDescriptor =>
      PrimitiveDescriptor(PrimitiveType.STRING);
}

class _BytesSerializer extends _PrimitiveSerializer<Uint8List> {
  @override
  bool isDefault(Uint8List value) => value.isEmpty;

  @override
  void encode(Uint8List input, Uint8Buffer buffer) {
    if (input.isEmpty) {
      buffer.add(244);
    } else {
      buffer.add(245);
      _BinaryWriter.encodeLengthPrefix(input.length, buffer);
      buffer.addAll(input);
    }
  }

  @override
  Uint8List decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = _BinaryReader(buffer);
    final wire = reader.readByte();
    if (wire == 0 || wire == 244) {
      return Uint8List(0);
    } else {
      final length = reader.decodeNumber().toInt();
      return reader.readBytes(length);
    }
  }

  @override
  void appendString(Uint8List input, StringBuffer out, String eolIndent) {
    out.write('"${_bytesToHex(input)}"');
  }

  @override
  dynamic toJson(Uint8List input, bool readableFlavor) {
    return base64Encode(input);
  }

  @override
  Uint8List fromJson(dynamic json, bool keepUnrecognizedFields) {
    if (json is String) {
      return base64Decode(json);
    } else if (json is num && json == 0) {
      return Uint8List(0);
    } else {
      throw ArgumentError('Expected: base64 string');
    }
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  String get typeName => 'bytes';

  @override
  ReflectiveTypeDescriptor get typeDescriptor =>
      PrimitiveDescriptor(PrimitiveType.BYTES);
}

class _TimestampSerializer extends _PrimitiveSerializer<DateTime> {
  @override
  bool isDefault(DateTime value) => value.millisecondsSinceEpoch == 0;

  @override
  void encode(DateTime input, Uint8Buffer buffer) {
    final unixMillis = _clampUnixMillis(input.millisecondsSinceEpoch);
    if (unixMillis == 0) {
      buffer.add(0);
    } else {
      buffer.add(239);
      _BinaryWriter.writeLongLe(unixMillis, buffer);
    }
  }

  @override
  DateTime decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = _BinaryReader(buffer);
    final unixMillis = _clampUnixMillis(reader.decodeNumber().toInt());
    return DateTime.fromMillisecondsSinceEpoch(unixMillis);
  }

  @override
  dynamic toJson(DateTime input, bool readableFlavor) {
    final unixMillis = _clampUnixMillis(input.millisecondsSinceEpoch);
    return readableFlavor
        ? {
            'unix_millis': unixMillis,
            'formatted': DateTime.fromMillisecondsSinceEpoch(unixMillis)
                .toIso8601String(),
          }
        : unixMillis;
  }

  @override
  DateTime fromJson(dynamic json, bool keepUnrecognizedFields) {
    late int unixMillis;
    if (json is Map && json.containsKey('unix_millis')) {
      unixMillis = (json['unix_millis'] as num).toInt();
    } else {
      unixMillis = (json as num).toInt();
    }
    return DateTime.fromMillisecondsSinceEpoch(_clampUnixMillis(unixMillis));
  }

  @override
  void appendString(DateTime input, StringBuffer out, String eolIndent) {
    out.write('DateTime.fromMillisecondsSinceEpoch(');
    out.write(eolIndent);
    out.write(_indentUnit);
    out.write('// ${input.toIso8601String()}');
    out.write(eolIndent);
    out.write(_indentUnit);
    out.write(input.millisecondsSinceEpoch);
    out.write(eolIndent);
    out.write(')');
  }

  static int _clampUnixMillis(int unixMillis) {
    return unixMillis.clamp(-8640000000000000, 8640000000000000);
  }

  @override
  String get typeName => 'timestamp';

  @override
  ReflectiveTypeDescriptor get typeDescriptor =>
      PrimitiveDescriptor(PrimitiveType.TIMESTAMP);
}

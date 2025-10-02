// TODO: address TO SORT
// TODO: remove DecodeResult?
// TODO: KeyedList

import 'dart:convert';
import 'dart:typed_data';
import 'package:typed_data/typed_buffers.dart';
import 'type_descriptor.dart';
import 'internal/binary_utils.dart';

/// A serializer for converting objects of type [T] to and from various formats including JSON and binary.
///
/// This class provides comprehensive serialization capabilities for Soia types, supporting both
/// human-readable JSON and efficient binary encoding formats.
class Serializer<T> {
  final _SerializerImpl<T> _impl;

  const Serializer._(this._impl);

  /// Converts an object to its JSON representation.
  ///
  /// [input] The object to serialize
  /// [readableFlavor] Whether to produce a more human-readable and less compact
  ///     JSON representation. Not suitable for persistence: renaming fields in
  ///     the '.soia' file, which is allowed by design, will break backward
  ///     compatibility.
  /// Returns the JSON representation as a dynamic object
  dynamic toJson(
    T input, {
    bool readableFlavor = false,
  }) {
    return _impl.toJson(input, readableFlavor);
  }

  /// Converts an object to its JSON string representation.
  ///
  /// [input] The object to serialize
  /// [readableFlavor] Whether to produce a more human-readable and less compact
  ///     JSON representation. Not suitable for persistence: renaming fields in
  ///     the '.soia' file, which is allowed by design, will break backward
  ///     compatibility.
  /// Returns the JSON representation as a string
  String toJsonCode(
    T input, {
    bool readableFlavor = false,
  }) {
    final jsonElement = _impl.toJson(input, readableFlavor);
    if (readableFlavor) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(jsonElement);
    } else {
      return jsonEncode(jsonElement);
    }
  }

  /// Deserializes an object from its JSON representation.
  ///
  /// [json] The JSON element to deserialize
  /// [keepUnrecognizedFields] Whether to keep unrecognized fields during deserialization
  /// Returns the deserialized object
  T fromJson(
    dynamic json, {
    bool keepUnrecognizedFields = false,
  }) {
    return _impl.fromJson(json, keepUnrecognizedFields);
  }

  /// Deserializes an object from its JSON string representation.
  ///
  /// [jsonCode] The JSON string to deserialize
  /// [keepUnrecognizedFields] Whether to keep unrecognized fields during deserialization
  /// Returns the deserialized object
  T fromJsonCode(
    String jsonCode, {
    bool keepUnrecognizedFields = false,
  }) {
    final jsonElement = jsonDecode(jsonCode);
    return _impl.fromJson(jsonElement, keepUnrecognizedFields);
  }

  /// Converts an object to its binary representation.
  ///
  /// The binary format includes a "soia" header followed by the encoded data,
  /// providing an efficient storage format for Soia objects.
  ///
  /// [input] The object to serialize
  /// Returns the binary representation as a Uint8List
  Uint8List toBytes(T input) {
    final buffer = Uint8Buffer();
    buffer.addAll('soia'.codeUnits);
    _impl.encode(input, buffer);
    return buffer.buffer.asUint8List(0, buffer.length);
  }

  /// Deserializes an object from its binary representation.
  ///
  /// [bytes] The byte array containing the serialized data
  /// [keepUnrecognizedFields] Whether to keep unrecognized fields during deserialization
  /// Returns the deserialized object
  T fromBytes(
    Uint8List bytes, {
    bool keepUnrecognizedFields = false,
  }) {
    if (bytes.length >= 4 &&
        bytes[0] == 's'.codeUnitAt(0) &&
        bytes[1] == 'o'.codeUnitAt(0) &&
        bytes[2] == 'i'.codeUnitAt(0) &&
        bytes[3] == 'a'.codeUnitAt(0)) {
      final data = bytes.sublist(4);
      final result = _impl.decode(data, keepUnrecognizedFields);
      return result;
    } else {
      // Fallback to JSON if no "soia" header
      final jsonCode = String.fromCharCodes(bytes);
      return fromJsonCode(jsonCode,
          keepUnrecognizedFields: keepUnrecognizedFields);
    }
  }

  /// Gets the type descriptor that describes the structure of type [T].
  ///
  /// This provides reflective information about the type, including field names,
  /// types, and other metadata useful for introspection and tooling.
  TypeDescriptor get typeDescriptor => _impl.typeDescriptor;

  /// Creates a string representation of the input object.
  ///
  /// [input] The object to convert to string
  /// Returns a formatted string representation
  String stringify(T input) {
    final stringBuffer = StringBuffer();
    _impl.appendString(input, stringBuffer, '\n');
    return stringBuffer.toString();
  }
}

/// Internal implementation base class for serializers
abstract class _SerializerImpl<T> {
  /// Checks if a value is the default value for this type
  bool isDefault(T value);

  /// Converts an object to its JSON representation
  dynamic toJson(T input, bool readableFlavor);

  /// Deserializes an object from its JSON representation
  T fromJson(dynamic json, bool keepUnrecognizedFields);

  /// Encodes an object to binary format
  void encode(T input, Uint8Buffer buffer);

  /// Decodes an object from binary format
  T decode(Uint8List buffer, bool keepUnrecognizedFields);

  /// Appends a string representation of the object to the output buffer
  void appendString(T input, StringBuffer out, String eolIndent);

  /// Gets the type descriptor for this serializer
  TypeDescriptor get typeDescriptor;

  /// Gets the type signature as a JSON element
  dynamic get typeSignature;

  /// Adds record definitions to the output map
  void addRecordDefinitionsTo(Map<String, dynamic> out);
}

/// Result of decoding operation
class DecodeResult<T> {
  final T value;
  final int bytesRead;

  DecodeResult(this.value, this.bytesRead);
}

/// Constant for indentation unit
const String _indentUnit = '  ';

/// Provides predefined serializers for all primitive types and utilities for creating
/// composite serializers such as optional and list serializers.
///
/// This class serves as the main entry point for accessing serializers for basic types
/// like integers, strings, timestamps, etc., as well as for constructing more complex
/// serializers for optional values and collections.
class Serializers {
  Serializers._() {}

  /// Serializer for Boolean values.
  static final Serializer<bool> BOOL = Serializer._(BoolSerializer());

  /// Serializer for 32-bit signed integers.
  static final Serializer<int> INT_32 = Serializer._(Int32Serializer());

  /// Serializer for 64-bit signed integers.
  static final Serializer<int> INT_64 = Serializer._(Int64Serializer());

  /// Serializer for 64-bit unsigned integers.
  static final Serializer<int> UINT_64 = Serializer._(Uint64Serializer());

  /// Serializer for 32-bit floating-point numbers.
  static final Serializer<double> FLOAT_32 = Serializer._(Float32Serializer());

  /// Serializer for 64-bit floating-point numbers.
  static final Serializer<double> FLOAT_64 = Serializer._(Float64Serializer());

  /// Serializer for UTF-8 strings.
  static final Serializer<String> STRING = Serializer._(StringSerializer());

  /// Serializer for binary data (byte arrays).
  static final Serializer<Uint8List> BYTES = Serializer._(BytesSerializer());

  /// Serializer for timestamp values.
  static final Serializer<DateTime> TIMESTAMP =
      Serializer._(TimestampSerializer());

  /// Creates a serializer for optional values of type [T].
  ///
  /// [other] The serializer for the wrapped type
  /// Returns a serializer that can handle null values of the given type
  static Serializer<T?> optional<T>(Serializer<T> other) {
    final otherImpl = other._impl;
    if (otherImpl is _OptionalSerializer<T>) {
      return other as Serializer<T?>;
    } else {
      return Serializer._(_OptionalSerializer<T>(otherImpl));
    }
  }

  /// Creates a serializer for lists of elements of type [E].
  ///
  /// [item] The serializer for individual list elements
  /// Returns a serializer that can handle lists of the given element type
  static Serializer<List<E>> list<E>(Serializer<E> item) {
    return Serializer._(_ListSerializer<E>(item._impl));
  }
}

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

class BoolSerializer extends _PrimitiveSerializer<bool> {
  @override
  bool isDefault(bool value) => !value;

  @override
  void encode(bool input, Uint8Buffer buffer) {
    buffer.add(input ? 1 : 0);
  }

  @override
  bool decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = BinaryReader(buffer);
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
  TypeDescriptor get typeDescriptor => PrimitiveTypeDescriptor.bool;
}

class Int32Serializer extends _PrimitiveSerializer<int> {
  @override
  bool isDefault(int value) => value == 0;

  @override
  void encode(int input, Uint8Buffer buffer) {
    BinaryWriter.encodeInt32(input, buffer);
  }

  @override
  int decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = BinaryReader(buffer);
    return reader.decodeNumber().toInt();
  }

  @override
  dynamic toJson(int input, bool readableFlavor) => input;

  @override
  int fromJson(dynamic json, bool keepUnrecognizedFields) {
    if (json is int) return json;
    if (json is String) return int.parse(json);
    return (json as num).toInt();
  }

  @override
  void appendString(int input, StringBuffer out, String eolIndent) {
    out.write(input);
  }

  @override
  String get typeName => 'int32';

  @override
  TypeDescriptor get typeDescriptor => PrimitiveTypeDescriptor.int;
}

class Int64Serializer extends _PrimitiveSerializer<int> {
  static const int minSafeJavaScriptInt = -9007199254740992; // -(2 ^ 53)
  static const int maxSafeJavaScriptInt = 9007199254740992; // 2 ^ 53

  @override
  bool isDefault(int value) => value == 0;

  @override
  void encode(int input, Uint8Buffer buffer) {
    if (input >= -2147483648 && input <= 2147483647) {
      Int32Serializer().encode(input, buffer);
    } else {
      buffer.add(238);
      BinaryWriter.writeLongLe(input, buffer);
    }
  }

  @override
  int decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = BinaryReader(buffer);
    return reader.decodeNumber().toInt();
  }

  @override
  dynamic toJson(int input, bool readableFlavor) {
    return (input >= minSafeJavaScriptInt && input <= maxSafeJavaScriptInt)
        ? input
        : input.toString();
  }

  @override
  int fromJson(dynamic json, bool keepUnrecognizedFields) {
    if (json is int) return json;
    if (json is String) return int.parse(json);
    return (json as num).toInt();
  }

  @override
  void appendString(int input, StringBuffer out, String eolIndent) {
    out.write(input);
  }

  @override
  String get typeName => 'int64';

  @override
  TypeDescriptor get typeDescriptor => PrimitiveTypeDescriptor.int;
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
        BinaryWriter.writeShortLe(input, buffer);
      } else {
        buffer.add(233);
        BinaryWriter.writeIntLe(input, buffer);
      }
    } else {
      buffer.add(234);
      BinaryWriter.writeLongLe(input, buffer);
    }
  }

  @override
  int decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = BinaryReader(buffer);
    return reader.decodeNumber().toInt();
  }

  @override
  dynamic toJson(int input, bool readableFlavor) {
    return input <= maxSafeJavaScriptInt ? input : input.toString();
  }

  @override
  int fromJson(dynamic json, bool keepUnrecognizedFields) {
    if (json is int) return json;
    if (json is String) return int.parse(json);
    return (json as num).toInt();
  }

  @override
  void appendString(int input, StringBuffer out, String eolIndent) {
    out.write(input);
  }

  @override
  String get typeName => 'uint64';

  @override
  TypeDescriptor get typeDescriptor => PrimitiveTypeDescriptor.int;
}

class Float32Serializer extends _PrimitiveSerializer<double> {
  @override
  bool isDefault(double value) => value == 0.0;

  @override
  void encode(double input, Uint8Buffer buffer) {
    if (input == 0.0) {
      buffer.add(0);
    } else {
      buffer.add(240);
      BinaryWriter.writeFloatLe(input, buffer);
    }
  }

  @override
  double decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = BinaryReader(buffer);
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
  TypeDescriptor get typeDescriptor => PrimitiveTypeDescriptor.double;
}

class Float64Serializer extends _PrimitiveSerializer<double> {
  @override
  bool isDefault(double value) => value == 0.0;

  @override
  void encode(double input, Uint8Buffer buffer) {
    if (input == 0.0) {
      buffer.add(0);
    } else {
      buffer.add(241);
      BinaryWriter.writeDoubleLe(input, buffer);
    }
  }

  @override
  double decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = BinaryReader(buffer);
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
  TypeDescriptor get typeDescriptor => PrimitiveTypeDescriptor.double;
}

class StringSerializer extends _PrimitiveSerializer<String> {
  @override
  bool isDefault(String value) => value.isEmpty;

  @override
  void encode(String input, Uint8Buffer buffer) {
    if (input.isEmpty) {
      buffer.add(242);
    } else {
      buffer.add(243);
      final bytes = utf8.encode(input);
      BinaryWriter.encodeLengthPrefix(bytes.length, buffer);
      buffer.addAll(bytes);
    }
  }

  @override
  String decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = BinaryReader(buffer);
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
  TypeDescriptor get typeDescriptor => PrimitiveTypeDescriptor.string;
}

class BytesSerializer extends _PrimitiveSerializer<Uint8List> {
  @override
  bool isDefault(Uint8List value) => value.isEmpty;

  @override
  void encode(Uint8List input, Uint8Buffer buffer) {
    if (input.isEmpty) {
      buffer.add(244);
    } else {
      buffer.add(245);
      BinaryWriter.encodeLengthPrefix(input.length, buffer);
      buffer.addAll(input);
    }
  }

  @override
  Uint8List decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = BinaryReader(buffer);
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
  TypeDescriptor get typeDescriptor => PrimitiveTypeDescriptor('bytes');
}

class TimestampSerializer extends _PrimitiveSerializer<DateTime> {
  @override
  bool isDefault(DateTime value) => value.millisecondsSinceEpoch == 0;

  @override
  void encode(DateTime input, Uint8Buffer buffer) {
    final unixMillis = _clampUnixMillis(input.millisecondsSinceEpoch);
    if (unixMillis == 0) {
      buffer.add(0);
    } else {
      buffer.add(239);
      BinaryWriter.writeLongLe(unixMillis, buffer);
    }
  }

  @override
  DateTime decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = BinaryReader(buffer);
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

  int _clampUnixMillis(int unixMillis) {
    return unixMillis.clamp(-8640000000000000, 8640000000000000);
  }

  @override
  String get typeName => 'timestamp';

  @override
  TypeDescriptor get typeDescriptor => PrimitiveTypeDescriptor('timestamp');
}

class _OptionalSerializer<T> extends _SerializerImpl<T?> {
  final _SerializerImpl<T> other;

  _OptionalSerializer(this.other);

  @override
  bool isDefault(T? value) => value == null;

  @override
  void encode(T? input, Uint8Buffer buffer) {
    if (input == null) {
      buffer.add(255);
    } else {
      other.encode(input, buffer);
    }
  }

  @override
  T? decode(Uint8List buffer, bool keepUnrecognizedFields) {
    if (buffer.isNotEmpty && buffer[0] == 255) {
      return null;
    } else {
      return other.decode(buffer, keepUnrecognizedFields);
    }
  }

  @override
  void appendString(T? input, StringBuffer out, String eolIndent) {
    if (input == null) {
      out.write('null');
    } else {
      other.appendString(input, out, eolIndent);
    }
  }

  @override
  dynamic toJson(T? input, bool readableFlavor) {
    return input == null ? null : other.toJson(input, readableFlavor);
  }

  @override
  T? fromJson(dynamic json, bool keepUnrecognizedFields) {
    return json == null ? null : other.fromJson(json, keepUnrecognizedFields);
  }

  @override
  dynamic get typeSignature => {
        'kind': 'optional',
        'value': other.typeSignature,
      };

  @override
  void addRecordDefinitionsTo(Map<String, dynamic> out) {
    other.addRecordDefinitionsTo(out);
  }

  @override
  TypeDescriptor get typeDescriptor =>
      OptionalTypeDescriptor(other.typeDescriptor);
}

class _ListSerializer<E> extends _SerializerImpl<List<E>> {
  final _SerializerImpl<E> item;

  _ListSerializer(this.item);

  @override
  bool isDefault(List<E> value) => value.isEmpty;

  @override
  void encode(List<E> input, Uint8Buffer buffer) {
    BinaryWriter.encodeLengthPrefix(input.length, buffer);
    for (final element in input) {
      item.encode(element, buffer);
    }
  }

  @override
  List<E> decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = BinaryReader(buffer);
    final length = reader.decodeNumber().toInt();
    final result = <E>[];
    for (int i = 0; i < length; i++) {
      result.add(item.decode(reader.remainingBytes, keepUnrecognizedFields));
    }
    return result;
  }

  @override
  void appendString(List<E> input, StringBuffer out, String eolIndent) {
    out.write('[');
    for (int i = 0; i < input.length; i++) {
      if (i > 0) out.write(', ');
      item.appendString(input[i], out, eolIndent);
    }
    out.write(']');
  }

  @override
  dynamic toJson(List<E> input, bool readableFlavor) {
    return input.map((e) => item.toJson(e, readableFlavor)).toList();
  }

  @override
  List<E> fromJson(dynamic json, bool keepUnrecognizedFields) {
    final list = json as List;
    return list.map((e) => item.fromJson(e, keepUnrecognizedFields)).toList();
  }

  @override
  dynamic get typeSignature => {
        'kind': 'list',
        'value': item.typeSignature,
      };

  @override
  void addRecordDefinitionsTo(Map<String, dynamic> out) {
    item.addRecordDefinitionsTo(out);
  }

  @override
  TypeDescriptor get typeDescriptor => ListTypeDescriptor(item.typeDescriptor);
}

class OptionalTypeDescriptor extends TypeDescriptor {
  final TypeDescriptor otherType;

  const OptionalTypeDescriptor(this.otherType);
}

// ========================================================================================================================================================================================================================================================
// TO SORT
// ========================================================================================================================================================================================================================================================

/// Helper function to create string representation of objects
String _toStringImpl<T>(T input, _SerializerImpl<T> serializer) {
  final stringBuffer = StringBuffer();
  serializer.appendString(input, stringBuffer, '\n');
  return stringBuffer.toString();
}

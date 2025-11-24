part of "../soia.dart";

/// Converts objects of type [T] to and from JSON or binary format.
class Serializer<T> {
  final _SerializerImpl<T> _impl;

  const Serializer._(this._impl);

  /// Converts an object to its JSON representation.
  /// If you just need the stringified JSON, call [toJsonCode] instead.
  ///
  /// The [readableFlavor] param controls whether to use readable or dense JSON
  /// flavor. If 'readable', structs are serialized as JSON objects, and enum
  /// constants are serialized as strings.
  /// If 'dense', structs are serialized as JSON arrays, where the field numbers
  /// in the index definition match the indexes in the array. Enum constants are
  /// serialized as numbers.
  ///
  /// The 'readable' flavor is more verbose and readable, but it should not be
  /// used if you need persistence, because soia allows fields to be renamed in
  /// record definitions. In other words, never store a readable JSON on disk or
  /// in a database.
  dynamic toJson(
    T input, {
    bool readableFlavor = false,
  }) {
    return _impl.toJson(input, readableFlavor);
  }

  /// Converts an object to its stringified JSON representation.
  ///
  /// The [readableFlavor] param controls whether to use readable or dense JSON
  /// flavor. If 'readable', structs are serialized as JSON objects, and enum
  /// constants are serialized as strings.
  /// If 'dense', structs are serialized as JSON arrays, where the field numbers
  /// in the index definition match the indexes in the array. Enum constants are
  /// serialized as numbers.
  ///
  /// The 'readable' flavor is more verbose and readable, but it should not be
  /// used if you need persistence, because soia allows fields to be renamed in
  /// record definitions. In other words, never store a readable JSON on disk or
  /// in a database.
  String toJsonCode(
    T input, {
    bool readableFlavor = false,
  }) {
    final jsonElement = _impl.toJson(input, readableFlavor);
    if (readableFlavor) {
      return _readableJsonEncoder.convert(jsonElement);
    } else {
      return jsonEncode(jsonElement);
    }
  }

  /// Deserializes an object from its JSON representation.
  /// Works with both dense and readable JSON flavors.
  ///
  /// If [keepUnrecognizedFields] is true, unrecognized fields are saved in the
  /// returned value. If the value is later re-serialized in JSON format (dense
  /// flavor), the unrecognized fields will be present in the serialized form.
  T fromJson(
    dynamic json, {
    bool keepUnrecognizedFields = false,
  }) {
    return _impl.fromJson(json, keepUnrecognizedFields);
  }

  /// Deserializes an object from its stringified JSON representation.
  /// Works with both dense and readable JSON flavors.
  ///
  /// If [keepUnrecognizedFields] is true, unrecognized fields are saved in the
  /// returned value. If the value is later re-serialized in JSON format (dense
  /// flavor), the unrecognized fields will be present in the serialized form.
  T fromJsonCode(
    String jsonCode, {
    bool keepUnrecognizedFields = false,
  }) {
    final jsonElement = jsonDecode(jsonCode);
    return _impl.fromJson(jsonElement, keepUnrecognizedFields);
  }

  /// Converts an object to its binary representation.
  Uint8List toBytes(T input) {
    final buffer = Uint8Buffer();
    buffer.addAll('soia'.codeUnits);
    _impl.encode(input, buffer);
    return buffer.buffer.asUint8List(0, buffer.length);
  }

  /// Deserializes an object from its binary representation.
  ///
  /// If [keepUnrecognizedFields] is true, unrecognized fields are saved in the
  /// returned value. If the value is later re-serialized in binary format, the
  /// unrecognized fields will be present in the serialized form.
  T fromBytes(
    Uint8List bytes, {
    bool keepUnrecognizedFields = false,
  }) {
    if (bytes.length >= 4 &&
        bytes[0] == 's'.codeUnitAt(0) &&
        bytes[1] == 'o'.codeUnitAt(0) &&
        bytes[2] == 'i'.codeUnitAt(0) &&
        bytes[3] == 'a'.codeUnitAt(0)) {
      final stream = _ByteStream(bytes, 4);
      final result = _impl.decode(stream, keepUnrecognizedFields);
      final extraBytes = bytes.length - stream.position;
      if (extraBytes != 0) {
        throw FormatException('Extra bytes found after deserializing value: '
            '${extraBytes} bytes remaining.');
      }
      return result;
    } else {
      // Fallback to JSON if no "soia" header
      final jsonCode = String.fromCharCodes(bytes);
      return fromJsonCode(jsonCode,
          keepUnrecognizedFields: keepUnrecognizedFields);
    }
  }

  /// The type descriptor that describes [T].
  /// Provides reflective information about the type. For structs and enums, it
  /// includes field names types, and other metadata useful for introspection
  /// and tooling.
  ReflectiveTypeDescriptor<T> get typeDescriptor => _impl.typeDescriptor;

  static final _readableJsonEncoder = JsonEncoder.withIndent('  ');
}

String internal__stringify<T>(T input, Serializer<T> serializer) {
  final stringBuffer = StringBuffer();
  serializer._impl.appendString(input, stringBuffer, '\n');
  return stringBuffer.toString();
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
  T decode(_ByteStream stream, bool keepUnrecognizedFields);

  /// Appends a string representation of the object to the output buffer
  void appendString(T input, StringBuffer out, String eolIndent);

  /// Gets the type descriptor for this serializer
  ReflectiveTypeDescriptor<T> get typeDescriptor;
}

/// Constant for indentation unit
const String _indentUnit = '  ';

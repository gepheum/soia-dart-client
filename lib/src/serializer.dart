part of "../soia.dart";

/// A serializer for converting objects of type [T] to and from various formats
/// including JSON and binary.
///
/// This class provides comprehensive serialization capabilities for Soia types,
/// supporting both human-readable JSON and efficient binary encoding formats.
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

  /// Gets the type descriptor that describes the structure of type [T].
  ///
  /// This provides reflective information about the type, including field names,
  /// types, and other metadata useful for introspection and tooling.
  ReflectiveTypeDescriptor get typeDescriptor => _impl.typeDescriptor;
}

/// Creates a string representation of the input object.
///
/// [input] The object to convert to string
/// Returns a formatted string representation
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
  ReflectiveTypeDescriptor get typeDescriptor;

  /// Gets the type signature as a JSON element
  dynamic get typeSignature;

  /// Adds record definitions to the output map
  void addRecordDefinitionsTo(Map<String, dynamic> out);
}

/// Constant for indentation unit
const String _indentUnit = '  ';

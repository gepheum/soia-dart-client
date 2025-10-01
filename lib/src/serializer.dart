import 'dart:convert';
import 'dart:typed_data';
import 'package:typed_data/typed_buffers.dart';

import 'internal/serializer_impl.dart';
import 'type_descriptor.dart';

/// A serializer for converting objects of type [T] to and from various formats including JSON and binary.
///
/// This class provides comprehensive serialization capabilities for Soia types, supporting both
/// human-readable JSON and efficient binary encoding formats.
class Serializer<T> {
  final SerializerImpl<T> _impl;

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

/// Result of decoding operation
class DecodeResult<T> {
  final T value;
  final int bytesRead;

  DecodeResult(this.value, this.bytesRead);
}

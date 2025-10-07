part of "../soia_client.dart";

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
      final stream = _ByteStream(Uint8Buffer()..addAll(data));
      final result = _impl.decode(stream, keepUnrecognizedFields);
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

  /// Creates a string representation of the input object.
  ///
  /// [input] The object to convert to string
  /// Returns a formatted string representation
  String internal__stringify(T input) {
    final stringBuffer = StringBuffer();
    _impl.appendString(input, stringBuffer, '\n');
    return stringBuffer.toString();
  }
}

class _ByteStream {
  final Uint8Buffer buffer;
  int position = 0;

  _ByteStream(this.buffer);

  int peekByte() => buffer[position];

  int readByte() {
    if (position >= buffer.length) {
      throw StateError('Buffer underflow');
    }
    return buffer[position++];
  }

  Uint8List readBytes(int count) {
    if (position + count > buffer.length) {
      throw StateError('Buffer underflow');
    }
    final result = buffer.buffer.asUint8List(position, count);
    position += count;
    return result;
  }

  Uint8List get remainingBytes {
    return buffer.buffer.asUint8List(position, buffer.length - position);
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
      case 239:
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

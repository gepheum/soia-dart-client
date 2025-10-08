part of "../soia.dart";

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
  T? decode(_ByteStream stream, bool keepUnrecognizedFields) {
    if (stream.peekByte() == 255) {
      stream.position++;
      return null;
    } else {
      return other.decode(stream, keepUnrecognizedFields);
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
  ReflectiveTypeDescriptor get typeDescriptor =>
      ReflectiveOptionalDescriptor(other.typeDescriptor);
}

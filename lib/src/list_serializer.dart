part of "../soia_client.dart";

class _ListSerializer<E> extends _SerializerImpl<List<E>> {
  final _SerializerImpl<E> item;
  final String getKeySpec;

  _ListSerializer(this.item, this.getKeySpec);

  @override
  bool isDefault(List<E> value) => value.isEmpty;

  @override
  void encode(List<E> input, Uint8Buffer buffer) {
    _BinaryWriter.encodeLengthPrefix(input.length, buffer);
    for (final element in input) {
      item.encode(element, buffer);
    }
  }

  @override
  List<E> decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = _BinaryReader(buffer);
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
  ReflectiveTypeDescriptor get typeDescriptor =>
      ReflectiveListDescriptor(item.typeDescriptor, getKeySpec);
}

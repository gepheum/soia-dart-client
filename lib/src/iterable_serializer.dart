part of "../soia_client.dart";

class _IterableSerializer<E, Collection extends Iterable<E>>
    extends _SerializerImpl<Collection> {
  final _SerializerImpl<E> item;
  final String getKeySpec;
  final Collection Function(Iterable<E>) toCollection;

  static iterable<E>(_SerializerImpl<E> item) =>
      _IterableSerializer<E, Iterable<E>>(
          item, "", (it) => it.toList(growable: false));

  static keyedIterable<E, K>(
          _SerializerImpl<E> item, String getKeySpec, K Function(E) getKey) =>
      _IterableSerializer<E, KeyedIterable<E, K>>(
          item, getKeySpec, (it) => KeyedIterable.copy(it, getKey));

  _IterableSerializer(this.item, this.getKeySpec, this.toCollection);

  @override
  bool isDefault(Iterable<E> value) => value.isEmpty;

  @override
  void encode(Iterable<E> input, Uint8Buffer buffer) {
    _BinaryWriter.encodeLengthPrefix(input.length, buffer);
    for (final element in input) {
      item.encode(element, buffer);
    }
  }

  @override
  Collection decode(_ByteStream stream, bool keepUnrecognizedFields) {
    final length = stream.decodeNumber().toInt();
    final result = <E>[];
    for (int i = 0; i < length; i++) {
      result.add(item.decode(stream, keepUnrecognizedFields));
    }
    return toCollection(result);
  }

  @override
  void appendString(Iterable<E> input, StringBuffer out, String eolIndent) {
    out.write('[');
    var separator = "";
    for (final E element in input) {
      out.write(separator);
      separator = ", ";
      item.appendString(element, out, eolIndent);
    }
    out.write(']');
  }

  @override
  dynamic toJson(Iterable<E> input, bool readableFlavor) {
    return input
        .map((e) => item.toJson(e, readableFlavor))
        .toList(growable: false);
  }

  @override
  Collection fromJson(dynamic json, bool keepUnrecognizedFields) {
    final list = json as List;
    return toCollection(
        list.map((e) => item.fromJson(e, keepUnrecognizedFields)));
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

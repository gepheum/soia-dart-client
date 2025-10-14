part of "../soia.dart";

/// Specialization of a [Serializer] for generated enum types.
class EnumSerializer<Enum> extends Serializer<Enum> {
  EnumSerializer._(_EnumSerializerImpl<Enum, dynamic> impl) : super._(impl);

  @override
  ReflectiveEnumDescriptor<Enum> get typeDescriptor =>
      super._impl as _EnumSerializerImpl<Enum, dynamic>;
}

class internal__EnumSerializerBuilder<Enum, Kind> {
  final _EnumSerializerImpl<Enum, Kind> _impl;
  final EnumSerializer<Enum> serializer;
  bool _initialized = false;

  internal__EnumSerializerBuilder._(this._impl, this.serializer);

  static internal__EnumSerializerBuilder<Enum, Kind>
      create<Enum, Kind, Unknown extends Enum>({
    required String recordId,
    required Unknown unknownInstance,
    required Enum enumInstance, // For type inference, not used at runtime
    required Kind Function(Enum) getKind,
    required int Function(Kind) getNumber,
    required Enum Function(internal__UnrecognizedEnum) wrapUnrecognized,
    required internal__UnrecognizedEnum? Function(Unknown) getUnrecognized,
  }) {
    final impl = _EnumSerializerImpl._(
      recordId,
      _EnumUnknownField<Enum, Kind>(
        getKind(unknownInstance),
        unknownInstance,
        wrapUnrecognized,
        (Enum e) => e is Unknown ? getUnrecognized(e) : null,
      ),
      getKind,
      getNumber,
    );
    return internal__EnumSerializerBuilder<Enum, Kind>._(
        impl, EnumSerializer._(impl));
  }

  bool mustInitialize() {
    if (_initialized) {
      return false;
    } else {
      _initialized = true;
      return true;
    }
  }

  void addConstantField(String name, Enum instance) {
    _impl.addConstantField(name, instance);
  }

  void addValueField<Wrapper extends Enum, Value>(
    String name,
    Kind kind,
    Serializer<Value> valueSerializer,
    Wrapper Function(Value) wrap,
    Value Function(Wrapper) getValue,
  ) {
    _impl.addValueField<Wrapper, Value>(
      name,
      kind,
      valueSerializer,
      wrap,
      getValue,
    );
  }

  void addRemovedNumber(int number) {
    _impl.addRemovedNumber(number);
  }

  void finalize() {
    _impl.finalize();
  }
}

/// Enum serializer implementation
class _EnumSerializerImpl<E, K> extends ReflectiveEnumDescriptor<E>
    implements _SerializerImpl<E> {
  final _RecordId recordId;
  final _EnumUnknownField<E, K> unknown;
  final K Function(E) getKind;
  final int Function(K) getNumber;

  _EnumSerializerImpl._(
      String recordId, this.unknown, this.getKind, this.getNumber)
      : recordId = _RecordId.parse(recordId);

  @override
  String get name => recordId.name;

  @override
  String get qualifiedName => recordId.qualifiedName;

  @override
  String get modulePath => recordId.modulePath;

  void addConstantField(String name, E instance) {
    checkNotFinalized();
    final kind = getKind(instance);
    final number = getNumber(kind);
    addFieldImpl(_EnumConstantField<E, K>(number, name, kind, instance));
  }

  void addValueField<W extends E, V>(
    String name,
    K kind,
    Serializer<V> valueSerializer,
    W Function(V) wrap,
    V Function(W) getValue,
  ) {
    checkNotFinalized();
    final number = getNumber(kind);
    addFieldImpl(_ValueField<E, K, W, V>(
      number,
      name,
      kind,
      valueSerializer,
      wrap,
      getValue,
    ));
  }

  void addRemovedNumber(int number) {
    checkNotFinalized();
    mutableRemovedNumbers.add(number);
    numberToField[number] = _EnumRemovedNumber<E, K>(number);
  }

  void finalize() {
    checkNotFinalized();
    addFieldImpl(unknown);
    finalized = true;
  }

  void checkNotFinalized() {
    if (finalized) {
      throw StateError('Enum is already finalized');
    }
  }

  void addFieldImpl(_EnumField<E, K> field) {
    mutableFields.add(field);
    numberToField[field.number] = field;
    nameToField[field.name] = field;
    kindToField[field.kind] = field;
  }

  final List<_EnumField<E, K>> mutableFields = [];
  final Set<int> mutableRemovedNumbers = <int>{};
  final Map<int, _EnumFieldOrRemovedNumber<E, K>> numberToField = {};
  final Map<String, _EnumField<E, K>> nameToField = {};
  final Map<K, _EnumField<E, K>> kindToField = {};
  bool finalized = false;

  @override
  bool isDefault(E value) => identical(value, unknown.constant);

  @override
  dynamic toJson(E input, bool readableFlavor) {
    final field = kindToField[getKind(input)]!;
    return field.toJson(input, readableFlavor);
  }

  @override
  E fromJson(dynamic json, bool keepUnrecognizedFields) {
    if (json is int || (json is String && int.tryParse(json) != null)) {
      final number = json is int ? json : int.parse(json);
      final field = numberToField[number];
      switch (field) {
        case _EnumUnknownField():
          return unknown.constant;
        case _EnumConstantField():
          return field.constant;
        case _EnumRemovedNumber():
          return unknown.constant;
        case _ValueField():
          throw ArgumentError('$number refers to a value field');
        default:
          if (keepUnrecognizedFields) {
            return unknown
                .wrapUnrecognized(internal__UnrecognizedEnum._fromJson(json));
          } else {
            return unknown.constant;
          }
      }
    } else if (json is String) {
      final field = nameToField[json];
      if (field is _EnumConstantField<E, K>) {
        return field.constant;
      } else {
        return unknown.constant;
      }
    } else if (json is List && json.length >= 2) {
      final first = json[0];
      final number =
          first is int ? first : (first is String ? int.tryParse(first) : null);
      if (number != null) {
        final field = numberToField[number];
        if (field is _ValueField<E, K, dynamic, dynamic>) {
          final second = json[1];
          return field.wrapFromJson(second, keepUnrecognizedFields);
        } else if (field is _EnumRemovedNumber<E, K>) {
          return unknown.constant;
        } else {
          if (keepUnrecognizedFields) {
            return unknown
                .wrapUnrecognized(internal__UnrecognizedEnum._fromJson(json));
          } else {
            return unknown.constant;
          }
        }
      }
    } else if (json is Map<String, dynamic>) {
      final name = json['kind'] as String?;
      final value = json['value'];
      if (name != null && value != null) {
        final field = nameToField[name];
        if (field is _ValueField<E, K, dynamic, dynamic>) {
          return field.wrapFromJson(value, keepUnrecognizedFields);
        }
      }
    }
    return unknown.constant;
  }

  @override
  void encode(E input, Uint8Buffer buffer) {
    final field = kindToField[getKind(input)]!;
    field.encode(input, buffer);
  }

  @override
  E decode(_ByteStream stream, bool keepUnrecognizedFields) {
    final wire = stream.readByte();
    late E result;

    if (wire < 242) {
      // A number: rewind and decode
      stream.position--; // rewind the byte we just read
      final startPosition = stream.position;
      final number = stream.decodeNumber().toInt();
      final field = numberToField[number];

      switch (field) {
        case _EnumConstantField():
          result = field.constant;
        case _EnumRemovedNumber():
          result = unknown.constant;
        case _ValueField():
          throw ArgumentError('$number refers to a value field');
        default:
          if (keepUnrecognizedFields) {
            // Capture the bytes for the unknown enum
            final consumed = stream.position - startPosition;
            final bytes =
                stream.buffer.buffer.asUint8List(startPosition, consumed);
            result = unknown
                .wrapUnrecognized(internal__UnrecognizedEnum._fromBytes(bytes));
          } else {
            result = unknown.constant;
          }
      }
    } else {
      final number = wire == 248 ? stream.decodeNumber().toInt() : wire - 250;
      final field = numberToField[number];

      if (field is _ValueField<E, K, dynamic, dynamic>) {
        result = field.wrapDecoded(stream, keepUnrecognizedFields);
      } else if (field is _EnumRemovedNumber<E, K>) {
        result = unknown.constant;
      } else {
        if (keepUnrecognizedFields) {
          // For unknown value fields, we'll just return the unknown constant
          // since reconstructing the full bytes is complex
          result = unknown.constant;
        } else {
          result = unknown.constant;
        }
      }
    }

    return result;
  }

  @override
  void appendString(E input, StringBuffer out, String eolIndent) {
    final field = kindToField[getKind(input)]!;
    field.appendString(input, out, eolIndent);
  }

  @override
  Iterable<ReflectiveEnumField<E>> get fields =>
      mutableFields.map((f) => f.asField).toList(growable: false);

  @override
  UnmodifiableSetView<int> get removedNumbers =>
      UnmodifiableSetView(mutableRemovedNumbers);

  @override
  ReflectiveEnumField<E>? getFieldByName(String name) =>
      nameToField[name]?.asField;

  @override
  ReflectiveEnumField<E>? getFieldByNumber(int number) {
    final field = numberToField[number];
    return switch (field) {
      _EnumField<E, K> f => f.asField,
      _EnumRemovedNumber<E, K>() => null,
      null => null
    };
  }

  @override
  ReflectiveEnumField<E> getField(E e) {
    final field = kindToField[getKind(e)]!;
    return field.asField;
  }

  @override
  ReflectiveTypeDescriptor get typeDescriptor => this;

  @override
  dynamic get typeSignature => {
        'kind': 'enum',
        'value': recordId.toString(),
      };

  @override
  void addRecordDefinitionsTo(Map<String, dynamic> out) {
    out[recordId.toString()] = {
      'kind': 'enum',
      'fields': fieldDefinitions(),
    };
    for (final dep in dependencies()) {
      dep.addRecordDefinitionsTo(out);
    }
  }

  List<Map<String, dynamic>> fieldDefinitions() {
    return nameToField.values
        .map((field) {
          if (field is _EnumConstantField<E, K>) {
            return {
              'name': field.name,
              'number': field.number,
            };
          } else if (field is _ValueField<E, K, dynamic, dynamic>) {
            return {
              'name': field.name,
              'number': field.number,
              'type': field.valueSerializer._impl.typeSignature,
            };
          } else {
            return const <String, dynamic>{};
          }
        })
        .where((def) => def.isNotEmpty)
        .toList();
  }

  List<_SerializerImpl<dynamic>> dependencies() {
    return mutableFields
        .whereType<_ValueField>()
        .map((field) => field.valueSerializer._impl)
        .toList();
  }
}

// Abstract base class for enum field implementations
sealed class _EnumFieldOrRemovedNumber<E, K> {
  int get number;
}

sealed class _EnumField<E, K> extends _EnumFieldOrRemovedNumber<E, K>
    implements Field {
  @override
  final String name;
  final K kind;

  _EnumField(this.name, this.kind);

  ReflectiveEnumField<E> get asField;

  dynamic toJson(E input, bool readableFlavor);
  void encode(E input, Uint8Buffer buffer);
  void appendString(E input, StringBuffer out, String eolIndent);
}

class _EnumUnknownField<E, K> extends _EnumField<E, K>
    implements ReflectiveEnumConstantField<E> {
  @override
  final E constant;
  final E Function(internal__UnrecognizedEnum) wrapUnrecognized;
  final internal__UnrecognizedEnum? Function(E) getUnrecognized;

  _EnumUnknownField(
    K kind,
    this.constant,
    this.wrapUnrecognized,
    this.getUnrecognized,
  ) : super('?', kind);

  @override
  int get number => 0;

  ReflectiveEnumField<E> get asField => this;

  @override
  dynamic toJson(E input, bool readableFlavor) {
    if (readableFlavor) {
      return '?';
    } else {
      final unrecognized = getUnrecognized(input);
      return unrecognized?._jsonElement ?? 0;
    }
  }

  @override
  void encode(E input, Uint8Buffer buffer) {
    final unrecognized = getUnrecognized(input);
    if (unrecognized?._bytes != null) {
      buffer.addAll(unrecognized!._bytes!);
    } else {
      buffer.add(0);
    }
  }

  @override
  void appendString(E input, StringBuffer out, String eolIndent) {
    final className = input.runtimeType.toString().split('.').first;
    out.write('$className.UNKNOWN');
  }
}

class _EnumConstantField<E, K> extends _EnumField<E, K>
    implements ReflectiveEnumConstantField<E> {
  @override
  final int number;
  @override
  final E constant;

  _EnumConstantField(this.number, String name, K kind, this.constant)
      : super(name, kind);

  ReflectiveEnumField<E> get asField => this;

  @override
  dynamic toJson(E input, bool readableFlavor) {
    return readableFlavor ? name : number;
  }

  @override
  void encode(E input, Uint8Buffer buffer) {
    _BinaryWriter.encodeInt32(number, buffer);
  }

  @override
  void appendString(E input, StringBuffer out, String eolIndent) {
    final className = input.runtimeType.toString();
    out.write(className);
  }
}

// E: enum type
// K: kind type
// W: wrapped enum type (for value fields)
// V: value type
class _ValueField<E, K, W extends E, V> extends _EnumField<E, K>
    implements ReflectiveEnumValueField<E, V> {
  @override
  final int number;
  final Serializer<V> valueSerializer;
  final W Function(V) wrapFn;
  final V Function(W) getValue;

  _ValueField(
    this.number,
    String name,
    K kind,
    this.valueSerializer,
    this.wrapFn,
    this.getValue,
  ) : super(name, kind);

  ReflectiveEnumField<E> get asField => this;

  @override
  dynamic toJson(E input, bool readableFlavor) {
    final value = getValue(input as W);
    final valueToJson =
        valueSerializer.toJson(value, readableFlavor: readableFlavor);
    if (readableFlavor) {
      return {
        'kind': name,
        'value': valueToJson,
      };
    } else {
      return [number, valueToJson];
    }
  }

  @override
  void encode(E input, Uint8Buffer buffer) {
    final value = getValue(input as W);
    if (number < 5) {
      buffer.add(250 + number);
    } else {
      buffer.add(248);
      _BinaryWriter.encodeInt32(number, buffer);
    }
    valueSerializer._impl.encode(value, buffer);
  }

  @override
  void appendString(E input, StringBuffer out, String eolIndent) {
    final newEolIndent = eolIndent + _indentUnit;
    out.write('${input.runtimeType}($newEolIndent');
    final value = getValue(input as W);
    valueSerializer._impl.appendString(value, out, newEolIndent);
    out.write('$eolIndent)');
  }

  @override
  ReflectiveTypeDescriptor get type => valueSerializer._impl.typeDescriptor;

  @override
  bool test(E e) => e is W;

  @override
  V get(E e) => getValue(e as W);

  @override
  W wrap(V value) => wrapFn(value);

  W wrapFromJson(dynamic json, bool keepUnrecognizedFields) {
    final value = valueSerializer.fromJson(json,
        keepUnrecognizedFields: keepUnrecognizedFields);
    return wrap(value);
  }

  W wrapDecoded(_ByteStream stream, bool keepUnrecognizedFields) {
    final value = valueSerializer._impl.decode(stream, keepUnrecognizedFields);
    return wrap(value);
  }
}

class _EnumRemovedNumber<E, K> extends _EnumFieldOrRemovedNumber<E, K> {
  @override
  final int number;

  _EnumRemovedNumber(this.number);
}

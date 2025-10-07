part of "../soia_client.dart";

class EnumSerializerBuilder<Enum> {
  final _EnumSerializerImpl<Enum> _impl;

  EnumSerializerBuilder._(this._impl);

  static EnumSerializerBuilder<Enum> create<Enum, Unknown extends Enum>({
    required String recordId,
    required Unknown unknownInstance,
    required Enum Function(UnrecognizedEnum<Enum>) wrapUnrecognized,
    required UnrecognizedEnum<Enum>? Function(Unknown) getUnrecognized,
  }) {
    return EnumSerializerBuilder<Enum>._(_EnumSerializerImpl._(
      recordId,
      _EnumUnknownField<Enum>(
        unknownInstance.runtimeType,
        unknownInstance,
        wrapUnrecognized,
        (Enum e) => e is Unknown ? getUnrecognized(e) : null,
      ),
    ));
  }

  Serializer<Enum> get serializer => Serializer._(_impl);

  void addConstant(int number, String name, Enum instance) {
    _impl.addConstantField(number, name, instance);
  }

  void addValue<Instance extends Enum, V>(
    int number,
    String name,
    Type instanceType,
    Serializer<V> valueSerializer,
    Instance Function(V) wrap,
    V Function(Instance) getValue,
  ) {
    _impl.addValueField<Instance, V>(
      number,
      name,
      instanceType,
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
class _EnumSerializerImpl<Enum> extends ReflectiveEnumDescriptor<Enum>
    implements _SerializerImpl<Enum> {
  final _RecordId _recordId;
  final _EnumUnknownField<Enum> _unknown;

  _EnumSerializerImpl._(String recordId, this._unknown)
      : _recordId = _RecordId.parse(recordId);

  @override
  String get name => _recordId.name;

  @override
  String get qualifiedName => _recordId.qualifiedName;

  @override
  String get modulePath => _recordId.modulePath;

  void addConstantField(int number, String name, Enum instance) {
    _checkNotFinalized();
    _addFieldImpl(
        _EnumConstantField<Enum>(number, name, instance.runtimeType, instance));
  }

  void addValueField<Instance extends Enum, V>(
    int number,
    String name,
    Type instanceType,
    Serializer<V> valueSerializer,
    Instance Function(V) wrap,
    V Function(Instance) getValue,
  ) {
    _checkNotFinalized();
    _addFieldImpl(_ValueField<Enum, V>(
      number,
      name,
      instanceType,
      valueSerializer,
      (V value) => wrap(value) as Enum,
      (Enum instance) => getValue(instance as Instance),
    ));
  }

  void addRemovedNumber(int number) {
    _checkNotFinalized();
    _mutableRemovedNumbers.add(number);
    _numberToField[number] = _EnumRemovedNumber<Enum>(number);
  }

  void finalize() {
    _checkNotFinalized();
    _addFieldImpl(_unknown);
    _finalized = true;
  }

  void _checkNotFinalized() {
    if (_finalized) {
      throw StateError('Enum is already finalized');
    }
  }

  void _addFieldImpl(_EnumField<Enum> field) {
    _mutableFields.add(field);
    _numberToField[field.number] = field;
    _nameToField[field.name] = field;
    _instanceTypeToField[field.instanceType] = field;
  }

  final List<_EnumField<Enum>> _mutableFields = [];
  final Set<int> _mutableRemovedNumbers = <int>{};
  final Map<int, _EnumFieldOrRemovedNumber<Enum>> _numberToField = {};
  final Map<String, _EnumField<Enum>> _nameToField = {};
  final Map<Type, _EnumField<Enum>> _instanceTypeToField = {};
  bool _finalized = false;

  @override
  bool isDefault(Enum value) => identical(value, _unknown.constant);

  @override
  dynamic toJson(Enum input, bool readableFlavor) {
    final field = _instanceTypeToField[input.runtimeType]!;
    return field.toJson(input, readableFlavor);
  }

  @override
  Enum fromJson(dynamic json, bool keepUnrecognizedFields) {
    if (json is int || (json is String && int.tryParse(json) != null)) {
      final number = json is int ? json : int.parse(json);
      final field = _numberToField[number];
      switch (field.runtimeType) {
        case _EnumUnknownField:
          return _unknown.constant;
        case _EnumConstantField:
          return (field as _EnumConstantField<Enum>).constant;
        case _EnumRemovedNumber:
          return _unknown.constant;
        case _ValueField:
          throw ArgumentError('$number refers to a value field');
        default:
          if (keepUnrecognizedFields) {
            return _unknown.wrapUnrecognized(UnrecognizedEnum._fromJson(json));
          } else {
            return _unknown.constant;
          }
      }
    } else if (json is String) {
      final field = _nameToField[json];
      if (field is _EnumConstantField<Enum>) {
        return field.constant;
      } else {
        return _unknown.constant;
      }
    } else if (json is List && json.length >= 2) {
      final first = json[0];
      final number =
          first is int ? first : (first is String ? int.tryParse(first) : null);
      if (number != null) {
        final field = _numberToField[number];
        if (field is _ValueField<Enum, dynamic>) {
          final second = json[1];
          return field.wrapFromJson(second, keepUnrecognizedFields);
        } else if (field is _EnumRemovedNumber<Enum>) {
          return _unknown.constant;
        } else {
          if (keepUnrecognizedFields) {
            return _unknown.wrapUnrecognized(UnrecognizedEnum._fromJson(json));
          } else {
            return _unknown.constant;
          }
        }
      }
    } else if (json is Map<String, dynamic>) {
      final name = json['kind'] as String?;
      final value = json['value'];
      if (name != null && value != null) {
        final field = _nameToField[name];
        if (field is _ValueField<Enum, dynamic>) {
          return field.wrapFromJson(value, keepUnrecognizedFields);
        }
      }
    }
    return _unknown.constant;
  }

  @override
  void encode(Enum input, Uint8Buffer buffer) {
    final field = _instanceTypeToField[input.runtimeType]!;
    field.encode(input, buffer);
  }

  @override
  Enum decode(_ByteStream stream, bool keepUnrecognizedFields) {
    final wire = stream.readByte();
    late Enum result;

    if (wire < 242) {
      // A number: rewind and decode
      stream.position--; // rewind the byte we just read
      final startPosition = stream.position;
      final number = stream.decodeNumber().toInt();
      final field = _numberToField[number];

      if (field is _EnumConstantField<Enum>) {
        result = field.constant;
      } else if (field is _EnumRemovedNumber<Enum> ||
          field is _EnumUnknownField<Enum>) {
        result = _unknown.constant;
      } else if (field is _ValueField<Enum, dynamic>) {
        throw ArgumentError('${number} refers to a value field');
      } else {
        if (keepUnrecognizedFields) {
          // Capture the bytes for the unknown enum
          final consumed = stream.position - startPosition;
          final bytes =
              stream.buffer.buffer.asUint8List(startPosition, consumed);
          result =
              _unknown.wrapUnrecognized(UnrecognizedEnum._fromBytes(bytes));
        } else {
          result = _unknown.constant;
        }
      }
    } else {
      final number = wire == 248 ? stream.decodeNumber().toInt() : wire - 250;
      final field = _numberToField[number];

      if (field is _ValueField<Enum, dynamic>) {
        result = field.wrapDecoded(stream, keepUnrecognizedFields);
      } else if (field is _EnumRemovedNumber<Enum>) {
        result = _unknown.constant;
      } else {
        if (keepUnrecognizedFields) {
          // For unknown value fields, we'll just return the unknown constant
          // since reconstructing the full bytes is complex
          result = _unknown.constant;
        } else {
          result = _unknown.constant;
        }
      }
    }

    return result;
  }

  @override
  void appendString(Enum input, StringBuffer out, String eolIndent) {
    final field = _instanceTypeToField[input.runtimeType]!;
    field.appendString(input, out, eolIndent);
  }

  @override
  Iterable<ReflectiveEnumField<Enum>> get fields =>
      _mutableFields.map((f) => f.asField).toList(growable: false);

  @override
  UnmodifiableSetView<int> get removedNumbers =>
      UnmodifiableSetView(_mutableRemovedNumbers);

  @override
  ReflectiveEnumField<Enum>? getFieldByName(String name) =>
      _nameToField[name]?.asField;

  @override
  ReflectiveEnumField<Enum>? getFieldByNumber(int number) {
    final field = _numberToField[number];
    return switch (field) {
      _EnumField<Enum> f => f.asField,
      _EnumRemovedNumber<Enum>() => null,
      null => null
    };
  }

  @override
  ReflectiveEnumField<Enum> getField(Enum e) {
    final field = _instanceTypeToField[e.runtimeType]!;
    return field.asField;
  }

  _EnumField<Enum> getFieldByInstance(Enum e) =>
      _instanceTypeToField[e.runtimeType]!;

  @override
  ReflectiveTypeDescriptor get typeDescriptor => this;

  @override
  dynamic get typeSignature => {
        'kind': 'enum',
        'value': _recordId.toString(),
      };

  @override
  void addRecordDefinitionsTo(Map<String, dynamic> out) {
    out[_recordId.toString()] = {
      'kind': 'enum',
      'fields': fieldDefinitions(),
    };
    for (final dep in dependencies()) {
      dep.addRecordDefinitionsTo(out);
    }
  }

  List<Map<String, dynamic>> fieldDefinitions() {
    return _nameToField.values
        .where((field) => field is! _EnumUnknownField<Enum>)
        .map((field) {
          if (field is _EnumConstantField<Enum>) {
            return {
              'name': field.name,
              'number': field.number,
            };
          } else if (field is _ValueField<Enum, dynamic>) {
            return {
              'name': field.name,
              'number': field.number,
              'type': field.valueSerializer._impl.typeSignature,
            };
          }
          return <String, dynamic>{};
        })
        .where((def) => def.isNotEmpty)
        .toList();
  }

  List<_SerializerImpl<dynamic>> dependencies() {
    return _mutableFields
        .whereType<_ValueField<Enum, dynamic>>()
        .map((field) => field.valueSerializer._impl)
        .toList();
  }
}

// Abstract base class for enum field implementations
sealed class _EnumFieldOrRemovedNumber<T> {
  int get number;
}

sealed class _EnumField<T> extends _EnumFieldOrRemovedNumber<T>
    implements Field {
  @override
  final String name;
  final Type instanceType;

  _EnumField(this.name, this.instanceType);

  ReflectiveEnumField<T> get asField;

  dynamic toJson(T input, bool readableFlavor);
  void encode(T input, Uint8Buffer buffer);
  void appendString(T input, StringBuffer out, String eolIndent);
}

class _EnumUnknownField<T> extends _EnumField<T>
    implements ReflectiveEnumConstantField<T> {
  @override
  final T constant;
  final T Function(UnrecognizedEnum<T>) wrapUnrecognized;
  final UnrecognizedEnum<T>? Function(T) getUnrecognized;

  _EnumUnknownField(
    Type instanceType,
    this.constant,
    this.wrapUnrecognized,
    this.getUnrecognized,
  ) : super('?', instanceType);

  @override
  int get number => 0;

  ReflectiveEnumField<T> get asField => this;

  @override
  dynamic toJson(T input, bool readableFlavor) {
    if (readableFlavor) {
      return '?';
    } else {
      final unrecognized = getUnrecognized(input);
      return unrecognized?._jsonElement ?? 0;
    }
  }

  @override
  void encode(T input, Uint8Buffer buffer) {
    final unrecognized = getUnrecognized(input);
    if (unrecognized?._bytes != null) {
      buffer.addAll(unrecognized!._bytes!);
    } else {
      buffer.add(0);
    }
  }

  @override
  void appendString(T input, StringBuffer out, String eolIndent) {
    final className = input.runtimeType.toString().split('.').first;
    out.write('$className.UNKNOWN');
  }
}

class _EnumConstantField<T> extends _EnumField<T>
    implements ReflectiveEnumConstantField<T> {
  @override
  final int number;
  @override
  final T constant;

  _EnumConstantField(this.number, String name, Type instanceType, this.constant)
      : super(name, instanceType);

  ReflectiveEnumField<T> get asField => this;

  @override
  dynamic toJson(T input, bool readableFlavor) {
    return readableFlavor ? name : number;
  }

  @override
  void encode(T input, Uint8Buffer buffer) {
    _BinaryWriter.encodeInt32(number, buffer);
  }

  @override
  void appendString(T input, StringBuffer out, String eolIndent) {
    final className = input.runtimeType.toString();
    out.write(className);
  }
}

class _ValueField<T, V> extends _EnumField<T>
    implements ReflectiveEnumValueField<T, V> {
  @override
  final int number;
  final Serializer<V> valueSerializer;
  final T Function(V) wrapFn;
  final V Function(T) getValue;

  _ValueField(
    this.number,
    String name,
    Type instanceType,
    this.valueSerializer,
    this.wrapFn,
    this.getValue,
  ) : super(name, instanceType);

  ReflectiveEnumField<T> get asField => this;

  @override
  dynamic toJson(T input, bool readableFlavor) {
    final value = getValue(input);
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
  void encode(T input, Uint8Buffer buffer) {
    final value = getValue(input);
    if (number < 5) {
      buffer.add(250 + number);
    } else {
      buffer.add(248);
      _BinaryWriter.encodeInt32(number, buffer);
    }
    valueSerializer._impl.encode(value, buffer);
  }

  @override
  void appendString(T input, StringBuffer out, String eolIndent) {
    final newEolIndent = eolIndent + _indentUnit;
    out.write('${input.runtimeType}($newEolIndent');
    final value = getValue(input);
    valueSerializer._impl.appendString(value, out, newEolIndent);
    out.write('$eolIndent)');
  }

  @override
  ReflectiveTypeDescriptor get type => valueSerializer._impl.typeDescriptor;

  @override
  bool test(T e) => e.runtimeType == instanceType;

  @override
  V get(T e) => getValue(e);

  @override
  T wrap(V value) => wrapFn(value);

  T wrapFromJson(dynamic json, bool keepUnrecognizedFields) {
    final value = valueSerializer.fromJson(json,
        keepUnrecognizedFields: keepUnrecognizedFields);
    return wrap(value);
  }

  T wrapDecoded(_ByteStream stream, bool keepUnrecognizedFields) {
    final value = valueSerializer._impl.decode(stream, keepUnrecognizedFields);
    return wrap(value);
  }
}

class _EnumRemovedNumber<T> extends _EnumFieldOrRemovedNumber<T> {
  @override
  final int number;

  _EnumRemovedNumber(this.number);
}

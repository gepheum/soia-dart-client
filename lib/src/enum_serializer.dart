part of "../soia_client.dart";

/// Enum serializer implementation
class EnumSerializer<T> extends ReflectiveEnumDescriptor<T>
    implements _SerializerImpl<T> {
  final _RecordId _recordId;
  final _EnumUnknownField<T> _unknown;

  EnumSerializer._(String recordId, this._unknown)
      : _recordId = _RecordId.parse(recordId);

  /// Creates an enum serializer
  static EnumSerializer<T> create<T, Unknown extends T>(
    String recordId,
    Unknown unknownInstance,
    T Function(UnrecognizedEnum<T>) wrapUnrecognized,
    UnrecognizedEnum<T>? Function(Unknown) getUnrecognized,
  ) {
    return EnumSerializer._(
      recordId,
      _EnumUnknownField<T>(
        unknownInstance.runtimeType,
        unknownInstance,
        wrapUnrecognized,
        (T e) => e is Unknown ? getUnrecognized(e) : null,
      ),
    );
  }

  @override
  String get name => _recordId.name;

  @override
  String get qualifiedName => _recordId.qualifiedName;

  @override
  String get modulePath => _recordId.modulePath;

  void addConstantField(int number, String name, T instance) {
    _checkNotFinalized();
    _addFieldImpl(
        _EnumConstantField<T>(number, name, instance.runtimeType, instance));
  }

  void addValueField<Instance extends T, V>(
    int number,
    String name,
    Type instanceType,
    Serializer<V> valueSerializer,
    Instance Function(V) wrap,
    V Function(Instance) getValue,
  ) {
    _checkNotFinalized();
    _addFieldImpl(_ValueField<T, V>(
      number,
      name,
      instanceType,
      valueSerializer,
      (V value) => wrap(value) as T,
      (T instance) => getValue(instance as Instance),
    ));
  }

  void addRemovedNumber(int number) {
    _checkNotFinalized();
    _mutableRemovedNumbers.add(number);
    _numberToField[number] = _EnumRemovedNumber<T>(number);
  }

  void finalizeEnum() {
    _checkNotFinalized();
    _addFieldImpl(_unknown);
    _finalized = true;
  }

  void _checkNotFinalized() {
    if (_finalized) {
      throw StateError('Enum is already finalized');
    }
  }

  void _addFieldImpl(_EnumField<T> field) {
    _mutableFields.add(field);
    _numberToField[field.number] = field;
    _nameToField[field.name] = field;
    _instanceTypeToField[field.instanceType] = field;
  }

  final List<_EnumField<T>> _mutableFields = [];
  final Set<int> _mutableRemovedNumbers = <int>{};
  final Map<int, _EnumFieldOrRemovedNumber<T>> _numberToField = {};
  final Map<String, _EnumField<T>> _nameToField = {};
  final Map<Type, _EnumField<T>> _instanceTypeToField = {};
  bool _finalized = false;

  @override
  bool isDefault(T value) => identical(value, _unknown.constant);

  @override
  dynamic toJson(T input, bool readableFlavor) {
    final field = _instanceTypeToField[input.runtimeType]!;
    return field.toJson(input, readableFlavor);
  }

  @override
  T fromJson(dynamic json, bool keepUnrecognizedFields) {
    if (json is int || (json is String && int.tryParse(json) != null)) {
      final number = json is int ? json : int.parse(json);
      final field = _numberToField[number];
      switch (field.runtimeType) {
        case _EnumUnknownField:
          return _unknown.constant;
        case _EnumConstantField:
          return (field as _EnumConstantField<T>).constant;
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
      if (field is _EnumConstantField<T>) {
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
        if (field is _ValueField<T, dynamic>) {
          final second = json[1];
          return field.wrapFromJson(second, keepUnrecognizedFields);
        } else if (field is _EnumRemovedNumber<T>) {
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
        if (field is _ValueField<T, dynamic>) {
          return field.wrapFromJson(value, keepUnrecognizedFields);
        }
      }
    }
    return _unknown.constant;
  }

  @override
  void encode(T input, Uint8Buffer buffer) {
    final field = _instanceTypeToField[input.runtimeType]!;
    field.encode(input, buffer);
  }

  @override
  T decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = _BinaryReader(buffer);
    final wire = reader.readByte();
    late T result;

    if (wire < 242) {
      // A number: rewind and decode
      final numberReader = _BinaryReader(buffer);
      final number = numberReader.decodeNumber().toInt();
      final field = _numberToField[number];

      if (field is _EnumConstantField<T>) {
        result = field.constant;
      } else if (field is _EnumRemovedNumber<T> ||
          field is _EnumUnknownField<T>) {
        result = _unknown.constant;
      } else if (field is _ValueField<T, dynamic>) {
        throw ArgumentError('${number} refers to a value field');
      } else {
        if (keepUnrecognizedFields) {
          final bytes = buffer.sublist(0, numberReader.position);
          result =
              _unknown.wrapUnrecognized(UnrecognizedEnum._fromBytes(bytes));
        } else {
          result = _unknown.constant;
        }
      }
    } else {
      final number = wire == 248 ? reader.decodeNumber().toInt() : wire - 250;
      final field = _numberToField[number];

      if (field is _ValueField<T, dynamic>) {
        result =
            field.wrapDecoded(reader.remainingBytes, keepUnrecognizedFields);
      } else if (field is _EnumRemovedNumber<T>) {
        result = _unknown.constant;
      } else {
        if (keepUnrecognizedFields) {
          final bytes = buffer;
          result =
              _unknown.wrapUnrecognized(UnrecognizedEnum._fromBytes(bytes));
        } else {
          result = _unknown.constant;
        }
      }
    }

    return result;
  }

  @override
  void appendString(T input, StringBuffer out, String eolIndent) {
    final field = _instanceTypeToField[input.runtimeType]!;
    field.appendString(input, out, eolIndent);
  }

  @override
  Iterable<ReflectiveEnumField<T>> get fields =>
      _mutableFields.map((f) => f.asField).toList(growable: false);

  @override
  UnmodifiableSetView<int> get removedNumbers =>
      UnmodifiableSetView(_mutableRemovedNumbers);

  @override
  ReflectiveEnumField<T>? getFieldByName(String name) =>
      _nameToField[name]?.asField;

  @override
  ReflectiveEnumField<T>? getFieldByNumber(int number) {
    final field = _numberToField[number];
    return switch (field) {
      _EnumField<T> f => f.asField,
      _EnumRemovedNumber<T>() => null,
      null => null
    };
  }

  @override
  ReflectiveEnumField<T> getField(T e) {
    final field = _instanceTypeToField[e.runtimeType]!;
    return field.asField;
  }

  _EnumField<T> getFieldByInstance(T e) => _instanceTypeToField[e.runtimeType]!;

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
        .where((field) => field is! _EnumUnknownField<T>)
        .map((field) {
          if (field is _EnumConstantField<T>) {
            return {
              'name': field.name,
              'number': field.number,
            };
          } else if (field is _ValueField<T, dynamic>) {
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
        .whereType<_ValueField<T, dynamic>>()
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

  T wrapDecoded(Uint8List buffer, bool keepUnrecognizedFields) {
    final value = valueSerializer._impl.decode(buffer, keepUnrecognizedFields);
    return wrap(value);
  }
}

class _EnumRemovedNumber<T> extends _EnumFieldOrRemovedNumber<T> {
  @override
  final int number;

  _EnumRemovedNumber(this.number);
}

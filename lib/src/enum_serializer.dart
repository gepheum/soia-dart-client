part of "../soia.dart";

/// Specialization of a [Serializer] for generated enum types.
class EnumSerializer<Enum> extends Serializer<Enum> {
  EnumSerializer._(_EnumSerializerImpl<Enum> impl) : super._(impl);

  @override
  ReflectiveEnumDescriptor<Enum> get typeDescriptor =>
      super._impl as _EnumSerializerImpl<Enum>;
}

class internal__EnumSerializerBuilder<Enum> {
  final _EnumSerializerImpl<Enum> _impl;
  final EnumSerializer<Enum> serializer;
  bool _initialized = false;

  internal__EnumSerializerBuilder._(this._impl, this.serializer);

  static internal__EnumSerializerBuilder<Enum>
      create<Enum, Unknown extends Enum>({
    required String recordId,
    required Unknown unknownInstance,
    required Enum enumInstance, // For type inference, not used at runtime
    required int Function(Enum) getOrdinal,
    required Enum Function(internal__UnrecognizedEnum) wrapUnrecognized,
    required internal__UnrecognizedEnum? Function(Unknown) getUnrecognized,
  }) {
    final String dartClassName = recordId.replaceAll(".", "_");
    final impl = _EnumSerializerImpl._(
      recordId,
      dartClassName,
      _EnumUnknownField<Enum>(
        unknownInstance,
        wrapUnrecognized,
        (Enum e) => e is Unknown ? getUnrecognized(e) : null,
        "${dartClassName}.unknown",
      ),
      getOrdinal,
    );
    return internal__EnumSerializerBuilder<Enum>._(
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

  void addConstantField(
      int number, String name, String dartName, Enum instance) {
    _impl.addConstantField(number, name, dartName, instance);
  }

  void addValueField<Wrapper extends Enum, Value>(
    int number,
    String name,
    String dartName,
    Serializer<Value> valueSerializer,
    Wrapper Function(Value) wrap,
    Value Function(Wrapper) getValue, {
    required int ordinal,
  }) {
    _impl.addValueField<Wrapper, Value>(
      number,
      name,
      dartName,
      valueSerializer,
      wrap,
      getValue,
      ordinal: ordinal,
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
class _EnumSerializerImpl<E> extends ReflectiveEnumDescriptor<E>
    implements _SerializerImpl<E> {
  final _RecordId recordId;
  final String dartClassName;
  final _EnumUnknownField<E> unknown;
  final int Function(E) getOrdinal;

  _EnumSerializerImpl._(
    String recordId,
    this.dartClassName,
    this.unknown,
    this.getOrdinal,
  ) : recordId = _RecordId.parse(recordId);

  @override
  String get name => recordId.name;

  @override
  String get qualifiedName => recordId.qualifiedName;

  @override
  String get modulePath => recordId.modulePath;

  void addConstantField(int number, String name, String dartName, E instance) {
    checkNotFinalized();
    final ordinal = getOrdinal(instance);
    final asString = '${dartClassName}.${dartName}';
    addFieldImpl(
      ordinal: ordinal,
      field: _EnumConstantField<E>(number, name, instance, asString),
    );
  }

  void addValueField<W extends E, V>(
    int number,
    String name,
    String dartName,
    Serializer<V> valueSerializer,
    W Function(V) wrap,
    V Function(W) getValue, {
    required int ordinal,
  }) {
    checkNotFinalized();
    final wrapFunctionName = '${dartClassName}.${dartName}';
    addFieldImpl(
        ordinal: ordinal,
        field: _ValueField<E, W, V>(
          number,
          name,
          valueSerializer,
          wrap,
          getValue,
          wrapFunctionName,
        ));
  }

  void addRemovedNumber(int number) {
    checkNotFinalized();
    mutableRemovedNumbers.add(number);
    numberToField[number] = _EnumRemovedNumber<E>(number);
  }

  void finalize() {
    checkNotFinalized();
    addFieldImpl(ordinal: 0, field: unknown);
    // Create fieldArray from ordinalToField
    for (int ordinal = 0;; ++ordinal) {
      final field = ordinalToField[ordinal];
      if (field != null) {
        fieldArray.add(field);
      } else {
        break;
      }
    }
    finalized = true;
  }

  void checkNotFinalized() {
    if (finalized) {
      throw StateError('Enum is already finalized');
    }
  }

  void addFieldImpl({required int ordinal, required _EnumField<E> field}) {
    mutableFields.add(field);
    numberToField[field.number] = field;
    ordinalToField[ordinal] = field;
    nameToField[field.name] = field;
  }

  final List<_EnumField<E>> mutableFields = [];
  final Set<int> mutableRemovedNumbers = <int>{};
  final Map<int, _EnumFieldOrRemovedNumber<E>> numberToField = {};
  final Map<int, _EnumField<E>> ordinalToField = {};
  final Map<String, _EnumField<E>> nameToField = {};
  // The index is the ordinal
  var fieldArray = <_EnumField<E>?>[];
  bool finalized = false;

  @override
  bool isDefault(E value) => identical(value, unknown.constant);

  @override
  dynamic toJson(E input, bool readableFlavor) {
    final field = fieldArray[getOrdinal(input)]!;
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
      if (field is _EnumConstantField<E>) {
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
        if (field is _ValueField<E, dynamic, dynamic>) {
          final second = json[1];
          return field.wrapFromJson(second, keepUnrecognizedFields);
        } else if (field is _EnumRemovedNumber<E>) {
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
        if (field is _ValueField<E, dynamic, dynamic>) {
          return field.wrapFromJson(value, keepUnrecognizedFields);
        }
      }
    }
    return unknown.constant;
  }

  @override
  void encode(E input, Uint8Buffer buffer) {
    final field = fieldArray[getOrdinal(input)]!;
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

      if (field is _ValueField<E, dynamic, dynamic>) {
        result = field.wrapDecoded(stream, keepUnrecognizedFields);
      } else if (field is _EnumRemovedNumber<E>) {
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
    final field = fieldArray[getOrdinal(input)]!;
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
      _EnumField<E> f => f.asField,
      _EnumRemovedNumber<E>() => null,
      null => null
    };
  }

  @override
  ReflectiveEnumField<E> getField(E e) {
    final field = fieldArray[getOrdinal(e)]!;
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
          if (field is _EnumConstantField<E>) {
            return {
              'name': field.name,
              'number': field.number,
            };
          } else if (field is _ValueField<E, dynamic, dynamic>) {
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
sealed class _EnumFieldOrRemovedNumber<E> {
  int get number;
}

sealed class _EnumField<E> extends _EnumFieldOrRemovedNumber<E>
    implements Field {
  @override
  final String name;

  _EnumField(this.name);

  ReflectiveEnumField<E> get asField;

  dynamic toJson(E input, bool readableFlavor);
  void encode(E input, Uint8Buffer buffer);
  void appendString(E input, StringBuffer out, String eolIndent);
}

class _EnumUnknownField<E> extends _EnumField<E>
    implements ReflectiveEnumConstantField<E> {
  @override
  final E constant;
  final E Function(internal__UnrecognizedEnum) wrapUnrecognized;
  final internal__UnrecognizedEnum? Function(E) getUnrecognized;
  final String asString;

  _EnumUnknownField(
    this.constant,
    this.wrapUnrecognized,
    this.getUnrecognized,
    this.asString,
  ) : super('?');

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
    out.write(asString);
  }
}

class _EnumConstantField<E> extends _EnumField<E>
    implements ReflectiveEnumConstantField<E> {
  @override
  final int number;
  @override
  final E constant;
  final String asString;

  _EnumConstantField(this.number, String name, this.constant, this.asString)
      : super(name);

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
    out.write(asString);
  }
}

// E: enum type
// W: wrapped enum type (for value fields)
// V: value type
class _ValueField<E, W extends E, V> extends _EnumField<E>
    implements ReflectiveEnumValueField<E, V> {
  @override
  final int number;
  final Serializer<V> valueSerializer;
  final W Function(V) wrapFn;
  final V Function(W) getValue;
  final String wrapFunctionName;

  _ValueField(
    this.number,
    String name,
    this.valueSerializer,
    this.wrapFn,
    this.getValue,
    this.wrapFunctionName,
  ) : super(name);

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
    out.write("${wrapFunctionName}($newEolIndent");
    final value = getValue(input as W);
    valueSerializer._impl.appendString(value, out, newEolIndent);
    out.write("$eolIndent)");
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

class _EnumRemovedNumber<E> extends _EnumFieldOrRemovedNumber<E> {
  @override
  final int number;

  _EnumRemovedNumber(this.number);
}

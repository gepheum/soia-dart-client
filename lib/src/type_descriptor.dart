part of "../soia.dart";

/// 🪞 Base interface for all type descriptors
abstract class _TypeDescriptorBase {
  Map<String, dynamic> get asJson;

  String get asJsonCode;
}

/// 🪞 Describes a Soia type.
///
/// Type descriptors provide metadata about Soia types, enabling schema
/// introspection. They don't let you inspect, modify or create Soia values at
/// runtime; for this, you have to use [ReflectiveTypeDescriptor].
sealed class TypeDescriptor implements _TypeDescriptorBase {
  /// Returns the JSON representation of this type descriptor.
  Map<String, dynamic> get asJson => _typeDescriptorAsJsonImpl(this);

  /// Returns the stringified JSON representation of this type descriptor.
  String get asJsonCode => _typeDescriptorAsJsonCodeImpl(this);

  /// Parses a type descriptor from its JSON representation, as returned by
  /// [asJson].
  static TypeDescriptor parseFromJson(dynamic json) {
    return _parseTypeDescriptor(json);
  }

  /// Parses a type descriptor from its JSON string representation, as returned
  /// by [asJsonCode].
  static TypeDescriptor parseFromJsonCode(String jsonCode) {
    final json = jsonDecode(jsonCode);
    return _parseTypeDescriptor(json);
  }
}

/// 🪞 Base class for reflective type descriptors that provide runtime type
/// information.
///
/// Reflective type descriptors offer enhanced introspection capabilities
/// compared to their non-reflective counterparts, enabling runtime manipulation
/// and analysis of Soia values.
sealed class ReflectiveTypeDescriptor<T> implements _TypeDescriptorBase {
  /// Returns a non-reflective type descriptor equivalent to this reflective
  /// descriptor.
  TypeDescriptor get notReflective => _notReflectiveImpl(this);

  /// Returns the JSON representation of this type descriptor.
  Map<String, dynamic> get asJson => notReflective.asJson;

  /// Returns the stringified JSON representation of this type descriptor.
  String get asJsonCode => notReflective.asJsonCode;

  T get defaultValue;

  /// Accepts a [visitor] to perform operations based on the specific Soia type:
  /// struct, enum, primitive, array, optional.
  ///
  /// See a complete example at
  /// https://github.com/gepheum/soia-dart-example/blob/main/lib/all_strings_to_upper_case.dart
  void accept(ReflectiveTypeVisitor<T> visitor) {
    _acceptImpl(this, visitor);
  }
}

/// 🪞 Enumeration of all primitive types supported by Soia.
enum PrimitiveType {
  bool,
  int32,
  int64,
  uint64,
  float32,
  float64,
  timestamp,
  string,
  bytes,
}

/// 🪞 Describes a primitive Soia type.
sealed class PrimitiveDescriptor<T> extends TypeDescriptor
    implements ReflectiveTypeDescriptor<T> {
  /// The specific primitive type being described.
  final PrimitiveType primitiveType;

  PrimitiveDescriptor._(this.primitiveType);

  @override
  PrimitiveDescriptor get notReflective => this;
  void accept(ReflectiveTypeVisitor<T> visitor) {
    _acceptImpl(this, visitor);
  }
}

/// 🪞 Describes the `bool` primitive type.
class BoolDescriptor extends PrimitiveDescriptor<bool> {
  static final instance = BoolDescriptor._();

  bool get defaultValue => false;

  BoolDescriptor._() : super._(PrimitiveType.bool);
}

/// 🪞 Describes the `int32` primitive type.
class Int32Descriptor extends PrimitiveDescriptor<int> {
  static final instance = Int32Descriptor._();

  int get defaultValue => 0;

  Int32Descriptor._() : super._(PrimitiveType.int32);
}

/// 🪞 Describes the `int64` primitive type.
class Int64Descriptor extends PrimitiveDescriptor<int> {
  static final instance = Int64Descriptor._();

  int get defaultValue => 0;

  Int64Descriptor._() : super._(PrimitiveType.int64);
}

/// 🪞 Describes the `uint64` primitive type.
class Uint64Descriptor extends PrimitiveDescriptor<BigInt> {
  static final instance = Uint64Descriptor._();

  BigInt get defaultValue => BigInt.zero;

  Uint64Descriptor._() : super._(PrimitiveType.uint64);
}

/// 🪞 Describes the `float32` primitive type.
class Float32Descriptor extends PrimitiveDescriptor<double> {
  static final instance = Float32Descriptor._();

  double get defaultValue => 0.0;

  Float32Descriptor._() : super._(PrimitiveType.float32);
}

/// 🪞 Describes the `float64` primitive type.
class Float64Descriptor extends PrimitiveDescriptor<double> {
  static final instance = Float64Descriptor._();

  double get defaultValue => 0.0;

  Float64Descriptor._() : super._(PrimitiveType.float64);
}

/// 🪞 Describes the `timestamp` primitive type.
class TimestampDescriptor extends PrimitiveDescriptor<DateTime> {
  static final instance = TimestampDescriptor._();

  DateTime get defaultValue => unixEpoch;

  TimestampDescriptor._() : super._(PrimitiveType.timestamp);
}

/// 🪞 Describes the `string` primitive type.
class StringDescriptor extends PrimitiveDescriptor<String> {
  static final instance = StringDescriptor._();

  String get defaultValue => '';

  StringDescriptor._() : super._(PrimitiveType.string);
}

/// 🪞 Describes the `bytes` primitive type.
class BytesDescriptor extends PrimitiveDescriptor<ByteString> {
  static final instance = BytesDescriptor._();

  ByteString get defaultValue => ByteString.empty;

  BytesDescriptor._() : super._(PrimitiveType.bytes);
}

abstract class _OptionalDescriptorBase<OtherType extends _TypeDescriptorBase>
    implements _TypeDescriptorBase {
  OtherType get otherType;
}

/// 🪞 Describes an optional type that can hold either a value of the wrapped
/// type or null.
class OptionalDescriptor extends TypeDescriptor
    implements _OptionalDescriptorBase<TypeDescriptor> {
  @override
  final TypeDescriptor otherType;

  OptionalDescriptor(this.otherType);
}

/// 🪞 Describes an optional type that can hold either a value of the wrapped
/// type or null.
abstract class ReflectiveOptionalDescriptor<NotNull>
    extends ReflectiveTypeDescriptor<NotNull?>
    implements _OptionalDescriptorBase<ReflectiveTypeDescriptor<NotNull>> {
  @override
  ReflectiveTypeDescriptor<NotNull> get otherType;

  /// Transforms the wrapped value if present, preserving null values.
  NotNull? map(NotNull? input, ReflectiveTransformer transformer) {
    if (input == null) {
      return null;
    } else {
      return transformer.transform<NotNull>(input, otherType);
    }
  }

  ReflectiveOptionalDescriptor._();
}

abstract class _ArrayDescriptorBase<ItemType extends _TypeDescriptorBase>
    implements _TypeDescriptorBase {
  /// Describes the type of the array items.
  ItemType get itemType;

  /// Optional key chain for keyed lists that support fast lookup by key.
  String? get keyExtractor;
}

/// 🪞 Describes an array type.
class ArrayDescriptor extends TypeDescriptor
    implements _ArrayDescriptorBase<TypeDescriptor> {
  /// Describes the type of the array elements.
  @override
  final TypeDescriptor itemType;

  /// Optional key chain specified in the `.soia` file after the pipe character.
  @override
  final String? keyExtractor;

  ArrayDescriptor(this.itemType, this.keyExtractor);
}

/// 🪞 Describes an array type.
abstract class ReflectiveArrayDescriptor<E, Collection extends Iterable<E>>
    extends ReflectiveTypeDescriptor<Collection>
    implements _ArrayDescriptorBase<ReflectiveTypeDescriptor<E>> {
  ReflectiveTypeDescriptor<E> get itemType;

  String? get keyExtractor;

  Collection toCollection(Iterable<E> iterable);

  /// Transforms each element in the collection using [transformer].
  ///  Returns a new collection of the same type containing the transformed
  /// elements.
  Collection map(Collection collection, ReflectiveTransformer transformer) {
    final newCollection =
        collection.map((e) => transformer.transform(e, itemType));
    // Try to preserve object identity if no elements changed
    final allIdentical = () {
      final oldIterator = collection.iterator;
      final newIterator = newCollection.iterator;
      while (oldIterator.moveNext() && newIterator.moveNext()) {
        if (!identical(oldIterator.current, newIterator.current)) {
          return false;
        }
      }
      return true;
    }();
    return allIdentical ? collection : toCollection(newCollection);
  }

  ReflectiveArrayDescriptor._();
}

/// 🪞 Describes a field in a struct or an enum.
abstract class Field {
  /// Field name as specified in the `.soia` file, for example 'user_id' or
  /// 'MONDAY'.
  String get name;

  /// Unique field number used for serialization.
  int get number;

  Field._();
}

abstract class _RecordDescriptorBase<F extends Field>
    implements _TypeDescriptorBase {
  /// Name of the struct as specified in the `.soia` file.
  String get name;

  /// A string containing all the names in the hierarchic sequence above and
  /// including the struct. For example: "Foo.Bar" if "Bar" is nested within a
  /// type called "Foo", or simply "Bar" if "Bar" is defined at the top-level of
  /// the module.
  String get qualifiedName;

  /// Path to the module where the struct is defined, relative to the root of the
  /// project.
  String get modulePath;

  /// The field numbers marked as removed.
  UnmodifiableSetView<int> get removedNumbers;

  /// List of all fields in this record.
  Iterable<F> get fields;

  /// Looks up a field by name.
  F? getFieldByName(String name);

  /// Looks up a field by number.
  F? getFieldByNumber(int number);
}

String _getRecordId<F extends Field>(_RecordDescriptorBase<F> record) {
  return '${record.modulePath}:${record.qualifiedName}';
}

/// 🪞 Describes a record type (struct or enum).
sealed class RecordDescriptor<F extends Field> extends TypeDescriptor
    implements _RecordDescriptorBase<F> {
  Map<String, F>? _nameToField;
  Map<int, F>? _numberToField;

  @override
  F? getFieldByName(String name) {
    _nameToField ??= {for (var f in fields) f.name: f};
    return _nameToField![name];
  }

  @override
  F? getFieldByNumber(int number) {
    _numberToField ??= {for (var f in fields) f.number: f};
    return _numberToField![number];
  }
}

/// 🪞 Describes a Soia record: struct or enum.
sealed class ReflectiveRecordDescriptor<T, F extends Field>
    extends ReflectiveTypeDescriptor<T> implements _RecordDescriptorBase<F> {}

abstract class _StructFieldBase<T extends _TypeDescriptorBase>
    implements Field {
  /// Describes the field type.
  T get type;
}

/// 🪞 Describes a field in a struct.
class StructField implements _StructFieldBase<TypeDescriptor> {
  /// The field name.
  @override
  final String name;

  /// The field number.
  @override
  final int number;

  /// The type descriptor for this field's value type.
  @override
  final TypeDescriptor type;

  StructField(this.name, this.number, this.type);
}

/// 🪞 Describes a field in a struct.
abstract class ReflectiveStructField<Frozen, Mutable, Value>
    implements _StructFieldBase<ReflectiveTypeDescriptor<Value>> {
  /// Extracts the value of the field from the given struct.
  Value get(Frozen struct);

  /// Assigns the given value to the field of the given struct.
  void set(Mutable struct, Value value);

  /// Copies this field's value from [source] to [target].
  /// If a [transformer] is provided, it is applied to the value before setting
  /// it.
  void copy(
    Frozen source,
    Mutable target, {
    ReflectiveTransformer transformer = ReflectiveTransformer.identity,
  }) {
    set(
        target,
        transformer.transform(
          get(source),
          type,
        ));
  }

  ReflectiveStructField._();
}

/// 🪞 Describes a Soia struct.
class StructDescriptor extends RecordDescriptor<StructField> {
  final _RecordId _recordId;

  @override
  final UnmodifiableSetView<int> removedNumbers;

  Iterable<StructField> _fields;

  @override
  Iterable<StructField> get fields => _fields;

  StructDescriptor._(
    this._recordId,
    this.removedNumbers,
    this._fields,
  );

  @override
  String get name => _recordId.name;

  @override
  String get qualifiedName => _recordId.qualifiedName;

  @override
  String get modulePath => _recordId.modulePath;
}

/// 🪞 Describes a Soia struct.
abstract class ReflectiveStructDescriptor<Frozen, Mutable>
    extends ReflectiveRecordDescriptor<Frozen,
        ReflectiveStructField<Frozen, Mutable, dynamic>> {
  /// Returns a new instance of the generated mutable class for a struct.
  /// Performs a shallow copy of `initializer` if `initializer` is specified.
  Mutable newMutable([Frozen? initializer]);

  /// Converts a mutable struct instance to its frozen (immutable) form.
  Frozen toFrozen(Mutable mutable);

  /// Applies [transformer] to each field value in [struct]. Returns a frozen
  /// struct containing the transformed field values.
  Frozen mapFields(Frozen struct, ReflectiveTransformer transformer) {
    final mutable = newMutable();
    for (final field in fields) {
      field.copy(struct, mutable, transformer: transformer);
    }
    final newStruct = toFrozen(mutable);
    final allIdentical = fields.every((field) {
      final oldValue = field.get(struct);
      final newValue = field.get(newStruct);
      return identical(oldValue, newValue);
    });
    return allIdentical ? struct : newStruct;
  }

  ReflectiveStructDescriptor._();
}

/// 🪞 Describes a field in an enum.
sealed class EnumField implements Field {}

/// 🪞 Describes a field in an enum.
sealed class ReflectiveEnumField<E> implements Field {}

/// 🪞 Describes an enum constant field.
class EnumConstantField implements EnumField {
  /// The field name.
  @override
  final String name;

  /// The field number.
  @override
  final int number;

  EnumConstantField(this.name, this.number);
}

/// 🪞 Describes an enum constant field.
abstract class ReflectiveEnumConstantField<E>
    implements ReflectiveEnumField<E> {
  /// The constant value represented by this field.
  E get constant;

  ReflectiveEnumConstantField._();
}

abstract class _EnumWrapperFieldBase<T extends _TypeDescriptorBase>
    implements Field {
  /// The type of the value associated with this enum field.
  T get type;
}

/// 🪞 Describes an enum wrapper field.
class EnumWrapperField
    implements EnumField, _EnumWrapperFieldBase<TypeDescriptor> {
  /// The field name.
  @override
  final String name;

  /// The field number.
  @override
  final int number;

  /// The type descriptor for the associated value type.
  @override
  final TypeDescriptor type;

  EnumWrapperField(this.name, this.number, this.type);
}

/// 🪞 Describes an enum wrapper field.
abstract class ReflectiveEnumWrapperField<E, Value>
    implements
        ReflectiveEnumField<E>,
        _EnumWrapperFieldBase<ReflectiveTypeDescriptor<Value>> {
  /// Returns whether the variant of the given enum instance matches this field.
  bool test(E e);

  /// Extracts the value held by the given enum instance assuming its variant
  /// matches this field. Throws an exception if `test(e)` is false.
  Value get(E e);

  /// Returns a new enum instance holding the given value.
  E wrap(Value value);

  /// Applies [transformer] to the wrapped value and returns a new enum instance
  /// wrapping around it. Throws an exception if `test(e)` is false.
  E mapValue(E e, ReflectiveTransformer transformer);

  ReflectiveEnumWrapperField._();
}

abstract class _EnumDescriptorBase<F extends Field>
    implements _RecordDescriptorBase<F> {}

/// 🪞 Describes a Soia enum.
class EnumDescriptor extends RecordDescriptor<EnumField>
    implements _EnumDescriptorBase<EnumField> {
  final _RecordId _recordId;

  @override
  final UnmodifiableSetView<int> removedNumbers;

  Iterable<EnumField> _fields;

  @override
  Iterable<EnumField> get fields => _fields;

  EnumDescriptor._(
    this._recordId,
    this.removedNumbers,
    this._fields,
  );

  @override
  String get name => _recordId.name;

  @override
  String get qualifiedName => _recordId.qualifiedName;

  @override
  String get modulePath => _recordId.modulePath;
}

/// 🪞 Describes a Soia enum.
abstract class ReflectiveEnumDescriptor<E>
    extends ReflectiveRecordDescriptor<E, ReflectiveEnumField<E>> {
  /// Looks up the field corresponding to the given instance of Enum.
  ReflectiveEnumField<E> getField(E e);

  /// If [e] holds a value (wrapper variant), extracts the value, transforms it
  /// and returns a new enum instance wrapping around it.
  /// Otherwise, returns [e] unchanged.
  E mapValue(E e, ReflectiveTransformer transformer) {
    final field = getField(e);
    if (field is ReflectiveEnumWrapperField<E, dynamic>) {
      return field.mapValue(e, transformer);
    } else {
      return e;
    }
  }

  ReflectiveEnumDescriptor._();
}

/// 🪞 Converts a reflective type descriptor to a non-reflective one.
TypeDescriptor _notReflectiveImpl(
  ReflectiveTypeDescriptor reflective, [
  Map<ReflectiveTypeDescriptor, TypeDescriptor>? inProgress,
]) {
  inProgress ??= {};
  {
    final inProgressResult = inProgress[reflective];
    if (inProgressResult != null) {
      return inProgressResult;
    }
  }
  return switch (reflective) {
    PrimitiveDescriptor() => reflective,
    ReflectiveOptionalDescriptor() => OptionalDescriptor(
        _notReflectiveImpl(reflective.otherType, inProgress),
      ),
    ReflectiveArrayDescriptor() => ArrayDescriptor(
        _notReflectiveImpl(reflective.itemType, inProgress),
        reflective.keyExtractor,
      ),
    ReflectiveStructDescriptor() => () {
        final result = StructDescriptor._(
          _RecordId.parse(_getRecordId(reflective)),
          reflective.removedNumbers,
          [],
        );
        inProgress![reflective] = result;
        result._fields = reflective.fields.map((f) {
          return StructField(
            f.name,
            f.number,
            _notReflectiveImpl(f.type, inProgress),
          );
        }).toList();
        return result;
      }(),
    ReflectiveEnumDescriptor() => () {
        final result = EnumDescriptor._(
          _RecordId.parse(_getRecordId(reflective)),
          reflective.removedNumbers,
          [],
        );
        inProgress![reflective] = result;
        result._fields = reflective.fields.map((f) {
          if (f is ReflectiveEnumWrapperField) {
            return EnumWrapperField(
              f.name,
              f.number,
              _notReflectiveImpl(f.type, inProgress),
            );
          } else {
            return EnumConstantField(f.name, f.number);
          }
        }).toList();
        return result;
      }(),
  };
}

/// 🪞 Converts this type descriptor to its JSON representation.
Map<String, dynamic> _typeDescriptorAsJsonImpl(TypeDescriptor descriptor) {
  final recordIdToDefinition = <String, Map<String, dynamic>>{};
  _addRecordDefinitions(descriptor, recordIdToDefinition);
  return {
    'type': _getTypeSignature(descriptor),
    'records': recordIdToDefinition.values.toList(),
  };
}

/// 🪞 Converts this type descriptor to its stringified JSON representation.
String _typeDescriptorAsJsonCodeImpl(TypeDescriptor descriptor) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(_typeDescriptorAsJsonImpl(descriptor));
}

Map<String, dynamic> _getTypeSignature(TypeDescriptor typeDescriptor) {
  return switch (typeDescriptor) {
    PrimitiveDescriptor(:final primitiveType) => {
        'kind': 'primitive',
        'value': _primitiveTypeToString(primitiveType),
      },
    OptionalDescriptor(:final otherType) => {
        'kind': 'optional',
        'value': _getTypeSignature(otherType),
      },
    ArrayDescriptor(:final itemType, keyExtractor: final keyExtractor) => () {
        final value = <String, dynamic>{
          'item': _getTypeSignature(itemType),
        };
        if ((keyExtractor ?? "").isNotEmpty) {
          value['key_extractor'] = keyExtractor;
        }
        return {
          'kind': 'array',
          'value': value,
        };
      }(), // The `()` immediately calls the anonymous function
    RecordDescriptor(:final modulePath, :final qualifiedName) => {
        'kind': 'record',
        'value': '$modulePath:$qualifiedName',
      },
  };
}

String _primitiveTypeToString(PrimitiveType type) {
  switch (type) {
    case PrimitiveType.bool:
      return 'bool';
    case PrimitiveType.int32:
      return 'int32';
    case PrimitiveType.int64:
      return 'int64';
    case PrimitiveType.uint64:
      return 'uint64';
    case PrimitiveType.float32:
      return 'float32';
    case PrimitiveType.float64:
      return 'float64';
    case PrimitiveType.timestamp:
      return 'timestamp';
    case PrimitiveType.string:
      return 'string';
    case PrimitiveType.bytes:
      return 'bytes';
  }
}

void _addRecordDefinitions(
  TypeDescriptor typeDescriptor,
  Map<String, Map<String, dynamic>> recordIdToDefinition,
) {
  if (typeDescriptor is PrimitiveDescriptor) {
    // No definitions to add
  } else if (typeDescriptor is OptionalDescriptor) {
    _addRecordDefinitions(typeDescriptor.otherType, recordIdToDefinition);
  } else if (typeDescriptor is ArrayDescriptor) {
    _addRecordDefinitions(typeDescriptor.itemType, recordIdToDefinition);
  } else if (typeDescriptor is StructDescriptor) {
    final recordId = _getRecordId(typeDescriptor);
    if (recordIdToDefinition.containsKey(recordId)) {
      return;
    }

    final recordDefinition = {
      'kind': 'struct',
      'id': recordId,
      'fields': typeDescriptor.fields.map((f) {
        return {
          'name': f.name,
          'number': f.number,
          'type': _getTypeSignature(f.type),
        };
      }).toList(),
    };
    if (typeDescriptor.removedNumbers.isNotEmpty) {
      final removedNumbers = typeDescriptor.removedNumbers.toList();
      removedNumbers.sort();
      recordDefinition['removed_numbers'] = removedNumbers;
    }
    recordIdToDefinition[recordId] = recordDefinition;

    for (final field in typeDescriptor.fields) {
      _addRecordDefinitions(field.type, recordIdToDefinition);
    }
  } else if (typeDescriptor is EnumDescriptor) {
    final recordId = _getRecordId(typeDescriptor);
    if (recordIdToDefinition.containsKey(recordId)) {
      return;
    }

    final recordDefinition = {
      'kind': 'enum',
      'id': recordId,
      'fields': typeDescriptor.fields.map((f) {
        if (f is EnumWrapperField) {
          return {
            'name': f.name,
            'number': f.number,
            'type': _getTypeSignature(f.type),
          };
        } else if (f is EnumConstantField) {
          return {
            'name': f.name,
            'number': f.number,
          };
        }
        throw ArgumentError('Unknown enum field type: $f');
      }).toList(),
    };
    if (typeDescriptor.removedNumbers.isNotEmpty) {
      final removedNumbers = typeDescriptor.removedNumbers.toList();
      removedNumbers.sort();
      recordDefinition['removed_numbers'] = removedNumbers;
    }
    recordIdToDefinition[recordId] = recordDefinition;

    for (final field in typeDescriptor.fields) {
      if (field is EnumWrapperField) {
        _addRecordDefinitions(field.type, recordIdToDefinition);
      }
    }
  }
}

part of "../soia.dart";

/// Base interface for all type descriptors
abstract class _TypeDescriptorBase {
  Map<String, dynamic> get asJson;

  String get asJsonCode;
}

/// Describes a Soia type.
///
/// Type descriptors provide metadata about Soia types, enabling schema
/// introspection. They don't let you to inspect, modify or create soia values
/// at runtime; for this, you have to use [ReflectiveTypeDescriptor].
sealed class TypeDescriptor implements _TypeDescriptorBase {
  /// Converts this type descriptor to its JSON representation.
  Map<String, dynamic> get asJson => _typeDescriptorAsJsonImpl(this);

  /// Converts this type descriptor to a JSON string representation.
  String get asJsonCode => _typeDescriptorAsJsonCodeImpl(this);

  /// Parses a type descriptor from its JSON representation.
  ///
  /// [json] The JSON object containing the type descriptor data
  /// Returns the parsed TypeDescriptor instance
  static TypeDescriptor parseFromJson(dynamic json) {
    return _parseTypeDescriptor(json);
  }

  /// Parses a type descriptor from its JSON string representation.
  ///
  /// [jsonCode] The JSON string containing the type descriptor data
  /// Returns the parsed TypeDescriptor instance
  static TypeDescriptor parseFromJsonCode(String jsonCode) {
    final json = jsonDecode(jsonCode);
    return _parseTypeDescriptor(json);
  }
}

/// Base class for reflective type descriptors that provide runtime type
/// information.
///
/// Reflective type descriptors offer enhanced introspection capabilities
/// compared to their non-reflective counterparts, enabling runtime manipulation
/// and analysis of soia values.
sealed class ReflectiveTypeDescriptor implements _TypeDescriptorBase {
  /// Converts this type descriptor to a non-reflective version.
  ///
  /// Non-reflective descriptors contain the same type information but without
  /// runtime reflection capabilities.
  TypeDescriptor get notReflective => _notReflectiveImpl(this);

  /// Converts this type descriptor to its JSON representation.
  Map<String, dynamic> get asJson => notReflective.asJson;

  /// Converts this type descriptor to a JSON string representation.
  String get asJsonCode => notReflective.asJsonCode;
}

/// Enumeration of all primitive types supported by Soia.
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

/// Describes a primitive type such as integers, strings, booleans, etc.
class PrimitiveDescriptor extends TypeDescriptor
    implements ReflectiveTypeDescriptor {
  /// The specific primitive type being described.
  final PrimitiveType primitiveType;

  PrimitiveDescriptor(this.primitiveType);

  @override
  PrimitiveDescriptor get notReflective => this;
}

abstract class _OptionalDescriptorBase<OtherType extends _TypeDescriptorBase>
    implements _TypeDescriptorBase {
  OtherType get otherType;
}

/// Describes an optional type that can hold either a value of the wrapped type
/// or null.
class OptionalDescriptor extends TypeDescriptor
    implements _OptionalDescriptorBase<TypeDescriptor> {
  @override
  final TypeDescriptor otherType;

  OptionalDescriptor(this.otherType);
}

/// Describes an optional type that can hold either a value of the wrapped type
/// or null.
class ReflectiveOptionalDescriptor extends ReflectiveTypeDescriptor
    implements _OptionalDescriptorBase<ReflectiveTypeDescriptor> {
  @override
  final ReflectiveTypeDescriptor otherType;

  ReflectiveOptionalDescriptor(this.otherType);
}

abstract class _ListDescriptorBase<ItemType extends _TypeDescriptorBase>
    implements _TypeDescriptorBase {
  /// Describes the type of the array items.
  ItemType get itemType;

  /// Optional key chain for keyed lists that support fast lookup by key.
  String? get keyChain;
}

/// Describes a list type containing elements of a specific type.
///
/// Lists represent ordered collections of elements, all of the same type.
/// They can optionally support keyed access for efficient lookup operations.
class ListDescriptor extends TypeDescriptor
    implements _ListDescriptorBase<TypeDescriptor> {
  /// Describes the type of the list elements.
  @override
  final TypeDescriptor itemType;

  /// Optional key chain specified in the `.soia` file after the pipe character.
  @override
  final String? keyChain;

  ListDescriptor(this.itemType, this.keyChain);
}

class ReflectiveListDescriptor extends ReflectiveTypeDescriptor
    implements _ListDescriptorBase<ReflectiveTypeDescriptor> {
  @override
  final ReflectiveTypeDescriptor itemType;

  @override
  final String? keyChain;

  ReflectiveListDescriptor(this.itemType, this.keyChain);
}

/// Base interface for fields in structs and enums.
///
/// Fields represent individual data elements within structured types,
/// each identified by a name and unique number for serialization purposes.
abstract class Field {
  /// Field name as specified in the `.soia` file, e.g. "user_id".
  String get name;

  /// Unique field number used for serialization.
  int get number;
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

/// Describes a record type (struct or enum).
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

sealed class ReflectiveRecordDescriptor<F extends Field>
    extends ReflectiveTypeDescriptor implements _RecordDescriptorBase<F> {}

abstract class _StructFieldBase<T extends _TypeDescriptorBase>
    implements Field {
  /// Describes the field type.
  T get type;
}

/// Represents a field within a struct type.
///
/// Struct fields define the structure and types of data that can be stored
/// in struct instances, providing the metadata needed for serialization.
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

abstract class ReflectiveStructField<Frozen, Mutable, Value>
    implements _StructFieldBase<ReflectiveTypeDescriptor> {
  /// Extracts the value of the field from the given struct.
  Value get(Frozen struct);

  /// Assigns the given value to the field of the given struct.
  void set(Mutable struct, Value value);
}

/// Describes a Soia struct type with its fields and structure.
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

abstract class ReflectiveStructDescriptor<Frozen, Mutable>
    extends ReflectiveRecordDescriptor<
        ReflectiveStructField<Frozen, Mutable, dynamic>> {
  /// Returns a new instance of the generated mutable class for a struct.
  /// Performs a shallow copy of `initializer` if `initializer` is specified.
  Mutable newMutable([Frozen? initializer]);

  /// Converts a mutable struct instance to its frozen (immutable) form.
  Frozen toFrozen(Mutable mutable);
}

sealed class EnumField implements Field {}

sealed class ReflectiveEnumField<E> implements Field {}

/// Describes an enum constant field: a field that represents a simple named
/// value.
///
/// Constant fields represent enum variants that carry no additional data,
/// similar to traditional enum constants in most programming languages.
class EnumConstantField implements EnumField {
  /// The field name.
  @override
  final String name;

  /// The field number.
  @override
  final int number;

  EnumConstantField(this.name, this.number);
}

abstract class ReflectiveEnumConstantField<E>
    implements ReflectiveEnumField<E> {
  /// The constant value represented by this field.
  E get constant;
}

abstract class _EnumValueFieldBase<T extends _TypeDescriptorBase>
    implements Field {
  /// The type of the value associated with this enum field.
  T get type;
}

/// Describes an enum value field: a field that can hold additional data.
///
/// Value fields represent enum variants that carry associated data of a
/// specific type
class EnumValueField implements EnumField, _EnumValueFieldBase<TypeDescriptor> {
  /// The field name.
  @override
  final String name;

  /// The field number.
  @override
  final int number;

  /// The type descriptor for the associated value type.
  @override
  final TypeDescriptor type;

  EnumValueField(this.name, this.number, this.type);
}

/// Reflective interface for enum value fields.
abstract class ReflectiveEnumValueField<E, Value>
    implements
        ReflectiveEnumField<E>,
        _EnumValueFieldBase<ReflectiveTypeDescriptor> {
  /// Returns whether the given enum instance if it matches this enum field.
  bool test(E e);

  /// Extracts the value held by the given enum instance assuming it matches this
  /// enum field. The behavior is undefined if `test(e)` is false.
  Value get(E e);

  /// Returns a new enum instance matching this enum field and holding the given
  /// value.
  E wrap(Value value);
}

abstract class _EnumDescriptorBase<F extends Field>
    implements _RecordDescriptorBase<F> {}

/// Describes a Soia enum type with its possible values and associated data.
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

/// Reflective interface for enum descriptors.
abstract class ReflectiveEnumDescriptor<E>
    extends ReflectiveRecordDescriptor<ReflectiveEnumField<E>> {
  /// Looks up the field corresponding to the given instance of Enum.
  ReflectiveEnumField<E> getField(E e);
}

/// Converts a reflective type descriptor to a non-reflective one.
TypeDescriptor _notReflectiveImpl(ReflectiveTypeDescriptor reflective) {
  return switch (reflective) {
    PrimitiveDescriptor() => reflective,
    ReflectiveOptionalDescriptor() =>
      OptionalDescriptor(_notReflectiveImpl(reflective.otherType)),
    ReflectiveListDescriptor() => ListDescriptor(
        _notReflectiveImpl(reflective.itemType),
        reflective.keyChain,
      ),
    ReflectiveStructDescriptor() => StructDescriptor._(
        _RecordId.parse(_getRecordId(reflective)),
        reflective.removedNumbers,
        reflective.fields.map((f) {
          return StructField(
            f.name,
            f.number,
            _notReflectiveImpl(f.type),
          );
        }),
      ),
    ReflectiveEnumDescriptor() => EnumDescriptor._(
        _RecordId.parse(_getRecordId(reflective)),
        reflective.removedNumbers,
        reflective.fields.map((f) {
          if (f is ReflectiveEnumValueField) {
            return EnumValueField(
              f.name,
              f.number,
              _notReflectiveImpl(f.type),
            );
          } else {
            return EnumConstantField(f.name, f.number);
          }
        }),
      ),
  };
}

/// Converts this type descriptor to its JSON representation.
Map<String, dynamic> _typeDescriptorAsJsonImpl(TypeDescriptor descriptor) {
  final recordIdToDefinition = <String, Map<String, dynamic>>{};
  _addRecordDefinitions(descriptor, recordIdToDefinition);
  return recordIdToDefinition.isNotEmpty
      ? {
          'type': _getTypeSignature(descriptor),
          'records': recordIdToDefinition.values.toList(),
        }
      : {
          'type': _getTypeSignature(descriptor),
        };
}

/// Converts this type descriptor to a JSON string representation.
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
    ListDescriptor(:final itemType, :final keyChain) => () {
        final value = <String, dynamic>{
          'item': _getTypeSignature(itemType),
        };
        if (keyChain != null) {
          value['key_chain'] = keyChain;
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
  _TypeDescriptorBase typeDescriptor,
  Map<String, Map<String, dynamic>> recordIdToDefinition,
) {
  if (typeDescriptor is PrimitiveDescriptor) {
    // No definitions to add
  } else if (typeDescriptor is OptionalDescriptor) {
    _addRecordDefinitions(typeDescriptor.otherType, recordIdToDefinition);
  } else if (typeDescriptor is ListDescriptor) {
    _addRecordDefinitions(typeDescriptor.itemType, recordIdToDefinition);
  } else if (typeDescriptor is StructDescriptor) {
    final recordId = _getRecordId(typeDescriptor);
    final fields = typeDescriptor.fields.map((f) {
      return {
        'name': f.name,
        'number': f.number,
        'type': _getTypeSignature(f.type),
      };
    }).toList();

    recordIdToDefinition[recordId] = {
      'kind': 'struct',
      'id': recordId,
      'fields': fields,
      'removed_fields': typeDescriptor.removedNumbers.toList(),
    };

    for (final field in typeDescriptor.fields) {
      _addRecordDefinitions(field.type, recordIdToDefinition);
    }
  } else if (typeDescriptor is EnumDescriptor) {
    final recordId = _getRecordId(typeDescriptor);
    final fields = typeDescriptor.fields.map((f) {
      if (f is EnumValueField) {
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
    }).toList();

    recordIdToDefinition[recordId] = {
      'kind': 'enum',
      'id': recordId,
      'fields': fields,
      'removed_fields': typeDescriptor.removedNumbers.toList(),
    };

    for (final field in typeDescriptor.fields) {
      if (field is EnumValueField) {
        _addRecordDefinitions(field.type, recordIdToDefinition);
      }
    }
  }
}

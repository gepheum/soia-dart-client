part of "../soia.dart";

class StructSerializerBuilder<Frozen, Mutable> {
  final _StructSerializerImpl<Frozen, Mutable> _impl;

  StructSerializerBuilder({
    required String recordId,
    required Frozen defaultInstance,
    required Mutable Function(Frozen?) newMutableFn,
    required Frozen Function(Mutable) toFrozenFn,
    required UnrecognizedFields<Frozen>? Function(Frozen) getUnrecognizedFields,
    required void Function(Mutable, UnrecognizedFields<Frozen>)
        setUnrecognizedFields,
  }) : _impl = _StructSerializerImpl(
          recordId: recordId,
          defaultInstance: defaultInstance,
          newMutableFn: newMutableFn,
          toFrozenFn: toFrozenFn,
          getUnrecognizedFields: getUnrecognizedFields,
          setUnrecognizedFields: setUnrecognizedFields,
        );

  Serializer<Frozen> get serializer => Serializer._(_impl);

  void addField<Value>(
    String name,
    String kotlinName,
    int number,
    Serializer<Value> serializer,
    Value Function(Frozen) getter,
    void Function(Mutable, Value) setter,
  ) {
    _impl.addField(name, kotlinName, number, serializer, getter, setter);
  }

  void addRemovedNumber(int number) {
    _impl.addRemovedNumber(number);
  }

  void finalize() {
    _impl.finalize();
  }
}

/// Implementation of struct field
class _StructFieldImpl<Frozen, Mutable, Value>
    implements ReflectiveStructField<Frozen, Mutable, Value> {
  @override
  final String name;
  final String kotlinName;
  @override
  final int number;
  final Serializer<Value> serializer;
  final Value Function(Frozen) getter;
  final void Function(Mutable, Value) setter;

  _StructFieldImpl({
    required this.name,
    required this.kotlinName,
    required this.number,
    required this.serializer,
    required this.getter,
    required this.setter,
  });

  bool valueIsDefault(Frozen input) {
    return serializer._impl.isDefault(getter(input));
  }

  dynamic valueToJson(Frozen input, bool readableFlavor) {
    return serializer.toJson(getter(input), readableFlavor: readableFlavor);
  }

  void valueFromJson(
      Mutable mutable, dynamic json, bool keepUnrecognizedFields) {
    final value = serializer.fromJson(json,
        keepUnrecognizedFields: keepUnrecognizedFields);
    setter(mutable, value);
  }

  void encodeValue(Frozen input, Uint8Buffer buffer) {
    serializer._impl.encode(getter(input), buffer);
  }

  void decodeValue(
      Mutable mutable, _ByteStream stream, bool keepUnrecognizedFields) {
    final value = serializer._impl.decode(stream, keepUnrecognizedFields);
    setter(mutable, value);
  }

  void appendString(Frozen input, StringBuffer out, String eolIndent) {
    serializer._impl.appendString(getter(input), out, eolIndent);
  }

  @override
  ReflectiveTypeDescriptor get type => serializer._impl.typeDescriptor;

  @override
  void set(Mutable struct, Value value) => setter(struct, value);

  @override
  Value get(Frozen struct) => getter(struct);
}

/// Struct serializer implementation
class _StructSerializerImpl<Frozen, Mutable>
    extends ReflectiveStructDescriptor<Frozen, Mutable>
    implements _SerializerImpl<Frozen> {
  final _RecordId _recordId;
  final Frozen defaultInstance;
  final Mutable Function(Frozen?) newMutableFn;
  final Frozen Function(Mutable) toFrozenFn;
  final UnrecognizedFields<Frozen>? Function(Frozen) getUnrecognizedFields;
  final void Function(Mutable, UnrecognizedFields<Frozen>)
      setUnrecognizedFields;

  final List<_StructFieldImpl<Frozen, Mutable, dynamic>> _mutableFields = [];
  final Set<int> _mutableRemovedNumbers = <int>{};
  final Map<String, _StructFieldImpl<Frozen, Mutable, dynamic>> _nameToField =
      {};
  List<_StructFieldImpl<Frozen, Mutable, dynamic>?> _slotToField = [];
  List<dynamic> _zeros = [];
  int _recognizedSlotCount = 0;
  int _maxRemovedNumber = -1;
  bool _finalized = false;

  _StructSerializerImpl({
    required String recordId,
    required this.defaultInstance,
    required this.newMutableFn,
    required this.toFrozenFn,
    required this.getUnrecognizedFields,
    required this.setUnrecognizedFields,
  }) : _recordId = _RecordId.parse(recordId);

  @override
  String get name => _recordId.name;

  @override
  String get qualifiedName => _recordId.qualifiedName;

  @override
  String get modulePath => _recordId.modulePath;

  void addField<Value>(
    String name,
    String kotlinName,
    int number,
    Serializer<Value> serializer,
    Value Function(Frozen) getter,
    void Function(Mutable, Value) setter,
  ) {
    _checkNotFinalized();
    final field = _StructFieldImpl<Frozen, Mutable, Value>(
      name: name,
      kotlinName: kotlinName,
      number: number,
      serializer: serializer,
      getter: getter,
      setter: setter,
    );
    _mutableFields.add(field);
    _nameToField[field.name] = field;
  }

  void addRemovedNumber(int number) {
    _checkNotFinalized();
    _mutableRemovedNumbers.add(number);
    _maxRemovedNumber = _maxRemovedNumber > number ? _maxRemovedNumber : number;
  }

  void finalize() {
    _checkNotFinalized();
    _finalized = true;
    _mutableFields.sort((a, b) => a.number.compareTo(b.number));
    final numSlots =
        _mutableFields.isNotEmpty ? _mutableFields.last.number + 1 : 0;
    _slotToField = List.filled(numSlots, null);
    for (final field in _mutableFields) {
      _slotToField[field.number] = field;
    }
    _zeros = List.filled(numSlots, 0);
    _recognizedSlotCount =
        (numSlots - 1 > _maxRemovedNumber ? numSlots - 1 : _maxRemovedNumber) +
            1;
  }

  void _checkNotFinalized() {
    if (_finalized) {
      throw StateError('Struct is already finalized');
    }
  }

  @override
  bool isDefault(Frozen value) {
    if (identical(value, defaultInstance)) {
      return true;
    } else {
      return _mutableFields.every((field) => field.valueIsDefault(value)) &&
          getUnrecognizedFields(value) == null;
    }
  }

  @override
  dynamic toJson(Frozen input, bool readableFlavor) {
    if (readableFlavor) {
      return identical(input, defaultInstance)
          ? <String, dynamic>{}
          : _toReadableJson(input);
    } else {
      return identical(input, defaultInstance)
          ? <dynamic>[]
          : _toDenseJson(input);
    }
  }

  List<dynamic> _toDenseJson(Frozen input) {
    final unrecognizedFields = getUnrecognizedFields(input);
    if (unrecognizedFields?._jsonElements != null) {
      // Some unrecognized fields
      final elements = List<dynamic>.from(_zeros)
        ..addAll(unrecognizedFields!._jsonElements!);
      for (final field in _mutableFields) {
        elements[field.number] = field.valueToJson(input, false);
      }
      return elements;
    } else {
      // No unrecognized fields
      final slotCount = _getSlotCount(input);
      final elements = List<dynamic>.filled(slotCount, 0);
      for (int i = 0; i < slotCount; i++) {
        final field = _slotToField[i];
        elements[i] = field?.valueToJson(input, false) ?? 0;
      }
      return elements;
    }
  }

  Map<String, dynamic> _toReadableJson(Frozen input) {
    final nameToElement = <String, dynamic>{};
    for (final field in _mutableFields) {
      if (field.valueIsDefault(input)) {
        continue;
      }
      nameToElement[field.name] = field.valueToJson(input, true);
    }
    return nameToElement;
  }

  @override
  Frozen fromJson(dynamic json, bool keepUnrecognizedFields) {
    if (json is int && json == 0) {
      return defaultInstance;
    } else if (json is List) {
      return _fromDenseJson(json, keepUnrecognizedFields);
    } else if (json is Map<String, dynamic>) {
      return _fromReadableJson(json);
    } else {
      throw ArgumentError('Expected: array or object');
    }
  }

  Frozen _fromDenseJson(List<dynamic> jsonArray, bool keepUnrecognizedFields) {
    final mutable = newMutableFn(null);
    final int numSlotsToFill;
    if (jsonArray.length > _recognizedSlotCount) {
      // We have some unrecognized fields
      if (keepUnrecognizedFields) {
        final unrecognizedFields = UnrecognizedFields<Frozen>._fromJson(
          jsonArray.length,
          jsonArray
              .sublist(_recognizedSlotCount)
              .map((e) => _copyJson(e))
              .toList(),
        );
        setUnrecognizedFields(mutable, unrecognizedFields);
      }
      numSlotsToFill = _recognizedSlotCount;
    } else {
      numSlotsToFill = jsonArray.length;
    }
    for (final field in _mutableFields) {
      if (field.number >= numSlotsToFill) {
        break;
      }
      field.valueFromJson(
          mutable, jsonArray[field.number], keepUnrecognizedFields);
    }
    return toFrozenFn(mutable);
  }

  Frozen _fromReadableJson(Map<String, dynamic> jsonObject) {
    final mutable = newMutableFn(null);
    for (final entry in jsonObject.entries) {
      _nameToField[entry.key]?.valueFromJson(mutable, entry.value, false);
    }
    return toFrozenFn(mutable);
  }

  @override
  void encode(Frozen input, Uint8Buffer buffer) {
    // Total number of slots to write. Includes removed and unrecognized fields.
    final int totalSlotCount;
    final int recognizedSlotCount;
    final Uint8List? unrecognizedBytes;
    final unrecognizedFields = getUnrecognizedFields(input);
    if (unrecognizedFields?._bytes != null) {
      totalSlotCount = unrecognizedFields!._totalSlotCount;
      recognizedSlotCount = _recognizedSlotCount;
      unrecognizedBytes = unrecognizedFields._bytes;
    } else {
      // No unrecognized fields
      totalSlotCount = _getSlotCount(input);
      recognizedSlotCount = totalSlotCount;
      unrecognizedBytes = null;
    }

    if (totalSlotCount <= 3) {
      buffer.add(246 + totalSlotCount);
    } else {
      buffer.add(250);
      _BinaryWriter.encodeLengthPrefix(totalSlotCount, buffer);
    }
    for (int i = 0; i < recognizedSlotCount; i++) {
      final field = _slotToField[i];
      if (field != null) {
        field.encodeValue(input, buffer);
      } else {
        // Append '0' if the field was removed
        buffer.add(0);
      }
    }
    if (unrecognizedBytes != null) {
      // Copy the unrecognized fields
      buffer.addAll(unrecognizedBytes);
    }
  }

  @override
  Frozen decode(_ByteStream stream, bool keepUnrecognizedFields) {
    final wire = stream.readByte();
    if (wire == 0 || wire == 246) {
      return defaultInstance;
    }
    final mutable = newMutableFn(null);
    final encodedSlotCount =
        wire == 250 ? stream.decodeNumber().toInt() : wire - 246;

    // Do not read more slots than the number of recognized slots
    for (int i = 0; i < encodedSlotCount && i < _recognizedSlotCount; i++) {
      final field = _slotToField[i];
      if (field != null) {
        field.decodeValue(mutable, stream, keepUnrecognizedFields);
      } else {
        // The field was removed
        _decodeUnused(stream);
      }
    }
    if (encodedSlotCount > _recognizedSlotCount) {
      // We have some unrecognized fields
      if (keepUnrecognizedFields) {
        final unrecognizedBuffer = Uint8Buffer();
        for (int i = _recognizedSlotCount; i < encodedSlotCount; i++) {
          _decodeUnused(stream);
          // In a real implementation, we'd capture the bytes
        }
        final unrecognizedFields = UnrecognizedFields<Frozen>._fromBytes(
          encodedSlotCount,
          unrecognizedBuffer.buffer.asUint8List(),
        );
        setUnrecognizedFields(mutable, unrecognizedFields);
      } else {
        for (int i = _recognizedSlotCount; i < encodedSlotCount; i++) {
          _decodeUnused(stream);
        }
      }
    }
    return toFrozenFn(mutable);
  }

  void _decodeUnused(_ByteStream stream) {
    // Decode and discard a value
    stream.decodeNumber();
  }

  @override
  void appendString(Frozen input, StringBuffer out, String eolIndent) {
    final defaultFieldNumbers = <int>{};
    for (final field in _mutableFields) {
      if (field.valueIsDefault(input)) {
        defaultFieldNumbers.add(field.number);
      }
    }
    final className = defaultInstance.runtimeType.toString();
    out.write(className);
    if (defaultFieldNumbers.isNotEmpty) {
      out.write('.partial');
    }
    out.write('(');
    final newEolIndent = eolIndent + _indentUnit;
    for (final field in _mutableFields) {
      if (defaultFieldNumbers.contains(field.number)) {
        continue;
      }
      out.write(newEolIndent);
      out.write(field.kotlinName);
      out.write(' = ');
      field.appendString(input, out, newEolIndent);
      out.write(',');
    }
    if (defaultFieldNumbers.length < _mutableFields.length) {
      out.write(eolIndent);
    }
    out.write(')');
  }

  /// Returns the length of the JSON array for the given input.
  /// Assumes that `input` does not contain unrecognized fields.
  int _getSlotCount(Frozen input) {
    for (int i = _mutableFields.length - 1; i >= 0; i--) {
      final field = _mutableFields[i];
      if (!field.valueIsDefault(input)) {
        return field.number + 1;
      }
    }
    return 0;
  }

  dynamic _copyJson(dynamic input) {
    if (input is List) {
      return input.map((e) => _copyJson(e)).toList();
    } else if (input is Map) {
      return input.map((k, v) => MapEntry(k, _copyJson(v)));
    } else {
      return input;
    }
  }

  // Reflection methods
  @override
  Iterable<_StructFieldImpl<Frozen, Mutable, dynamic>> get fields =>
      List.unmodifiable(_mutableFields);

  @override
  UnmodifiableSetView<int> get removedNumbers =>
      UnmodifiableSetView(_mutableRemovedNumbers);

  @override
  _StructFieldImpl<Frozen, Mutable, dynamic>? getFieldByName(String name) {
    return _nameToField[name];
  }

  @override
  _StructFieldImpl<Frozen, Mutable, dynamic>? getFieldByNumber(int number) {
    return number < _slotToField.length ? _slotToField[number] : null;
  }

  @override
  Mutable newMutable([Frozen? initializer]) => newMutableFn(initializer);

  @override
  Frozen toFrozen(Mutable mutable) => toFrozenFn(mutable);

  @override
  ReflectiveTypeDescriptor get typeDescriptor => this;

  @override
  dynamic get typeSignature => {
        'kind': 'struct',
        'value': _recordId.toString(),
      };

  @override
  void addRecordDefinitionsTo(Map<String, dynamic> out) {
    out[_recordId.toString()] = {
      'kind': 'struct',
      'fields': fieldDefinitions(),
    };
    for (final dep in dependencies()) {
      dep.addRecordDefinitionsTo(out);
    }
  }

  List<Map<String, dynamic>> fieldDefinitions() {
    return _mutableFields
        .map((field) => {
              'name': field.name,
              'type': field.serializer._impl.typeSignature,
              'number': field.number,
            })
        .toList();
  }

  List<_SerializerImpl<dynamic>> dependencies() {
    return _mutableFields.map((field) => field.serializer._impl).toList();
  }
}

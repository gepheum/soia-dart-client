part of "../soia_client.dart";

/// Implementation of struct field
class _StructFieldImpl<T, M, V> implements ReflectiveStructField<T, M, V> {
  @override
  final String name;
  final String kotlinName;
  @override
  final int number;
  final Serializer<V> serializer;
  final V Function(T) getter;
  final void Function(M, V) setter;

  _StructFieldImpl({
    required this.name,
    required this.kotlinName,
    required this.number,
    required this.serializer,
    required this.getter,
    required this.setter,
  });

  bool valueIsDefault(T input) {
    return serializer._impl.isDefault(getter(input));
  }

  dynamic valueToJson(T input, bool readableFlavor) {
    return serializer.toJson(getter(input), readableFlavor: readableFlavor);
  }

  void valueFromJson(M mutable, dynamic json, bool keepUnrecognizedFields) {
    final value = serializer.fromJson(json,
        keepUnrecognizedFields: keepUnrecognizedFields);
    setter(mutable, value);
  }

  void encodeValue(T input, Uint8Buffer buffer) {
    serializer._impl.encode(getter(input), buffer);
  }

  void decodeValue(M mutable, Uint8List buffer, bool keepUnrecognizedFields) {
    final value = serializer._impl.decode(buffer, keepUnrecognizedFields);
    setter(mutable, value);
  }

  void appendString(T input, StringBuffer out, String eolIndent) {
    serializer._impl.appendString(getter(input), out, eolIndent);
  }

  @override
  ReflectiveTypeDescriptor get type => serializer._impl.typeDescriptor;

  @override
  void set(M struct, V value) => setter(struct, value);

  @override
  V get(T struct) => getter(struct);
}

/// Struct serializer implementation
class StructSerializer<T, M> extends ReflectiveStructDescriptor<T, M>
    implements _SerializerImpl<T> {
  final _RecordId _recordId;
  final T defaultInstance;
  final M Function(T?) newMutableFn;
  final T Function(M) toFrozenFn;
  final UnrecognizedFields<T>? Function(T) getUnrecognizedFields;
  final void Function(M, UnrecognizedFields<T>) setUnrecognizedFields;

  final List<_StructFieldImpl<T, M, dynamic>> _mutableFields = [];
  final Set<int> _mutableRemovedNumbers = <int>{};
  final Map<String, _StructFieldImpl<T, M, dynamic>> _nameToField = {};
  List<_StructFieldImpl<T, M, dynamic>?> _slotToField = [];
  List<dynamic> _zeros = [];
  int _recognizedSlotCount = 0;
  int _maxRemovedNumber = -1;
  bool _finalized = false;

  StructSerializer({
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

  void addField<V>(
    String name,
    String kotlinName,
    int number,
    Serializer<V> serializer,
    V Function(T) getter,
    void Function(M, V) setter,
  ) {
    _checkNotFinalized();
    final field = _StructFieldImpl<T, M, V>(
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

  void finalizeStruct() {
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
  bool isDefault(T value) {
    if (identical(value, defaultInstance)) {
      return true;
    } else {
      return _mutableFields.every((field) => field.valueIsDefault(value)) &&
          getUnrecognizedFields(value) == null;
    }
  }

  @override
  dynamic toJson(T input, bool readableFlavor) {
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

  List<dynamic> _toDenseJson(T input) {
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

  Map<String, dynamic> _toReadableJson(T input) {
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
  T fromJson(dynamic json, bool keepUnrecognizedFields) {
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

  T _fromDenseJson(List<dynamic> jsonArray, bool keepUnrecognizedFields) {
    final mutable = newMutableFn(null);
    final int numSlotsToFill;
    if (jsonArray.length > _recognizedSlotCount) {
      // We have some unrecognized fields
      if (keepUnrecognizedFields) {
        final unrecognizedFields = UnrecognizedFields<T>._fromJson(
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

  T _fromReadableJson(Map<String, dynamic> jsonObject) {
    final mutable = newMutableFn(null);
    for (final entry in jsonObject.entries) {
      _nameToField[entry.key]?.valueFromJson(mutable, entry.value, false);
    }
    return toFrozenFn(mutable);
  }

  @override
  void encode(T input, Uint8Buffer buffer) {
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
  T decode(Uint8List buffer, bool keepUnrecognizedFields) {
    final reader = _BinaryReader(buffer);
    final wire = reader.readByte();
    if (wire == 0 || wire == 246) {
      return defaultInstance;
    }
    final mutable = newMutableFn(null);
    final encodedSlotCount =
        wire == 250 ? reader.decodeNumber().toInt() : wire - 246;

    // Do not read more slots than the number of recognized slots
    for (int i = 0; i < encodedSlotCount && i < _recognizedSlotCount; i++) {
      final field = _slotToField[i];
      if (field != null) {
        field.decodeValue(
            mutable, reader.remainingBytes, keepUnrecognizedFields);
      } else {
        // The field was removed
        _decodeUnused(reader);
      }
    }
    if (encodedSlotCount > _recognizedSlotCount) {
      // We have some unrecognized fields
      if (keepUnrecognizedFields) {
        final unrecognizedBuffer = Uint8Buffer();
        for (int i = _recognizedSlotCount; i < encodedSlotCount; i++) {
          _decodeUnused(reader);
          // In a real implementation, we'd capture the bytes
        }
        final unrecognizedFields = UnrecognizedFields<T>._fromBytes(
          encodedSlotCount,
          unrecognizedBuffer.buffer.asUint8List(),
        );
        setUnrecognizedFields(mutable, unrecognizedFields);
      } else {
        for (int i = _recognizedSlotCount; i < encodedSlotCount; i++) {
          _decodeUnused(reader);
        }
      }
    }
    return toFrozenFn(mutable);
  }

  void _decodeUnused(_BinaryReader reader) {
    // Decode and discard a value
    reader.decodeNumber();
  }

  @override
  void appendString(T input, StringBuffer out, String eolIndent) {
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
  int _getSlotCount(T input) {
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
  Iterable<_StructFieldImpl<T, M, dynamic>> get fields =>
      List.unmodifiable(_mutableFields);

  @override
  UnmodifiableSetView<int> get removedNumbers =>
      UnmodifiableSetView(_mutableRemovedNumbers);

  @override
  _StructFieldImpl<T, M, dynamic>? getFieldByName(String name) {
    return _nameToField[name];
  }

  @override
  _StructFieldImpl<T, M, dynamic>? getFieldByNumber(int number) {
    return number < _slotToField.length ? _slotToField[number] : null;
  }

  @override
  M newMutable([T? initializer]) => newMutableFn(initializer);

  @override
  T toFrozen(M mutable) => toFrozenFn(mutable);

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

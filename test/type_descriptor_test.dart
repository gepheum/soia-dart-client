import 'dart:convert';
import 'package:test/test.dart';
import 'package:soia_client/soia_client.dart';

void main() {
  group('PrimitiveType', () {
    test('enum contains all expected primitive types', () {
      expect(PrimitiveType.values, hasLength(9));
      expect(PrimitiveType.values, contains(PrimitiveType.bool));
      expect(PrimitiveType.values, contains(PrimitiveType.int32));
      expect(PrimitiveType.values, contains(PrimitiveType.int64));
      expect(PrimitiveType.values, contains(PrimitiveType.uint64));
      expect(PrimitiveType.values, contains(PrimitiveType.float32));
      expect(PrimitiveType.values, contains(PrimitiveType.float64));
      expect(PrimitiveType.values, contains(PrimitiveType.timestamp));
      expect(PrimitiveType.values, contains(PrimitiveType.string));
      expect(PrimitiveType.values, contains(PrimitiveType.bytes));
    });
  });

  group('PrimitiveDescriptor', () {
    test('creates descriptor for each primitive type', () {
      for (final primitiveType in PrimitiveType.values) {
        final descriptor = PrimitiveDescriptor(primitiveType);
        expect(descriptor.primitiveType, equals(primitiveType));
      }
    });

    test('notReflective returns the same instance for primitives', () {
      final descriptor = PrimitiveDescriptor(PrimitiveType.bool);
      final notReflective = descriptor.notReflective;

      expect(identical(descriptor, notReflective), isTrue);
    });

    test('asJson works correctly for all primitive types', () {
      final testCases = {
        PrimitiveType.bool: 'bool',
        PrimitiveType.int32: 'int32',
        PrimitiveType.int64: 'int64',
        PrimitiveType.uint64: 'uint64',
        PrimitiveType.float32: 'float32',
        PrimitiveType.float64: 'float64',
        PrimitiveType.timestamp: 'timestamp',
        PrimitiveType.string: 'string',
        PrimitiveType.bytes: 'bytes',
      };

      for (final entry in testCases.entries) {
        final descriptor = PrimitiveDescriptor(entry.key);
        final json = descriptor.asJson;

        expect(json, isA<Map<String, dynamic>>());
        final jsonMap = json as Map<String, dynamic>;
        expect(jsonMap['records'], isEmpty);
        expect(jsonMap['type'], isA<Map<String, dynamic>>());

        final typeMap = jsonMap['type'] as Map<String, dynamic>;
        expect(typeMap['kind'], equals('primitive'));
        expect(typeMap['value'], equals(entry.value));
      }
    });

    test('asJsonCode produces valid JSON string', () {
      final descriptor = PrimitiveDescriptor(PrimitiveType.string);
      final jsonCode = descriptor.asJsonCode;

      expect(jsonCode, isA<String>());
      expect(jsonCode, contains('"kind": "primitive"'));
      expect(jsonCode, contains('"value": "string"'));

      // Should be able to parse back
      expect(() => jsonDecode(jsonCode), returnsNormally);
    });
  });

  group('OptionalDescriptor', () {
    test('wraps another type descriptor', () {
      // Create a simple primitive descriptor for testing
      final innerType = PrimitiveDescriptor(PrimitiveType.string);
      final optional = OptionalDescriptor(innerType);

      expect(optional.otherType, equals(innerType));
    });

    test('can nest optional types', () {
      final innerType = PrimitiveDescriptor(PrimitiveType.float32);
      final optionalInner = OptionalDescriptor(innerType);
      final optionalOuter = OptionalDescriptor(optionalInner);

      expect(optionalOuter.otherType, equals(optionalInner));
      expect((optionalOuter.otherType as OptionalDescriptor).otherType,
          equals(innerType));
    });

    test('asJson works correctly for optional types', () {
      final innerType = PrimitiveDescriptor(PrimitiveType.int32);
      final optional = OptionalDescriptor(innerType);
      final json = optional.asJson;

      expect(json, isA<Map<String, dynamic>>());
      final jsonMap = json as Map<String, dynamic>;
      expect(jsonMap['records'], isEmpty);
      expect(jsonMap['type'], isA<Map<String, dynamic>>());

      final typeMap = jsonMap['type'] as Map<String, dynamic>;
      expect(typeMap['kind'], equals('optional'));
      expect(typeMap['value'], isA<Map<String, dynamic>>());

      final valueMap = typeMap['value'] as Map<String, dynamic>;
      expect(valueMap['kind'], equals('primitive'));
      expect(valueMap['value'], equals('int32'));
    });
  });

  group('ReflectiveOptionalDescriptor', () {
    test('wraps another reflective type descriptor', () {
      final innerType = PrimitiveDescriptor(PrimitiveType.timestamp);
      final optional = ReflectiveOptionalDescriptor(innerType);

      expect(optional.otherType, equals(innerType));
    });

    test('notReflective works', () {
      final innerType = PrimitiveDescriptor(PrimitiveType.bytes);
      final reflectiveOptional = ReflectiveOptionalDescriptor(innerType);
      final notReflective = reflectiveOptional.notReflective;

      // Since primitive notReflective returns itself,
      // the ReflectiveOptionalDescriptor.notReflective should return the primitive directly
      expect(notReflective, isA<OptionalDescriptor>());
      expect(
          (notReflective as OptionalDescriptor).otherType, equals(innerType));
    });

    test('asJson works correctly for reflective optional types', () {
      final innerType = PrimitiveDescriptor(PrimitiveType.bool);
      final reflectiveOptional = ReflectiveOptionalDescriptor(innerType);
      final json = reflectiveOptional.asJson;

      expect(json, isA<Map<String, dynamic>>());
      final jsonMap = json as Map<String, dynamic>;
      expect(jsonMap['records'], isEmpty);
      expect(jsonMap['type'], isA<Map<String, dynamic>>());

      final typeMap = jsonMap['type'] as Map<String, dynamic>;
      expect(typeMap['kind'], equals('optional'));
      expect(typeMap['value'], isA<Map<String, dynamic>>());

      final valueMap = typeMap['value'] as Map<String, dynamic>;
      expect(valueMap['kind'], equals('primitive'));
      expect(valueMap['value'], equals('bool'));
    });
  });

  group('ListDescriptor', () {
    test('describes list with item type', () {
      final itemType = PrimitiveDescriptor(PrimitiveType.string);
      final listDesc = ListDescriptor(itemType, null);

      expect(listDesc.itemType, equals(itemType));
      expect(listDesc.keyChain, isNull);
    });

    test('supports key chain for keyed lists', () {
      final itemType = PrimitiveDescriptor(PrimitiveType.int32);
      const keyChain = 'id';
      final listDesc = ListDescriptor(itemType, keyChain);

      expect(listDesc.itemType, equals(itemType));
      expect(listDesc.keyChain, equals(keyChain));
    });

    test('asJson works correctly for list types', () {
      final itemType = PrimitiveDescriptor(PrimitiveType.float64);
      final listDesc = ListDescriptor(itemType, null);
      final json = listDesc.asJson;

      expect(json, isA<Map<String, dynamic>>());
      final jsonMap = json as Map<String, dynamic>;
      expect(jsonMap['records'], isEmpty);
      expect(jsonMap['type'], isA<Map<String, dynamic>>());

      final typeMap = jsonMap['type'] as Map<String, dynamic>;
      expect(typeMap['kind'], equals('array'));
      expect(typeMap['value'], isA<Map<String, dynamic>>());

      final valueMap = typeMap['value'] as Map<String, dynamic>;
      expect(valueMap['item'], isA<Map<String, dynamic>>());
      expect(valueMap.containsKey('key_chain'), isFalse);

      final itemMap = valueMap['item'] as Map<String, dynamic>;
      expect(itemMap['kind'], equals('primitive'));
      expect(itemMap['value'], equals('float64'));
    });

    test('asJson includes key_chain when present', () {
      final itemType = PrimitiveDescriptor(PrimitiveType.string);
      const keyChain = 'user_id';
      final listDesc = ListDescriptor(itemType, keyChain);
      final json = listDesc.asJson;

      final jsonMap = json as Map<String, dynamic>;
      final typeMap = jsonMap['type'] as Map<String, dynamic>;
      final valueMap = typeMap['value'] as Map<String, dynamic>;

      expect(valueMap['key_chain'], equals(keyChain));
    });
  });

  group('ReflectiveListDescriptor', () {
    test('describes reflective list with item type', () {
      final itemType = PrimitiveDescriptor(PrimitiveType.float64);
      const keyChain = 'index';
      final reflectiveList = ReflectiveListDescriptor(itemType, keyChain);

      expect(reflectiveList.itemType, equals(itemType));
      expect(reflectiveList.keyChain, equals(keyChain));
    });

    test('notReflective converts to non-reflective list', () {
      final itemType = PrimitiveDescriptor(PrimitiveType.string);
      const keyChain = 'name';
      final reflectiveList = ReflectiveListDescriptor(itemType, keyChain);
      final notReflective = reflectiveList.notReflective;

      expect(notReflective, isA<ListDescriptor>());
      final listDesc = notReflective as ListDescriptor;
      expect(listDesc.itemType, equals(itemType));
      expect(listDesc.keyChain, equals(keyChain));
    });

    test('asJson works correctly for reflective list types', () {
      final itemType = PrimitiveDescriptor(PrimitiveType.int64);
      const keyChain = 'id';
      final reflectiveList = ReflectiveListDescriptor(itemType, keyChain);
      final json = reflectiveList.asJson;

      expect(json, isA<Map<String, dynamic>>());
      final jsonMap = json as Map<String, dynamic>;
      expect(jsonMap['records'], isEmpty);
      expect(jsonMap['type'], isA<Map<String, dynamic>>());

      final typeMap = jsonMap['type'] as Map<String, dynamic>;
      expect(typeMap['kind'], equals('array'));
      expect(typeMap['value'], isA<Map<String, dynamic>>());

      final valueMap = typeMap['value'] as Map<String, dynamic>;
      expect(valueMap['item'], isA<Map<String, dynamic>>());
      expect(valueMap['key_chain'], equals(keyChain));

      final itemMap = valueMap['item'] as Map<String, dynamic>;
      expect(itemMap['kind'], equals('primitive'));
      expect(itemMap['value'], equals('int64'));
    });
  });

  group('StructField', () {
    test('creates field with name, number, and type', () {
      const name = 'username';
      const number = 1;
      final type = PrimitiveDescriptor(PrimitiveType.string);
      final field = StructField(name, number, type);

      expect(field.name, equals(name));
      expect(field.number, equals(number));
      expect(field.type, equals(type));
    });
  });

  group('EnumConstantField', () {
    test('creates constant field with name and number', () {
      const name = 'ACTIVE';
      const number = 1;
      final field = EnumConstantField(name, number);

      expect(field.name, equals(name));
      expect(field.number, equals(number));
    });
  });

  group('EnumValueField', () {
    test('creates value field with name, number, and type', () {
      const name = 'custom_value';
      const number = 100;
      final type = PrimitiveDescriptor(PrimitiveType.int32);
      final field = EnumValueField(name, number, type);

      expect(field.name, equals(name));
      expect(field.number, equals(number));
      expect(field.type, equals(type));
    });
  });

  group('TypeDescriptor JSON parsing', () {
    test('parseFromJsonCode creates descriptor from JSON string', () {
      const jsonCode = '''
      {
        "records": [],
        "type": {
          "kind": "primitive",
          "value": "string"
        }
      }
      ''';

      final descriptor = TypeDescriptor.parseFromJsonCode(jsonCode);

      expect(descriptor, isA<PrimitiveDescriptor>());
      final primitiveDesc = descriptor as PrimitiveDescriptor;
      expect(primitiveDesc.primitiveType, equals(PrimitiveType.string));
    });

    test('parseFromJson creates descriptor from JSON object', () {
      final json = {
        'records': <dynamic>[],
        'type': {'kind': 'primitive', 'value': 'int32'}
      };

      final descriptor = TypeDescriptor.parseFromJson(json);

      expect(descriptor, isA<PrimitiveDescriptor>());
      final primitiveDesc = descriptor as PrimitiveDescriptor;
      expect(primitiveDesc.primitiveType, equals(PrimitiveType.int32));
    });

    test('parseFromJson handles optional types', () {
      final json = {
        'records': <dynamic>[],
        'type': {
          'kind': 'optional',
          'value': {'kind': 'primitive', 'value': 'bool'}
        }
      };

      final descriptor = TypeDescriptor.parseFromJson(json);

      expect(descriptor, isA<OptionalDescriptor>());
      final optionalDesc = descriptor as OptionalDescriptor;
      expect(optionalDesc.otherType, isA<PrimitiveDescriptor>());
      final innerDesc = optionalDesc.otherType as PrimitiveDescriptor;
      expect(innerDesc.primitiveType, equals(PrimitiveType.bool));
    });

    test('parseFromJson handles array types', () {
      final json = {
        'records': <dynamic>[],
        'type': {
          'kind': 'array',
          'value': {
            'item': {'kind': 'primitive', 'value': 'float64'}
          }
        }
      };

      final descriptor = TypeDescriptor.parseFromJson(json);

      expect(descriptor, isA<ListDescriptor>());
      final listDesc = descriptor as ListDescriptor;
      expect(listDesc.itemType, isA<PrimitiveDescriptor>());
      expect(listDesc.keyChain, isNull);

      final itemDesc = listDesc.itemType as PrimitiveDescriptor;
      expect(itemDesc.primitiveType, equals(PrimitiveType.float64));
    });

    test('parseFromJson handles array types with key chain', () {
      final json = {
        'records': <dynamic>[],
        'type': {
          'kind': 'array',
          'value': {
            'item': {'kind': 'primitive', 'value': 'string'},
            'key_chain': 'id'
          }
        }
      };

      final descriptor = TypeDescriptor.parseFromJson(json);

      expect(descriptor, isA<ListDescriptor>());
      final listDesc = descriptor as ListDescriptor;
      expect(listDesc.keyChain, equals('id'));
    });

    test('parseFromJson handles all primitive types', () {
      final primitiveTestCases = {
        'bool': PrimitiveType.bool,
        'int32': PrimitiveType.int32,
        'int64': PrimitiveType.int64,
        'uint64': PrimitiveType.uint64,
        'float32': PrimitiveType.float32,
        'float64': PrimitiveType.float64,
        'timestamp': PrimitiveType.timestamp,
        'string': PrimitiveType.string,
        'bytes': PrimitiveType.bytes,
      };

      for (final entry in primitiveTestCases.entries) {
        final json = {
          'records': <dynamic>[],
          'type': {'kind': 'primitive', 'value': entry.key}
        };

        final descriptor = TypeDescriptor.parseFromJson(json);
        expect(descriptor, isA<PrimitiveDescriptor>());

        final primitiveDesc = descriptor as PrimitiveDescriptor;
        expect(primitiveDesc.primitiveType, equals(entry.value),
            reason: 'Failed for primitive type: ${entry.key}');
      }
    });
  });

  group('Error handling', () {
    test('parseFromJson throws on unknown primitive type', () {
      final json = {
        'records': <dynamic>[],
        'type': {'kind': 'primitive', 'value': 'unknown_type'}
      };

      expect(() => TypeDescriptor.parseFromJson(json), throwsArgumentError);
    });

    test('parseFromJson throws on unknown type kind', () {
      final json = {
        'records': <dynamic>[],
        'type': {'kind': 'unknown_kind', 'value': 'something'}
      };

      expect(() => TypeDescriptor.parseFromJson(json), throwsArgumentError);
    });

    test('parseFromJsonCode throws on invalid JSON', () {
      const invalidJson = '{ invalid json }';

      expect(() => TypeDescriptor.parseFromJsonCode(invalidJson),
          throwsA(isA<FormatException>()));
    });
  });

  group('Complex type structures', () {
    test('can create nested complex types', () {
      // Create a complex nested type: List<Optional<String>>
      final stringType = PrimitiveDescriptor(PrimitiveType.string);
      final optionalString = OptionalDescriptor(stringType);
      final listOfOptionalStrings = ListDescriptor(optionalString, 'key');

      expect(listOfOptionalStrings.itemType, equals(optionalString));
      expect(listOfOptionalStrings.keyChain, equals('key'));
      expect(optionalString.otherType, equals(stringType));
    });

    test('field types work correctly', () {
      final stringType = PrimitiveDescriptor(PrimitiveType.string);
      final structField = StructField('name', 1, stringType);
      final enumValueField = EnumValueField('value', 2, stringType);
      final enumConstantField = EnumConstantField('CONSTANT', 3);

      expect(structField.type, equals(stringType));
      expect(enumValueField.type, equals(stringType));
      expect(enumConstantField.name, equals('CONSTANT'));
      expect(enumConstantField.number, equals(3));
    });

    test('asJson works for complex nested types without infinite loops', () {
      // This test specifically verifies that the infinite loop bug has been fixed
      final stringType = PrimitiveDescriptor(PrimitiveType.string);
      final optionalString = OptionalDescriptor(stringType);
      final listOfOptionalStrings = ListDescriptor(optionalString, 'key');

      // These calls should complete without infinite loops
      final json = listOfOptionalStrings.asJson;
      final jsonCode = listOfOptionalStrings.asJsonCode;

      expect(json, isA<Map<String, dynamic>>());
      expect(jsonCode, isA<String>());
      expect(jsonCode, contains('"kind": "array"'));
      expect(jsonCode, contains('"kind": "optional"'));
      expect(jsonCode, contains('"kind": "primitive"'));
      expect(jsonCode, contains('"value": "string"'));
      expect(jsonCode, contains('"key_chain": "key"'));

      // Should be able to parse back to verify valid JSON
      final parsedJson = jsonDecode(jsonCode);
      expect(parsedJson, isA<Map<String, dynamic>>());
    });

    test('asJsonCode produces properly formatted JSON', () {
      final boolType = PrimitiveDescriptor(PrimitiveType.bool);
      final optionalBool = OptionalDescriptor(boolType);

      final jsonCode = optionalBool.asJsonCode;

      // Should be pretty-printed JSON
      expect(jsonCode, contains('\n'));
      expect(jsonCode, contains('  '));

      // Should be parseable
      final parsed = jsonDecode(jsonCode);
      expect(parsed, isA<Map<String, dynamic>>());

      final parsedMap = parsed as Map<String, dynamic>;
      expect(parsedMap['records'], isA<List>());
      expect(parsedMap['type'], isA<Map<String, dynamic>>());
    });
  });

  group('Infinite loop regression tests', () {
    test('primitive asJson does not cause infinite loop', () {
      final descriptor = PrimitiveDescriptor(PrimitiveType.string);

      // This should complete quickly without hanging
      final json = descriptor.asJson;
      final jsonCode = descriptor.asJsonCode;

      expect(json, isNotNull);
      expect(jsonCode, isNotNull);
      expect(jsonCode, contains('"kind": "primitive"'));
      expect(jsonCode, contains('"value": "string"'));
    });

    test('multiple calls to asJson work correctly', () {
      final descriptor = PrimitiveDescriptor(PrimitiveType.int32);

      // Multiple calls should all work without issues
      final json1 = descriptor.asJson;
      final json2 = descriptor.asJson;
      final jsonCode1 = descriptor.asJsonCode;
      final jsonCode2 = descriptor.asJsonCode;

      expect(json1, equals(json2));
      expect(jsonCode1, equals(jsonCode2));
    });

    test('all primitive types work with asJson', () {
      // Test that every primitive type can successfully generate JSON
      for (final primitiveType in PrimitiveType.values) {
        final descriptor = PrimitiveDescriptor(primitiveType);

        // These should all complete without infinite loops
        expect(() => descriptor.asJson, returnsNormally);
        expect(() => descriptor.asJsonCode, returnsNormally);

        final json = descriptor.asJson;
        expect(json, isA<Map<String, dynamic>>());

        final jsonCode = descriptor.asJsonCode;
        expect(jsonCode, isA<String>());
        expect(jsonCode.length, greaterThan(0));
      }
    });
  });
}

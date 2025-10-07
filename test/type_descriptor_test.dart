import 'package:test/test.dart';
import 'package:soia_client/soia_client.dart';

void main() {
  group('PrimitiveType', () {
    test('enum contains all expected primitive types', () {
      expect(PrimitiveType.values, hasLength(9));
      expect(PrimitiveType.values, contains(PrimitiveType.BOOL));
      expect(PrimitiveType.values, contains(PrimitiveType.INT_32));
      expect(PrimitiveType.values, contains(PrimitiveType.INT_64));
      expect(PrimitiveType.values, contains(PrimitiveType.UINT_64));
      expect(PrimitiveType.values, contains(PrimitiveType.FLOAT_32));
      expect(PrimitiveType.values, contains(PrimitiveType.FLOAT_64));
      expect(PrimitiveType.values, contains(PrimitiveType.TIMESTAMP));
      expect(PrimitiveType.values, contains(PrimitiveType.STRING));
      expect(PrimitiveType.values, contains(PrimitiveType.BYTES));
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
      final descriptor = PrimitiveDescriptor(PrimitiveType.BOOL);
      final notReflective = descriptor.notReflective;

      expect(identical(descriptor, notReflective), isTrue);
    });
  });

  group('OptionalDescriptor', () {
    test('wraps another type descriptor', () {
      // Create a simple primitive descriptor for testing
      final innerType = PrimitiveDescriptor(PrimitiveType.STRING);
      final optional = OptionalDescriptor(innerType);

      expect(optional.otherType, equals(innerType));
    });

    test('can nest optional types', () {
      final innerType = PrimitiveDescriptor(PrimitiveType.FLOAT_32);
      final optionalInner = OptionalDescriptor(innerType);
      final optionalOuter = OptionalDescriptor(optionalInner);

      expect(optionalOuter.otherType, equals(optionalInner));
      expect((optionalOuter.otherType as OptionalDescriptor).otherType,
          equals(innerType));
    });
  });

  group('ReflectiveOptionalDescriptor', () {
    test('wraps another reflective type descriptor', () {
      final innerType = PrimitiveDescriptor(PrimitiveType.TIMESTAMP);
      final optional = ReflectiveOptionalDescriptor(innerType);

      expect(optional.otherType, equals(innerType));
    });

    test('notReflective works', () {
      final innerType = PrimitiveDescriptor(PrimitiveType.BYTES);
      final reflectiveOptional = ReflectiveOptionalDescriptor(innerType);
      final notReflective = reflectiveOptional.notReflective;

      // Since primitive notReflective returns itself,
      // the ReflectiveOptionalDescriptor.notReflective should return the primitive directly
      expect(notReflective, isA<OptionalDescriptor>());
      expect(
          (notReflective as OptionalDescriptor).otherType, equals(innerType));
    });
  });

  group('ListDescriptor', () {
    test('describes list with item type', () {
      final itemType = PrimitiveDescriptor(PrimitiveType.STRING);
      final listDesc = ListDescriptor(itemType, null);

      expect(listDesc.itemType, equals(itemType));
      expect(listDesc.keyChain, isNull);
    });

    test('supports key chain for keyed lists', () {
      final itemType = PrimitiveDescriptor(PrimitiveType.INT_32);
      const keyChain = 'id';
      final listDesc = ListDescriptor(itemType, keyChain);

      expect(listDesc.itemType, equals(itemType));
      expect(listDesc.keyChain, equals(keyChain));
    });
  });

  group('ReflectiveListDescriptor', () {
    test('describes reflective list with item type', () {
      final itemType = PrimitiveDescriptor(PrimitiveType.FLOAT_64);
      const keyChain = 'index';
      final reflectiveList = ReflectiveListDescriptor(itemType, keyChain);

      expect(reflectiveList.itemType, equals(itemType));
      expect(reflectiveList.keyChain, equals(keyChain));
    });

    test('notReflective converts to non-reflective list', () {
      final itemType = PrimitiveDescriptor(PrimitiveType.STRING);
      const keyChain = 'name';
      final reflectiveList = ReflectiveListDescriptor(itemType, keyChain);
      final notReflective = reflectiveList.notReflective;

      expect(notReflective, isA<ListDescriptor>());
      final listDesc = notReflective as ListDescriptor;
      expect(listDesc.itemType, equals(itemType));
      expect(listDesc.keyChain, equals(keyChain));
    });
  });

  group('StructField', () {
    test('creates field with name, number, and type', () {
      const name = 'username';
      const number = 1;
      final type = PrimitiveDescriptor(PrimitiveType.STRING);
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
      final type = PrimitiveDescriptor(PrimitiveType.INT_32);
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
      expect(primitiveDesc.primitiveType, equals(PrimitiveType.STRING));
    });

    test('parseFromJson creates descriptor from JSON object', () {
      final json = {
        'records': <dynamic>[],
        'type': {'kind': 'primitive', 'value': 'int32'}
      };

      final descriptor = TypeDescriptor.parseFromJson(json);

      expect(descriptor, isA<PrimitiveDescriptor>());
      final primitiveDesc = descriptor as PrimitiveDescriptor;
      expect(primitiveDesc.primitiveType, equals(PrimitiveType.INT_32));
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
      expect(innerDesc.primitiveType, equals(PrimitiveType.BOOL));
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
      expect(itemDesc.primitiveType, equals(PrimitiveType.FLOAT_64));
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
        'bool': PrimitiveType.BOOL,
        'int32': PrimitiveType.INT_32,
        'int64': PrimitiveType.INT_64,
        'uint64': PrimitiveType.UINT_64,
        'float32': PrimitiveType.FLOAT_32,
        'float64': PrimitiveType.FLOAT_64,
        'timestamp': PrimitiveType.TIMESTAMP,
        'string': PrimitiveType.STRING,
        'bytes': PrimitiveType.BYTES,
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
      final stringType = PrimitiveDescriptor(PrimitiveType.STRING);
      final optionalString = OptionalDescriptor(stringType);
      final listOfOptionalStrings = ListDescriptor(optionalString, 'key');

      expect(listOfOptionalStrings.itemType, equals(optionalString));
      expect(listOfOptionalStrings.keyChain, equals('key'));
      expect(optionalString.otherType, equals(stringType));
    });

    test('field types work correctly', () {
      final stringType = PrimitiveDescriptor(PrimitiveType.STRING);
      final structField = StructField('name', 1, stringType);
      final enumValueField = EnumValueField('value', 2, stringType);
      final enumConstantField = EnumConstantField('CONSTANT', 3);

      expect(structField.type, equals(stringType));
      expect(enumValueField.type, equals(stringType));
      expect(enumConstantField.name, equals('CONSTANT'));
      expect(enumConstantField.number, equals(3));
    });
  });
}

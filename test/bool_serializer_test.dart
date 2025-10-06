import 'package:test/test.dart';
import 'package:soia_client/soia_client.dart';
import 'dart:typed_data';

void main() {
  group('BoolSerializer', () {
    test('basic functionality - JSON serialization', () {
      // Test true value - should be true in readable, 1 in dense
      expect(
          Serializers.bool.toJson(false, readableFlavor: true), equals(false));
      expect(Serializers.bool.toJson(false, readableFlavor: false), equals(0));
      expect(Serializers.bool.toJson(true, readableFlavor: true), equals(true));
      expect(Serializers.bool.toJson(true, readableFlavor: false), equals(1));

      // Test JSON string serialization
      expect(Serializers.bool.toJsonCode(false, readableFlavor: true),
          equals('false'));
      expect(Serializers.bool.toJsonCode(false, readableFlavor: false),
          equals('0'));
      expect(Serializers.bool.toJsonCode(true, readableFlavor: true),
          equals('true'));
      expect(Serializers.bool.toJsonCode(true, readableFlavor: false),
          equals('1'));
    });

    test('JSON deserialization - boolean values', () {
      // Test boolean JSON values
      expect(Serializers.bool.fromJson(true), equals(true));
      expect(Serializers.bool.fromJson(false), equals(false));
      expect(Serializers.bool.fromJsonCode('true'), equals(true));
      expect(Serializers.bool.fromJsonCode('false'), equals(false));
    });

    test('JSON deserialization - numeric values', () {
      // Test numeric JSON values
      expect(Serializers.bool.fromJson(1), equals(true));
      expect(Serializers.bool.fromJson(0), equals(false));
      expect(Serializers.bool.fromJson(100), equals(true));
      expect(Serializers.bool.fromJson(-1), equals(true));
      expect(Serializers.bool.fromJson(3.14), equals(true));
      expect(Serializers.bool.fromJsonCode('1'), equals(true));
      expect(Serializers.bool.fromJsonCode('0'), equals(false));
      expect(Serializers.bool.fromJsonCode('100'), equals(true));
      expect(Serializers.bool.fromJsonCode('3.14'), equals(true));
    });

    test('JSON deserialization - string values', () {
      // Test string JSON values
      expect(Serializers.bool.fromJson('0'), equals(false));
      expect(Serializers.bool.fromJson('false'), equals(false));
      expect(Serializers.bool.fromJson('1'), equals(true));
      expect(Serializers.bool.fromJson('100'), equals(true));
      expect(Serializers.bool.fromJson('true'), equals(true));
      expect(Serializers.bool.fromJson('anything'), equals(true));
      expect(Serializers.bool.fromJsonCode('"0"'), equals(false));
      expect(Serializers.bool.fromJsonCode('"false"'), equals(false));
      expect(Serializers.bool.fromJsonCode('"1"'), equals(true));
      expect(Serializers.bool.fromJsonCode('"true"'), equals(true));
      expect(Serializers.bool.fromJsonCode('"anything"'), equals(true));
    });

    test('binary serialization', () {
      // From TypeScript tests: true -> "01", false -> "00"
      final trueBytes = Serializers.bool.toBytes(true);
      expect(_bytesToHex(trueBytes), equals('736f696101'));

      final falseBytes = Serializers.bool.toBytes(false);
      expect(_bytesToHex(falseBytes), equals('736f696100'));
    });

    test('binary deserialization roundtrip', () {
      // Test round trip
      final trueBytes = Serializers.bool.toBytes(true);
      final restoredTrue = Serializers.bool.fromBytes(trueBytes);
      expect(restoredTrue, equals(true));

      final falseBytes = Serializers.bool.toBytes(false);
      final restoredFalse = Serializers.bool.fromBytes(falseBytes);
      expect(restoredFalse, equals(false));
    });

    test('binary deserialization from other numeric types', () {
      // Test that non-zero numbers decode as true, zero as false
      expect(Serializers.bool.fromBytes(Serializers.int32.toBytes(100)),
          equals(true));
      expect(Serializers.bool.fromBytes(Serializers.float32.toBytes(3.14)),
          equals(true));
      expect(Serializers.bool.fromBytes(Serializers.uint64.toBytes(0)),
          equals(false));
      expect(Serializers.bool.fromBytes(Serializers.int64.toBytes(-1)),
          equals(true));
    });

    test('JSON roundtrip for all value types', () {
      final testValues = [true, false];

      for (final value in testValues) {
        // Test both flavors
        final denseJson =
            Serializers.bool.toJsonCode(value, readableFlavor: false);
        final readableJson =
            Serializers.bool.toJsonCode(value, readableFlavor: true);

        expect(Serializers.bool.fromJsonCode(denseJson), equals(value));
        expect(Serializers.bool.fromJsonCode(readableJson), equals(value));

        // Test binary roundtrip
        final bytes = Serializers.bool.toBytes(value);
        expect(Serializers.bool.fromBytes(bytes), equals(value));
      }
    });

    test('type descriptor', () {
      final typeDescriptor = Serializers.bool.typeDescriptor;
      expect(typeDescriptor, isA<PrimitiveDescriptor>());

      final primitiveDescriptor = typeDescriptor as PrimitiveDescriptor;
      expect(primitiveDescriptor.primitiveType, equals(PrimitiveType.BOOL));
    });

    test('edge cases and error handling', () {
      // Test empty string
      expect(Serializers.bool.fromJson(''), equals(true));
    });

    test('string encoding specifics', () {
      // Test specific string values that should return false
      final falseStrings = ['0', 'false'];
      for (final str in falseStrings) {
        expect(Serializers.bool.fromJson(str), equals(false));
      }

      // Test various strings that should return true
      final trueStrings = [
        '1',
        'true',
        'TRUE',
        'False',
        'anything',
        ' ',
        '00',
        'null'
      ];
      for (final str in trueStrings) {
        expect(Serializers.bool.fromJson(str), equals(true));
      }
    });

    test('binary format specifics', () {
      // Test specific binary format encoding (includes "soia" prefix)
      final testCases = [
        (true, '736f696101'),
        (false, '736f696100'),
      ];

      for (final (value, expectedHex) in testCases) {
        final bytes = Serializers.bool.toBytes(value);
        expect(_bytesToHex(bytes), equals(expectedHex));
        expect(Serializers.bool.fromBytes(bytes), equals(value));
      }
    });

    test('stringify method', () {
      // Test string representation functionality
      // Note: _stringify is not public, so we test via side effects or skip this test
      // This test verifies that the serializer can be used consistently
      final trueJson = Serializers.bool.toJsonCode(true);
      final falseJson = Serializers.bool.toJsonCode(false);
      expect(trueJson, isA<String>());
      expect(falseJson, isA<String>());
    });

    test('default value behavior in serialization', () {
      // Test that false (default) serializes to minimal representation in binary
      final falseBytes = Serializers.bool.toBytes(false);
      final trueBytes = Serializers.bool.toBytes(true);

      // Both should have same length due to fixed encoding
      expect(falseBytes.length, equals(trueBytes.length));
      expect(falseBytes.length, equals(5)); // "soia" + 1 byte
    });
  });
}

/// Helper function to convert bytes to hex string
String _bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

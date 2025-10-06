import 'package:test/test.dart';
import 'package:soia_client/soia_client.dart';
import 'dart:typed_data';

void main() {
  group('Int32Serializer', () {
    test('basic functionality - JSON serialization', () {
      // Test various int32 values - should be the same in both readable and dense flavors
      expect(Serializers.int32.toJson(0, readableFlavor: true), equals(0));
      expect(Serializers.int32.toJson(0, readableFlavor: false), equals(0));
      expect(Serializers.int32.toJson(42, readableFlavor: true), equals(42));
      expect(Serializers.int32.toJson(42, readableFlavor: false), equals(42));
      expect(Serializers.int32.toJson(-1, readableFlavor: true), equals(-1));
      expect(Serializers.int32.toJson(-1, readableFlavor: false), equals(-1));

      // Test JSON string serialization
      expect(
          Serializers.int32.toJsonCode(0, readableFlavor: true), equals('0'));
      expect(
          Serializers.int32.toJsonCode(0, readableFlavor: false), equals('0'));
      expect(
          Serializers.int32.toJsonCode(42, readableFlavor: true), equals('42'));
      expect(Serializers.int32.toJsonCode(42, readableFlavor: false),
          equals('42'));
      expect(
          Serializers.int32.toJsonCode(-1, readableFlavor: true), equals('-1'));
      expect(Serializers.int32.toJsonCode(-1, readableFlavor: false),
          equals('-1'));
    });

    test('JSON deserialization - integer values', () {
      // Test integer JSON values
      expect(Serializers.int32.fromJson(0), equals(0));
      expect(Serializers.int32.fromJson(42), equals(42));
      expect(Serializers.int32.fromJson(-1), equals(-1));
      expect(Serializers.int32.fromJsonCode('0'), equals(0));
      expect(Serializers.int32.fromJsonCode('42'), equals(42));
      expect(Serializers.int32.fromJsonCode('-1'), equals(-1));
    });

    test('JSON deserialization - string values', () {
      // Test string JSON values
      expect(Serializers.int32.fromJson('0'), equals(0));
      expect(Serializers.int32.fromJson('42'), equals(42));
      expect(Serializers.int32.fromJson('-1'), equals(-1));
      expect(Serializers.int32.fromJson('123456'), equals(123456));
      expect(Serializers.int32.fromJsonCode('"0"'), equals(0));
      expect(Serializers.int32.fromJsonCode('"42"'), equals(42));
      expect(Serializers.int32.fromJsonCode('"-1"'), equals(-1));
      expect(Serializers.int32.fromJsonCode('"123456"'), equals(123456));
    });

    test('JSON deserialization - floating point values', () {
      // Test floating point JSON values (should truncate to integer)
      expect(Serializers.int32.fromJson(3.14), equals(3));
      expect(Serializers.int32.fromJson(-2.7), equals(-2));
      expect(Serializers.int32.fromJson(42.0), equals(42));
      expect(Serializers.int32.fromJsonCode('3.14'), equals(3));
      expect(Serializers.int32.fromJsonCode('-2.7'), equals(-2));
      expect(Serializers.int32.fromJsonCode('42.0'), equals(42));
    });

    test('32-bit signed integer boundaries', () {
      const int maxInt32 = 2147483647; // 2^31 - 1
      const int minInt32 = -2147483648; // -2^31

      // Test boundary values
      expect(Serializers.int32.fromJson(maxInt32), equals(maxInt32));
      expect(Serializers.int32.fromJson(minInt32), equals(minInt32));
      expect(Serializers.int32.toJson(maxInt32), equals(maxInt32));
      expect(Serializers.int32.toJson(minInt32), equals(minInt32));

      // Test that toSigned(32) is applied - overflow should wrap around
      // Note: This tests the Dart-specific behavior not present in Kotlin
      const int overflowValue = 2147483648; // 2^31 (one more than max)
      const int underflowValue = -2147483649; // -2^31 - 1 (one less than min)

      expect(Serializers.int32.toJson(overflowValue),
          equals(-2147483648)); // wraps to min
      expect(Serializers.int32.toJson(underflowValue),
          equals(2147483647)); // wraps to max
    });

    test('binary serialization', () {
      // Test specific binary encodings for various int32 values
      final zeroBytes = Serializers.int32.toBytes(0);
      expect(_bytesToHex(zeroBytes), equals('736f696100')); // "soia" + 0x00

      final oneBytes = Serializers.int32.toBytes(1);
      expect(_bytesToHex(oneBytes), equals('736f696101')); // "soia" + 0x01

      final negativeOneBytes = Serializers.int32.toBytes(-1);
      expect(_bytesToHex(negativeOneBytes),
          startsWith('736f6961')); // "soia" prefix
    });

    test('binary deserialization roundtrip', () {
      final testValues = [
        0, 1, -1, 42, -42, 100, -100, 1000, -1000,
        2147483647, -2147483648, // boundary values
      ];

      for (final value in testValues) {
        final bytes = Serializers.int32.toBytes(value);
        final restored = Serializers.int32.fromBytes(bytes);
        expect(restored, equals(value),
            reason: 'Failed roundtrip for value: $value');
      }
    });

    test('binary deserialization from other numeric types', () {
      // Test that int32 can decode from other numeric serializers when values are in range
      expect(Serializers.int32.fromBytes(Serializers.uint64.toBytes(42)),
          equals(42));
      expect(Serializers.int32.fromBytes(Serializers.int64.toBytes(100)),
          equals(100));
      expect(Serializers.int32.fromBytes(Serializers.uint64.toBytes(0)),
          equals(0));
    });

    test('JSON roundtrip for all value types', () {
      final testValues = [
        0, 1, -1, 42, -42, 100, -100, 1000, -1000,
        2147483647, -2147483648, // boundary values
      ];

      for (final value in testValues) {
        // Test both flavors (should be identical for int32)
        final denseJson =
            Serializers.int32.toJsonCode(value, readableFlavor: false);
        final readableJson =
            Serializers.int32.toJsonCode(value, readableFlavor: true);

        expect(denseJson, equals(readableJson),
            reason: 'JSON flavors should be identical for int32');
        expect(Serializers.int32.fromJsonCode(denseJson), equals(value));
        expect(Serializers.int32.fromJsonCode(readableJson), equals(value));

        // Test binary roundtrip
        final bytes = Serializers.int32.toBytes(value);
        expect(Serializers.int32.fromBytes(bytes), equals(value));
      }
    });

    test('type descriptor', () {
      final typeDescriptor = Serializers.int32.typeDescriptor;
      expect(typeDescriptor, isA<PrimitiveDescriptor>());

      final primitiveDescriptor = typeDescriptor as PrimitiveDescriptor;
      expect(primitiveDescriptor.primitiveType, equals(PrimitiveType.INT_32));
    });

    test('edge cases and error handling', () {
      // Test zero value
      expect(Serializers.int32.fromJson(0), equals(0));
      expect(Serializers.int32.fromJson(0.0), equals(0));
      expect(Serializers.int32.fromJson('0'), equals(0));

      // Test large numbers that should be truncated/converted
      expect(Serializers.int32.fromJson(2147483648.0),
          equals(-2147483648)); // overflow
      expect(Serializers.int32.fromJson(-2147483649.0),
          equals(2147483647)); // underflow
    });

    test('string parsing edge cases', () {
      // Test various string formats
      expect(Serializers.int32.fromJson('0'), equals(0));
      expect(Serializers.int32.fromJson('-0'), equals(0));
      expect(Serializers.int32.fromJson('+42'), equals(42));
      expect(Serializers.int32.fromJson('  123  '),
          equals(123)); // Dart's int.parse handles whitespace

      // Test that decimal strings throw exceptions (both Dart and Kotlin should fail on these)
      expect(() => Serializers.int32.fromJson('3.14'), throwsFormatException);
      expect(() => Serializers.int32.fromJson('-2.7'), throwsFormatException);
    });

    test('binary format specifics', () {
      // Test specific binary format encoding based on wire format
      final testCases = [
        (0, '736f696100'), // 0 -> wire 0
        (1, '736f696101'), // 1 -> wire 1
        (42, '736f69612a'), // 42 -> wire 42
        (100, '736f696164'), // 100 -> wire 100
        (200, '736f6961c8'), // 200 -> wire 200
      ];

      for (final (value, expectedHex) in testCases) {
        final bytes = Serializers.int32.toBytes(value);
        expect(_bytesToHex(bytes), equals(expectedHex));
        expect(Serializers.int32.fromBytes(bytes), equals(value));
      }
    });

    test('large value binary encoding', () {
      // Test values that require multi-byte encoding
      final largeTestCases = [
        1000, // Should use extended encoding
        10000, // Should use extended encoding
        100000, // Should use extended encoding
        1000000, // Should use extended encoding
        2147483647, // max int32
        -1, // negative numbers
        -1000, // negative numbers
        -2147483648, // min int32
      ];

      for (final value in largeTestCases) {
        final bytes = Serializers.int32.toBytes(value);
        expect(bytes.length, greaterThan(4)); // "soia" prefix + at least 1 byte
        final restored = Serializers.int32.fromBytes(bytes);
        expect(restored, equals(value),
            reason: 'Failed roundtrip for large value: $value');
      }
    });

    test('default value behavior', () {
      // Test that 0 is identified as default value
      // Note: Can't directly test isDefault since _impl is private
      // But we can test that 0 serializes efficiently
      final zeroBytes = Serializers.int32.toBytes(0);
      final oneBytes = Serializers.int32.toBytes(1);

      // Both should serialize, but encoding may be optimized differently
      expect(zeroBytes.length,
          greaterThanOrEqualTo(5)); // At least "soia" + 1 byte
      expect(
          oneBytes.length, greaterThanOrEqualTo(5)); // At least "soia" + 1 byte
    });

    test('consistency with other numeric serializers for similar values', () {
      final testValues = [0, 1, 42, -1, 100];

      for (final value in testValues) {
        // Test that int32 and int64 produce same results for values in int32 range
        final int32Json = Serializers.int32.toJsonCode(value);
        final int64Json = Serializers.int64.toJsonCode(value);
        expect(int32Json, equals(int64Json),
            reason:
                'int32 and int64 should produce same JSON for value: $value');

        // Test that values roundtrip consistently
        expect(Serializers.int32.fromJsonCode(int32Json), equals(value));
        expect(Serializers.int64.fromJsonCode(int64Json), equals(value));
      }
    });

    test('overflow and underflow behavior', () {
      // Test specific overflow/underflow scenarios that highlight Dart vs Kotlin difference
      const testCases = [
        (2147483648, -2147483648), // 2^31 -> -2^31 (overflow)
        (-2147483649, 2147483647), // -2^31-1 -> 2^31-1 (underflow)
        (4294967295, -1), // 2^32-1 -> -1 (overflow)
        (4294967296, 0), // 2^32 -> 0 (overflow)
      ];

      for (final (input, expectedOutput) in testCases) {
        final result = Serializers.int32.toJson(input);
        expect(result, equals(expectedOutput),
            reason: 'toSigned(32) should convert $input to $expectedOutput');

        // Test that fromJson also applies the same conversion
        final fromJsonResult = Serializers.int32.fromJson(input);
        expect(fromJsonResult, equals(expectedOutput),
            reason: 'fromJson should convert $input to $expectedOutput');
      }
    });
  });
}

/// Helper function to convert bytes to hex string
String _bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

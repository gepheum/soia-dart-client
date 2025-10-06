import 'package:test/test.dart';
import 'package:soia_client/soia_client.dart';
import 'dart:typed_data';
import 'dart:convert';

void main() {
  group('BytesSerializer', () {
    test('basic functionality - JSON serialization', () {
      // Test empty bytes - should be base64 encoded
      final emptyBytes = Uint8List(0);
      expect(Serializers.bytes.toJson(emptyBytes, readableFlavor: true), equals(''));
      expect(Serializers.bytes.toJson(emptyBytes, readableFlavor: false), equals(''));
      expect(Serializers.bytes.toJsonCode(emptyBytes, readableFlavor: true), equals('""'));
      expect(Serializers.bytes.toJsonCode(emptyBytes, readableFlavor: false), equals('""'));

      // Test simple byte arrays
      final helloBytes = Uint8List.fromList('hello'.codeUnits);
      final helloBase64 = base64Encode(helloBytes);
      expect(Serializers.bytes.toJson(helloBytes, readableFlavor: true), equals(helloBase64));
      expect(Serializers.bytes.toJson(helloBytes, readableFlavor: false), equals(helloBase64));
      expect(Serializers.bytes.toJsonCode(helloBytes, readableFlavor: true), equals('"$helloBase64"'));
      expect(Serializers.bytes.toJsonCode(helloBytes, readableFlavor: false), equals('"$helloBase64"'));

      // Test UTF-8 encoded bytes
      final utf8Bytes = Uint8List.fromList(utf8.encode('Hello, 世界!'));
      final utf8Base64 = base64Encode(utf8Bytes);
      expect(Serializers.bytes.toJson(utf8Bytes, readableFlavor: true), equals(utf8Base64));
      expect(Serializers.bytes.toJson(utf8Bytes, readableFlavor: false), equals(utf8Base64));
    });

    test('JSON flavor consistency', () {
      // JsonFlavor shouldn't affect bytes - both should produce identical base64 results
      final testByteArrays = [
        Uint8List(0),
        Uint8List.fromList([65]), // 'A'
        Uint8List.fromList('hello'.codeUnits),
        Uint8List.fromList('world'.codeUnits),
        Uint8List.fromList(utf8.encode('Hello, 世界!')),
        Uint8List.fromList([0, 255, 128, 64, 32]), // Various byte values
      ];

      for (final value in testByteArrays) {
        expect(
          Serializers.bytes.toJsonCode(value, readableFlavor: true),
          equals(Serializers.bytes.toJsonCode(value, readableFlavor: false)),
          reason: 'Readable and dense flavors should be identical for bytes: ${_bytesToHex(value)}',
        );
        
        expect(
          Serializers.bytes.toJson(value, readableFlavor: true),
          equals(Serializers.bytes.toJson(value, readableFlavor: false)),
          reason: 'Readable and dense JSON should be identical for bytes: ${_bytesToHex(value)}',
        );
      }
    });

    test('JSON deserialization - base64 string values', () {
      // Test base64 string JSON values
      expect(Serializers.bytes.fromJson(''), equals(Uint8List(0)));
      
      final helloBytes = Uint8List.fromList('hello'.codeUnits);
      final helloBase64 = base64Encode(helloBytes);
      expect(Serializers.bytes.fromJson(helloBase64), equals(helloBytes));
      expect(Serializers.bytes.fromJsonCode('"$helloBase64"'), equals(helloBytes));
      
      final utf8Bytes = Uint8List.fromList(utf8.encode('Hello, 世界!'));
      final utf8Base64 = base64Encode(utf8Bytes);
      expect(Serializers.bytes.fromJson(utf8Base64), equals(utf8Bytes));
      expect(Serializers.bytes.fromJsonCode('"$utf8Base64"'), equals(utf8Bytes));
      
      // Test binary data
      final binaryBytes = Uint8List.fromList([0, 255, 128, 64, 32]);
      final binaryBase64 = base64Encode(binaryBytes);
      expect(Serializers.bytes.fromJson(binaryBase64), equals(binaryBytes));
      expect(Serializers.bytes.fromJsonCode('"$binaryBase64"'), equals(binaryBytes));
    });

    test('JSON deserialization - special numeric case', () {
      // Test special case: numeric 0 should deserialize to empty bytes
      expect(Serializers.bytes.fromJson(0), equals(Uint8List(0)));
      expect(Serializers.bytes.fromJsonCode('0'), equals(Uint8List(0)));
      
      // Other numbers should cause ArgumentError (since they're not valid base64)
      expect(() => Serializers.bytes.fromJson(42), throwsA(isA<ArgumentError>()));
      expect(() => Serializers.bytes.fromJsonCode('42'), throwsA(isA<ArgumentError>()));
    });

    test('JSON deserialization - invalid values', () {
      // Test that invalid base64 strings cause errors
      expect(() => Serializers.bytes.fromJson('invalid-base64!'), throwsA(isA<FormatException>()));
      expect(() => Serializers.bytes.fromJsonCode('"invalid-base64!"'), throwsA(isA<FormatException>()));
      
      // Test that non-string, non-zero values cause ArgumentError
      expect(() => Serializers.bytes.fromJson(true), throwsA(isA<ArgumentError>()));
      expect(() => Serializers.bytes.fromJson(false), throwsA(isA<ArgumentError>()));
      expect(() => Serializers.bytes.fromJson([1, 2, 3]), throwsA(isA<ArgumentError>()));
      expect(() => Serializers.bytes.fromJson({'key': 'value'}), throwsA(isA<ArgumentError>()));
    });

    test('binary serialization - empty bytes optimization', () {
      // Test that empty bytes uses optimized encoding (wire code 244/0xF4)
      final emptyBytes = Uint8List(0);
      final emptyBinary = Serializers.bytes.toBytes(emptyBytes);
      expect(_bytesToHex(emptyBinary), equals('736f6961f4')); // "soia" + 0xF4

      // Test non-empty bytes use standard encoding (wire code 245/0xF5)
      final nonEmptyBytes = Uint8List.fromList([65]); // 'A'
      final nonEmptyBinary = Serializers.bytes.toBytes(nonEmptyBytes);
      expect(_bytesToHex(nonEmptyBinary), startsWith('736f6961f5')); // "soia" + 0xF5 + length + data
    });

    test('binary encoding specifics', () {
      // Test specific wire format encoding (includes "soia" prefix + wire code + length + raw bytes)
      final testCases = [
        (Uint8List(0), '736f6961f4'), // empty -> 0xF4
        (Uint8List.fromList([65]), '736f6961f50141'), // "A" -> 0xF5 + length(1) + 0x41
        (Uint8List.fromList([0, 255]), '736f6961f50200ff'), // [0, 255] -> 0xF5 + length(2) + 0x00 + 0xFF
      ];

      for (final (value, expectedHex) in testCases) {
        final bytes = Serializers.bytes.toBytes(value);
        expect(_bytesToHex(bytes), equals(expectedHex),
            reason: 'Failed encoding for bytes: ${_bytesToHex(value)}');
      }
    });

    test('binary deserialization roundtrip', () {
      final testValues = [
        Uint8List(0), // empty
        Uint8List.fromList([65]), // single byte 'A'
        Uint8List.fromList([0]), // null byte
        Uint8List.fromList([255]), // max byte
        Uint8List.fromList([0, 255]), // min and max
        Uint8List.fromList('hello'.codeUnits), // ASCII string
        Uint8List.fromList(utf8.encode('Hello, 世界!')), // UTF-8 string
        Uint8List.fromList([0, 1, 2, 3, 4, 5, 252, 253, 254, 255]), // various values
        Uint8List.fromList(List.generate(256, (i) => i)), // all byte values
        Uint8List.fromList(List.generate(1000, (i) => i % 256)), // larger array
      ];

      for (final value in testValues) {
        final bytes = Serializers.bytes.toBytes(value);
        final restored = Serializers.bytes.fromBytes(bytes);
        expect(restored, equals(value),
            reason: 'Failed roundtrip for bytes: ${_bytesToHex(value)}');
      }
    });

    test('type descriptor', () {
      final typeDescriptor = Serializers.bytes.typeDescriptor;
      expect(typeDescriptor, isA<PrimitiveDescriptor>());

      final primitiveDescriptor = typeDescriptor as PrimitiveDescriptor;
      expect(primitiveDescriptor.primitiveType, equals(PrimitiveType.BYTES));
    });

    test('JSON roundtrip for various byte arrays', () {
      final testByteArrays = [
        Uint8List(0), // empty
        Uint8List.fromList([65]), // single ASCII
        Uint8List.fromList('hello'.codeUnits), // ASCII string
        Uint8List.fromList(utf8.encode('Hello, 世界!')), // UTF-8 string
        Uint8List.fromList([0, 255, 128]), // binary data
        Uint8List.fromList(List.generate(256, (i) => i)), // all byte values
        Uint8List.fromList([255, 254, 253, 252, 251]), // high byte values
        Uint8List.fromList([0, 1, 2, 3, 4]), // low byte values
      ];

      for (final value in testByteArrays) {
        // Test JSON roundtrip
        final jsonCode = Serializers.bytes.toJsonCode(value);
        expect(Serializers.bytes.fromJsonCode(jsonCode), equals(value),
            reason: 'JSON roundtrip failed for bytes: ${_bytesToHex(value)}');

        // Test that readable and dense produce same results for roundtrip
        final readableJson = Serializers.bytes.toJsonCode(value, readableFlavor: true);
        final denseJson = Serializers.bytes.toJsonCode(value, readableFlavor: false);
        expect(readableJson, equals(denseJson));
        expect(Serializers.bytes.fromJsonCode(readableJson), equals(value));
        expect(Serializers.bytes.fromJsonCode(denseJson), equals(value));
      }
    });

    test('default value detection', () {
      // Test that empty bytes is considered the default value
      final emptyBytes = Uint8List(0);
      final nonEmptyBytes = Uint8List.fromList([1]);

      // Verify empty bytes gets optimized binary encoding
      final emptyBinary = Serializers.bytes.toBytes(emptyBytes);
      final nonEmptyBinary = Serializers.bytes.toBytes(nonEmptyBytes);
      
      expect(emptyBinary.length, lessThan(nonEmptyBinary.length),
          reason: 'Empty bytes should use shorter encoding than non-empty');
      expect(_bytesToHex(emptyBinary), endsWith('f4')); // Should end with 0xF4
      expect(_bytesToHex(nonEmptyBinary), contains('f5')); // Should contain 0xF5 wire code
    });

    test('base64 encoding edge cases', () {
      // Test various byte patterns that might cause base64 encoding issues
      final edgeCases = [
        Uint8List(0), // empty
        Uint8List.fromList([0]), // single null
        Uint8List.fromList([255]), // single max
        Uint8List.fromList([0, 0, 0]), // multiple nulls
        Uint8List.fromList([255, 255, 255]), // multiple max
        Uint8List.fromList([77, 97, 110]), // "Man" in ASCII (classic base64 example)
        Uint8List.fromList([77, 97]), // "Ma" (padding test)
        Uint8List.fromList([77]), // "M" (more padding)
        Uint8List.fromList([240, 159, 152, 128]), // 😀 emoji in UTF-8
      ];

      for (final value in edgeCases) {
        // Test that base64 encoding/decoding works correctly
        final binary = Serializers.bytes.toBytes(value);
        final restored = Serializers.bytes.fromBytes(binary);
        expect(restored, equals(value),
            reason: 'Binary roundtrip failed for: ${_bytesToHex(value)}');

        // Test JSON roundtrip with base64
        final jsonCode = Serializers.bytes.toJsonCode(value);
        final jsonRestored = Serializers.bytes.fromJsonCode(jsonCode);
        expect(jsonRestored, equals(value),
            reason: 'JSON base64 roundtrip failed for: ${_bytesToHex(value)}');
        
        // Verify the JSON is valid base64
        if (value.isNotEmpty) {
          expect(jsonCode, startsWith('"'));
          expect(jsonCode, endsWith('"'));
          final base64Content = jsonCode.substring(1, jsonCode.length - 1);
          expect(() => base64Decode(base64Content), returnsNormally,
              reason: 'Generated JSON should contain valid base64: $jsonCode');
        }
      }
    });

    test('large byte array handling', () {
      // Test very large byte arrays to ensure the serializer can handle them
      final smallArray = Uint8List.fromList(List.generate(100, (i) => i % 256));
      final mediumArray = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      final largeArray = Uint8List.fromList(List.generate(10000, (i) => i % 256));
      final hugeArray = Uint8List.fromList(List.generate(100000, (i) => i % 256)); // 100KB

      final testArrays = [smallArray, mediumArray, largeArray, hugeArray];

      for (final value in testArrays) {
        // Test binary serialization of large arrays
        final bytes = Serializers.bytes.toBytes(value);
        final restored = Serializers.bytes.fromBytes(bytes);
        expect(restored, equals(value),
            reason: 'Large array roundtrip failed for ${value.length}-byte array');
        expect(restored.length, equals(value.length));

        // Test JSON serialization of large arrays
        final jsonCode = Serializers.bytes.toJsonCode(value);
        final jsonRestored = Serializers.bytes.fromJsonCode(jsonCode);
        expect(jsonRestored, equals(value),
            reason: 'Large array JSON roundtrip failed for ${value.length}-byte array');
        expect(jsonRestored.length, equals(value.length));
      }
    });

    test('byte length prefix encoding', () {
      // Test that byte array length is properly encoded in binary format
      final testCases = [
        Uint8List(0), // empty has no length prefix
        Uint8List.fromList([1]), // 1 byte
        Uint8List.fromList([1, 2]), // 2 bytes  
        Uint8List.fromList(List.generate(231, (i) => i)), // just under wire type threshold
        Uint8List.fromList(List.generate(232, (i) => i)), // at wire type threshold  
        Uint8List.fromList(List.generate(1000, (i) => i % 256)), // larger length
      ];

      for (final value in testCases) {
        final bytes = Serializers.bytes.toBytes(value);
        final restored = Serializers.bytes.fromBytes(bytes);
        expect(restored, equals(value),
            reason: 'Length encoding roundtrip failed for ${value.length}-byte array');
        expect(restored.length, equals(value.length));
      }
    });

    test('binary data patterns', () {
      // Test specific binary data patterns that might cause issues
      final patterns = [
        // All zeros
        Uint8List.fromList(List.filled(10, 0)),
        // All ones (max values)
        Uint8List.fromList(List.filled(10, 255)),
        // Alternating pattern
        Uint8List.fromList(List.generate(10, (i) => i % 2 == 0 ? 0 : 255)),
        // Ascending sequence
        Uint8List.fromList(List.generate(10, (i) => i)),
        // Descending sequence
        Uint8List.fromList(List.generate(10, (i) => 9 - i)),
        // Random-looking pattern
        Uint8List.fromList([142, 73, 199, 84, 201, 15, 88, 162, 37, 249]),
        // Pattern that might look like wire codes
        Uint8List.fromList([244, 245, 242, 243, 240, 241]),
      ];

      for (final value in patterns) {
        // Test binary serialization
        final bytes = Serializers.bytes.toBytes(value);
        final restored = Serializers.bytes.fromBytes(bytes);
        expect(restored, equals(value),
            reason: 'Binary pattern roundtrip failed for: ${_bytesToHex(value)}');

        // Test JSON serialization
        final jsonCode = Serializers.bytes.toJsonCode(value);
        final jsonRestored = Serializers.bytes.fromJsonCode(jsonCode);
        expect(jsonRestored, equals(value),
            reason: 'JSON pattern roundtrip failed for: ${_bytesToHex(value)}');
      }
    });

    test('error handling and edge cases', () {
      // Test edge cases and potential error conditions
      
      // Empty bytes should work perfectly
      expect(Serializers.bytes.fromJsonCode('""'), equals(Uint8List(0)));
      expect(Serializers.bytes.fromJson(''), equals(Uint8List(0)));
      expect(Serializers.bytes.fromJson(0), equals(Uint8List(0))); // Special case
      
      // Valid base64 should work
      final testBytes = Uint8List.fromList([72, 101, 108, 108, 111]); // "Hello"
      final validBase64 = base64Encode(testBytes);
      expect(Serializers.bytes.fromJson(validBase64), equals(testBytes));
      
      // Invalid base64 should throw FormatException
      expect(() => Serializers.bytes.fromJson('not-base64!'), throwsA(isA<FormatException>()));
      expect(() => Serializers.bytes.fromJson('almost-base64='), throwsA(isA<FormatException>()));
      
      // Non-string, non-zero values should throw ArgumentError
      expect(() => Serializers.bytes.fromJson(42), throwsA(isA<ArgumentError>()));
      expect(() => Serializers.bytes.fromJson(true), throwsA(isA<ArgumentError>()));
      expect(() => Serializers.bytes.fromJson([]), throwsA(isA<ArgumentError>()));
    });

    test('consistency with other serializers', () {
      // Test interaction with the serialization system
      
      // Empty bytes should be considered default
      final emptyBinary = Serializers.bytes.toBytes(Uint8List(0));
      final nonEmptyBinary = Serializers.bytes.toBytes(Uint8List.fromList([1]));
      expect(emptyBinary.length, lessThan(nonEmptyBinary.length));
      
      // Bytes serialization should be deterministic
      final testBytes = Uint8List.fromList([72, 101, 108, 108, 111, 44, 32, 240, 159, 140, 141]);
      final binary1 = Serializers.bytes.toBytes(testBytes);
      final binary2 = Serializers.bytes.toBytes(testBytes);
      expect(_bytesToHex(binary1), equals(_bytesToHex(binary2)));
      
      final json1 = Serializers.bytes.toJsonCode(testBytes);
      final json2 = Serializers.bytes.toJsonCode(testBytes);
      expect(json1, equals(json2));
    });

    test('wire code boundary testing', () {
      // Test bytes that might be confused with wire codes
      final wireCodeBytes = [0, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 255];
      
      for (final wireCode in wireCodeBytes) {
        final testBytes = Uint8List.fromList([wireCode]);
        
        // Test that these bytes serialize and deserialize correctly
        final binary = Serializers.bytes.toBytes(testBytes);
        final restored = Serializers.bytes.fromBytes(binary);
        expect(restored, equals(testBytes),
            reason: 'Wire code byte $wireCode should roundtrip correctly');
        
        // Test JSON roundtrip
        final jsonCode = Serializers.bytes.toJsonCode(testBytes);
        final jsonRestored = Serializers.bytes.fromJsonCode(jsonCode);
        expect(jsonRestored, equals(testBytes),
            reason: 'Wire code byte $wireCode should JSON roundtrip correctly');
      }
    });
  });
}

/// Helper function to convert bytes to hex string
String _bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

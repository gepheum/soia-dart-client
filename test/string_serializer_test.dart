import 'package:test/test.dart';
import 'package:soia_client/soia_client.dart';
import 'dart:typed_data';

void main() {
  group('StringSerializer', () {
    test('basic functionality - JSON serialization', () {
      // Test empty string - should be the same in both readable and dense flavors
      expect(Serializers.string.toJson('', readableFlavor: true), equals(''));
      expect(Serializers.string.toJson('', readableFlavor: false), equals(''));
      expect(Serializers.string.toJsonCode('', readableFlavor: true), equals('""'));
      expect(Serializers.string.toJsonCode('', readableFlavor: false), equals('""'));

      // Test simple strings
      expect(Serializers.string.toJson('hello', readableFlavor: true), equals('hello'));
      expect(Serializers.string.toJson('hello', readableFlavor: false), equals('hello'));
      expect(Serializers.string.toJsonCode('hello', readableFlavor: true), equals('"hello"'));
      expect(Serializers.string.toJsonCode('hello', readableFlavor: false), equals('"hello"'));

      // Test special characters
      expect(Serializers.string.toJson('Hello, 世界!', readableFlavor: true), equals('Hello, 世界!'));
      expect(Serializers.string.toJson('🚀', readableFlavor: true), equals('🚀'));
      expect(Serializers.string.toJson('\n\t\r', readableFlavor: true), equals('\n\t\r'));
    });

    test('JSON flavor consistency', () {
      // JsonFlavor shouldn't affect plain strings - both should produce identical results
      final testStrings = [
        '',
        'hello',
        'world',
        'Hello, 世界!',
        '🚀',
        '\n\t\r',
        'A very long string that exceeds normal buffer sizes and should test the streaming capabilities of the serializer properly',
      ];

      for (final value in testStrings) {
        expect(
          Serializers.string.toJsonCode(value, readableFlavor: true),
          equals(Serializers.string.toJsonCode(value, readableFlavor: false)),
          reason: 'Readable and dense flavors should be identical for string: "$value"',
        );
        
        expect(
          Serializers.string.toJson(value, readableFlavor: true),
          equals(Serializers.string.toJson(value, readableFlavor: false)),
          reason: 'Readable and dense JSON should be identical for string: "$value"',
        );
      }
    });

    test('JSON deserialization - string values', () {
      // Test string JSON values
      expect(Serializers.string.fromJson(''), equals(''));
      expect(Serializers.string.fromJson('hello'), equals('hello'));
      expect(Serializers.string.fromJson('world'), equals('world'));
      expect(Serializers.string.fromJson('Hello, 世界!'), equals('Hello, 世界!'));
      expect(Serializers.string.fromJson('🚀'), equals('🚀'));
      expect(Serializers.string.fromJson('\n\t\r'), equals('\n\t\r'));
      
      expect(Serializers.string.fromJsonCode('""'), equals(''));
      expect(Serializers.string.fromJsonCode('"hello"'), equals('hello'));
      expect(Serializers.string.fromJsonCode('"Hello, 世界!"'), equals('Hello, 世界!'));
      expect(Serializers.string.fromJsonCode('"🚀"'), equals('🚀'));
    });

    test('JSON deserialization - special numeric case', () {
      // Test special case: numeric 0 should deserialize to empty string
      expect(Serializers.string.fromJson(0), equals(''));
      expect(Serializers.string.fromJsonCode('0'), equals(''));
      
      // Other numbers should be converted to string
      expect(Serializers.string.fromJson(42), equals('42'));
      expect(Serializers.string.fromJson(3.14), equals('3.14'));
      expect(Serializers.string.fromJsonCode('42'), equals('42'));
      expect(Serializers.string.fromJsonCode('3.14'), equals('3.14'));
    });

    test('JSON deserialization - non-string values', () {
      // Test that non-string values are converted to string via toString()
      expect(Serializers.string.fromJson(true), equals('true'));
      expect(Serializers.string.fromJson(false), equals('false'));
      expect(Serializers.string.fromJson(null), equals('null'));
      expect(Serializers.string.fromJson([1, 2, 3]), equals('[1, 2, 3]'));
      expect(Serializers.string.fromJson({'key': 'value'}), equals('{key: value}'));
    });

    test('binary serialization - empty string optimization', () {
      // Test that empty string uses optimized encoding (wire code 242/0xF2)
      final emptyBytes = Serializers.string.toBytes('');
      expect(_bytesToHex(emptyBytes), equals('736f6961f2')); // "soia" + 0xF2

      // Test non-empty strings use standard encoding (wire code 243/0xF3)
      final nonEmptyBytes = Serializers.string.toBytes('A');
      expect(_bytesToHex(nonEmptyBytes), startsWith('736f6961f3')); // "soia" + 0xF3 + length + data
    });

    test('binary encoding specifics', () {
      // Test specific wire format encoding (includes "soia" prefix + wire code + length + UTF-8 data)
      final testCases = [
        ('', '736f6961f2'), // empty -> 0xF2
        ('0', '736f6961f30130'), // "0" -> 0xF3 + length(1) + 0x30
        ('A', '736f6961f30141'), // "A" -> 0xF3 + length(1) + 0x41
        ('🚀', '736f6961f304f09f9a80'), // rocket emoji -> 0xF3 + length(4) + UTF-8 bytes
        ('\u0000', '736f6961f30100'), // null char -> 0xF3 + length(1) + 0x00
        ('Hello\nWorld', '736f6961f30b48656c6c6f0a576f726c64'), // with newline
      ];

      for (final (value, expectedHex) in testCases) {
        final bytes = Serializers.string.toBytes(value);
        expect(_bytesToHex(bytes), equals(expectedHex),
            reason: 'Failed encoding for string: "$value"');
      }
    });

    test('binary deserialization roundtrip', () {
      final testValues = [
        '',
        'hello',
        'world',
        'Hello, 世界!',
        '🚀',
        '\n\t\r',
        '\u0000',
        'A very long string that exceeds normal buffer sizes and should test the streaming capabilities of the serializer properly',
        'String with "quotes" and \\backslashes\\',
        'Multi\nline\nstring\nwith\nvarious\ncharacters',
        '0123456789',
        'Special chars: !@#\$%^&*()_+-=[]{}|;:,.<>?',
      ];

      for (final value in testValues) {
        final bytes = Serializers.string.toBytes(value);
        final restored = Serializers.string.fromBytes(bytes);
        expect(restored, equals(value),
            reason: 'Failed roundtrip for string: "$value"');
      }
    });

    test('type descriptor', () {
      final typeDescriptor = Serializers.string.typeDescriptor;
      expect(typeDescriptor, isA<PrimitiveDescriptor>());

      final primitiveDescriptor = typeDescriptor as PrimitiveDescriptor;
      expect(primitiveDescriptor.primitiveType, equals(PrimitiveType.STRING));
    });

    test('JSON roundtrip for various strings', () {
      final testStrings = [
        '',
        'hello',
        'world',
        'Hello, 世界!',
        '🚀',
        '\n\t\r',
        '\u0000',
        'String with "quotes" and \\backslashes\\',
        'Multi\nline\nstring',
        '{"json": "like", "string": true}',
        '[1, 2, 3, "array", "like"]',
        'Very long string that contains many characters and should test the limits of the serialization system while ensuring that all data is preserved correctly during the roundtrip process',
      ];

      for (final value in testStrings) {
        // Test JSON roundtrip
        final jsonCode = Serializers.string.toJsonCode(value);
        expect(Serializers.string.fromJsonCode(jsonCode), equals(value),
            reason: 'JSON roundtrip failed for string: "$value"');

        // Test that readable and dense produce same results for roundtrip
        final readableJson = Serializers.string.toJsonCode(value, readableFlavor: true);
        final denseJson = Serializers.string.toJsonCode(value, readableFlavor: false);
        expect(readableJson, equals(denseJson));
        expect(Serializers.string.fromJsonCode(readableJson), equals(value));
        expect(Serializers.string.fromJsonCode(denseJson), equals(value));
      }
    });

    test('default value detection', () {
      // Test that empty string is considered the default value
      final emptyString = '';
      final nonEmptyString = 'hello';

      // Verify empty string gets optimized binary encoding
      final emptyBytes = Serializers.string.toBytes(emptyString);
      final nonEmptyBytes = Serializers.string.toBytes(nonEmptyString);
      
      expect(emptyBytes.length, lessThan(nonEmptyBytes.length),
          reason: 'Empty string should use shorter encoding than non-empty');
      expect(_bytesToHex(emptyBytes), endsWith('f2')); // Should end with 0xF2
      expect(_bytesToHex(nonEmptyBytes), contains('f3')); // Should contain 0xF3 wire code
    });

    test('UTF-8 encoding edge cases', () {
      // Test various UTF-8 encoded strings
      final utf8TestCases = [
        'ASCII only',
        'Ñoño español',
        'Ελληνικά Greek',
        'العربية Arabic',
        'עברית Hebrew',
        '中文 Chinese',
        '日本語 Japanese',
        '한국어 Korean',
        'Русский Russian',
        'हिन्दी Hindi',
        'Emoji: 😀😂🤣❤️😍🤔👍🔥💯🚀',
        '🏳️‍🌈🏳️‍⚧️', // Complex emoji with modifiers
        '\u{1F600}\u{1F601}\u{1F602}', // Unicode escape sequences
      ];

      for (final value in utf8TestCases) {
        // Test that UTF-8 encoding/decoding works correctly
        final bytes = Serializers.string.toBytes(value);
        final restored = Serializers.string.fromBytes(bytes);
        expect(restored, equals(value),
            reason: 'UTF-8 roundtrip failed for: "$value"');

        // Test JSON roundtrip with UTF-8
        final jsonCode = Serializers.string.toJsonCode(value);
        final jsonRestored = Serializers.string.fromJsonCode(jsonCode);
        expect(jsonRestored, equals(value),
            reason: 'JSON UTF-8 roundtrip failed for: "$value"');
      }
    });

    test('control characters and escape sequences', () {
      // Test strings with control characters and escape sequences
      final controlTestCases = [
        '\u0000', // null
        '\u0001', // start of heading
        '\u0007', // bell
        '\u0008', // backspace
        '\u0009', // tab
        '\u000A', // line feed
        '\u000B', // vertical tab
        '\u000C', // form feed
        '\u000D', // carriage return
        '\u001B', // escape
        '\u007F', // delete
        '\u0080', // control character
        '\u009F', // control character
        'String with \u0000 null character in middle',
        'Line 1\nLine 2\rLine 3\r\nLine 4',
        'Tab\tseparated\tvalues',
        'Quote: " and backslash: \\',
        'All controls: \u0000\u0001\u0002\u0003\u0004\u0005\u0006\u0007\u0008\u0009\u000A\u000B\u000C\u000D\u000E\u000F',
      ];

      for (final value in controlTestCases) {
        // Test binary roundtrip with control characters
        final bytes = Serializers.string.toBytes(value);
        final restored = Serializers.string.fromBytes(bytes);
        expect(restored, equals(value),
            reason: 'Control character roundtrip failed for: "${value.replaceAll('\u0000', '\\u0000')}"');

        // Test JSON roundtrip (JSON escaping should handle these)
        final jsonCode = Serializers.string.toJsonCode(value);
        final jsonRestored = Serializers.string.fromJsonCode(jsonCode);
        expect(jsonRestored, equals(value),
            reason: 'JSON control character roundtrip failed for: "${value.replaceAll('\u0000', '\\u0000')}"');
      }
    });

    test('large string handling', () {
      // Test very large strings to ensure the serializer can handle them
      final smallString = 'A' * 100;
      final mediumString = 'B' * 1000;
      final largeString = 'C' * 10000;
      final hugeString = 'D' * 100000; // 100KB string

      final testStrings = [smallString, mediumString, largeString, hugeString];

      for (final value in testStrings) {
        // Test binary serialization of large strings
        final bytes = Serializers.string.toBytes(value);
        final restored = Serializers.string.fromBytes(bytes);
        expect(restored, equals(value),
            reason: 'Large string roundtrip failed for ${value.length}-char string');
        expect(restored.length, equals(value.length));

        // Test JSON serialization of large strings  
        final jsonCode = Serializers.string.toJsonCode(value);
        final jsonRestored = Serializers.string.fromJsonCode(jsonCode);
        expect(jsonRestored, equals(value),
            reason: 'Large string JSON roundtrip failed for ${value.length}-char string');
        expect(jsonRestored.length, equals(value.length));
      }
    });

    test('string length prefix encoding', () {
      // Test that string length is properly encoded in binary format
      final testCases = [
        '', // empty string has no length prefix
        'A', // 1 byte
        'AB', // 2 bytes  
        '🚀', // emoji is 4 UTF-8 bytes
        'Hello', // 5 ASCII bytes
        'A' * 231, // just under wire type threshold
        'A' * 232, // at wire type threshold  
        'A' * 1000, // larger length
      ];

      for (final value in testCases) {
        final bytes = Serializers.string.toBytes(value);
        final restored = Serializers.string.fromBytes(bytes);
        expect(restored, equals(value),
            reason: 'Length encoding roundtrip failed for ${value.length}-char string');
      }
    });

    test('error handling and edge cases', () {
      // Test edge cases and potential error conditions
      
      // Empty string should work perfectly
      expect(Serializers.string.fromJsonCode('""'), equals(''));
      expect(Serializers.string.fromJson(''), equals(''));
      expect(Serializers.string.fromJson(0), equals('')); // Special case
      
      // Numeric values should convert to strings
      expect(Serializers.string.fromJson(123), equals('123'));
      expect(Serializers.string.fromJson(-456), equals('-456'));
      expect(Serializers.string.fromJson(3.14159), equals('3.14159'));
      
      // Boolean values should convert to strings  
      expect(Serializers.string.fromJson(true), equals('true'));
      expect(Serializers.string.fromJson(false), equals('false'));
      
      // Null should convert to string
      expect(Serializers.string.fromJson(null), equals('null'));
    });

    test('consistency with other serializers', () {
      // Test interaction with the serialization system
      
      // Empty string should be considered default
      final emptyBytes = Serializers.string.toBytes('');
      final nonEmptyBytes = Serializers.string.toBytes('hello');
      expect(emptyBytes.length, lessThan(nonEmptyBytes.length));
      
      // String serialization should be deterministic
      final testString = 'Hello, 世界! 🚀';
      final bytes1 = Serializers.string.toBytes(testString);
      final bytes2 = Serializers.string.toBytes(testString);
      expect(_bytesToHex(bytes1), equals(_bytesToHex(bytes2)));
      
      final json1 = Serializers.string.toJsonCode(testString);
      final json2 = Serializers.string.toJsonCode(testString);
      expect(json1, equals(json2));
    });
  });
}

/// Helper function to convert bytes to hex string
String _bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

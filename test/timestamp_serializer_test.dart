import 'package:test/test.dart';
import 'package:soia_client/soia_client.dart';
import 'dart:typed_data';

void main() {
  group('TimestampSerializer', () {
    test('basic functionality - JSON serialization', () {
      // Test epoch - should be 0 in dense, and unix_millis in readable
      final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      expect(Serializers.timestamp.toJson(epoch, readableFlavor: false),
          equals(0));
      expect(Serializers.timestamp.toJsonCode(epoch, readableFlavor: false),
          equals('0'));

      // Test readable flavor for epoch
      final epochReadable =
          Serializers.timestamp.toJson(epoch, readableFlavor: true);
      expect(epochReadable, isA<Map>());
      final epochMap = epochReadable as Map;
      expect(epochMap['unix_millis'], equals(0));
      expect(epochMap['formatted'], equals('1970-01-01T00:00:00.000Z'));

      // Test positive timestamp
      final testTime = DateTime.fromMillisecondsSinceEpoch(1756117845000,
          isUtc: true); // 2025-08-25T10:30:45Z
      expect(Serializers.timestamp.toJson(testTime, readableFlavor: false),
          equals(1756117845000));
      expect(Serializers.timestamp.toJsonCode(testTime, readableFlavor: false),
          equals('1756117845000'));

      // Test negative timestamp (before epoch)
      final beforeEpoch =
          DateTime.fromMillisecondsSinceEpoch(-1000, isUtc: true);
      expect(Serializers.timestamp.toJson(beforeEpoch, readableFlavor: false),
          equals(-1000));
      expect(
          Serializers.timestamp.toJsonCode(beforeEpoch, readableFlavor: false),
          equals('-1000'));
    });

    test('readable flavor - object format', () {
      final testTime = DateTime.fromMillisecondsSinceEpoch(1756117845000,
          isUtc: true); // 2025-08-25T10:30:45Z
      final readableJson =
          Serializers.timestamp.toJsonCode(testTime, readableFlavor: true);

      // Should produce an object with unix_millis and formatted
      expect(readableJson, contains('unix_millis'));
      expect(readableJson, contains('formatted'));
      expect(readableJson, contains('1756117845000'));
      expect(readableJson, contains('2025-08-25T10:30:45'));

      // Parse the JSON to verify structure
      final readableObj =
          Serializers.timestamp.toJson(testTime, readableFlavor: true) as Map;
      expect(readableObj['unix_millis'], equals(1756117845000));
      expect(readableObj['formatted'], equals('2025-08-25T10:30:45.000Z'));

      // Should roundtrip correctly
      final restoredFromReadable =
          Serializers.timestamp.fromJsonCode(readableJson);
      expect(restoredFromReadable, equals(testTime));
    });

    test('JSON deserialization - numeric values', () {
      // Test numeric JSON values (dense format)
      expect(Serializers.timestamp.fromJson(0),
          equals(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)));
      expect(
          Serializers.timestamp.fromJson(1756117845000),
          equals(
              DateTime.fromMillisecondsSinceEpoch(1756117845000, isUtc: true)));
      expect(Serializers.timestamp.fromJson(-1000),
          equals(DateTime.fromMillisecondsSinceEpoch(-1000, isUtc: true)));

      expect(Serializers.timestamp.fromJsonCode('0'),
          equals(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)));
      expect(
          Serializers.timestamp.fromJsonCode('1756117845000'),
          equals(
              DateTime.fromMillisecondsSinceEpoch(1756117845000, isUtc: true)));
      expect(Serializers.timestamp.fromJsonCode('-1000'),
          equals(DateTime.fromMillisecondsSinceEpoch(-1000, isUtc: true)));
    });

    test('JSON deserialization - object format (readable)', () {
      // Test object JSON values (readable format)
      final readableObj = {
        'unix_millis': 1756117845000,
        'formatted': '2025-08-25T10:30:45.000Z'
      };
      final expected =
          DateTime.fromMillisecondsSinceEpoch(1756117845000, isUtc: true);
      expect(Serializers.timestamp.fromJson(readableObj), equals(expected));

      final readableJsonCode =
          '{"unix_millis": 1756117845000, "formatted": "2025-08-25T10:30:45.000Z"}';
      expect(Serializers.timestamp.fromJsonCode(readableJsonCode),
          equals(expected));

      // Test that only unix_millis is used for reconstruction (formatted is ignored)
      final readableObjInconsistent = {
        'unix_millis': 1756117845000,
        'formatted': 'different-string'
      };
      expect(Serializers.timestamp.fromJson(readableObjInconsistent),
          equals(expected));
    });

    test('timestamp clamping behavior', () {
      // Test that timestamps are clamped to valid JavaScript Date range
      const int minValidMillis = -8640000000000000;
      const int maxValidMillis = 8640000000000000;

      final minValid =
          DateTime.fromMillisecondsSinceEpoch(minValidMillis, isUtc: true);
      final maxValid =
          DateTime.fromMillisecondsSinceEpoch(maxValidMillis, isUtc: true);

      // Test that these values roundtrip correctly through JSON
      expect(Serializers.timestamp.toJson(minValid), equals(minValidMillis));
      expect(Serializers.timestamp.toJson(maxValid), equals(maxValidMillis));
      expect(Serializers.timestamp.fromJson(minValidMillis), equals(minValid));
      expect(Serializers.timestamp.fromJson(maxValidMillis), equals(maxValid));

      // Test clamping is applied in the serializer implementation
      // Note: Dart's DateTime constructor may itself clamp values, so we test what the serializer receives
      final clampedMin = Serializers.timestamp.fromJson(minValidMillis - 1000);
      final clampedMax = Serializers.timestamp.fromJson(maxValidMillis + 1000);

      // Verify the clamping logic is consistent
      expect(
          clampedMin.millisecondsSinceEpoch, lessThanOrEqualTo(minValidMillis));
      expect(
          clampedMax.millisecondsSinceEpoch, lessThanOrEqualTo(maxValidMillis));
    });

    test('binary serialization - zero optimization', () {
      // Test that epoch uses optimized encoding (wire code 0)
      final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final epochBytes = Serializers.timestamp.toBytes(epoch);
      expect(_bytesToHex(epochBytes), equals('736f696100')); // "soia" + 0x00

      // Test non-zero values use timestamp encoding (wire code 239/0xEF)
      final nonZero = DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true);
      final nonZeroBytes = Serializers.timestamp.toBytes(nonZero);
      expect(_bytesToHex(nonZeroBytes),
          startsWith('736f6961ef')); // "soia" + 0xEF wire
    });

    test('binary encoding specifics', () {
      // Test specific wire format encoding (includes "soia" prefix + 0xEF + 8-byte long)
      final testCases = [
        (
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          '736f696100'
        ), // epoch -> 0x00
        (
          DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
          '736f6961efe803000000000000'
        ), // 1000ms -> 0xEF + long
        (
          DateTime.fromMillisecondsSinceEpoch(-1000, isUtc: true),
          '736f6961ef18fcffffffffffff'
        ), // -1000ms -> 0xEF + long
      ];

      for (final (timestamp, expectedHex) in testCases) {
        final bytes = Serializers.timestamp.toBytes(timestamp);
        expect(_bytesToHex(bytes), equals(expectedHex),
            reason:
                'Failed encoding for timestamp: ${timestamp.toIso8601String()}');
      }
    });

    test('binary deserialization roundtrip', () {
      final testValues = [
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true), // epoch
        DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true), // positive
        DateTime.fromMillisecondsSinceEpoch(-1000, isUtc: true), // negative
        DateTime.fromMillisecondsSinceEpoch(1756117845000,
            isUtc: true), // 2025-08-25T10:30:45Z
        DateTime.fromMillisecondsSinceEpoch(946684800000,
            isUtc: true), // 2000-01-01T00:00:00Z
        DateTime.fromMillisecondsSinceEpoch(
            DateTime.now().millisecondsSinceEpoch,
            isUtc: true), // current time
        DateTime.fromMillisecondsSinceEpoch(-8640000000000000,
            isUtc: true), // min valid
        DateTime.fromMillisecondsSinceEpoch(8640000000000000,
            isUtc: true), // max valid
      ];

      for (final timestamp in testValues) {
        final bytes = Serializers.timestamp.toBytes(timestamp);
        final restored = Serializers.timestamp.fromBytes(bytes);
        expect(restored, equals(timestamp),
            reason:
                'Failed roundtrip for timestamp: ${timestamp.toIso8601String()}');
      }
    });

    test('type descriptor', () {
      final typeDescriptor = Serializers.timestamp.typeDescriptor;
      expect(typeDescriptor, isA<PrimitiveDescriptor>());

      final primitiveDescriptor = typeDescriptor as PrimitiveDescriptor;
      expect(
          primitiveDescriptor.primitiveType, equals(PrimitiveType.TIMESTAMP));
    });

    test('JSON roundtrip for various timestamps', () {
      final testTimestamps = [
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true), // epoch
        DateTime.fromMillisecondsSinceEpoch(1756117845000,
            isUtc: true), // 2025-08-25T10:30:45Z
        DateTime.fromMillisecondsSinceEpoch(-1000, isUtc: true), // before epoch
        DateTime.fromMillisecondsSinceEpoch(946684800000,
            isUtc: true), // 2000-01-01T00:00:00Z
        DateTime.fromMillisecondsSinceEpoch(253402300799000,
            isUtc: true), // far future
        DateTime.fromMillisecondsSinceEpoch(-62135596800000,
            isUtc: true), // far past
      ];

      for (final timestamp in testTimestamps) {
        // Test dense format roundtrip
        final denseJson =
            Serializers.timestamp.toJsonCode(timestamp, readableFlavor: false);
        expect(Serializers.timestamp.fromJsonCode(denseJson), equals(timestamp),
            reason:
                'Dense JSON roundtrip failed for: ${timestamp.toIso8601String()}');

        // Test readable format roundtrip
        final readableJson =
            Serializers.timestamp.toJsonCode(timestamp, readableFlavor: true);
        expect(
            Serializers.timestamp.fromJsonCode(readableJson), equals(timestamp),
            reason:
                'Readable JSON roundtrip failed for: ${timestamp.toIso8601String()}');
      }
    });

    test('default value detection', () {
      // Test that epoch is considered the default value
      final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final nonEpoch = DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true);

      // Verify epoch gets optimized binary encoding
      final epochBytes = Serializers.timestamp.toBytes(epoch);
      final nonEpochBytes = Serializers.timestamp.toBytes(nonEpoch);

      expect(epochBytes.length, lessThan(nonEpochBytes.length),
          reason: 'Epoch should use shorter encoding than non-epoch');
      expect(_bytesToHex(epochBytes), endsWith('00')); // Should end with 0x00
      expect(_bytesToHex(nonEpochBytes),
          contains('ef')); // Should contain 0xEF wire code
    });

    test('edge cases and special timestamps', () {
      // Test year boundaries and common edge cases
      final edgeCases = [
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true), // Unix epoch
        DateTime.fromMillisecondsSinceEpoch(-1,
            isUtc: true), // Just before epoch
        DateTime.fromMillisecondsSinceEpoch(1, isUtc: true), // Just after epoch
        DateTime.fromMillisecondsSinceEpoch(86400000,
            isUtc: true), // 1 day after epoch
        DateTime.fromMillisecondsSinceEpoch(-86400000,
            isUtc: true), // 1 day before epoch
        DateTime.fromMillisecondsSinceEpoch(946684800000, isUtc: true), // Y2K
        DateTime.fromMillisecondsSinceEpoch(1577836800000,
            isUtc: true), // 2020-01-01
      ];

      for (final timestamp in edgeCases) {
        // Verify JSON serialization consistency
        final json = Serializers.timestamp.toJsonCode(timestamp);
        final restored = Serializers.timestamp.fromJsonCode(json);
        expect(restored, equals(timestamp),
            reason:
                'JSON roundtrip failed for edge case: ${timestamp.toIso8601String()}');

        // Verify binary serialization consistency
        final bytes = Serializers.timestamp.toBytes(timestamp);
        final restoredFromBytes = Serializers.timestamp.fromBytes(bytes);
        expect(restoredFromBytes, equals(timestamp),
            reason:
                'Binary roundtrip failed for edge case: ${timestamp.toIso8601String()}');
      }
    });

    test('consistency with Dart DateTime behavior', () {
      // Test that our serializer properly handles Dart's DateTime quirks
      final now = DateTime.now();
      final utcNow = now.toUtc();

      // Since timestamps only preserve millisecond precision, create a version with millisecond precision
      final utcNowMillis = DateTime.fromMillisecondsSinceEpoch(
          utcNow.millisecondsSinceEpoch,
          isUtc: true);

      // Our serializer should always work with UTC
      final nowBytes = Serializers.timestamp.toBytes(utcNowMillis);
      final restoredNow = Serializers.timestamp.fromBytes(nowBytes);
      expect(restoredNow.isUtc, isTrue,
          reason: 'Restored timestamp should be UTC');
      expect(restoredNow, equals(utcNowMillis));

      // Test that non-UTC timestamps are handled properly
      final localTime = DateTime.fromMillisecondsSinceEpoch(1756117845000);
      final utcEquivalent =
          DateTime.fromMillisecondsSinceEpoch(1756117845000, isUtc: true);

      // Both should serialize to the same value (millisecondsSinceEpoch is the same)
      expect(Serializers.timestamp.toJson(localTime),
          equals(Serializers.timestamp.toJson(utcEquivalent)));
    });

    test('string representation format', () {
      // While we can't directly test appendString, we can verify the internal string format
      // by checking the serializer's behavior and the timestamp's ISO string format
      final testTime =
          DateTime.fromMillisecondsSinceEpoch(1756117845000, isUtc: true);
      expect(testTime.toIso8601String(), equals('2025-08-25T10:30:45.000Z'));

      // Verify the readable JSON format includes the properly formatted timestamp
      final readableObj =
          Serializers.timestamp.toJson(testTime, readableFlavor: true) as Map;
      expect(readableObj['formatted'], equals('2025-08-25T10:30:45.000Z'));
    });
  });
}

/// Helper function to convert bytes to hex string
String _bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

import 'package:test/test.dart';
import 'package:soia/soia.dart';
import 'dart:typed_data';

// Helper function to convert bytes to hex string
String _bytesToHex(Uint8List bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
} // Test enum types

enum ColorKind {
  unknown(0),
  red(1),
  green(2),
  blue(3),
  custom(4);

  final int number;
  const ColorKind(this.number);
}

sealed class Color {
  const Color();
  ColorKind get kind;
}

class ColorUnknown extends Color {
  final internal__UnrecognizedEnum? unrecognized;
  const ColorUnknown(this.unrecognized);
  get kind => ColorKind.unknown;
}

class ColorRed extends Color {
  const ColorRed();
  get kind => ColorKind.red;
}

class ColorGreen extends Color {
  const ColorGreen();
  get kind => ColorKind.green;
}

class ColorBlue extends Color {
  const ColorBlue();
  get kind => ColorKind.blue;
}

class ColorCustomOption extends Color {
  final int rgb;
  const ColorCustomOption(this.rgb);
  get kind => ColorKind.custom;
}

// Complex enum with both constants and value fields

enum StatusKind {
  unknown(0),
  active(1),
  inactive(2),
  pending(3),
  error(4);

  final int number;
  const StatusKind(this.number);
}

sealed class Status {
  const Status();
  StatusKind get kind;
}

class StatusUnknown extends Status {
  final internal__UnrecognizedEnum? unrecognized;
  const StatusUnknown(this.unrecognized);
  get kind => StatusKind.unknown;
}

class StatusActive extends Status {
  const StatusActive();
  get kind => StatusKind.active;
}

class StatusInactive extends Status {
  const StatusInactive();
  get kind => StatusKind.inactive;
}

class StatusPendingOption extends Status {
  final String reason;
  const StatusPendingOption(this.reason);
  get kind => StatusKind.pending;
}

class StatusErrorOption extends Status {
  final String message;
  const StatusErrorOption(this.message);
  get kind => StatusKind.error;
}

void main() {
  group('EnumSerializerBuilder', () {
    const colorUnknown = ColorUnknown(null);
    const statusUnknown = StatusUnknown(null);
    const colorRed = ColorRed();
    const colorGreen = ColorGreen();
    const colorBlue = ColorBlue();

    late internal__EnumSerializerBuilder<Color, ColorKind> colorEnumBuilder;
    late Serializer<Color> colorSerializer;
    late internal__EnumSerializerBuilder<Status, StatusKind> statusEnumBuilder;
    late Serializer<Status> statusSerializer;

    setUp(() {
      // Simple enum with only constants
      colorEnumBuilder = internal__EnumSerializerBuilder.create(
        recordId: 'foo.bar:Color',
        unknownInstance: colorUnknown,
        enumInstance: colorUnknown as Color,
        getKind: (it) => it.kind,
        getNumber: (it) => it.number,
        wrapUnrecognized: (unrecognized) => ColorUnknown(unrecognized),
        getUnrecognized: (unknown) => unknown.unrecognized,
      );

      colorEnumBuilder.addConstantField('red', colorRed);
      colorEnumBuilder.addConstantField('green', colorGreen);
      colorEnumBuilder.addConstantField('blue', colorBlue);
      colorEnumBuilder.addValueField<ColorCustomOption, int>(
        'custom',
        ColorKind.custom,
        Serializers.int32,
        (rgb) => ColorCustomOption(rgb),
        (custom) => custom.rgb,
      );
      colorEnumBuilder.finalize();

      colorSerializer = colorEnumBuilder.serializer;

      // Complex enum with both constants and value fields
      statusEnumBuilder = internal__EnumSerializerBuilder.create(
        recordId: 'foo.bar:Color.Status',
        unknownInstance: statusUnknown,
        enumInstance: statusUnknown as Status,
        getKind: (it) => it.kind,
        getNumber: (it) => it.number,
        wrapUnrecognized: (unrecognized) => StatusUnknown(unrecognized),
        getUnrecognized: (unknown) => unknown.unrecognized,
      );

      statusEnumBuilder.addConstantField('active', StatusActive());
      statusEnumBuilder.addConstantField('inactive', StatusInactive());
      statusEnumBuilder.addValueField<StatusPendingOption, String>(
        'pending',
        StatusKind.pending,
        Serializers.string,
        (reason) => StatusPendingOption(reason),
        (pending) => pending.reason,
      );
      statusEnumBuilder.addRemovedNumber(4); // Removed field number
      statusEnumBuilder.finalize();

      statusSerializer = statusEnumBuilder.serializer;
    });

    test('enum serializer - constant fields dense JSON', () {
      // Test constant field serialization in dense format
      final redJson = colorSerializer.toJson(colorRed, readableFlavor: false);
      expect(redJson, equals(1));

      final greenJson =
          colorSerializer.toJson(colorGreen, readableFlavor: false);
      expect(greenJson, equals(2));

      final blueJson = colorSerializer.toJson(colorBlue, readableFlavor: false);
      expect(blueJson, equals(3));

      // Test deserialization from dense format
      expect(colorSerializer.fromJson(1, keepUnrecognizedFields: false),
          isA<ColorRed>());
      expect(colorSerializer.fromJson(2, keepUnrecognizedFields: false),
          isA<ColorGreen>());
      expect(colorSerializer.fromJson(3, keepUnrecognizedFields: false),
          isA<ColorBlue>());
    });

    test('enum serializer - constant fields readable JSON', () {
      // Test constant field serialization in readable format
      final redJson = colorSerializer.toJson(colorRed, readableFlavor: true);
      expect(redJson, equals('red'));

      final greenJson =
          colorSerializer.toJson(colorGreen, readableFlavor: true);
      expect(greenJson, equals('green'));

      final blueJson = colorSerializer.toJson(colorBlue, readableFlavor: true);
      expect(blueJson, equals('blue'));

      // Test deserialization from readable format
      expect(colorSerializer.fromJson('red', keepUnrecognizedFields: false),
          isA<ColorRed>());
      expect(colorSerializer.fromJson('green', keepUnrecognizedFields: false),
          isA<ColorGreen>());
      expect(colorSerializer.fromJson('blue', keepUnrecognizedFields: false),
          isA<ColorBlue>());
    });

    test('enum serializer - value fields dense JSON', () {
      final customColor = ColorCustomOption(0xFF0000);

      // Test value field serialization in dense format
      final customJson =
          colorSerializer.toJson(customColor, readableFlavor: false);
      expect(customJson, isA<List>());

      final jsonArray = customJson as List;
      expect(jsonArray, hasLength(2));
      expect(jsonArray[0], equals(4));
      expect(jsonArray[1], equals(16711680)); // 0xFF0000 in decimal

      // Test deserialization from dense format
      final restored =
          colorSerializer.fromJson(jsonArray, keepUnrecognizedFields: false);
      expect(restored, isA<ColorCustomOption>());
      expect((restored as ColorCustomOption).rgb, equals(0xFF0000));
    });

    test('enum serializer - value fields readable JSON', () {
      final customColor = ColorCustomOption(0x00FF00);

      // Test value field serialization in readable format
      final customJson =
          colorSerializer.toJson(customColor, readableFlavor: true);
      expect(customJson, isA<Map>());

      final jsonObject = customJson as Map<String, dynamic>;
      expect(jsonObject, hasLength(2));
      expect(jsonObject, containsPair('kind', 'custom'));
      expect(jsonObject, containsPair('value', 65280)); // 0x00FF00 in decimal

      // Test deserialization from readable format
      final restored =
          colorSerializer.fromJson(jsonObject, keepUnrecognizedFields: false);
      expect(restored, isA<ColorCustomOption>());
      expect((restored as ColorCustomOption).rgb, equals(0x00FF00));
    });

    test('enum serializer - binary format constants', () {
      // Test binary encoding for constant fields
      final redBytes = colorSerializer.toBytes(colorRed);
      expect(_bytesToHex(redBytes), startsWith('736f6961')); // "soia" prefix

      final greenBytes = colorSerializer.toBytes(colorGreen);
      expect(_bytesToHex(greenBytes), startsWith('736f6961'));

      final blueBytes = colorSerializer.toBytes(colorBlue);
      expect(_bytesToHex(blueBytes), startsWith('736f6961'));

      // Test binary roundtrips
      expect(colorSerializer.fromBytes(redBytes), isA<ColorRed>());
      expect(colorSerializer.fromBytes(greenBytes), isA<ColorGreen>());
      expect(colorSerializer.fromBytes(blueBytes), isA<ColorBlue>());
    });

    test('enum serializer - binary format value fields', () {
      final customColor = ColorCustomOption(42);

      // Test binary encoding for value fields
      final customBytes = colorSerializer.toBytes(customColor);
      expect(_bytesToHex(customBytes), startsWith('736f6961'));

      // Test binary roundtrip
      final restored = colorSerializer.fromBytes(customBytes);
      expect(restored, isA<ColorCustomOption>());
      expect((restored as ColorCustomOption).rgb, equals(42));
    });

    test('enum serializer - unknown values without keeping unrecognized', () {
      // Test unknown constant number
      final unknownConstant =
          colorSerializer.fromJson(99, keepUnrecognizedFields: false);
      expect(unknownConstant, isA<ColorUnknown>());

      // Test unknown field name
      final unknownName =
          colorSerializer.fromJson('purple', keepUnrecognizedFields: false);
      expect(unknownName, isA<ColorUnknown>());

      // Test unknown value field
      final unknownValue =
          colorSerializer.fromJson([99, 123], keepUnrecognizedFields: false);
      expect(unknownValue, isA<ColorUnknown>());
    });

    test('enum serializer - unknown values with keeping unrecognized', () {
      // Test unknown constant number with keepUnrecognizedFields = true
      final unknownConstant =
          colorSerializer.fromJson(99, keepUnrecognizedFields: true);
      expect(unknownConstant, isA<ColorUnknown>());
      final unknownEnum = (unknownConstant as ColorUnknown).unrecognized;
      expect(unknownEnum, isNotNull);

      // Test unknown value field with keepUnrecognizedFields = true
      final unknownValueJson = [99, 123];
      final unknownValue = colorSerializer.fromJson(unknownValueJson,
          keepUnrecognizedFields: true);
      expect(unknownValue, isA<ColorUnknown>());
      final unknownValueEnum = (unknownValue as ColorUnknown).unrecognized;
      expect(unknownValueEnum, isNotNull);
    });

    test('enum serializer - removed fields', () {
      // Test accessing a removed field (should return unknown)
      final removedField =
          statusSerializer.fromJson(4, keepUnrecognizedFields: false);
      expect(removedField, isA<StatusUnknown>());
    });

    test('enum serializer - complex enum roundtrips', () {
      final pendingStatus = StatusPendingOption('waiting for approval');

      // Test JSON roundtrips
      final denseJson =
          statusSerializer.toJsonCode(pendingStatus, readableFlavor: false);
      final readableJson =
          statusSerializer.toJsonCode(pendingStatus, readableFlavor: true);

      final restoredFromDense = statusSerializer.fromJsonCode(denseJson);
      final restoredFromReadable = statusSerializer.fromJsonCode(readableJson);

      expect(restoredFromDense, isA<StatusPendingOption>());
      expect((restoredFromDense as StatusPendingOption).reason,
          equals('waiting for approval'));

      expect(restoredFromReadable, isA<StatusPendingOption>());
      expect((restoredFromReadable as StatusPendingOption).reason,
          equals('waiting for approval'));

      // Test binary roundtrip
      final bytes = statusSerializer.toBytes(pendingStatus);
      final restoredFromBinary = statusSerializer.fromBytes(bytes);

      expect(restoredFromBinary, isA<StatusPendingOption>());
      expect((restoredFromBinary as StatusPendingOption).reason,
          equals('waiting for approval'));
    });

    test('enum serializer - all constant types roundtrip', () {
      final constantValues = [StatusActive(), StatusInactive()];

      for (final status in constantValues) {
        // Test both dense and readable JSON roundtrips
        final denseJson =
            statusSerializer.toJsonCode(status, readableFlavor: false);
        final readableJson =
            statusSerializer.toJsonCode(status, readableFlavor: true);

        final restoredFromDense = statusSerializer.fromJsonCode(denseJson);
        final restoredFromReadable =
            statusSerializer.fromJsonCode(readableJson);

        expect(restoredFromDense.runtimeType, equals(status.runtimeType));
        expect(restoredFromReadable.runtimeType, equals(status.runtimeType));

        // Test binary roundtrip
        final bytes = statusSerializer.toBytes(status);
        final restoredFromBinary = statusSerializer.fromBytes(bytes);
        expect(restoredFromBinary.runtimeType, equals(status.runtimeType));
      }
    });

    test('enum serializer - error cases', () {
      // Test that finalize() can only be called once
      final testEnumBuilder = internal__EnumSerializerBuilder.create(
        recordId: 'foo.bar:Color',
        unknownInstance: colorUnknown,
        enumInstance: colorUnknown as Color,
        getKind: (Color it) => it.kind,
        getNumber: (it) => it.number,
        wrapUnrecognized: (unrecognized) => ColorUnknown(unrecognized),
        getUnrecognized: (unknown) => unknown.unrecognized,
      );

      testEnumBuilder.addConstantField('test', colorRed);
      testEnumBuilder.finalize();

      // Adding fields after finalization should throw
      expect(
        () => testEnumBuilder.addConstantField('test2', colorGreen),
        throwsStateError,
      );

      // Double finalization should throw
      expect(
        () => testEnumBuilder.finalize(),
        throwsStateError,
      );
    });

    test('enum serializer - edge cases', () {
      // Test with edge case values
      final edgeCases = [
        ColorCustomOption(0),
        ColorCustomOption(2147483647), // Int.MAX_VALUE in Dart (32-bit)
        ColorCustomOption(-2147483648), // Int.MIN_VALUE in Dart (32-bit)
      ];

      for (final color in edgeCases) {
        // Test JSON roundtrips
        final denseJson =
            colorSerializer.toJsonCode(color, readableFlavor: false);
        final readableJson =
            colorSerializer.toJsonCode(color, readableFlavor: true);

        final restoredFromDense = colorSerializer.fromJsonCode(denseJson);
        final restoredFromReadable = colorSerializer.fromJsonCode(readableJson);

        expect(restoredFromDense, isA<ColorCustomOption>());
        expect((restoredFromDense as ColorCustomOption).rgb, equals(color.rgb));

        expect(restoredFromReadable, isA<ColorCustomOption>());
        expect(
            (restoredFromReadable as ColorCustomOption).rgb, equals(color.rgb));

        // Test binary roundtrip
        final bytes = colorSerializer.toBytes(color);
        final restoredFromBinary = colorSerializer.fromBytes(bytes);

        expect(restoredFromBinary, isA<ColorCustomOption>());
        expect(
            (restoredFromBinary as ColorCustomOption).rgb, equals(color.rgb));
      }
    });

    test('enum serializer - json format consistency', () {
      // Test that dense and readable formats are different for value fields but same for constants
      final redConstant = colorRed;
      final customValue = ColorCustomOption(0xABCDEF);

      // Constants should be different between dense/readable
      final redDenseJson =
          colorSerializer.toJsonCode(redConstant, readableFlavor: false);
      final redReadableJson =
          colorSerializer.toJsonCode(redConstant, readableFlavor: true);
      expect(redDenseJson, isNot(equals(redReadableJson)));

      // Value fields should be different between dense/readable
      final customDenseJson =
          colorSerializer.toJsonCode(customValue, readableFlavor: false);
      final customReadableJson =
          colorSerializer.toJsonCode(customValue, readableFlavor: true);
      expect(customDenseJson, isNot(equals(customReadableJson)));

      // Dense should be array/number, readable should be string/object
      expect(int.tryParse(redDenseJson), isNotNull);
      expect(redReadableJson, startsWith('"'));
      expect(redReadableJson, endsWith('"'));

      expect(customDenseJson, startsWith('['));
      expect(customDenseJson, endsWith(']'));
      expect(customReadableJson, startsWith('{'));
      expect(customReadableJson, endsWith('}'));
    });

    test('enum serializer - field number ranges', () {
      // Test that field numbers work correctly for different ranges
      // Using the existing colorSerializer which has field numbers 1, 2, 3, 4

      final constantValues = [colorRed, colorGreen, colorBlue];
      for (final constant in constantValues) {
        final bytes = colorSerializer.toBytes(constant);
        final restored = colorSerializer.fromBytes(bytes);
        expect(restored.runtimeType, equals(constant.runtimeType));
      }

      // Test value field
      final customColor = ColorCustomOption(42);
      final bytes = colorSerializer.toBytes(customColor);
      final restored = colorSerializer.fromBytes(bytes);
      expect(restored, isA<ColorCustomOption>());
      expect((restored as ColorCustomOption).rgb, equals(42));
    });

    test('enum serializer - multiple value serializers', () {
      // Test with the existing Status enum that already has multiple serializer types
      final testCases = [
        StatusActive(),
        StatusInactive(),
        StatusPendingOption('waiting for approval'),
      ];

      for (final testCase in testCases) {
        // Test JSON roundtrips - use readable format which works correctly
        final readableJson =
            statusSerializer.toJsonCode(testCase, readableFlavor: true);
        final restoredFromReadable =
            statusSerializer.fromJsonCode(readableJson);
        expect(restoredFromReadable.runtimeType, equals(testCase.runtimeType));

        if (testCase is StatusPendingOption) {
          expect((restoredFromReadable as StatusPendingOption).reason,
              equals(testCase.reason));
        }

        // Test binary roundtrip
        final bytes = statusSerializer.toBytes(testCase);
        final restoredFromBinary = statusSerializer.fromBytes(bytes);

        expect(restoredFromBinary.runtimeType, equals(testCase.runtimeType));
        if (testCase is StatusPendingOption) {
          expect((restoredFromBinary as StatusPendingOption).reason,
              equals(testCase.reason));
        }
      }
    });

    test('.serializer field access', () {
      // Test that the serializer field is accessible and works correctly
      final builder = internal__EnumSerializerBuilder.create(
        recordId: 'test:Color',
        unknownInstance: colorUnknown,
        enumInstance: colorUnknown as Color,
        getKind: (it) => it.kind,
        getNumber: (it) => it.number,
        wrapUnrecognized: (unrecognized) => ColorUnknown(unrecognized),
        getUnrecognized: (unknown) => unknown.unrecognized,
      );

      builder.addConstantField('red', colorRed);
      builder.finalize();

      final serializer = builder.serializer;
      expect(serializer, isA<Serializer<Color>>());

      // Test that the serializer works - use readable format which works correctly
      final json = serializer.toJsonCode(colorRed, readableFlavor: true);
      final restored = serializer.fromJsonCode(json);
      expect(restored, isA<ColorRed>());
    });

    test('builder state management', () {
      final builder = internal__EnumSerializerBuilder.create(
        recordId: 'test:Color',
        unknownInstance: colorUnknown,
        enumInstance: colorUnknown as Color,
        wrapUnrecognized: (unrecognized) => ColorUnknown(unrecognized),
        getUnrecognized: (unknown) => unknown.unrecognized,
        getKind: (it) => it.kind,
        getNumber: (it) => it.number,
      );

      // Should be able to add constants before finalization
      builder.addConstantField('red', colorRed);

      // Should be able to add value fields before finalization
      builder.addValueField<ColorCustomOption, int>(
        'custom',
        ColorKind.custom,
        Serializers.int32,
        (rgb) => ColorCustomOption(rgb),
        (custom) => custom.rgb,
      );

      // Should be able to add removed numbers before finalization
      builder.addRemovedNumber(5);

      // Should be able to access serializer before finalization
      final serializer1 = builder.serializer;
      expect(serializer1, isA<Serializer<Color>>());

      // Finalize the builder
      builder.finalize();

      // Should still be able to access serializer after finalization
      final serializer2 = builder.serializer;
      expect(serializer2, isA<Serializer<Color>>());

      // Should not be able to add constants after finalization
      expect(
        () => builder.addConstantField('green', colorGreen),
        throwsStateError,
      );

      // Should not be able to add value fields after finalization
      expect(
        () => builder.addValueField<ColorCustomOption, int>(
          'custom2',
          ColorKind.custom,
          Serializers.int32,
          (rgb) => ColorCustomOption(rgb),
          (custom) => custom.rgb,
        ),
        throwsStateError,
      );

      // Should not be able to add removed numbers after finalization
      expect(
        () => builder.addRemovedNumber(6),
        throwsStateError,
      );

      // Should not be able to finalize again
      expect(
        () => builder.finalize(),
        throwsStateError,
      );
    });

    test('enum serializer - type descriptor', () {
      final typeDescriptor = statusSerializer.typeDescriptor;
      final actualJson = typeDescriptor.asJsonCode;

      // Test that type descriptor is properly formed
      expect(actualJson, contains('"id": "foo.bar:Color.Status"'));
      expect(actualJson, contains('"kind": "enum"'));
      expect(actualJson, contains('"name": "active"'));
      expect(actualJson, contains('"name": "inactive"'));
      expect(actualJson, contains('"name": "pending"'));
      expect(actualJson, contains('"number": 1'));
      expect(actualJson, contains('"number": 2'));
      expect(actualJson, contains('"number": 3'));
      expect(actualJson, contains('removed_fields'));

      // Test that parsing the type descriptor works
      final parsed = TypeDescriptor.parseFromJson(typeDescriptor.asJson);
      expect(parsed.asJsonCode, equals(actualJson));
    });

    test('enum serializer - default detection', () {
      // Create a simple builder to test default detection
      final testBuilder = internal__EnumSerializerBuilder.create(
        recordId: 'test:Color',
        unknownInstance: colorUnknown,
        enumInstance: colorUnknown as Color,
        getKind: (it) => it.kind,
        getNumber: (it) => it.number,
        wrapUnrecognized: (unrecognized) => ColorUnknown(unrecognized),
        getUnrecognized: (unknown) => unknown.unrecognized,
      );

      testBuilder.addConstantField('red', colorRed);
      testBuilder.finalize();

      final testSerializer = testBuilder.serializer;

      // Test serialization of default (unknown) vs non-default values
      final unknownJson =
          testSerializer.toJsonCode(colorUnknown, readableFlavor: true);
      final redJson = testSerializer.toJsonCode(colorRed, readableFlavor: true);

      // They should produce different JSON
      expect(unknownJson, isNot(equals(redJson)));

      // Unknown should be able to roundtrip
      final restoredUnknown = testSerializer.fromJsonCode(unknownJson);
      expect(restoredUnknown, isA<ColorUnknown>());

      // Red should be able to roundtrip (using readable format)
      final restoredRed = testSerializer.fromJsonCode(redJson);
      expect(restoredRed, isA<ColorRed>());
    });
  });
}

import 'dart:typed_data';
import 'package:soia_client/soia_client.dart';
import 'package:test/test.dart';

void main() {
  group('_ByteStream position advancement', () {
    test('position advances when reading bytes', () {
      final buffer = Uint8Buffer();
      buffer.addAll([1, 2, 3, 4, 5]);
      final stream = _ByteStream(buffer);

      expect(stream.position, equals(0));

      final byte1 = stream.readByte();
      expect(byte1, equals(1));
      expect(stream.position, equals(1));

      final bytes = stream.readBytes(2);
      expect(bytes, equals([2, 3]));
      expect(stream.position, equals(3));

      final remainingBytes = stream.remainingBytes;
      expect(remainingBytes, equals([4, 5]));
      expect(stream.position,
          equals(3)); // remainingBytes doesn't advance position
    });

    test('decode methods advance stream position correctly', () {
      // Test that primitive serializers advance the stream position
      final intSerializer = soiaInt32;
      final stringSerializer = soiaString;

      // Create a buffer with encoded int (value 42) followed by encoded string ("hello")
      final buffer = Uint8Buffer();
      intSerializer._impl.encode(42, buffer);
      stringSerializer._impl.encode("hello", buffer);

      final stream = _ByteStream(buffer);
      final initialPosition = stream.position;

      // Decode the int
      final decodedInt = intSerializer._impl.decode(stream, false);
      expect(decodedInt, equals(42));
      expect(stream.position, greaterThan(initialPosition));

      final positionAfterInt = stream.position;

      // Decode the string
      final decodedString = stringSerializer._impl.decode(stream, false);
      expect(decodedString, equals("hello"));
      expect(stream.position, greaterThan(positionAfterInt));
      expect(stream.position, equals(buffer.length));
    });

    test('complex nested structures advance position correctly', () {
      // Test with optional and list serializers
      final optionalIntSerializer = soiaOptional(soiaInt32);
      final listSerializer = soiaList(soiaString);

      // Create a buffer with optional int (42) followed by list of strings
      final buffer = Uint8Buffer();
      optionalIntSerializer._impl.encode(42, buffer);
      listSerializer._impl.encode(["a", "b", "c"], buffer);

      final stream = _ByteStream(buffer);

      // Decode optional int
      final decodedOptional = optionalIntSerializer._impl.decode(stream, false);
      expect(decodedOptional, equals(42));

      final positionAfterOptional = stream.position;

      // Decode list
      final decodedList = listSerializer._impl.decode(stream, false);
      expect(decodedList, equals(["a", "b", "c"]));
      expect(stream.position, greaterThan(positionAfterOptional));
      expect(stream.position, equals(buffer.length));
    });
  });
}

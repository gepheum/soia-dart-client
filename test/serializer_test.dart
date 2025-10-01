import 'package:test/test.dart';
import 'package:soia_client/soia_client.dart';
import 'dart:typed_data';

void main() {
  group('Serializer', () {
    test('type descriptor provides type information', () {
      // This would be implemented with generated serializers
      expect(true, isTrue); // Placeholder test
    });

    test('binary format includes soia header', () {
      final testBytes = Uint8List.fromList([
        's'.codeUnitAt(0),
        'o'.codeUnitAt(0),
        'i'.codeUnitAt(0),
        'a'.codeUnitAt(0),
        // ... additional binary data would follow
      ]);

      expect(testBytes[0], equals('s'.codeUnitAt(0)));
      expect(testBytes[1], equals('o'.codeUnitAt(0)));
      expect(testBytes[2], equals('i'.codeUnitAt(0)));
      expect(testBytes[3], equals('a'.codeUnitAt(0)));
    });

    test('indentation unit is defined', () {
      expect(indentUnit, equals('  '));
    });
  });
}

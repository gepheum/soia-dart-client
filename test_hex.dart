import 'package:convert/convert.dart';

void main() {
  try {
    print('hex type: ${hex.runtimeType}');
    var encoded = hex.encode([72, 101, 108, 108, 111]);
    print('encoded: $encoded');
    var decoded = hex.decode(encoded);
    print('decoded: $decoded');
  } catch (e) {
    print('Error: $e');
  }
}

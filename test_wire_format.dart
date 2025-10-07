import "lib/soia_client.dart";
import "dart:typed_data";

void main() {
  final serializer = Serializers.iterable(Serializers.int32);

  final empty = <int>[];
  final single = [42];
  final double = [1, 2];
  final triple = [10, 20, 30];
  final large = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

  String toHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, "0")).join();
  }

  print("=== Encoding ===");
  print("Empty (0 elements): ${toHex(serializer.toBytes(empty))}");
  print("Single (1 element): ${toHex(serializer.toBytes(single))}");
  print("Double (2 elements): ${toHex(serializer.toBytes(double))}");
  print("Triple (3 elements): ${toHex(serializer.toBytes(triple))}");
  print("Large (10 elements): ${toHex(serializer.toBytes(large))}");

  print("\n=== Roundtrip Test ===");
  final testCases = [empty, single, double, triple, large];
  for (final testCase in testCases) {
    final bytes = serializer.toBytes(testCase);
    final decoded = serializer.fromBytes(bytes);
    final match = testCase.toString() == decoded.toString();
    print("${testCase} -> ${decoded} (${match ? 'OK' : 'FAIL'})");
  }
}

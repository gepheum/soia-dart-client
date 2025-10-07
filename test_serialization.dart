import "lib/soia_client.dart";
import "dart:typed_data";

void main() {
  final serializer = Serializers.iterable(Serializers.int32);
  final keyedSerializer = Serializers.keyedIterable(
      Serializers.string, (String value) => value.length);

  final empty = <int>[];
  final single = [42];
  final multiple = [1, 2, 3];

  final words = ['hello', 'world', 'test', 'a'];
  final keyedWords = KeyedIterable.copy(words, (value) => value.length);

  String toHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, "0")).join();
  }

  print("=== Regular Iterable ===");
  print("Empty: ${toHex(serializer.toBytes(empty))}");
  print("Single: ${toHex(serializer.toBytes(single))}");
  print("Multiple: ${toHex(serializer.toBytes(multiple))}");

  print("Empty JSON: ${serializer.toJsonCode(empty)}");
  print("Single JSON: ${serializer.toJsonCode(single)}");
  print("Multiple JSON: ${serializer.toJsonCode(multiple)}");

  print(
      "Empty JSON (readable): ${serializer.toJsonCode(empty, readableFlavor: true)}");
  print(
      "Single JSON (readable): ${serializer.toJsonCode(single, readableFlavor: true)}");
  print(
      "Multiple JSON (readable): ${serializer.toJsonCode(multiple, readableFlavor: true)}");

  print("\n=== Keyed Iterable ===");
  print("Words: ${toHex(keyedSerializer.toBytes(keyedWords))}");
  print("Words JSON: ${keyedSerializer.toJsonCode(keyedWords)}");
  print(
      "Words JSON (readable): ${keyedSerializer.toJsonCode(keyedWords, readableFlavor: true)}");

  print("\n=== Key Lookup ===");
  print("Length 5: ${keyedWords.findByKey(5)}");
  print("Length 4: ${keyedWords.findByKey(4)}");
  print("Length 1: ${keyedWords.findByKey(1)}");
  print("Length 10: ${keyedWords.findByKey(10)}");

  print("\n=== Immutability Test ===");
  final original = KeyedIterable.copy([1, 2, 3], (value) => value.toString());
  final copy = KeyedIterable.copy(original, (value) => value.toString());
  print("Same instance: ${identical(original, copy)}");
}

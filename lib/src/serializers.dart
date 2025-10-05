part of "../soia_client.dart";

/// Provides predefined serializers for all primitive types and utilities for creating
/// composite serializers such as optional and list serializers.
///
/// This class serves as the main entry point for accessing serializers for basic types
/// like integers, strings, timestamps, etc., as well as for constructing more complex
/// serializers for optional values and collections.
class Serializers {
  Serializers._() {}

  /// Serializer for 32-bit signed integers.
  static final Serializer<int> int32 = Serializer._(_Int32Serializer());

  /// Serializer for 64-bit signed integers.
  static final Serializer<int> int64 = Serializer._(_Int64Serializer());

  /// Serializer for 64-bit unsigned integers.
  static final Serializer<int> uint64 = Serializer._(Uint64Serializer());

  /// Serializer for 32-bit floating-point numbers.
  static final Serializer<double> float32 = Serializer._(_Float32Serializer());

  /// Serializer for 64-bit floating-point numbers.
  static final Serializer<double> float64 = Serializer._(_Float64Serializer());

  /// Serializer for UTF-8 strings.
  static final Serializer<String> string = Serializer._(_StringSerializer());

  /// Serializer for binary data (byte arrays).
  static final Serializer<Uint8List> bytes = Serializer._(_BytesSerializer());

  /// Serializer for timestamp values.
  static final Serializer<DateTime> timestamp =
      Serializer._(_TimestampSerializer());

  /// Serializer for Boolean values.
  static final bool = Serializer._(_BoolSerializer());

  /// Creates a serializer for optional values of type [T].
  ///
  /// [other] The serializer for the wrapped type
  /// Returns a serializer that can handle null values of the given type
  static Serializer<T?> optional<T>(Serializer<T> other) {
    final otherImpl = other._impl;
    if (otherImpl is _OptionalSerializer<T>) {
      return other as Serializer<T?>;
    } else {
      return Serializer._(_OptionalSerializer<T>(otherImpl));
    }
  }

  /// Creates a serializer for lists of elements of type [E].
  ///
  /// [item] The serializer for individual list elements
  /// Returns a serializer that can handle lists of the given element type
  static Serializer<List<E>> list<E>(Serializer<E> item) {
    const getKeySpec = "";
    return Serializer._(_ListSerializer<E>(item._impl, getKeySpec));
  }
}

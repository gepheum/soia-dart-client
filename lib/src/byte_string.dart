part of "../soia.dart";

/// An immutable array of bytes.
class ByteString {
  final Uint8List _uint8List;

  /// An empty byte string.
  static final ByteString empty = ByteString._(Uint8List(0));

  /// Private constructor to ensure immutability.
  const ByteString._(this._uint8List);

  factory ByteString._wrap(Uint8List list) =>
      list.isEmpty ? ByteString.empty : ByteString._(list);

  factory ByteString.copy(List<int> list) =>
      ByteString._wrap(Uint8List.fromList(list));

  factory ByteString.copySlice(TypedData data, [int start = 0, int? end]) =>
      ByteString._wrap(Uint8List.sublistView(data, start, end).sublist(0));

  /// Decodes a Base64 string, which can be obtained by calling [toBase64].
  ///
  /// Throws [FormatException] if the given string is not a valid Base64 string.
  /// See https://en.wikipedia.org/wiki/Base64
  factory ByteString.fromBase64(String base64) =>
      ByteString._wrap(base64Decode(base64));

  /// Decodes a hexadecimal string, which can be obtained by calling [toBase16].
  ///
  /// Throws [FormatException] if the given string is not a valid hexadecimal string.
  factory ByteString.fromBase16(String base16) =>
      ByteString.copy(hex.decode(base16));

  Uint8List get asUnmodifiableList => _uint8List.asUnmodifiableView();

  int get length => _uint8List.length;
  bool get isEmpty => _uint8List.isEmpty;
  bool get isNotEmpty => _uint8List.isNotEmpty;

  ByteString substring(int start, [int? end]) {
    if (start == 0 && end == _uint8List.length) {
      return this;
    } else {
      return ByteString._wrap(_uint8List.sublist(start, end));
    }
  }

  /// Encodes this byte string into a Base64 string.
  ///
  /// See https://en.wikipedia.org/wiki/Base64
  String toBase64() => base64Encode(_uint8List);

  /// Encodes this byte string into a hexadecimal string.
  String toBase16() => hex.encode(_uint8List);

  @override
  String toString() {
    return 'ByteString.fromBase16("${toBase16()}")';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ByteString) return false;
    if (_uint8List.length != other._uint8List.length) return false;
    for (int i = 0; i < _uint8List.length; i++) {
      if (_uint8List[i] != other._uint8List[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    int hash = 0;
    for (int i = 0; i < _uint8List.length; i++) {
      hash = hash * 31 + _uint8List[i];
    }
    return hash + 3912107;
  }
}

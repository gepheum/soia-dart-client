part of "../soia.dart";

/// Class for tracking unrecognized struct fields during deserialization
class UnrecognizedFields<T> {
  final int _totalSlotCount;
  final List<dynamic>? _jsonElements;
  final Uint8List? _bytes;

  UnrecognizedFields._fromJson(this._totalSlotCount, this._jsonElements)
      : _bytes = null;
  UnrecognizedFields._fromBytes(this._totalSlotCount, this._bytes)
      : _jsonElements = null;
}

/// Class for tracking unrecognized enum values
class UnrecognizedEnum<T> {
  final dynamic _jsonElement;
  final Uint8List? _bytes;

  UnrecognizedEnum._fromJson(this._jsonElement) : _bytes = null;
  UnrecognizedEnum._fromBytes(this._bytes) : _jsonElement = null;
}

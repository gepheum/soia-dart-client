part of "../skir.dart";

class internal__UnrecognizedFields {
  final int _totalSlotCount;
  final List<dynamic>? _jsonElements;
  final Uint8List? _bytes;

  internal__UnrecognizedFields._fromJson(
    this._totalSlotCount,
    this._jsonElements,
  ) : _bytes = null;

  internal__UnrecognizedFields._fromBytes(this._totalSlotCount, this._bytes)
      : _jsonElements = null;
}

class internal__UnrecognizedEnum {
  final dynamic _jsonElement;
  final Uint8List? _bytes;

  internal__UnrecognizedEnum._fromJson(this._jsonElement) : _bytes = null;

  internal__UnrecognizedEnum._fromBytes(this._bytes) : _jsonElement = null;
}

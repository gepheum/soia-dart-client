import 'dart:typed_data';
import 'package:typed_data/typed_buffers.dart';
import '../type_descriptor.dart';

/// Internal implementation base class for serializers
abstract class SerializerImpl<T> {
  /// Checks if a value is the default value for this type
  bool isDefault(T value);

  /// Converts an object to its JSON representation
  dynamic toJson(T input, bool readableFlavor);

  /// Deserializes an object from its JSON representation
  T fromJson(dynamic json, bool keepUnrecognizedFields);

  /// Encodes an object to binary format
  void encode(T input, Uint8Buffer buffer);

  /// Decodes an object from binary format
  T decode(Uint8List buffer, bool keepUnrecognizedFields);

  /// Appends a string representation of the object to the output buffer
  void appendString(T input, StringBuffer out, String eolIndent);

  /// Gets the type descriptor for this serializer
  TypeDescriptor get typeDescriptor;

  /// Gets the type signature as a JSON element
  dynamic get typeSignature;

  /// Adds record definitions to the output map
  void addRecordDefinitionsTo(Map<String, dynamic> out);
}

/// Constant for indentation unit
const String indentUnit = '  ';

/// Helper function to create string representation of objects
String toStringImpl<T>(T input, SerializerImpl<T> serializer) {
  final stringBuffer = StringBuffer();
  serializer.appendString(input, stringBuffer, '\n');
  return stringBuffer.toString();
}

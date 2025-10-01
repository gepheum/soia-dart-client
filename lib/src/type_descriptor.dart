/// Base class for type descriptors
abstract class TypeDescriptor {
  const TypeDescriptor();
}

/// Reflective type descriptor that provides runtime type information
class ReflectiveTypeDescriptor extends TypeDescriptor {
  final String typeName;
  final List<FieldDescriptor> fields;
  final Map<String, dynamic> metadata;

  const ReflectiveTypeDescriptor({
    required this.typeName,
    required this.fields,
    this.metadata = const {},
  });
}

/// Descriptor for a field in a type
class FieldDescriptor {
  final String name;
  final TypeDescriptor type;
  final bool isOptional;
  final dynamic defaultValue;
  final Map<String, dynamic> metadata;

  const FieldDescriptor({
    required this.name,
    required this.type,
    this.isOptional = false,
    this.defaultValue,
    this.metadata = const {},
  });
}

/// Primitive type descriptors
class PrimitiveTypeDescriptor extends TypeDescriptor {
  final String typeName;

  const PrimitiveTypeDescriptor(this.typeName);

  static const string = PrimitiveTypeDescriptor('String');
  static const int = PrimitiveTypeDescriptor('int');
  static const double = PrimitiveTypeDescriptor('double');
  static const bool = PrimitiveTypeDescriptor('bool');
}

/// List type descriptor
class ListTypeDescriptor extends TypeDescriptor {
  final TypeDescriptor elementType;

  const ListTypeDescriptor(this.elementType);
}

/// Map type descriptor
class MapTypeDescriptor extends TypeDescriptor {
  final TypeDescriptor keyType;
  final TypeDescriptor valueType;

  const MapTypeDescriptor(this.keyType, this.valueType);
}

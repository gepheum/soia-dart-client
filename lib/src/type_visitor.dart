part of '../soia.dart';

/// 🪞 Visitor for performing type-specific reflective operations on Soia types.
///
/// Implement this interface to execute different logic based on whether a type
/// is a struct, enum, optional, array, or primitive. While you could achieve
/// the same using switch patterns on [ReflectiveTypeDescriptor], this visitor
/// provides type safety that's difficult to achieve manually.
///
/// For example, when visiting a [ReflectiveArrayDescriptor], the [visitArray]
/// method receives type parameter `E` representing the element type, allowing
/// the compiler to enforce type correctness throughout your implementation.
///
/// Usage: write your own implementations of this interface, which can possibly
/// extend [NoopReflectiveTypeVisitor], and pass it to methods such as
/// [ReflectiveTypeDescriptor.accept].
///
/// See a complete example at
/// https://github.com/gepheum/soia-dart-example/blob/main/lib/all_strings_to_upper_case.dart
abstract class ReflectiveTypeVisitor<T> {
  /// Visits a struct type.
  void visitStruct<Mutable>(
    ReflectiveStructDescriptor<T, Mutable> descriptor,
  );

  /// Visits an enum type.
  void visitEnum(
    ReflectiveEnumDescriptor<T> descriptor,
  );

  /// Visits an optional type (nullable type).
  void visitOptional<NotNull>(
    ReflectiveOptionalDescriptor<NotNull> descriptor,
    TypeEquivalence<T, NotNull?> equivalence,
  );

  /// Visits an array type.
  ///
  /// [equivalence] allows safe conversion between [T] and [Collection].
  void visitArray<E, Collection extends Iterable<E>>(
    ReflectiveArrayDescriptor<E, Collection> descriptor,
    TypeEquivalence<T, Collection> equivalence,
  );

  /// Visits a boolean primitive type.
  void visitBool(TypeEquivalence<T, bool> equivalence);

  /// Visits a 32-bit signed integer primitive type.
  void visitInt32(TypeEquivalence<T, int> equivalence);

  /// Visits a 64-bit signed integer primitive type.
  void visitInt64(TypeEquivalence<T, int> equivalence);

  /// Visits a 64-bit unsigned integer primitive type.
  void visitUint64(TypeEquivalence<T, BigInt> equivalence);

  /// Visits a 32-bit floating point primitive type.
  void visitFloat32(TypeEquivalence<T, double> equivalence);

  /// Visits a 64-bit floating point primitive type.
  void visitFloat64(TypeEquivalence<T, double> equivalence);

  /// Visits a timestamp primitive type.
  void visitTimestamp(TypeEquivalence<T, DateTime> equivalence);

  /// Visits a string primitive type.
  void visitString(TypeEquivalence<T, String> equivalence);

  /// Visits a bytes primitive type.
  void visitBytes(TypeEquivalence<T, ByteString> equivalence);
}

/// 🪞 A no-op implementation of [ReflectiveTypeVisitor] that does nothing for
/// each visit method.
///
/// This class is useful as a base class when you only need to override a few
/// specific visit methods while leaving the others as no-ops.
///
/// See a complete example at
/// https://github.com/gepheum/soia-dart-example/blob/main/lib/all_strings_to_upper_case.dart
class NoopReflectiveTypeVisitor<T> implements ReflectiveTypeVisitor<T> {
  @override
  void visitStruct<Mutable>(
    ReflectiveStructDescriptor<T, Mutable> descriptor,
  ) {}

  @override
  void visitEnum(ReflectiveEnumDescriptor<T> descriptor) {}

  @override
  void visitOptional<NotNull>(
    ReflectiveOptionalDescriptor<NotNull> descriptor,
    TypeEquivalence<T, NotNull?> equivalence,
  ) {}

  @override
  void visitArray<E, Collection extends Iterable<E>>(
    ReflectiveArrayDescriptor<E, Collection> descriptor,
    TypeEquivalence<T, Collection> equivalence,
  ) {}

  @override
  void visitBool(TypeEquivalence<T, bool> equivalence) {}

  @override
  void visitInt32(TypeEquivalence<T, int> equivalence) {}

  @override
  void visitInt64(TypeEquivalence<T, int> equivalence) {}

  @override
  void visitUint64(TypeEquivalence<T, BigInt> equivalence) {}

  @override
  void visitFloat32(TypeEquivalence<T, double> equivalence) {}

  @override
  void visitFloat64(TypeEquivalence<T, double> equivalence) {}

  @override
  void visitTimestamp(TypeEquivalence<T, DateTime> equivalence) {}

  @override
  void visitString(TypeEquivalence<T, String> equivalence) {}

  @override
  void visitBytes(TypeEquivalence<T, ByteString> equivalence) {}
}

void _acceptImpl<T>(
  ReflectiveTypeDescriptor<T> descriptor,
  ReflectiveTypeVisitor<T> visitor,
) {
  switch (descriptor) {
    case ReflectiveStructDescriptor<dynamic, dynamic>():
      visitor.visitStruct(
        descriptor as ReflectiveStructDescriptor<T, dynamic>,
      );
    case ReflectiveEnumDescriptor<dynamic>():
      visitor.visitEnum(
        descriptor as ReflectiveEnumDescriptor<T>,
      );
    case ReflectiveOptionalDescriptor<dynamic>():
      visitor.visitOptional(
        descriptor as ReflectiveOptionalDescriptor,
        TypeEquivalence<T, T>._(),
      );
    case ReflectiveArrayDescriptor<dynamic, Iterable<dynamic>>():
      _visitArrayImpl(
        descriptor as ReflectiveArrayDescriptor,
        visitor,
      );
    case BoolDescriptor():
      visitor.visitBool(TypeEquivalence<T, bool>._());
    case Int32Descriptor():
      visitor.visitInt32(TypeEquivalence<T, int>._());
    case Int64Descriptor():
      visitor.visitInt64(TypeEquivalence<T, int>._());
    case Uint64Descriptor():
      visitor.visitUint64(TypeEquivalence<T, BigInt>._());
    case Float32Descriptor():
      visitor.visitFloat32(TypeEquivalence<T, double>._());
    case Float64Descriptor():
      visitor.visitFloat64(TypeEquivalence<T, double>._());
    case TimestampDescriptor():
      visitor.visitTimestamp(TypeEquivalence<T, DateTime>._());
    case StringDescriptor():
      visitor.visitString(TypeEquivalence<T, String>._());
    case BytesDescriptor():
      visitor.visitBytes(TypeEquivalence<T, ByteString>._());
  }
}

void _visitArrayImpl<E, Collection extends Iterable<E>, T>(
  ReflectiveArrayDescriptor<E, Collection> descriptor,
  ReflectiveTypeVisitor<T> visitor,
) {
  visitor.visitArray(
    descriptor,
    TypeEquivalence<T, Collection>._(),
  );
}

/// 🪞 A witness that two types [T] and [U] are guaranteed to be identical at
/// runtime, even if Dart's static type checker sees them as different types.
///
/// Provides safe casting methods to make the static type checker happy.
class TypeEquivalence<T, U> {
  const TypeEquivalence._();

  /// Converts from type [U] to type [T].
  T toT(U u) => u as T;

  /// Converts from type [T] to type [U].
  U fromT(T t) => t as U;
}

/// 🪞 A function object that takes in a Soia value of any type and returns a
/// new value of the same type.
///
/// Usage: write your own implementations of this interface, and pass it to
/// methods such as [ReflectiveStructDescriptor.mapFields] to recursively
/// transform a Soia value.
///
/// See a complete example at
/// https://github.com/gepheum/soia-dart-example/blob/main/lib/all_strings_to_upper_case.dart
abstract class ReflectiveTransformer {
  /// Returns values unchanged.
  static const ReflectiveTransformer identity = _IdentityTransformer();

  /// Expects a Soia value of any type, returns a value of the same type.
  T transform<T>(T input, ReflectiveTypeDescriptor<T> descriptor);

  const ReflectiveTransformer();
}

class _IdentityTransformer extends ReflectiveTransformer {
  const _IdentityTransformer();

  @override
  T transform<T>(T input, ReflectiveTypeDescriptor<T> descriptor) {
    return input;
  }
}

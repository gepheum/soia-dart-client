part of '../soia.dart';

class TypeEquivalence<T, U> {
  const TypeEquivalence._();

  T toT(U u) => u as T;
  U fromT(T t) => t as U;
}

abstract class ReflectiveTypeVisitor<T> {
  void visitStruct<Mutable>(
    ReflectiveStructDescriptor<T, Mutable> descriptor,
  );

  void visitEnum(
    ReflectiveEnumDescriptor<T> descriptor,
  );

  void visitOptional<NotNull>(
    ReflectiveOptionalDescriptor<NotNull> descriptor,
    TypeEquivalence<T, NotNull?> equivalence,
  );

  void visitArray<E, Collection extends Iterable<E>>(
    ReflectiveArrayDescriptor<E, Collection> descriptor,
    TypeEquivalence<T, Collection> equivalence,
  );

  void visitBool(TypeEquivalence<T, bool> equivalence);
  void visitInt32(TypeEquivalence<T, int> equivalence);
  void visitInt64(TypeEquivalence<T, int> equivalence);
  void visitUint64(TypeEquivalence<T, BigInt> equivalence);
  void visitFloat32(TypeEquivalence<T, double> equivalence);
  void visitFloat64(TypeEquivalence<T, double> equivalence);
  void visitTimestamp(TypeEquivalence<T, DateTime> equivalence);
  void visitString(TypeEquivalence<T, String> equivalence);
  void visitBytes(TypeEquivalence<T, ByteString> equivalence);
}

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

abstract class ReflectiveTransformer {
  static const ReflectiveTransformer identity = _IdentityTransformer();

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

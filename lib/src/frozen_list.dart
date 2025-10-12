part of "../soia.dart";

sealed class _FrozenList<E> implements List<E> {}

class _FrozenListImpl<E> extends UnmodifiableListView<E>
    implements _FrozenList<E> {
  _FrozenListImpl(List<E> list) : super(list);
}

sealed class KeyedIterable<E, K> implements Iterable<E> {
  static const KeyedIterable<Never, Never> empty = _EmptyFrozenList();

  factory KeyedIterable.copy(Iterable<E> elements, K Function(E) getKey) {
    return internal__keyedCopy(elements, '', getKey);
  }

  E? findByKey(K key);
}

class _KeyedIterableImpl<E, K> extends UnmodifiableListView<E>
    implements KeyedIterable<E, K>, _FrozenList<E> {
  final String _getKeySpec;
  final K Function(E) _getKey;
  Map<K, E>? _mapView;

  _KeyedIterableImpl(List<E> list, this._getKeySpec, this._getKey)
      : super(list);

  @override
  E? findByKey(K key) {
    final mapView = (_mapView ??= {for (var e in this) _getKey(e): e});
    return mapView[key];
  }
}

class _EmptyFrozenList extends DelegatingList<Never>
    implements KeyedIterable<Never, Never>, _FrozenList<Never> {
  const _EmptyFrozenList() : super(const []);

  @override
  Never? findByKey(dynamic key) => null;
}

Iterable<E> internal__frozenCopy<E>(Iterable<E> elements) {
  if (elements is _FrozenList<E>) {
    return elements;
  } else {
    return _FrozenListImpl(elements.toList(growable: false));
  }
}

Iterable<E> internal__frozenMappedCopy<E extends M, M>(
    Iterable<M> elements, E Function(M) toFrozen) {
  if (elements is _FrozenList<E>) {
    return elements;
  } else {
    return _FrozenListImpl(elements.map(toFrozen).toList(growable: false));
  }
}

KeyedIterable<E, K> internal__keyedCopy<E, K>(
  Iterable<E> elements,
  String getKeySpec,
  K Function(E) getKey,
) {
  if (elements.isEmpty) {
    return KeyedIterable.empty;
  } else if (elements is _KeyedIterableImpl<E, K> &&
      elements._getKeySpec.isNotEmpty &&
      elements._getKeySpec == getKeySpec) {
    return elements;
  } else {
    return _KeyedIterableImpl(
      elements.toList(growable: false),
      getKeySpec,
      getKey,
    );
  }
}

KeyedIterable<E, K> internal__keyedMappedCopy<E extends M, K, M>(
  Iterable<M> elements,
  String getKeySpec,
  K Function(E) getKey,
  E Function(M) toFrozen,
) {
  if (elements.isEmpty) {
    return KeyedIterable.empty;
  } else if (elements is _KeyedIterableImpl<E, K> &&
      elements._getKeySpec.isNotEmpty &&
      elements._getKeySpec == getKeySpec) {
    return elements;
  } else {
    return _KeyedIterableImpl<E, K>(
      elements.map(toFrozen).toList(growable: false),
      getKeySpec,
      getKey,
    );
  }
}

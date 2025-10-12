part of "../soia.dart";

class _FrozenList<E> extends UnmodifiableListView<E> {
  _FrozenList(List<E> list) : super(list);
}

sealed class KeyedIterable<E, K> implements Iterable<E> {
  factory KeyedIterable.empty() => _EmptyFrozenList();

  factory KeyedIterable.copy(Iterable<E> elements, K Function(E) getKey) {
    return internal__keyedCopy(elements, '', getKey);
  }

  E? findByKey(K key);
}

class _KeyedIterableImpl<E, K> extends _FrozenList<E>
    implements KeyedIterable<E, K> {
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

class _EmptyFrozenList<E, K> extends _FrozenList<E>
    implements KeyedIterable<E, K> {
  _EmptyFrozenList() : super(List.empty(growable: false));

  @override
  E? findByKey(K key) => null;
}

Iterable<E> internal__frozenCopy<E>(Iterable<E> elements) {
  if (elements case final _FrozenList<E> frozenList) {
    return frozenList;
  } else {
    return _FrozenList(elements.toList(growable: false));
  }
}

Iterable<E> internal__frozenMappedCopy<E extends M, M>(
    Iterable<M> elements, E Function(M) toFrozen) {
  if (elements case final _FrozenList<E> frozenList) {
    return frozenList;
  } else {
    return _FrozenList(elements.map(toFrozen).toList(growable: false));
  }
}

KeyedIterable<E, K> internal__keyedCopy<E, K>(
  Iterable<E> elements,
  String getKeySpec,
  K Function(E) getKey,
) {
  if (elements case final _KeyedIterableImpl<E, K> keyedIterable) {
    if (keyedIterable._getKeySpec == getKeySpec &&
        keyedIterable._getKey == getKey) {
      return keyedIterable;
    }
  }
  return _KeyedIterableImpl<E, K>(
    elements.toList(growable: false),
    getKeySpec,
    getKey,
  );
}

KeyedIterable<E, K> internal__keyedMappedCopy<E extends M, K, M>(
  Iterable<M> elements,
  String getKeySpec,
  K Function(E) getKey,
  E Function(M) toFrozen,
) {
  if (elements case final _KeyedIterableImpl<E, K> keyedIterable) {
    if (keyedIterable._getKeySpec == getKeySpec &&
        keyedIterable._getKey == getKey) {
      return keyedIterable;
    }
  }
  return _KeyedIterableImpl<E, K>(
    elements.map(toFrozen).toList(growable: false),
    getKeySpec,
    getKey,
  );
}

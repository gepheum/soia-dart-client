part of "../soia.dart";

class _FrozenList<E> extends UnmodifiableListView<E> {
  _FrozenList(List<E> list) : super(list);
}

sealed class KeyedIterable<E, K> implements Iterable<E> {
  factory KeyedIterable.empty() => _EmptyFrozenList();

  factory KeyedIterable.copy(Iterable<E> elements, K Function(E) getKey) {
    return KeyedIterable.internal__copy(elements, '', (it) => it, getKey);
  }

  static KeyedIterable<E, K> internal__copy<E, K, M>(
    Iterable<M> elements,
    String getKeySpec,
    E Function(M) toFrozen,
    K Function(E) getKey,
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

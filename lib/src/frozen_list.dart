part of "../soia_client.dart";

class _FrozenList<E> extends UnmodifiableListView<E> {
  _FrozenList(List<E> list) : super(list);
}

sealed class KeyedIterable<E, K> implements Iterable<E> {
  factory KeyedIterable(List<E> elements, K Function(E) getKey) {
    return KeyedIterable.internalCreate(elements, '', (it) => it, getKey);
  }

  factory KeyedIterable.empty() {
    return _emptyFrozenList as KeyedIterable<E, K>;
  }

  static KeyedIterable<E, K> internalCreate<E, K, M>(List<M> elements,
      String getKeySpec, E Function(M) toFrozen, K Function(E) getKey) {
    if (elements is _KeyedIterableImpl &&
        (elements as _KeyedIterableImpl)._getKeySpec.isNotEmpty &&
        (elements as _KeyedIterableImpl)._getKey == getKey) {
      return elements as KeyedIterable<E, K>;
    } else {
      final result = _KeyedIterableImpl<E, K>(
        elements.map(toFrozen).toList(),
        getKeySpec,
        getKey,
      );
      return result.isEmpty ? KeyedIterable.empty() : result;
    }
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

class _EmptyFrozenList extends _FrozenList<dynamic>
    implements KeyedIterable<dynamic, dynamic> {
  _EmptyFrozenList() : super([]);

  @override
  dynamic findByKey(dynamic key) => null;
}

final _emptyFrozenList = _EmptyFrozenList();

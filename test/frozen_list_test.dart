import 'package:test/test.dart';
import 'package:soia_client/soia_client.dart';

void main() {
  group('KeyedIterable', () {
    group('factory constructors', () {
      test('empty() creates an empty keyed iterable', () {
        final empty = KeyedIterable.empty();

        expect(empty, isEmpty);
        expect(empty.length, equals(0));
        expect(empty.toList(), equals([]));
      });

      test('typed empty() creates an empty keyed iterable with proper types',
          () {
        final empty = KeyedIterable<String, int>.empty();

        expect(empty, isEmpty);
        expect(empty.length, equals(0));
        expect(empty.toList(), equals([]));
        expect(empty.findByKey(1), isNull);
      });

      test('copy() creates a keyed iterable from elements', () {
        final elements = ['apple', 'banana', 'cherry'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        expect(keyed.length, equals(3));
        expect(keyed.toList(), equals(['apple', 'banana', 'cherry']));
      });

      test('copy() with empty list creates empty keyed iterable', () {
        final keyed = KeyedIterable<String, int>.copy([], (e) => e.length);

        expect(keyed, isEmpty);
        expect(keyed.length, equals(0));
        expect(keyed.findByKey(1), isNull);
      });
    });

    group('findByKey', () {
      test('finds element by key', () {
        final elements = ['apple', 'banana', 'cherry'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        expect(keyed.findByKey(5), equals('apple'));
        expect(
            keyed.findByKey(6), equals('cherry')); // Last element with length 6
      });

      test('returns null for non-existent key', () {
        final elements = ['apple', 'banana'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        expect(keyed.findByKey(10), isNull);
        expect(keyed.findByKey(1), isNull);
      });

      test('typed empty keyed iterable returns null for any key', () {
        final empty = KeyedIterable<String, int>.empty();

        expect(empty.findByKey(1), isNull);
        expect(empty.findByKey(100), isNull);
      });

      test('untyped empty keyed iterable returns null for any key', () {
        final empty = KeyedIterable.empty();

        expect(empty.findByKey(1), isNull);
        expect(empty.findByKey(100), isNull);
        expect(empty.findByKey('test'), isNull);
      });

      test('caches map view for efficient lookups', () {
        final elements = ['a', 'bb', 'ccc', 'dddd'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        // First lookup should create the map
        expect(keyed.findByKey(2), equals('bb'));

        // Subsequent lookups should use cached map
        expect(keyed.findByKey(4), equals('dddd'));
        expect(keyed.findByKey(1), equals('a'));
        expect(keyed.findByKey(3), equals('ccc'));
      });
    });

    group('immutability', () {
      test('is unmodifiable', () {
        final elements = ['apple', 'banana', 'cherry'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        // KeyedIterable should be unmodifiable
        expect(() => (keyed as List).add('new'), throwsUnsupportedError);
        expect(() => (keyed as List).remove('apple'), throwsUnsupportedError);
        expect(() => (keyed as List).clear(), throwsUnsupportedError);
      });

      test('original list modification does not affect keyed iterable', () {
        final originalList = ['apple', 'banana'];
        final keyed = KeyedIterable.copy(originalList, (e) => e.length);

        // Modify original list
        originalList.add('cherry');

        // KeyedIterable should be unaffected
        expect(keyed.length, equals(2));
        expect(keyed.toList(), equals(['apple', 'banana']));
      });
    });

    group('iteration', () {
      test('supports for-in loop', () {
        final elements = ['apple', 'banana', 'cherry'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        final result = <String>[];
        for (final item in keyed) {
          result.add(item);
        }

        expect(result, equals(['apple', 'banana', 'cherry']));
      });

      test('supports iterator methods', () {
        final elements = [1, 2, 3, 4, 5];
        final keyed = KeyedIterable.copy(elements, (e) => e);

        expect(keyed.where((e) => e.isEven).toList(), equals([2, 4]));
        expect(keyed.map((e) => e * 2).toList(), equals([2, 4, 6, 8, 10]));
        expect(keyed.fold(0, (sum, e) => sum + e), equals(15));
      });

      test('first and last work correctly', () {
        final elements = ['apple', 'banana', 'cherry'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        expect(keyed.first, equals('apple'));
        expect(keyed.last, equals('cherry'));
      });

      test('typed empty iterable throws on first and last', () {
        final empty = KeyedIterable<String, int>.empty();

        expect(() => empty.first, throwsStateError);
        expect(() => empty.last, throwsStateError);
      });

      test('empty iterable throws on first and last', () {
        final empty = KeyedIterable.empty();

        expect(() => empty.first, throwsStateError);
        expect(() => empty.last, throwsStateError);
      });
    });

    group('optimization', () {
      test('reuses existing KeyedIterable when conditions match', () {
        final elements = ['apple', 'banana', 'cherry'];
        final original = KeyedIterable.copy(elements, (e) => e.length);

        // Creating a new KeyedIterable with the same key function should reuse
        final copy = KeyedIterable.copy(original, (e) => e.length);

        // Note: The reuse depends on getKeySpec and getKey matching exactly
        // In this case, both should have empty getKeySpec and same key function
        expect(copy.toList(), equals(original.toList()));
        expect(copy.findByKey(5), equals('apple'));
        expect(
            copy.findByKey(6), equals('cherry')); // Last element with length 6
      });

      test('function reference equality affects reuse', () {
        final elements = ['apple', 'banana', 'cherry'];

        // Use the same function reference
        int keyFunction(String e) => e.length;
        final original = KeyedIterable.copy(elements, keyFunction);
        final copy = KeyedIterable.copy(original, keyFunction);

        // With same function reference, should potentially reuse
        expect(copy.toList(), equals(original.toList()));

        // Test with different function instances
        final copy2 = KeyedIterable.copy(original, (e) => e.length);
        expect(copy2.toList(), equals(original.toList()));
      });

      test('creates new instance for different key function', () {
        final elements = ['apple', 'banana', 'cherry'];
        final original = KeyedIterable.copy(elements, (e) => e.length);

        // Creating with different key function should create new instance
        final different = KeyedIterable.copy(original, (e) => e.codeUnitAt(0));

        expect(identical(original, different), isFalse);
        expect(different.toList(), equals(original.toList()));
        expect(different.findByKey(97), equals('apple')); // 'a' = 97
      });
    });

    group('internalFrozenCopy', () {
      test('reuses existing frozen list', () {
        final elements = ['apple', 'banana', 'cherry'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        // internalFrozenCopy should reuse the same frozen list
        final frozen = internalFrozenCopy(keyed);
        expect(identical(keyed, frozen), isTrue);
      });

      test('creates new frozen list from regular iterable', () {
        final elements = ['apple', 'banana', 'cherry'];
        final frozen = internalFrozenCopy(elements);

        expect(frozen, isNot(same(elements)));
        expect(frozen.toList(), equals(elements));
        expect(() => (frozen as List).add('new'), throwsUnsupportedError);
      });
    });

    group('edge cases', () {
      test('handles duplicate keys correctly', () {
        final elements = ['aa', 'bb', 'cc']; // All have length 2
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        // Should return the last element with the key (due to map overwriting)
        expect(keyed.findByKey(2), equals('cc'));
      });

      test('handles null elements', () {
        final elements = <String?>['apple', null, 'banana'];
        final keyed = KeyedIterable.copy(elements, (e) => e?.length ?? -1);

        expect(keyed.length, equals(3));
        expect(keyed.findByKey(-1), isNull);
        expect(keyed.findByKey(5), equals('apple'));
        expect(keyed.findByKey(6), equals('banana'));
      });

      test('works with different key types', () {
        final elements = [
          Person('Alice', 25),
          Person('Bob', 30),
          Person('Charlie', 25),
        ];

        // Test with string keys
        final byName = KeyedIterable.copy(elements, (p) => p.name);
        expect(byName.findByKey('Alice')?.age, equals(25));
        expect(byName.findByKey('Bob')?.age, equals(30));
        expect(byName.findByKey('David'), isNull);

        // Test with int keys
        final byAge = KeyedIterable.copy(elements, (p) => p.age);
        expect(byAge.findByKey(25)?.name,
            equals('Charlie')); // Last match due to map overwriting
        expect(byAge.findByKey(30)?.name, equals('Bob'));
        expect(byAge.findByKey(35), isNull);
      });

      test('works with complex key types', () {
        final elements = [
          Person('Alice', 25),
          Person('Bob', 30),
        ];

        final byAgeGroup =
            KeyedIterable.copy(elements, (p) => AgeGroup(p.age ~/ 10));
        expect(byAgeGroup.findByKey(AgeGroup(2))?.name, equals('Alice'));
        expect(byAgeGroup.findByKey(AgeGroup(3))?.name, equals('Bob'));
        expect(byAgeGroup.findByKey(AgeGroup(4)), isNull);
      });

      test('empty from filtered iterable works correctly', () {
        final elements = [1, 2, 3, 4, 5];
        // Create a filtered iterable that results in empty
        final filtered = elements.where((e) => e > 10);
        final keyed = KeyedIterable.copy(filtered, (e) => e);

        expect(keyed, isEmpty);
        expect(keyed.length, equals(0));
        expect(keyed.findByKey(1), isNull);
        expect(keyed.toList(), equals([]));
      });

      test('immutable list creation', () {
        final mutableList = ['apple', 'banana', 'cherry'];
        final keyed = KeyedIterable.copy(mutableList, (e) => e.length);

        // Original list should not affect the keyed iterable
        mutableList.clear();

        expect(keyed.length, equals(3));
        expect(keyed.toList(), equals(['apple', 'banana', 'cherry']));
      });
    });
  });
}

// Test helper classes
class Person {
  final String name;
  final int age;

  Person(this.name, this.age);

  @override
  String toString() => 'Person($name, $age)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Person &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          age == other.age;

  @override
  int get hashCode => name.hashCode ^ age.hashCode;
}

class AgeGroup {
  final int decade;

  AgeGroup(this.decade);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgeGroup &&
          runtimeType == other.runtimeType &&
          decade == other.decade;

  @override
  int get hashCode => decade.hashCode;

  @override
  String toString() => 'AgeGroup($decade)';
}

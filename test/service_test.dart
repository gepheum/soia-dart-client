import 'package:test/test.dart';
import 'package:skir_client/skir_client.dart';

void main() {
  group('RawResponse', () {
    test('status codes are correct', () {
      expect(
        const RawResponse('', 200, 'application/json').statusCode,
        equals(200),
      );
      expect(
        const RawResponse('', 200, 'text/html; charset=utf-8').statusCode,
        equals(200),
      );
      expect(
        const RawResponse('', 400, 'text/plain; charset=utf-8').statusCode,
        equals(400),
      );
      expect(
        const RawResponse('', 500, 'text/plain; charset=utf-8').statusCode,
        equals(500),
      );
    });

    test('content types are correct', () {
      expect(
        const RawResponse('', 200, 'application/json').contentType,
        equals('application/json'),
      );
      expect(
        const RawResponse('', 200, 'text/html; charset=utf-8').contentType,
        equals('text/html; charset=utf-8'),
      );
      expect(
        const RawResponse('', 400, 'text/plain; charset=utf-8').contentType,
        equals('text/plain; charset=utf-8'),
      );
      expect(
        const RawResponse('', 500, 'text/plain; charset=utf-8').contentType,
        equals('text/plain; charset=utf-8'),
      );
    });
  });

  group('ServiceBuilder', () {
    test('prevents duplicate method numbers', () {
      final builder = Service.builder();

      // Create a mock method
      final method1 = Method<String, String>(
        'test1',
        1,
        Serializers.string,
        Serializers.string,
        "doc text",
      );

      final method2 = Method<String, String>(
        'test2',
        1, // Same number as method1
        Serializers.string,
        Serializers.string,
        "doc text",
      );

      builder.addMethod(method1, (request, meta) async => 'response1');

      expect(
        () => builder.addMethod(method2, (request, meta) async => 'response2'),
        throwsArgumentError,
      );
    });

    test('allows different method numbers', () {
      final builder = Service.builder();

      final method1 = Method<String, String>(
        'test1',
        1,
        Serializers.string,
        Serializers.string,
        "doc text",
      );

      final method2 = Method<String, String>(
        'test2',
        2, // Different number
        Serializers.string,
        Serializers.string,
        "doc text",
      );

      expect(
        () => builder
            .addMethod(method1, (request, meta) async => 'response1')
            .addMethod(method2, (request, meta) async => 'response2'),
        returnsNormally,
      );
    });
  });

  group('Service', () {
    late Service<HttpHeaders> service;

    setUp(() {
      final method = Method<String, String>(
        'echo',
        1,
        Serializers.string,
        Serializers.string,
        "doc text",
      );

      service = Service.builder()
          .addMethod(method, (request, meta) async => 'echo: $request')
          .build();
    });

    test('handles empty request body with method list', () async {
      final response = await service.handleRequest('', {});

      expect(response.statusCode, equals(200));
      expect(response.contentType, equals('application/json'));
      expect(response.data, contains('methods'));
      expect(response.data, contains('echo'));
    });

    test('handles "list" request with method list', () async {
      final response = await service.handleRequest('list', {});

      expect(response.statusCode, equals(200));
      expect(response.contentType, equals('application/json'));
      expect(response.data, contains('methods'));
    });

    test('handles "studio" request', () async {
      final response = await service.handleRequest('studio', {});

      expect(response.statusCode, equals(200));
      expect(response.contentType, equals('text/html; charset=utf-8'));
      expect(response.data, contains('Skir Studio'));
      expect(response.data, contains('<!DOCTYPE html>'));
    });

    test('handles invalid request format', () async {
      final response = await service.handleRequest('invalid', {});

      expect(response.statusCode, equals(400));
      expect(response.contentType, equals('text/plain; charset=utf-8'));
      expect(response.data, contains('invalid request format'));
    });

    test('handles invalid method number', () async {
      final response = await service.handleRequest('method:abc::{}', {});

      expect(response.statusCode, equals(400));
      expect(response.contentType, equals('text/plain; charset=utf-8'));
      expect(response.data, contains('can\'t parse method number'));
    });

    test('handles method not found', () async {
      final response = await service.handleRequest('unknown:999::{}', {});

      expect(response.statusCode, equals(400));
      expect(response.contentType, equals('text/plain; charset=utf-8'));
      expect(response.data, contains('method not found'));
    });

    test('handles successful method call', () async {
      final response = await service.handleRequest(
        'echo:1::"test message"',
        {},
      );

      expect(response.statusCode, equals(200));
      expect(response.contentType, equals('application/json'));
      expect(response.data, equals('"echo: test message"'));
    });

    test('handles readable format', () async {
      final response = await service.handleRequest(
        'echo:1:readable:"test"',
        {},
      );

      expect(response.statusCode, equals(200));
      expect(response.contentType, equals('application/json'));
      // Should be prettified JSON
      expect(response.data, equals('"echo: test"'));
    });
  });

  group('Service with custom metadata', () {
    test('extracts custom metadata correctly', () async {
      final service = Service.builderWithCustomMeta<String>((headers) {
        final auth = headers['authorization'] ?? '';
        return auth.startsWith('Bearer ') ? auth.substring(7) : 'anonymous';
      })
          .addMethod<String, String>(
            Method(
              'echo',
              1,
              Serializers.string,
              Serializers.string,
              "doc text",
            ),
            (request, token) async => 'User $token: $request',
          )
          .build();

      final response = await service.handleRequest('echo:1::"hello"', {
        'authorization': 'Bearer user123',
      });

      expect(response.statusCode, equals(200));
      expect(response.data, equals('"User user123: hello"'));
    });
  });
}

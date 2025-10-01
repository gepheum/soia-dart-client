import 'package:test/test.dart';
import 'package:soia_client/soia_client.dart';

void main() {
  group('SoiaClient', () {
    test('creates client with base URL', () {
      final client = SoiaClient(baseUrl: 'https://api.example.com');
      expect(client.baseUrl, equals('https://api.example.com'));
      client.dispose();
    });

    test('ApiResponse model works correctly', () {
      final response = ApiResponse(
        statusCode: 200,
        data: {'message': 'success'},
      );

      expect(response.statusCode, equals(200));
      expect(response.data['message'], equals('success'));
      expect(response.isSuccess, isTrue);
    });
  });
}

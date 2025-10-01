import 'package:soia_client/soia_client.dart';

void main() async {
  final client = SoiaClient(baseUrl: 'https://api.example.com');

  try {
    final response = await client.sendRequest('test');
    print('Status: ${response.statusCode}');
    print('Data: ${response.data}');
  } catch (e) {
    print('Error: $e');
  } finally {
    client.dispose();
  }
}

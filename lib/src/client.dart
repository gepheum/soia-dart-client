import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

/// Main client class for interacting with Soia API
class SoiaClient {
  final String baseUrl;
  final http.Client _httpClient;

  SoiaClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Sends a simple request
  Future<ApiResponse> sendRequest(String endpoint) async {
    final uri = Uri.parse('$baseUrl/$endpoint');
    final response = await _httpClient.get(uri);

    return ApiResponse(
      statusCode: response.statusCode,
      data: jsonDecode(response.body),
    );
  }

  /// Dispose the client
  void dispose() {
    _httpClient.close();
  }
}

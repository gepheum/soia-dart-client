/// Response model for API calls
class ApiResponse {
  final int statusCode;
  final Map<String, dynamic> data;

  ApiResponse({
    required this.statusCode,
    required this.data,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

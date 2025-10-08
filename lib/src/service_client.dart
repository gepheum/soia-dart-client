part of "../soia.dart";

/// HTTP method enum for RPC requests.
enum HttpMethod {
  get,
  post,
}

/// Exception thrown when an RPC call fails.
class RpcException implements Exception {
  final int statusCode;
  final String message;

  const RpcException(this.statusCode, this.message);

  @override
  String toString() => 'RpcException($statusCode): $message';
}

/// Sends RPCs to a soia service.
class ServiceClient {
  final Uri _serviceUri;
  final Map<String, String> _defaultRequestHeaders;
  final http.Client _httpClient;

  /// Creates a new service client.
  ///
  /// [serviceUrl] The base URL of the service. Must not contain a query string.
  /// [defaultRequestHeaders] Default headers to include with every request.
  /// [httpClient] The HTTP client to use. If not provided, a default client will be created.
  ServiceClient(
    String serviceUrl, {
    Map<String, String> defaultRequestHeaders = const {},
    http.Client? httpClient,
  })  : _serviceUri = Uri.parse(serviceUrl),
        _defaultRequestHeaders = {...defaultRequestHeaders},
        _httpClient = httpClient ?? http.Client() {
    if (_serviceUri.hasQuery) {
      throw ArgumentError('Service URL must not contain a query string');
    }
  }

  /// Invokes the given method on the remote server through an RPC.
  ///
  /// [method] The RPC method to invoke.
  /// [request] The request object to send.
  /// [httpMethod] The HTTP method to use (GET or POST). Defaults to POST.
  /// [requestHeaders] Additional headers for this specific request.
  /// [timeout] The request timeout. If not provided, no timeout is set.
  ///
  /// Returns the response object.
  /// Throws [RpcException] if the RPC fails.
  /// Throws [http.ClientException] for network-related errors.
  Future<Response> invokeRemote<Request, Response>(
    Method<Request, Response> method,
    Request request, {
    HttpMethod httpMethod = HttpMethod.post,
    Map<String, String> requestHeaders = const {},
    Duration? timeout,
  }) async {
    final requestJson = method.requestSerializer.toJsonCode(request);
    final requestBody = [
      method.name,
      method.number.toString(),
      '',
      requestJson,
    ].join(':');

    // Merge headers
    final headers = {..._defaultRequestHeaders};

    // Add request-specific headers
    for (final entry in requestHeaders.entries) {
      headers[entry.key] = entry.value;
    }

    late final http.Response httpResponse;

    try {
      switch (httpMethod) {
        case HttpMethod.post:
          final postRequest = http.Request('POST', _serviceUri)
            ..headers.addAll(headers)
            ..body = requestBody;

          final streamedResponse = timeout != null
              ? await _httpClient.send(postRequest).timeout(timeout)
              : await _httpClient.send(postRequest);

          httpResponse = await http.Response.fromStream(streamedResponse);
          break;

        case HttpMethod.get:
          final encodedBody =
              Uri.encodeComponent(requestBody.replaceAll('%', '%25'));
          final urlWithQuery = _serviceUri.replace(query: encodedBody);

          final getRequest = http.Request('GET', urlWithQuery)
            ..headers.addAll(headers);

          final streamedResponse = timeout != null
              ? await _httpClient.send(getRequest).timeout(timeout)
              : await _httpClient.send(getRequest);

          httpResponse = await http.Response.fromStream(streamedResponse);
          break;
      }

      if (httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299) {
        final jsonCode = httpResponse.body;
        return method.responseSerializer.fromJsonCode(
          jsonCode,
          keepUnrecognizedFields: true,
        );
      } else {
        var message = '';
        final contentType = httpResponse.headers['content-type'] ?? '';
        if (contentType.toLowerCase().contains('text/plain')) {
          message = ': ${httpResponse.body}';
        }
        throw RpcException(
          httpResponse.statusCode,
          'HTTP status ${httpResponse.statusCode}$message',
        );
      }
    } catch (e) {
      if (e is RpcException) {
        rethrow;
      }
      // Wrap other exceptions as RpcException
      throw RpcException(0, 'Request failed: $e');
    }
  }

  /// Closes the underlying HTTP client.
  ///
  /// This should be called when the service client is no longer needed
  /// to free up resources.
  void close() {
    _httpClient.close();
  }
}

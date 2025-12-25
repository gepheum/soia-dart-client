part of "../skir_client.dart";

typedef HttpHeaders = Map<String, String>;

/// Raw response returned by the server.
class RawResponse {
  final String data;
  final ResponseType type;

  const RawResponse(this.data, this.type);

  /// HTTP status code based on response type.
  int get statusCode {
    switch (type) {
      case ResponseType.okJson:
      case ResponseType.okHtml:
        return 200;
      case ResponseType.badRequest:
        return 400;
      case ResponseType.serverError:
        return 500;
    }
  }

  /// Content type header value based on response type.
  String get contentType {
    switch (type) {
      case ResponseType.okJson:
        return 'application/json';
      case ResponseType.okHtml:
        return 'text/html; charset=utf-8';
      case ResponseType.badRequest:
      case ResponseType.serverError:
        return 'text/plain; charset=utf-8';
    }
  }
}

/// Response types supported by the service handler.
enum ResponseType {
  /// Successful response with JSON content.
  okJson,

  /// Successful response with HTML content.
  okHtml,

  /// Client error response (HTTP 400).
  badRequest,

  /// Server error response (HTTP 500).
  serverError,
}

/// Implementation of a skir RPC service that handles incoming requests.
///
/// A service manages method implementations and provides request routing,
/// serialization, and error handling for RPC operations.
class Service<RequestMeta> {
  final RequestMeta Function(HttpHeaders) _getRequestMeta;
  final Map<int, _MethodImpl<dynamic, dynamic, RequestMeta>> _methodImpls;

  Service._(this._getRequestMeta, this._methodImpls);

  /// Parses the content of a user request and invokes the appropriate method.
  ///
  /// If the request is a GET request, pass in the decoded query string as the
  /// request's body. The query string is the part of the URL after '?', and it
  /// can be decoded with Uri.decodeComponent.
  ///
  /// Pass in [keepUnrecognizedValues] if the request cannot come from a
  /// malicious user.
  Future<RawResponse> handleRequest(
    String requestBody,
    HttpHeaders requestHeaders, {
    bool keepUnrecognizedValues = false,
  }) async {
    if (requestBody.isEmpty || requestBody == 'list') {
      final methodsData = _methodImpls.values
          .map((methodImpl) => _JsonObjectBuilder()
              .put("method", methodImpl.method.name)
              .put("number", methodImpl.method.number)
              .put("request",
                  methodImpl.method.requestSerializer.typeDescriptor.asJson)
              .put("response",
                  methodImpl.method.responseSerializer.typeDescriptor.asJson)
              .putIf("doc", methodImpl.method.doc, (doc) => doc.isNotEmpty)
              .build())
          .toList();

      final json = {'methods': methodsData};
      const encoder = JsonEncoder.withIndent('  ');
      final jsonCode = encoder.convert(json);
      return RawResponse(jsonCode, ResponseType.okJson);
    } else if (requestBody == 'debug' || requestBody == 'restudio') {
      return const RawResponse(_restudioHtml, ResponseType.okHtml);
    }

    // Parse request
    final String methodName;
    final int? methodNumber;
    final String format;
    final dynamic requestData;
    final bool requestDataIsJson;

    final firstChar = requestBody[0];
    if (firstChar == '{' || firstChar.trim().isEmpty) {
      // A JSON object
      final dynamic reqBodyJson;
      try {
        reqBodyJson = jsonDecode(requestBody);
      } catch (e) {
        return const RawResponse(
          'bad request: invalid JSON',
          ResponseType.badRequest,
        );
      }

      if (reqBodyJson is! Map) {
        return const RawResponse(
          'bad request: expected JSON object',
          ResponseType.badRequest,
        );
      }

      final methodField = reqBodyJson['method'];
      if (methodField == null) {
        return const RawResponse(
          'bad request: missing \'method\' field in JSON',
          ResponseType.badRequest,
        );
      }

      if (methodField is String) {
        methodName = methodField;
        methodNumber = null;
      } else if (methodField is int) {
        methodName = '?';
        methodNumber = methodField;
      } else {
        return const RawResponse(
          'bad request: \'method\' field must be a string or an integer',
          ResponseType.badRequest,
        );
      }

      format = 'readable';
      final requestField = reqBodyJson['request'];
      if (requestField == null) {
        return const RawResponse(
          'bad request: missing \'request\' field in JSON',
          ResponseType.badRequest,
        );
      }
      requestData = requestField;
      requestDataIsJson = true;
    } else {
      // A colon-separated string
      final regex = RegExp(r'^([^:]*):([^:]*):([^:]*):([\s\S]*?)$');
      final match = regex.firstMatch(requestBody);
      if (match == null) {
        return const RawResponse(
          'bad request: invalid request format',
          ResponseType.badRequest,
        );
      }

      methodName = match.group(1)!;
      final methodNumberStr = match.group(2)!;
      format = match.group(3)!;
      requestData = match.group(4)!;
      requestDataIsJson = false;

      if (methodNumberStr.isNotEmpty) {
        final methodNumberRegex = RegExp(r'^-?[0-9]+$');
        if (!methodNumberRegex.hasMatch(methodNumberStr)) {
          return const RawResponse(
            'bad request: can\'t parse method number',
            ResponseType.badRequest,
          );
        }
        methodNumber = int.parse(methodNumberStr);
      } else {
        methodNumber = null;
      }
    }

    // Look up method by number or name
    final int resolvedMethodNumber;
    if (methodNumber == null) {
      // Try to get the method number by name
      final nameMatches = _methodImpls.values
          .where((m) => m.method.name == methodName)
          .toList();
      if (nameMatches.isEmpty) {
        return RawResponse(
          'bad request: method not found: $methodName',
          ResponseType.badRequest,
        );
      } else if (nameMatches.length > 1) {
        return RawResponse(
          'bad request: method name \'$methodName\' is ambiguous; '
          'use method number instead',
          ResponseType.badRequest,
        );
      }
      resolvedMethodNumber = nameMatches[0].method.number;
    } else {
      resolvedMethodNumber = methodNumber;
    }

    final methodImpl = _methodImpls[resolvedMethodNumber];
    if (methodImpl == null) {
      return RawResponse(
        'bad request: method not found: $methodName; number: $resolvedMethodNumber',
        ResponseType.badRequest,
      );
    }

    final dynamic request;
    try {
      if (requestDataIsJson) {
        request = methodImpl.method.requestSerializer.fromJson(
          requestData,
          keepUnrecognizedValues: keepUnrecognizedValues,
        );
      } else {
        request = methodImpl.method.requestSerializer.fromJsonCode(
          requestData as String,
          keepUnrecognizedValues: keepUnrecognizedValues,
        );
      }
    } catch (e) {
      return RawResponse(
        'bad request: can\'t parse JSON: ${e.toString()}',
        ResponseType.badRequest,
      );
    }

    final dynamic response;
    try {
      response = await methodImpl.impl(
        request,
        _getRequestMeta(requestHeaders),
      );
    } catch (e) {
      return RawResponse(
        'server error: ${e.toString()}',
        ResponseType.serverError,
      );
    }

    final String responseJson;
    try {
      final readableFlavor = format == 'readable';
      responseJson = methodImpl.method.responseSerializer.toJsonCode(
        response,
        readableFlavor: readableFlavor,
      );
    } catch (e) {
      return RawResponse(
        'server error: can\'t serialize response to JSON: ${e.toString()}',
        ResponseType.serverError,
      );
    }

    return RawResponse(responseJson, ResponseType.okJson);
  }

  /// Creates a builder for constructing a service with default header handling.
  ///
  /// Returns a [ServiceBuilder] that passes HTTP headers directly as request
  /// metadata.
  static ServiceBuilder<HttpHeaders> builder() {
    return ServiceBuilder<HttpHeaders>((headers) => headers);
  }

  /// Creates a builder with custom request metadata extraction.
  ///
  /// [getRequestMeta] Function to extract custom metadata from HTTP headers
  /// Returns a [ServiceBuilder] configured to use the provided metadata
  /// extraction function
  static ServiceBuilder<RequestMeta> builderWithMeta<RequestMeta>(
    RequestMeta Function(HttpHeaders) getRequestMeta,
  ) {
    return ServiceBuilder<RequestMeta>(getRequestMeta);
  }
}

/// Builder for constructing a Service instance with method implementations.
///
/// This builder provides a fluent API for registering RPC method implementations
/// and configuring request metadata handling before creating the final service.
class ServiceBuilder<RequestMeta> {
  final RequestMeta Function(HttpHeaders) _getRequestMeta;
  final Map<int, _MethodImpl<dynamic, dynamic, RequestMeta>> _methodImpls = {};

  ServiceBuilder(this._getRequestMeta);

  /// Adds a method implementation to the service.
  ///
  /// [method] The method definition to implement
  /// [impl] The implementation function that handles requests for this method
  /// Returns this builder for method chaining
  ServiceBuilder<RequestMeta> addMethod<Request, Response>(
    Method<Request, Response> method,
    Future<Response> Function(Request request, RequestMeta requestMeta) impl,
  ) {
    final number = method.number;
    if (_methodImpls.containsKey(number)) {
      throw ArgumentError(
        'Method with the same number already registered ($number)',
      );
    }
    // Type-safe wrapper
    Future<dynamic> dynamicImpl(dynamic request, RequestMeta requestMeta) {
      return impl(request as Request, requestMeta);
    }

    _methodImpls[number] = _MethodImpl(method, dynamicImpl);
    return this;
  }

  /// Builds the service instance.
  ///
  /// Returns a fully configured [Service] ready to handle RPC requests.
  Service<RequestMeta> build() {
    return Service._(_getRequestMeta, {..._methodImpls});
  }
}

/// Internal method implementation wrapper.
class _MethodImpl<Request, Response, RequestMeta> {
  final Method<Request, Response> method;
  final Future<dynamic> Function(dynamic, RequestMeta) impl;

  _MethodImpl(this.method, this.impl);
}

/// RESTudio HTML content for interactive API testing.
const String _restudioHtml = '''<!DOCTYPE html>

<html>
  <head>
    <meta charset="utf-8" />
    <title>RESTudio</title>
    <script src="https://cdn.jsdelivr.net/npm/restudio/dist/restudio-standalone.js"></script>
  </head>
  <body style="margin: 0; padding: 0;">
    <restudio-app></restudio-app>
  </body>
</html>
''';

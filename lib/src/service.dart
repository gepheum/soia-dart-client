part of "../soia_client.dart";

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

/// Response type enumeration.
enum ResponseType {
  okJson,
  okHtml,
  badRequest,
  serverError,
}

/// Implementation of a soia service.
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
  /// Pass in [keepUnrecognizedFields] if the request cannot come from a
  /// malicious user.
  Future<RawResponse> handleRequest(
    String requestBody,
    HttpHeaders requestHeaders, {
    bool keepUnrecognizedFields = false,
  }) async {
    if (requestBody.isEmpty || requestBody == 'list') {
      final methodsData = _methodImpls.values.map((methodImpl) {
        return {
          'method': methodImpl.method.name,
          'number': methodImpl.method.number,
          'request': methodImpl.method.requestSerializer.typeDescriptor.asJson,
          'response':
              methodImpl.method.responseSerializer.typeDescriptor.asJson,
        };
      }).toList();

      final json = {'methods': methodsData};
      const encoder = JsonEncoder.withIndent('  ');
      final jsonCode = encoder.convert(json);
      return RawResponse(jsonCode, ResponseType.okJson);
    } else if (requestBody == 'restudio') {
      return const RawResponse(_restudioHtml, ResponseType.okHtml);
    }

    final regex = RegExp(r'^([^:]*):([^:]*):([^:]*):([\s\S]*?)$');
    final match = regex.firstMatch(requestBody);
    if (match == null) {
      return const RawResponse(
        'bad request: invalid request format',
        ResponseType.badRequest,
      );
    }

    final methodName = match.group(1)!;
    final methodNumberStr = match.group(2)!;
    final format = match.group(3)!;
    final requestData = match.group(4)!;

    final methodNumberRegex = RegExp(r'^-?[0-9]+$');
    if (!methodNumberRegex.hasMatch(methodNumberStr)) {
      return const RawResponse(
        'bad request: can\'t parse method number',
        ResponseType.badRequest,
      );
    }
    final methodNumber = int.parse(methodNumberStr);

    final methodImpl = _methodImpls[methodNumber];
    if (methodImpl == null) {
      return RawResponse(
        'bad request: method not found: $methodName; number: $methodNumber',
        ResponseType.badRequest,
      );
    }

    final dynamic request;
    try {
      request = methodImpl.method.requestSerializer.fromJsonCode(
        requestData,
        keepUnrecognizedFields: keepUnrecognizedFields,
      );
    } catch (e) {
      return RawResponse(
        'bad request: can\'t parse JSON: ${e.toString()}',
        ResponseType.badRequest,
      );
    }

    final dynamic response;
    try {
      response =
          await methodImpl.impl(request, _getRequestMeta(requestHeaders));
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

  /// Creates a builder for constructing a service.
  static ServiceBuilder<HttpHeaders> builder() {
    return ServiceBuilder<HttpHeaders>((headers) => headers);
  }

  /// Creates a builder with custom request metadata extraction.
  static ServiceBuilder<RequestMeta> builderWithMeta<RequestMeta>(
    RequestMeta Function(HttpHeaders) getRequestMeta,
  ) {
    return ServiceBuilder<RequestMeta>(getRequestMeta);
  }
}

/// Builder for constructing a Service instance.
class ServiceBuilder<RequestMeta> {
  final RequestMeta Function(HttpHeaders) _getRequestMeta;
  final Map<int, _MethodImpl<dynamic, dynamic, RequestMeta>> _methodImpls = {};

  ServiceBuilder(this._getRequestMeta);

  /// Adds a method implementation to the service.
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

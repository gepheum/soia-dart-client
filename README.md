# Soia Client

Dart client library for Soia serialization and RPC communication.

## Features

- **Serialization**: Convert Dart objects to/from JSON and binary formats
- **RPC Client**: Make remote procedure calls to Soia services  
- **RPC Server**: Implement Soia services that handle incoming RPC requests
- **Type Safety**: Fully typed API with generated serializers

## Usage

### Basic Serialization

```dart
import 'package:soia_client/soia_client.dart';

// Example with generated types (from .soia files)
final myObject = MyStruct(field1: 'value', field2: 42);

// Serialize to JSON
final json = MyStruct.serializer.toJson(myObject);
final jsonString = MyStruct.serializer.toJsonCode(myObject);

// Deserialize from JSON
final restored = MyStruct.serializer.fromJsonCode(jsonString);

// Serialize to binary
final bytes = MyStruct.serializer.toBytes(myObject);
final fromBytes = MyStruct.serializer.fromBytes(bytes);
```

### RPC Client

```dart
import 'package:soia_client/soia_client.dart';

// Create a service client
final client = ServiceClient(
  'https://api.example.com',
  defaultRequestHeaders: {
    'Authorization': 'Bearer your-token',
  },
);

try {
  // Define method (typically generated from .soia files)
  final method = Method<MyRequest, MyResponse>(
    'getUserInfo',
    1,
    MyRequest.serializer,
    MyResponse.serializer,
  );

  // Make RPC call
  final request = MyRequest(userId: 123);
  final response = await client.invokeRemote(
    method,
    request,
    httpMethod: HttpMethod.post,
    timeout: Duration(seconds: 30),
  );
  
  print('User: ${response.userName}');
} catch (e) {
  print('RPC failed: $e');
} finally {
  client.close();
}
```

### RPC Server

```dart
import 'package:soia_client/soia_client.dart';

// Create a service implementation
final service = Service.builder()
    .addMethod<GetUserRequest, GetUserResponse>(
      getUserMethod, // Method definition from generated code
      (request, headers) async {
        // Your business logic here
        final user = await userRepository.findById(request.userId);
        return GetUserResponse(user: user);
      },
    )
    .addMethod<CreateUserRequest, CreateUserResponse>(
      createUserMethod,
      (request, headers) async {
        final user = await userRepository.create(request.userData);
        return CreateUserResponse(user: user);
      },
    )
    .build();

// Handle incoming HTTP requests
Future<void> handleHttpRequest(HttpRequest request) async {
  final body = await utf8.decoder.bind(request).join();
  final headers = <String, List<String>>{};
  request.headers.forEach((name, values) {
    headers[name.toLowerCase()] = values;
  });

  final response = await service.handleRequest(
    body,
    headers,
    keepUnrecognizedFields: false,
  );

  request.response
    ..statusCode = response.statusCode
    ..headers.contentType = ContentType.parse(response.contentType)
    ..write(response.data);
  
  await request.response.close();
}

// Service with custom metadata extraction
final serviceWithAuth = Service.builderWithMeta<String>((headers) {
  final auth = headers['authorization']?.first ?? '';
  return auth.startsWith('Bearer ') ? auth.substring(7) : 'anonymous';
})
    .addMethod<ProtectedRequest, ProtectedResponse>(
      protectedMethod,
      (request, userToken) async {
        // userToken contains the extracted Bearer token
        if (userToken == 'anonymous') {
          throw Exception('Authentication required');
        }
        // Handle authenticated request
        return ProtectedResponse(data: 'Hello $userToken');
      },
    )
    .build();
```

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  soia_client: ^0.1.0
```

Then run:
```bash
dart pub get
```

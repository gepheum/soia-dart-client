# Soia Client

A simple Dart client library for Soia.

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  soia_client: ^0.1.0
```

## Usage

```dart
import 'package:soia_client/soia_client.dart';

void main() async {
  final client = SoiaClient(baseUrl: 'https://api.example.com');
  
  try {
    final response = await client.sendRequest('test');
    print('Status: ${response.statusCode}');
    print('Data: ${response.data}');
  } finally {
    client.dispose();
  }
}
```

## Features

- Simple HTTP client
- Basic response models
- Easy to extend

## Contributing

Please read our contributing guidelines before submitting pull requests.

## License

This project is licensed under the MIT License.

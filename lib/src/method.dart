part of "../soia_client.dart";

class Method<Request, Response> {
  final String name;
  final int number;
  final Serializer<Request> requestSerializer;
  final Serializer<Response> responseSerializer;

  Method(
    this.name,
    this.number,
    this.requestSerializer,
    this.responseSerializer,
  );
}

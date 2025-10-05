/// A Dart client library for Soia serialization
library soia_client;

import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:typed_data/typed_buffers.dart';

part 'src/binary_utils.dart';
part 'src/enum_serializer.dart';
part 'src/frozen_list.dart';
part 'src/list_serializer.dart';
part 'src/optional_serializer.dart';
part 'src/primitive_serializers.dart';
part 'src/record_id.dart';
part 'src/serializer.dart';
part 'src/serializers.dart';
part 'src/struct_serializer.dart';
part 'src/type_descriptor.dart';
part 'src/type_descriptor_parser.dart';
part 'src/unrecognized.dart';

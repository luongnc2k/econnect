import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

Future<MultipartFile> buildUploadMultipartFile({
  required String fileName,
  required Uint8List fileBytes,
  String? filePath,
  bool isWeb = kIsWeb,
}) async {
  final normalizedPath = filePath?.trim();
  final canReadFromFile =
      !isWeb && normalizedPath != null && normalizedPath.isNotEmpty;

  if (canReadFromFile) {
    return MultipartFile.fromFile(normalizedPath, filename: fileName);
  }

  return MultipartFile.fromBytes(fileBytes, filename: fileName);
}

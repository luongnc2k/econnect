import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

Future<MultipartFile> buildUploadMultipartFile({
  required String fileName,
  Uint8List? fileBytes,
  String? filePath,
  bool isWeb = kIsWeb,
}) async {
  final normalizedPath = filePath?.trim();
  final canReadFromFile =
      !isWeb && normalizedPath != null && normalizedPath.isNotEmpty;

  if (canReadFromFile) {
    return MultipartFile.fromFile(normalizedPath, filename: fileName);
  }

  if (fileBytes == null) {
    throw ArgumentError('fileBytes is required when filePath is unavailable');
  }

  return MultipartFile.fromBytes(fileBytes, filename: fileName);
}

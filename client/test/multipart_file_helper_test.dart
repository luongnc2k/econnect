import 'dart:io';
import 'dart:typed_data';

import 'package:client/core/network/multipart_file_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'web upload falls back to bytes even when filePath is present',
    () async {
      final multipart = await buildUploadMultipartFile(
        fileName: 'thumb.png',
        fileBytes: Uint8List.fromList([1, 2, 3]),
        filePath: r'Z:\missing\thumb.png',
        isWeb: true,
      );

      expect(multipart.filename, 'thumb.png');
      expect(multipart.length, 3);
    },
  );

  test('non-web upload can read from a local file path', () async {
    final tempDir = await Directory.systemTemp.createTemp('econnect_upload_');
    addTearDown(() async {
      await tempDir.delete(recursive: true);
    });

    final tempFile = File('${tempDir.path}\\thumb.png');
    await tempFile.writeAsBytes([4, 5, 6, 7]);

    final multipart = await buildUploadMultipartFile(
      fileName: 'thumb.png',
      fileBytes: Uint8List.fromList([1]),
      filePath: tempFile.path,
      isWeb: false,
    );

    expect(multipart.filename, 'thumb.png');
    expect(multipart.length, 4);
  });
}

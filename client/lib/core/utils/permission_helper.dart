import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestGalleryPermission() async {
    if (Platform.isAndroid) {
      // Android 13+
      final photosStatus = await Permission.photos.request();
      if (photosStatus.isGranted || photosStatus.isLimited) {
        return true;
      }

      // Android <= 12
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }

    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }

    // Desktop platforms: không cần xin quyền kiểu mobile
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return true;
    }

    return false;
  }

  static Future<bool> requestCameraPermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.camera.request();
      return status.isGranted;
    }

    // Desktop: không hỗ trợ camera mặc định trong flow này
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return false;
    }

    return false;
  }
}

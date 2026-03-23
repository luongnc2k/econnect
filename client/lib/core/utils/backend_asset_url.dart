import 'package:client/core/constants/server_constant.dart';

String normalizeBackendAssetUrl(String? rawUrl) {
  final trimmed = rawUrl?.trim() ?? '';
  if (trimmed.isEmpty) {
    return trimmed;
  }

  final assetUri = Uri.tryParse(trimmed);
  final serverUri = ServerConstant.serverUri;
  if (assetUri == null || serverUri == null) {
    return trimmed;
  }

  if (!assetUri.path.startsWith('/static/')) {
    return trimmed;
  }

  return assetUri
      .replace(
        scheme: serverUri.scheme,
        host: serverUri.host,
        port: serverUri.hasPort ? serverUri.port : null,
      )
      .toString();
}

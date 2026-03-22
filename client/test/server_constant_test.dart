import 'package:client/core/constants/server_constant.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit SERVER_URL override wins', () {
    expect(
      ServerConstant.resolveServerUrl(
        environmentUrl: 'http://192.168.1.10:8000',
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      ),
      'http://192.168.1.10:8000',
    );
  });

  test('android default local server uses 10.0.2.2', () {
    expect(
      ServerConstant.resolveServerUrl(
        environmentUrl: '',
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      ),
      'http://10.0.2.2:8000',
    );
  });

  test('non-android default local server uses 127.0.0.1', () {
    expect(
      ServerConstant.resolveServerUrl(
        environmentUrl: '',
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      ),
      'http://127.0.0.1:8000',
    );
  });
}

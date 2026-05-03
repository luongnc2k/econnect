import 'package:client/features/profile/model/payout_bank_account_verification_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes payOS success message for UI', () {
    final result = PayoutBankAccountVerificationResult.fromMap({
      'provider': 'payos',
      'is_valid': true,
      'message':
          'payOS khong tra loi khi kiem tra so bo tai khoan nhan tien nay',
      'estimate_credit': 2950,
    });

    expect(
      result.message,
      'payOS không trả lỗi khi kiểm tra sơ bộ tài khoản nhận tiền này.',
    );
  });

  test('normalizes payout IPv4 guidance message for UI', () {
    final message = PayoutBankAccountVerificationResult.normalizeMessage(
      'payOS tu choi kiem tra vi IP may chu hien tai chua duoc them vao '
      'Kenh chuyen tien > Quan ly IP. Neu ban dang chay local/ngrok, hay doi '
      'PAYOS_PAYOUT_MOCK_MODE=true trong server/.env roi restart backend. '
      'Neu muon kiem tra that, hay them public outbound IP cua backend vao my.payos.vn. '
      'Neu may local uu tien IPv6 va ban chi allowlist IPv4, hay bat them '
      'PAYOS_PAYOUT_FORCE_IPV4=true.',
    );

    expect(message, contains('Kênh chuyển tiền > Quản lý IP'));
    expect(message, contains('PAYOS_PAYOUT_FORCE_IPV4=true'));
  });
}

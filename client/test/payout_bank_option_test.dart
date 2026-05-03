import 'package:client/features/profile/model/payout_bank_option.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches stored aliases to a supported payout bank', () {
    final matched = PayoutBankCatalog.match(bankName: 'MBB', bankBin: null);

    expect(matched, isNotNull);
    expect(matched?.id, 'mbbank');
    expect(matched?.bankBin, '970422');
  });

  test('prefers BIN when matching an existing payout bank', () {
    final matched = PayoutBankCatalog.match(
      bankName: 'Unknown Legacy Name',
      bankBin: '970418',
    );

    expect(matched, isNotNull);
    expect(matched?.id, 'bidv');
    expect(matched?.bankName, 'BIDV');
  });

  test('returns null when bank is outside the supported dropdown list', () {
    final matched = PayoutBankCatalog.match(
      bankName: 'Some Other Bank',
      bankBin: '123456',
    );

    expect(matched, isNull);
  });
}

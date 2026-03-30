class PayoutBankAccountVerificationResult {
  final String provider;
  final bool isValid;
  final String message;
  final int? estimateCredit;

  const PayoutBankAccountVerificationResult({
    required this.provider,
    required this.isValid,
    required this.message,
    this.estimateCredit,
  });

  factory PayoutBankAccountVerificationResult.fromMap(
    Map<String, dynamic> map,
  ) {
    final rawMessage =
        map['message']?.toString() ?? 'Không thể kiểm tra tài khoản ngân hàng';
    return PayoutBankAccountVerificationResult(
      provider: map['provider']?.toString() ?? 'payos',
      isValid: map['is_valid'] == true,
      message: normalizeMessage(rawMessage),
      estimateCredit: map['estimate_credit'] is num
          ? (map['estimate_credit'] as num).toInt()
          : int.tryParse(map['estimate_credit']?.toString() ?? ''),
    );
  }

  static String normalizeMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return 'Không thể kiểm tra tài khoản ngân hàng';
    }

    const knownMessages = {
      'payOS khong tra loi khi kiem tra so bo tai khoan nhan tien nay':
          'payOS không trả lỗi khi kiểm tra sơ bộ tài khoản nhận tiền này.',
      'Mock payout da hoan tat buoc kiem tra so bo tai khoan nhan tien':
          'Mock payout đã hoàn tất bước kiểm tra sơ bộ tài khoản nhận tiền.',
    };

    final knownMessage = knownMessages[trimmed];
    if (knownMessage != null) {
      return knownMessage;
    }

    if (trimmed.contains('PAYOS_PAYOUT_FORCE_IPV4=true') &&
        trimmed.contains('my.payos.vn')) {
      return 'payOS từ chối kiểm tra vì IP máy chủ hiện tại chưa được thêm vào '
          'Kênh chuyển tiền > Quản lý IP. Nếu bạn đang chạy local/ngrok, hãy đổi '
          'PAYOS_PAYOUT_MOCK_MODE=true trong server/.env rồi restart backend. '
          'Nếu muốn kiểm tra thật, hãy thêm public outbound IP của backend vào my.payos.vn. '
          'Nếu máy local ưu tiên IPv6 và bạn chỉ allowlist IPv4, hãy bật thêm '
          'PAYOS_PAYOUT_FORCE_IPV4=true.';
    }

    if (trimmed.startsWith(
      'Khong the kiem tra tai khoan ngan hang luc nay: ',
    )) {
      return trimmed.replaceFirst(
        'Khong the kiem tra tai khoan ngan hang luc nay: ',
        'Không thể kiểm tra tài khoản ngân hàng lúc này: ',
      );
    }

    return trimmed;
  }
}

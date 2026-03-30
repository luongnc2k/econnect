class PayoutBankOption {
  final String id;
  final String label;
  final String bankName;
  final String bankBin;
  final bool isManualEntry;
  final List<String> aliases;

  const PayoutBankOption({
    required this.id,
    required this.label,
    required this.bankName,
    required this.bankBin,
    this.isManualEntry = false,
    this.aliases = const [],
  });

  bool matches({String? bankName, String? bankBin}) {
    final normalizedBankName = _normalize(bankName);
    final normalizedBankBin = _normalize(bankBin);

    if (normalizedBankBin.isNotEmpty && normalizedBankBin == this.bankBin) {
      return true;
    }

    if (normalizedBankName.isEmpty) {
      return false;
    }

    return normalizedBankName == _normalize(this.bankName) ||
        aliases.any((alias) => normalizedBankName == _normalize(alias));
  }

  static String _normalize(String? value) {
    return (value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}

class PayoutBankCatalog {
  static const manual = PayoutBankOption(
    id: 'manual',
    label: 'Nhập thủ công',
    bankName: '',
    bankBin: '',
    isManualEntry: true,
  );

  // Verified against VietQR bank list and kept focused on payOS payout banks.
  static const supportedBanks = <PayoutBankOption>[
    PayoutBankOption(
      id: 'acb',
      label: 'ACB',
      bankName: 'ACB',
      bankBin: '970416',
      aliases: ['Ngan hang A Chau'],
    ),
    PayoutBankOption(
      id: 'bidv',
      label: 'BIDV',
      bankName: 'BIDV',
      bankBin: '970418',
      aliases: ['Ngan hang Dau tu va Phat trien Viet Nam'],
    ),
    PayoutBankOption(
      id: 'mbbank',
      label: 'MBBank',
      bankName: 'MBBank',
      bankBin: '970422',
      aliases: ['MB', 'MBB', 'MB Bank', 'Ngan hang Quan doi'],
    ),
    PayoutBankOption(
      id: 'shinhanbank',
      label: 'Shinhan Bank',
      bankName: 'ShinhanBank',
      bankBin: '970424',
      aliases: ['Shinhan Bank', 'SHBVN'],
    ),
    PayoutBankOption(
      id: 'ocb',
      label: 'OCB',
      bankName: 'OCB',
      bankBin: '970448',
      aliases: ['Ngan hang Phuong Dong'],
    ),
    PayoutBankOption(
      id: 'kienlongbank',
      label: 'KienLongBank',
      bankName: 'KienLongBank',
      bankBin: '970452',
      aliases: ['KienlongBank', 'Kien Long Bank', 'KLB'],
    ),
  ];

  static const options = <PayoutBankOption>[manual, ...supportedBanks];

  static PayoutBankOption? findById(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final option in options) {
      if (option.id == id) {
        return option;
      }
    }
    return null;
  }

  static PayoutBankOption? match({String? bankName, String? bankBin}) {
    for (final option in supportedBanks) {
      if (option.matches(bankName: bankName, bankBin: bankBin)) {
        return option;
      }
    }
    return null;
  }
}

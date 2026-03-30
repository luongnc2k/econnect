from runtime_checks import payos_payout_real_mode_startup_notice


def test_payos_payout_startup_notice_mentions_ipv4_when_forced(monkeypatch):
    monkeypatch.setenv("PAYMENT_GATEWAY_MODE", "payos")
    monkeypatch.setenv("PAYOS_PAYOUT_MOCK_MODE", "false")
    monkeypatch.setenv("PAYOS_PAYOUT_FORCE_IPV4", "true")

    notice = payos_payout_real_mode_startup_notice()

    assert notice is not None
    assert "PAYOS_PAYOUT_FORCE_IPV4=true" in notice
    assert "IPv4" in notice


def test_payos_payout_startup_notice_warns_about_ip_allowlist_when_ipv4_not_forced(
    monkeypatch,
):
    monkeypatch.setenv("PAYMENT_GATEWAY_MODE", "payos")
    monkeypatch.setenv("PAYOS_PAYOUT_MOCK_MODE", "false")
    monkeypatch.delenv("PAYOS_PAYOUT_FORCE_IPV4", raising=False)
    monkeypatch.delenv("PAYOS_FORCE_IPV4", raising=False)

    notice = payos_payout_real_mode_startup_notice()

    assert notice is not None
    assert "Kenh chuyen tien > Quan ly IP" in notice
    assert "PAYOS_PAYOUT_MOCK_MODE=true" in notice

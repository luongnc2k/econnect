def test_health_live_and_ready_endpoints_return_ok(client):
    live_response = client.get("/health/live")
    assert live_response.status_code == 200
    live_body = live_response.json()
    assert live_body["status"] == "ok"
    assert "app_env" in live_body
    assert "payos_payout_mock_mode" in live_body
    assert "payos_payout_force_ipv4" in live_body

    ready_response = client.get("/health/ready")
    assert ready_response.status_code == 200
    ready_body = ready_response.json()
    assert ready_body["status"] == "ready"
    assert ready_body["checks"]["database"] == "ok"

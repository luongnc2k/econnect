from importlib import import_module
from pathlib import Path
import sys


ROOT_DIR = Path(__file__).resolve().parents[1]
SERVER_DIR = ROOT_DIR / "server"

if str(SERVER_DIR) not in sys.path:
    sys.path.insert(0, str(SERVER_DIR))

MODULES = [
    "database",
    "payment_gateways",
    "middleware.auth_middleware",
    "routes.auth",
    "routes.classes",
    "routes.payments",
    "routes.profile",
    "routes.topics",
    "routes.upload",
    "routes.users",
    "main",
]


def main() -> int:
    for module_name in MODULES:
        import_module(module_name)
        print(f"Imported {module_name}")
    print("Backend import check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

import os
from pathlib import Path

TESTING = any(v in os.environ for v in ("PYTEST_VERSION", "TESTING"))
DEBUG = os.environ.get("DEBUG", TESTING)

CONFIG_HOME = Path(os.environ["XDG_DATA_HOME"]).expanduser() / "pytagdb"

if TESTING:
    DATABASE_URI = f"sqlite+pysqlite:///:memory:"
else:
    DATABASE_URI = f"sqlite+pysqlite://{CONFIG_HOME / "db.sqlite3"}"

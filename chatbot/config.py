"""Configuration constants and path management for the chatbot engine."""
import os
from pathlib import Path
from typing import Final

# Base directory is the directory containing this file (the chatbot package)
BASE_DIR: Final[Path] = Path(__file__).resolve().parent

# Subdirectories
PROFILES_DIR: Final[Path] = BASE_DIR / "profiles"
DATA_DIR: Final[Path] = BASE_DIR / "data"
IPC_DIR: Final[Path] = BASE_DIR / "ipc"
CONVERSATIONS_DIR: Final[Path] = BASE_DIR / "conversations"
LOGS_DIR: Final[Path] = BASE_DIR / "logs"

# IPC file paths
REQUEST_FILE: Final[Path] = IPC_DIR / "request.json"
RESPONSE_FILE: Final[Path] = IPC_DIR / "response.json"
SHUTDOWN_FILE: Final[Path] = IPC_DIR / "shutdown.json"
LOCK_FILE: Final[Path] = IPC_DIR / "request.lock"

# Timing
POLL_INTERVAL: Final[float] = 0.05  # 50ms polling interval

# Limits
MAX_RESPONSE_LENGTH: Final[int] = 300
MAX_CONVERSATION_TURNS: Final[int] = 50

# Logging format
LOG_FORMAT: Final[str] = "%(asctime)s [%(levelname)s] %(name)s: %(message)s"
LOG_DATE_FORMAT: Final[str] = "%Y-%m-%d %H:%M:%S"

# Auto-create all required directories on import
for _dir in (PROFILES_DIR, DATA_DIR, IPC_DIR, CONVERSATIONS_DIR, LOGS_DIR):
    _dir.mkdir(parents=True, exist_ok=True)

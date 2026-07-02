"""File-based IPC watcher for the chatbot engine."""
import json
import logging
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional

from chatbot import __version__
from chatbot.config import (
    IPC_DIR, LOGS_DIR, REQUEST_FILE, RESPONSE_FILE,
    SHUTDOWN_FILE, LOCK_FILE, POLL_INTERVAL, LOG_FORMAT, LOG_DATE_FORMAT,
)
from chatbot.engine import ChatbotEngine

logger = logging.getLogger("chatbot")
READ_RETRIES: int = 3
READ_RETRY_DELAY: float = 0.01


def _setup_logging() -> None:
    """Configure logging to both console and a daily log file."""
    logger.setLevel(logging.DEBUG)
    console = logging.StreamHandler(sys.stdout)
    console.setLevel(logging.INFO)
    console.setFormatter(logging.Formatter(LOG_FORMAT, LOG_DATE_FORMAT))
    logger.addHandler(console)
    try:
        log_filename = datetime.now().strftime("chatbot_%Y%m%d.log")
        log_path = LOGS_DIR / log_filename
        file_handler = logging.FileHandler(log_path, encoding="utf-8")
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(logging.Formatter(LOG_FORMAT, LOG_DATE_FORMAT))
        logger.addHandler(file_handler)
    except OSError as e:
        logger.warning("Could not create log file: %s", e)


def _read_json_safe(filepath: Path) -> Optional[Dict[str, Any]]:
    """Read a JSON file with retry logic."""
    for attempt in range(READ_RETRIES):
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                data = json.load(f)
            if isinstance(data, dict):
                return data
            logger.warning("JSON file %s is not a dict", filepath)
        except json.JSONDecodeError:
            if attempt < READ_RETRIES - 1:
                time.sleep(READ_RETRY_DELAY)
                continue
            logger.warning("Failed to parse JSON after %d attempts: %s", READ_RETRIES, filepath)
        except OSError as e:
            logger.error("Failed to read %s: %s", filepath, e)
            return None
    return None


def _write_json_safe(filepath: Path, data: Dict[str, Any]) -> bool:
    """Write a dictionary to a JSON file safely."""
    try:
        temp_path = filepath.with_suffix(".tmp")
        with open(temp_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.flush()
        temp_path.replace(filepath)
        return True
    except OSError as e:
        logger.error("Failed to write %s: %s", filepath, e)
        try:
            temp_path = filepath.with_suffix(".tmp")
            if temp_path.exists():
                temp_path.unlink()
        except OSError:
            pass
        return False


def _delete_safe(filepath: Path) -> None:
    """Delete a file, ignoring errors if it does not exist."""
    try:
        if filepath.exists():
            filepath.unlink()
    except OSError as e:
        logger.warning("Failed to delete %s: %s", filepath, e)


def _log_exchange(request: Dict, response: Dict) -> None:
    """Log a request/response exchange."""
    npc = request.get("npc_name", "?")
    player = request.get("player_name", "?")
    msg = request.get("message", "")
    reply = response.get("reply", "")
    topic = response.get("topic", "?")
    logger.info("[%s -> %s] msg=%r topic=%s reply=%r", player, npc, msg[:80], topic, reply[:80])


def _check_lock() -> bool:
    """Check if a lock file exists."""
    return LOCK_FILE.exists()


def _print_banner() -> None:
    """Print the startup banner."""
    print(f"""
========================================
  Tavern Quest NPC Chatbot Engine
  Version {__version__}
========================================
  IPC Directory: {IPC_DIR}
  Poll Interval: {POLL_INTERVAL}s
  Waiting for requests...
========================================
""")


def main() -> None:
    """Main entry point for the chatbot file watcher."""
    _setup_logging()
    _print_banner()
    try:
        engine = ChatbotEngine()
    except Exception as e:
        logger.critical("Failed to initialize ChatbotEngine: %s", e, exc_info=True)
        sys.exit(1)
    logger.info("ChatbotEngine ready. Entering polling loop.")
    running = True
    while running:
        try:
            if SHUTDOWN_FILE.exists():
                logger.info("Shutdown signal received. Exiting.")
                _delete_safe(SHUTDOWN_FILE)
                running = False
                break
            if REQUEST_FILE.exists():
                if _check_lock():
                    time.sleep(READ_RETRY_DELAY)
                    continue
                request = _read_json_safe(REQUEST_FILE)
                _delete_safe(REQUEST_FILE)
                if request is None:
                    logger.warning("Failed to read request file, skipping.")
                    time.sleep(POLL_INTERVAL)
                    continue
                response = engine.process(request)
                if _write_json_safe(RESPONSE_FILE, response):
                    _log_exchange(request, response)
                else:
                    logger.error("Failed to write response.")
            time.sleep(POLL_INTERVAL)
        except KeyboardInterrupt:
            logger.info("Keyboard interrupt. Shutting down.")
            running = False
        except Exception as e:
            logger.error("Unexpected error in main loop: %s", e, exc_info=True)
            time.sleep(POLL_INTERVAL)
    logger.info("Chatbot engine stopped.")

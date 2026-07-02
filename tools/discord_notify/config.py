"""
Shared configuration loader for Discord notification tools.
Parses .env manually - no external dependencies required.
Environment variables override .env values.
"""

import os
import sys

ENV_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")

def load_env():
    """Load variables from .env file. Environment variables take precedence."""
    config = {}

    # Read .env file if it exists
    if os.path.exists(ENV_PATH):
        with open(ENV_PATH, "r") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    key, _, value = line.partition("=")
                    key = key.strip()
                    value = value.strip().strip('"').strip("'")
                    if value:
                        config[key] = value

    # Environment variables override .env
    for key in ("DISCORD_BOT_TOKEN", "DISCORD_USER_ID", "DISCORD_CHANNEL_ID"):
        env_val = os.environ.get(key)
        if env_val:
            config[key] = env_val

    return config


def get_config():
    """Load and validate configuration. Exits with helpful message on failure."""
    config = load_env()

    missing = []
    if not config.get("DISCORD_BOT_TOKEN"):
        missing.append("DISCORD_BOT_TOKEN")
    if not config.get("DISCORD_USER_ID"):
        missing.append("DISCORD_USER_ID")

    if missing:
        print(f"ERROR: Missing required config: {', '.join(missing)}")
        print(f"\nSetup instructions:")
        print(f"  1. Copy .env.example to .env in: {os.path.dirname(ENV_PATH)}")
        print(f"  2. Fill in your bot token and Discord user ID")
        print(f"  3. Or set them as environment variables")
        sys.exit(1)

    return config

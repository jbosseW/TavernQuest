"""
Lightweight Discord DM notification sender.
Zero external dependencies - uses only urllib.request.

Usage:
  Quick:  python notify.py "Task done!"
  Rich:   python notify.py --title "Build Complete" --message "All tests passed" --status success --agent lua-coder

Status colors: success (green), error (red), warning (orange), info (blue)
"""

import argparse
import json
import sys
import urllib.request
import urllib.error

# Add parent directory for config import
sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
from config import get_config

DISCORD_API = "https://discord.com/api/v10"

STATUS_COLORS = {
    "success": 0x2ECC71,  # Green
    "error": 0xE74C3C,    # Red
    "warning": 0xF39C12,  # Orange
    "info": 0x3498DB,     # Blue
}

STATUS_EMOJI = {
    "success": "✅",
    "error": "❌",
    "warning": "⚠️",
    "info": "ℹ️",
}


def api_request(token, endpoint, payload):
    """Make a Discord API request. Returns parsed JSON response."""
    url = f"{DISCORD_API}{endpoint}"
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={
        "Authorization": f"Bot {token}",
        "Content-Type": "application/json",
        "User-Agent": "TavernQuest-Notify/1.0",
    })
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"Discord API error {e.code}: {body}")
        sys.exit(1)


def get_dm_channel(token, user_id):
    """Open or retrieve existing DM channel with a user."""
    return api_request(token, "/users/@me/channels", {"recipient_id": user_id})


def send_simple(token, channel_id, message):
    """Send a plain text message."""
    return api_request(token, f"/channels/{channel_id}/messages", {"content": message})


def send_embed(token, channel_id, title, message, status="info", agent=None):
    """Send a rich embed message with color-coded status."""
    color = STATUS_COLORS.get(status, STATUS_COLORS["info"])
    emoji = STATUS_EMOJI.get(status, STATUS_EMOJI["info"])

    embed = {
        "title": f"{emoji} {title}",
        "description": message,
        "color": color,
        "footer": {"text": "Tavern Quest Notifications"},
    }

    if agent:
        embed["fields"] = [{"name": "Agent", "value": f"`{agent}`", "inline": True}]

    return api_request(token, f"/channels/{channel_id}/messages", {"embeds": [embed]})


def main():
    parser = argparse.ArgumentParser(description="Send Discord DM notification")
    parser.add_argument("quick_message", nargs="?", help="Quick plain-text message")
    parser.add_argument("-t", "--title", help="Embed title")
    parser.add_argument("-m", "--message", help="Embed message body")
    parser.add_argument("-s", "--status", choices=["success", "error", "warning", "info"],
                        default="info", help="Status color (default: info)")
    parser.add_argument("-a", "--agent", help="Agent name to display")

    args = parser.parse_args()

    if not args.quick_message and not args.title and not args.message:
        parser.print_help()
        print("\nExamples:")
        print('  python notify.py "Quick message"')
        print('  python notify.py -t "Title" -m "Details" -s success')
        print('  python notify.py -t "Done" -m "Fishing fixed" -s success -a lua-coder')
        sys.exit(1)

    config = get_config()
    token = config["DISCORD_BOT_TOKEN"]
    user_id = config["DISCORD_USER_ID"]
    server_channel_id = config.get("DISCORD_CHANNEL_ID")

    # Get DM channel
    dm = get_dm_channel(token, user_id)
    dm_channel_id = dm["id"]

    # Send to both DM and server channel
    targets = [("DM", dm_channel_id)]
    if server_channel_id:
        targets.append(("channel", server_channel_id))

    for label, ch_id in targets:
        if args.title or args.message:
            title = args.title or "Notification"
            message = args.message or args.quick_message or ""
            send_embed(token, ch_id, title, message, args.status, args.agent)
        else:
            send_simple(token, ch_id, args.quick_message)

    sent_to = " + ".join(label for label, _ in targets)
    if args.title:
        print(f"Sent embed: {args.title} ({sent_to})")
    else:
        print(f"Sent: {args.quick_message} ({sent_to})")


if __name__ == "__main__":
    main()

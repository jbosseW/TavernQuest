"""
Persistent bidirectional Discord bot for Tavern Quest.
- Receives DM commands (prefixed with !)
- Forwards plain DMs to Claude CLI and returns output
- Supports conversational sessions (back-and-forth with Claude)
- Owner-only: silently ignores all other users

Requires: discord.py >= 2.3.0
"""

import asyncio
import datetime
import json
import os
import subprocess
import sys
import textwrap

import discord
from discord.ext import commands

# Add this directory for config import
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import get_config

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
config = get_config()
TOKEN = config["DISCORD_BOT_TOKEN"]
OWNER_ID = int(config["DISCORD_USER_ID"])
PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CLAUDE_TIMEOUT = 300  # 5 minutes

AGENTS = [
    "lua-coder", "lore-writer", "senior-debugger", "balance-tester",
    "ui-designer", "upgrade-planner", "mechanics-analyst",
    "network-engineer", "project-manager",
]

# ---------------------------------------------------------------------------
# Bot setup
# ---------------------------------------------------------------------------
intents = discord.Intents.default()
intents.message_content = True

bot = commands.Bot(command_prefix="!", intents=intents)

# State
notification_history = []  # List of (timestamp, summary) tuples
claude_lock = asyncio.Lock()
claude_process = None  # Reference to running subprocess
session_id = None  # Current Claude conversation session ID
session_active = False  # Whether we're in a conversation


def is_owner(ctx_or_message):
    """Check if message is from the bot owner."""
    user_id = getattr(ctx_or_message, "author", ctx_or_message).id
    return user_id == OWNER_ID


def log_notification(summary):
    """Record a notification in history (keep last 20)."""
    notification_history.append((datetime.datetime.now(), summary))
    if len(notification_history) > 20:
        notification_history.pop(0)


async def send_chunked(dest, text, prefix=""):
    """Send text split into 2000-char Discord messages."""
    if prefix:
        text = f"{prefix}\n{text}"
    # Split on newlines first, then by length
    lines = text.split("\n")
    current_chunk = ""
    for line in lines:
        # If a single line exceeds limit, hard-wrap it
        if len(line) > 1980:
            if current_chunk:
                await dest.send(f"```\n{current_chunk}\n```")
                current_chunk = ""
            for i in range(0, len(line), 1980):
                await dest.send(f"```\n{line[i:i+1980]}\n```")
            continue

        if len(current_chunk) + len(line) + 1 > 1980:
            await dest.send(f"```\n{current_chunk}\n```")
            current_chunk = line
        else:
            current_chunk = f"{current_chunk}\n{line}" if current_chunk else line

    if current_chunk:
        await dest.send(f"```\n{current_chunk}\n```")
    elif not text.strip():
        await dest.send("(empty response)")


def parse_session_id(output):
    """Try to extract session ID from Claude CLI output."""
    # Claude CLI outputs session info in JSON when using --output-format json
    # With plain text, we look for session ID patterns in stderr
    for line in output.split("\n"):
        line = line.strip()
        # Try JSON parse
        try:
            data = json.loads(line)
            if "session_id" in data:
                return data["session_id"]
        except (json.JSONDecodeError, TypeError):
            pass
    return None


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------
@bot.event
async def on_ready():
    """Notify owner when bot comes online."""
    print(f"Bot online as {bot.user} (ID: {bot.user.id})")
    print(f"Project directory: {PROJECT_DIR}")
    try:
        owner = await bot.fetch_user(OWNER_ID)
        dm = await owner.create_dm()
        await dm.send(
            f"**Tavern Quest Bot Online**\n"
            f"Project: `{PROJECT_DIR}`\n\n"
            f"**Commands:**\n"
            f"`!ping` - Check latency\n"
            f"`!status` - Recent notifications\n"
            f"`!agents` - List Claude agents\n"
            f"`!session` - Show current conversation session\n"
            f"`!new` - Start a fresh conversation\n"
            f"`!cancel` - Kill running Claude process\n"
            f"`!notify <msg>` - Test notification\n\n"
            f"Just send a message to chat with Claude. "
            f"Conversations are maintained automatically — "
            f"each follow-up message continues the same session."
        )
    except Exception as e:
        print(f"Could not send startup DM: {e}")


@bot.event
async def on_message(message):
    """Route DMs from owner: commands go to command handler, plain text to Claude."""
    # Ignore bots
    if message.author.bot:
        return

    # Only process DMs
    if not isinstance(message.channel, discord.DMChannel):
        return

    # Owner-only
    if message.author.id != OWNER_ID:
        return

    # If it starts with command prefix, let commands handle it
    if message.content.startswith("!"):
        await bot.process_commands(message)
        return

    # Otherwise, treat as Claude prompt
    await handle_claude_prompt(message)


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
@bot.command()
async def ping(ctx):
    """Check bot latency."""
    if not is_owner(ctx):
        return
    latency = round(bot.latency * 1000)
    await ctx.send(f"Pong! Latency: {latency}ms")


@bot.command()
async def status(ctx):
    """Show recent notification history."""
    if not is_owner(ctx):
        return
    if not notification_history:
        await ctx.send("No notifications yet.")
        return

    lines = []
    for ts, summary in notification_history[-10:]:
        time_str = ts.strftime("%H:%M:%S")
        lines.append(f"`{time_str}` {summary}")
    await ctx.send("**Recent Notifications:**\n" + "\n".join(lines))


@bot.command(name="agents")
async def agents_cmd(ctx):
    """List available Claude Code agents."""
    if not is_owner(ctx):
        return
    agent_list = "\n".join(f"  `{a}`" for a in AGENTS)
    await ctx.send(f"**Available Agents ({len(AGENTS)}):**\n{agent_list}")


@bot.command(name="notify")
async def notify_cmd(ctx, *, msg: str = ""):
    """Send a test notification."""
    if not is_owner(ctx):
        return
    if not msg:
        await ctx.send("Usage: `!notify <message>`")
        return
    log_notification(f"Test: {msg}")
    await ctx.send(f"Notification logged: {msg}")


@bot.command()
async def cancel(ctx):
    """Cancel a running Claude prompt."""
    global claude_process
    if not is_owner(ctx):
        return

    if claude_process and claude_process.returncode is None:
        try:
            claude_process.terminate()
            await ctx.send("Claude process terminated.")
        except Exception as e:
            await ctx.send(f"Error terminating process: {e}")
    else:
        await ctx.send("No Claude process is currently running.")


@bot.command(name="new")
async def new_session(ctx):
    """Start a fresh Claude conversation (clears session context)."""
    global session_id, session_active
    if not is_owner(ctx):
        return
    old = session_id
    session_id = None
    session_active = False
    if old:
        await ctx.send(f"Session cleared (was `{old[:12]}...`). Next message starts a new conversation.")
    else:
        await ctx.send("No active session. Next message starts a new conversation.")


@bot.command(name="session")
async def session_info(ctx):
    """Show current conversation session info."""
    if not is_owner(ctx):
        return
    if session_id:
        await ctx.send(
            f"**Active Session:** `{session_id}`\n"
            f"Send any message to continue this conversation.\n"
            f"Use `!new` to start fresh."
        )
    else:
        await ctx.send("No active session. Send a message to start one.")


@bot.command(name="resume")
async def resume_session(ctx, sid: str = ""):
    """Resume a specific Claude session by ID."""
    global session_id, session_active
    if not is_owner(ctx):
        return
    if not sid:
        await ctx.send("Usage: `!resume <session_id>`\nGet session IDs from Claude CLI output.")
        return
    session_id = sid
    session_active = True
    await ctx.send(f"Resumed session `{sid[:20]}...`. Next message continues that conversation.")


# ---------------------------------------------------------------------------
# Claude CLI integration
# ---------------------------------------------------------------------------
async def handle_claude_prompt(message):
    """Run a Claude CLI prompt and return the output. Maintains conversation sessions."""
    global claude_process, session_id, session_active

    prompt_text = message.content.strip()
    if not prompt_text:
        return

    # Check if another prompt is running
    if claude_lock.locked():
        await message.channel.send(
            "A Claude prompt is already running. Use `!cancel` to stop it, or wait."
        )
        return

    async with claude_lock:
        # Show typing indicator
        async with message.channel.typing():
            log_notification(f"Prompt: {prompt_text[:80]}...")

            # Build command
            cmd = ["claude", "-p", prompt_text]

            # If we have an active session, continue it
            if session_id and session_active:
                cmd.extend(["--resume", session_id, "--continue"])

            # Request JSON output so we can capture session ID
            cmd.extend(["--output-format", "json"])

            try:
                # Run Claude CLI as subprocess
                loop = asyncio.get_event_loop()
                claude_process = await loop.run_in_executor(
                    None,
                    lambda: subprocess.Popen(
                        cmd,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        cwd=PROJECT_DIR,
                        text=True,
                        encoding="utf-8",
                        errors="replace",
                    )
                )

                try:
                    stdout, stderr = await asyncio.wait_for(
                        loop.run_in_executor(
                            None,
                            lambda: claude_process.communicate()
                        ),
                        timeout=CLAUDE_TIMEOUT,
                    )
                except asyncio.TimeoutError:
                    claude_process.terminate()
                    await message.channel.send(
                        f"Claude timed out after {CLAUDE_TIMEOUT}s. Process terminated."
                    )
                    log_notification(f"Timeout: {prompt_text[:60]}...")
                    return

                raw_stdout = stdout.strip() if stdout else ""
                raw_stderr = stderr.strip() if stderr else ""

                # Try to parse JSON output for session ID and result
                output_text = ""
                new_session_id = None

                try:
                    data = json.loads(raw_stdout)
                    # Claude JSON output has "result" for the text and "session_id"
                    if isinstance(data, dict):
                        output_text = data.get("result", "")
                        new_session_id = data.get("session_id")
                        # Some formats nest differently
                        if not output_text and "message" in data:
                            output_text = data.get("message", "")
                except (json.JSONDecodeError, TypeError):
                    # Fallback: treat as plain text
                    output_text = raw_stdout

                # Update session tracking
                if new_session_id:
                    session_id = new_session_id
                    session_active = True

                if claude_process.returncode != 0:
                    # On error, try to show useful info
                    error_text = raw_stderr or output_text or raw_stdout
                    if error_text:
                        await send_chunked(message.channel, error_text, prefix="**Error:**")
                    else:
                        await message.channel.send(
                            f"Claude exited with code {claude_process.returncode} (no output)."
                        )
                    log_notification(f"Error (code {claude_process.returncode}): {prompt_text[:50]}...")
                else:
                    if output_text:
                        await send_chunked(message.channel, output_text)
                    else:
                        await message.channel.send("Claude returned no output.")
                    log_notification(f"Done: {prompt_text[:60]}...")

                    # Session indicator
                    session_label = f"Session: `{session_id[:12]}...`" if session_id else "No session"
                    embed = discord.Embed(
                        title="Prompt Complete",
                        description=f"`{prompt_text[:100]}`",
                        color=0x2ECC71,
                    )
                    embed.set_footer(text=f"Tavern Quest Bot | {session_label}")
                    await message.channel.send(embed=embed)

            except FileNotFoundError:
                await message.channel.send(
                    "Error: `claude` CLI not found. Make sure it's installed and on PATH."
                )
            except Exception as e:
                await message.channel.send(f"Error running Claude: {e}")
                log_notification(f"Exception: {e}")
            finally:
                claude_process = None


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    print("Starting Tavern Quest Discord Bot...")
    print(f"Project: {PROJECT_DIR}")
    bot.run(TOKEN)

"""
Tavern Quest Automated Game Tester
===================================
Launches the LÖVE2D game, navigates menus, plays game modes,
detects crashes (LÖVE2D blue error screen), screenshots them,
and sends crash reports to Claude CLI + Discord.

Uses human-like mouse movements with smooth curves, random jitter,
and natural timing delays.

Usage:
  python tester.py                    # Test all modes
  python tester.py --mode fishing     # Test specific mode
  python tester.py --mode textrpg --duration 120   # Test for 2 min
  python tester.py --list             # List available test modes
"""

import argparse
import datetime
import json
import os
import random
import subprocess
import sys
import time
import traceback

import pyautogui
import pygetwindow as gw
from PIL import Image, ImageGrab

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
NOTIFY_SCRIPT = os.path.join(PROJECT_DIR, "tools", "discord_notify", "notify.py")
SCREENSHOT_DIR = os.path.join(PROJECT_DIR, "tools", "game_tester", "screenshots")
GAME_TITLE = "Tavern Quest"

# LÖVE2D error screen background color (approximate)
# love.errorhandler uses {0.35, 0.62, 0.86} = RGB(89, 158, 219)
CRASH_COLOR_R = (70, 110)   # Red range
CRASH_COLOR_G = (140, 180)  # Green range
CRASH_COLOR_B = (200, 240)  # Blue range
CRASH_SAMPLE_THRESHOLD = 0.6  # 60% of sampled pixels must match

# Human-like timing
CLICK_DELAY_MIN = 0.3
CLICK_DELAY_MAX = 0.8
MOVE_DURATION_MIN = 0.2
MOVE_DURATION_MAX = 0.6
THINK_PAUSE_MIN = 0.5
THINK_PAUSE_MAX = 2.0
JITTER_PIXELS = 3

# Crash check interval (seconds)
CRASH_CHECK_INTERVAL = 2.0

# Default test duration per mode (seconds)
DEFAULT_DURATION = 60

# Timeout for Claude CLI fix sessions (seconds)
CLAUDE_FIX_TIMEOUT = 600  # 10 minutes - fixing code takes longer than analysis

# Failsafe - move mouse to corner to abort
pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.05

# ---------------------------------------------------------------------------
# Game mode definitions with menu navigation paths
# ---------------------------------------------------------------------------
GAME_MODES = {
    "textrpg": {
        "name": "Tavern Quest",
        "nav": "main_menu_tavern_quest",
        "description": "Main RPG adventure mode",
        "gameplay": "rpg",
    },
    "fishing": {
        "name": "Fishing",
        "nav": "game_modes_menu",
        "mode_id": "fishing",
        "description": "Fishing mini-game",
        "gameplay": "minigame",
    },
    "forge": {
        "name": "Blacksmith Forge",
        "nav": "game_modes_menu",
        "mode_id": "forge",
        "description": "Blacksmithing crafting",
        "gameplay": "minigame",
    },
    "alchemist": {
        "name": "Alchemist",
        "nav": "game_modes_menu",
        "mode_id": "alchemist",
        "description": "Potion brewing",
        "gameplay": "minigame",
    },
    "hunting": {
        "name": "Hunting",
        "nav": "game_modes_menu",
        "mode_id": "hunting",
        "description": "Wilderness hunting",
        "gameplay": "minigame",
    },
    "cafegame": {
        "name": "Wage Job (Cafe)",
        "nav": "game_modes_menu",
        "mode_id": "cafe_game",
        "description": "Cafe simulation",
        "gameplay": "minigame",
    },
    "wizardtower": {
        "name": "Wizard Tower",
        "nav": "game_modes_menu",
        "mode_id": "wizardtower",
        "description": "Spell crafting",
        "gameplay": "minigame",
    },
    "petsim": {
        "name": "Wilds Rancher",
        "nav": "game_modes_menu",
        "mode_id": "pet_sim",
        "description": "Pet simulation",
        "gameplay": "minigame",
    },
    "stockmarket": {
        "name": "Trading Post",
        "nav": "game_modes_menu",
        "mode_id": "stock_market",
        "description": "Stock market trading",
        "gameplay": "minigame",
    },
    "standard": {
        "name": "Standard Poker",
        "nav": "game_modes_menu",
        "mode_id": "standard",
        "description": "Card battle",
        "gameplay": "card_game",
    },
    "endlessmode": {
        "name": "Endless Poker",
        "nav": "game_modes_menu",
        "mode_id": "endless_mode",
        "description": "Roguelike poker",
        "gameplay": "card_game",
    },
}


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
class Logger:
    def __init__(self):
        self.entries = []

    def log(self, msg, level="INFO"):
        ts = datetime.datetime.now().strftime("%H:%M:%S")
        entry = f"[{ts}] [{level}] {msg}"
        print(entry)
        self.entries.append(entry)

    def info(self, msg):
        self.log(msg, "INFO")

    def warn(self, msg):
        self.log(msg, "WARN")

    def error(self, msg):
        self.log(msg, "ERROR")

    def action(self, msg):
        self.log(msg, "ACTION")

    def get_log_text(self):
        return "\n".join(self.entries)


log = Logger()


# ---------------------------------------------------------------------------
# Human-like input simulation
# ---------------------------------------------------------------------------
def human_delay(min_s=CLICK_DELAY_MIN, max_s=CLICK_DELAY_MAX):
    """Wait a random human-like delay."""
    time.sleep(random.uniform(min_s, max_s))


def think_pause():
    """Simulate a longer 'thinking' pause."""
    time.sleep(random.uniform(THINK_PAUSE_MIN, THINK_PAUSE_MAX))


def jitter(x, y, amount=JITTER_PIXELS):
    """Add slight random offset to coordinates."""
    return (
        x + random.randint(-amount, amount),
        y + random.randint(-amount, amount),
    )


def smooth_move(x, y):
    """Move mouse smoothly to target with human-like duration."""
    jx, jy = jitter(x, y)
    duration = random.uniform(MOVE_DURATION_MIN, MOVE_DURATION_MAX)
    pyautogui.moveTo(jx, jy, duration=duration, tween=pyautogui.easeOutQuad)


def human_click(x, y, button="left"):
    """Click at position with human-like movement and timing."""
    smooth_move(x, y)
    human_delay(0.05, 0.15)
    pyautogui.click(button=button)
    human_delay()
    log.action(f"Clicked ({x}, {y})")


def human_press(key):
    """Press a key with human-like timing."""
    human_delay(0.1, 0.3)
    pyautogui.press(key)
    human_delay(0.1, 0.3)
    log.action(f"Pressed '{key}'")


def human_type(text, interval=0.05):
    """Type text with human-like speed."""
    pyautogui.typewrite(text, interval=interval + random.uniform(0, 0.03))
    log.action(f"Typed '{text[:30]}...'")


# ---------------------------------------------------------------------------
# Window management
# ---------------------------------------------------------------------------
def find_game_window():
    """Find the Tavern Quest game window. Returns window object or None."""
    windows = gw.getWindowsWithTitle(GAME_TITLE)
    if windows:
        return windows[0]
    # Also try partial match
    for w in gw.getAllWindows():
        if GAME_TITLE.lower() in w.title.lower():
            return w
    return None


def focus_game_window(win):
    """Bring game window to foreground."""
    try:
        if win.isMinimized:
            win.restore()
        win.activate()
        time.sleep(0.5)
        return True
    except Exception as e:
        log.warn(f"Could not focus window: {e}")
        return False


def get_window_rect(win):
    """Get window client area as (left, top, width, height)."""
    return win.left, win.top, win.width, win.height


def game_to_screen(win, game_x, game_y, game_w=1280, game_h=720):
    """Convert game coordinates (1280x720 space) to screen coordinates."""
    wl, wt, ww, wh = get_window_rect(win)
    # Account for window borders/title bar
    # Approximate: title bar ~30px on Windows
    client_top = wt + 30
    client_left = wl + 8
    client_w = ww - 16
    client_h = wh - 38

    scale_x = client_w / game_w
    scale_y = client_h / game_h

    screen_x = client_left + int(game_x * scale_x)
    screen_y = client_top + int(game_y * scale_y)
    return screen_x, screen_y


def game_to_screen_fullscreen(game_x, game_y, game_w=1280, game_h=720):
    """Convert game coords to screen coords in fullscreen mode."""
    screen_w, screen_h = pyautogui.size()
    scale_x = screen_w / game_w
    scale_y = screen_h / game_h
    return int(game_x * scale_x), int(game_y * scale_y)


# ---------------------------------------------------------------------------
# Screen capture and crash detection
# ---------------------------------------------------------------------------
def capture_screen(region=None):
    """Capture screen or region. Returns PIL Image."""
    return ImageGrab.grab(bbox=region)


def capture_game_window(win):
    """Capture just the game window area."""
    wl, wt, ww, wh = get_window_rect(win)
    return ImageGrab.grab(bbox=(wl, wt, wl + ww, wt + wh))


def save_screenshot(img, prefix="crash"):
    """Save screenshot to disk. Returns file path."""
    os.makedirs(SCREENSHOT_DIR, exist_ok=True)
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    path = os.path.join(SCREENSHOT_DIR, f"{prefix}_{ts}.png")
    img.save(path)
    log.info(f"Screenshot saved: {path}")
    return path


def is_crash_screen(img):
    """
    Detect LÖVE2D blue error screen by sampling pixels.
    The error screen has a distinctive blue background ~RGB(89, 158, 219).
    """
    width, height = img.size
    sample_count = 0
    match_count = 0

    # Sample a grid of pixels across the image
    step_x = max(1, width // 20)
    step_y = max(1, height // 20)

    for x in range(0, width, step_x):
        for y in range(0, height, step_y):
            r, g, b = img.getpixel((x, y))[:3]
            sample_count += 1
            if (CRASH_COLOR_R[0] <= r <= CRASH_COLOR_R[1] and
                    CRASH_COLOR_G[0] <= g <= CRASH_COLOR_G[1] and
                    CRASH_COLOR_B[0] <= b <= CRASH_COLOR_B[1]):
                match_count += 1

    if sample_count == 0:
        return False

    ratio = match_count / sample_count
    if ratio >= CRASH_SAMPLE_THRESHOLD:
        log.warn(f"Crash screen detected! ({ratio:.0%} blue pixel match)")
        return True
    return False


def is_game_running(process):
    """Check if the game process is still running."""
    if process is None:
        return False
    return process.poll() is None


# ---------------------------------------------------------------------------
# Game launching
# ---------------------------------------------------------------------------
def launch_game(windowed=True):
    """Launch the LÖVE2D game. Returns subprocess.Popen."""
    love_path = "love"  # Assumes love is on PATH
    game_path = PROJECT_DIR

    log.info(f"Launching game from: {game_path}")

    # Try to find love executable
    possible_paths = [
        "love",
        r"C:\Program Files\LOVE\love.exe",
        r"C:\Program Files (x86)\LOVE\love.exe",
        os.path.expanduser(r"~\AppData\Local\Programs\LOVE\love.exe"),
    ]

    love_exe = None
    for p in possible_paths:
        try:
            result = subprocess.run([p, "--version"], capture_output=True, timeout=5)
            if result.returncode == 0:
                love_exe = p
                break
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue

    if not love_exe:
        log.error("LÖVE2D not found. Install it and add to PATH.")
        return None

    log.info(f"Using LÖVE: {love_exe}")

    proc = subprocess.Popen(
        [love_exe, game_path],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=game_path,
    )

    # Wait for window to appear
    log.info("Waiting for game window...")
    for _ in range(30):  # 15 seconds max
        time.sleep(0.5)
        win = find_game_window()
        if win:
            log.info(f"Game window found: {win.title} ({win.width}x{win.height})")
            time.sleep(1)  # Let it fully initialize
            return proc

    log.error("Game window did not appear within 15 seconds.")
    proc.terminate()
    return None


# ---------------------------------------------------------------------------
# Navigation actions
# ---------------------------------------------------------------------------
class GameNavigator:
    """Handles menu navigation with human-like input."""

    def __init__(self, win, fullscreen=False):
        self.win = win
        self.fullscreen = fullscreen
        self._detect_game_dimensions()

    def _detect_game_dimensions(self):
        """Detect actual game rendering dimensions."""
        if self.fullscreen:
            self.screen_w, self.screen_h = pyautogui.size()
        else:
            _, _, self.screen_w, self.screen_h = get_window_rect(self.win)
        # Game designs for 1280x720 base
        self.game_w = 1280
        self.game_h = 720
        log.info(f"Game dimensions: {self.screen_w}x{self.screen_h} "
                 f"(base: {self.game_w}x{self.game_h})")

    def click_game(self, game_x, game_y):
        """Click at game-space coordinates."""
        if self.fullscreen:
            sx, sy = game_to_screen_fullscreen(game_x, game_y, self.game_w, self.game_h)
        else:
            sx, sy = game_to_screen(self.win, game_x, game_y, self.game_w, self.game_h)
        human_click(sx, sy)

    def click_center(self):
        """Click center of screen."""
        self.click_game(self.game_w // 2, self.game_h // 2)

    def press_key(self, key):
        """Press a key."""
        human_press(key)

    def go_to_main_menu(self):
        """Navigate back to main menu via ESC."""
        log.info("Navigating to main menu...")
        self.press_key("escape")
        think_pause()
        # If pause menu appeared, look for Menu button
        # Pause menu "Menu" button is typically at center
        self.click_game(self.game_w // 2, 360)
        think_pause()

    def click_tavern_quest(self):
        """Click the 'Tavern Quest' button on main menu."""
        log.info("Clicking 'Tavern Quest' button...")
        # Main menu: "Tavern Quest" at (screenW/2 - 90, 510), size 180x45
        btn_x = self.game_w // 2
        btn_y = 532  # Center of button (510 + 45/2)
        self.click_game(btn_x, btn_y)
        think_pause()

    def scroll_down(self, amount=3):
        """Scroll down in a menu."""
        pyautogui.scroll(-amount)
        human_delay(0.2, 0.4)

    def scroll_up(self, amount=3):
        """Scroll up in a menu."""
        pyautogui.scroll(amount)
        human_delay(0.2, 0.4)


# ---------------------------------------------------------------------------
# Gameplay simulation
# ---------------------------------------------------------------------------
class GamePlayer:
    """Simulates basic gameplay interactions."""

    def __init__(self, nav):
        self.nav = nav

    def random_clicks(self, duration=10, area=None):
        """Click randomly within game area for a duration."""
        start = time.time()
        while time.time() - start < duration:
            if area:
                x = random.randint(area[0], area[2])
                y = random.randint(area[1], area[3])
            else:
                x = random.randint(100, self.nav.game_w - 100)
                y = random.randint(100, self.nav.game_h - 100)
            self.nav.click_game(x, y)
            think_pause()

    def explore_ui(self, duration=10):
        """Click around the UI trying buttons and interactive elements."""
        start = time.time()
        # Common interactive regions
        regions = [
            (50, 50, 300, 200),      # Top-left area
            (400, 100, 900, 400),     # Center area
            (50, 500, 400, 680),      # Bottom-left
            (900, 500, 1230, 680),    # Bottom-right
            (500, 300, 800, 500),     # Dead center
        ]
        while time.time() - start < duration:
            region = random.choice(regions)
            x = random.randint(region[0], region[2])
            y = random.randint(region[1], region[3])
            self.nav.click_game(x, y)
            # Occasionally press keys
            if random.random() < 0.2:
                key = random.choice(["space", "enter", "e", "1", "2", "3"])
                self.nav.press_key(key)
            think_pause()

    def play_rpg(self, duration=30):
        """Simulate RPG gameplay - click through dialogs, make choices."""
        log.info("Playing RPG mode...")
        start = time.time()
        while time.time() - start < duration:
            # Click center to advance dialog
            self.nav.click_game(640, 500)
            human_delay(0.5, 1.5)

            # Sometimes click on choice buttons (typically in lower half)
            if random.random() < 0.4:
                choice_y = random.randint(400, 650)
                choice_x = random.randint(200, 1080)
                self.nav.click_game(choice_x, choice_y)

            # Occasionally press keys for navigation
            if random.random() < 0.2:
                key = random.choice(["space", "enter", "1", "2", "3", "4"])
                self.nav.press_key(key)

            think_pause()

    def play_minigame(self, duration=30):
        """Simulate minigame gameplay - more active clicking."""
        log.info("Playing minigame...")
        start = time.time()
        while time.time() - start < duration:
            # Click in the main game area
            x = random.randint(200, 1080)
            y = random.randint(150, 600)
            self.nav.click_game(x, y)
            human_delay(0.3, 0.8)

            # Rapid clicks sometimes (for timing-based games)
            if random.random() < 0.3:
                for _ in range(random.randint(2, 5)):
                    x = random.randint(400, 900)
                    y = random.randint(200, 550)
                    self.nav.click_game(x, y)
                    human_delay(0.1, 0.3)

            if random.random() < 0.15:
                key = random.choice(["space", "enter", "e", "escape"])
                self.nav.press_key(key)

    def play_card_game(self, duration=30):
        """Simulate card game - select cards, confirm plays."""
        log.info("Playing card game...")
        start = time.time()
        while time.time() - start < duration:
            # Click on card positions (lower half of screen)
            x = random.randint(200, 1080)
            y = random.randint(450, 650)
            self.nav.click_game(x, y)
            human_delay(0.5, 1.0)

            # Click confirm/play buttons
            if random.random() < 0.3:
                self.nav.click_game(640, 680)
                human_delay(0.3, 0.6)

            # Click on opponent area sometimes
            if random.random() < 0.2:
                x = random.randint(300, 980)
                y = random.randint(100, 300)
                self.nav.click_game(x, y)

            think_pause()


# ---------------------------------------------------------------------------
# Crash handling
# ---------------------------------------------------------------------------
def handle_crash(win, proc, mode_name, test_log):
    """Handle a detected crash: screenshot, notify Discord, send to Claude."""
    log.error(f"CRASH DETECTED in mode: {mode_name}")

    # Capture screenshot
    if win:
        img = capture_game_window(win)
    else:
        img = capture_screen()

    screenshot_path = save_screenshot(img, prefix=f"crash_{mode_name}")

    # Send Discord notification
    try:
        subprocess.run([
            sys.executable, NOTIFY_SCRIPT,
            "-t", f"CRASH: {mode_name}",
            "-m", f"Game crashed in {mode_name} mode. Screenshot saved. Sending to Claude for analysis.",
            "-s", "error",
            "-a", "game-tester",
        ], timeout=15, cwd=PROJECT_DIR)
    except Exception as e:
        log.warn(f"Discord notification failed: {e}")

    # Send to Claude CLI to diagnose AND fix the crash
    log.info("Spawning Claude CLI session to fix the crash...")
    try:
        prompt = (
            f"AUTOMATED CRASH REPORT - FIX THIS BUG\n"
            f"{'=' * 50}\n\n"
            f"The LÖVE2D game 'Tavern Quest' crashed while automated testing was running "
            f"the '{mode_name}' mode.\n\n"
            f"A screenshot of the LÖVE2D blue error screen has been saved to:\n"
            f"  {screenshot_path}\n\n"
            f"Read that screenshot to see the exact error message and stack trace.\n\n"
            f"YOUR TASK:\n"
            f"1. Read the screenshot to get the error message and stack trace\n"
            f"2. Open and read the source file(s) mentioned in the stack trace\n"
            f"3. Identify the root cause of the crash\n"
            f"4. IMPLEMENT THE FIX by editing the source files directly\n"
            f"5. Verify your fix doesn't break other code that calls the same functions\n"
            f"6. Run: python {NOTIFY_SCRIPT} -t \"Bug Fixed: {mode_name}\" "
            f"-m \"<describe what you fixed>\" -s success -a senior-debugger\n\n"
            f"Do NOT just analyze the error. Actually fix it in the source code.\n\n"
            f"Test log from the automated tester:\n{test_log[-2000:]}"
        )

        # Run Claude CLI with full tool access so it can edit files
        claude_proc = subprocess.Popen(
            ["claude", "-p", prompt],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=PROJECT_DIR,
        )

        try:
            stdout, stderr = claude_proc.communicate(timeout=CLAUDE_FIX_TIMEOUT)
        except subprocess.TimeoutExpired:
            claude_proc.terminate()
            log.warn(f"Claude fix session timed out after {CLAUDE_FIX_TIMEOUT}s.")
            try:
                subprocess.run([
                    sys.executable, NOTIFY_SCRIPT,
                    "-t", f"Fix Timeout: {mode_name}",
                    "-m", f"Claude timed out trying to fix the crash. Manual intervention needed.",
                    "-s", "warning",
                    "-a", "game-tester",
                ], timeout=15, cwd=PROJECT_DIR)
            except Exception:
                pass
            return None

        output = stdout.strip() if stdout else ""

        # Save the full Claude output
        fix_log_path = screenshot_path.replace(".png", "_fix_log.txt")
        with open(fix_log_path, "w", encoding="utf-8") as f:
            f.write(f"Crash Fix Session for: {mode_name}\n")
            f.write(f"Time: {datetime.datetime.now()}\n")
            f.write(f"Screenshot: {screenshot_path}\n")
            f.write(f"Exit code: {claude_proc.returncode}\n")
            f.write(f"{'=' * 60}\n\n")
            f.write(output)
        log.info(f"Fix session log saved: {fix_log_path}")

        if claude_proc.returncode == 0 and output:
            log.info("Claude fix session completed.")

            # Send summary to Discord
            summary = output[-500:] if len(output) > 500 else output
            try:
                subprocess.run([
                    sys.executable, NOTIFY_SCRIPT,
                    "-t", f"Fix Applied: {mode_name}",
                    "-m", f"Claude attempted to fix the crash. Check fix log:\n{fix_log_path}",
                    "-s", "info",
                    "-a", "game-tester",
                ], timeout=15, cwd=PROJECT_DIR)
            except Exception:
                pass

            return output
        else:
            log.warn(f"Claude fix session failed (exit code {claude_proc.returncode}).")
            return None

    except FileNotFoundError:
        log.warn("Claude CLI not found on PATH.")
        return None
    except Exception as e:
        log.error(f"Error running Claude fix session: {e}")
        return None


# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------
def run_test(mode_key, duration=DEFAULT_DURATION, proc=None):
    """Run a test on a specific game mode."""
    mode = GAME_MODES.get(mode_key)
    if not mode:
        log.error(f"Unknown mode: {mode_key}")
        return False

    log.info(f"{'=' * 50}")
    log.info(f"TESTING: {mode['name']} ({mode_key})")
    log.info(f"Duration: {duration}s")
    log.info(f"{'=' * 50}")

    # Find game window
    win = find_game_window()
    if not win:
        log.error("Game window not found. Is the game running?")
        return False

    fullscreen = (win.width == pyautogui.size()[0] and
                  win.height == pyautogui.size()[1])

    focus_game_window(win)
    nav = GameNavigator(win, fullscreen=fullscreen)
    player = GamePlayer(nav)

    # Navigate to the mode
    think_pause()

    if mode["nav"] == "main_menu_tavern_quest":
        nav.click_tavern_quest()
    else:
        # For other modes, we'd navigate through the game modes menu
        # For now, click Tavern Quest as the primary entry point
        nav.click_tavern_quest()

    think_pause()

    # Play the mode and monitor for crashes
    start_time = time.time()
    crash_detected = False
    last_crash_check = time.time()

    gameplay_func = {
        "rpg": player.play_rpg,
        "minigame": player.play_minigame,
        "card_game": player.play_card_game,
    }.get(mode.get("gameplay", "minigame"), player.explore_ui)

    log.info(f"Starting gameplay simulation ({mode.get('gameplay', 'generic')})...")

    while time.time() - start_time < duration:
        # Check for crash periodically
        if time.time() - last_crash_check >= CRASH_CHECK_INTERVAL:
            try:
                win = find_game_window()
                if win:
                    img = capture_game_window(win)
                    if is_crash_screen(img):
                        crash_detected = True
                        handle_crash(win, proc, mode["name"], log.get_log_text())
                        break
                else:
                    # Window gone - game probably crashed hard
                    log.error("Game window disappeared - possible hard crash")
                    img = capture_screen()
                    save_screenshot(img, prefix=f"hardcrash_{mode_key}")
                    try:
                        subprocess.run([
                            sys.executable, NOTIFY_SCRIPT,
                            "-t", f"HARD CRASH: {mode['name']}",
                            "-m", "Game window disappeared. Process may have terminated.",
                            "-s", "error",
                            "-a", "game-tester",
                        ], timeout=15, cwd=PROJECT_DIR)
                    except Exception:
                        pass
                    crash_detected = True
                    break
            except Exception as e:
                log.warn(f"Error during crash check: {e}")
            last_crash_check = time.time()

        # Check if game process died
        if proc and not is_game_running(proc):
            log.error("Game process terminated unexpectedly.")
            img = capture_screen()
            save_screenshot(img, prefix=f"terminated_{mode_key}")
            crash_detected = True
            break

        # Play a short burst
        remaining = duration - (time.time() - start_time)
        burst = min(5, remaining)
        if burst > 0:
            try:
                gameplay_func(duration=burst)
            except pyautogui.FailSafeException:
                log.warn("Failsafe triggered - mouse moved to corner. Aborting.")
                return False

    elapsed = time.time() - start_time

    if crash_detected:
        log.error(f"Test FAILED: {mode['name']} crashed after {elapsed:.0f}s")
        return False
    else:
        log.info(f"Test PASSED: {mode['name']} ran {elapsed:.0f}s without crash")
        # Notify success
        try:
            subprocess.run([
                sys.executable, NOTIFY_SCRIPT,
                "-t", f"Test Passed: {mode['name']}",
                "-m", f"Ran for {elapsed:.0f}s without crashing.",
                "-s", "success",
                "-a", "game-tester",
            ], timeout=15, cwd=PROJECT_DIR)
        except Exception:
            pass
        return True


def run_all_tests(duration_per_mode=DEFAULT_DURATION):
    """Run tests on all game modes sequentially."""
    log.info("=" * 60)
    log.info("TAVERN QUEST AUTOMATED TEST SUITE")
    log.info(f"Modes to test: {len(GAME_MODES)}")
    log.info(f"Duration per mode: {duration_per_mode}s")
    log.info("=" * 60)

    # Launch game
    proc = launch_game()
    if not proc:
        log.error("Failed to launch game. Aborting.")
        return

    # Wait for game to fully load
    time.sleep(3)

    results = {}
    for mode_key in GAME_MODES:
        try:
            passed = run_test(mode_key, duration=duration_per_mode, proc=proc)
            results[mode_key] = "PASS" if passed else "FAIL"
        except pyautogui.FailSafeException:
            log.warn("Failsafe triggered. Stopping all tests.")
            break
        except Exception as e:
            log.error(f"Error testing {mode_key}: {e}")
            results[mode_key] = "ERROR"

        # Return to main menu between tests
        try:
            win = find_game_window()
            if win:
                nav = GameNavigator(win)
                nav.go_to_main_menu()
                think_pause()
        except Exception:
            pass

    # Summary
    log.info("\n" + "=" * 60)
    log.info("TEST RESULTS SUMMARY")
    log.info("=" * 60)
    for mode_key, result in results.items():
        mode_name = GAME_MODES[mode_key]["name"]
        icon = "PASS" if result == "PASS" else "FAIL"
        log.info(f"  [{icon}] {mode_name}")

    passed = sum(1 for r in results.values() if r == "PASS")
    total = len(results)
    log.info(f"\nTotal: {passed}/{total} passed")

    # Send summary to Discord
    summary_lines = [f"{'PASS' if r == 'PASS' else 'FAIL'} - {GAME_MODES[k]['name']}"
                     for k, r in results.items()]
    try:
        subprocess.run([
            sys.executable, NOTIFY_SCRIPT,
            "-t", f"Test Suite: {passed}/{total} passed",
            "-m", "\n".join(summary_lines),
            "-s", "success" if passed == total else "warning",
            "-a", "game-tester",
        ], timeout=15, cwd=PROJECT_DIR)
    except Exception:
        pass

    # Save full log
    os.makedirs(SCREENSHOT_DIR, exist_ok=True)
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    log_path = os.path.join(SCREENSHOT_DIR, f"test_log_{ts}.txt")
    with open(log_path, "w", encoding="utf-8") as f:
        f.write(log.get_log_text())
    log.info(f"Full log saved: {log_path}")

    # Clean up
    if proc and is_game_running(proc):
        log.info("Leaving game running.")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Tavern Quest Automated Game Tester")
    parser.add_argument("--mode", "-m", help="Test a specific game mode")
    parser.add_argument("--duration", "-d", type=int, default=DEFAULT_DURATION,
                        help=f"Test duration in seconds (default: {DEFAULT_DURATION})")
    parser.add_argument("--list", "-l", action="store_true",
                        help="List available game modes")
    parser.add_argument("--no-launch", action="store_true",
                        help="Don't launch game (attach to already running)")
    parser.add_argument("--all", "-a", action="store_true",
                        help="Test all modes sequentially")

    args = parser.parse_args()

    if args.list:
        print("Available test modes:")
        print("-" * 50)
        for key, mode in GAME_MODES.items():
            print(f"  {key:15s} - {mode['name']:20s} ({mode['description']})")
        return

    print("=" * 60)
    print("  TAVERN QUEST AUTOMATED GAME TESTER")
    print("  Move mouse to any corner to ABORT (failsafe)")
    print("=" * 60)
    print()

    if args.all:
        run_all_tests(duration_per_mode=args.duration)
    elif args.mode:
        if args.mode not in GAME_MODES:
            print(f"Unknown mode: {args.mode}")
            print(f"Available: {', '.join(GAME_MODES.keys())}")
            return

        proc = None
        if not args.no_launch:
            proc = launch_game()
            if not proc:
                return
            time.sleep(3)

        run_test(args.mode, duration=args.duration, proc=proc)
    else:
        # Default: test Tavern Quest RPG mode
        proc = None
        if not args.no_launch:
            proc = launch_game()
            if not proc:
                return
            time.sleep(3)

        run_test("textrpg", duration=args.duration, proc=proc)


if __name__ == "__main__":
    main()

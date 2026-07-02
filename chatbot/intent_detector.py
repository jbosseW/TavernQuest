"""Intent detection for player messages."""
import json
import logging
import re
from pathlib import Path
from typing import List, Set

logger = logging.getLogger(__name__)

_GREETING_PATTERNS = [
    r"\b(hi|hello|hey|greetings|howdy|yo|hail|salutations|sup|heya|hiya)\b",
    r"\bgood\s+(morning|day|evening|afternoon|night)\b",
    r"\bwell\s+met\b",
    r"\bhow\s+are\s+you\b",
    r"\bwhat.?s\s+up\b",
]

_FAREWELL_PATTERNS = [
    r"\b(bye|goodbye|farewell|cya|laterz?)\b",
    r"\bsee\s+(you|ya)\b",
    r"\btake\s+care\b",
    r"\bgood\s*night\b",
    r"\buntil\s+(next|we\s+meet)\b",
    r"\bgotta\s+go\b",
    r"\bso\s+long\b",
]

_THANKS_PATTERNS = [
    r"\b(thanks?|thankyou|thx|ty)\b",
    r"\b(grateful|appreciate|cheers)\b",
    r"\bthank\s+(you|ye|ya)\b",
    r"\bmuch\s+obliged\b",
]

_QUESTION_STARTERS = [
    r"^\s*(who|what|where|when|why|how|do|does|did|can|could|is|are|will|would|should|shall|may|might)\b",
]


class IntentDetector:
    """Detects conversational intent from raw player messages."""

    def __init__(self, data_dir: Path) -> None:
        """Initialize the intent detector and load insult words."""
        self._insult_words: Set[str] = set()
        self._load_insults(data_dir / "insults.json")
        self._greeting_re = [re.compile(p, re.IGNORECASE) for p in _GREETING_PATTERNS]
        self._farewell_re = [re.compile(p, re.IGNORECASE) for p in _FAREWELL_PATTERNS]
        self._thanks_re = [re.compile(p, re.IGNORECASE) for p in _THANKS_PATTERNS]
        self._question_re = [re.compile(p, re.IGNORECASE) for p in _QUESTION_STARTERS]

    def _load_insults(self, filepath: Path) -> None:
        """Load insult words from a JSON file."""
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                raw = json.load(f)
            if isinstance(raw, list):
                self._insult_words = {w.lower() for w in raw if isinstance(w, str)}
                logger.info("Loaded %d insult words", len(self._insult_words))
        except FileNotFoundError:
            logger.warning("Insults file not found: %s", filepath)
        except json.JSONDecodeError as e:
            logger.error("Failed to parse insults: %s", e)

    def _check_patterns(self, text: str, patterns: List[re.Pattern]) -> bool:
        """Check if any pattern matches the text."""
        for pattern in patterns:
            if pattern.search(text):
                return True
        return False

    def _check_insult(self, text: str) -> bool:
        """Check if the text contains insult words."""
        words = re.findall(r"[a-z]+", text.lower())
        for word in words:
            if word in self._insult_words:
                return True
        return False

    def _check_question(self, text: str) -> bool:
        """Check if the text is a question."""
        if text.rstrip().endswith("?"):
            return True
        return self._check_patterns(text, self._question_re)

    def detect(self, text: str) -> str:
        """Detect the intent of a player message."""
        if not text or not text.strip():
            return "statement"
        clean = text.strip()
        if self._check_patterns(clean, self._greeting_re):
            return "greeting"
        if self._check_patterns(clean, self._farewell_re):
            return "farewell"
        if self._check_patterns(clean, self._thanks_re):
            return "thanks"
        if self._check_insult(clean):
            return "insult"
        if self._check_question(clean):
            return "question"
        return "statement"

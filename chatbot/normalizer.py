"""Text normalization for the chatbot engine.

Handles contraction expansion, punctuation stripping, simple stemming,
and stop word removal to produce clean token lists for keyword matching.
"""
import json
import logging
import re
from pathlib import Path
from typing import Dict, List, Set

logger = logging.getLogger(__name__)

STOP_WORDS: Set[str] = {
    "the", "a", "an", "is", "are", "am", "was", "were",
    "be", "been", "being", "have", "has", "had", "do", "does",
    "did", "will", "would", "could", "should", "shall", "may", "might",
    "can", "this", "that", "these", "those", "it", "its", "i",
    "me", "my", "we", "our", "you", "your", "he", "she",
    "they", "them", "their", "of", "in", "on", "at", "to",
    "for", "with", "by", "from", "and", "or", "but", "not",
    "so", "very", "just", "also", "too", "about", "up", "out",
    "if", "then", "than", "into", "some", "any", "each", "every",
    "all", "both", "few", "more", "most", "other", "such", "no",
    "nor", "only", "own", "same", "here", "there", "when", "where",
    "why", "how", "what", "which", "who",
}

_SUFFIXES: List[str] = [
    "tion", "ment", "ness", "able", "ible", "ing", "est", "er", "ed", "ly",
    "ies", "es", "s",
]


class Normalizer:
    """Normalizes player input text into clean token lists for keyword matching."""

    def __init__(self, data_dir: Path) -> None:
        """Initialize the normalizer and load contraction data."""
        self._contractions: Dict[str, str] = {}
        self._load_contractions(data_dir / "contractions.json")

    def _load_contractions(self, filepath: Path) -> None:
        """Load contraction mappings from a JSON file."""
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                raw = json.load(f)
            if isinstance(raw, dict):
                self._contractions = {k.lower(): v.lower() for k, v in raw.items()}
                logger.info("Loaded %d contractions", len(self._contractions))
            else:
                logger.warning("Contractions file unexpected format: %s", filepath)
        except FileNotFoundError:
            logger.warning("Contractions file not found: %s", filepath)
        except json.JSONDecodeError as e:
            logger.error("Failed to parse contractions: %s", e)

    def _expand_contractions(self, text: str) -> str:
        """Expand contractions in the given text."""
        words = text.split()
        expanded = []
        for word in words:
            clean = word.strip(".,!?;:()").lower()
            if clean in self._contractions:
                expanded.append(self._contractions[clean])
            else:
                expanded.append(word)
        return " ".join(expanded)

    @staticmethod
    def _strip_punctuation(text: str) -> str:
        """Remove punctuation except apostrophes within words."""
        cleaned = re.sub(r"[^\w\s']", " ", text)
        cleaned = re.sub(r"(?<!\w)'|'(?!\w)", " ", cleaned)
        cleaned = re.sub(r"\s+", " ", cleaned)
        return cleaned.strip()

    @staticmethod
    def _stem_word(word: str) -> str:
        """Apply simple suffix stripping to a word."""
        for suffix in _SUFFIXES:
            if word.endswith(suffix) and len(word) - len(suffix) >= 3:
                return word[: -len(suffix)]
        return word

    def normalize(self, text: str) -> List[str]:
        """Normalize input text into a list of clean, stemmed tokens."""
        if not text or not text.strip():
            return []
        result = text.lower()
        result = self._expand_contractions(result)
        result = self._strip_punctuation(result)
        tokens = result.split()
        tokens = [self._stem_word(t) for t in tokens]
        tokens = [t for t in tokens if t and t not in STOP_WORDS]
        return tokens

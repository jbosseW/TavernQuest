"""Keyword matching engine with synonym support and fuzzy matching.

Scores player input tokens against topic keywords using direct matches,
synonym lookups, substring containment, and Levenshtein distance.
"""
import json
import logging
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

logger = logging.getLogger(__name__)

SCORE_DIRECT: float = 1.0
SCORE_SYNONYM: float = 0.7
SCORE_SUBSTRING: float = 0.4
SCORE_FUZZY: float = 0.3
MIN_SUBSTRING_LEN: int = 4
MIN_FUZZY_WORD_LEN: int = 5
MAX_FUZZY_DISTANCE: int = 2
MIN_TOPIC_SCORE: float = 0.2


def levenshtein_distance(s1: str, s2: str) -> int:
    """Compute the Levenshtein edit distance between two strings."""
    if len(s1) < len(s2):
        return levenshtein_distance(s2, s1)
    if len(s2) == 0:
        return len(s1)
    previous_row = list(range(len(s2) + 1))
    for i, c1 in enumerate(s1):
        current_row = [i + 1]
        for j, c2 in enumerate(s2):
            insertions = previous_row[j + 1] + 1
            deletions = current_row[j] + 1
            substitutions = previous_row[j] + (0 if c1 == c2 else 1)
            current_row.append(min(insertions, deletions, substitutions))
        previous_row = current_row
    return previous_row[-1]


class KeywordMatcher:
    """Matches player input tokens against topic keywords with synonym support."""

    def __init__(self, data_dir: Path) -> None:
        """Initialize the matcher and load synonym data."""
        self._word_to_groups: Dict[str, Set[str]] = {}
        self._group_words: Dict[str, Set[str]] = {}
        self._load_synonyms(data_dir / "synonyms.json")

    def _load_synonyms(self, filepath: Path) -> None:
        """Load synonym groups from a JSON file."""
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                raw = json.load(f)
            if not isinstance(raw, dict):
                logger.warning("Synonyms file unexpected format: %s", filepath)
                return
            for group_name, words in raw.items():
                if not isinstance(words, list):
                    continue
                word_set = {w.lower() for w in words if isinstance(w, str)}
                self._group_words[group_name] = word_set
                for word in word_set:
                    if word not in self._word_to_groups:
                        self._word_to_groups[word] = set()
                    self._word_to_groups[word].add(group_name)
            logger.info("Loaded %d synonym groups", len(self._group_words))
        except FileNotFoundError:
            logger.warning("Synonyms file not found: %s", filepath)
        except json.JSONDecodeError as e:
            logger.error("Failed to parse synonyms: %s", e)

    def _are_synonyms(self, word1: str, word2: str) -> bool:
        """Check if two words share a synonym group."""
        groups1 = self._word_to_groups.get(word1, set())
        groups2 = self._word_to_groups.get(word2, set())
        return bool(groups1 & groups2)

    def match(self, tokens: List[str], topic_keywords: List[str]) -> float:
        """Score how well tokens match topic keywords."""
        if not tokens or not topic_keywords:
            return 0.0
        total_score = 0.0
        for keyword in topic_keywords:
            kw = keyword.lower()
            best = 0.0
            for token in tokens:
                tk = token.lower()
                if tk == kw:
                    best = max(best, SCORE_DIRECT)
                    continue
                if self._are_synonyms(tk, kw):
                    best = max(best, SCORE_SYNONYM)
                    continue
                if len(tk) >= MIN_SUBSTRING_LEN and len(kw) >= MIN_SUBSTRING_LEN:
                    if tk in kw or kw in tk:
                        best = max(best, SCORE_SUBSTRING)
                        continue
                if len(tk) >= MIN_FUZZY_WORD_LEN and len(kw) >= MIN_FUZZY_WORD_LEN:
                    dist = levenshtein_distance(tk, kw)
                    if dist <= MAX_FUZZY_DISTANCE:
                        best = max(best, SCORE_FUZZY)
            total_score += best
        # Normalize by the smaller of token count or keyword count to avoid
        # penalizing topics that have many keywords when the player input is short
        divisor = max(1, min(len(tokens), len(topic_keywords)))
        return total_score / divisor

    def find_best_topic(
        self, tokens: List[str], topics_dict: Dict[str, dict],
    ) -> Tuple[Optional[str], float]:
        """Find the best matching topic for tokens."""
        if not tokens or not topics_dict:
            return None, 0.0
        best_topic: Optional[str] = None
        best_score: float = 0.0
        best_match_count: int = 0
        for topic_name, topic_data in topics_dict.items():
            keywords = topic_data.get("keywords", [])
            if not keywords:
                continue
            score = self.match(tokens, keywords)
            if score < MIN_TOPIC_SCORE:
                continue
            match_count = sum(
                1 for kw in keywords
                if any(t.lower() == kw.lower() for t in tokens)
            )
            if score > best_score or (score == best_score and match_count > best_match_count):
                best_topic = topic_name
                best_score = score
                best_match_count = match_count
        return best_topic, best_score

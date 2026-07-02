"""Conversation state tracking for NPC interactions."""
import json
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional, Set

logger = logging.getLogger(__name__)
MAX_LAST_TOPICS: int = 5


class ConversationState:
    """Tracks the state of a conversation with a specific NPC instance."""

    def __init__(self, npc_id: str, default_mood: str = "neutral") -> None:
        """Initialize a new conversation state."""
        self.npc_id: str = npc_id
        self.discussed_topics: Set[str] = set()
        self.unlocked_topics: Set[str] = set()
        self.turn_count: int = 0
        self.mood: str = default_mood
        self.last_topics: List[str] = []
        self.repeat_counts: Dict[str, int] = {}
        self.player_sentiment: float = 0.0
        self.variables: Dict[str, Any] = {}
        self._recent_responses: List[str] = []

    def update(self, topic: Optional[str], player_message: str, response: str) -> None:
        """Update conversation state after an exchange."""
        self.turn_count += 1
        if topic:
            self.discussed_topics.add(topic)
            self.repeat_counts[topic] = self.repeat_counts.get(topic, 0) + 1
            self.last_topics.append(topic)
            if len(self.last_topics) > MAX_LAST_TOPICS:
                self.last_topics = self.last_topics[-MAX_LAST_TOPICS:]
        self._recent_responses.append(response)
        if len(self._recent_responses) > 10:
            self._recent_responses = self._recent_responses[-10:]

    def get_repeat_count(self, topic: str) -> int:
        """Get how many times a specific topic has been discussed."""
        return self.repeat_counts.get(topic, 0)

    def is_discussed(self, topic: str) -> bool:
        """Check if a topic has been discussed at least once."""
        return topic in self.discussed_topics

    def is_unlocked(self, topic: str) -> bool:
        """Check if a topic has been unlocked."""
        return topic in self.unlocked_topics

    def unlock_topic(self, topic: str) -> None:
        """Unlock a topic for future discussion."""
        self.unlocked_topics.add(topic)
        logger.debug("Topic unlocked for %s: %s", self.npc_id, topic)

    def is_response_recent(self, response: str) -> bool:
        """Check if a response was used recently."""
        return response in self._recent_responses

    def shift_mood(self, direction: str) -> None:
        """Shift the NPC mood in a given direction."""
        mood_ladder = [
            "hostile", "angry", "annoyed", "cold", "neutral",
            "calm", "friendly", "happy", "enthusiastic", "elated",
        ]
        current_idx = -1
        for i, m in enumerate(mood_ladder):
            if m == self.mood:
                current_idx = i
                break
        if current_idx == -1:
            current_idx = mood_ladder.index("neutral")
        if direction == "positive" and current_idx < len(mood_ladder) - 1:
            self.mood = mood_ladder[current_idx + 1]
        elif direction == "negative" and current_idx > 0:
            self.mood = mood_ladder[current_idx - 1]
        if direction == "positive":
            self.player_sentiment = min(1.0, self.player_sentiment + 0.1)
        elif direction == "negative":
            self.player_sentiment = max(-1.0, self.player_sentiment - 0.15)

    def to_dict(self) -> Dict[str, Any]:
        """Serialize state to a JSON-compatible dictionary."""
        return {
            "npc_id": self.npc_id,
            "discussed_topics": sorted(self.discussed_topics),
            "unlocked_topics": sorted(self.unlocked_topics),
            "turn_count": self.turn_count,
            "mood": self.mood,
            "last_topics": self.last_topics,
            "repeat_counts": self.repeat_counts,
            "player_sentiment": self.player_sentiment,
            "variables": self.variables,
            "_recent_responses": self._recent_responses,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ConversationState":
        """Deserialize state from a dictionary."""
        state = cls(npc_id=data.get("npc_id", "unknown"))
        state.discussed_topics = set(data.get("discussed_topics", []))
        state.unlocked_topics = set(data.get("unlocked_topics", []))
        state.turn_count = data.get("turn_count", 0)
        state.mood = data.get("mood", "neutral")
        state.last_topics = data.get("last_topics", [])
        state.repeat_counts = data.get("repeat_counts", {})
        state.player_sentiment = data.get("player_sentiment", 0.0)
        state.variables = data.get("variables", {})
        state._recent_responses = data.get("_recent_responses", [])
        return state

    def save(self, filepath: Path) -> None:
        """Save state to a JSON file."""
        try:
            filepath.parent.mkdir(parents=True, exist_ok=True)
            with open(filepath, "w", encoding="utf-8") as f:
                json.dump(self.to_dict(), f, indent=2, ensure_ascii=False)
            logger.debug("Saved conversation state to %s", filepath)
        except OSError as e:
            logger.error("Failed to save state to %s: %s", filepath, e)

    @classmethod
    def load(cls, filepath: Path) -> Optional["ConversationState"]:
        """Load state from a JSON file."""
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                data = json.load(f)
            state = cls.from_dict(data)
            logger.debug("Loaded conversation state from %s", filepath)
            return state
        except FileNotFoundError:
            return None
        except (json.JSONDecodeError, KeyError, TypeError) as e:
            logger.error("Failed to load state from %s: %s", filepath, e)
            return None


class StateManager:
    """Manages conversation states for all NPC instances."""

    def __init__(self, conversations_dir: Path) -> None:
        """Initialize the state manager."""
        self._dir = conversations_dir
        self._dir.mkdir(parents=True, exist_ok=True)
        self._states: Dict[str, ConversationState] = {}
        self._load_all()

    def _state_file(self, npc_id: str) -> Path:
        """Get the file path for an NPC conversation state."""
        safe_id = npc_id.replace("/", "_").replace("\\", "_")
        return self._dir / f"{safe_id}.json"

    def _load_all(self) -> None:
        """Load all existing conversation states from disk."""
        count = 0
        try:
            for filepath in self._dir.glob("*.json"):
                state = ConversationState.load(filepath)
                if state:
                    self._states[state.npc_id] = state
                    count += 1
        except OSError as e:
            logger.error("Error scanning conversations directory: %s", e)
        if count > 0:
            logger.info("Loaded %d existing conversation states", count)

    def get_or_create(self, npc_id: str, default_mood: str = "neutral") -> ConversationState:
        """Get an existing conversation state or create a new one."""
        if npc_id not in self._states:
            self._states[npc_id] = ConversationState(npc_id, default_mood)
            logger.debug("Created new conversation state for %s", npc_id)
        return self._states[npc_id]

    def save(self, npc_id: str) -> None:
        """Save a specific NPC conversation state to disk."""
        if npc_id in self._states:
            self._states[npc_id].save(self._state_file(npc_id))

    def save_all(self) -> None:
        """Save all conversation states to disk."""
        for npc_id in self._states:
            self.save(npc_id)
        logger.debug("Saved all %d conversation states", len(self._states))

"""Topic permission gating for NPC conversations."""
import logging
import random
from typing import Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)


class TopicGate:
    """Gates conversation topics based on NPC profile permissions."""

    def check(self, topic: str, profile: Dict) -> Tuple[bool, Optional[str]]:
        """Check whether a topic is permitted for this NPC profile."""
        if not topic or not profile:
            return True, None
        allowed = profile.get("allowed_topics", [])
        banned = profile.get("banned_topics", [])
        is_open = profile.get("open_topics", False)
        if banned and topic in banned:
            return False, self._get_deflection(profile)
        if allowed and topic not in allowed:
            if not is_open:
                return False, self._get_deflection(profile)
        return True, None

    @staticmethod
    def _get_deflection(profile: Dict) -> str:
        """Pick a random deflection message from the profile."""
        deflections = profile.get("deflection", [])
        if deflections:
            return random.choice(deflections)
        return "I cannot help you with that."

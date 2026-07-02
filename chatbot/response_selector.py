"""Response selection and template rendering for NPC dialogue."""
import logging
import random
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

_KARMA_TITLES = [
    (-9999, -50, "villain"),
    (-50, -20, "troublemaker"),
    (-20, 20, "stranger"),
    (20, 50, "friend"),
    (50, 9999, "hero"),
]

_NIGHT_TIMES = {"evening", "night"}
_DAY_TIMES = {"morning", "afternoon", "dawn", "midday", "noon"}


def get_karma_title(karma: float) -> str:
    """Determine the karma-based title for a player."""
    for low, high, title in _KARMA_TITLES:
        if low <= karma < high:
            return title
    return "stranger"


class ResponseSelector:
    """Selects and formats NPC responses."""

    def select(self, topic: str, profile: Dict[str, Any], state: Any,
               context: Dict[str, Any], intent: str, player_info: Dict[str, Any]) -> Dict[str, Any]:
        """Select an appropriate response for the given topic and context."""
        topics = profile.get("topics", {})
        topic_data = topics.get(topic, {})
        response_pool = topic_data.get("responses", [])
        if not response_pool:
            return self._make_no_match_response(profile, player_info, context)
        eligible = []
        for resp in response_pool:
            if self._check_conditions(resp, state, player_info, context):
                eligible.append(resp)
        if not eligible:
            eligible = [r for r in response_pool if "conditions" not in r]
        if not eligible:
            eligible = response_pool
        not_recent = [r for r in eligible if not state.is_response_recent(r.get("text", ""))]
        if not_recent:
            eligible = not_recent
        chosen = random.choice(eligible)
        text = chosen.get("text", "...")
        mood = chosen.get("mood", profile.get("default_mood", "neutral"))
        options = chosen.get("options", [])
        end_convo = chosen.get("end_conversation", False)
        unlocks = chosen.get("unlocks", [])
        for unlock_topic in unlocks:
            state.unlock_topic(unlock_topic)
        text = self._apply_templates(text, player_info, context, profile)
        options = [self._apply_templates(o, player_info, context, profile) for o in options]
        return {"reply": text, "topic": topic, "mood": mood, "options": options, "end_conversation": end_convo}

    def select_special(self, intent: str, profile: Dict[str, Any], state: Any,
                       context: Dict[str, Any], player_info: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Select a response for special intents.

        Handles both flat list format (legacy) and conditional dict format:
          flat:  "greetings": ["text1", "text2"]
          dict:  "greeting": {"default": [...], "if_race:dwarf": [...]}
        """
        # Try both singular (conditional dict) and plural (flat list) keys
        singular_map = {"greeting": "greeting", "farewell": "farewell",
                        "thanks": "thanks_response", "insult": "insult_response"}
        plural_map = {"greeting": "greetings", "farewell": "farewells",
                      "thanks": "thanks_responses", "insult": "insult_responses"}
        singular_key = singular_map.get(intent)
        plural_key = plural_map.get(intent)
        section = profile.get(singular_key) or profile.get(plural_key)
        if not section:
            return None
        if isinstance(section, dict):
            pool = self._select_from_conditional(section, player_info, context, state)
        elif isinstance(section, list):
            pool = list(section)
        else:
            return None
        if not pool:
            return None
        not_recent = [r for r in pool if not state.is_response_recent(r)]
        if not_recent:
            pool = not_recent
        text = random.choice(pool)
        text = self._apply_templates(text, player_info, context, profile)
        mood = profile.get("default_mood", "neutral")
        if intent == "insult":
            mood = "angry"
        elif intent == "greeting":
            mood = "friendly"
        elif intent == "farewell":
            mood = "warm"
        elif intent == "thanks":
            mood = "pleased"
        return {"reply": text, "topic": intent, "mood": mood, "options": [], "end_conversation": intent == "farewell"}

    def _make_no_match_response(self, profile: Dict[str, Any],
                                player_info: Dict[str, Any], context: Dict[str, Any]) -> Dict[str, Any]:
        """Create a response when no topic was matched."""
        pool = profile.get("no_match_responses", ["I do not understand."])
        text = random.choice(pool)
        text = self._apply_templates(text, player_info, context, profile)
        return {"reply": text, "topic": "no_match", "mood": profile.get("default_mood", "neutral"), "options": [], "end_conversation": False}

    @staticmethod
    def _select_from_conditional(section: Dict[str, Any], player_info: Dict[str, Any],
                                 context: Dict[str, Any], state: Any) -> List[str]:
        """Select appropriate texts from a conditional dict section.

        Builds a pool from 'default' entries plus any matching conditional entries
        (race, karma, time of day, mood).
        """
        candidates: List[str] = list(section.get("default", []))
        karma = player_info.get("player_karma", 0)
        race = player_info.get("player_race", "").lower()
        time_of_day = context.get("time_of_day", "").lower()

        # Race-specific
        race_key = f"if_race:{race}"
        if race_key in section and isinstance(section[race_key], list):
            candidates.extend(section[race_key])

        # Karma-specific
        if karma > 20 and "if_karma:good" in section:
            candidates.extend(section["if_karma:good"])
        elif karma < -20 and "if_karma:evil" in section:
            candidates.extend(section["if_karma:evil"])

        # Time-specific
        if time_of_day in _NIGHT_TIMES and "if_time:night" in section:
            candidates.extend(section["if_time:night"])
        elif time_of_day in _DAY_TIMES:
            if "if_time:morning" in section:
                candidates.extend(section["if_time:morning"])
            elif "if_time:day" in section:
                candidates.extend(section["if_time:day"])

        # Mood-specific
        if hasattr(state, "mood") and f"if_mood:{state.mood}" in section:
            candidates.extend(section[f"if_mood:{state.mood}"])

        return candidates

    def _check_conditions(self, response: Dict[str, Any], state: Any,
                          player_info: Dict[str, Any], context: Dict[str, Any]) -> bool:
        """Check if all conditions on a response are met."""
        conditions = response.get("conditions", [])
        if not conditions:
            return True
        karma = player_info.get("player_karma", 0)
        race = player_info.get("player_race", "").lower()
        time_of_day = context.get("time_of_day", "").lower()
        for cond in conditions:
            if not isinstance(cond, str):
                continue
            if cond.startswith("if_discussed:"):
                req_topic = cond[len("if_discussed:"):]
                if not state.is_discussed(req_topic):
                    return False
            elif cond.startswith("if_not_discussed:"):
                req_topic = cond[len("if_not_discussed:"):]
                if state.is_discussed(req_topic):
                    return False
            elif cond.startswith("if_race:"):
                req_race = cond[len("if_race:"):].lower()
                if race != req_race:
                    return False
            elif cond.startswith("if_karma:"):
                karma_type = cond[len("if_karma:"):]
                if karma_type == "good" and karma <= 20:
                    return False
                if karma_type == "evil" and karma >= -20:
                    return False
            elif cond.startswith("if_mood:"):
                req_mood = cond[len("if_mood:"):]
                if state.mood != req_mood:
                    return False
            elif cond.startswith("if_time:"):
                time_type = cond[len("if_time:"):]
                if time_type == "night" and time_of_day not in _NIGHT_TIMES:
                    return False
                if time_type == "day" and time_of_day not in _DAY_TIMES:
                    return False
            elif cond == "if_repeat":
                if not any(c > 1 for c in state.repeat_counts.values()):
                    return False
        return True

    def _apply_templates(self, text: str, player_info: Dict[str, Any],
                         context: Dict[str, Any], profile: Dict[str, Any]) -> str:
        """Apply template variable substitution to a text string."""
        karma = player_info.get("player_karma", 0)
        replacements = {
            "{player_name}": player_info.get("player_name", "traveler"),
            "{player_race}": player_info.get("player_race", "stranger"),
            "{npc_name}": player_info.get("npc_name", "I"),
            "{town}": context.get("town", "this town"),
            "{weather}": context.get("weather", "fair"),
            "{time_of_day}": context.get("time_of_day", "day"),
            "{karma_title}": get_karma_title(karma),
        }
        result = text
        for key, value in replacements.items():
            result = result.replace(key, str(value))
        return result

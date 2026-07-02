"""Main chatbot engine orchestrator."""
import json
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional

from chatbot.config import (
    DATA_DIR, PROFILES_DIR, CONVERSATIONS_DIR,
    MAX_RESPONSE_LENGTH, MAX_CONVERSATION_TURNS,
)
from chatbot.normalizer import Normalizer
from chatbot.keyword_matcher import KeywordMatcher
from chatbot.topic_gate import TopicGate
from chatbot.state_machine import StateManager
from chatbot.intent_detector import IntentDetector
from chatbot.response_selector import ResponseSelector, get_karma_title

logger = logging.getLogger(__name__)


class ChatbotEngine:
    """Main orchestrator for NPC dialogue processing."""

    def __init__(self) -> None:
        """Initialize all subsystems and load NPC profiles."""
        logger.info("Initializing ChatbotEngine...")
        self._normalizer = Normalizer(DATA_DIR)
        self._matcher = KeywordMatcher(DATA_DIR)
        self._gate = TopicGate()
        self._state_mgr = StateManager(CONVERSATIONS_DIR)
        self._intent_detector = IntentDetector(DATA_DIR)
        self._response_selector = ResponseSelector()
        self._profiles: Dict[str, Dict] = {}
        self._load_profiles()
        self._add_profession_aliases()
        logger.info("ChatbotEngine initialized with %d profiles", len(self._profiles))

    def _load_profiles(self) -> None:
        """Load all NPC profile JSON files from the profiles directory."""
        try:
            for filepath in PROFILES_DIR.glob("*.json"):
                try:
                    with open(filepath, "r", encoding="utf-8") as f:
                        profile = json.load(f)
                    npc_type = profile.get("npc_type", filepath.stem)
                    profile = self._normalize_profile(profile)
                    npc_type = profile.get("npc_type", npc_type)
                    self._profiles[npc_type] = profile
                    logger.info("Loaded profile: %s", npc_type)
                except json.JSONDecodeError as e:
                    logger.error("Failed to parse profile %s: %s", filepath, e)
                except OSError as e:
                    logger.error("Failed to read profile %s: %s", filepath, e)
        except OSError as e:
            logger.error("Failed to scan profiles directory: %s", e)
        if not self._profiles:
            logger.warning("No NPC profiles loaded. Creating minimal fallback.")
            self._profiles["commoner"] = {
                "npc_type": "commoner", "default_mood": "neutral", "open_topics": True,
                "greetings": ["Hello there."], "farewells": ["Goodbye."],
                "thanks_responses": ["You are welcome."], "insult_responses": ["That was rude."],
                "no_match_responses": ["I do not understand."],
                "deflection": ["I cannot help with that."], "topics": {},
            }

    def _add_profession_aliases(self) -> None:
        """Map game profession names to existing profiles as aliases."""
        aliases = {
            "shopkeeper": "merchant",
            "town_guard": "guard",
            "tavernkeeper": "tavernkeep",
            "tavern_keeper": "tavernkeep",
            "fisher": "commoner",
            "hunter": "commoner",
            "butcher": "commoner",
            "baker": "commoner",
            "tailor": "commoner",
            "jeweler": "merchant",
            "wellkeeper": "commoner",
            "stablemaster": "commoner",
            "land_commissioner": "merchant",
        }
        for alias, target in aliases.items():
            if alias not in self._profiles and target in self._profiles:
                self._profiles[alias] = self._profiles[target]
                logger.debug("Added profile alias: %s -> %s", alias, target)

    @staticmethod
    def _normalize_profile(raw: Dict[str, Any]) -> Dict[str, Any]:
        """Convert author-friendly profile format to engine-internal format.

        Handles:
        - 'type' -> 'npc_type'
        - 'no_match' -> 'no_match_responses'
        - Conditional greeting/farewell dicts preserved (selector handles them)
        - Topic responses from conditional dict to list of response dicts
        """
        profile = dict(raw)

        # Rename 'type' -> 'npc_type'
        if "type" in profile and "npc_type" not in profile:
            profile["npc_type"] = profile.pop("type")

        # Rename 'no_match' -> 'no_match_responses'
        if "no_match" in profile and "no_match_responses" not in profile:
            profile["no_match_responses"] = profile.pop("no_match")

        # Convert topic responses from conditional dict format to list of dicts
        for topic_name, topic_data in profile.get("topics", {}).items():
            responses = topic_data.get("responses")
            if isinstance(responses, dict):
                converted: List[Dict[str, Any]] = []
                topic_unlocks = topic_data.get("unlocks", [])
                topic_options = topic_data.get("suggested_options", [])

                for condition_key, texts in responses.items():
                    if not isinstance(texts, list):
                        continue
                    for text in texts:
                        entry: Dict[str, Any] = {"text": text}
                        if condition_key != "default":
                            entry["conditions"] = [condition_key]
                        # Attach topic-level unlocks to default responses
                        if condition_key == "default" and topic_unlocks:
                            entry["unlocks"] = topic_unlocks
                        if topic_options:
                            entry["options"] = topic_options
                        converted.append(entry)

                topic_data["responses"] = converted

        return profile

    def process(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """Process a player message and generate an NPC response."""
        try:
            return self._process_internal(request)
        except Exception as e:
            logger.error("Error processing request: %s", e, exc_info=True)
            return {"reply": "...", "topic": "error", "mood": "confused", "options": [], "end_conversation": False}

    def _process_internal(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """Internal processing pipeline."""
        npc_id = request.get("npc_id", "unknown_npc")
        npc_type = request.get("npc_type", "commoner")
        npc_name = request.get("npc_name", "Someone")
        player_name = request.get("player_name", "Traveler")
        player_race = request.get("player_race", "human")
        player_karma = request.get("player_karma", 0)
        message = request.get("message", "").strip()
        context = request.get("context", {})
        profile = self._profiles.get(npc_type, self._profiles.get("commoner", {}))
        default_mood = profile.get("default_mood", "neutral")
        state = self._state_mgr.get_or_create(npc_id, default_mood)
        if state.turn_count >= MAX_CONVERSATION_TURNS:
            return {"reply": "I have enjoyed our conversation, but I must attend to other matters now.",
                    "topic": "turn_limit", "mood": "apologetic", "options": [], "end_conversation": True}
        player_info = {"player_name": player_name, "player_race": player_race,
                       "player_karma": player_karma, "npc_name": npc_name}
        intent = self._intent_detector.detect(message)
        logger.debug("Detected intent: %s for message: %s", intent, message[:50])
        # Handle special intents
        if intent in ("greeting", "farewell", "thanks", "insult"):
            response = self._response_selector.select_special(intent, profile, state, context, player_info)
            if response:
                if intent == "insult":
                    state.shift_mood("negative")
                elif intent in ("greeting", "thanks"):
                    state.shift_mood("positive")
                if intent != "greeting":
                    state.update(intent, message, response["reply"])
                else:
                    state.update(None, message, response["reply"])
                if not response["end_conversation"]:
                    response["options"] = self._generate_options(profile, state)
                self._state_mgr.save(npc_id)
                response["reply"] = self._truncate(response["reply"])
                return response
        # Normalize and match for question/statement intents
        tokens = self._normalizer.normalize(message)
        logger.debug("Normalized tokens: %s", tokens)
        topics = profile.get("topics", {})
        topic_name, score = self._matcher.find_best_topic(tokens, topics)
        logger.debug("Best topic: %s (score: %.2f)", topic_name, score)
        # No topic matched
        if topic_name is None:
            no_match = self._response_selector._make_no_match_response(profile, player_info, context)
            no_match["options"] = self._generate_options(profile, state)
            state.update(None, message, no_match["reply"])
            self._state_mgr.save(npc_id)
            no_match["reply"] = self._truncate(no_match["reply"])
            return no_match
        # Gate the topic
        approved, deflection = self._gate.check(topic_name, profile)
        if not approved:
            deflection_text = self._response_selector._apply_templates(
                deflection or "I cannot help with that.", player_info, context, profile)
            result = {"reply": self._truncate(deflection_text), "topic": "deflection",
                      "mood": profile.get("default_mood", "neutral"),
                      "options": self._generate_options(profile, state), "end_conversation": False}
            state.update(None, message, result["reply"])
            self._state_mgr.save(npc_id)
            return result
        # Select response
        response = self._response_selector.select(topic_name, profile, state, context, intent, player_info)
        state.update(topic_name, message, response["reply"])
        if not response["options"]:
            response["options"] = self._generate_options(profile, state)
        self._state_mgr.save(npc_id)
        response["reply"] = self._truncate(response["reply"])
        return response

    def _generate_options(self, profile: Dict[str, Any], state: Any) -> List[str]:
        """Generate suggested dialogue options for the player."""
        options: List[str] = []
        topics = profile.get("topics", {})
        for topic_name in state.unlocked_topics:
            if topic_name not in state.discussed_topics and topic_name in topics:
                topic_data = topics[topic_name]
                keywords = topic_data.get("keywords", [])
                if keywords:
                    options.append(f"Tell me about {keywords[0]}")
                if len(options) >= 2:
                    break
        for topic_name, topic_data in topics.items():
            if len(options) >= 3:
                break
            if topic_name in state.discussed_topics:
                continue
            keywords = topic_data.get("keywords", [])
            if keywords:
                option = f"What about {keywords[0]}?"
                if option not in options:
                    options.append(option)
        if len(options) < 4:
            options.append("That is all, goodbye")
        return options[:4]

    @staticmethod
    def _truncate(text: str) -> str:
        """Truncate text to the maximum response length."""
        if len(text) <= MAX_RESPONSE_LENGTH:
            return text
        return text[: MAX_RESPONSE_LENGTH - 3].rstrip() + "..."

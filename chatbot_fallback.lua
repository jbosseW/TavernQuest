-- chatbot_fallback.lua
-- Pure Lua fallback chatbot engine for Tavern Quest
-- Replicates the Python chatbot backend's core functionality
-- Used when the Python backend is not running

local json = require("json")

local M = {}

-- ============================================================================
-- INTERNAL DATA STORES
-- ============================================================================

local profiles = {}           -- keyed by npc_type string
local synonymGroups = {}      -- synonym group name -> list of words
local synonymLookup = {}      -- word -> list of group names it belongs to
local insults = {}            -- set: word -> true
local contractions = {}       -- contraction -> expansion
local conversationStates = {} -- keyed by npc_id

-- ============================================================================
-- PROFESSION ALIASES (fallback mappings when real profile does not exist)
-- ============================================================================

local PROFESSION_ALIASES = {
    shopkeeper     = "merchant",
    town_guard     = "guard",
    tavernkeeper   = "tavernkeep",
    tavern_keeper  = "tavernkeep",
    fisher         = "commoner",
    hunter         = "commoner",
    butcher        = "commoner",
    baker          = "commoner",
    tailor         = "commoner",
    jeweler        = "merchant",
    wellkeeper     = "commoner",
    stablemaster   = "commoner",
    land_commissioner = "merchant",
}

-- ============================================================================
-- STOP WORDS
-- ============================================================================

local STOP_WORDS = {}
do
    local list = {
        "the", "a", "an", "is", "are", "am", "was", "were", "be", "been",
        "being", "have", "has", "had", "do", "does", "did", "will", "would",
        "could", "should", "shall", "may", "might", "can", "this", "that",
        "these", "those", "it", "its", "i", "me", "my", "we", "our", "you",
        "your", "he", "she", "they", "them", "their", "of", "in", "on", "at",
        "to", "for", "with", "by", "from", "and", "or", "but", "not", "so",
        "very", "just", "also", "too", "about", "up", "out", "if", "then",
        "than", "into", "some", "any", "each", "every", "all", "both", "few",
        "more", "most", "other", "such", "no", "nor", "only", "own", "same",
        "here", "there", "when", "where", "why", "how", "what", "which", "who",
    }
    for _, w in ipairs(list) do
        STOP_WORDS[w] = true
    end
end

-- ============================================================================
-- SUFFIX STRIPPING LIST (ordered longest first for greedy match)
-- ============================================================================

local SUFFIXES = {
    "tion", "ment", "ness", "able", "ible",
    "ing", "est", "ies",
    "er", "ed", "ly", "es",
    "s",
}

-- ============================================================================
-- MAX CONVERSATION TURNS
-- ============================================================================

local MAX_TURNS = 50

-- ============================================================================
-- FILE I/O HELPERS
-- ============================================================================

local sourceDir = nil

local function getSourceDir()
    if sourceDir then return sourceDir end
    sourceDir = love.filesystem.getSource():gsub("\\", "/")
    if sourceDir:sub(-1) == "/" then
        sourceDir = sourceDir:sub(1, -2)
    end
    return sourceDir
end

local function toOSPath(path)
    if love.system.getOS() == "Windows" then
        return path:gsub("/", "\\")
    end
    return path
end

local function readJSONFile(relPath)
    local fullPath = getSourceDir() .. "/" .. relPath
    local osPath = toOSPath(fullPath)
    local file, err = io.open(osPath, "r")
    if not file then
        return nil, "Could not open " .. osPath .. ": " .. tostring(err)
    end
    local content = file:read("*a")
    file:close()
    if not content or content == "" then
        return nil, "Empty file: " .. osPath
    end
    local data, decErr = json.decode(content)
    if not data then
        return nil, "JSON decode error in " .. osPath .. ": " .. tostring(decErr)
    end
    return data
end

-- ============================================================================
-- PROFILE NORMALIZATION
-- ============================================================================

local function normalizeProfile(data)
    -- Handle "type" -> "npc_type" alias
    if not data.npc_type and data.type then
        data.npc_type = data.type
    end
    -- Handle "no_match" -> "no_match_responses" alias
    if not data.no_match_responses and data.no_match then
        data.no_match_responses = data.no_match
    end
    -- Ensure required fields have defaults
    data.npc_type = data.npc_type or "unknown"
    data.default_mood = data.default_mood or "neutral"
    data.allowed_topics = data.allowed_topics or {}
    data.banned_topics = data.banned_topics or {}
    data.open_topics = data.open_topics or false
    data.deflection = data.deflection or {"I have nothing to say about that."}
    data.greetings = data.greetings or {"Hello."}
    data.farewells = data.farewells or {"Goodbye."}
    data.thanks_responses = data.thanks_responses or {"You are welcome."}
    data.insult_responses = data.insult_responses or {"How rude."}
    data.no_match_responses = data.no_match_responses or {"I do not understand."}
    data.topics = data.topics or {}

    -- Build allowed_topics set for fast lookup
    data._allowed_set = {}
    for _, t in ipairs(data.allowed_topics) do
        data._allowed_set[t] = true
    end

    -- Build banned_topics set for fast lookup
    data._banned_set = {}
    for _, t in ipairs(data.banned_topics) do
        data._banned_set[t] = true
    end

    return data
end

-- ============================================================================
-- INIT
-- ============================================================================

function M.init()
    profiles = {}
    synonymGroups = {}
    synonymLookup = {}
    insults = {}
    contractions = {}
    conversationStates = {}

    -- Load profiles
    local profileFiles = love.filesystem.getDirectoryItems("chatbot/profiles")
    local loadedCount = 0
    for _, filename in ipairs(profileFiles) do
        if filename:match("%.json$") then
            local data, err = readJSONFile("chatbot/profiles/" .. filename)
            if data then
                data = normalizeProfile(data)
                local key = data.npc_type:lower()
                profiles[key] = data
                loadedCount = loadedCount + 1
            else
                print("[ChatbotFallback] Failed to load profile " .. filename .. ": " .. tostring(err))
            end
        end
    end
    print("[ChatbotFallback] Loaded " .. loadedCount .. " profiles")

    -- Apply profession aliases (only where the real profile does not exist)
    for alias, target in pairs(PROFESSION_ALIASES) do
        if not profiles[alias] and profiles[target] then
            profiles[alias] = profiles[target]
        end
    end

    -- Load synonyms
    local synData = readJSONFile("chatbot/data/synonyms.json")
    if synData then
        synonymGroups = synData
        -- Build reverse lookup: word -> set of group names
        for groupName, words in pairs(synData) do
            for _, word in ipairs(words) do
                local w = word:lower()
                if not synonymLookup[w] then
                    synonymLookup[w] = {}
                end
                synonymLookup[w][groupName] = true
            end
        end
        print("[ChatbotFallback] Loaded synonym groups")
    else
        print("[ChatbotFallback] Warning: could not load synonyms.json")
    end

    -- Load insults
    local insultData = readJSONFile("chatbot/data/insults.json")
    if insultData then
        for _, word in ipairs(insultData) do
            insults[word:lower()] = true
        end
        print("[ChatbotFallback] Loaded insults list")
    else
        print("[ChatbotFallback] Warning: could not load insults.json")
    end

    -- Load contractions
    local contrData = readJSONFile("chatbot/data/contractions.json")
    if contrData then
        for k, v in pairs(contrData) do
            contractions[k:lower()] = v:lower()
        end
        print("[ChatbotFallback] Loaded contractions")
    else
        print("[ChatbotFallback] Warning: could not load contractions.json")
    end

    print("[ChatbotFallback] Initialization complete")
end

-- ============================================================================
-- TEXT NORMALIZATION
-- ============================================================================

local function expandContractions(text)
    -- Split into words (preserving spaces), look up each word in contractions table
    local result = text:lower()
    -- Split on whitespace boundaries, keeping delimiters
    local parts = {}
    local lastEnd = 1
    for ws_start, ws_end in result:gmatch("()%s+()") do
        if ws_start > lastEnd then
            parts[#parts + 1] = result:sub(lastEnd, ws_start - 1)
        end
        parts[#parts + 1] = result:sub(ws_start, ws_end - 1)
        lastEnd = ws_end
    end
    if lastEnd <= #result then
        parts[#parts + 1] = result:sub(lastEnd)
    end

    -- Replace contractions in-place
    for i, part in ipairs(parts) do
        -- Strip trailing punctuation for lookup, reattach after
        local word, trailing = part:match("^(.-)([%.%?!,;:]+)$")
        if not word then
            word = part
            trailing = ""
        end
        if contractions[word] then
            parts[i] = contractions[word] .. trailing
        end
    end

    return table.concat(parts)
end

local function stripPunctuation(text)
    -- Remove punctuation but keep apostrophes within words
    -- First, protect apostrophes that are within words (e.g., don't)
    -- Then strip all other punctuation
    local result = {}
    local i = 1
    local len = #text
    while i <= len do
        local c = text:sub(i, i)
        if c == "'" then
            -- Keep apostrophe only if surrounded by letters
            local prev = (i > 1) and text:sub(i - 1, i - 1) or ""
            local nxt = (i < len) and text:sub(i + 1, i + 1) or ""
            if prev:match("%a") and nxt:match("%a") then
                result[#result + 1] = c
            else
                result[#result + 1] = " "
            end
        elseif c:match("[%a%d%s]") then
            result[#result + 1] = c
        else
            result[#result + 1] = " "
        end
        i = i + 1
    end
    return table.concat(result)
end

local function stripSuffix(word)
    -- Simple suffix stripping: remove suffix if remaining root is 3+ chars
    for _, suffix in ipairs(SUFFIXES) do
        local suffLen = #suffix
        if #word > suffLen + 2 and word:sub(-suffLen) == suffix then
            return word:sub(1, -suffLen - 1)
        end
    end
    return word
end

local function tokenize(text)
    local tokens = {}
    for word in text:gmatch("%S+") do
        if word ~= "" then
            tokens[#tokens + 1] = word
        end
    end
    return tokens
end

local function normalizeText(text)
    if not text or text == "" then return {}, "" end

    -- Step 1: Expand contractions
    local processed = expandContractions(text)

    -- Step 2: Lowercase
    processed = processed:lower()

    -- Step 3: Strip punctuation (keep apostrophes within words)
    processed = stripPunctuation(processed)

    -- Step 4: Tokenize
    local rawTokens = tokenize(processed)

    -- Step 5: Remove stop words and apply suffix stripping
    local tokens = {}
    for _, word in ipairs(rawTokens) do
        if not STOP_WORDS[word] then
            local stemmed = stripSuffix(word)
            tokens[#tokens + 1] = stemmed
        end
    end

    return tokens, processed
end

-- ============================================================================
-- LEVENSHTEIN DISTANCE
-- ============================================================================

local function levenshtein(s1, s2)
    local len1, len2 = #s1, #s2
    if len1 == 0 then return len2 end
    if len2 == 0 then return len1 end

    -- Use single row optimization
    local prev = {}
    local curr = {}
    for j = 0, len2 do
        prev[j] = j
    end

    for i = 1, len1 do
        curr[0] = i
        for j = 1, len2 do
            local cost = (s1:sub(i, i) == s2:sub(j, j)) and 0 or 1
            curr[j] = math.min(
                prev[j] + 1,       -- deletion
                curr[j - 1] + 1,   -- insertion
                prev[j - 1] + cost  -- substitution
            )
        end
        -- Swap rows
        prev, curr = curr, prev
    end

    return prev[len2]
end

-- ============================================================================
-- SYNONYM MATCHING
-- ============================================================================

local function areSynonyms(word1, word2)
    -- Check if word1 and word2 share any synonym group
    local groups1 = synonymLookup[word1]
    if not groups1 then return false end
    local groups2 = synonymLookup[word2]
    if not groups2 then return false end

    for groupName in pairs(groups1) do
        if groups2[groupName] then
            return true
        end
    end
    return false
end

-- ============================================================================
-- INTENT DETECTION
-- ============================================================================

local function detectIntent(rawText, tokens, normalizedText)
    local lower = rawText:lower()
    local trimmed = lower:match("^%s*(.-)%s*$") or lower

    -- Greeting patterns
    local greetingPatterns = {
        "^hi$", "^hi%s", "^hello", "^hey$", "^hey%s", "^greetings",
        "^howdy", "^yo$", "^yo%s", "^hail", "^salutations",
        "^good morning", "^good day", "^good evening", "^good afternoon",
        "^well met", "how are you", "what's up", "whats up",
    }
    for _, pat in ipairs(greetingPatterns) do
        if trimmed:match(pat) then
            return "greeting"
        end
    end

    -- Farewell patterns
    local farewellPatterns = {
        "^bye$", "^bye%s", "^bye[!%.]", "^goodbye", "^farewell",
        "see you", "take care", "^goodnight", "gotta go", "so long",
        "^later$", "^later%s",
    }
    for _, pat in ipairs(farewellPatterns) do
        if trimmed:match(pat) then
            return "farewell"
        end
    end

    -- Thanks patterns
    local thanksPatterns = {
        "thanks", "thank you", "thank ye", "grateful", "appreciate",
        "^cheers", "much obliged",
    }
    for _, pat in ipairs(thanksPatterns) do
        if trimmed:match(pat) then
            return "thanks"
        end
    end

    -- Insult detection: check if any word in the raw message is in the insults list
    local rawWords = tokenize(trimmed)
    for _, word in ipairs(rawWords) do
        -- Strip basic punctuation from the word for matching
        local clean = word:gsub("[^%a]", ""):lower()
        if clean ~= "" and insults[clean] then
            return "insult"
        end
    end

    -- Question detection
    local questionStarters = {
        "who", "what", "where", "when", "why", "how",
        "do", "does", "did", "can", "could",
        "is", "are", "will", "would", "should",
        "have", "has", "shall", "may", "might",
    }
    local firstWord = trimmed:match("^(%S+)")
    if firstWord then
        firstWord = firstWord:gsub("[^%a]", ""):lower()
        for _, starter in ipairs(questionStarters) do
            if firstWord == starter then
                return "question"
            end
        end
    end
    if trimmed:match("%?%s*$") then
        return "question"
    end

    -- Default: statement
    return "statement"
end

-- ============================================================================
-- CONVERSATION STATE
-- ============================================================================

local function getState(npcId)
    if not conversationStates[npcId] then
        conversationStates[npcId] = {
            discussed_topics = {},   -- topic_name -> true
            unlocked_topics = {},    -- topic_name -> true
            turn_count = 0,
            recent_responses = {},   -- list of last 5 response texts
            repeat_counts = {},      -- topic_name -> count
            mood = nil,              -- current mood string (nil = use profile default)
        }
    end
    return conversationStates[npcId]
end

local function stateIsDiscussed(cstate, topic)
    return cstate.discussed_topics[topic] == true
end

local function stateUnlockTopic(cstate, topic)
    cstate.unlocked_topics[topic] = true
end

local function stateIsResponseRecent(cstate, text)
    for _, recent in ipairs(cstate.recent_responses) do
        if recent == text then
            return true
        end
    end
    return false
end

local function stateUpdate(cstate, topic, message, reply)
    cstate.turn_count = cstate.turn_count + 1

    if topic then
        cstate.discussed_topics[topic] = true
        cstate.repeat_counts[topic] = (cstate.repeat_counts[topic] or 0) + 1
    end

    -- Track recent responses (keep last 5)
    if reply then
        local recent = cstate.recent_responses
        recent[#recent + 1] = reply
        while #recent > 5 do
            table.remove(recent, 1)
        end
    end
end

local function stateShiftMood(cstate, direction)
    -- Simple mood shift based on direction
    local moodMap = {
        positive = {
            neutral = "friendly",
            friendly = "warm",
            warm = "enthusiastic",
            hostile = "neutral",
            annoyed = "neutral",
            suspicious = "neutral",
        },
        negative = {
            neutral = "annoyed",
            friendly = "neutral",
            warm = "friendly",
            enthusiastic = "warm",
            annoyed = "hostile",
        },
    }

    local currentMood = cstate.mood or "neutral"
    local transitions = moodMap[direction]
    if transitions and transitions[currentMood] then
        cstate.mood = transitions[currentMood]
    end
end

-- ============================================================================
-- TEMPLATE SUBSTITUTION
-- ============================================================================

local function getKarmaTitle(karma)
    karma = karma or 0
    if karma <= -50 then return "villain"
    elseif karma <= -20 then return "troublemaker"
    elseif karma <= 20 then return "stranger"
    elseif karma <= 50 then return "friend"
    else return "hero"
    end
end

local function applyTemplate(text, request)
    if not text or type(text) ~= "string" then return text or "" end

    local ctx = request.context or {}

    -- Use a generic pattern to find {key} placeholders and replace them
    local replacements = {
        player_name = request.player_name or "Adventurer",
        player_race = request.player_race or "human",
        npc_name    = request.npc_name or "NPC",
        town        = ctx.town or "town",
        weather     = ctx.weather or "pleasant",
        time_of_day = ctx.time_of_day or "afternoon",
        karma_title = getKarmaTitle(request.player_karma),
    }

    text = text:gsub("{(%w+)}", function(key)
        return replacements[key] or ("{" .. key .. "}")
    end)

    return text
end

-- ============================================================================
-- KEYWORD MATCHING
-- ============================================================================

local function scoreTopicMatch(tokens, keywords)
    if #tokens == 0 or #keywords == 0 then
        return 0, 0
    end

    local totalScore = 0
    local directMatches = 0

    -- Also stem the keywords for comparison
    local stemmedKeywords = {}
    for _, kw in ipairs(keywords) do
        stemmedKeywords[#stemmedKeywords + 1] = stripSuffix(kw:lower())
    end

    for _, token in ipairs(tokens) do
        local bestTokenScore = 0
        local isDirectMatch = false

        for ki, kw in ipairs(keywords) do
            local kwLower = kw:lower()
            local kwStemmed = stemmedKeywords[ki]

            -- Direct match (token or its stem matches keyword or keyword stem)
            if token == kwLower or token == kwStemmed then
                if 1.0 > bestTokenScore then
                    bestTokenScore = 1.0
                    isDirectMatch = true
                end
            -- Synonym match
            elseif areSynonyms(token, kwLower) then
                if 0.7 > bestTokenScore then
                    bestTokenScore = 0.7
                    isDirectMatch = false
                end
            -- Substring match (both words 4+ chars)
            elseif #token >= 4 and #kwLower >= 4 then
                if token:find(kwLower, 1, true) or kwLower:find(token, 1, true) then
                    if 0.4 > bestTokenScore then
                        bestTokenScore = 0.4
                        isDirectMatch = false
                    end
                end

                -- Fuzzy/Levenshtein match (both words 5+ chars, distance <= 2)
                if bestTokenScore < 0.3 and #token >= 5 and #kwLower >= 5 then
                    local dist = levenshtein(token, kwLower)
                    if dist <= 2 then
                        bestTokenScore = 0.3
                        isDirectMatch = false
                    end
                end
            end
        end

        totalScore = totalScore + bestTokenScore
        if isDirectMatch then
            directMatches = directMatches + 1
        end
    end

    -- Normalize score
    local divisor = math.min(#tokens, #keywords)
    if divisor == 0 then divisor = 1 end
    local normalized = totalScore / divisor

    return normalized, directMatches
end

local function findBestTopic(tokens, profile, cstate)
    local bestTopic = nil
    local bestScore = 0
    local bestDirectMatches = 0

    for topicName, topicData in pairs(profile.topics) do
        local keywords = topicData.keywords
        if keywords and #keywords > 0 then
            local score, directMatches = scoreTopicMatch(tokens, keywords)
            if score >= 0.2 then
                -- Pick if score is better, or if tied pick the one with more direct matches
                if score > bestScore or (score == bestScore and directMatches > bestDirectMatches) then
                    bestScore = score
                    bestDirectMatches = directMatches
                    bestTopic = topicName
                end
            end
        end
    end

    return bestTopic, bestScore
end

-- ============================================================================
-- CONDITION CHECKING
-- ============================================================================

local function checkCondition(condition, request, cstate, topicName)
    if not condition or type(condition) ~= "string" then
        return true
    end

    if condition == "if_repeat" then
        return (cstate.repeat_counts[topicName] or 0) >= 1
    end

    local key, value = condition:match("^if_(%w+):(.+)$")
    if not key then
        -- Unknown condition format, treat as met
        return true
    end

    if key == "race" then
        return (request.player_race or ""):lower() == value:lower()

    elseif key == "karma" then
        local karma = request.player_karma or 0
        if value == "good" then
            return karma > 20
        elseif value == "evil" then
            return karma < -20
        end

    elseif key == "time" then
        local tod = (request.context and request.context.time_of_day or "afternoon"):lower()
        if value == "night" then
            return tod == "evening" or tod == "night"
        elseif value == "day" then
            return tod == "morning" or tod == "afternoon" or tod == "dawn"
                or tod == "midday" or tod == "noon"
        end

    elseif key == "discussed" then
        return stateIsDiscussed(cstate, value)

    elseif key == "not_discussed" then
        return not stateIsDiscussed(cstate, value)

    elseif key == "mood" then
        local currentMood = cstate.mood or "neutral"
        return currentMood:lower() == value:lower()
    end

    return true
end

local function checkAllConditions(conditionsList, request, cstate, topicName)
    if not conditionsList or type(conditionsList) ~= "table" then
        return true
    end
    for _, cond in ipairs(conditionsList) do
        if not checkCondition(cond, request, cstate, topicName) then
            return false
        end
    end
    return true
end

-- ============================================================================
-- RESPONSE SELECTION HELPERS
-- ============================================================================

local function pickRandom(list)
    if not list or #list == 0 then return nil end
    return list[math.random(#list)]
end

local function filterRecentAndPick(list, cstate)
    -- Filter out recently used responses, then pick randomly
    -- list is a list of strings
    if not list or #list == 0 then return nil end

    local eligible = {}
    for _, text in ipairs(list) do
        if not stateIsResponseRecent(cstate, text) then
            eligible[#eligible + 1] = text
        end
    end

    if #eligible > 0 then
        return pickRandom(eligible)
    end

    -- All are recent, fall back to any
    return pickRandom(list)
end

local function processUnlocks(responseData, topicData, cstate)
    -- Process unlock chains from the response itself
    if responseData and type(responseData) == "table" and responseData.unlocks then
        local unlockList = responseData.unlocks
        if type(unlockList) == "table" then
            for _, topic in ipairs(unlockList) do
                stateUnlockTopic(cstate, topic)
            end
        elseif type(unlockList) == "string" then
            stateUnlockTopic(cstate, unlockList)
        end
    end

    -- Process unlock chains from the topic level
    if topicData and type(topicData) == "table" and topicData.unlocks then
        local unlockList = topicData.unlocks
        if type(unlockList) == "table" then
            for _, topic in ipairs(unlockList) do
                stateUnlockTopic(cstate, topic)
            end
        elseif type(unlockList) == "string" then
            stateUnlockTopic(cstate, unlockList)
        end
    end
end

-- ============================================================================
-- TOPIC GATING
-- ============================================================================

local function isTopicAccessible(topicName, profile, cstate)
    -- If open_topics is true, everything is allowed
    if profile.open_topics then
        return true
    end

    -- Check if topic is in the allowed_topics set
    if profile._allowed_set[topicName] then
        return true
    end

    -- Check if the topic has been unlocked via conversation
    if cstate.unlocked_topics[topicName] then
        return true
    end

    -- Topic is gated
    return false
end

-- ============================================================================
-- RESPONSE SELECTION FOR SPECIAL INTENTS
-- ============================================================================

local function selectSpecialIntentResponse(intent, profile, cstate, request)
    local responseList
    if intent == "greeting" then
        responseList = profile.greetings
    elseif intent == "farewell" then
        responseList = profile.farewells
    elseif intent == "thanks" then
        responseList = profile.thanks_responses
    elseif intent == "insult" then
        responseList = profile.insult_responses
    end

    if not responseList or #responseList == 0 then
        return nil
    end

    local text = filterRecentAndPick(responseList, cstate)
    if text then
        text = applyTemplate(text, request)
    end
    return text
end

-- ============================================================================
-- RESPONSE SELECTION FOR TOPIC MATCH
-- ============================================================================

local function selectTopicResponse(topicName, profile, cstate, request)
    local topicData = profile.topics[topicName]
    if not topicData or not topicData.responses then
        return nil, nil, nil
    end

    local responses = topicData.responses

    -- Partition into conditional and unconditional responses
    local eligible = {}
    local unconditional = {}
    for _, resp in ipairs(responses) do
        if resp.conditions and #resp.conditions > 0 then
            if checkAllConditions(resp.conditions, request, cstate, topicName) then
                eligible[#eligible + 1] = resp
            end
        else
            unconditional[#unconditional + 1] = resp
        end
    end

    -- Prefer conditional matches, fall back to unconditional, fall back to all
    local pool = #eligible > 0 and eligible or (#unconditional > 0 and unconditional or responses)

    -- Filter out recently used
    local nonRecent = {}
    for _, resp in ipairs(pool) do
        if not stateIsResponseRecent(cstate, resp.text) then
            nonRecent[#nonRecent + 1] = resp
        end
    end

    local chosen = #nonRecent > 0 and pickRandom(nonRecent) or pickRandom(pool)
    if not chosen then return nil, nil, nil end

    -- Process unlocks from the chosen response and topic level
    processUnlocks(chosen, topicData, cstate)

    local text = applyTemplate(chosen.text, request)
    local mood = chosen.mood or profile.default_mood
    local options = chosen.options  -- response-level suggested options (may be nil)

    return text, mood, options
end

-- ============================================================================
-- SUGGESTED OPTIONS GENERATION
-- ============================================================================

local function generateOptions(profile, cstate)
    local options = {}

    -- Gather all accessible, undiscussed topics
    local unlocked_undiscussed = {}
    local other_undiscussed = {}

    for topicName, topicData in pairs(profile.topics) do
        if not stateIsDiscussed(cstate, topicName) and isTopicAccessible(topicName, profile, cstate) then
            local firstKeyword = topicData.keywords and topicData.keywords[1] or topicName
            if cstate.unlocked_topics[topicName] then
                unlocked_undiscussed[#unlocked_undiscussed + 1] = firstKeyword
            else
                other_undiscussed[#other_undiscussed + 1] = firstKeyword
            end
        end
    end

    -- First: suggest unlocked topics that haven't been discussed (up to 2)
    local unlockCount = 0
    for _, kw in ipairs(unlocked_undiscussed) do
        if unlockCount >= 2 then break end
        options[#options + 1] = "Tell me about " .. kw
        unlockCount = unlockCount + 1
    end

    -- Then fill from other undiscussed topics
    for _, kw in ipairs(other_undiscussed) do
        if #options >= 3 then break end  -- Leave room for goodbye
        options[#options + 1] = "What about " .. kw .. "?"
    end

    -- Always include goodbye if room
    if #options < 4 then
        options[#options + 1] = "That is all, goodbye"
    end

    return options
end

-- ============================================================================
-- PROFILE LOOKUP
-- ============================================================================

local function getProfile(npcType)
    if not npcType then return profiles["commoner"] end

    local key = npcType:lower()

    -- Direct lookup first
    if profiles[key] then
        return profiles[key]
    end

    -- Try alias
    local aliasTarget = PROFESSION_ALIASES[key]
    if aliasTarget and profiles[aliasTarget] then
        return profiles[aliasTarget]
    end

    -- Fallback to commoner
    return profiles["commoner"]
end

-- ============================================================================
-- PROCESS (MAIN ENTRY POINT)
-- ============================================================================

function M.process(request)
    -- Validate request
    if not request then
        return {
            reply = "...",
            topic = "error",
            mood = "neutral",
            options = {},
            end_conversation = false,
        }
    end

    local message = request.message or ""
    local npcId = request.npc_id or "unknown"
    local npcType = request.npc_type or "commoner"
    local profile = getProfile(npcType)

    -- If no profile at all, return a generic response
    if not profile then
        return {
            reply = "I have nothing to say right now.",
            topic = "none",
            mood = "neutral",
            options = {"That is all, goodbye"},
            end_conversation = false,
        }
    end

    -- Get or create conversation state
    local cstate = getState(npcId)

    -- Check max turns
    if cstate.turn_count >= MAX_TURNS then
        return {
            reply = applyTemplate("It has been good talking, but I must attend to other matters. Farewell, {player_name}.", request),
            topic = "farewell",
            mood = profile.default_mood,
            options = {},
            end_conversation = true,
        }
    end

    -- Handle empty messages
    if message:match("^%s*$") then
        local noMatch = filterRecentAndPick(profile.no_match_responses, cstate)
        noMatch = applyTemplate(noMatch or "What was that?", request)
        stateUpdate(cstate, nil, message, noMatch)
        return {
            reply = noMatch,
            topic = "no_match",
            mood = profile.default_mood,
            options = generateOptions(profile, cstate),
            end_conversation = false,
        }
    end

    -- Normalize text and detect intent
    local tokens, normalizedText = normalizeText(message)
    local intent = detectIntent(message, tokens, normalizedText)

    -- Handle special intents: greeting, farewell, thanks, insult
    if intent == "greeting" then
        local text = selectSpecialIntentResponse("greeting", profile, cstate, request)
        text = text or applyTemplate("Hello, {player_name}.", request)
        stateUpdate(cstate, nil, message, text)
        return {
            reply = text,
            topic = "greeting",
            mood = profile.default_mood,
            options = generateOptions(profile, cstate),
            end_conversation = false,
        }
    end

    if intent == "farewell" then
        local text = selectSpecialIntentResponse("farewell", profile, cstate, request)
        text = text or applyTemplate("Farewell, {player_name}.", request)
        stateUpdate(cstate, nil, message, text)
        return {
            reply = text,
            topic = "farewell",
            mood = profile.default_mood,
            options = {},
            end_conversation = true,
        }
    end

    if intent == "thanks" then
        local text = selectSpecialIntentResponse("thanks", profile, cstate, request)
        text = text or "You are welcome."
        stateUpdate(cstate, nil, message, text)
        return {
            reply = text,
            topic = "thanks",
            mood = profile.default_mood,
            options = generateOptions(profile, cstate),
            end_conversation = false,
        }
    end

    if intent == "insult" then
        local text = selectSpecialIntentResponse("insult", profile, cstate, request)
        text = text or "I will not dignify that with a response."
        stateShiftMood(cstate, "negative")
        stateUpdate(cstate, nil, message, text)
        return {
            reply = text,
            topic = "insult",
            mood = cstate.mood or profile.default_mood,
            options = generateOptions(profile, cstate),
            end_conversation = false,
        }
    end

    -- Keyword matching: find the best topic
    local bestTopic, bestScore = findBestTopic(tokens, profile, cstate)

    if bestTopic then
        -- Check topic gating
        if not isTopicAccessible(bestTopic, profile, cstate) then
            -- Deflection response
            local deflect = filterRecentAndPick(profile.deflection, cstate)
            deflect = applyTemplate(deflect or "I cannot help you with that.", request)
            stateUpdate(cstate, nil, message, deflect)
            return {
                reply = deflect,
                topic = "deflection",
                mood = profile.default_mood,
                options = generateOptions(profile, cstate),
                end_conversation = false,
            }
        end

        -- Check banned topics
        if profile._banned_set[bestTopic] then
            local deflect = filterRecentAndPick(profile.deflection, cstate)
            deflect = applyTemplate(deflect or "I would rather not talk about that.", request)
            stateUpdate(cstate, nil, message, deflect)
            return {
                reply = deflect,
                topic = "deflection",
                mood = profile.default_mood,
                options = generateOptions(profile, cstate),
                end_conversation = false,
            }
        end

        -- Select topic response
        local text, mood, responseOptions = selectTopicResponse(bestTopic, profile, cstate, request)
        if text then
            stateUpdate(cstate, bestTopic, message, text)

            -- Use response-level options if provided, otherwise generate
            local opts = responseOptions or generateOptions(profile, cstate)

            return {
                reply = text,
                topic = bestTopic,
                mood = mood or profile.default_mood,
                options = opts,
                end_conversation = false,
            }
        end
    end

    -- No match: return no_match response
    local noMatch = filterRecentAndPick(profile.no_match_responses, cstate)
    noMatch = applyTemplate(noMatch or "I am not sure what you mean.", request)
    stateUpdate(cstate, nil, message, noMatch)

    return {
        reply = noMatch,
        topic = "no_match",
        mood = profile.default_mood,
        options = generateOptions(profile, cstate),
        end_conversation = false,
    }
end

-- ============================================================================
-- UTILITY: Reset conversation state for an NPC
-- ============================================================================

function M.resetState(npcId)
    if npcId then
        conversationStates[npcId] = nil
    end
end

-- ============================================================================
-- UTILITY: Reset all conversation states
-- ============================================================================

function M.resetAllStates()
    conversationStates = {}
end

-- ============================================================================
-- UTILITY: Check if initialized (profiles loaded)
-- ============================================================================

function M.isInitialized()
    local count = 0
    for _ in pairs(profiles) do
        count = count + 1
        if count > 0 then return true end
    end
    return false
end

-- ============================================================================
-- UTILITY: Get loaded profile count (for debugging)
-- ============================================================================

function M.getProfileCount()
    local count = 0
    for _ in pairs(profiles) do
        count = count + 1
    end
    return count
end

return M

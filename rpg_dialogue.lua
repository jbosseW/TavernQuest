-- RPG Dialogue System
-- Extracted from textrpg.lua

local M = {}

local state
local F

-- Local log helper (delegates to the shared log via F table / _G)
local function log(text, color)
    if F and F.log then
        F.log(text, color)
    elseif _G.log then
        _G.log(text, color)
    elseif state and state.textLog then
        table.insert(state.textLog, {text = text, color = color or {0.8, 0.8, 0.8}, time = love.timer.getTime()})
        if #state.textLog > 100 then
            table.remove(state.textLog, 1)
        end
    end
end

-- ============================================================================
-- DATA TABLES
-- ============================================================================

-- Weather dialogue responses by weather type and opinion
local WEATHER_DIALOGUE = {
    sunny = {
        positive = {"Beautiful day, isn't it?", "The sun warms my old bones.", "Perfect weather for working outdoors!"},
        neutral = {"Another sunny day.", "At least it's not raining.", "The sun is quite bright today."},
        negative = {"Too hot for my liking.", "This heat is unbearable.", "I wish it would cool down."}
    },
    cloudy = {
        positive = {"Nice and cool today.", "Good day for a walk.", "I prefer these overcast skies."},
        neutral = {"Looks like rain might be coming.", "Grey skies today.", "The clouds are rolling in."},
        negative = {"Gloomy weather again.", "These clouds dampen my spirits.", "I miss the sun."}
    },
    rainy = {
        positive = {"Good for the crops!", "I love the sound of rain.", "The land needs this."},
        neutral = {"Wet day today.", "Better stay inside.", "The rain keeps falling."},
        negative = {"This rain ruins everything!", "My joints ache in this weather.", "When will it stop?"}
    },
    stormy = {
        positive = {"Exciting weather!", "Nature shows its power.", "I find storms invigorating."},
        neutral = {"Stay safe in this storm.", "The thunder is loud today.", "Best not to travel far."},
        negative = {"Terrible storm outside!", "I fear for the livestock.", "This weather frightens me."}
    },
    foggy = {
        positive = {"Mysterious weather today.", "The mist is quite beautiful.", "Good cover for hunting."},
        neutral = {"Can barely see ahead.", "The fog is thick today.", "Watch your step in this fog."},
        negative = {"This fog hides dangers.", "I can't see anything!", "Eerie weather we're having."}
    },
    snowy = {
        positive = {"How beautiful the snow is!", "A true Frosthollow wonderland!", "I love fresh snowfall."},
        neutral = {"Frosthollow is upon us.", "The snow keeps falling.", "Bundle up warm."},
        negative = {"This cold bites to the bone!", "Too much snow again.", "I hate the Frosthollow."}
    },
    windy = {
        positive = {"Brisk and refreshing!", "Good wind for the mills.", "I enjoy a good breeze."},
        neutral = {"Hold onto your hat!", "Quite windy today.", "The wind howls outside."},
        negative = {"This wind is terrible!", "Can barely walk in this gale.", "My roof might blow off!"}
    },
    pleasant = {
        positive = {"Couldn't ask for better weather!", "What a lovely day!", "Perfect in every way."},
        neutral = {"Nice enough weather.", "Can't complain about today.", "Weather's fine."},
        negative = {"Even good weather doesn't lift my spirits.", "I suppose it's nice out.", "Whatever."}
    }
}

-- Political topics and opinions
local POLITICAL_TOPICS = {
    {topic = "the King",
        positive = {"Long live the King! He keeps us safe.", "Our King is wise and just.", "The crown protects us all."},
        neutral = {"The King does what he must.", "Politics is above my station.", "I don't follow court matters."},
        negative = {"The King's taxes bleed us dry!", "When did royalty last visit us?", "The throne cares nothing for common folk."}},
    {topic = "the war in the north",
        positive = {"Our soldiers are brave!", "We must defend our borders.", "Victory will be ours!"},
        neutral = {"War is terrible, but necessary.", "I pray for peace.", "Both sides have their reasons."},
        negative = {"This war takes our children!", "Pointless bloodshed!", "Who benefits from this war? Not us."}},
    {topic = "the merchant guilds",
        positive = {"They bring prosperity!", "Trade makes us all wealthy.", "The guilds know business."},
        neutral = {"Merchants will be merchants.", "They serve their purpose.", "I deal with them when I must."},
        negative = {"Greedy coin-counters!", "They fix prices against us!", "Guilds only help themselves."}},
    {topic = "the local lord",
        positive = {"Our lord protects this land.", "A fair and noble leader.", "We're lucky to have such governance."},
        neutral = {"The lord has his duties.", "I've never met them personally.", "Nobles live different lives."},
        negative = {"That tyrant in the manor?", "Our lord is never here when needed!", "All they do is collect taxes!"}},
    {topic = "the mages' council",
        positive = {"Magic protects us all!", "Wise practitioners of the arts.", "We need their knowledge."},
        neutral = {"I don't understand magic.", "They keep to themselves.", "Magic is beyond common folk."},
        negative = {"Meddling with forces best left alone!", "Magic brings nothing but trouble!", "I don't trust spellcasters."}},
    {topic = "adventurers",
        positive = {"Heroes walk among us!", "Thank the gods for adventurers!", "They keep the roads safe."},
        neutral = {"Adventurers come and go.", "Some good, some trouble.", "They're just doing their job."},
        negative = {"They bring danger wherever they go!", "More trouble than they're worth!", "Leave us simple folk alone!"}},
}

-- Mood/feeling expressions
local MOOD_EXPRESSIONS = {
    happy = {
        "Life is good!", "I'm feeling wonderful today!", "Things are looking up!",
        "Can't complain - actually, I won't!", "Today is a blessing.",
        "My heart is light today.", "Everything's coming together nicely!"
    },
    content = {
        "I'm doing well enough.", "Can't complain.", "Life goes on.",
        "Same as always, really.", "I'm content with what I have.",
        "No troubles to speak of.", "Getting by just fine."
    },
    worried = {
        "Times are uncertain...", "I've been anxious lately.", "There's much to worry about.",
        "I can't shake this feeling of dread.", "Dark thoughts plague me.",
        "I fear what tomorrow brings.", "So much uncertainty in the air."
    },
    sad = {
        "I've seen better days...", "My spirits are low.", "Life has been hard lately.",
        "I miss the old times.", "Sadness weighs on my heart.",
        "It's been difficult recently.", "I try to stay positive, but..."
    },
    angry = {
        "Don't get me started!", "Everything frustrates me lately!", "I've had it up to here!",
        "People test my patience daily!", "Nothing works the way it should!",
        "The world seems against me!", "I can barely contain my anger!"
    },
    tired = {
        "I'm exhausted...", "Sleep doesn't come easy.", "So much work, so little rest.",
        "My bones ache from labor.", "I could sleep for days.",
        "Just so tired lately.", "When did life become so draining?"
    }
}

-- === RACIAL ATTITUDE SYSTEM ===
-- How NPC races feel about player races, modified by region

-- Base attitudes: npc_race -> player_race -> attitude
-- Scale: "welcoming" > "friendly" > "neutral" > "cautious" > "hostile"
-- Special (don't shift): "fearful", "reverent", "awed", "curious"
local RACIAL_ATTITUDES = {
    human = {
        human = "friendly", elf = "neutral", dwarf = "friendly", orc = "cautious",
        goblin = "cautious", gnome = "neutral", catfolk = "curious", lizardfolk = "cautious",
    },
    elf = {
        human = "neutral", elf = "welcoming", dwarf = "neutral", orc = "hostile",
        goblin = "cautious", gnome = "neutral", catfolk = "neutral", lizardfolk = "cautious",
    },
    dwarf = {
        human = "friendly", elf = "neutral", dwarf = "welcoming", orc = "hostile",
        goblin = "hostile", gnome = "friendly", catfolk = "neutral", lizardfolk = "cautious",
    },
    orc = {
        human = "cautious", elf = "hostile", dwarf = "hostile", orc = "welcoming",
        goblin = "friendly", gnome = "cautious", catfolk = "neutral", lizardfolk = "neutral",
    },
    gnome = {
        human = "neutral", elf = "neutral", dwarf = "friendly", orc = "cautious",
        goblin = "cautious", gnome = "welcoming", catfolk = "curious", lizardfolk = "neutral",
    },
    goblin = {
        human = "cautious", elf = "cautious", dwarf = "hostile", orc = "friendly",
        goblin = "welcoming", gnome = "cautious", catfolk = "cautious", lizardfolk = "neutral",
    },
    catfolk = {
        human = "neutral", elf = "neutral", dwarf = "neutral", orc = "cautious",
        goblin = "cautious", gnome = "curious", catfolk = "welcoming", lizardfolk = "neutral",
    },
    lizardfolk = {
        human = "cautious", elf = "cautious", dwarf = "neutral", orc = "neutral",
        goblin = "neutral", gnome = "neutral", catfolk = "neutral", lizardfolk = "welcoming",
    },
}

-- Region modifiers: shift attitudes up (+1 friendlier) or down (-1 more hostile)
local REGION_ATTITUDE_SHIFTS = {
    holy_dominion = {
        human = 1, elf = 0, dwarf = 0,
        orc = -1, goblin = -1, lizardfolk = -1,
    },
    dwarven_mountains = {
        dwarf = 1, gnome = 1, human = 0,
        orc = -1, goblin = -2, elf = 0,
    },
    orcish_steppes = {
        orc = 1, goblin = 1,
        human = -1, elf = -1, dwarf = -1,
    },
    shadowfen = {
        lizardfolk = 1, goblin = 0,
        human = -1, elf = -1,
    },
    gnomish_isles = {
        gnome = 1, dwarf = 1,
        orc = -1, goblin = -1,
    },
    great_endless_desert = {
        catfolk = 1,
        human = 0, lizardfolk = 0,
    },
}

-- Generic greetings by attitude level
local RACE_GREETINGS = {
    welcoming = {
        "Welcome, welcome! Always good to see your kind here!",
        "Ah, a kindred spirit! Come, come!",
        "You honor us with your presence!",
    },
    friendly = {
        "Well met, traveler!", "Good to see you!",
        "Greetings, friend. What can I do for you?",
    },
    neutral = {
        "Greetings.", "What brings you here?",
        "Hmm. What do you need?",
    },
    cautious = {
        "Hmm... your kind aren't often seen around here.",
        "I'll be watching you, outsider.",
        "State your business.",
    },
    hostile = {
        "Your kind isn't welcome here. Move along.",
        "You've got nerve showing your face around here.",
        "I have nothing to say to the likes of you.",
    },
    fearful = {
        "By the gods... what ARE you?",
        "Stay back! Don't come any closer!",
        "I... I've heard stories about your kind...",
    },
    reverent = {
        "It is an honor! A true blessing upon us!",
        "The divine walks among us! How may I serve?",
        "I am humbled by your presence.",
    },
    awed = {
        "I... I never thought I'd see one of your kind.",
        "By the ancestors... is this real?",
        "Incredible. Simply incredible.",
    },
    curious = {
        "Fascinating! I've read about your kind but never met one!",
        "My, you're an interesting one! Tell me about yourself!",
        "Well now, isn't THIS a surprise! Welcome!",
    },
}

-- NPC-race-specific comments about player races (lore-driven flavor)
local RACE_SPECIFIC_COMMENTS = {
    dwarf = {
        elf = {"At least you don't stink like an orc.", "Your folk live too long and learn too little, if you ask me."},
        orc = {"Keep your axes sheathed in my shop, greenskin.", "We haven't forgotten the Siege of Ironpeak."},
        gnome = {"Your tinkering folk make decent gear, I'll grant you that.", "Small but crafty, you lot."},
        goblin = {"Touch anything and you'll lose the hand.", "I count my stock twice when goblins are about. No offense—just business."},
        human = {"Your folk trade fair enough. That's all I ask.", "Humans — reliable customers, at least."},
        catfolk = {"Fur and forges don't mix well, friend.", "You're a long way from the sands, whiskers."},
        lizardfolk = {"The deep mines have lizards bigger than you. No offense.", "Cold-blooded in the cold mountains... you're bold."},
    },
    elf = {
        dwarf = {"Do try not to track mud everywhere.", "Your kind builds well, if crudely."},
        orc = {"The ancient wounds between our peoples run deep.", "I sense violence in your blood. Prove me wrong."},
        human = {"So brief, your lives. Yet you accomplish much.", "Your kind's ambition is... admirable, if reckless."},
        gnome = {"Clever little inventors. Just keep the noise down.", "Your contraptions are fascinating, if chaotic."},
        goblin = {"I will not pretend comfort with your presence.", "Speak quickly and leave quickly. The empire's propaganda about your kind is... exaggerated, but caution is warranted."},
        catfolk = {"Graceful, for a furred creature. I can respect that.", "Your kind has a certain... wild elegance."},
        lizardfolk = {"The swamps hold ancient magic. I sense it on you.", "Your people keep old ways. There is wisdom in that."},
    },
    orc = {
        human = {"You're tougher than most pink-skins. I respect that.", "Humans die easy but fight hard. Interesting."},
        elf = {"Pointy-ears in my territory? Bold.", "Your arrows mean nothing up close."},
        dwarf = {"Short and stubborn as a mountain. Almost admirable.", "At least you know how to swing a hammer."},
        goblin = {"You fight the empire. That earns respect.", "Small but fierce. The empire underestimates you. Their mistake."},
        gnome = {"What even ARE you? Some kind of tiny elf?", "Don't blow anything up in here."},
        catfolk = {"Fast and slippery. Could use you in a raid.", "You fight like a cornered animal. Good."},
        lizardfolk = {"Tough hide. The swamp breeds survivors.", "You don't talk much. I like that."},
    },
    gnome = {
        dwarf = {"A fellow craftsman! Your metalwork is always welcome.", "Dwarves understand the value of precision."},
        orc = {"Please don't break anything. These devices are delicate.", "I've reinforced the furniture, so... welcome."},
        elf = {"Your magical theory is elegant, if impractical.", "Welcome! We have much to discuss — academically."},
        human = {"Ah, a human! Always eager customers.", "Welcome to the workshop. Mind the gears."},
        goblin = {"Hmm. A goblin. My security systems are active, just so you know.", "If you can resist touching things, we'll get along."},
        catfolk = {"Careful with that tail near the machinery!", "Curious creatures, you catfolk. I appreciate curiosity."},
        lizardfolk = {"Interesting thermal regulation! Cold-blooded physiology is fascinating.", "Welcome! Mind the steam vents — they run hot."},
    },
    human = {
        orc = {"Keep the peace here and we'll have no trouble.", "The guard keeps a close eye. Fair warning."},
        goblin = {"Watch yourself. People here are... wary.", "I'd keep a low profile if I were you."},
        elf = {"Your kind's always welcome. Wise folk, elves.", "An elf! We don't see many of your kind."},
        dwarf = {"A dwarf! The smiths will be pleased.", "Stout folk are always welcome here."},
        lizardfolk = {"You're... a long way from the swamps.", "Don't mind the stares. Not many of your kind pass through."},
        catfolk = {"A catfolk! The children will be fascinated.", "Welcome! Your kind has a reputation for good trade."},
        gnome = {"A gnome! I hear your people make the most wondrous contraptions.", "Welcome, little friend. Mind the doorframes."},
    },
    catfolk = {
        human = {"Welcome, traveler. Rest your weary paws... er, feet.", "You smell of the road. Good travels?"},
        lizardfolk = {"Cold-blood! Not often we see your kind in the sands.", "The desert treats all equally, scale-friend."},
        gnome = {"Ooh, tiny and interesting! What gadgets do you carry?", "Don't mind me... just curious about your pockets."},
        orc = {"Big and loud. Try not to scare the kittens.", "The sand wolves are bigger. You'll fit right in."},
    },
    lizardfolk = {
        human = {"Warm-blood. The swamp cares not for your kind.", "Speak. I listen."},
        elf = {"Tree-dwellers venture to the marsh? Unusual.", "Your magic smells different here."},
        orc = {"Strong. Good. The swamp respects strength.", "You survive, you belong. Simple."},
        catfolk = {"Fur does not last in the swamp. You are brave.", "The dry-landers visit. Interesting."},
    },
    goblin = {
        dwarf = {"Don't crush me, boulder-brain!", "You stay neutral. We remember that. Better than the empire, at least."},
        human = {"You imperial? Then get lost. You anti-imperial? Prove it.", "Don't tell the guards I'm here. Or do. Give me a reason to make you disappear."},
        orc = {"Your people understand fighting empires. We can work together.", "The empire screwed your clans too. Common enemy, yeah?"},
        elf = {"You lot talk about 'order' while the empire burns our warrens. Save the speeches.", "Elves acknowledge our land claims but say 'escalation is unproductive.' How's that working for you?"},
        gnome = {"You study us like insects. We fight empires while you take notes.", "Your 'research' won't stop imperial soldiers. Pick a side or stay out of the way."},
        lizardfolk = {"Shadow Fen helps us. You're good people. The empire will pay for what they did to you too.", "Scaled folk understand occupation. We share intelligence. We share the fight."},
        catfolk = {"Beast Folk know displacement. Your caravans help us. We don't forget allies.", "You walk the roads. We walk the tunnels. Both got screwed by the empire. Stay safe out there."},
    },
}

-- Sickness types and symptoms
local SICKNESS_TYPES = {
    {name = "fever", symptoms = {"I've been burning up with fever...", "This terrible fever won't break.", "I'm so hot, yet I shiver."},
        helpText = "I need medicine... perhaps some Healing Herbs would help?", cureCost = 30, cureItem = "Feverfew Tea"},
    {name = "cough", symptoms = {"This cough won't stop...", "*cough cough* Excuse me...", "My chest aches from coughing."},
        helpText = "Do you know where I could find some remedy?", cureCost = 25, cureItem = "Honey Elixir"},
    {name = "weakness", symptoms = {"I can barely stand...", "My strength has left me.", "Everything feels so heavy."},
        helpText = "I need something to restore my strength...", cureCost = 40, cureItem = "Strength Tonic"},
    {name = "headache", symptoms = {"My head is splitting...", "This headache is unbearable.", "I can't think straight with this pain."},
        helpText = "Some medicine would be a blessing...", cureCost = 20, cureItem = "Willow Bark"},
    {name = "stomach illness", symptoms = {"My stomach is in knots...", "I can barely keep food down.", "This nausea is terrible."},
        helpText = "I haven't eaten in days... I need healing.", cureCost = 35, cureItem = "Ginger Root"},
}

-- Gossip and rumors
local GOSSIP_TEMPLATES = {
    "Did you hear about %s? They say %s.",
    "I shouldn't say this, but %s apparently %s.",
    "Word around town is that %s %s.",
    "Between you and me, %s %s.",
    "My neighbor told me %s %s.",
}

local GOSSIP_SUBJECTS = {
    "the blacksmith", "the innkeeper", "the merchant", "old Gregor", "the miller's daughter",
    "the baker", "that strange traveler", "the mayor", "the healer", "young Thomas",
}

local GOSSIP_RUMORS = {
    "has been acting strange lately", "found treasure in the old ruins",
    "was seen talking to suspicious figures", "is secretly very wealthy",
    "has a hidden past", "might be leaving town soon",
    "discovered something in the forest", "has been having strange dreams",
    "made a deal with someone powerful", "knows more than they let on",
}

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

M.F_FUNCTIONS = {
    "generateWeatherDialogue", "generateMoodDialogue", "generatePoliticsDialogue",
    "generateRaceGreeting", "generateRaceOpinionDialogue", "generateGossip",
    "generateHealQuest", "buildDialogueOptions", "getRelationshipDialogue",
    "getRacialAttitude", "generateNPCState",
}

function M.register(s, f)
    state = s
    F = f
    for _, name in ipairs(M.F_FUNCTIONS) do
        if M[name] then F[name] = M[name] end
    end
end

-- ============================================================================
-- RACIAL ATTITUDES
-- ============================================================================

-- Compute final racial attitude given NPC race, player race, and region
M.getRacialAttitude = function(npcRace, playerRace, region)
    local base = RACIAL_ATTITUDES[npcRace] and RACIAL_ATTITUDES[npcRace][playerRace]
    if not base then base = "neutral" end

    -- Special attitudes don't shift on the scale
    if base == "fearful" or base == "reverent" or base == "awed" or base == "curious" then
        return base
    end

    local scale = {"hostile", "cautious", "neutral", "friendly", "welcoming"}
    local idx = 3
    for i, v in ipairs(scale) do
        if v == base then idx = i break end
    end

    local shift = REGION_ATTITUDE_SHIFTS[region] and REGION_ATTITUDE_SHIFTS[region][playerRace] or 0
    idx = math.max(1, math.min(5, idx + shift))

    return scale[idx]
end

-- ============================================================================
-- NPC STATE GENERATION
-- ============================================================================

-- Generate NPC state when first talking (mood, health, opinions)
M.generateNPCState = function(npc)
    if npc.dialogueState then return end  -- Already generated

    npc.dialogueState = {
        mood = ({"happy", "content", "content", "content", "worried", "sad", "tired"})[math.random(7)],
        isSick = math.random() < 0.15,  -- 15% chance of being sick
        sickness = nil,
        politicalOpinions = {},
        weatherOpinion = ({"positive", "neutral", "neutral", "negative"})[math.random(4)],
        hasGossip = math.random() < 0.4,  -- 40% chance to have gossip
        talkedAbout = {},  -- Track what topics we've discussed
    }

    -- Assign sickness if sick
    if npc.dialogueState.isSick then
        npc.dialogueState.sickness = SICKNESS_TYPES[math.random(#SICKNESS_TYPES)]
        npc.dialogueState.mood = "tired"  -- Sick NPCs are tired
    end

    -- Generate political opinions (positive, neutral, or negative for each topic)
    for _, topic in ipairs(POLITICAL_TOPICS) do
        npc.dialogueState.politicalOpinions[topic.topic] = ({"positive", "neutral", "neutral", "negative"})[math.random(4)]
    end

    -- Compute racial attitude toward player
    if state.player and state.player.race then
        local region = state.world and state.world.currentTown and state.world.currentTown.region
        npc.dialogueState.raceAttitude = M.getRacialAttitude(npc.race or "human", state.player.race, region)
    end
end

-- ============================================================================
-- DIALOGUE GENERATION FUNCTIONS
-- ============================================================================

-- Generate dialogue about weather
M.generateWeatherDialogue = function(npc)
    M.generateNPCState(npc)
    local weather = F.getCurrentWeather()
    local opinion = npc.dialogueState.weatherOpinion
    local dialogues = WEATHER_DIALOGUE[weather] and WEATHER_DIALOGUE[weather][opinion]
    if dialogues then
        return dialogues[math.random(#dialogues)]
    end
    return "The weather is... weather."
end

-- Generate dialogue about feelings/mood
M.generateMoodDialogue = function(npc)
    M.generateNPCState(npc)
    local mood = npc.dialogueState.mood

    -- If sick, mention it
    if npc.dialogueState.isSick and npc.dialogueState.sickness then
        local sickness = npc.dialogueState.sickness
        return sickness.symptoms[math.random(#sickness.symptoms)]
    end

    local expressions = MOOD_EXPRESSIONS[mood]
    if expressions then
        return expressions[math.random(#expressions)]
    end
    return "I'm doing alright."
end

-- Generate dialogue about politics
M.generatePoliticsDialogue = function(npc)
    M.generateNPCState(npc)
    local topic = POLITICAL_TOPICS[math.random(#POLITICAL_TOPICS)]
    local opinion = npc.dialogueState.politicalOpinions[topic.topic] or "neutral"
    local dialogues = topic[opinion]
    if dialogues then
        local prefix = "About " .. topic.topic .. "? "
        return prefix .. dialogues[math.random(#dialogues)]
    end
    return "I try not to get involved in politics."
end

-- Generate race-based greeting (returns nil for neutral attitude = fall through to profession greeting)
M.generateRaceGreeting = function(npc)
    if not state.player or not state.player.race then return nil end
    local playerRace = state.player.race
    local npcRace = npc.race or "human"
    local region = state.world and state.world.currentTown and state.world.currentTown.region

    local attitude = M.getRacialAttitude(npcRace, playerRace, region)

    -- Neutral attitude = no race comment, fall through to profession greeting
    if attitude == "neutral" then return nil end

    -- Check for specific NPC-race-to-player-race comment first (50% chance)
    local specific = RACE_SPECIFIC_COMMENTS[npcRace] and RACE_SPECIFIC_COMMENTS[npcRace][playerRace]
    if specific and math.random() < 0.5 then
        return specific[math.random(#specific)]
    end

    -- Otherwise use generic attitude greeting
    local greetings = RACE_GREETINGS[attitude]
    if greetings then
        return greetings[math.random(#greetings)]
    end

    return nil
end

-- Generate dialogue when player asks "What do you think of my kind?"
M.generateRaceOpinionDialogue = function(npc)
    if not state.player or not state.player.race then return "I have no opinion." end
    local playerRace = state.player.race
    local npcRace = npc.race or "human"

    -- Try specific comment first
    local specific = RACE_SPECIFIC_COMMENTS[npcRace] and RACE_SPECIFIC_COMMENTS[npcRace][playerRace]
    if specific then
        return specific[math.random(#specific)]
    end

    -- Fall back to generic attitude response
    local attitude = npc.dialogueState and npc.dialogueState.raceAttitude or "neutral"
    local responses = {
        welcoming = "Your people are always welcome here. We consider you kin.",
        friendly = "I've always gotten along well with your kind. Good people.",
        neutral = "I have no strong feelings either way. You seem decent enough.",
        cautious = "I'll be honest... your kind makes me uneasy. But I'll give you a chance.",
        hostile = "I'll speak plainly. Your people have caused mine nothing but grief.",
        fearful = "Forgive me, but... your kind unsettles me deeply. What even are you?",
        reverent = "Your kind is blessed by the divine! It is an honor to even speak with you.",
        awed = "I never thought I'd meet one of your kind. The stories don't do you justice.",
        curious = "I find your kind absolutely fascinating! I have so many questions!",
    }
    return responses[attitude] or "I have no opinion."
end

-- Generate gossip
M.generateGossip = function(npc)
    M.generateNPCState(npc)
    if not npc.dialogueState.hasGossip then
        return "I don't pay attention to rumors."
    end

    -- Try to get a world rumor first (60% chance if in a town)
    if state.currentTown and math.random() < 0.6 then
        local RumorSystem = require("rumorsystem")
        RumorSystem.init(state)
        local rumorDialogue, rumorData = RumorSystem.getNPCRumorDialogue(state.currentTown.id)
        if rumorDialogue and rumorData and rumorData.type ~= "small_talk" then
            return rumorDialogue
        end
    end

    -- Fall back to generic gossip
    local template = GOSSIP_TEMPLATES[math.random(#GOSSIP_TEMPLATES)]
    local subject = GOSSIP_SUBJECTS[math.random(#GOSSIP_SUBJECTS)]
    local rumor = GOSSIP_RUMORS[math.random(#GOSSIP_RUMORS)]

    return string.format(template, subject, rumor)
end

-- Generate help quest for sick NPC
M.generateHealQuest = function(npc)
    if not npc.dialogueState or not npc.dialogueState.isSick then return nil end

    local sickness = npc.dialogueState.sickness
    local cureItem = sickness.cureItem or "Healing Herbs"
    local symptom = sickness.symptoms[math.random(#sickness.symptoms)]

    local quest = {
        type = "heal",
        name = "Help " .. npc.name,
        desc = npc.name .. " is suffering from " .. sickness.name .. ". Find " .. cureItem .. " or pay " .. sickness.cureCost .. " gold for treatment.",
        giver = npc.name,
        target = 1,
        progress = 0,
        goldReward = sickness.cureCost + 20,
        xpReward = 15 + state.player.level * 3,
        healCost = sickness.cureCost,
        cureItem = cureItem,
        accepted = false,
        completed = false,
        npcRef = npc,
    }

    local text = symptom .. " " .. sickness.helpText .. " If only someone could bring me " .. cureItem .. " or help pay for a healer..."

    return {text = text, quest = quest}
end

-- Build comprehensive dialogue options
M.buildDialogueOptions = function(npc)
    M.generateNPCState(npc)
    local opts = {}

    -- NEW QUEST SYSTEM: Check for quests from new expansion
    local availableQuests = F.getAvailableQuestsFromNPC(npc)

    -- Quests ready to complete
    if availableQuests.readyToComplete and #availableQuests.readyToComplete > 0 then
        for _, quest in ipairs(availableQuests.readyToComplete) do
            table.insert(opts, {text = "[✓ Complete Quest] " .. quest.name, action = "complete_quest_new", quest = quest, color = {0.4, 1.0, 0.4}})
        end
    end

    -- New quests available
    if availableQuests.available and #availableQuests.available > 0 then
        for _, questInfo in ipairs(availableQuests.available) do
            if questInfo.meetsRequirements then
                table.insert(opts, {text = "[❗ New Quest] " .. questInfo.template.name, action = "view_quest_new", questInfo = questInfo, color = {1.0, 0.84, 0.0}})
            else
                table.insert(opts, {text = "[? Quest] " .. questInfo.template.name .. " (" .. questInfo.requirementReason .. ")", action = "view_quest_locked", questInfo = questInfo, color = {0.6, 0.6, 0.6}})
            end
        end
    end

    -- OLD QUEST SYSTEM: Keep backward compatibility
    if npc.hasQuest and npc.quest and not npc.quest.accepted then
        table.insert(opts, {text = "Ask about work", action = "ask_work"})
        table.insert(opts, {text = "Accept: " .. npc.quest.name, action = "accept_quest", quest = npc.quest})
    end

    -- Sick NPC help option
    if npc.dialogueState.isSick and not npc.dialogueState.talkedAbout.sickness then
        table.insert(opts, {text = "You don't look well...", action = "ask_health"})
    end

    -- Conversation options
    if not npc.dialogueState.talkedAbout.mood then
        table.insert(opts, {text = "How are you?", action = "ask_mood"})
    end
    if not npc.dialogueState.talkedAbout.weather then
        table.insert(opts, {text = "Nice weather today?", action = "ask_weather"})
    end
    if not npc.dialogueState.talkedAbout.politics then
        table.insert(opts, {text = "What's the news?", action = "ask_politics"})
    end
    if not npc.dialogueState.talkedAbout.gossip then
        table.insert(opts, {text = "Heard any rumors?", action = "ask_gossip"})
    end

    -- Location knowledge (NPCs can reveal nearby locations)
    if npc.revealsLocation and not npc.dialogueState.talkedAbout.location then
        table.insert(opts, {text = "Know any interesting places nearby?", action = "ask_location"})
    end

    -- Race-specific dialogue option (only if NPC is a different race and has something to say)
    if not npc.dialogueState.talkedAbout.race then
        local playerRace = state.player and state.player.race
        local npcRace = npc.race or "human"
        if playerRace and playerRace ~= npcRace then
            local specific = RACE_SPECIFIC_COMMENTS[npcRace] and RACE_SPECIFIC_COMMENTS[npcRace][playerRace]
            local attitude = npc.dialogueState.raceAttitude or "neutral"
            if specific or attitude ~= "neutral" then
                table.insert(opts, {text = "What do you think of my kind?", action = "ask_race"})
            end
        end
    end

    -- Show relationship status
    local relationship = F.getNPCRelationship(npc.id)
    if relationship then
        table.insert(opts, {text = "[❤️ Relationship: " .. relationship.relationshipLevel .. " (" .. relationship.reputation .. ")]", action = "view_relationship", color = {1.0, 0.6, 0.8}})
    end

    -- Free Talk chatbot option
    if not F.isFreeTalkActive or not F.isFreeTalkActive() then
        table.insert(opts, {text = "[Free Talk]", action = "free_talk", color = {0.3, 0.7, 1.0}})
    end

    -- Always have goodbye
    table.insert(opts, {text = "Goodbye", action = "leave"})

    -- CRIME: Attack civilian option (red color)
    table.insert(opts, {text = "[⚔️ Attack]", action = "attack_civilian", color = {0.9, 0.2, 0.2}})

    -- VAMPIRE: Bite option (only if vampire and NPC is asleep)
    if state.player and state.player.isVampire and F.isNPCAsleep(npc) then
        table.insert(opts, {text = "[🦇 Bite] (Turn into vampire)", action = "vampire_bite", color = {0.8, 0.2, 0.3}})
    end

    return opts
end

-- ============================================================================
-- RELATIONSHIP DIALOGUE
-- ============================================================================

M.getRelationshipDialogue = function(npc)
    if not npc or not npc.id then return nil end

    local relationship = F.getNPCRelationship(npc.id)
    local level = relationship.relationshipLevel

    -- Modify greeting based on relationship
    local greetingModifiers = {
        loved = {"My dear friend!", "Always a pleasure!", "Welcome, welcome!"},
        friendly = {"Good to see you!", "Hello friend!", "Greetings!"},
        neutral = {"Hello.", "Yes?", "Can I help you?"},
        disliked = {"What do you want?", "You again...", "Make it quick."},
        hated = {"Get out of my sight!", "I don't want your business!", "Leave!"},
    }

    local modifiers = greetingModifiers[level]
    if modifiers then
        return modifiers[math.random(1, #modifiers)]
    end

    return nil
end

return M

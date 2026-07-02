-- Cutscene System - Placeholder cutscene queue and display
-- Provides a system for queuing story cutscenes (text-based with speaker portraits)
-- Each cutscene is a sequence of dialogue lines with speaker, text, and optional effects.

local Cutscenes = {}

-- Font cache
local FontCache = require("fontcache")
local function getFont(size)
    return FontCache.get(size)
end

-- ============================================================================
--                        CUTSCENE STATE
-- ============================================================================

local cutsceneState = {
    active = false,
    currentCutscene = nil,
    currentLine = 1,
    textProgress = 0,      -- For typewriter effect (characters revealed)
    textSpeed = 40,        -- Characters per second
    timer = 0,
    skipping = false,
    onComplete = nil,      -- Callback when cutscene ends
    queue = {},            -- Queue of pending cutscenes
}

-- Colors
local colors = {
    bg = {0, 0, 0, 0.85},
    dialogueBox = {0.08, 0.08, 0.12, 0.95},
    border = {0.6, 0.5, 0.3},
    speakerName = {0.9, 0.7, 0.3},
    text = {0.9, 0.9, 0.9},
    continueHint = {0.5, 0.5, 0.5},
    narratorName = {0.6, 0.7, 0.9},
}

-- ============================================================================
--                      CUTSCENE DEFINITIONS
-- ============================================================================

-- All cutscene data is defined here. Each cutscene is an array of lines.
-- Line format: {speaker = "Name", text = "Dialogue text", effect = "optional_effect"}
-- Speaker of "" or nil means narrator text.

Cutscenes.SCENES = {
    -- =====================================================================
    -- PRISON ESCAPE CUTSCENES
    -- =====================================================================

    intro_wake_up = {
        id = "intro_wake_up",
        title = "Awakening",
        music = nil,  -- placeholder for prison ambient track
        lines = {
            {speaker = nil, text = "Darkness. Cold stone against your face. The taste of iron and grime."},
            {speaker = nil, text = "Your head pounds. Your wrists ache under the weight of iron cuffs. You have no memory of how long you have been here."},
            {speaker = nil, text = "A thin shaft of grey light seeps through a crack in the ceiling. Somewhere above, the sea crashes against stone."},
            {speaker = nil, text = "This is The Sunken Ledger, the Holy Dominion's prison. You are in the cell block below the docks."},
            {speaker = nil, text = "Your arrest warrant said 'sedition and forbidden knowledge.' You do not remember the trial. Perhaps there was none."},
            {speaker = nil, text = "But something stirs in you now. A refusal. A spark that the darkness has not yet extinguished."},
            {speaker = nil, text = "You will not die here."},
            {speaker = nil, text = "[Your cuffs weigh heavily on your wrists. All stats are reduced. Find a way to remove them.]", effect = "show_cuffs_debuff"},
            {speaker = nil, text = "[Search your cell for anything useful. Press SPACE or ENTER to interact with objects.]", effect = "tutorial_interact"},
        },
    },

    meet_grimjaw = {
        id = "meet_grimjaw",
        title = "The Orc in the Next Cell",
        lines = {
            {speaker = nil, text = "A voice rumbles from the cell across the corridor. Low, gravelly, deliberate."},
            {speaker = "Grimjaw", text = "You there. You have that look. The look of someone who does not plan to die here."},
            {speaker = nil, text = "You see a massive orc pressed against the bars of his cell. Scars crisscross his green skin. His eyes are sharp and calculating."},
            {speaker = "Grimjaw", text = "I am Grimjaw. Clan Ironmaw. They took my honor-blade when they threw me in here. Said I was too dangerous for regular confinement."},
            {speaker = "Grimjaw", text = "They were right about that."},
            {speaker = "Grimjaw", text = "Get these cuffs off me and open this cell, and I will fight beside you. I would rather die free than rot in chains."},
            {speaker = nil, text = "You unlock Grimjaw's restraints. He rolls his shoulders and cracks his knuckles with a grin."},
            {speaker = "Grimjaw", text = "Now we move. Stay behind me if the guards come. I will handle the rest."},
        },
    },

    meet_sera = {
        id = "meet_sera",
        title = "A Voice in the Shadows",
        lines = {
            {speaker = nil, text = "A hand shoots out from beneath a pile of rags and grabs your ankle. Before you can react..."},
            {speaker = "Sera Voss", text = "Psst. Over here. Keep your voice down unless you want every guard on this level to come running."},
            {speaker = nil, text = "A young woman emerges from what you thought was a pile of laundry. She moves like smoke: quick, silent, precise."},
            {speaker = "Sera Voss", text = "I am Sera. I used to work for the Crown. Intelligence division. Then I found something they wanted to stay buried."},
            {speaker = "Sera Voss", text = "I know every guard rotation in this place. I know which doors are weak and which corridors have blind spots."},
            {speaker = "Sera Voss", text = "Get me out of here and I will guide us to the surface. The docks are just one floor up."},
            {speaker = nil, text = "Sera slips her chains with practiced ease. She had already picked the lock days ago, just waiting for the right moment."},
            {speaker = "Sera Voss", text = "Lead on. I will watch our backs. And trust me, you want someone watching your back in this place."},
        },
    },

    meet_aldric = {
        id = "meet_aldric",
        title = "The Heretic Priest",
        lines = {
            {speaker = nil, text = "In a corner of the ruined chapel, a man kneels in prayer. A faint golden light emanates from his clasped hands."},
            {speaker = "Brother Aldric", text = "Blessings of Helios upon you, stranger. Even in this darkness, the light endures."},
            {speaker = nil, text = "He rises. His prison garb is worn but clean. Despite the grime of the prison, there is an unmistakable dignity about him."},
            {speaker = "Brother Aldric", text = "They call me heretic because I spoke truth to power. The Dominion has strayed far from the sun god's true teachings."},
            {speaker = "Brother Aldric", text = "I can heal wounds and shield against the darkness that lurks below. But my focus was shattered when they took me."},
            {speaker = "Brother Aldric", text = "Bring me a crystal shard, even a fragment will do, and I can fashion a new one. Then I will join your exodus."},
            {speaker = nil, text = "You hand Aldric a shard of crystal. Light flows through it, and his eyes regain their fire."},
            {speaker = "Brother Aldric", text = "The light returns. I am with you, friend. Let us deliver these lost souls from darkness."},
        },
    },

    meet_nyx = {
        id = "meet_nyx",
        title = "The Mad Artificer",
        lines = {
            {speaker = nil, text = "Behind a reinforced door, you hear rapid tapping and muttering."},
            {speaker = "Nyx", text = "Three turns clockwise, two counter, apply pressure at forty-five degrees and... BANG!"},
            {speaker = nil, text = "A small explosion rattles the door. Smoke seeps through the cracks."},
            {speaker = "Nyx", text = "Oh! OH! You are not a guard! You have that 'I am definitely escaping' energy and I am HERE for it!"},
            {speaker = nil, text = "A small goblin woman peers through the bars. Her fingers are stained with chemicals and her eyes are wild with intelligence."},
            {speaker = "Nyx", text = "They locked me up for making a device that lets ANYONE cast cantrips. Democratizing magic is apparently TREASON!"},
            {speaker = "Nyx", text = "The empire hoards magic like they hoarded our land! Monopoly on power. Monopoly on violence. I'm going to BREAK their monopoly!"},
            {speaker = "Nyx", text = "Get me out of here and I will build you things. Weapons. Tools. Distractions. BOMBS. All the things the empire doesn't want us to have!"},
            {speaker = nil, text = "You force open the reinforced lock. Nyx practically explodes out of the cell, already pulling components from hidden pockets."},
            {speaker = "Nyx", text = "FREEDOM! Oh, the things I am going to build. Stay close, I have SO many ideas and most of them probably will not explode. Probably."},
        },
    },

    warden_confrontation = {
        id = "warden_confrontation",
        title = "The Warden's Stand",
        lines = {
            {speaker = nil, text = "Daylight. After the dim cells below, the light is almost blinding. You can hear seagulls. The sea. Freedom is steps away."},
            {speaker = nil, text = "But a figure stands between you and the exit. Tall, armored, a heavy blade resting on his shoulder."},
            {speaker = "Warden Blackthorn", text = "I wondered when you would make it this far."},
            {speaker = "Warden Blackthorn", text = "You think you are escaping? You are a loose end. And I do not leave loose ends."},
            {speaker = "Warden Blackthorn", text = "The Crown sent you here to be forgotten. The Ledger keeps its secrets. ALL of them."},
            {speaker = "Warden Blackthorn", text = "Including you."},
            {speaker = nil, text = "[Boss Fight: Warden Blackthorn. Defeat him to reach the exit.]"},
        },
    },

    escape_surface = {
        id = "escape_surface",
        title = "Daylight",
        lines = {
            {speaker = nil, text = "The Warden falls. His blade clatters on the stone dock."},
            {speaker = nil, text = "Beyond the gate, the sea stretches to the horizon. Salt air fills your lungs. The sun, you had almost forgotten what it looked like, hangs low and golden over the water."},
            {speaker = nil, text = "You are free."},
            {speaker = nil, text = "But freedom is not safety. The Holy Dominion will not let escaped prisoners walk free. Your face is known. Your name is on every bounty board from here to Helios' Gate."},
            {speaker = nil, text = "You need new identities. New names. And allies who know how to make people disappear."},
            {speaker = nil, text = "As if on cue, a figure emerges from behind a stack of crates near the dock."},
        },
    },

    meet_thieves_guild = {
        id = "meet_thieves_guild",
        title = "The Crossed Daggers",
        lines = {
            {speaker = nil, text = "The figure is cloaked, face hidden. They hold up a hand showing a tattoo of two crossed daggers."},
            {speaker = "???", text = "You match the description. Took you long enough."},
            {speaker = "Guild Contact", text = "Name does not matter. What matters is that certain people invested in getting you out of The Ledger. And those people expect a return on their investment."},
            {speaker = "Guild Contact", text = "First things first. You cannot walk around with prison rags and a bounty. We have a safehouse inland. New clothes, new names, new start."},
            {speaker = "Guild Contact", text = "After that... well. The people who put you in The Ledger have secrets. Dangerous secrets. The kind that topple kingdoms."},
            {speaker = "Guild Contact", text = "The Veiled Hand wants those secrets. And you are going to help us get them."},
            {speaker = "Guild Contact", text = "Unless you prefer to go back to your cell?"},
            {speaker = nil, text = "[The prison escape is complete. Your adventure in the world above begins. Your crimes must be cleared. The truth must be uncovered.]"},
            {speaker = nil, text = "[You will now enter the main game world. Your prison allies will join your party. The Veiled Hand thieves guild will provide quests to clear your name.]"},
        },
    },
}

-- ============================================================================
--                      CUTSCENE API
-- ============================================================================

function Cutscenes.isActive()
    return cutsceneState.active
end

function Cutscenes.play(sceneId, onComplete)
    local scene = Cutscenes.SCENES[sceneId]
    if not scene then
        print("[Cutscenes] WARNING: Scene not found: " .. tostring(sceneId))
        if onComplete then onComplete() end
        return
    end

    cutsceneState.active = true
    cutsceneState.currentCutscene = scene
    cutsceneState.currentLine = 1
    cutsceneState.textProgress = 0
    cutsceneState.timer = 0
    cutsceneState.skipping = false
    cutsceneState.onComplete = onComplete
end

function Cutscenes.queue(sceneId, onComplete)
    table.insert(cutsceneState.queue, {id = sceneId, onComplete = onComplete})
    -- If not currently playing, start the first one
    if not cutsceneState.active then
        Cutscenes.playNext()
    end
end

function Cutscenes.playNext()
    if #cutsceneState.queue > 0 then
        local next = table.remove(cutsceneState.queue, 1)
        Cutscenes.play(next.id, next.onComplete)
    end
end

function Cutscenes.skip()
    if not cutsceneState.active then return end
    cutsceneState.active = false
    local callback = cutsceneState.onComplete
    cutsceneState.currentCutscene = nil
    cutsceneState.currentLine = 1
    cutsceneState.textProgress = 0
    if callback then callback() end
    -- Check queue
    Cutscenes.playNext()
end

function Cutscenes.advance()
    if not cutsceneState.active or not cutsceneState.currentCutscene then return end

    local scene = cutsceneState.currentCutscene
    local line = scene.lines[cutsceneState.currentLine]
    if not line then
        Cutscenes.skip()
        return
    end

    -- If text is still typing, complete it instantly
    if cutsceneState.textProgress < #line.text then
        cutsceneState.textProgress = #line.text
        return
    end

    -- Move to next line
    cutsceneState.currentLine = cutsceneState.currentLine + 1
    cutsceneState.textProgress = 0
    cutsceneState.timer = 0

    -- If past last line, end cutscene
    if cutsceneState.currentLine > #scene.lines then
        Cutscenes.skip()
    end
end

-- ============================================================================
--                      UPDATE & DRAW
-- ============================================================================

function Cutscenes.update(dt)
    if not cutsceneState.active or not cutsceneState.currentCutscene then return end

    local scene = cutsceneState.currentCutscene
    local line = scene.lines[cutsceneState.currentLine]
    if not line then return end

    -- Typewriter effect
    if cutsceneState.textProgress < #line.text then
        cutsceneState.timer = cutsceneState.timer + dt
        cutsceneState.textProgress = math.min(
            #line.text,
            math.floor(cutsceneState.timer * cutsceneState.textSpeed)
        )
    end
end

function Cutscenes.draw()
    if not cutsceneState.active or not cutsceneState.currentCutscene then return end

    local screenW, screenH = love.graphics.getDimensions()
    local scene = cutsceneState.currentCutscene
    local line = scene.lines[cutsceneState.currentLine]
    if not line then return end

    -- Full screen dark background
    love.graphics.setColor(colors.bg)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Title bar (top)
    if scene.title then
        love.graphics.setColor(colors.border)
        love.graphics.setFont(getFont(14))
        local titleText = string.upper(scene.title)
        local titleW = love.graphics.getFont():getWidth(titleText)
        love.graphics.print(titleText, screenW/2 - titleW/2, 20)
    end

    -- Dialogue box (bottom third of screen)
    local boxH = 200
    local boxW = screenW - 80
    local boxX = 40
    local boxY = screenH - boxH - 40

    -- Box background
    love.graphics.setColor(colors.dialogueBox)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 10, 10)

    -- Box border
    love.graphics.setColor(colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 10, 10)
    love.graphics.setLineWidth(1)

    -- Speaker name
    local textStartY = boxY + 15
    if line.speaker then
        love.graphics.setColor(colors.speakerName)
        love.graphics.setFont(getFont(20))
        love.graphics.print(line.speaker, boxX + 20, textStartY)
        textStartY = textStartY + 30
    else
        -- Narrator
        love.graphics.setColor(colors.narratorName)
        love.graphics.setFont(getFont(16))
        love.graphics.print("NARRATOR", boxX + 20, textStartY)
        textStartY = textStartY + 25
    end

    -- Dialogue text (with typewriter effect)
    love.graphics.setColor(colors.text)
    love.graphics.setFont(getFont(16))
    local displayText = line.text:sub(1, math.floor(cutsceneState.textProgress))
    love.graphics.printf(displayText, boxX + 20, textStartY, boxW - 40, "left")

    -- Continue hint
    if cutsceneState.textProgress >= #line.text then
        love.graphics.setColor(colors.continueHint)
        love.graphics.setFont(getFont(12))
        local hintText = "[SPACE / ENTER to continue    |    ESC to skip]"
        local hintW = love.graphics.getFont():getWidth(hintText)
        love.graphics.print(hintText, boxX + boxW - hintW - 20, boxY + boxH - 25)
    end

    -- Line counter
    love.graphics.setColor(colors.continueHint)
    love.graphics.setFont(getFont(11))
    local counter = cutsceneState.currentLine .. " / " .. #scene.lines
    love.graphics.print(counter, boxX + 20, boxY + boxH - 25)
end

-- ============================================================================
--                      INPUT HANDLING
-- ============================================================================

function Cutscenes.keypressed(key)
    if not cutsceneState.active then return false end

    if key == "space" or key == "return" then
        Cutscenes.advance()
        return true
    elseif key == "escape" then
        Cutscenes.skip()
        return true
    end

    return true  -- Consume all input during cutscenes
end

function Cutscenes.mousepressed(x, y, button)
    if not cutsceneState.active then return false end
    if button == 1 then
        Cutscenes.advance()
        return true
    end
    return true
end

-- Get the current line's effect (for game logic to respond to)
function Cutscenes.getCurrentEffect()
    if not cutsceneState.active or not cutsceneState.currentCutscene then return nil end
    local line = cutsceneState.currentCutscene.lines[cutsceneState.currentLine]
    if line then return line.effect end
    return nil
end

return Cutscenes

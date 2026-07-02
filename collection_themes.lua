-- collection_themes.lua
-- Themes and Portraits tabs for the collection screen

local UI = require("ui")
local shared = require("collection_shared")

local Themes = {}

-- Themes data
local THEMES = {
    {id = "default", name = "Classic", desc = "The original love cards look", color = {0.3, 0.5, 0.7}, unlocked = true},
    {id = "neon", name = "Neon Nights", desc = "Cyberpunk casino vibes", color = {0.9, 0.2, 0.9}, unlocked = false, comingSoon = true},
    {id = "royal", name = "Royal Palace", desc = "Elegant gold and velvet", color = {0.9, 0.7, 0.2}, unlocked = false, comingSoon = true},
    {id = "ocean", name = "Deep Ocean", desc = "Underwater card adventure", color = {0.2, 0.5, 0.9}, unlocked = false, comingSoon = true},
    {id = "forest", name = "Enchanted Forest", desc = "Mystical woodland theme", color = {0.3, 0.7, 0.3}, unlocked = false, comingSoon = true},
    {id = "space", name = "Cosmic Void", desc = "Cards among the stars", color = {0.1, 0.1, 0.3}, unlocked = false, comingSoon = true},
    {id = "fire", name = "Inferno", desc = "Blazing hot poker nights", color = {0.9, 0.3, 0.1}, unlocked = false, comingSoon = true},
    {id = "ice", name = "Frozen Tundra", desc = "Cool blue winter theme", color = {0.5, 0.8, 1}, unlocked = false, comingSoon = true},
}

local CHARACTERS = {
    {id = "dealer", name = "The Dealer", desc = "Classic casino dealer", unlocked = true},
    {id = "witch", name = "Card Witch", desc = "Mystical fortune teller", comingSoon = true},
    {id = "robot", name = "Croupier Bot", desc = "Automated dealer 3000", comingSoon = true},
    {id = "pirate", name = "Captain Cards", desc = "Swashbuckling card shark", comingSoon = true},
    {id = "knight", name = "Sir Deckard", desc = "Noble card champion", comingSoon = true},
}

local MUSIC_THEMES = {
    {id = "default", name = "Ambient", desc = "Relaxing background music", unlocked = true},
    {id = "jazz", name = "Jazz Lounge", desc = "Smooth casino jazz", comingSoon = true},
    {id = "electronic", name = "Synth Wave", desc = "Retro electronic beats", comingSoon = true},
    {id = "orchestral", name = "Grand Orchestra", desc = "Epic classical music", comingSoon = true},
}

-- Portraits data
local PORTRAITS = {
    {id = "default", name = "Default Avatar", desc = "Simple card player portrait", unlocked = true},
    {id = "king", name = "The King", desc = "Royal card master portrait", comingSoon = true},
    {id = "queen", name = "The Queen", desc = "Elegant card ruler portrait", comingSoon = true},
    {id = "joker", name = "Wild Joker", desc = "Chaotic trickster portrait", comingSoon = true},
    {id = "ace", name = "Ace of Spades", desc = "Mysterious card player", comingSoon = true},
    {id = "dealer", name = "Casino Dealer", desc = "Professional card handler", comingSoon = true},
    {id = "gambler", name = "High Roller", desc = "Confident big bettor", comingSoon = true},
    {id = "mystic", name = "Card Mystic", desc = "Fortune telling master", comingSoon = true},
    {id = "robot", name = "Card-Bot 3000", desc = "AI card champion", comingSoon = true},
    {id = "pirate", name = "Card Pirate", desc = "Treasure hunting gambler", comingSoon = true},
    {id = "knight", name = "Card Knight", desc = "Noble deck defender", comingSoon = true},
    {id = "dragon", name = "Dragon Lord", desc = "Fearsome card master", comingSoon = true},
}

-- Expose data for wheelmoved calculations
Themes.THEMES = THEMES
Themes.PORTRAITS = PORTRAITS

-- Draw themes tab
function Themes.drawThemesTab()
    local layout = shared.layout
    local scrollOffset = shared.scrollOffset

    love.graphics.setScissor(layout.areaX, layout.areaY, layout.areaWidth, layout.areaHeight)

    local mx, my = love.mouse.getPosition()

    -- Card dimensions
    local cardW, cardH = 180, 100
    local startX = layout.areaX + 20
    local baseY = layout.areaY + 15

    -- Title - Visual Themes
    local titleY = baseY - scrollOffset
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(UI.fonts.get(20))
    love.graphics.print("Visual Themes", layout.areaX + 20, titleY)

    -- Theme cards
    local startY = baseY + 35 - scrollOffset
    local col = 0

    for i, theme in ipairs(THEMES) do
        local x = startX + col * (cardW + 15)
        local y = startY + math.floor((i-1) / 5) * (cardH + 15)

        if y + cardH > layout.areaY and y < layout.areaY + layout.areaHeight then
            local hovered = mx >= x and mx <= x + cardW and my >= y and my <= y + cardH and
                           my >= layout.areaY and my <= layout.areaY + layout.areaHeight

            love.graphics.setColor(theme.color[1] * 0.3, theme.color[2] * 0.3, theme.color[3] * 0.3, 0.9)
            love.graphics.rectangle("fill", x, y, cardW, cardH, 8, 8)

            love.graphics.setColor(hovered and {1, 1, 1} or theme.color)
            love.graphics.setLineWidth(theme.unlocked and 2 or 1)
            love.graphics.rectangle("line", x, y, cardW, cardH, 8, 8)
            love.graphics.setLineWidth(1)

            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(UI.fonts.get(14))
            love.graphics.print(theme.name, x + 10, y + 10)

            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.setFont(UI.fonts.get(11))
            love.graphics.print(theme.desc, x + 10, y + 30)

            if theme.comingSoon then
                love.graphics.setColor(0.9, 0.6, 0.2)
                love.graphics.setFont(UI.fonts.get(12))
                love.graphics.print("COMING SOON", x + 10, y + cardH - 25)
            elseif theme.unlocked then
                love.graphics.setColor(0.3, 0.9, 0.3)
                love.graphics.print("UNLOCKED", x + 10, y + cardH - 25)
            end
        end

        col = col + 1
        if col >= 5 then col = 0 end
    end

    -- Characters section
    local charY = startY + math.ceil(#THEMES / 5) * (cardH + 15) + 20
    if charY + 30 > layout.areaY and charY < layout.areaY + layout.areaHeight then
        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.setFont(UI.fonts.get(18))
        love.graphics.print("Characters", layout.areaX + 20, charY)
    end

    charY = charY + 30
    col = 0
    for i, char in ipairs(CHARACTERS) do
        local x = startX + col * (cardW + 15)
        local y = charY

        if y + 70 > layout.areaY and y < layout.areaY + layout.areaHeight then
            love.graphics.setColor(0.15, 0.15, 0.2, 0.9)
            love.graphics.rectangle("fill", x, y, cardW, 70, 8, 8)
            love.graphics.setColor(char.comingSoon and {0.5, 0.5, 0.6} or {0.5, 0.8, 0.5})
            love.graphics.rectangle("line", x, y, cardW, 70, 8, 8)

            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(UI.fonts.get(14))
            love.graphics.print(char.name, x + 10, y + 10)
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.setFont(UI.fonts.get(10))
            love.graphics.print(char.desc, x + 10, y + 28)

            if char.comingSoon then
                love.graphics.setColor(0.9, 0.6, 0.2)
                love.graphics.setFont(UI.fonts.get(10))
                love.graphics.print("COMING SOON", x + 10, y + 50)
            end
        end

        col = col + 1
        if col >= 5 then col = 0 end
    end

    -- Music themes section
    local musicY = charY + 100
    if musicY + 30 > layout.areaY and musicY < layout.areaY + layout.areaHeight then
        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.setFont(UI.fonts.get(18))
        love.graphics.print("Music Themes", layout.areaX + 20, musicY)
    end

    musicY = musicY + 30
    col = 0
    for i, music in ipairs(MUSIC_THEMES) do
        local x = startX + col * (cardW + 15)
        local y = musicY

        if y + 60 > layout.areaY and y < layout.areaY + layout.areaHeight then
            love.graphics.setColor(0.12, 0.15, 0.2, 0.9)
            love.graphics.rectangle("fill", x, y, cardW, 60, 8, 8)
            love.graphics.setColor(music.comingSoon and {0.5, 0.5, 0.6} or {0.5, 0.7, 0.9})
            love.graphics.rectangle("line", x, y, cardW, 60, 8, 8)

            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(UI.fonts.get(14))
            love.graphics.print(music.name, x + 10, y + 8)
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.setFont(UI.fonts.get(10))
            love.graphics.print(music.desc, x + 10, y + 26)

            if music.comingSoon then
                love.graphics.setColor(0.9, 0.6, 0.2)
                love.graphics.setFont(UI.fonts.get(10))
                love.graphics.print("COMING SOON", x + 10, y + 42)
            end
        end

        col = col + 1
        if col >= 5 then col = 0 end
    end

    love.graphics.setScissor()

    -- Calculate total content height and show scroll hint + scrollbar
    local totalContentHeight = 35 + math.ceil(#THEMES / 5) * (cardH + 15) + 20 + 30 + 70 + 100 + 30 + 60 + 20
    local maxScroll = math.max(0, totalContentHeight - layout.areaHeight + 40)
    if totalContentHeight > layout.areaHeight then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(UI.fonts.get(11))
        love.graphics.print("Scroll to see more", layout.areaX + layout.areaWidth - 130, layout.areaY + layout.areaHeight + 5)
        local scrollbarX = layout.areaX + layout.areaWidth - 8
        local scrollbarH = layout.areaHeight
        local thumbH = math.max(30, scrollbarH * (layout.areaHeight / totalContentHeight))
        local thumbY = layout.areaY + (scrollOffset / math.max(1, maxScroll)) * (scrollbarH - thumbH)
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", scrollbarX, layout.areaY, 6, scrollbarH, 3, 3)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("fill", scrollbarX, thumbY, 6, thumbH, 3, 3)
    end
end

-- Draw portraits tab
function Themes.drawPortraitsTab()
    local layout = shared.layout
    local scrollOffset = shared.scrollOffset

    love.graphics.setScissor(layout.areaX, layout.areaY, layout.areaWidth, layout.areaHeight)

    local mx, my = love.mouse.getPosition()

    -- Title
    local titleY = layout.areaY + 15 - scrollOffset
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(UI.fonts.get(20))
    love.graphics.print("Player Portraits", layout.areaX + 20, titleY)

    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("Customize your player avatar for multiplayer and leaderboards", layout.areaX + 20, titleY + 25)

    -- Portrait cards
    local cardW, cardH = 140, 180
    local startX = layout.areaX + 20
    local startY = layout.areaY + 70 - scrollOffset
    local col = 0

    for i, portrait in ipairs(PORTRAITS) do
        local x = startX + col * (cardW + 15)
        local y = startY + math.floor((i-1) / 7) * (cardH + 15)

        if y + cardH > layout.areaY and y < layout.areaY + layout.areaHeight then
            local hovered = mx >= x and mx <= x + cardW and my >= y and my <= y + cardH and
                           my >= layout.areaY and my <= layout.areaY + layout.areaHeight

            love.graphics.setColor(0.12, 0.12, 0.18, 0.95)
            love.graphics.rectangle("fill", x, y, cardW, cardH, 10, 10)

            love.graphics.setColor(hovered and {0.9, 0.8, 0.3} or (portrait.unlocked and {0.3, 0.7, 0.4} or {0.4, 0.4, 0.5}))
            love.graphics.setLineWidth(hovered and 2 or 1)
            love.graphics.rectangle("line", x, y, cardW, cardH, 10, 10)
            love.graphics.setLineWidth(1)

            love.graphics.setColor(0.2, 0.2, 0.25)
            love.graphics.rectangle("fill", x + 20, y + 15, cardW - 40, cardW - 40, 8, 8)

            love.graphics.setColor(0.5, 0.5, 0.6)
            love.graphics.setFont(UI.fonts.get(40))
            love.graphics.printf("?", x + 20, y + 40, cardW - 40, "center")

            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.printf(portrait.name, x + 5, y + cardW - 25, cardW - 10, "center")

            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.setFont(UI.fonts.get(9))
            love.graphics.printf(portrait.desc, x + 5, y + cardW - 5, cardW - 10, "center")

            if portrait.comingSoon then
                love.graphics.setColor(0.9, 0.5, 0.1, 0.9)
                love.graphics.rectangle("fill", x + cardW - 75, y + 5, 70, 18, 4, 4)
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(UI.fonts.get(10))
                love.graphics.print("COMING SOON", x + cardW - 73, y + 7)
            elseif portrait.unlocked then
                love.graphics.setColor(0.2, 0.7, 0.3, 0.9)
                love.graphics.rectangle("fill", x + cardW - 60, y + 5, 55, 18, 4, 4)
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(UI.fonts.get(10))
                love.graphics.print("EQUIPPED", x + cardW - 55, y + 7)
            end
        end

        col = col + 1
        if col >= 7 then col = 0 end
    end

    love.graphics.setScissor()

    -- Show scroll hint if content exceeds area
    local rows = math.ceil(#PORTRAITS / 7)
    local contentHeight = 70 + rows * (cardH + 15)
    local maxScroll = math.max(0, contentHeight - layout.areaHeight + 40)
    if contentHeight > layout.areaHeight then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(UI.fonts.get(11))
        love.graphics.print("Scroll to see more", layout.areaX + layout.areaWidth - 130, layout.areaY + layout.areaHeight + 5)
        local scrollbarX = layout.areaX + layout.areaWidth - 8
        local scrollbarH = layout.areaHeight
        local thumbH = math.max(30, scrollbarH * (layout.areaHeight / contentHeight))
        local thumbY = layout.areaY + (scrollOffset / math.max(1, maxScroll)) * (scrollbarH - thumbH)
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", scrollbarX, layout.areaY, 6, scrollbarH, 3, 3)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("fill", scrollbarX, thumbY, 6, thumbH, 3, 3)
    end
end

return Themes

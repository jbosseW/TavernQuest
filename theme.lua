-- Shared UI Theme - Centralized color definitions
-- Used by menu.lua, options.lua, and other UI modules

local Theme = {}

Theme.colors = {
    -- Backgrounds
    bg = {0.1, 0.1, 0.15},
    bgOverlay = {0.1, 0.1, 0.15, 0.95},
    panel = {0.15, 0.15, 0.2},

    -- Buttons
    button = {0.2, 0.3, 0.5},
    buttonHover = {0.3, 0.4, 0.6},
    buttonActive = {0.4, 0.5, 0.7},
    buttonLocked = {0.25, 0.25, 0.28},
    buttonDanger = {0.6, 0.2, 0.2},
    buttonDangerHover = {0.8, 0.3, 0.3},

    -- Text
    text = {1, 1, 1},
    textDim = {0.6, 0.6, 0.6},
    subtitle = {0.7, 0.7, 0.7},

    -- Semantic
    accent = {0.9, 0.6, 0.2},
    success = {0.3, 0.8, 0.3},
    warning = {0.9, 0.7, 0.2},
}

return Theme

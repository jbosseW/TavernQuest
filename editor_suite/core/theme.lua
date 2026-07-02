local Theme = {}

Theme.colors = {
    bg = {0.08, 0.10, 0.14},
    bgLight = {0.12, 0.14, 0.20},
    bgDark = {0.05, 0.06, 0.09},
    panel = {0.10, 0.12, 0.18},
    panelBorder = {0.25, 0.30, 0.40},
    panelHeader = {0.14, 0.16, 0.22},

    primary = {0.90, 0.65, 0.20},
    primaryHover = {1.0, 0.75, 0.30},
    primaryDark = {0.70, 0.50, 0.15},
    secondary = {0.30, 0.50, 0.80},
    secondaryHover = {0.40, 0.60, 0.90},

    success = {0.30, 0.80, 0.40},
    warning = {0.90, 0.70, 0.20},
    danger = {0.80, 0.25, 0.25},
    dangerHover = {0.90, 0.35, 0.35},
    info = {0.40, 0.70, 0.90},

    text = {0.92, 0.92, 0.92},
    textDim = {0.55, 0.55, 0.60},
    textAccent = {1.0, 0.85, 0.30},
    textDark = {0.35, 0.35, 0.40},

    input = {0.14, 0.16, 0.22},
    inputBorder = {0.30, 0.35, 0.45},
    inputFocus = {0.90, 0.65, 0.20},

    scrollbar = {0.20, 0.22, 0.28},
    scrollbarThumb = {0.40, 0.42, 0.50},
    scrollbarThumbHover = {0.50, 0.52, 0.60},

    tabActive = {0.90, 0.65, 0.20},
    tabInactive = {0.20, 0.22, 0.28},
    tabHover = {0.25, 0.28, 0.35},
    tabText = {0.92, 0.92, 0.92},
    tabTextInactive = {0.55, 0.55, 0.60},

    listItem = {0.10, 0.12, 0.18},
    listItemHover = {0.15, 0.18, 0.25},
    listItemSelected = {0.20, 0.25, 0.35},
    listItemAlt = {0.11, 0.13, 0.19},

    overlay = {0, 0, 0, 0.75},
    shadow = {0, 0, 0, 0.50},

    statusBar = {0.06, 0.07, 0.10},
    statusText = {0.55, 0.55, 0.60},
}

Theme.spacing = {
    xs = 2,
    sm = 4,
    md = 8,
    lg = 12,
    xl = 16,
    xxl = 24,
    xxxl = 32,
}

Theme.radius = {
    sm = 3,
    md = 6,
    lg = 10,
    pill = 999,
}

Theme.border = {
    thin = 1,
    normal = 2,
    thick = 3,
}

Theme.sizes = {
    tabBarHeight = 36,
    statusBarHeight = 24,
    toolbarHeight = 32,
    sidebarWidth = 260,
    propertyLabelWidth = 140,
    buttonHeight = 28,
    inputHeight = 26,
    listItemHeight = 28,
    scrollbarWidth = 10,
    iconSmall = 16,
    iconMedium = 32,
    iconLarge = 64,
    iconPreview = 128,
}

function Theme.setColor(colorKey)
    local c = Theme.colors[colorKey]
    if c then
        love.graphics.setColor(c)
    end
end

function Theme.withAlpha(colorKey, alpha)
    local c = Theme.colors[colorKey]
    if c then
        return {c[1], c[2], c[3], alpha}
    end
    return {1, 1, 1, alpha}
end

function Theme.lerp(colorA, colorB, t)
    return {
        colorA[1] + (colorB[1] - colorA[1]) * t,
        colorA[2] + (colorB[2] - colorA[2]) * t,
        colorA[3] + (colorB[3] - colorA[3]) * t,
        (colorA[4] or 1) + ((colorB[4] or 1) - (colorA[4] or 1)) * t,
    }
end

return Theme

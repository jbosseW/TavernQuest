-- collection_effects.lua
-- Visual effects system for collection: particles, screen effects, holographic/foil/prismatic card effects

local Cards = require("cards")

local Effects = {}

-- Animation time tracker
local effectTime = 0

-- Particle pool
local particles = {}

-- Screen effects
local screenEffects = {
    flash = {active = false, color = {1, 1, 1}, alpha = 0, duration = 0},
    shake = {active = false, intensity = 0, duration = 0, offsetX = 0, offsetY = 0},
}

-- Fusion notifications
local fusionNotifications = {}

function Effects.getEffectTime()
    return effectTime
end

-- ============================================
-- FUSION NOTIFICATIONS
-- ============================================

function Effects.addFusionNotification(text, color)
    table.insert(fusionNotifications, {
        text = text,
        color = color or {1, 1, 1},
        timer = 3.5,
        alpha = 1,
        y = 0
    })
end

function Effects.updateFusionNotifications(dt)
    for i = #fusionNotifications, 1, -1 do
        local notif = fusionNotifications[i]
        notif.timer = notif.timer - dt
        notif.y = notif.y + dt * 30
        if notif.timer < 1 then
            notif.alpha = notif.timer
        end
        if notif.timer <= 0 then
            table.remove(fusionNotifications, i)
        end
    end
end

function Effects.getFusionNotifications()
    return fusionNotifications
end

-- ============================================
-- HSL TO RGB
-- ============================================

function Effects.hslToRgb(h, s, l)
    local r, g, b
    if s == 0 then
        r, g, b = l, l, l
    else
        local function hue2rgb(p, q, t)
            if t < 0 then t = t + 1 end
            if t > 1 then t = t - 1 end
            if t < 1/6 then return p + (q - p) * 6 * t end
            if t < 1/2 then return q end
            if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
            return p
        end
        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q
        r = hue2rgb(p, q, h + 1/3)
        g = hue2rgb(p, q, h)
        b = hue2rgb(p, q, h - 1/3)
    end
    return {r, g, b}
end

-- ============================================
-- PARTICLE SYSTEM
-- ============================================

function Effects.spawnFusionParticles(effectType, x, y)
    local configs = {
        splinter = {
            count = 25, color = {1, 0.6, 0.2}, color2 = {1, 0.3, 0},
            speed = 200, spread = math.pi * 2, size = 6, lifetime = 1.2,
            shape = "shard", gravity = 100
        },
        mirror = {
            count = 30, color = {0.8, 0.8, 0.95}, color2 = {0.6, 0.6, 0.8},
            speed = 150, spread = math.pi * 2, size = 8, lifetime = 1.5,
            shape = "diamond", gravity = -20
        },
        catalyst = {
            count = 40, color = {1, 0.9, 0.3}, color2 = {1, 0.6, 0},
            speed = 250, spread = math.pi * 2, size = 5, lifetime = 1.0,
            shape = "spark", gravity = 50
        },
        prismatic = {
            count = 35, color = {1, 0.5, 1}, color2 = {0.5, 0.5, 1},
            speed = 180, spread = math.pi * 2, size = 7, lifetime = 1.3,
            shape = "circle", gravity = 0, rainbow = true
        },
        echo = {
            count = 20, color = {0.3, 0.6, 1}, color2 = {0.1, 0.3, 0.8},
            speed = 120, spread = math.pi * 2, size = 10, lifetime = 1.4,
            shape = "ring", gravity = -30
        },
        fortify = {
            count = 30, color = {0.3, 1, 0.4}, color2 = {0.1, 0.6, 0.2},
            speed = 160, spread = math.pi * 2, size = 6, lifetime = 1.1,
            shape = "square", gravity = 80
        },
        jackpot = {
            count = 80, color = {1, 0.8, 0.2}, color2 = {1, 0.4, 0.8},
            speed = 300, spread = math.pi * 2, size = 8, lifetime = 2.0,
            shape = "star", gravity = 0, rainbow = true
        },
        fusion = {
            count = 50, color = {0.8, 0.5, 1}, color2 = {0.4, 0.2, 0.8},
            speed = 200, spread = math.pi * 2, size = 5, lifetime = 1.0,
            shape = "circle", gravity = 60
        }
    }

    local config = configs[effectType] or configs.fusion

    for i = 1, config.count do
        local angle = math.random() * config.spread - config.spread / 2
        local speed = config.speed * (0.5 + math.random() * 0.5)
        local baseColor = math.random() < 0.5 and config.color or config.color2

        table.insert(particles, {
            x = x + math.random(-20, 20),
            y = y + math.random(-20, 20),
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            color = {baseColor[1], baseColor[2], baseColor[3]},
            size = config.size * (0.5 + math.random() * 0.5),
            lifetime = config.lifetime,
            maxLifetime = config.lifetime,
            shape = config.shape,
            gravity = config.gravity,
            rainbow = config.rainbow,
            rotation = math.random() * math.pi * 2,
            rotationSpeed = (math.random() - 0.5) * 10
        })
    end
end

-- ============================================
-- SCREEN EFFECTS
-- ============================================

function Effects.triggerScreenFlash(color, duration)
    screenEffects.flash = {
        active = true,
        color = color or {1, 1, 1},
        alpha = 0.8,
        duration = duration or 0.3,
        maxDuration = duration or 0.3
    }
end

function Effects.triggerScreenShake(intensity, duration)
    screenEffects.shake = {
        active = true,
        intensity = intensity or 5,
        duration = duration or 0.3,
        offsetX = 0,
        offsetY = 0
    }
end

function Effects.triggerFusionEffect(effectName, x, y)
    local effectColors = {
        splinter = {1, 0.6, 0.2},
        mirror = {0.8, 0.8, 0.95},
        catalyst = {1, 0.9, 0.3},
        prismatic = {0.9, 0.5, 1},
        echo = {0.3, 0.6, 1},
        fortify = {0.3, 1, 0.4},
        jackpot = {1, 0.8, 0.2},
    }

    local color = effectColors[effectName] or {1, 1, 1}

    Effects.spawnFusionParticles(effectName, x, y)

    if effectName == "jackpot" then
        Effects.triggerScreenFlash({1, 0.9, 0.4}, 0.5)
        Effects.triggerScreenShake(10, 0.4)
    else
        Effects.triggerScreenFlash(color, 0.2)
        Effects.triggerScreenShake(3, 0.15)
    end
end

-- ============================================
-- UPDATE
-- ============================================

function Effects.updateVisualEffects(dt)
    effectTime = effectTime + dt

    -- Update particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.lifetime = p.lifetime - dt

        if p.lifetime <= 0 then
            table.remove(particles, i)
        else
            p.vy = p.vy + (p.gravity or 0) * dt
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.rotation = p.rotation + p.rotationSpeed * dt

            if p.rainbow then
                local hue = (effectTime * 2 + i * 0.1) % 1
                p.color = Effects.hslToRgb(hue, 0.8, 0.6)
            end
        end
    end

    -- Update screen flash
    if screenEffects.flash.active then
        screenEffects.flash.duration = screenEffects.flash.duration - dt
        screenEffects.flash.alpha = screenEffects.flash.duration / screenEffects.flash.maxDuration * 0.8
        if screenEffects.flash.duration <= 0 then
            screenEffects.flash.active = false
        end
    end

    -- Update screen shake
    if screenEffects.shake.active then
        screenEffects.shake.duration = screenEffects.shake.duration - dt
        local intensity = screenEffects.shake.intensity * (screenEffects.shake.duration / 0.3)
        screenEffects.shake.offsetX = (math.random() - 0.5) * intensity * 2
        screenEffects.shake.offsetY = (math.random() - 0.5) * intensity * 2
        if screenEffects.shake.duration <= 0 then
            screenEffects.shake.active = false
            screenEffects.shake.offsetX = 0
            screenEffects.shake.offsetY = 0
        end
    end
end

-- ============================================
-- DRAW
-- ============================================

function Effects.drawParticles()
    for _, p in ipairs(particles) do
        local alpha = p.lifetime / p.maxLifetime
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)

        love.graphics.push()
        love.graphics.translate(p.x, p.y)
        love.graphics.rotate(p.rotation)

        if p.shape == "circle" then
            love.graphics.circle("fill", 0, 0, p.size)
        elseif p.shape == "square" then
            love.graphics.rectangle("fill", -p.size/2, -p.size/2, p.size, p.size)
        elseif p.shape == "diamond" then
            love.graphics.polygon("fill", 0, -p.size, p.size, 0, 0, p.size, -p.size, 0)
        elseif p.shape == "shard" then
            love.graphics.polygon("fill", 0, -p.size*1.5, p.size*0.4, 0, 0, p.size*0.5, -p.size*0.4, 0)
        elseif p.shape == "spark" then
            love.graphics.setLineWidth(2)
            love.graphics.line(0, -p.size, 0, p.size)
            love.graphics.line(-p.size*0.5, 0, p.size*0.5, 0)
        elseif p.shape == "ring" then
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", 0, 0, p.size)
        elseif p.shape == "star" then
            local points = {}
            for i = 0, 4 do
                local angle = (i / 5) * math.pi * 2 - math.pi / 2
                table.insert(points, math.cos(angle) * p.size)
                table.insert(points, math.sin(angle) * p.size)
                angle = angle + math.pi / 5
                table.insert(points, math.cos(angle) * p.size * 0.4)
                table.insert(points, math.sin(angle) * p.size * 0.4)
            end
            love.graphics.polygon("fill", points)
        end

        love.graphics.pop()
    end
    love.graphics.setLineWidth(1)
end

function Effects.drawScreenEffects(screenW, screenH)
    if screenEffects.flash.active then
        love.graphics.setColor(
            screenEffects.flash.color[1],
            screenEffects.flash.color[2],
            screenEffects.flash.color[3],
            screenEffects.flash.alpha
        )
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    end
end

-- ============================================
-- HOLOGRAPHIC / PARALLAX CARD EFFECTS
-- ============================================

function Effects.drawHolographicEffect(x, y, w, h, intensity)
    intensity = intensity or 1
    local mx, my = love.mouse.getPosition()

    local cardCenterX = x + w / 2
    local cardCenterY = y + h / 2
    local dx = (mx - cardCenterX) / 200
    local dy = (my - cardCenterY) / 200

    local hue1 = (effectTime * 0.3 + dx * 0.5) % 1
    local hue2 = (hue1 + 0.3) % 1
    local hue3 = (hue1 + 0.6) % 1

    local color1 = Effects.hslToRgb(hue1, 0.7, 0.6)
    local color2 = Effects.hslToRgb(hue2, 0.7, 0.6)
    local color3 = Effects.hslToRgb(hue3, 0.7, 0.6)

    for layer = 1, 3 do
        local layerOffset = layer * 0.5
        local offsetX = dx * layerOffset * 15
        local offsetY = dy * layerOffset * 15
        local alpha = 0.15 * intensity / layer

        local bandWidth = w * 0.4
        local bandX = x + (effectTime * 100 + offsetX * 10) % (w + bandWidth * 2) - bandWidth

        love.graphics.setColor(color1[1], color1[2], color1[3], alpha)
        love.graphics.polygon("fill",
            bandX + offsetX, y,
            bandX + bandWidth + offsetX, y,
            bandX + bandWidth * 0.7 + offsetX, y + h,
            bandX - bandWidth * 0.3 + offsetX, y + h
        )
    end

    local edgeAlpha = 0.3 * intensity
    love.graphics.setColor(1, 1, 1, edgeAlpha * math.abs(dx))
    love.graphics.setLineWidth(2)
    if dx > 0 then
        love.graphics.line(x + w, y, x + w, y + h)
    else
        love.graphics.line(x, y, x, y + h)
    end
    if dy > 0 then
        love.graphics.line(x, y + h, x + w, y + h)
    else
        love.graphics.line(x, y, x + w, y)
    end
    love.graphics.setLineWidth(1)
end

function Effects.drawFoilEffect(x, y, w, h)
    local mx, my = love.mouse.getPosition()
    local cardCenterX = x + w / 2
    local cardCenterY = y + h / 2
    local dx = (mx - cardCenterX) / 300
    local dy = (my - cardCenterY) / 300

    local shimmerX = x + w * (0.5 + dx * 0.3)
    local shimmerY = y + h * (0.5 + dy * 0.3)

    for i = 1, 3 do
        local radius = (w + h) * 0.3 * i
        local alpha = 0.2 / i
        love.graphics.setColor(0.9, 0.95, 1, alpha)
        love.graphics.circle("fill", shimmerX, shimmerY, radius * 0.3)
    end

    local scanY = y + ((effectTime * 50) % (h + 20)) - 10
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.rectangle("fill", x, scanY, w, 3)
end

function Effects.drawPrismaticEffect(x, y, w, h)
    local stripeCount = 6
    local stripeHeight = h / stripeCount

    for i = 0, stripeCount - 1 do
        local hue = ((i / stripeCount) + effectTime * 0.2) % 1
        local color = Effects.hslToRgb(hue, 0.6, 0.5)
        love.graphics.setColor(color[1], color[2], color[3], 0.15)
        love.graphics.rectangle("fill", x, y + i * stripeHeight, w, stripeHeight)
    end
end

function Effects.drawParallaxCard(card, x, y, w, h)
    local mx, my = love.mouse.getPosition()
    local cardCenterX = x + w / 2
    local cardCenterY = y + h / 2

    local maxTilt = 8
    local dx = math.max(-1, math.min(1, (mx - cardCenterX) / 200))
    local dy = math.max(-1, math.min(1, (my - cardCenterY) / 200))

    local fusionCount = card.fusionCount or 0
    if fusionCount == 0 then return end

    local layers = fusionCount + 1

    for layer = layers, 1, -1 do
        local offsetX = dx * (layer - 1) * 3
        local offsetY = dy * (layer - 1) * 3
        local layerAlpha = layer == 1 and 1 or 0.3

        if layer > 1 then
            love.graphics.setColor(0, 0, 0, 0.2)
            love.graphics.rectangle("fill", x + offsetX + 2, y + offsetY + 2, w, h, 6, 6)
        end

        local rarity = Cards.rarities[card.rarity] or Cards.rarities.common
        love.graphics.setColor(rarity.color[1], rarity.color[2], rarity.color[3], layerAlpha * 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + offsetX, y + offsetY, w, h, 6, 6)
    end
    love.graphics.setLineWidth(1)
end

return Effects

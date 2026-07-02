-- RPG NPC Management, Events, Wandering, Relationships, and Quest System
-- Extracted from textrpg.lua

local Data = require("rpg_data")

local M = {}

-- Upvalues set by register()
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
-- DATA TABLES (local to this module, copied from textrpg.lua)
-- ============================================================================

-- Calendar helpers from rpg_data
local MONTHS = Data.MONTHS
local DAYS_PER_YEAR = Data.DAYS_PER_YEAR

local function getCalendarDate(daysPassed)
    local totalDays = daysPassed
    local year = 1
    while totalDays >= DAYS_PER_YEAR do
        totalDays = totalDays - DAYS_PER_YEAR
        year = year + 1
    end
    local month = 1
    for i = 1, 12 do
        if totalDays < MONTHS[i].days then
            month = i
            break
        end
        totalDays = totalDays - MONTHS[i].days
    end
    return {
        year = year,
        month = month,
        day = totalDays + 1,
        monthName = MONTHS[month].name,
    }
end

-- Helper to access getTownBuildingById from either F or bare local
local function getTownBuildingById(buildingId)
    if F and F.getTownBuildingById then
        return F.getTownBuildingById(buildingId)
    end
    return nil
end

-- NPC Templates
local NPC_TEMPLATES = {
    shopkeeper = {
        profession = "shopkeeper",
        names = {"Harold", "Margaret", "Thomas", "Eleanor", "William", "Catherine"},
        sprite = "🧑‍💼",
        dialogue = {
            greeting = "Welcome to my shop! How can I help you?",
            options = {
                {text = "Browse wares", action = "shop"},
                {text = "Chat", action = "chat", responses = {
                    "Business has been good lately.",
                    "I get my supplies from traveling merchants.",
                    "Let me know if you need anything!",
                }},
            }
        }
    },
    blacksmith = {
        profession = "blacksmith",
        names = {"Gareth", "Brunhilda", "Thorgrim", "Astrid", "Marcus"},
        sprite = "🔨",
        dialogue = {
            greeting = "Welcome to the forge. Need some work done?",
            options = {
                {text = "Work at forge", action = "forge"},
                {text = "Chat", action = "chat", responses = {
                    "The fire must stay hot to work the metal.",
                    "I learned this trade from my father.",
                    "A good blade can save your life.",
                }},
            }
        }
    },
    priest = {
        profession = "priest",
        names = {"Father Benedict", "Sister Miriam", "Father Aldric", "Sister Elara"},
        sprite = "⛪",
        dialogue = {
            greeting = "May the light guide you, child.",
            options = {
                {text = "Request blessing", action = "blessing"},
                {text = "Pray", action = "chat", responses = {
                    "The divine watches over us all.",
                    "Faith is the shield against darkness.",
                    "I pray for the safety of this town.",
                }},
            }
        }
    },
    tavernkeep = {
        profession = "tavernkeep",
        names = {"Barley", "Rosie", "Finn", "Mabel", "Duncan"},
        sprite = "🍺",
        dialogue = {
            greeting = "Welcome, friend! Pull up a chair!",
            options = {
                {text = "Chat", action = "chat", responses = {
                    "I hear all the best gossip in here.",
                    "Fresh ale every day!",
                    "Travelers come through with interesting stories.",
                }},
            }
        }
    },
    stablemaster = {
        profession = "stablemaster",
        names = {"Roland", "Beatrice", "Garrett", "Hilda"},
        sprite = "🐴",
        dialogue = {
            greeting = "Looking for a mount or transport?",
            options = {
                {text = "View mounts", action = "stable"},
                {text = "Chat", action = "chat", responses = {
                    "I raise the finest horses in the region.",
                    "A good mount can make all the difference.",
                    "These animals are well cared for.",
                }},
            }
        }
    },
    alchemist = {
        profession = "alchemist",
        names = {"Paracelsus", "Morgana", "Albertus", "Rowena"},
        sprite = "⚗️",
        dialogue = {
            greeting = "Ah, interested in the alchemical arts?",
            options = {
                {text = "Work at lab", action = "alchemist"},
                {text = "Chat", action = "chat", responses = {
                    "The transmutation of base metals... fascinating.",
                    "Each reagent has unique properties.",
                    "Precision is key in this craft.",
                }},
            }
        }
    },
    wizard = {
        profession = "wizard",
        names = {"Merlin", "Morgause", "Gandor", "Thessaly", "Aramis"},
        sprite = "🧙",
        dialogue = {
            greeting = "Welcome to my tower. Seek arcane knowledge?",
            options = {
                {text = "Work on spells", action = "wizardtower"},
                {text = "Chat", action = "chat", responses = {
                    "Magic flows through all things.",
                    "The ancient texts hold great secrets.",
                    "Be careful what powers you invoke.",
                }},
            }
        }
    },
    fisher = {
        profession = "fisher",
        names = {"Jonah", "Marina", "Fisher", "Pearl"},
        sprite = "🎣",
        dialogue = {
            greeting = "The fish are biting today!",
            options = {
                {text = "Go fishing", action = "fishing"},
                {text = "Chat", action = "chat", responses = {
                    "Patience is the fisherman's virtue.",
                    "The river provides for those who wait.",
                    "Best spot is just past the old pier.",
                }},
            }
        }
    },
    hunter = {
        profession = "hunter",
        names = {"Ranger", "Diana", "Orion", "Artemis"},
        sprite = "🏹",
        dialogue = {
            greeting = "Hunter's lodge - best game in the land!",
            options = {
                {text = "Go hunting", action = "hunting"},
                {text = "Chat", action = "chat", responses = {
                    "Track your prey, move silently.",
                    "The forest is full of game.",
                    "I've hunted these woods for years.",
                }},
            }
        }
    },
    merchant = {
        profession = "merchant",
        names = {"Cosimo", "Venetia", "Lorenzo", "Medici"},
        sprite = "💰",
        dialogue = {
            greeting = "Looking to trade goods or stocks?",
            options = {
                {text = "Trading post", action = "stockmarket"},
                {text = "Chat", action = "chat", responses = {
                    "Buy low, sell high - that's the secret!",
                    "Markets fluctuate based on supply and demand.",
                    "I deal in commodities from across the land.",
                }},
            }
        }
    },
    butcher = {
        profession = "butcher",
        names = {"Butch", "Helga", "Cleaver", "Bertha"},
        sprite = "🔪",
        dialogue = {
            greeting = "Fresh cuts today! What'll it be?",
            options = {
                {text = "Browse meats", action = "shop", shopType = "butcher"},
                {text = "Chat", action = "chat", responses = {
                    "Only the finest cuts here.",
                    "Fresh delivery every morning.",
                    "A good steak can lift anyone's spirits.",
                }},
            }
        }
    },
    baker = {
        profession = "baker",
        names = {"Baker", "Flour", "Crust", "Yeastly"},
        sprite = "🥖",
        dialogue = {
            greeting = "Fresh from the oven! Care for some bread?",
            options = {
                {text = "Browse goods", action = "shop", shopType = "bakery"},
                {text = "Chat", action = "chat", responses = {
                    "The secret is in the kneading.",
                    "Been baking since before dawn!",
                    "Nothing beats fresh bread.",
                }},
            }
        }
    },
    tailor = {
        profession = "tailor",
        names = {"Stitch", "Fabric", "Seam", "Velvet"},
        sprite = "🧵",
        dialogue = {
            greeting = "Looking for fine clothing?",
            options = {
                {text = "Browse clothes", action = "shop", shopType = "tailor"},
                {text = "Chat", action = "chat", responses = {
                    "Every garment is made with care.",
                    "Fashion is my passion!",
                    "I can tailor anything to fit.",
                }},
            }
        }
    },
    jeweler = {
        profession = "jeweler",
        names = {"Ruby", "Sapphire", "Diamond", "Emerald"},
        sprite = "💎",
        dialogue = {
            greeting = "Exquisite gems and jewelry here!",
            options = {
                {text = "Browse jewelry", action = "shop", shopType = "jeweler"},
                {text = "Chat", action = "chat", responses = {
                    "Each gem is carefully selected.",
                    "Jewelry is an investment.",
                    "The craftsmanship speaks for itself.",
                }},
            }
        }
    },
    wellkeeper = {
        profession = "wellkeeper",
        names = {"Wells", "Bucket", "Aqua", "Spring"},
        sprite = "🪣",
        dialogue = {
            greeting = "Fresh water from the town well!",
            options = {
                {text = "Draw water", action = "water"},
                {text = "Chat", action = "chat", responses = {
                    "The well has never run dry.",
                    "Cleanest water in the region!",
                    "Been maintaining this well for years.",
                }},
            }
        }
    },
    land_commissioner = {
        profession = "land_commissioner",
        names = {"Commissioner Harland", "Commissioner Thane", "Commissioner Aldara", "Commissioner Brennan"},
        sprite = "📜",
        dialogue = {
            greeting = "Welcome to the Land Office. I oversee all land expansion permits in this region.",
            options = {
                {text = "Purchase expansion permit", action = "land_office_permit"},
                {text = "View expansion rules", action = "land_office_rules"},
                {text = "Check permit status", action = "land_office_status"},
                {text = "Chat", action = "chat", responses = {
                    "Every plot of land must be properly documented.",
                    "Expansion requires permits - it keeps the realm orderly.",
                    "The Crown demands proper records of all land holdings.",
                    "I have overseen hundreds of land expansions in my career.",
                }},
            }
        }
    },
}

-- NPC Schedule Templates
local NPC_SCHEDULE_TEMPLATES = {
    shopkeeper = {
        workDays = {1, 2, 3, 4, 5, 6}, -- Works 6 days, off on day 7
        schedule = {
            {startHour = 8, endHour = 13, location = {type = "building", id = "work"}}, -- Morning shift
            {startHour = 13, endHour = 14, location = {type = "building", id = "tavern"}}, -- Lunch break
            {startHour = 14, endHour = 18, location = {type = "building", id = "work"}}, -- Afternoon shift
            {startHour = 18, endHour = 22, location = {type = "building", id = "tavern"}}, -- Evening socializing
            {startHour = 22, endHour = 8, location = {type = "building", id = "home"}}, -- Night rest
        },
        dayOffSchedule = {
            {startHour = 8, endHour = 12, location = {type = "building", id = "home"}}, -- Sleep in
            {startHour = 12, endHour = 20, location = {type = "building", id = "tavern"}}, -- Day off at tavern
            {startHour = 20, endHour = 8, location = {type = "building", id = "home"}}, -- Night rest
        }
    },
    blacksmith = {
        workDays = {1, 2, 3, 4, 5, 6},
        schedule = {
            {startHour = 6, endHour = 13, location = {type = "building", id = "work"}}, -- Early start
            {startHour = 13, endHour = 14, location = {type = "building", id = "tavern"}}, -- Lunch
            {startHour = 14, endHour = 20, location = {type = "building", id = "work"}}, -- Works late
            {startHour = 20, endHour = 22, location = {type = "building", id = "tavern"}}, -- Evening
            {startHour = 22, endHour = 6, location = {type = "building", id = "home"}}, -- Rest
        },
        dayOffSchedule = {
            {startHour = 7, endHour = 20, location = {type = "building", id = "tavern"}},
            {startHour = 20, endHour = 7, location = {type = "building", id = "home"}},
        }
    },
    alchemist = {
        workDays = {1, 2, 3, 4, 5, 6},
        schedule = {
            {startHour = 9, endHour = 13, location = {type = "building", id = "work"}}, -- Precise hours
            {startHour = 13, endHour = 14, location = {type = "building", id = "tavern"}}, -- Lunch
            {startHour = 14, endHour = 17, location = {type = "building", id = "work"}}, -- Shorter hours
            {startHour = 17, endHour = 22, location = {type = "building", id = "tavern"}}, -- Evening
            {startHour = 22, endHour = 9, location = {type = "building", id = "home"}}, -- Rest
        },
        dayOffSchedule = {
            {startHour = 9, endHour = 22, location = {type = "building", id = "home"}}, -- Studies at home
            {startHour = 22, endHour = 9, location = {type = "building", id = "home"}},
        }
    },
    wizard = {
        workDays = {1, 2, 3, 4, 5, 6, 7}, -- Works every day (magic never sleeps)
        schedule = {
            {startHour = 22, endHour = 4, location = {type = "building", id = "work"}}, -- Nocturnal studies
            {startHour = 4, endHour = 14, location = {type = "building", id = "home"}}, -- Sleep during day
            {startHour = 14, endHour = 15, location = {type = "building", id = "tavern"}}, -- Brief meal
            {startHour = 15, endHour = 22, location = {type = "building", id = "work"}}, -- Afternoon research
        },
        dayOffSchedule = {} -- Same schedule every day
    },
    priest = {
        workDays = {1, 2, 3, 4, 5, 6, 7}, -- Always available
        schedule = {
            {startHour = 5, endHour = 6, location = {type = "building", id = "work"}}, -- Morning prayers
            {startHour = 6, endHour = 12, location = {type = "building", id = "work"}}, -- Morning services
            {startHour = 12, endHour = 13, location = {type = "building", id = "work"}}, -- Midday prayer
            {startHour = 13, endHour = 18, location = {type = "building", id = "work"}}, -- Afternoon duties
            {startHour = 18, endHour = 23, location = {type = "building", id = "work"}}, -- Evening vespers
            {startHour = 23, endHour = 5, location = {type = "building", id = "home"}}, -- Night rest
        },
        dayOffSchedule = {} -- Same schedule every day
    },
    baker = {
        workDays = {1, 2, 3, 4, 5, 6},
        schedule = {
            {startHour = 4, endHour = 10, location = {type = "building", id = "work"}}, -- Very early start
            {startHour = 10, endHour = 14, location = {type = "building", id = "work"}}, -- Continue baking
            {startHour = 14, endHour = 20, location = {type = "building", id = "tavern"}}, -- Done early, socializing
            {startHour = 20, endHour = 4, location = {type = "building", id = "home"}}, -- Early to bed
        },
        dayOffSchedule = {
            {startHour = 6, endHour = 20, location = {type = "building", id = "tavern"}}, -- Sleep in, then tavern
            {startHour = 20, endHour = 6, location = {type = "building", id = "home"}},
        }
    },
    tavernkeep = {
        workDays = {1, 2, 3, 4, 5, 6},
        schedule = {
            {startHour = 11, endHour = 14, location = {type = "building", id = "work"}}, -- Lunch service
            {startHour = 14, endHour = 17, location = {type = "building", id = "home"}}, -- Afternoon break
            {startHour = 17, endHour = 2, location = {type = "building", id = "work"}}, -- Dinner through late night
            {startHour = 2, endHour = 11, location = {type = "building", id = "home"}}, -- Sleep late
        },
        dayOffSchedule = {
            {startHour = 11, endHour = 2, location = {type = "building", id = "home"}}, -- Home all day
            {startHour = 2, endHour = 11, location = {type = "building", id = "home"}},
        }
    },
    fisher = {
        workDays = {1, 2, 3, 4, 5, 6},
        schedule = {
            {startHour = 5, endHour = 12, location = {type = "building", id = "work"}}, -- Early fishing
            {startHour = 12, endHour = 13, location = {type = "building", id = "tavern"}}, -- Lunch
            {startHour = 13, endHour = 19, location = {type = "building", id = "work"}}, -- Afternoon fishing
            {startHour = 19, endHour = 22, location = {type = "building", id = "tavern"}}, -- Evening
            {startHour = 22, endHour = 5, location = {type = "building", id = "home"}}, -- Rest
        },
        dayOffSchedule = {
            {startHour = 8, endHour = 22, location = {type = "building", id = "tavern"}},
            {startHour = 22, endHour = 8, location = {type = "building", id = "home"}},
        }
    },
    hunter = {
        workDays = {1, 2, 3, 4, 5, 6},
        schedule = {
            {startHour = 5, endHour = 12, location = {type = "building", id = "work"}}, -- Early hunting
            {startHour = 12, endHour = 13, location = {type = "building", id = "tavern"}}, -- Lunch
            {startHour = 13, endHour = 19, location = {type = "building", id = "work"}}, -- Afternoon hunting
            {startHour = 19, endHour = 22, location = {type = "building", id = "tavern"}}, -- Evening
            {startHour = 22, endHour = 5, location = {type = "building", id = "home"}}, -- Rest
        },
        dayOffSchedule = {
            {startHour = 8, endHour = 22, location = {type = "building", id = "tavern"}},
            {startHour = 22, endHour = 8, location = {type = "building", id = "home"}},
        }
    },
    merchant = {
        workDays = {1, 2, 3, 4, 5, 6},
        schedule = {
            {startHour = 8, endHour = 13, location = {type = "building", id = "work"}},
            {startHour = 13, endHour = 14, location = {type = "building", id = "tavern"}},
            {startHour = 14, endHour = 18, location = {type = "building", id = "work"}},
            {startHour = 18, endHour = 22, location = {type = "building", id = "tavern"}},
            {startHour = 22, endHour = 8, location = {type = "building", id = "home"}},
        },
        dayOffSchedule = {
            {startHour = 8, endHour = 20, location = {type = "building", id = "tavern"}},
            {startHour = 20, endHour = 8, location = {type = "building", id = "home"}},
        }
    },
    butcher = {
        workDays = {1, 2, 3, 4, 5, 6},
        schedule = {
            {startHour = 6, endHour = 13, location = {type = "building", id = "work"}},
            {startHour = 13, endHour = 14, location = {type = "building", id = "tavern"}},
            {startHour = 14, endHour = 18, location = {type = "building", id = "work"}},
            {startHour = 18, endHour = 22, location = {type = "building", id = "tavern"}},
            {startHour = 22, endHour = 6, location = {type = "building", id = "home"}},
        },
        dayOffSchedule = {
            {startHour = 8, endHour = 20, location = {type = "building", id = "tavern"}},
            {startHour = 20, endHour = 8, location = {type = "building", id = "home"}},
        }
    },
    tailor = {
        workDays = {1, 2, 3, 4, 5, 6},
        schedule = {
            {startHour = 8, endHour = 13, location = {type = "building", id = "work"}},
            {startHour = 13, endHour = 14, location = {type = "building", id = "tavern"}},
            {startHour = 14, endHour = 18, location = {type = "building", id = "work"}},
            {startHour = 18, endHour = 22, location = {type = "building", id = "tavern"}},
            {startHour = 22, endHour = 8, location = {type = "building", id = "home"}},
        },
        dayOffSchedule = {
            {startHour = 8, endHour = 20, location = {type = "building", id = "tavern"}},
            {startHour = 20, endHour = 8, location = {type = "building", id = "home"}},
        }
    },
    jeweler = {
        workDays = {1, 2, 3, 4, 5, 6},
        schedule = {
            {startHour = 9, endHour = 13, location = {type = "building", id = "work"}},
            {startHour = 13, endHour = 14, location = {type = "building", id = "tavern"}},
            {startHour = 14, endHour = 17, location = {type = "building", id = "work"}},
            {startHour = 17, endHour = 22, location = {type = "building", id = "tavern"}},
            {startHour = 22, endHour = 9, location = {type = "building", id = "home"}},
        },
        dayOffSchedule = {
            {startHour = 9, endHour = 20, location = {type = "building", id = "tavern"}},
            {startHour = 20, endHour = 9, location = {type = "building", id = "home"}},
        }
    },
    stablemaster = {
        workDays = {1, 2, 3, 4, 5, 6, 7}, -- Animals need daily care
        schedule = {
            {startHour = 5, endHour = 13, location = {type = "building", id = "work"}},
            {startHour = 13, endHour = 14, location = {type = "building", id = "tavern"}},
            {startHour = 14, endHour = 19, location = {type = "building", id = "work"}},
            {startHour = 19, endHour = 22, location = {type = "building", id = "tavern"}},
            {startHour = 22, endHour = 5, location = {type = "building", id = "home"}},
        },
        dayOffSchedule = {} -- Same every day
    },
    wellkeeper = {
        workDays = {1, 2, 3, 4, 5, 6},
        schedule = {
            {startHour = 7, endHour = 13, location = {type = "building", id = "work"}},
            {startHour = 13, endHour = 14, location = {type = "building", id = "tavern"}},
            {startHour = 14, endHour = 19, location = {type = "building", id = "work"}},
            {startHour = 19, endHour = 22, location = {type = "building", id = "tavern"}},
            {startHour = 22, endHour = 7, location = {type = "building", id = "home"}},
        },
        dayOffSchedule = {
            {startHour = 9, endHour = 20, location = {type = "building", id = "tavern"}},
            {startHour = 20, endHour = 9, location = {type = "building", id = "home"}},
        }
    },
    -- Default for unknown professions
    default = {
        workDays = {1, 2, 3, 4, 5, 6},
        schedule = {
            {startHour = 8, endHour = 13, location = {type = "building", id = "work"}},
            {startHour = 13, endHour = 14, location = {type = "building", id = "tavern"}},
            {startHour = 14, endHour = 18, location = {type = "building", id = "work"}},
            {startHour = 18, endHour = 22, location = {type = "building", id = "tavern"}},
            {startHour = 22, endHour = 8, location = {type = "building", id = "home"}},
        },
        dayOffSchedule = {
            {startHour = 8, endHour = 20, location = {type = "building", id = "tavern"}},
            {startHour = 20, endHour = 8, location = {type = "building", id = "home"}},
        }
    }
}

-- Town events that affect NPC schedules and behavior
local TOWN_EVENTS = {
    weekly_market = {
        frequency = "weekly",
        day = 3, -- Day of week (1-7)
        startHour = 8,
        endHour = 18,
        location = {type = "building", id = "market"},
        affectedNPCs = {"merchant", "shopkeeper", "butcher", "baker", "tailor", "jeweler"}, -- Profession list
        description = "Weekly market day! Merchants gather with special wares.",
        priceModifier = 0.9, -- 10% discount during market day
        eventDialogue = {
            greeting = "Market day! Everything's on sale!",
            responses = {
                "Special prices today at the market!",
                "The weekly market brings the best deals.",
                "Come back every week for market day!",
            }
        }
    },
    harvest_festival = {
        frequency = "yearly",
        month = 9, -- September equivalent (based on season)
        day = 15, -- Day of month
        startHour = 10,
        endHour = 22,
        location = {type = "town_square", gridX = 3, gridY = 6},
        affectedNPCs = "all",
        description = "Harvest Festival! The whole town celebrates!",
        priceModifier = 1.0,
        eventDialogue = {
            greeting = "Happy Harvest Festival!",
            responses = {
                "What a wonderful celebration!",
                "The harvest has been bountiful this year.",
                "I love this time of year!",
            }
        }
    },
    moonlight_vigil = {
        frequency = "monthly",
        moonPhase = "full", -- Day 15 and 30 of each month
        startHour = 20,
        endHour = 24,
        location = {type = "building", id = "chapel"},
        affectedNPCs = {"priest"}, -- Only priests
        description = "Full moon vigil at the chapel.",
        eventDialogue = {
            greeting = "Join us for the moonlight vigil.",
            responses = {
                "The moon's power is strong tonight.",
                "We gather to honor the celestial cycle.",
                "May the moonlight guide your path.",
            }
        }
    },
    merchants_guild_meeting = {
        frequency = "weekly",
        day = 5, -- Friday equivalent
        startHour = 19,
        endHour = 21,
        location = {type = "building", id = "market"},
        affectedNPCs = {"merchant", "shopkeeper"},
        description = "Merchants Guild meeting.",
        eventDialogue = {
            greeting = "Guild meeting tonight.",
            responses = {
                "We discuss trade routes and prices.",
                "The guild looks after its members.",
                "Can't talk now, meeting soon.",
            }
        }
    },
    dawn_service = {
        frequency = "weekly",
        day = 1, -- First day of week
        startHour = 5,
        endHour = 7,
        location = {type = "building", id = "chapel"},
        affectedNPCs = {"priest"},
        description = "Special dawn service at the chapel.",
        eventDialogue = {
            greeting = "Join us for dawn service.",
            responses = {
                "The first light brings new hope.",
                "Dawn service is a blessed tradition.",
                "All are welcome at sunrise.",
            }
        }
    }
}

-- Wandering NPC templates
local WANDERING_NPC_TYPES = {
    town_guard = {
        count = 2,
        sprite = "🛡️",
        behavior = "patrol",
        route = {
            {x=1, y=1}, {x=6, y=1}, {x=6, y=11}, {x=1, y=11}
        },
        speed = 2.0, -- Seconds per tile
        schedule = "always",
        names = {"Guard Thomas", "Guard Sarah", "Guard William", "Guard Anne"}
    },
    child = {
        count = 3,
        sprite = "🧒",
        behavior = "wander",
        area = {x1=2, y1=3, x2=5, y2=7},
        speed = 1.5,
        schedule = {startHour = 8, endHour = 20},
        names = {"Little Tim", "Young Emma", "Small Jack", "Tiny Lucy", "Wee Peter"}
    },
    traveling_merchant = {
        count = 1,
        sprite = "🎒",
        behavior = "visit_schedule",
        buildings = {"shop", "market", "tavern"},
        visitDuration = 120, -- 2 minutes per location
        speed = 2.0,
        schedule = {startHour = 10, endHour = 18},
        names = {"Wandering Merchant", "Roving Trader", "Itinerant Seller"}
    },
    stray_cat = {
        count = 2,
        sprite = "🐱",
        behavior = "random",
        speed = 3.0,
        schedule = "always",
        names = {"Stray Cat", "Alley Cat", "Street Cat"}
    },
    dog = {
        count = 1,
        sprite = "🐕",
        behavior = "random",
        speed = 2.5,
        schedule = {startHour = 6, endHour = 22},
        names = {"Town Dog", "Friendly Dog", "Mutt"}
    }
}

-- Quest templates by profession
local QUEST_TEMPLATES = {
    alchemist = {
        {
            id = "fetch_herbs",
            name = "Gather Healing Herbs",
            description = "I need 5 healing herbs from the forest for my potions.",
            type = "collect",
            objectives = {
                {type = "collect", item = "healing_herb", amount = 5, current = 0}
            },
            requirements = {
                minLevel = 1,
                minReputation = 0,
                completedQuests = {}
            },
            rewards = {
                gold = 50,
                experience = 100,
                reputation = 10,
                items = {{id = "health_potion", amount = 2}}
            },
            repeatable = true,
            cooldown = 7, -- Days before can repeat
        },
        {
            id = "rare_ingredient",
            name = "Find Rare Ingredient",
            description = "I need a rare moonflower that only grows at night.",
            type = "collect",
            objectives = {
                {type = "collect", item = "moonflower", amount = 1, current = 0}
            },
            requirements = {
                minLevel = 5,
                minReputation = 25,
                completedQuests = {"fetch_herbs"}
            },
            rewards = {
                gold = 200,
                experience = 500,
                reputation = 25,
                items = {{id = "mana_potion", amount = 5}}
            },
            repeatable = false,
        },
    },
    blacksmith = {
        {
            id = "gather_iron",
            name = "Gather Iron Ore",
            description = "Bring me 10 iron ore from the mines.",
            type = "collect",
            objectives = {
                {type = "collect", item = "iron_ore", amount = 10, current = 0}
            },
            requirements = {
                minLevel = 1,
                minReputation = 0,
                completedQuests = {}
            },
            rewards = {
                gold = 75,
                experience = 150,
                reputation = 10,
                items = {{id = "iron_sword", amount = 1}}
            },
            repeatable = true,
            cooldown = 5,
        },
        {
            id = "slay_bandits",
            name = "Bandit Problem",
            description = "Bandits have been attacking travelers. Defeat 5 of them.",
            type = "kill",
            objectives = {
                {type = "kill", enemy = "bandit", amount = 5, current = 0}
            },
            requirements = {
                minLevel = 3,
                minReputation = 10,
                completedQuests = {}
            },
            rewards = {
                gold = 150,
                experience = 300,
                reputation = 20,
                items = {{id = "steel_sword", amount = 1}}
            },
            repeatable = true,
            cooldown = 10,
        },
    },
    priest = {
        {
            id = "donate_to_church",
            name = "Charitable Donation",
            description = "The church needs donations to help the poor.",
            type = "donation",
            objectives = {
                {type = "donate", amount = 100, current = 0}
            },
            requirements = {
                minLevel = 1,
                minReputation = 0,
                completedQuests = {}
            },
            rewards = {
                gold = 0,
                experience = 50,
                reputation = 15,
                items = {}
            },
            repeatable = true,
            cooldown = 7,
        },
        {
            id = "cleanse_undead",
            name = "Cleanse the Undead",
            description = "Undead creatures plague the cemetery. Destroy 10 of them.",
            type = "kill",
            objectives = {
                {type = "kill", enemy = "undead", amount = 10, current = 0}
            },
            requirements = {
                minLevel = 4,
                minReputation = 20,
                completedQuests = {}
            },
            rewards = {
                gold = 200,
                experience = 400,
                reputation = 30,
                items = {{id = "holy_water", amount = 3}}
            },
            repeatable = true,
            cooldown = 14,
        },
    },
    merchant = {
        {
            id = "delivery_quest",
            name = "Urgent Delivery",
            description = "Deliver this package to the merchant in the next town.",
            type = "delivery",
            objectives = {
                {type = "deliver", item = "package", destination = "next_town", current = 0}
            },
            requirements = {
                minLevel = 2,
                minReputation = 0,
                completedQuests = {}
            },
            rewards = {
                gold = 100,
                experience = 200,
                reputation = 15,
                items = {}
            },
            repeatable = true,
            cooldown = 5,
        },
    },
    tavernkeep = {
        {
            id = "find_rare_wine",
            name = "Rare Wine Request",
            description = "A customer wants rare wine. Find a bottle for me.",
            type = "collect",
            objectives = {
                {type = "collect", item = "rare_wine", amount = 1, current = 0}
            },
            requirements = {
                minLevel = 1,
                minReputation = 0,
                completedQuests = {}
            },
            rewards = {
                gold = 80,
                experience = 120,
                reputation = 10,
                items = {{id = "ale", amount = 3}}
            },
            repeatable = true,
            cooldown = 7,
        },
        {
            id = "bouncer_help",
            name = "Rowdy Customers",
            description = "Help me deal with some troublemakers in the tavern.",
            type = "combat_help",
            objectives = {
                {type = "complete_event", current = 0}
            },
            requirements = {
                minLevel = 3,
                minReputation = 10,
                completedQuests = {}
            },
            rewards = {
                gold = 120,
                experience = 250,
                reputation = 20,
                items = {}
            },
            repeatable = true,
            cooldown = 10,
        },
    },
}

-- ============================================================================
-- F_FUNCTIONS list and register
-- ============================================================================

M.F_FUNCTIONS = {
    -- NPC Creation & Management
    "createNPC",
    "getBuildingInteriorMap",
    "initializeTownNPCs",
    "updateNPCLocations",
    "getNPCsAtBuilding",
    "getNPCsAtPosition",
    -- NPC Schedules
    "getNPCScheduleForDay",
    -- Event System
    "initializeEventSystem",
    "checkActiveEvents",
    "updateNPCsForEvents",
    "getEventDialogue",
    "getEventPriceModifier",
    -- Wandering NPCs
    "initializeWanderingNPCs",
    "isWanderingNPCActive",
    "isPositionWalkable",
    "moveNPCAlongPath",
    "randomWalk",
    "visitSchedule",
    "randomMovement",
    "updateWanderingNPCs",
    "getWanderingNPCsAtPosition",
    -- Relationship System
    "initializeRelationshipSystem",
    "getNPCRelationship",
    "getTownReputation",
    "getRelationshipLevel",
    "getReputationPriceModifier",
    "modifyNPCRelationship",
    "modifyTownReputation",
    "modifyFactionReputation",
    "checkReputationRequirement",
    "getRelationshipDialogue",
    -- Quest System
    "initializeQuestSystem",
    "generateNPCQuests",
    "checkQuestRequirements",
    "acceptQuest",
    "updateQuestProgress",
    "isQuestReadyToComplete",
    "completeQuest",
    "getNPCQuestIndicator",
    "getAvailableQuestsFromNPC",
}

function M.register(s, f)
    state = s
    F = f
    for _, name in ipairs(M.F_FUNCTIONS) do
        if M[name] then F[name] = M[name] end
    end
end

-- ============================================================================
-- NPC CREATION & MANAGEMENT
-- ============================================================================

-- Function to create an NPC instance from a template
M.createNPC = function(profession, building, townId)
    local template = NPC_TEMPLATES[profession]
    if not template then return nil end

    local name = template.names[math.random(1, #template.names)]
    local npcId = townId .. "_" .. building .. "_" .. profession

    -- Determine home building (try to find a house, otherwise use work building)
    local homeBuilding = building
    -- Could be enhanced to assign actual houses to NPCs

    return {
        id = npcId,
        name = name,
        profession = profession,
        building = building,
        homeBuilding = homeBuilding,
        sprite = template.sprite or "🧑", -- Fallback sprite if template doesn't have one
        dialogue = template.dialogue,
        -- Schedule is now generated dynamically based on profession and day
        currentLocation = {type = "building", id = building, gridX = nil, gridY = nil},
        currentEvent = nil, -- Set when affected by an event
    }
end

-- Function to get building interior map layout
M.getBuildingInteriorMap = function(buildingId)
    -- Define interior layouts for different building types
    local layouts = {
        butcher = {
            width = 8,
            height = 6,
            furniture = {
                {x = 3, y = 2, type = "counter", sprite = "🪵"},
                {x = 4, y = 2, type = "counter", sprite = "🪵"},
                {x = 5, y = 2, type = "counter", sprite = "🪵"},
                {x = 2, y = 1, type = "hook", sprite = "🥩"},
                {x = 6, y = 1, type = "hook", sprite = "🥩"},
            },
            npcSpawn = {x = 4, y = 2},
            playerSpawn = {x = 4, y = 5}
        },
        bakery = {
            width = 8,
            height = 6,
            furniture = {
                {x = 2, y = 2, type = "oven", sprite = "🔥"},
                {x = 4, y = 3, type = "counter", sprite = "🪵"},
                {x = 5, y = 3, type = "counter", sprite = "🪵"},
                {x = 6, y = 2, type = "table", sprite = "🍞"},
            },
            npcSpawn = {x = 2, y = 2},
            playerSpawn = {x = 4, y = 5}
        },
        jeweler = {
            width = 8,
            height = 6,
            furniture = {
                {x = 3, y = 2, type = "display", sprite = "💎"},
                {x = 4, y = 2, type = "display", sprite = "💍"},
                {x = 5, y = 2, type = "display", sprite = "👑"},
                {x = 4, y = 3, type = "counter", sprite = "🪵"},
            },
            npcSpawn = {x = 4, y = 3},
            playerSpawn = {x = 4, y = 5}
        },
        tailor = {
            width = 8,
            height = 6,
            furniture = {
                {x = 2, y = 2, type = "table", sprite = "🪡"},
                {x = 6, y = 2, type = "rack", sprite = "👔"},
                {x = 6, y = 3, type = "rack", sprite = "👗"},
                {x = 4, y = 3, type = "counter", sprite = "🪵"},
            },
            npcSpawn = {x = 2, y = 2},
            playerSpawn = {x = 4, y = 5}
        },
        chapel = {
            width = 10,
            height = 8,
            furniture = {
                {x = 5, y = 2, type = "altar", sprite = "⛪"},
                {x = 3, y = 4, type = "pew", sprite = "🪑"},
                {x = 7, y = 4, type = "pew", sprite = "🪑"},
                {x = 3, y = 5, type = "pew", sprite = "🪑"},
                {x = 7, y = 5, type = "pew", sprite = "🪑"},
            },
            npcSpawn = {x = 5, y = 2},
            playerSpawn = {x = 5, y = 7}
        },
        shop = {
            width = 10,
            height = 8,
            furniture = {
                {x = 2, y = 2, type = "shelf", sprite = "📦"},
                {x = 2, y = 3, type = "shelf", sprite = "📦"},
                {x = 8, y = 2, type = "shelf", sprite = "📦"},
                {x = 8, y = 3, type = "shelf", sprite = "📦"},
                {x = 5, y = 4, type = "counter", sprite = "🪵"},
            },
            npcSpawn = {x = 5, y = 4},
            playerSpawn = {x = 5, y = 7}
        },
        stable = {
            width = 10,
            height = 8,
            furniture = {
                {x = 2, y = 2, type = "stall", sprite = "🐴"},
                {x = 2, y = 4, type = "stall", sprite = "🐴"},
                {x = 8, y = 2, type = "stall", sprite = "🐴"},
                {x = 8, y = 4, type = "stall", sprite = "🐴"},
                {x = 5, y = 6, type = "hay", sprite = "🌾"},
            },
            npcSpawn = {x = 5, y = 5},
            playerSpawn = {x = 5, y = 7}
        },
        well = {
            width = 6,
            height = 5,
            furniture = {
                {x = 3, y = 2, type = "well", sprite = "🪣"},
            },
            npcSpawn = {x = 3, y = 3},
            playerSpawn = {x = 3, y = 4}
        },
        shack = {
            width = 6,
            height = 5,
            furniture = {
                {x = 2, y = 2, type = "crate", sprite = "📦"},
                {x = 4, y = 2, type = "barrel", sprite = "🛢️"},
            },
            npcSpawn = {x = 3, y = 2},
            playerSpawn = {x = 3, y = 4}
        },
        farmhouse = {
            width = 8,
            height = 6,
            furniture = {
                {x = 2, y = 2, type = "table", sprite = "🪵"},
                {x = 6, y = 2, type = "chest", sprite = "📦"},
                {x = 4, y = 3, type = "chair", sprite = "🪑"},
            },
            npcSpawn = {x = 4, y = 2},
            playerSpawn = {x = 4, y = 5}
        }
    }

    -- Default layout for buildings without specific layout
    local defaultLayout = {
        width = 8,
        height = 6,
        furniture = {},
        npcSpawn = {x = 4, y = 3},
        playerSpawn = {x = 4, y = 5}
    }

    return layouts[buildingId] or defaultLayout
end

-- Function to initialize NPCs for a town
M.initializeTownNPCs = function(town)
    if not town then return end
    if town.npcs then return end -- Already initialized

    local townId = town.id or town.name or "unknown"
    town.npcs = {}

    -- Create key NPCs for each building type
    local npcBuildings = {
        {building = "shop", profession = "shopkeeper"},
        {building = "forge", profession = "blacksmith"},
        {building = "chapel", profession = "priest"},
        {building = "tavern", profession = "tavernkeep"},
        {building = "stable", profession = "stablemaster"},
        {building = "alchemist", profession = "alchemist"},
        {building = "wizardtower", profession = "wizard"},
        {building = "fishing", profession = "fisher"},
        {building = "hunting", profession = "hunter"},
        {building = "market", profession = "merchant"},
        {building = "butcher", profession = "butcher"},
        {building = "bakery", profession = "baker"},
        {building = "tailor", profession = "tailor"},
        {building = "jeweler", profession = "jeweler"},
        {building = "well", profession = "wellkeeper"},
        {building = "land_office", profession = "land_commissioner"},
    }

    for _, npcData in ipairs(npcBuildings) do
        local npc = F.createNPC(npcData.profession, npcData.building, townId)
        if npc then
            table.insert(town.npcs, npc)
        end
    end

    -- Initialize wandering NPCs
    F.initializeWanderingNPCs(town)

    -- Initialize systems
    F.initializeEventSystem()
    F.initializeRelationshipSystem()
    F.initializeQuestSystem()

    -- Update initial NPC locations based on current time
    F.updateNPCLocations(town)
end

-- Function to update NPC locations based on time of day
M.updateNPCLocations = function(town)
    if not town or not town.npcs then return end

    local currentHour = math.floor(state.timeOfDay or 12)
    local currentDay = math.floor(state.daysPassed or 0)
    local dayOfWeek = (currentDay % 7) + 1 -- 1-7

    -- First, update NPCs for any active events
    F.updateNPCsForEvents(town)

    for _, npc in ipairs(town.npcs) do
        -- Skip if NPC is at an event
        if npc.currentEvent then
            goto continue
        end

        -- Get schedule for current day
        local schedule = F.getNPCScheduleForDay(npc, dayOfWeek)

        -- Find which schedule entry applies to current time
        for _, scheduleEntry in ipairs(schedule) do
            local inSchedule = false
            if scheduleEntry.startHour <= scheduleEntry.endHour then
                -- Normal schedule (e.g., 8 to 18)
                inSchedule = currentHour >= scheduleEntry.startHour and currentHour < scheduleEntry.endHour
            else
                -- Overnight schedule (e.g., 22 to 6)
                inSchedule = currentHour >= scheduleEntry.startHour or currentHour < scheduleEntry.endHour
            end

            if inSchedule then
                local locationId = scheduleEntry.location.id

                -- Replace "work" and "home" placeholders
                if locationId == "work" then
                    locationId = npc.building
                elseif locationId == "home" then
                    locationId = npc.homeBuilding
                end

                npc.currentLocation = {
                    type = scheduleEntry.location.type,
                    id = locationId,
                    gridX = nil, -- Will be set based on building location
                    gridY = nil
                }

                -- Set grid position based on building
                if scheduleEntry.location.type == "building" then
                    local building = F.getTownBuildingById(locationId)
                    if building then
                        npc.currentLocation.gridX = building.gridX
                        npc.currentLocation.gridY = building.gridY
                    end
                end
                break
            end
        end

        -- Fallback: If NPC doesn't have a valid grid position (no schedule matched), place them at their work building
        if not npc.currentLocation.gridX or not npc.currentLocation.gridY then
            local building = F.getTownBuildingById(npc.building)
            if building then
                npc.currentLocation.gridX = building.gridX
                npc.currentLocation.gridY = building.gridY
                npc.currentLocation.id = npc.building
                npc.currentLocation.type = "building"
            end
        end

        ::continue::
    end
end

-- Function to get NPCs at a specific building
M.getNPCsAtBuilding = function(buildingId)
    local town = state.world and state.world.currentTown
    if not town or not town.npcs then return {} end

    local npcsHere = {}
    for _, npc in ipairs(town.npcs) do
        if npc.currentLocation.id == buildingId then
            table.insert(npcsHere, npc)
        end
    end
    return npcsHere
end

-- Function to get NPCs at a specific grid position (for town rendering)
M.getNPCsAtPosition = function(gridX, gridY)
    local town = state.world and state.world.currentTown
    if not town or not town.npcs then return {} end

    local npcsHere = {}
    for _, npc in ipairs(town.npcs) do
        if npc.currentLocation.gridX == gridX and npc.currentLocation.gridY == gridY then
            table.insert(npcsHere, npc)
        end
    end
    return npcsHere
end

-- ============================================================================
-- NPC SCHEDULES
-- ============================================================================

-- Get appropriate schedule for an NPC based on profession and day
M.getNPCScheduleForDay = function(npc, dayOfWeek)
    local scheduleTemplate = NPC_SCHEDULE_TEMPLATES[npc.profession] or NPC_SCHEDULE_TEMPLATES.default

    -- Check if NPC is working today
    local isWorkDay = false
    for _, workDay in ipairs(scheduleTemplate.workDays) do
        if workDay == dayOfWeek then
            isWorkDay = true
            break
        end
    end

    -- Return appropriate schedule
    if isWorkDay then
        return scheduleTemplate.schedule
    else
        if #scheduleTemplate.dayOffSchedule > 0 then
            return scheduleTemplate.dayOffSchedule
        else
            return scheduleTemplate.schedule -- Some NPCs work every day
        end
    end
end

-- ============================================================================
-- EVENT SYSTEM
-- ============================================================================

-- Initialize event system in state
M.initializeEventSystem = function()
    if not state.townEvents then
        state.townEvents = {
            activeEvents = {},
            lastCheckedDay = 0,
        }
    end
end

-- Check what events are currently active
M.checkActiveEvents = function()
    F.initializeEventSystem()

    local currentDay = math.floor(state.daysPassed or 0)
    local currentHour = math.floor(state.timeOfDay or 12)
    local dayOfWeek = (currentDay % 7) + 1 -- 1-7
    local cal = getCalendarDate(currentDay)
    local dayOfMonth = cal.day
    local month = cal.month

    local activeEvents = {}

    for eventId, event in pairs(TOWN_EVENTS) do
        local isActive = false

        -- Check if event should be active based on frequency
        if event.frequency == "weekly" then
            if dayOfWeek == event.day and currentHour >= event.startHour and currentHour < event.endHour then
                isActive = true
            end
        elseif event.frequency == "monthly" then
            if event.moonPhase == "full" then
                -- Full moon on days 15 and 30
                if (dayOfMonth == 15 or dayOfMonth == 30) and currentHour >= event.startHour and currentHour < event.endHour then
                    isActive = true
                end
            elseif dayOfMonth == event.day and currentHour >= event.startHour and currentHour < event.endHour then
                isActive = true
            end
        elseif event.frequency == "yearly" then
            if month == event.month and dayOfMonth == event.day and currentHour >= event.startHour and currentHour < event.endHour then
                isActive = true
            end
        end

        if isActive then
            table.insert(activeEvents, {id = eventId, data = event})
        end
    end

    state.townEvents.activeEvents = activeEvents
    return activeEvents
end

-- Update NPC locations based on active events
M.updateNPCsForEvents = function(town)
    if not town or not town.npcs then return end

    local activeEvents = F.checkActiveEvents()

    for _, eventInfo in ipairs(activeEvents) do
        local event = eventInfo.data

        for _, npc in ipairs(town.npcs) do
            local isAffected = false

            -- Check if NPC is affected by this event
            if event.affectedNPCs == "all" then
                isAffected = true
            elseif type(event.affectedNPCs) == "table" then
                for _, profession in ipairs(event.affectedNPCs) do
                    if npc.profession == profession then
                        isAffected = true
                        break
                    end
                end
            end

            -- Override NPC location if affected
            if isAffected then
                npc.currentEvent = eventInfo.id
                npc.currentLocation = {
                    type = event.location.type,
                    id = event.location.id,
                    gridX = event.location.gridX,
                    gridY = event.location.gridY
                }

                -- Set grid position based on location
                if event.location.type == "building" then
                    local building = getTownBuildingById(event.location.id)
                    if building then
                        npc.currentLocation.gridX = building.gridX
                        npc.currentLocation.gridY = building.gridY
                    end
                elseif event.location.gridX and event.location.gridY then
                    npc.currentLocation.gridX = event.location.gridX
                    npc.currentLocation.gridY = event.location.gridY
                end
            else
                npc.currentEvent = nil
            end
        end
    end
end

-- Get event-specific dialogue for an NPC
M.getEventDialogue = function(npc)
    if not npc.currentEvent then return nil end

    local event = TOWN_EVENTS[npc.currentEvent]
    if not event or not event.eventDialogue then return nil end

    return event.eventDialogue
end

-- Get price modifier from active events
M.getEventPriceModifier = function(npc)
    if not npc or not npc.currentEvent then return 1.0 end

    local event = TOWN_EVENTS[npc.currentEvent]
    if not event then return 1.0 end

    return event.priceModifier or 1.0
end

-- ============================================================================
-- WANDERING NPCs (PATROL ROUTES & RANDOM MOVEMENT)
-- ============================================================================

-- Initialize wandering NPCs for a town
M.initializeWanderingNPCs = function(town)
    if not town then return end
    if town.wanderingNPCs then return end -- Already initialized

    town.wanderingNPCs = {}

    for npcType, template in pairs(WANDERING_NPC_TYPES) do
        for i = 1, template.count do
            local wanderingNPC = {
                id = town.id .. "_" .. npcType .. "_" .. i,
                type = npcType,
                name = template.names[math.random(1, #template.names)],
                sprite = template.sprite,
                behavior = template.behavior,
                speed = template.speed,
                schedule = template.schedule,
                gridX = 3,
                gridY = 6,
                visible = true,
                moveTimer = 0,
                routeIndex = 1,
                visitIndex = 1,
                visitTimer = 0,
            }

            -- Set type-specific data
            if template.behavior == "patrol" then
                wanderingNPC.route = template.route
                -- Start at random position on route
                local startPos = template.route[math.random(1, #template.route)]
                wanderingNPC.gridX = startPos.x
                wanderingNPC.gridY = startPos.y
            elseif template.behavior == "wander" then
                wanderingNPC.area = template.area
                -- Start at random position in area
                wanderingNPC.gridX = math.random(template.area.x1, template.area.x2)
                wanderingNPC.gridY = math.random(template.area.y1, template.area.y2)
            elseif template.behavior == "visit_schedule" then
                wanderingNPC.buildings = template.buildings
                wanderingNPC.visitDuration = template.visitDuration
                -- Start at first building
                local building = getTownBuildingById(template.buildings[1])
                if building then
                    wanderingNPC.gridX = building.gridX
                    wanderingNPC.gridY = building.gridY
                end
            elseif template.behavior == "random" then
                -- Start at random valid position
                wanderingNPC.gridX = math.random(1, 6)
                wanderingNPC.gridY = math.random(1, 12)
            end

            table.insert(town.wanderingNPCs, wanderingNPC)
        end
    end
end

-- Check if wandering NPC should be visible based on schedule
M.isWanderingNPCActive = function(npc)
    if npc.schedule == "always" then
        return true
    end

    local currentHour = math.floor(state.timeOfDay or 12)

    if npc.schedule.startHour <= npc.schedule.endHour then
        return currentHour >= npc.schedule.startHour and currentHour < npc.schedule.endHour
    else
        return currentHour >= npc.schedule.startHour or currentHour < npc.schedule.endHour
    end
end

-- Check if position is walkable (not a building, except streets)
M.isPositionWalkable = function(x, y)
    -- Check bounds
    if x < 1 or x > 6 or y < 1 or y > 12 then
        return false
    end

    -- Street column is always walkable
    if x == 3 then
        return true
    end

    -- Street rows are walkable
    if F.isStreetRow(y) then
        return true
    end

    -- Check if there's a building here
    local building = F.getTownBuildingAt(x, y)
    return building == nil
end

-- Move NPC along patrol route
M.moveNPCAlongPath = function(npc, dt)
    npc.moveTimer = npc.moveTimer + dt

    if npc.moveTimer >= npc.speed then
        npc.moveTimer = 0

        -- Move to next point on route
        npc.routeIndex = npc.routeIndex + 1
        if npc.routeIndex > #npc.route then
            npc.routeIndex = 1
        end

        local nextPos = npc.route[npc.routeIndex]
        npc.gridX = nextPos.x
        npc.gridY = nextPos.y
    end
end

-- Random walk within area
M.randomWalk = function(npc, dt)
    npc.moveTimer = npc.moveTimer + dt

    if npc.moveTimer >= npc.speed then
        npc.moveTimer = 0

        -- Try to move in random direction
        local directions = {
            {dx = 0, dy = -1}, {dx = 0, dy = 1},
            {dx = -1, dy = 0}, {dx = 1, dy = 0}
        }

        -- Shuffle directions
        for i = #directions, 2, -1 do
            local j = math.random(i)
            directions[i], directions[j] = directions[j], directions[i]
        end

        -- Try each direction
        for _, dir in ipairs(directions) do
            local newX = npc.gridX + dir.dx
            local newY = npc.gridY + dir.dy

            -- Check if within area (if specified)
            local inArea = true
            if npc.area then
                inArea = newX >= npc.area.x1 and newX <= npc.area.x2 and
                         newY >= npc.area.y1 and newY <= npc.area.y2
            end

            -- Check if walkable
            if inArea and F.isPositionWalkable(newX, newY) then
                npc.gridX = newX
                npc.gridY = newY
                break
            end
        end
    end
end

-- Visit buildings in sequence
M.visitSchedule = function(npc, dt)
    npc.visitTimer = npc.visitTimer + dt

    if npc.visitTimer >= npc.visitDuration then
        npc.visitTimer = 0

        -- Move to next building
        npc.visitIndex = npc.visitIndex + 1
        if npc.visitIndex > #npc.buildings then
            npc.visitIndex = 1
        end

        local building = getTownBuildingById(npc.buildings[npc.visitIndex])
        if building then
            npc.gridX = building.gridX
            npc.gridY = building.gridY
        end
    end
end

-- Completely random movement
M.randomMovement = function(npc, dt)
    npc.moveTimer = npc.moveTimer + dt

    if npc.moveTimer >= npc.speed then
        npc.moveTimer = 0

        -- 50% chance to move
        if math.random() < 0.5 then
            local directions = {
                {dx = 0, dy = -1}, {dx = 0, dy = 1},
                {dx = -1, dy = 0}, {dx = 1, dy = 0}
            }

            local dir = directions[math.random(1, #directions)]
            local newX = npc.gridX + dir.dx
            local newY = npc.gridY + dir.dy

            if F.isPositionWalkable(newX, newY) then
                npc.gridX = newX
                npc.gridY = newY
            end
        end
    end
end

-- Update all wandering NPCs
M.updateWanderingNPCs = function(dt)
    local town = state.world and state.world.currentTown
    if not town or not town.wanderingNPCs then return end

    for _, npc in ipairs(town.wanderingNPCs) do
        -- Check if NPC should be visible
        npc.visible = F.isWanderingNPCActive(npc)

        if npc.visible then
            -- Update based on behavior type
            if npc.behavior == "patrol" then
                F.moveNPCAlongPath(npc, dt)
            elseif npc.behavior == "wander" then
                F.randomWalk(npc, dt)
            elseif npc.behavior == "visit_schedule" then
                F.visitSchedule(npc, dt)
            elseif npc.behavior == "random" then
                F.randomMovement(npc, dt)
            end
        end
    end
end

-- Get wandering NPCs at position
M.getWanderingNPCsAtPosition = function(gridX, gridY)
    local town = state.world and state.world.currentTown
    if not town or not town.wanderingNPCs then return {} end

    local npcsHere = {}
    for _, npc in ipairs(town.wanderingNPCs) do
        if npc.visible and npc.gridX == gridX and npc.gridY == gridY then
            table.insert(npcsHere, npc)
        end
    end
    return npcsHere
end

-- ============================================================================
-- RELATIONSHIP/REPUTATION SYSTEM
-- ============================================================================

-- Initialize relationship system in state
M.initializeRelationshipSystem = function()
    if not state.npcRelationships then
        state.npcRelationships = {}
    end
    if not state.townReputation then
        state.townReputation = {}
    end
    if not state.factionReputation then
        state.factionReputation = {
            merchants_guild = 0,
            church = 0,
            thieves_guild = 0,
            mages_guild = 0,
            guards = 0,
        }
    end
end

-- Get or create NPC relationship data
M.getNPCRelationship = function(npcId)
    F.initializeRelationshipSystem()

    if not state.npcRelationships[npcId] then
        state.npcRelationships[npcId] = {
            reputation = 0, -- -100 to 100
            interactions = 0,
            giftsGiven = 0,
            questsCompleted = 0,
            lastInteraction = state.timeOfDay or 12,
            relationshipLevel = "neutral",
            priceModifier = 1.0,
        }
    end

    return state.npcRelationships[npcId]
end

-- Get or create town reputation data
M.getTownReputation = function(townId)
    F.initializeRelationshipSystem()

    if not state.townReputation[townId] then
        state.townReputation[townId] = {
            reputation = 0,
            crimes = 0,
            questsCompleted = 0,
            donations = 0,
        }
    end

    return state.townReputation[townId]
end

-- Convert reputation number to level string
M.getRelationshipLevel = function(reputation)
    if reputation <= -75 then
        return "hated"
    elseif reputation <= -25 then
        return "disliked"
    elseif reputation <= 25 then
        return "neutral"
    elseif reputation <= 75 then
        return "friendly"
    else
        return "loved"
    end
end

-- Calculate price modifier based on relationship
M.getReputationPriceModifier = function(npcId)
    local relationship = F.getNPCRelationship(npcId)

    if relationship.relationshipLevel == "loved" then
        return 0.75 -- 25% discount
    elseif relationship.relationshipLevel == "friendly" then
        return 0.90 -- 10% discount
    elseif relationship.relationshipLevel == "neutral" then
        return 1.0 -- Normal price
    elseif relationship.relationshipLevel == "disliked" then
        return 1.25 -- 25% markup
    elseif relationship.relationshipLevel == "hated" then
        return 1.50 -- 50% markup (or refuse service)
    end

    return 1.0
end

-- Modify NPC relationship
M.modifyNPCRelationship = function(npcId, amount, reason)
    local relationship = F.getNPCRelationship(npcId)

    relationship.reputation = math.max(-100, math.min(100, relationship.reputation + amount))
    relationship.relationshipLevel = F.getRelationshipLevel(relationship.reputation)
    relationship.priceModifier = F.getReputationPriceModifier(npcId)
    relationship.lastInteraction = state.timeOfDay or 12

    -- Track specific actions
    if reason == "chat" then
        relationship.interactions = relationship.interactions + 1
    elseif reason == "gift" then
        relationship.giftsGiven = relationship.giftsGiven + 1
    elseif reason == "quest_complete" then
        relationship.questsCompleted = relationship.questsCompleted + 1
    end

    -- Log relationship changes
    if amount > 0 then
        log("Relationship with " .. npcId .. " improved! (+" .. amount .. ")", {0.4, 0.8, 0.4})
    elseif amount < 0 then
        log("Relationship with " .. npcId .. " worsened! (" .. amount .. ")", {0.8, 0.4, 0.4})
    end
end

-- Modify town reputation
M.modifyTownReputation = function(townId, amount, reason)
    local townRep = F.getTownReputation(townId)

    townRep.reputation = math.max(-100, math.min(100, townRep.reputation + amount))

    -- Track specific actions
    if reason == "crime" then
        townRep.crimes = townRep.crimes + 1
    elseif reason == "quest" then
        townRep.questsCompleted = townRep.questsCompleted + 1
    elseif reason == "donation" then
        townRep.donations = townRep.donations + 1
    end

    if amount > 0 then
        log("Town reputation improved! (+" .. amount .. ")", {0.4, 0.8, 0.4})
    elseif amount < 0 then
        log("Town reputation worsened! (" .. amount .. ")", {0.8, 0.4, 0.4})
    end
end

-- Modify faction reputation
M.modifyFactionReputation = function(faction, amount)
    F.initializeRelationshipSystem()

    if state.factionReputation[faction] then
        state.factionReputation[faction] = math.max(-100, math.min(100, state.factionReputation[faction] + amount))

        if amount > 0 then
            log(faction .. " reputation improved! (+" .. amount .. ")", {0.4, 0.8, 0.4})
        elseif amount < 0 then
            log(faction .. " reputation worsened! (" .. amount .. ")", {0.8, 0.4, 0.4})
        end
    end
end

-- Check if player meets reputation requirement
M.checkReputationRequirement = function(npcId, requiredRep)
    local relationship = F.getNPCRelationship(npcId)
    return relationship.reputation >= requiredRep
end

-- Get relationship dialogue modifier
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

-- ============================================================================
-- QUEST SYSTEM
-- ============================================================================

-- Initialize quest system
M.initializeQuestSystem = function()
    if not state.quests then
        state.quests = {
            available = {}, -- Quest IDs available from NPCs
            active = {}, -- Active quests: {questId, npcId, progress, objectives}
            completed = {}, -- Completed quest IDs
            completedTimestamps = {}, -- When quests were completed (for cooldowns)
        }
    end
end

-- Generate quests for an NPC
M.generateNPCQuests = function(npc)
    F.initializeQuestSystem()

    if not npc or not npc.profession then return {} end

    local templates = QUEST_TEMPLATES[npc.profession]
    if not templates then return {} end

    local availableQuests = {}
    local currentDay = math.floor(state.daysPassed or 0)

    for _, template in ipairs(templates) do
        local questId = npc.id .. "_" .. template.id

        -- Check if already completed
        local isCompleted = false
        for _, completedId in ipairs(state.quests.completed) do
            if completedId == questId then
                isCompleted = true
                break
            end
        end

        -- Check if already active
        local isActive = false
        for _, activeQuest in ipairs(state.quests.active) do
            if activeQuest.questId == questId then
                isActive = true
                break
            end
        end

        -- Check cooldown for repeatable quests
        local onCooldown = false
        if template.repeatable and isCompleted and template.cooldown then
            local completedTime = state.quests.completedTimestamps[questId]
            if completedTime then
                local daysSinceComplete = currentDay - completedTime
                if daysSinceComplete < template.cooldown then
                    onCooldown = true
                end
            end
        end

        -- Check if quest can be offered
        if not isActive then
            if template.repeatable then
                if not onCooldown then
                    table.insert(availableQuests, {questId = questId, template = template, completed = isCompleted})
                end
            else
                if not isCompleted then
                    table.insert(availableQuests, {questId = questId, template = template, completed = false})
                end
            end
        end
    end

    return availableQuests
end

-- Check if player meets quest requirements
M.checkQuestRequirements = function(quest, npcId)
    if not quest or not quest.template then return false end

    local template = quest.template
    local player = state.player

    -- Check level
    if player.level < template.requirements.minLevel then
        return false, "Level " .. template.requirements.minLevel .. " required"
    end

    -- Check reputation
    if npcId and template.requirements.minReputation > 0 then
        if not F.checkReputationRequirement(npcId, template.requirements.minReputation) then
            return false, "Better reputation needed"
        end
    end

    -- Check prerequisite quests
    if template.requirements.completedQuests and #template.requirements.completedQuests > 0 then
        for _, prereqId in ipairs(template.requirements.completedQuests) do
            local hasPrereq = false
            for _, completedId in ipairs(state.quests.completed) do
                if completedId:find(prereqId) then
                    hasPrereq = true
                    break
                end
            end
            if not hasPrereq then
                return false, "Complete prerequisite quests first"
            end
        end
    end

    return true, "Requirements met"
end

-- Accept a quest
M.acceptQuest = function(questId, npcId, template)
    F.initializeQuestSystem()

    -- Create quest instance
    local quest = {
        questId = questId,
        npcId = npcId,
        name = template.name,
        description = template.description,
        type = template.type,
        objectives = {},
        rewards = template.rewards,
        acceptedDay = math.floor(state.daysPassed or 0),
    }

    -- Copy objectives
    for _, obj in ipairs(template.objectives) do
        table.insert(quest.objectives, {
            type = obj.type,
            item = obj.item,
            enemy = obj.enemy,
            amount = obj.amount,
            destination = obj.destination,
            current = 0,
            completed = false,
        })
    end

    table.insert(state.quests.active, quest)
    log("Quest accepted: " .. template.name, {0.4, 0.8, 1.0})

    -- Discover locations mentioned in quest
    local AutoTravel = require("auto_travel")
    if AutoTravel and template.mentionedLocations then
        for _, location in ipairs(template.mentionedLocations) do
            AutoTravel.discoverLocation(location)
        end
    end
end

-- Update quest progress
M.updateQuestProgress = function(updateType, updateData)
    F.initializeQuestSystem()

    for _, quest in ipairs(state.quests.active) do
        for _, objective in ipairs(quest.objectives) do
            if not objective.completed then
                -- Check if this update applies to this objective
                if objective.type == "collect" and updateType == "collect" then
                    if objective.item == updateData.item then
                        objective.current = math.min(objective.amount, objective.current + (updateData.count or 1))
                        if objective.current >= objective.amount then
                            objective.completed = true
                            log("Quest objective complete: " .. quest.name, {0.4, 1.0, 0.4})
                        end
                    end
                elseif objective.type == "kill" and updateType == "kill" then
                    if objective.enemy == updateData.enemy or updateData.enemy == "any" then
                        objective.current = math.min(objective.amount, objective.current + 1)
                        if objective.current >= objective.amount then
                            objective.completed = true
                            log("Quest objective complete: " .. quest.name, {0.4, 1.0, 0.4})
                        end
                    end
                elseif objective.type == "deliver" and updateType == "deliver" then
                    if objective.item == updateData.item and objective.destination == updateData.destination then
                        objective.current = 1
                        objective.completed = true
                        log("Quest objective complete: " .. quest.name, {0.4, 1.0, 0.4})
                    end
                elseif objective.type == "donate" and updateType == "donate" then
                    objective.current = math.min(objective.amount, objective.current + updateData.amount)
                    if objective.current >= objective.amount then
                        objective.completed = true
                        log("Quest objective complete: " .. quest.name, {0.4, 1.0, 0.4})
                    end
                end
            end
        end
    end
end

-- Check if quest is ready to complete
M.isQuestReadyToComplete = function(quest)
    for _, objective in ipairs(quest.objectives) do
        if not objective.completed then
            return false
        end
    end
    return true
end

-- Complete a quest
M.completeQuest = function(questId)
    F.initializeQuestSystem()

    -- Find quest in active list
    local questIndex = nil
    local quest = nil
    for i, q in ipairs(state.quests.active) do
        if q.questId == questId then
            questIndex = i
            quest = q
            break
        end
    end

    if not quest then return false end

    -- Check if all objectives complete
    if not F.isQuestReadyToComplete(quest) then
        return false
    end

    -- Give rewards
    if quest.rewards.gold and quest.rewards.gold > 0 then
        PlayerData.coins = (PlayerData.coins or 0) + quest.rewards.gold
        if state.player then
            state.player.gold = (state.player.gold or 0) + quest.rewards.gold
        end
        log("Received " .. quest.rewards.gold .. " gold!", {1.0, 0.84, 0.0})
    end

    if quest.rewards.experience and quest.rewards.experience > 0 then
        if state.player then
            state.player.xp = (state.player.xp or 0) + quest.rewards.experience
            log("Gained " .. quest.rewards.experience .. " experience!", {0.6, 0.8, 1.0})
            -- Check for level up
            local xpNeeded = (state.player.level or 1) * 100
            while state.player.xp >= xpNeeded do
                state.player.xp = state.player.xp - xpNeeded
                state.player.level = (state.player.level or 1) + 1
                state.player.maxHP = (state.player.maxHP or 100) + 10
                state.player.hp = state.player.maxHP
                log("LEVEL UP! You are now level " .. state.player.level .. "!", {1.0, 0.84, 0.0})
                xpNeeded = state.player.level * 100
            end
        end
    end

    if quest.rewards.reputation and quest.rewards.reputation > 0 then
        F.modifyNPCRelationship(quest.npcId, quest.rewards.reputation, "quest_complete")
    end

    if quest.rewards.items and #quest.rewards.items > 0 then
        local Backpack = require("backpack")
        for _, itemReward in ipairs(quest.rewards.items) do
            Backpack.addItem(itemReward.id, itemReward.amount or 1)
            log("Received " .. (itemReward.amount or 1) .. "x " .. itemReward.id, {0.8, 1.0, 0.8})
        end
    end

    -- Move to completed
    table.insert(state.quests.completed, questId)
    state.quests.completedTimestamps[questId] = math.floor(state.daysPassed or 0)
    table.remove(state.quests.active, questIndex)

    -- Update stats
    if state.stats then
        state.stats.questsCompleted = (state.stats.questsCompleted or 0) + 1
    end

    log("Quest completed: " .. quest.name .. "!", {0.4, 1.0, 0.4})
    return true
end

-- Get quest indicator for NPC
M.getNPCQuestIndicator = function(npc)
    F.initializeQuestSystem()

    -- Check if any active quests are ready to turn in
    for _, quest in ipairs(state.quests.active) do
        if quest.npcId == npc.id and F.isQuestReadyToComplete(quest) then
            return "✓" -- Ready to turn in
        end
    end

    -- Check if NPC has available quests
    local availableQuests = F.generateNPCQuests(npc)
    for _, questInfo in ipairs(availableQuests) do
        local meetsReq, reason = F.checkQuestRequirements(questInfo, npc.id)
        if meetsReq then
            return "❗" -- Quest available
        else
            return "?" -- Quest available but requirements not met
        end
    end

    return nil -- No quests
end

-- Get all available quests from NPC
M.getAvailableQuestsFromNPC = function(npc)
    local availableQuests = F.generateNPCQuests(npc)
    local quests = {
        available = {},
        readyToComplete = {},
    }

    -- Check active quests ready to complete
    for _, quest in ipairs(state.quests.active) do
        if quest.npcId == npc.id and F.isQuestReadyToComplete(quest) then
            table.insert(quests.readyToComplete, quest)
        end
    end

    -- Filter available quests by requirements
    for _, questInfo in ipairs(availableQuests) do
        local meetsReq, reason = F.checkQuestRequirements(questInfo, npc.id)
        table.insert(quests.available, {
            questId = questInfo.questId,
            template = questInfo.template,
            meetsRequirements = meetsReq,
            requirementReason = reason,
        })
    end

    return quests
end

return M

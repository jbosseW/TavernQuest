# Karma/Crime & Faction System Implementation

## ✅ COMPLETED

### 1. Data Structures Added
- **Karma Levels** (Saint, Good, Neutral, Chaotic, Criminal, Villain)
- **Crime Types** (Assault, Murder, Theft, Trespassing, etc.)
- **Factions** (15 total):
  - **Nations**: Holy Dominion, Dwarven Kingdom, Orcish Clans, Shadowfen Witches, Gnomish Republic
  - **Guilds**: Blacksmith's Guild, Merchant's Guild, Adventurer's Guild, Mage's Guild
  - **Crime Orgs**: Thieves' Guild, Assassin's Guild, Smuggler's Ring
  - **Unions**: Miner's Union, Craftsmen's Union
- **Reputation Levels** (Exalted, Honored, Friendly, Neutral, Unfriendly, Hostile, Hated, Kill on Sight)

### 2. Player Data Extended
Added to player object:
```lua
karma = 0                  -- Karma score (-100 to 100)
bounty = 0                 -- Active bounty
crimes = {}                -- List of crimes committed
isJailed = false           -- Currently in jail
jailTimeRemaining = 0      -- Hours remaining
factionRep = {}            -- Reputation with each faction
joinedFactions = {}        -- List of joined factions
```

### 3. Core Functions Implemented
- **commitCrime(crimeType)** - Applies karma penalty, adds bounty, triggers guard response
- **arrestPlayer()** - Arrests player and switches to jail phase
- **payBounty()** - Pay bounty + 50% fine to clear crimes
- **serveJailTime()** - Fast-forward time and release player
- **attemptJailEscape()** - DEX-based escape chance (risky)
- **changeFactionRep(factionId, amount)** - Modify faction reputation
- **joinFaction(factionId)** - Join faction with requirements check
- **getFactionBenefits()** - Get bonuses from joined factions
- **getKarmaLevel(karma)** - Get karma level info
- **getReputationLevel(rep)** - Get reputation level info

### 4. Save/Load Migration
- Added karma/crime fields to save data
- Added faction reputation to save data
- Added migration for old saves without these fields

## 🔧 STILL NEEDS IMPLEMENTATION

### 1. UI Components Needed
- [ ] **Jail Phase UI** - Options to pay bounty, serve time, or escape
- [ ] **Karma Display** - Show karma level in character screen
- [ ] **Faction Menu** - View/join factions, see reputation
- [ ] **Attack Civilian Option** - Add to town interaction menu
- [ ] **Bounty Display** - Show active bounty in UI
- [ ] **Crime Log** - View committed crimes

### 2. Combat Integration
- [ ] **Attack Civilian Combat** - Generate civilian enemy, commit crime on kill
- [ ] **Guard Spawn System** - Guards appear when bounty is high
- [ ] **Guard Combat** - Special guard enemies with arrest mechanics

### 3. Faction Benefits Integration
- [ ] Apply faction benefits to:
  - Crafting (craftingBonus, craftingSpeedBonus)
  - Shopping (shopDiscount, sellBonus)
  - Combat (combatXPBonus, critDamageBonus, spellDamageBonus)
  - Lockpicking (lockpickBonus)
  - Travel (travelCostReduction)
  - Quests (questRewardBonus)

### 4. Guard AI System
- [ ] **Guard Patrols** - NPCs that patrol towns
- [ ] **Arrest Mechanics** - Guards chase and arrest player
- [ ] **Combat Guards** - Player can fight guards (very risky)

### 5. Faction-Specific Content
- [ ] **Faction Quests** - Unique quests for each faction
- [ ] **Faction Vendors** - Special shops for members
- [ ] **Faction Hideouts** - Locations for crime organizations
- [ ] **Faction Conflicts** - Reputation with one affects others

## 📋 NEXT STEPS TO COMPLETE

### Priority 1: Basic UI (2-3 hours)
1. Add "Attack Civilian" button in town menu
2. Create jail phase UI with 3 options
3. Add karma/bounty display to character sheet
4. Add faction list UI

### Priority 2: Combat Integration (1-2 hours)
1. Create civilian enemy type
2. Hook up attack civilian to combat
3. Auto-commit crime on civilian death
4. Add guard spawn on high bounty

### Priority 3: Faction Benefits (1 hour)
1. Apply shop discounts from merchant guild
2. Apply combat bonuses from guilds
3. Apply crafting bonuses

### Priority 4: Advanced Features (4-6 hours)
1. Faction quest system
2. Faction vendors
3. Guard patrol and arrest mechanics
4. Faction hideout locations

## 🎮 HOW TO USE (Once Complete)

### Karma System
- **Good Actions**: Complete quests, help NPCs, donate to temples (+karma)
- **Bad Actions**: Attack civilians, steal, murder (-karma)
- **Consequences**: Guards arrest you at karma < -25 or bounty > 50

### Crime System
1. Attack civilian → Lose karma, gain bounty
2. Guards spot you (chance based on bounty)
3. Arrested → Three options:
   - Pay bounty × 1.5
   - Serve jail time (lose days)
   - Escape (DEX check, doubles bounty if caught)

### Faction System
1. Join factions by meeting requirements
2. Gain reputation through actions
3. Unlock benefits as rep increases
4. Some factions are mutually exclusive (lawful vs criminal)

## 🐛 TESTING CHECKLIST
- [ ] Commit crime and verify karma/bounty changes
- [ ] Get arrested and test all 3 jail options
- [ ] Join faction and verify benefits applied
- [ ] Attack civilian and survive guard response
- [ ] Escape jail successfully
- [ ] Reach Exalted status with a faction
- [ ] Verify save/load preserves karma and factions

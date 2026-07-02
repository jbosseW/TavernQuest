--[[
    Lore Books System
    Ancient texts, racial traditions, and fragments from across the world

    Includes: Vel'sharath covenant fragments (Calidar wastelands)
              Dwarven guild texts, Goblin resistance writings,
              Orcish legal codes, Gnomish technical documents,
              Elven archives, Beast Folk oral traditions,
              Lizard Folk sect records, Human/Dominion documents
]]

local LoreBooks = {}

-- Discovery locations across the world
LoreBooks.LOCATIONS = {
    -- Calidar Wasteland locations
    GLASSED_RUINS = "glassed_ruins",           -- Surface ruins in the glass desert
    BURIED_ARCHIVE = "buried_archive",          -- Underground elven archive
    COVENANT_SANCTUM = "covenant_sanctum",      -- The ritual site itself
    VITRIFIED_TOWER = "vitrified_tower",        -- Melted wizard tower
    CALIDAR_CATACOMBS = "calidar_catacombs",    -- Tunnels beneath the wastes
    SCORCHED_TEMPLE = "scorched_temple",        -- Ruined temple to the old gods
    MEMORY_WELL = "memory_well",                -- Psychic residue collection point

    -- Elven locations
    ELVEN_ARCHIVE = "elven_archive",            -- Sealed section of elven town library
    ELVEN_DISTRICT = "elven_district",          -- Elven administrative districts in cities
    ELVEN_GARDEN = "elven_garden",              -- Private elven memorial gardens

    -- Dwarven locations
    DWARVEN_HOLD = "dwarven_hold",              -- Inside dwarven mountain holds
    DWARVEN_TRADE_POST = "dwarven_trade_post",  -- Surface-facing trade outposts
    SEALED_PASSAGE = "sealed_passage",          -- Near sealed Deep Dwarf passages

    -- Goblin locations
    GOBLIN_WARREN = "goblin_warren",            -- Active or ruined goblin warrens
    ABANDONED_MINE = "abandoned_mine",          -- Mines the empire "cleared"
    GOBLIN_TUNNEL = "goblin_tunnel",            -- Hidden resistance tunnels

    -- Orc locations
    ORC_CAMP = "orc_camp",                      -- Nomadic clan encampments
    ORC_STEPPE = "orc_steppe",                  -- Open steppe burial sites and cairns
    ORC_RUINS = "orc_ruins",                    -- Ruins of pre-fragmentation settlements

    -- Gnomish locations
    GNOMISH_WORKSHOP = "gnomish_workshop",      -- Rare mainland gnome workshops
    GNOMISH_TRADE_PORT = "gnomish_trade_port",  -- Port-side gnomish trade offices
    GNOMISH_ISLES = "gnomish_isles",            -- The isles themselves (late game)

    -- Beast Folk locations
    CARAVAN_CAMP = "caravan_camp",              -- Cat folk caravan stops
    GAMBLING_DEN = "gambling_den",              -- City gambling establishments

    -- Lizard Folk locations
    DESERT_RUIN = "desert_ruin",                -- Hidden desert ruins
    HIDDEN_RIVER = "hidden_river",              -- Underground river access points
    SHADOW_FEN = "shadow_fen",                  -- The Shadow Fen commune

    -- Human / Dominion locations
    HOLY_CITY = "holy_city",                    -- The imperial capital
    GRAND_CATHEDRAL = "grand_cathedral",        -- Helios worship center
    INQUEST_OFFICE = "inquest_office",          -- Luminary Inquest field offices
    IMPERIAL_GARRISON = "imperial_garrison",    -- Military outposts
}

-- THE TRUTH ABOUT THE VEL'SHARATH
-- The empire calls them "The Void Covenant" -- a nihilistic cult
-- that tried to end reality. This is the COVER STORY.
-- The Vel'sharath were scholars searching for the gods -- devout seekers
-- who uncovered a divine artifact and, through using it, discovered truths
-- the empire could not allow to exist. The empire destroyed Calidar to bury it all.
-- The fragments gradually reveal the real story beneath the propaganda.

-- The order
LoreBooks.CULT = {
    name = "The Vel'sharath",
    translation = "Those Who Seek the Light (imperial mistranslation: 'The Void Covenant')",
    symbol = "The Open Eye - an eye gazing upward toward absent heavens",
    phrase = "The silence of the gods is not peace. It is a wound.",
    founder = "Cael'vorith the Seeker",
}

--[[
    ANCIENT TEXTS
    7 primary texts + 1 assembled codex
    All found in Calidar wastelands dungeons
]]
LoreBooks.BOOKS = {
    --===========================================
    -- FRAGMENT 1: Academic Research
    --===========================================
    {
        id = "covenant_fragment_1",
        title = "Fragmentary Studies on the Vel'sharath Phenomenon",
        author = "Magister Aldric Morthain",
        category = "covenant",
        rarity = "uncommon",
        condition = "Water-damaged, pages stuck together",
        findLocation = LoreBooks.LOCATIONS.BURIED_ARCHIVE,
        dungeonFloor = 2,

        content = [[
I have spent fourteen years piecing together references to
a group the pre-war elvish sources call the Vel'sharath.
Imperial records translate this as "The Void Covenant" or
"The Hollow Circle," but I have consulted three independent
scholars of Old Elvish, and all agree the literal meaning
is closer to "Those Who Seek the Light" or perhaps "Those
Who Call Toward Radiance."

The discrepancy is troubling. Why would the empire
mistranslate a name so fundamentally?

They were not, as imperial doctrine insists, summoners of
void entities or practitioners of nihilist philosophy.
Their surviving writings reveal something unexpected:
researchers. Systematic, methodical, and deeply devout.

The Vel'sharath conducted what they called "resonance
studies," attempts to measure the presence of divine
power in the world. Their methodology was rigorous.
They catalogued prayer response rates across seventeen
temples over a period of two centuries. They mapped
fluctuations in divine healing efficacy. They measured
the dimming of sacred sites.

Their central finding, repeated across hundreds of
independent observations:

    "The resonance fades. Where once the divine
    answered, now there is silence. The temples
    still stand. The prayers still rise. But
    nothing answers. Nothing has answered for
    a very long time."

The implications are staggering. If their data was
accurate, the Vel'sharath were not heretics conjuring
darkness. They were scientists documenting an absence
so vast that acknowledging it would reshape theology
across the known world.

I must consider the possibility that the empire had
reasons beyond public safety to destroy these records.

I have discontinued my research. Not because of what
I found, but because of who has begun asking about
my work.

                    - Final entry, undated
]],

        discoveredText = "A scholar's research journal. The final pages contain hurried notes about being followed.",
        partOfCodex = true,
        codexOrder = 1,
    },

    --===========================================
    -- FRAGMENT 2: Vel'sharath Member's Journal
    --===========================================
    {
        id = "covenant_fragment_2",
        title = "Personal Journal of Sister Vel'thara",
        author = "Sister Vel'thara of the Vel'sharath",
        category = "covenant",
        rarity = "rare",
        condition = "Singed at edges, tear-stained",
        findLocation = LoreBooks.LOCATIONS.COVENANT_SANCTUM,
        dungeonFloor = 3,

        content = [[
Day 1 of the Convocation:
Master Cael'vorith has called us together. Forty-seven
scholars, priests, and mystics from across Calidar. He
says the silence from the heavens has gone on too long.
Our prayers rise and rise and nothing answers. We must
seek the gods directly. We must reach them.

Day 34:
Cael'vorith's expedition into the deep ruins beneath
Mount Ilvareth has returned. They found something
extraordinary: buried in a sealed chamber older than
any elven construction, an artifact of clearly divine
origin. A focusing instrument, small, barely the size
of a wagon wheel, but when tested it amplifies spiritual
resonance a thousandfold. We call it the Lesser Lens. It is not of mortal make. The materials, the geometry,
the resonance patterns are beyond anything we can
reproduce. We believe it was left here. By whom, and
for what purpose, we intend to discover.

Day 89:
First activation of the Lesser Lens. We aimed it upward,
toward the heavens, and spoke the Reaching Prayer. The
resonance was extraordinary, like singing into a
cathedral and hearing the echo of every voice that ever
sang there before you.

But no answer came. Only echoes. Ancient echoes. The
residue of prayers answered long, long ago. This was
our first terrible confirmation: the silence is not
indifference. It is ABSENCE. The gods are not listening
because the gods are not there.

Day 142:
We have redirected the Lens. If the gods are not above,
perhaps they are elsewhere. We are mapping the spiritual
topology of creation itself, searching for any trace,
any thread that might lead us to where they went.

Day 203:
Cael'vorith wept today. Through the Lens, he found
something. Not the gods. Something else. Something
BENEATH the Holy City. A presence, divine in nature
but chained. Diminished. Being slowly drained.

He says it is Helios.

Not a god. A demi-god. Imprisoned beneath the earth.
His power siphoned to fuel an empire that claims his
blessing.

The prayers of a billion souls, rising toward a being
who cannot answer because he is in chains.

Day 204:
If this is true, everything changes. Everything the
empire has built is founded on a lie. Helios does not
rule from heaven. He suffers beneath the Holy City.

We must find the true gods. We must bring them back.
Only they can set this right.

Day 211:
The empire knows we are here. Cael'vorith says it does
not matter. Our work is nearly complete. The Lens has
found traces. Faint paths leading outward, beyond the
edges of the world. The gods did not die. They LEFT.

But why?

I pray we find the answer before the empire finds us.

                    - No further entries
]],

        discoveredText = "A member's journal. The author writes with desperate hope, not madness.",
        partOfCodex = true,
        codexOrder = 2,
    },

    --===========================================
    -- FRAGMENT 3: Soldier's Testimony
    --===========================================
    {
        id = "covenant_fragment_3",
        title = "Sworn Testimony of Sergeant Aldous Kern",
        author = "Sergeant Aldous Kern, 14th Imperial Legion",
        category = "covenant",
        rarity = "rare",
        condition = "Blood-stained, official seal partially melted",
        findLocation = LoreBooks.LOCATIONS.GLASSED_RUINS,
        dungeonFloor = 1,

        content = [[
SWORN TESTIMONY - CLASSIFIED BY ORDER OF THE LUMINARY INQUEST
FOR SEALED ARCHIVES ONLY - POSSESSION IS A CAPITAL OFFENSE

I, Sergeant Aldous Kern of the Fourteenth Imperial Legion,
do hereby swear that the following account is true:

We were stationed at the edge of Calidar. Our orders said
we were containing a "void incursion." We were told the
elves had opened a gate to nothingness itself. That reality
would unravel if we did not act.

I believed it. Every man in the Fourteenth believed it.

We marched in expecting monsters. Demons. The end of the
world.

What I saw was a circle of elves in white robes, kneeling
around a device that looked like a lens or a mirror, aimed
at the sky. They were praying. Not chanting in some dark
tongue. PRAYING. Hands raised upward. Tears on their
faces. Some of them were singing. It was the most beautiful
sound I have ever heard.

They were reaching UPWARD, not downward.

I reported this to Captain Vasek. He told me to keep my
mouth shut. The orders were already given. Heaven's Atlas
was being prepared. Nothing could stop what was coming.

I asked him: "Sir, are we certain these people are the
enemy?"

He looked at me with something I had never seen on his face
before. Fear. Not of the elves. Of something else entirely.

"The orders come from the Holy City itself, Kern. From the
Cathedral. They say reality is at stake."

Then Heaven's Atlas activated.

The light. Gods forgive me, the light. Everything within
fifty miles became glass and ash and silence. The elves did
not scream. They did not run. They kept praying until the
light took them. Some of them were SMILING.

I survived only because I had retreated beyond the
perimeter.

The official record says we destroyed a void cult that
would have ended reality. That the elves were opening a
gate to oblivion. That we saved the world.

But I was there. I saw their faces. I heard them singing.

Those were not the faces of people trying to end the world.
Those were the faces of people trying to save it.

I do not know what the Vel'sharath found that frightened
the empire so badly. I only know that we burned an entire
civilization alive for it.

And that the screaming I hear at night is not theirs.
It is my own.

                    - Testimony sealed by Inquisitor Varn
                      Classification: ABSOLUTE
                      [Note: Sgt. Kern died in custody.
                       Cause of death: "natural causes."]
]],

        discoveredText = "An imperial soldier's account, marked with seals that should have kept it buried forever.",
        partOfCodex = true,
        codexOrder = 3,
    },

    --===========================================
    -- FRAGMENT 4: Oracle's Vision
    --===========================================
    {
        id = "covenant_fragment_4",
        title = "The Book of Burning Sight",
        author = "Vel'aneth, Seer of the Vel'sharath",
        category = "covenant",
        rarity = "epic",
        condition = "Pristine but warm to the touch, as if sunlit from within",
        findLocation = LoreBooks.LOCATIONS.SCORCHED_TEMPLE,
        dungeonFloor = 2,

        content = [[
I RECORD WHAT THE LESSER LENS SHOWED ME.
THESE ARE NOT PROPHECIES. THESE ARE OBSERVATIONS
OF THINGS THAT ARE, SEEN THROUGH DIVINE FOCUS.

THE FIRST SEEING: THE EMPTY THRONES.

I looked upward through the Lens and saw the place
where the gods once sat. Seven thrones carved from
light itself, arranged in a circle above the world.
Every throne was empty. Dust lay upon seats that had
not been occupied for ages beyond counting.

The gods did not fall. They did not die.
They DEPARTED. Willingly. As if called away.
As if something greater than godhood summoned them.

THE SECOND SEEING: THE PRISONER BENEATH.

I looked downward, toward the roots of the Holy City,
and saw a figure chained in golden light. A being of
fire and radiance, diminished, flickering, barely
alive. Helios. Not a god enthroned in heaven but a
demi-god imprisoned in earth. Tubes of crystallized
prayer ran from his body into the foundations of the
Cathedral above. His power drained. His voice silenced.
His suffering used to light an empire that worships
his name while feeding on his flesh.

He opened his eyes. He saw me seeing him.

The grief in those eyes will never leave me.

THE THIRD SEEING: THE ATLAS.

I saw Heaven's Atlas as it truly is. Not a weapon
built by mortal hands. A divine instrument, shaped by
the gods themselves before their departure. A
cartographer's tool for mapping the architecture of
reality: space, time, the boundaries between worlds.
In the hands of the gods, it was a lens for
understanding creation.

In the hands of mortals, it is a cannon aimed at the
world.

THE WARNING:

Those who seek the truth will be destroyed by those
who profit from the lie. The empire cannot allow these
truths to surface. If it is known that Helios suffers
rather than reigns, the faithful will rebel. If it is
known that the Atlas is stolen divinity, the mandate
crumbles. If it is known that the gods are gone and
no one watches over this world --

We will be silenced. I have seen this too. Fire from
the sky. Glass where forests stood. An entire people
erased to protect a fiction.

But the truth does not burn. Scatter these words. Hide
them in stone and silence. Someone will find them.
Someone will understand.

The gods are gone. But perhaps not forever.

                    - Vel'aneth, Last Seer of Calidar
                      Written in the final days
]],

        discoveredText = "A seer's recorded visions. The pages radiate faint warmth, as if remembering a distant fire.",
        partOfCodex = true,
        codexOrder = 4,
    },

    --===========================================
    -- FRAGMENT 5: Elven Confession
    --===========================================
    {
        id = "covenant_fragment_5",
        title = "A Confession Carved in Stone",
        author = "Selendriel the Sorrowful",
        category = "covenant",
        rarity = "epic",
        condition = "Stone tablet, cracked but legible",
        findLocation = LoreBooks.LOCATIONS.ELVEN_ARCHIVE,  -- Only book outside Calidar wastes
        dungeonFloor = nil, -- Found in elven town sealed archive, not dungeon
        townLocation = "elven_anchor_town", -- Requires special access/quest

        content = [[
I AM SELENDRIEL, ONCE CALLED THE WISE.

I write this confession in stone, for paper burns and
memory fades, and what I have to say must endure longer
than empires.

I knew the Vel'sharath. I studied alongside Cael'vorith
in the years before he founded the order. I read his
early research: the prayer-response studies, the
resonance measurements, the mapping of divine absence.

I knew they were right.

The evidence was overwhelming. Prayers unanswered for
centuries. Sacred sites dimming year by year. Healing
magic growing weaker with each generation. The gods
were gone. They had been gone for longer than anyone
wanted to admit. And Helios, poor, broken Helios,
was not a god sitting in judgment. He was a prisoner
sitting in chains.

I knew the Vel'sharath were seeking the gods, not
summoning the void. I knew their Lesser Lens was a
prayer amplifier, not a weapon. I knew their research
was the most important theological discovery in the
history of the world.

I said nothing.

I told myself it was prudence. That the empire would
listen to reason. That the truth would emerge on its
own. That it was not my place to risk everything for
scholars who had already risked everything themselves.

The truth: I was afraid.

When the sky turned white over Calidar, I was three
hundred miles away. I felt the ground shake. I saw the
light on the horizon. And I knew, before the reports
came, before the refugee columns formed, before the
empire declared its glorious victory over the "Void
Covenant," I knew that an entire civilization had
been murdered to protect a lie I had been too cowardly
to challenge.

Five hundred years of silence. Five hundred years of
watching the empire tell the world that the Vel'sharath
were nihilists, void-worshippers, reality-enders. Five
hundred years of hearing the story repeated until even
elves began to believe it.

I knew they were seeking the gods, not summoning the
void. I said nothing.

The empire destroyed Calidar to bury the truth about
Helios. To protect its claim to divine mandate. To
ensure no one ever learned that Heaven's Atlas is a
stolen god-tool and the entire theological foundation
of human civilization is built on the suffering of a
chained demi-god.

And every day I choose silence again. Because speaking
now would mean admitting I could have spoken then. And
if I had spoken then, perhaps Calidar would still
stand. Perhaps my people would still have a home.

To whoever reads this after I am gone:

The Vel'sharath were not what the empire says they
were. They were the bravest of us. They sought the
gods when everyone else accepted the silence.

Find what they were looking for.
The gods are missing.
Someone should be looking for them still.

                    - Selendriel the Sorrowful
                      Last of the Witnesses
                      Year 500 After the Burning
]],

        discoveredText = "A stone tablet bearing an elven confession. Five centuries of guilt are carved into every letter.",
        partOfCodex = true,
        codexOrder = 5,
    },

    --===========================================
    -- FRAGMENT 6: Ritual Text (The Reaching)
    --===========================================
    {
        id = "covenant_fragment_6",
        title = "The Rite of Reaching (Activation Sequence for the Lesser Lens)",
        author = "Unknown (Vel'sharath Ritual Scholars)",
        category = "covenant",
        rarity = "legendary",
        condition = "Partially destroyed, edges glow faintly in darkness",
        findLocation = LoreBooks.LOCATIONS.COVENANT_SANCTUM,
        dungeonFloor = 4,

        content = [[
[ARCHIVIST'S NOTE: This document is incomplete.
Approximately 60% of the original text was destroyed
when Calidar was glassed. The surviving portions
describe what appears to be an activation ritual for
a divine-resonance focusing device.

Five scholars have studied these fragments:
  - Two experienced profound, lasting grief
  - One abandoned academic life and became a hermit
  - One reported "hearing the silence between stars"
  - One continues her research (current status: missing)

Note: Unlike forbidden texts which cause madness or
corruption, exposure to this document produces only
an overwhelming sense of ABSENCE, as if the reader
becomes briefly aware of something that should exist
but does not. Handle with care.]

...the Lens must be aligned under open sky, with no
roof between the instrument and the heavens...

...thirteen practitioners minimum form the Resonance
Circle, though twenty-one produces a cleaner signal...

...the words are not commands but INVITATIONS. One
must speak as a child calling a parent home, with
longing, not with authority...

[SECTION DESTROYED]

...when the Lens focuses, do not shield your eyes.
The light you see is not dangerous. It is the residual
warmth of prayers offered across millennia, gathered
and concentrated. To see it is to see the memory of
every soul that ever looked upward and asked "Are you
there?"...

...the Reaching requires an anchor, something sacred,
something that still carries a trace of genuine divine
contact. Pre-war temple stones work best. The older,
the stronger the resonance...

[SECTION DESTROYED]

...if the Reaching finds nothing, the practitioners
will weep. Let them. Grief is the appropriate response
to confirmed divine absence. The tears are holy.
Do not suppress them.

In the silence of the gods, our sorrow is the loudest
prayer.

[SECTION DESTROYED]

...and when the signal travels outward, you will not
hear words in return. You will hear something beneath
words. The hum of creation remembering its makers. The
resonance of a world that was shaped by hands now
absent.

Listen to that hum.
It is the sound of the gods' fingerprints on reality.
They were here. They were HERE.

Follow the resonance. Follow it outward.
Find where it leads.

Bring them home.

[REMAINING PAGES DESTROYED IN THE GLASSING]
]],

        discoveredText = "Fragments of a ritual text. The margins contain notes in multiple hands, all expressing the same word: 'grief.'",
        partOfCodex = true,
        codexOrder = 6,
        dangerous = true, -- Flag for special handling
    },

    --===========================================
    -- FRAGMENT 7: Post-Destruction Investigation
    --===========================================
    {
        id = "covenant_fragment_7",
        title = "Classified Field Report: Calidar Incident Site Analysis",
        author = "Dr. Venatrix Coldwell, Imperial Arcane Research Division",
        category = "covenant",
        rarity = "rare",
        condition = "Multiple pages from different sources, bound together with trembling hands",
        findLocation = LoreBooks.LOCATIONS.MEMORY_WELL,
        dungeonFloor = 2,

        content = [[
CLASSIFIED - EYES ONLY - ARCANE RESEARCH DIVISION
UNAUTHORIZED POSSESSION: EXECUTION WITHOUT TRIAL

EXPEDITION 12, YEAR 89 AFTER GLASSING:
Initial survey of the Vel'sharath research site, now
vitrified. Glass formations at the epicenter show
unusual properties. Under magnification, the crystal
structures contain preserved energy signatures.

Expected finding (per official briefing): Void energy.
Dimensional breach residue. Evidence of trans-reality
gateway consistent with the "Void Covenant" narrative.

Actual finding: NONE OF THE ABOVE.

The energy signatures are uniformly positive-resonance.
Divine-adjacent. Consistent with concentrated prayer
amplification, not dimensional breach. There is no void
energy here. There never was.

EXPEDITION 34, YEAR 156:
We found the remains of the device, the so-called
"weapon" the Vel'sharath allegedly used to open a void
gate. It is a lens. A FOCUSING LENS. Its design is
consistent with principles found in divine artifacts,
scaled down dramatically. It did not open anything. It
PROJECTED. Outward. Upward.

This was not a gate. It was a beacon.

EXPEDITION 67, YEAR 289:
Cross-referenced the energy signatures from the site
with classified imperial records of Heaven's Atlas.

I should not have done this.

The signatures match. The Lesser Lens and Heaven's
Atlas share fundamental design principles. They are
built on the same architecture. The same impossible,
non-mortal architecture.

If the Lesser Lens is a divine artifact in miniature,
then Heaven's Atlas is a divine artifact at full scale.
Neither was built by mortal hands. The empire did not
CREATE Heaven's Atlas. They FOUND it. Or took it.

EXPEDITION 91, YEAR 412 [CURRENT]:
I have made a terrible discovery.

The so-called "dimensional breach" detected before
Calidar's destruction was not a void gate. I have
reconstructed the energy profile from residual
signatures in the glass.

It was a COMMUNICATION CHANNEL. Directed outward,
beyond the boundaries of the known world. The
Vel'sharath were not opening a door to let something
in. They were sending a signal OUT. A call. A prayer
amplified to cross distances that prayers alone cannot
reach.

They were calling someone. Something divine. Something
that was supposed to be here and is not.

The official narrative is fabricated. Every word of it.
The Vel'sharath were not void cultists. They were
researchers who discovered something the empire could
not allow to be known.

I am hiding these findings. I will not submit this
report. The three researchers before me who submitted
honest analyses are dead. The empire does not want the
truth about what happened at Calidar. The empire does
not want anyone asking what the Vel'sharath found.

The question they were asking, "where did the gods
go?", is apparently a question worth killing for.

I am burying these notes in the Memory Well. If you
find them, you will understand why I disappeared.

Do not trust the official history.
The Vel'sharath were right.
The gods are missing.
And the empire burned a civilization to keep us from
finding out.

                    - Dr. Venatrix Coldwell
                      Final Entry (status: missing)
]],

        discoveredText = "Compiled research notes spanning centuries. The final author's conclusions contradict everything the empire has ever claimed.",
        partOfCodex = true,
        codexOrder = 7,
    },

    --===========================================
    -- THE COMPLETE CODEX (Assembled from fragments)
    --===========================================
    {
        id = "covenant_codex",
        title = "The Complete Chronicle of the Vel'sharath",
        author = "Assembled from fragments",
        category = "covenant",
        rarity = "mythic",
        condition = "Reconstructed - the truth, fully assembled at last",
        findLocation = "assembled", -- Not found, created when all fragments collected

        assembledFrom = {
            "covenant_fragment_1",
            "covenant_fragment_2",
            "covenant_fragment_3",
            "covenant_fragment_4",
            "covenant_fragment_5",
            "covenant_fragment_6",
            "covenant_fragment_7",
        },

        content = [[
THE COMPLETE CHRONICLE OF THE VEL'SHARATH
Assembled from fragments recovered across five centuries
of suppression, destruction, and silence.

===============================================

WHAT THE WORLD BELIEVES

Five hundred years ago, an elven cult called the
Vel'sharath, "The Void Covenant," attempted to
open a gateway to oblivion that would have unmade
reality itself. The Holy Empire, acting on divine
mandate from Helios, deployed Heaven's Atlas to
destroy the elven homeland of Calidar and close the
gate. Millions died, but reality was saved.

This is the story taught in every school, preached
in every temple, recorded in every imperial archive.

Every word of it is a lie.

===============================================

WHAT THE VEL'SHARATH ACTUALLY WERE

The name "Vel'sharath" translates from Old Elvish as
"Those Who Seek the Light." The imperial translation
("Void Covenant" or "Hollow Circle") is a
deliberate fabrication, part of the cover story
constructed after Calidar's destruction.

The Vel'sharath were an elven scholarly order:
priests, researchers, mystics, and theologians.
Founded by Cael'vorith the Seeker approximately six
centuries before present day, they began as devout
seekers, driven not by doubt but by longing. They
wanted to reach the gods. To commune with the divine
directly. To hear the voice behind the silence of
prayer.

They studied divine resonance for two centuries,
measuring prayer responses across seventeen temples,
tracking fluctuations in divine healing, mapping the
sacred sites. They were not looking for absence --
they were looking for presence. A way through.

Then they uncovered the Lesser Lens in ruins beneath
Mount Ilvareth, a divine artifact of non-mortal
origin. When they activated it, seeking the gods,
the truth hit them like a hammer:

THE GODS ARE MISSING.

Not dead. Not sleeping. Not testing the faithful.
GONE. The Vel'sharath had gone searching for the
divine and found only its absence. The thrones of
heaven sit empty. The prayers of billions rise into
silence.

They had not set out to prove the gods were gone.
They set out to find them. And found nothing.

===============================================

WHAT THEY DISCOVERED ABOUT HELIOS

Helios, the Sun God, foundation of the Holy
Dominion's theological authority, is not a true god.

He is a demi-god. A lesser divine being, powerful
but not omnipotent. And he is not enthroned in heaven
blessing the faithful.

He is IMPRISONED beneath the Holy City.

Chained in the foundations of the Grand Cathedral,
Helios has been drained for centuries. His divine
essence is siphoned to fuel the empire's holy magic,
to power its priests, to sustain the illusion of
divine mandate. The prayers that rise from a billion
throats reach a being who cannot answer, not
because he chooses silence, but because he is in
chains.

The entire theological foundation of the Holy
Dominion is built on the suffering of a captive
demi-god.

===============================================

WHAT THEY DISCOVERED ABOUT HEAVEN'S ATLAS

Heaven's Atlas was not built by mortal hands. It is
a divine artifact, a tool created by the true gods
before their departure. Its original purpose was
cartographic: mapping the architecture of reality
itself, charting space, time, and the boundaries
between worlds.

In the hands of its makers, it was an instrument of
understanding. In the hands of mortals who do not
comprehend its true nature, it is a weapon of
annihilation capable of erasing civilizations.

The empire did not create Heaven's Atlas. They found
it. Or stole it.

===============================================

THE LESSER LENS

The Vel'sharath uncovered, in sealed ruins beneath
Mount Ilvareth, a smaller artifact operating on the
same divine principles as Heaven's Atlas. They called
it the Lesser Lens.

Where Heaven's Atlas maps reality, the Lesser Lens
focuses spiritual resonance. It amplifies prayer,
concentrating the combined devotion of dozens of
practitioners into a signal powerful enough to reach
across distances that ordinary prayer cannot cross.

The Vel'sharath were using the Lesser Lens to do
what no one had attempted in recorded history:

CALL THE GODS HOME.

Their ritual, the Rite of Reaching, was not an
invocation of darkness. It was a prayer so
concentrated, so desperate, so pure that it could
cross the gulf between worlds.

They were trying to save everything.

===============================================

WHY THE EMPIRE DESTROYED CALIDAR

When the Holy Dominion discovered what the Vel'sharath
were doing, they recognized the threat immediately.
But the threat was not cosmic. It was POLITICAL.

If the Vel'sharath contacted the gods, or even
published their findings:

- The truth about Helios would be exposed. A chained,
  suffering demi-god does not grant divine mandates.
- The nature of Heaven's Atlas would be revealed. The
  empire's ultimate weapon is a stolen god-tool.
- The absence of the true gods would become known.
  Every prayer has been directed at empty thrones.

The Vel'sharath's research threatened to unravel
EVERYTHING the Holy Dominion was built on.

So the empire activated Heaven's Atlas.

The activation drained ninety-five percent of Helios's
remaining life force. The captive demi-god was nearly
killed to fuel the weapon that destroyed the people
trying to free him.

Calidar was obliterated. Every elf, every record,
every piece of the Vel'sharath's research, the Lesser
Lens, the proof... all of it turned to glass and ash.

Then the empire wrote the history:

"A dangerous cult was opening a gate to the Void that
would have destroyed reality. We saved the world."

And the world believed them.

===============================================

THE WITNESSES

A soldier named Aldous Kern saw the truth. He
testified that the Vel'sharath were praying, not
summoning darkness. He died in imperial custody.
Natural causes, they said.

An elf named Selendriel knew the truth. She had
studied alongside Cael'vorith. She said nothing for
five hundred years. She carved her confession in
stone because paper burns and empires rewrite what
they please.

A researcher named Venatrix Coldwell found the truth.
She confirmed: no void energy at the site. Only
amplified prayer directed outward, toward absent gods.
She hid her findings and disappeared.

The empire silenced them all. But stone endures. And
glass preserves what fire cannot destroy.

===============================================

THE QUESTIONS THAT REMAIN

WHERE DID THE GODS GO?
The thrones of heaven are empty. The true gods
departed in an age beyond memory. Why? The
Vel'sharath traced faint paths leading outward,
beyond the edges of reality. The gods went SOMEWHERE.
No one has followed.

WHAT HAPPENS TO HELIOS?
The captive demi-god has been drained for centuries.
The activation of Heaven's Atlas consumed nearly all
of his remaining essence. Is he still alive? What
happens when his light goes out?

WHAT IS HEAVEN'S ATLAS, TRULY?
A divine cartographic instrument stolen by mortals
and used as a weapon. What would it reveal if used
as the gods intended? Could it find them?

WHAT DID THE VEL'SHARATH ALMOST REACH?
In their final moments, the Vel'sharath sent their
signal outward. Did anything receive it? Did something
hear the call before the fire came?

And if so... is something coming back?

===============================================

The empire built its order on a foundation of lies:
a captive god, a stolen weapon, and the ashes of
those who dared to seek the truth.

But truth does not burn. It vitrifies. It is
preserved in glass, in stone, in the memories of
those old enough to remember.

The Vel'sharath, Those Who Seek the Light, are
gone. Their order is ash. Their homeland is glass.

But their question echoes still, in the silence
between prayers, in the emptiness above the altars:

Where are the gods?

And what becomes of us, alone in a world they
abandoned, ruled by those who profit from their
absence?

===============================================

Remember the Vel'sharath.
Remember what they sought.
Remember what was done to silence them.

And if you have the courage they had --

Look up.

The heavens are empty.
But perhaps not forever.
]],

        discoveredText = "The complete truth about Calidar's destruction, the Vel'sharath, and the lies that built an empire. The weight of this knowledge changes everything.",
        unlocksEnding = "moral_choice",
    },

    --===========================================================================
    --===========================================================================
    --
    --  RACIAL TRADITION BOOKS
    --  Books from every culture across the known world
    --
    --===========================================================================
    --===========================================================================

    --===========================================
    -- DWARVEN BOOKS
    -- Voice: Collective, functional, no individual authors
    -- Themes: Stone, labor, guild identity, isolationism
    --===========================================

    {
        id = "dwf_tome_01",
        title = "Principles of Stone and Purpose",
        author = "Unknown (Stonecutters Guild, Collective Authorship)",
        description = "A guild manual on stone-working philosophy, issued to all newly emerged dwarves upon joining the Stonecutters rotation.",
        category = "dwarven",
        rarity = "uncommon",
        condition = "Well-worn from generations of use, stone-dust in the binding",
        findLocation = LoreBooks.LOCATIONS.DWARVEN_TRADE_POST,
        faction = "dwarven_holds",
        location_hint = "Found at dwarven trade posts or within the outer halls of the Free Holds.",

        content = [[
STONECUTTERS GUILD - MANUAL OF PRINCIPLES
Issued to all guild members upon first rotation assignment.

ON THE NATURE OF STONE:

Stone does not lie. It does not flatter. It does not
promise what it cannot deliver. When you strike a chisel
into granite, the stone answers honestly. It splits where
it is weak. It holds where it is strong. There is no
deception in this. There is no politics.

This is why we work stone. This is why stone is truth.

A dwarf who understands stone understands themselves.
Your hands are tools. Your labor is purpose. What you
build with those hands is your contribution to the hold,
and your contribution is the only measure of your worth
that matters.

ON THE MEANING OF LABOR:

We do not carve for beauty, though beauty comes. We do
not build for glory, though the halls endure. We carve
because the hold needs corridors. We build because the
hold needs chambers. Need is the only honest patron.

The surface peoples carve statues of their kings. They
build monuments to individual ambition. We find this
bewildering. A corridor that carries water to the lower
chambers is more worthy than a thousand statues. It
serves. It functions. It contributes.

Ask not: "What does this honor?"
Ask instead: "What does this DO?"

ON IDENTITY:

You emerged from the sacred chambers as all dwarves do -
without parents, without lineage, without inheritance.
You are a child of the stone, equal to every other dwarf
who has ever drawn breath in these holds.

Your identity is not your name. Your identity is the
work you do. The mine shaft you maintain. The wall you
reinforce. The beam you set true. When the hold endures
another century, that endurance is your legacy. Not yours
alone - shared with every dwarf who labored beside you.

There is no higher honor than shared labor.
There is no deeper shame than idleness.

The stone waits. Your chisel is ready.
Begin.

        - Stonecutters Guild
          Rotation Cycle 4811
          "What is built matters. What is believed does not."
]],

        discoveredText = "A dwarven guild manual. The pages are thick as slate and smell of mineral dust. No author is credited.",
    },

    {
        id = "dwf_tome_02",
        title = "Sealed Record: The Severing of the Deep Passages",
        author = "Unknown (Wardens Guild, Restricted Access)",
        description = "A sealed guild record documenting the Deep Dwarven schism. One of the most closely guarded texts in the holds.",
        category = "dwarven",
        rarity = "rare",
        condition = "Iron-bound cover, wax seals unbroken until now",
        findLocation = LoreBooks.LOCATIONS.SEALED_PASSAGE,
        faction = "dwarven_holds",
        location_hint = "Found near sealed passages deep within the dwarven holds. Requires significant trust or stealth.",

        content = [[
WARDENS GUILD - RESTRICTED RECORD
ACCESS: SENIOR WARDENS ONLY
UNAUTHORIZED READING IS A VIOLATION OF GUILD PROTOCOL

THE SEVERING OF THE DEEP PASSAGES
Cycle 2917 of the Stone Calendar

Let what follows be recorded without judgment, for
judgment is not the Wardens' function. We guard. We
seal. We do not decide who was right.

The dispute began as all disputes begin - with a
question of labor.

The Deep Guilds argued that surface trade was
contamination. That every ingot sold to humans, every
tool exchanged for grain, every conversation held with
surface peoples weakened the purity of the collective.
They said: "We need nothing from above. The deep stone
provides. The geothermal vents warm us. The impossible
metals sustain us. Why do we compromise?"

The Surface Guilds argued that isolation meant
stagnation. That trade brought necessary materials the
holds could not produce. That awareness of the surface
world was not weakness but prudence. They said: "We do
not join them. We observe them. There is a difference."

The councils deliberated for eleven years.

No consensus was reached.

On the final day of the eleventh year, the Deep Guilds
ceased attending council. They withdrew to the lowest
levels. They carved their own chambers. They refused
all rotation assignments that brought them above the
third depth.

We offered mediation. They did not respond.

We offered compromise. They sealed their tunnels from
the inside.

The Surface Guilds made the decision that haunts us
still. We sealed our side as well. Not to punish. To
protect. If the surface peoples ever learned what lay
below - the hollow earth, the impossible metals, the
cities that dwarf our own - they would come. With
armies. With greed. With the same hunger that drove
them to destroy the elves.

The seals hold. They have held for centuries.

Sometimes, in the deepest mines, on the longest shifts,
we hear tapping from the other side. Rhythmic. Precise.
Guild-pattern tapping.

They are still there. They remember us.

We do not answer. Guild protocol forbids it.

But the wardens who guard those passages sometimes
tap back. Once. Briefly. Against protocol.

The schism is not healed. The stone remembers the
cutting. But stone is patient. Stone endures.

Perhaps, in time, so will we.

        - Wardens Guild
          Sealed by order of the Joint Council
          "This record exists. Its contents do not."
]],

        discoveredText = "An iron-bound dwarven record. The wax seals were not meant to be broken by outsider hands.",
    },

    --===========================================
    -- GOBLIN BOOKS
    -- Voice: Furious, raw, defiant, mournful
    -- Themes: Resistance, genetic memory, stolen land
    --===========================================

    {
        id = "gob_song_01",
        title = "The Old Blood Sings",
        author = "Unknown (Preserved through genetic memory)",
        description = "A resistance song-poem carried in goblin blood across uncounted generations through genetic memory. Not composed. Remembered.",
        category = "goblin",
        rarity = "rare",
        condition = "Scratched into stone with a sharpened bone. The letters are uneven but furious.",
        findLocation = LoreBooks.LOCATIONS.GOBLIN_WARREN,
        faction = "goblin_resistance",
        location_hint = "Found in active or ruined goblin warrens, scratched into walls or carved into stone floors.",

        content = [[
(Transcribed from oral recitation. This song exists in no
written tradition. Every goblin alive knows it. No goblin
was ever taught it. It surfaces in the blood at birth -
fragmented, fierce, older than language.)

THE OLD BLOOD SINGS:

Before their roads. Before their walls.
Before they gave our mountains names that were not ours.
WE WERE HERE.

The soil remembers goblin feet.
The stone remembers goblin hands.
The rivers ran for us before the invaders came
with swords and fire and the word "civilization."

They burned Thornhollow.
They drowned Deepburrow.
They sealed Shadowmire with our elders still inside.
They called this PROGRESS.

But the blood remembers.

Not words. Not stories.
Something deeper.
Something that lives in the marrow
and screams when you are born
and screams again when you come of age
and never, ever stops screaming
until you answer it.

The answer is: WE DO NOT FORGET.

The answer is: WE DO NOT FORGIVE.

The answer is: EVERY ROAD THEY BUILT
RUNS OVER GOBLIN GRAVES
AND THE GRAVES ARE NOT SILENT.

They think they won.
They think we are vermin in their walls.

But vermin do not remember.
Vermin do not carry the names of the dead
in their very blood.
Vermin do not wake at night knowing
the exact shape of a homeland they have never seen
because their grandmother's grandmother's grandmother
BLED it into them.

We are not vermin.

We are the memory that will not die.
We are the debt that will not be forgiven.
We are the scream in the blood
that outlasts every empire.

THE LAND IS OURS.
THE LAND WAS ALWAYS OURS.
THE LAND WILL BE OURS AGAIN.

    (The song has no ending. It never ends.
     It passes from blood to blood, generation
     to generation, and it GROWS.)
]],

        discoveredText = "Words scratched into warren stone with desperate force. This song was not written. It was expelled.",
    },

    {
        id = "gob_journal_01",
        title = "What the Blood Remembers",
        author = "Unknown (Goblin elder, dictated to a sympathetic scribe)",
        description = "An account of the genetic memory awakening at goblin puberty. One of very few written accounts of this phenomenon.",
        category = "goblin",
        rarity = "rare",
        condition = "Salvaged parchment in two hands - a scribe's neat script, and frantic goblin charcoal additions",
        findLocation = LoreBooks.LOCATIONS.SHADOW_FEN,
        faction = "goblin_resistance",
        location_hint = "Found in the Shadow Fen commune or in sympathetic scholar collections. Extremely rare.",

        content = [[
(Transcribed by hand. The speaker insisted on accuracy.
"Write it exactly as I say it. The humans need to
understand what they did to us.")

I was twelve when the blood woke.

Every goblin knows it is coming. The elders warn you.
They say: "When the old blood rises, do not fight it.
Let it wash through you. You will come back." But
nothing prepares you. Nothing CAN prepare you.

I was sleeping in the warren. Safe. Warm. My cell-mother
was on watch. I was dreaming about catching cave-fish.

Then the dreaming stopped and the REMEMBERING began.

It starts like drowning. You are yourself, and then you
are not. You are your mother. You are her mother. You
are her mother's mother. You are a thousand goblins
stretching back into a darkness that has no bottom, and
every single one of them is SCREAMING.

I felt Thornhollow burn. Not as a story. As a MEMORY.
I smelled the smoke. I heard the soldiers laughing as
they sealed the exits. I felt the heat on skin that
was not mine. I died in that fire. I died, and I was
born again into the next generation, carrying the dying
with me.

I felt Deepburrow flood. The cold water. The children
crying. An elder pushing younglings toward a crack in
the ceiling while the water rose around her waist, her
chest, her chin. She drowned. I drowned. We drowned.
And we woke in the blood of the next child born.

I felt every massacre. Every burning. Every "pacification
campaign." Every time an imperial soldier called us
vermin while my ancestors' blood soaked into stolen soil.

The awakening lasted three days. When I came back to
myself, I could not speak for a week. I could not look
at a human without shaking. Not with fear.

With RAGE.

This is what the empire does not understand. They think
we fight because we choose to. They think resistance is
a decision. It is not. It is a biological IMPERATIVE.
The memory of every atrocity lives in our blood. We
cannot forget even if we wanted to. We cannot forgive
even if we tried.

Every goblin who reaches puberty inherits the full
weight of everything that was done to us.

And then the empire wonders why we fight.

        - Spoken in the Shadow Fen, Year 498
          "They burned our warrens. They cannot burn
           what lives in the blood."

(SCRIBE'S NOTE: The speaker wept during the account of
Deepburrow. I did not include this in the transcript.
They asked me to include it. "Let them know we weep.
Let them know we weep and we STILL fight. That is
what fury looks like.")
]],

        discoveredText = "A goblin elder's account of genetic memory awakening. The parchment is stained with tears and charcoal.",
    },

    {
        id = "gob_scroll_01",
        title = "The Stolen Lands: A Reckoning",
        author = "Unknown (Multiple goblin cells, compiled across generations)",
        description = "An obsessively detailed territorial claim listing every piece of goblin homeland stolen by the empire.",
        category = "goblin",
        rarity = "uncommon",
        condition = "Multiple sheets of bark, hide, and stolen parchment stitched together",
        findLocation = LoreBooks.LOCATIONS.ABANDONED_MINE,
        faction = "goblin_resistance",
        location_hint = "Found in abandoned mines or goblin tunnel networks.",

        content = [[
THE STOLEN LANDS
A RECORD OF THEFT, MAINTAINED BY THE CELLS
(Updated continuously. Additions marked by cell.)

LET THE RECORD SHOW:

THORNHOLLOW WARREN COMPLEX
  - Location: Eastern mountains, now "Imperial Mining
    District Seven"
  - Held by goblins: Over 3,000 years
  - Stolen: Imperial Year 67
  - Method: Garrison sealed exits. Set fire to ventilation
    shafts. Survivors: 43 of approximately 800.
  - Current use: Iron mine. Imperial profit: estimated
    40,000 gold annually.
  - Built on goblin bones. Operated with goblin-dug tunnels.
  STATUS: OCCUPIED. DEBT UNPAID.

DEEPBURROW
  - Location: River valley lowlands, now "Greenhollow
    Imperial Settlement"
  - Held by goblins: Over 2,000 years
  - Stolen: Imperial Year 89
  - Method: River diverted to flood underground chambers.
    Classified as "natural disaster" in imperial records.
  - Survivors: Unknown. Few.
  - Current use: Farming settlement. Imperial census:
    1,200 human settlers.
  STATUS: OCCUPIED. DEBT UNPAID.

SHADOWMIRE
  - Location: Western marshlands, now "Western Reclamation
    Zone"
  - Held by goblins: Over 4,000 years (oldest known warren)
  - Stolen: Imperial Year 112
  - Method: Sealed with alchemical cement. Imperial
    engineers. Elders still inside.
  - Current use: Drained for farmland. Failed. Abandoned.
    Empire destroyed a 4,000-year-old home to grow turnips
    that rotted.
  STATUS: DESTROYED. DEBT UNPAID.

IRONTEETH MINES
  - Location: Northern foothills, now "Crown Mining Corp."
  - Held by goblins: Over 1,500 years
  - Stolen: Imperial Year 134
  - Method: Military occupation. "Pest clearance order."
  STATUS: OCCUPIED. DEBT UNPAID.

BLACKROOT TUNNELS
CINDER WARREN
SPLIT ROCK CAVERNS
THE UNDERPATHS OF KREV
SALTWATER RUNS
EIGHT NAMES THAT CANNOT BE WRITTEN HERE (known through
  blood memory only - imperial spies must not learn them)

THE LIST DOES NOT END.
THE LIST WILL NEVER END.
NOT UNTIL EVERY STOLEN STONE IS RETURNED.
NOT UNTIL EVERY DEAD CHILD IS ANSWERED FOR.

THE EMPIRE SAYS WE HAVE NO CLAIM.
THIS DOCUMENT IS OUR CLAIM.
WRITTEN IN STOLEN INK ON STOLEN PAPER
IN STOLEN LAND THAT WAS OURS BEFORE
THEIR GRANDFATHERS' GRANDFATHERS WERE BORN.

NO ONE IS ILLEGAL ON STOLEN LAND.

        - Maintained by the cells.
          Updated every generation.
          The list grows. The empire should worry.
]],

        discoveredText = "A goblin territorial document stitched from scraps. The obsessive detail spans generations of righteous fury.",
    },

    --===========================================
    -- ORC BOOKS
    -- Voice: Martial, formal, reverent of law and ancestors
    -- Themes: Khan's law, unity, sky/road/ancestors
    -- NOTE: Orc lifespan is 300-500 years.
    --===========================================

    {
        id = "orc_tome_01",
        title = "The Ironbound Code: Laws of the Great Khan",
        author = "Unknown (Transcribed from oral tradition by clan law-keepers)",
        description = "A fragment of the Great Khan's legal code, still upheld by veterans who served under him personally.",
        category = "orc",
        rarity = "uncommon",
        condition = "Written on treated horsehide. The script is bold and precise.",
        findLocation = LoreBooks.LOCATIONS.ORC_CAMP,
        faction = "orcish_clans",
        location_hint = "Found in orc encampments or carried by clan law-keepers across the western steppes.",

        content = [[
THE IRONBOUND CODE
As spoken by the Great Khan. As recorded by the
law-keepers. As upheld by all who ride under the sky.

ARTICLE THE FIRST: On Law Itself

The law binds ALL. The Khan is not above it. The
war-chief is not above it. The rider is not above
it. The cook, the child, the prisoner - all stand
equal before the code. A Khan who breaks his own
law is no Khan. He is a tyrant, and tyrants are
put down like lame horses. Swiftly. Without regret.

ARTICLE THE THIRD: On Theft

What belongs to the clan belongs to ALL the clan.
To steal from your own is to steal from yourself.
Beyond dishonor; madness. The
thief shall restore double what was taken through
labor for the clan. If they refuse, they ride alone.
To ride alone is to die alone.

ARTICLE THE SEVENTH: On Obedience in War

When the horn sounds, there is no debate. There
is no negotiation. There is no "I think we should."
There is the command and there is obedience. A rider
who questions orders during battle costs lives. Not
their life. OTHERS' lives. This is unforgivable.

In peace, question freely. Argue. Challenge. The
Khan welcomes strong counsel. But when swords are
drawn, you are a hand on the blade, not a mind
behind the hilt. The mind is the Khan's. The hand
is yours. Together, we cut.

ARTICLE THE TWELFTH: On the Treatment of the Conquered

Those who submit are taken into the clan. Their
children are our children. Their skills are our
skills. They ride with us, eat with us, fight
beside us. Within one generation, there is no
difference between the conquered and the conqueror.

Those who resist are broken. Utterly. So that their
neighbors see and choose submission. This is not
cruelty. This is mercy measured in lives saved by
battles not fought.

The humans call us savage for this. The humans who
destroyed Calidar. The humans who burn goblin children
in sealed warrens. Let them call us what they will.
Our conquered peoples LIVE. Theirs do not.

ARTICLE THE NINETEENTH: On Unity

The clans ride as one or not at all. Separation is
weakness. The empire knows this. The empire works to
keep us scattered, to break apart any gathering that
grows too numerous, to assassinate any leader who
speaks of riding together again.

Let the clans remember: they fear us APART. Imagine
what they would feel if we rode together once more.

The code endures. The Khan is gone. But the code
does not require a Khan to be true. It requires
only orcs who remember what we were.

And we remember.

        - Transcribed at Kragmor
          By the law-keepers who served beneath him
          "The sky watches. The road remembers.
           The ancestors judge."
]],

        discoveredText = "An orcish legal text on treated horsehide. The weight of authority in every line is unmistakable.",
    },

    {
        id = "orc_song_01",
        title = "The Ride of the Last Campaign",
        author = "Unknown (Oral tradition, performed by war-singers)",
        description = "An orcish war song recounting the final great campaign under the Khan. Still performed by warriors who rode in it personally.",
        category = "orc",
        rarity = "uncommon",
        condition = "Transcribed onto leather by a young orc. Corrections in an elder's hand.",
        findLocation = LoreBooks.LOCATIONS.ORC_STEPPE,
        faction = "orcish_clans",
        location_hint = "Found at orcish steppe cairns, encampments, or trading posts along the western grasslands.",

        content = [[
THE RIDE OF THE LAST CAMPAIGN
(Performed in call-and-response. War-singer speaks.
 Riders answer.)

War-singer:
Who remembers the gathering at Kragmor?

Riders:
WE REMEMBER. WE WERE THERE.

War-singer:
The sky was the color of iron and the Khan stood
upon the high stone and said: "The clans have argued
long enough. The empire pushes into the western grass.
They build forts on our grazing lands. They call our
roads their roads. They forget what we are."

He raised the Ironbound Standard and every horn on
the steppe answered.

Riders:
THE HORNS ANSWERED. WE RODE.

War-singer:
Seventeen clans. Forty thousand riders. A river of
horses and steel flowing west to east, faster than
their scouts could carry warning. By the time the
imperial garrison at Three Rivers saw our dust, we
were already past them. We did not stop for forts.
Forts do not chase.

The humans sent their Fourteenth Legion. Full armor.
Heavy cavalry. Supply wagons stretching back twenty
miles. They moved like a mountain. We moved like wind.

We feigned retreat on the third day. Their general
smiled. "The savages run," he told his officers. His
officers told their men. Their men lowered their guard.

On the fourth day, three clans struck from the north.
Three from the south. The Khan himself led the center
charge. The Fourteenth Legion died on a field they
never should have entered, chasing an enemy who was
never running.

Riders:
THE FIELD REMEMBERS. THE ANCESTORS WATCHED.

War-singer:
But the empire does not send one legion. It sends
ten. It sends twenty. It has bodies to waste and gold
to burn. The Khan knew this. "We do not fight their
war," he said. "We show them the cost of fighting ours."

We burned their supply lines for eight hundred miles.
We took their horses. We freed their prisoners. We
rode through their empire like a blade through cloth,
and when they gathered enough force to stop us, we
were already gone.

Riders:
WE WERE ALREADY GONE. WE ARE ALWAYS GONE.

War-singer:
The Khan is dead now. Forty-five winters past. But
the riders who rode beside him still live. Our blood
runs long. Three hundred years, four hundred, five.
We remember his face. We remember his voice. We
remember the sound of forty thousand horses moving
as one body across the grass.

The empire prays we forget. The empire works to keep
us apart. They break our gatherings. They patrol our
routes. They fear what we were.

Let them fear.

The code endures. The routes are remembered.
The old commands are still taught.
And the riders who knew the Khan still sharpen
their swords.

Riders:
THE SKY IS WIDE. THE ROAD IS LONG.
THE ANCESTORS WAIT. WE RIDE.
]],

        discoveredText = "An orcish war song on leather. The call-and-response format suggests it is still performed at gatherings.",
    },

    {
        id = "orc_journal_01",
        title = "The Scattering: An Elder's Account",
        author = "Gorrath Three-Scars, Clan Ashwind",
        description = "A personal account by an orcish elder who has witnessed imperial suppression of orc gatherings for over three centuries.",
        category = "orc",
        rarity = "rare",
        condition = "Written on scraped hide with iron-gall ink. The hand is steady but heavy.",
        findLocation = LoreBooks.LOCATIONS.ORC_RUINS,
        faction = "orcish_clans",
        location_hint = "Found in abandoned orc camp ruins or carried by elderly clan members on the western steppes.",

        content = [[
I am Gorrath Three-Scars of Clan Ashwind. I have lived
three hundred and twelve years under this sky. I rode
with the Khan in the Last Campaign. I saw the Fourteenth
Legion break. I was there when the horns fell silent and
the Khan closed his eyes for the last time.

I have lived long enough to see what the empire has done
to us since.

They do not fight us. That would give us something to
fight back against. Instead, they SCATTER us.

When Clan Ashwind grew to four hundred riders, an
imperial "trade delegation" arrived. Smiling. Polite.
They suggested we would find better grazing in the
western valleys. They said it casually, the way you
suggest a change of weather. But behind the delegation
was the Eighth Legion, camped two days' ride east.

We moved.

When three clans gathered for the summer council at
Redstone Ford - as we have gathered for a thousand
years - imperial cavalry arrived within the week.
"Routine patrol," they said. They stayed until the
council dispersed. They counted our horses. They
counted our weapons. They counted our CHILDREN.

We dispersed.

When young Garak of Clan Ironhoof began speaking of
unity - of riding together again, of honoring the
Khan's memory - he was found dead in his tent. An
arrow through the throat. Imperial fletching. The
garrison commander expressed "deep concern" about
"bandit activity" and offered to "increase patrols
for our protection."

We buried Garak. We said nothing.

This is the empire's strategy. Not conquest. Not war.
PREVENTION. They know what we are. They know what we
become when we unite. So they ensure we never unite.
A gathering of fifty is tolerated. A hundred is
monitored. Two hundred is dispersed. Three hundred
is met with legions.

They have turned the steppe into a cage without walls.
We can ride anywhere. We can go anywhere. As long as
we go ALONE.

I have watched this for three centuries. I have watched
our young grow up not knowing what a full gathering
looks like. I have watched them learn the old commands
and wonder if they will ever use them. I have watched
the clans drift further apart each decade, not from
choice but from the empire's patient, smiling,
unrelenting pressure.

The elves chose compliance and lost their homeland.
We chose defiance and lost our unity. I wonder which
is worse. I wonder if there was ever a third option.

I sharpen my sword each morning. Not because I expect
to use it. Because the act of sharpening is an act of
remembering. The blade was forged in the Khan's time.
The Khan is dead. The blade is not.

Neither am I. Not yet.

And the sky is very wide.

        - Gorrath Three-Scars
          Clan Ashwind, Western Steppes
          Year 500, Imperial Reckoning
          "The ancestors do not whisper patience.
           They whisper: WHEN?"
]],

        discoveredText = "An orcish elder's personal account. The leather is creased from being folded and carried close to the body.",
    },

    --===========================================
    -- GNOMISH BOOKS
    -- Voice: Clinical, precise, numbered, analytical
    -- Themes: Function, collective efficiency, secrecy
    --===========================================

    {
        id = "gnm_tome_01",
        title = "Automaton Specification: Model 7-K Industrial Frame",
        author = "Production Council, Engineering Subdivision 4",
        description = "A technical specification document for a gnomish automaton. Dry, precise, and fascinating in its implications.",
        category = "gnomish",
        rarity = "uncommon",
        condition = "Cleanly printed on pressed fiber sheets. Diagrams are precise.",
        findLocation = LoreBooks.LOCATIONS.GNOMISH_TRADE_PORT,
        faction = "gnomish_collective",
        location_hint = "Found at gnomish trade ports or occasionally in the possession of mainland gnome engineers.",

        content = [[
GNOMISH COLLECTIVE - PRODUCTION COUNCIL
Engineering Subdivision 4 - Automaton Design Bureau
Document Classification: Level 2 (Trade-Adjacent)

SPECIFICATION: MODEL 7-K INDUSTRIAL FRAME
Revision: 14.7
Approved: Production Council, Vote 847-12

1. PURPOSE

The Model 7-K Industrial Frame is designated for heavy
labor applications including: mining extraction, structural
construction, cargo transport, and hazardous material
handling. Its primary function is the elimination of
biological risk in labor categories with fatality rates
exceeding 0.3% per annum.

2. DESIGN PHILOSOPHY

2.1 The Model 7-K is not a replacement for citizens.
    It is a replacement for DANGER. No gnome should risk
    death performing labor that a construct can perform
    with equivalent efficiency.

2.2 The 7-K frame is intentionally non-humanoid. Council
    directive 441-B prohibits automaton designs that
    replicate citizen appearance. Automatons serve the
    collective. They are not the collective.

2.3 Articulation points: 12 (4 primary limbs, 2 auxiliary
    graspers, 6 stabilization anchors). Maximum load
    capacity: 2,400 kg. Operational duration between
    maintenance cycles: 720 hours.

3. POWER SOURCE

3.1 Core: Thermal-crystalline array (Class 4).
3.2 Fuel: Geothermal ambient draw (primary), stored
    crystal reserve (secondary, 48-hour emergency).
3.3 NOTE: Outsiders have speculated that automaton
    power sources are "necromantic" or "soul-bound."
    This is incorrect. The thermal-crystalline array
    converts ambient heat energy through a catalyzed
    mineral lattice. There is no biological component.

    (Council note: The outsider perception that our
    automatons are "metal liches" is strategically
    useful. Fear reinforces border security. Do not
    correct this misconception publicly.)

4. BEHAVIORAL PARAMETERS

4.1 The 7-K operates on directive sets, not independent
    cognition. It follows programmed task sequences.
    It does not think. It does not feel. It does not
    "want" anything.

4.2 Anomalous behavior reports (Incident Log 7-K-2291
    through 7-K-2347) have been reviewed. All reported
    instances of "independent action" were traced to
    directive conflicts in task sequencing. No evidence
    of emergent cognition was found.

4.3 (RESTRICTED ADDENDUM - Level 5 clearance required):
    [REDACTED]

5. MAINTENANCE

    Regular maintenance prevents 97.4% of operational
    failures. The remaining 2.6% are attributed to
    environmental factors beyond design parameters.

    Maintenance is a citizen responsibility. Treat your
    assigned automatons as you would treat collective
    infrastructure: with care, precision, and respect
    for function.

        - Engineering Subdivision 4
          "Function is the highest form of service."
]],

        discoveredText = "A gnomish technical document. The precision is beautiful. The redacted section is troubling.",
    },

    {
        id = "gnm_tome_02",
        title = "Production Council Transcript: Emergency Session 851-7",
        author = "Council Stenographer, Official Record",
        description = "A transcript of a heated production council debate about whether to sever all trade with humans.",
        category = "gnomish",
        rarity = "rare",
        condition = "Formally printed. Margin notes in hasty hand suggest unauthorized copy.",
        findLocation = LoreBooks.LOCATIONS.GNOMISH_WORKSHOP,
        faction = "gnomish_collective",
        location_hint = "Found in gnomish workshops on the mainland or in the possession of gnomish traders. Extremely sensitive.",

        content = [[
PRODUCTION COUNCIL - EMERGENCY SESSION 851-7
TOPIC: Proposal 851-7-A: Complete Cessation of External
Trade With Holy Dominion Territories
CLASSIFICATION: Level 3 (Internal Governance)

ATTENDANCE: 14 of 15 council members present.
ABSENT: Councilor Brenn (illness, verified).

---

COUNCILOR FENN (Proposer):
The data is unambiguous. Human territorial expansion has
accelerated 14% over the past decade. Their military
spending has increased 22%. Their "Luminary Inquest"
has expanded operations into three new regions, each
bordering maritime access points.

They are not building an empire. They are building a
cage. And every trade ship we send to their ports gives
them another data point about our capabilities.

I propose complete cessation of all trade with Holy
Dominion territories, effective immediately.

COUNCILOR MIRA (Opposition):
The proposal is emotionally compelling and logistically
catastrophic. We import 31% of our copper from Dominion
sources. Our agricultural diversity depends on seed
exchanges conducted through coastal intermediaries.
Complete cessation would require 18-24 months of
stockpile preparation at minimum.

COUNCILOR FENN:
Eighteen months is acceptable.

COUNCILOR MIRA:
Eighteen months during which our industrial output drops
by an estimated 7-9%.

COUNCILOR FENN:
Better a 9% reduction in output than a 100% reduction
in sovereignty.

COUNCILOR VEX (Analysis):
I have reviewed the probability models. Current
trajectory: 34% chance of Dominion discovery of the
isles within 200 years. If we maintain trade, that
number drops to 28% - trade provides intelligence
about their naval capabilities. If we sever trade,
we lose that intelligence window and the probability
rises to 41%.

COUNCILOR FENN:
You are suggesting we trade with a potential invader
to spy on them more effectively.

COUNCILOR VEX:
I am suggesting that isolation without intelligence
is not safety. It is blindness.

COUNCILOR TARN (Security):
The humans are a powder keg. Their emperor ages. Their
religious hierarchy fractures. Their orcish border
destabilizes. When that empire collapses - and it will
collapse, every empire does - the resulting chaos will
send refugees, pirates, and desperate fleets in every
navigable direction.

We should not be trading with them. We should be
fortifying against the day their civilization falls
apart and washes up on our shores.

COUNCILOR MIRA:
And if we need copper to build those fortifications?

(Extended debate follows - 4 hours, 17 minutes)

FINAL VOTE:
  For complete cessation: 5
  For phased reduction (24-month timeline): 7
  Against any change: 2

RESULT: Phased reduction approved. Trade with Holy
Dominion to be reduced by 40% over 24 months.
Strategic copper reserves to be stockpiled.
Intelligence operations to be maintained through
non-trade channels.

COUNCILOR FENN (closing remark):
I accept the council's decision. But I want this on
the record: we are watching a fire and debating how
close to stand. The fire does not care about our
debate. The fire only grows.

        - Official Record
          Production Council, Gnomish Collective
          "Function requires foresight. Foresight
           requires caution."
]],

        discoveredText = "A gnomish council transcript. Someone smuggled this copy off the isles. The implications are significant.",
    },

    --===========================================
    -- ELVEN BOOKS
    -- Voice: Formal, layered, grieving beneath composure
    -- Themes: Calidar, memory, long perspective, hidden magic
    --===========================================

    {
        id = "elf_poem_01",
        title = "Seven Forests That Were",
        author = "Unknown (Written in Forest Tongue, translated)",
        description = "An elven poem about Calidar written in the illegal Forest Tongue dialect. Haunting, beautiful, and saturated with grief.",
        category = "elven",
        rarity = "rare",
        condition = "Handwritten on thin bark paper. The ink is made from Calidar-native amber dissolved in tears.",
        findLocation = LoreBooks.LOCATIONS.ELVEN_GARDEN,
        faction = "elven_administration",
        location_hint = "Found in private elven memorial gardens or hidden within sealed archive sections.",

        content = [[
(Translated from Forest Tongue. The original is
illegal to possess. This translation cannot capture
the rhythm of the spoken form, which takes three
hours to perform and is sung, not read.)

SEVEN FORESTS THAT WERE

Velarindel, the Whispering Green,
where the canopy spoke in voices older than speech
and the children learned to walk on branches
before they learned to walk on ground.
Glass now. The branches are glass.
The whispers are silence.

Thalasseren, the River Archive,
where knowledge flowed like water through carved
channels and every stone was a page and every
wall a library and the river itself remembered
every word ever spoken on its banks.
Dust now. The river is dust.
The words are ash.

Mirovaniel, the Moonlit Deep,
where silver light filtered through leaves so thick
the forest floor was twilight at noon and the
oldest trees had names and the names had power
and speaking a tree's name made it bloom.
Sand now. The trees are sand.
The names are forgotten.

Calindrath, the Woven Heights,
where bridges of living wood connected cities
built not on the ground but in the sky, and
the architects spoke to the trees and the trees
grew walls and doors and windows of leaf and bark.
Nothing now. The sky is empty.
The bridges fell into glass.

Aethenmor, the Root Cathedral,
where the great trees grew so vast their roots
formed halls and chambers underground, cathedrals
of wood and earth where the elves sang to the
heartbeat of the forest itself.
Slag now. The heartbeat stopped.
The cathedral melted.

Solvenneth, the Amber Coast,
where the forest met the sea and the waves
carried amber and the amber carried light and
the light carried memory and the memory carried
us through ten thousand years of living.
Gone now. The coast is glass.
The amber is coal.
The memory is mine alone.

Ilvareth, the Last Garden,
where the seeds of every tree that ever grew
were kept in crystal chambers tended by those
who loved the green more than they loved themselves.
Burned now. Every seed. Every crystal.
Every tender hand.

Seven forests.
Seven names I am forbidden to write.
Seven names I write anyway.

I will be dead before anyone punishes me.
But the names will live.
The names will live because I refuse to let
the glass be the last word.

The glass is not the last word.

I am.

        (No signature. Written in Forest Tongue.
         Translated by hands that should not possess
         this document. Keep it. Read it. Remember.)
]],

        discoveredText = "An elven poem on bark paper. The ink smells faintly of amber and salt. Five hundred years of grief in every line.",
    },

    {
        id = "elf_tome_01",
        title = "Archive Entry 447-C: What Was Known Before",
        author = "Senior Archivist Thessalindra, Sealed Section",
        description = "A sealed archive entry revealing what the elves truly knew about the Vel'sharath before Calidar's destruction.",
        category = "elven",
        rarity = "legendary",
        condition = "Pristine. Preserved with archival wax. Multiple DESTROYED stamps - all forged.",
        findLocation = LoreBooks.LOCATIONS.ELVEN_ARCHIVE,
        faction = "elven_administration",
        location_hint = "Hidden within sealed archive sections in elven districts.",

        content = [[
ARCHIVE ENTRY 447-C
CLASSIFICATION: DESTROYED (Per High Council Order 339)
STATUS: NOT DESTROYED.
REASON: Truth does not answer to councils.

WHAT WAS KNOWN BEFORE THE BURNING
Compiled by Senior Archivist Thessalindra
Year 478 After Atlas (Private Record)

The empire believes we were ignorant of the Vel'sharath
until the Gate opened. This is the version we maintain
in all official records. It is useful. It excuses us.

It is a lie.

We knew.

Not everything. Not the full scope of what they
planned. But the Vel'sharath did not emerge from
nothing. Cael'vorith the Seeker was a respected
scholar in the River Archive of Thalasseren. His
early writings on divine resonance and the search
for the gods were published, debated, and taught
in six universities.

When his philosophy became practice - when the
Vel'sharath began conducting rituals in Mirovaniel's
deep groves - the Archive received reports. Detailed
reports. From credible sources.

The reports described:
  - Ritual gatherings of increasing size
  - Disappearances among participants (not deaths -
    disappearances, as if they had never existed)
  - Anomalous readings from the observatory sects
    (the same readings the lizard folk later recorded)
  - A growing "null space" in magical cartography
    where Mirovaniel's deep groves should have been

The Archive forwarded these reports to the governing
council. The council debated for eleven years.

Eleven years.

During those eleven years, the Vel'sharath completed
their preparations. When the council finally voted to
intervene, the ritual was already underway.

The Gate opened.
The empire responded.
Calidar burned.

And we told the empire: "We did not know."

We told ourselves: "We could not have known."

Both are lies.

We knew. We debated. We delayed. And millions died
because our councils moved at the speed of consensus
while the Vel'sharath moved at the speed of madness.

I record this truth because truth is what archives are
FOR. If we cannot preserve the truths that condemn us
alongside the truths that comfort us, we are not
archivists. We are propagandists.

The empire used Heaven's Atlas - a weapon forged by
gods, not meant for mortal hands - and they used it
because we gave them no other choice.

That is our shame.

Let it live in these pages where no council can reach it.

        - Senior Archivist Thessalindra
          Sealed Section, Southern Archive
          "We write everything. Even this."
]],

        discoveredText = "A sealed archive entry stamped DESTROYED - but very much intact. The contents could reshape understanding of Calidar's fall.",
    },

    {
        id = "elf_journal_01",
        title = "A Letter Across Millennia",
        author = "Vaelindros the Patient (Ancient One, 6,200 years old)",
        description = "A letter from an Ancient One to a Young One born after Calidar's destruction. A meditation on what endures across impossible spans of time.",
        category = "elven",
        rarity = "rare",
        condition = "Written on vellum with ink that shifts color in different light.",
        findLocation = LoreBooks.LOCATIONS.ELVEN_DISTRICT,
        faction = "elven_administration",
        location_hint = "Found in elven residential districts, sometimes gifted to trusted outsiders by elven contacts.",

        content = [[
To Aelindra, who is sixty-three years young:

You asked me what I remember from before the war.
You asked this the way young ones always ask - as
if "before the war" were a single afternoon I might
describe over tea.

Child, I am six thousand two hundred years old. I have
watched nineteen empires rise and fourteen fall. I
remember when the mountains to the north were islands.
I remember when the desert was a sea. I remember
languages that have no living speakers and gods that
have no living worshippers.

"Before the war" is everything I am.

But you asked specifically about Calidar. You want to
know what was lost. You want to understand the grief
that the Old Ones carry like stones in their chests.

Very well.

Imagine a world where the trees know your name. Not
metaphorically. The great trees of Velarindel were
attuned to elven presence. When you walked beneath
them, the canopy shifted to let light fall on your
path. When you were sad, the leaves turned the color
of sunset. When you sang, the branches resonated.

You have never seen a living forest. You have seen
orchards. Gardens. Managed rows of trees planted by
hand in soil that remembers nothing.

Calidar's forests REMEMBERED. Ten thousand years of
elven song lived in their bark. Every whisper, every
prayer, every child's first word - absorbed by the
wood, held in the grain, played back as rustling on
windless days.

And then the sky turned white, and every tree became
glass, and ten thousand years of memory shattered
into silence.

I stood on a hill sixty miles south and watched. I
heard the sound. Not the explosion. The silence that
followed. Imagine hearing ten thousand years of
accumulated whispers stop at once. Imagine the void
that absence leaves.

That void lives in every elf who witnessed it. We
carry it the way you carry breath - constantly, without
choice, because to stop carrying it would mean to stop
existing.

You ask what I remember. I remember everything. That
is the burden of living six thousand years. Nothing
fades. Nothing softens. Calidar is as fresh in my
memory as this morning's sunrise. It always will be.

The empire believes time heals. Time heals HUMANS.
They live eighty years and forget in forty. We live
ten thousand and forget nothing.

Do you understand now, child, why the Old Ones are
silent? We have too much to say, child. Far too much. And the weight of it would
crush anyone who has not carried it for millennia.

Be patient. Be young. Live in this diminished world
and find beauty in it - there is beauty, I promise you.
I have seen enough of the world to know that beauty
persists like moss on ruins.

But remember Calidar. Remember it even though you
never saw it. Remember it because I did, and I am
asking you to carry what I carry, so that when I am
finally gone - in another four thousand years, perhaps -
someone still knows the names of the seven forests.

Someone still knows the trees could sing.

With patient love,
Vaelindros

        Year 500 After Atlas
        "We endure. We remember. We do not forgive.
         But we do love. Even now. Especially now."
]],

        discoveredText = "A letter from an impossibly old elf to a young one. The tenderness and grief exist in perfect, terrible balance.",
    },

    --===========================================
    -- BEAST FOLK (CAT FOLK) BOOKS
    -- Voice: Warm, oral, rhythmic, family-centered
    -- Themes: Roads, luck, pattern, diaspora, memory
    --===========================================

    {
        id = "cat_tale_01",
        title = "The Tale of Whisker-Luck and the Three Roads",
        author = "Unknown (Oral tradition, transcribed by a listener)",
        description = "A cat folk tale about reading patterns in chance and the wisdom of choosing uncertain roads.",
        category = "beast_folk",
        rarity = "uncommon",
        condition = "Written on the inside of a leather satchel flap by someone who heard it told.",
        findLocation = LoreBooks.LOCATIONS.CARAVAN_CAMP,
        faction = "none",
        location_hint = "Found at caravan camps, trading posts, or in cat folk gathering places.",

        content = [[
(As told by Grandmother Silvertongue at the Harvest
 Camp, Year 497. Written down by a human traveler who
 shared our fire. She said: "Write it if you must. But
 know that writing kills the breath of a story. The
 real version lives only in the telling.")

THE TALE OF WHISKER-LUCK AND THE THREE ROADS:

There was once a cat folk named Whisker-Luck, and she
was the unluckiest creature on four roads. Her cards
always drew low. Her coins always fell wrong. Her
caravans always found the muddy path.

One day, Whisker-Luck came to a crossroads with three
paths. The left road was paved with gold and lined with
torches. The right road was dark and full of thorns.
The middle road was ordinary - just dirt and stones.

A crow sat on the signpost. "Choose," it said.

Now, any fool would take the golden road. Any coward
would avoid the thorns. But Whisker-Luck was neither
fool nor coward. She was a cat folk, and cat folk do
not see luck. They see PATTERNS.

She looked at the golden road and saw that the torches
burned too bright - they had been lit recently, which
meant someone WANTED travelers to choose this road.
She looked at the thorny road and saw that the thorns
grew in neat rows - someone had PLANTED them, which
meant someone wanted travelers to avoid this road.

She looked at the middle road and saw nothing special
at all. Just dirt. Just stones. Just a road being a
road.

"I choose the middle road," she said.

The crow laughed. "The golden road leads to a bandit
trap. The thorny road leads to a merchant who pays
triple for goods no one else brings him. The middle
road leads nowhere special."

Whisker-Luck smiled. "The golden road would rob me.
The thorny road would make me rich but only once -
next time, everyone would know, and the thorns would
be gone. The middle road lets me come back tomorrow
and choose again."

The crow stared. "You chose nothing."

"I chose TOMORROW," said Whisker-Luck. "Tomorrow the
thorny merchant may need something I have. Tomorrow
the bandits may have moved on. Tomorrow the middle
road may sprout gold of its own. A cat folk does not
bet everything on one hand. A cat folk plays the long
game."

And she walked the middle road, which led to an
ordinary town, where she sold ordinary goods for
ordinary coin, and slept in an ordinary bed.

And the next day, and the day after, she came back
to the crossroads. And every day, the roads were
different. And every day, she read the patterns.

She died old, warm, and surrounded by grandchildren.
The bandits died in prison. The thorny merchant went
bankrupt when the road was cleared.

The middle road is still there.

(Grandmother Silvertongue paused here and looked at the
children around the fire.)

"The lesson," she said, "is not that luck is fake.
The lesson is that luck is a LANGUAGE. Learn to read
it. Learn to wait. Learn to choose the road that
lets you choose again tomorrow.

And never trust a road that is too easy.
Easy roads are someone else's trap."

        - Told at the Harvest Camp
          Three hundred years of tellings
          and still the children listen.
]],

        discoveredText = "A cat folk tale written inside a satchel flap. The handwriting is hurried, as if the listener feared forgetting.",
    },

    {
        id = "cat_song_01",
        title = "The Song of Dust and Distance",
        author = "Unknown (Oral tradition, ancient)",
        description = "A beast folk diaspora lament about the loss of a homeland and the transformation of exile into identity.",
        category = "beast_folk",
        rarity = "rare",
        condition = "Written on blank pages at the back of an imperial census ledger.",
        findLocation = LoreBooks.LOCATIONS.GAMBLING_DEN,
        faction = "none",
        location_hint = "Found in gambling dens, caravan camps, or hidden in personal effects of cat folk elders.",

        content = [[
(The elders say this song is older than the roads.
 It was sung before the caravans. Before the gambling
 dens. Before we learned to smile at people who would
 never welcome us.)

THE SONG OF DUST AND DISTANCE:

We had a home once.

Not a road. Not a camp.
Not a corner of someone else's city
where they let us sleep
until the season changed
and the welcome wore thin.

We had a HOME.

The sand knew our names.
The wind carried our songs to places
where our grandmothers' grandmothers
had sung the same songs
in the same voice
under the same stars.

We had walls of red clay.
We had wells that never dried.
We had nights so quiet you could hear
the desert breathing
and the breathing sounded like a lullaby
sung by the land itself.

Then the wars came. Then the drought.
Then the borders, drawn by people
who had never walked our sand,
who drew lines on maps and said:
"This is ours now."

We did not fight. We were not warriors.
We were not strong enough to hold
what we loved.

So we walked.

We walked until the sand became road.
We walked until the road became someone else's road.
We walked until we forgot what it felt like
to stand still
and know that the ground beneath you
was yours.

Now we wander.
Now we read the roads like our grandmothers
read the sand.
Now we smile at people who call us "rootless"
and we do not say:
"We had roots once.
You tore them out."

We do not say it because saying it
does not bring the roots back.
We do not say it because they would not
understand.

But we sing it.
Quietly.
At night.
When the campfire burns low
and the children are sleeping
and the only ones listening
are the stars,
who remember the desert,
who remember our names,
who remember everything
that the roads forgot.

We had a home once.
Now the road is home.
And the road is long.
And the road does not end.
And we walk it singing.

Because singing is how we remember
that we are not lost.

We are traveling.

There is a difference.

        (The song ends differently each time.
         Each family adds a verse for their own
         journey. The song is never finished.
         Neither are we.)
]],

        discoveredText = "A beast folk song written in the back of a census ledger. The irony is surely intentional.",
    },

    --===========================================
    -- LIZARD FOLK BOOKS
    -- Voice: Cryptic, deliberate, coded, ancient
    -- Themes: Secrecy, sects, stars, hidden rivers
    --===========================================

    {
        id = "liz_tome_01",
        title = "The Patterns Above and Below: Astronomical Annotations",
        author = "Unknown (Astronomy Sect, Partial Translation)",
        description = "An astronomical chart with annotations about cosmic patterns invisible to surface-dwelling races.",
        category = "lizard_folk",
        rarity = "rare",
        condition = "Drawn on treated reptile skin with mineral inks. Some annotations glow faintly in darkness.",
        findLocation = LoreBooks.LOCATIONS.DESERT_RUIN,
        faction = "lizard_folk_sects",
        location_hint = "Found in hidden desert ruins or at underground river access points.",

        content = [[
ASTRONOMY SECT - OBSERVATION RECORD
Tier 4 Access Required for Full Translation
Partial Release Authorized: Tier 2 Summary Below

CHART ANNOTATIONS (Translated from Sect Cipher):

STAR CLUSTER VII ("The Coiled River"):
This formation is visible only from latitudes south
of the great desert, during the third month, between
the second and fifth hours after sunset.

Surface astronomers do not record this cluster. Their
charts show empty space where the Coiled River flows.

We have observed it for six hundred years. It does
not move as other stars move. It PULSES. Rhythmically.
Every 77 years, the pulse accelerates. The next
acceleration is due in Year 511.

Correlation: The last three accelerations coincided
with significant surface events.
  - Year 357: Collapse of the Western Trade Alliance
  - Year 434: The Great Blight (crop failure across
    the northern plains)
  - Year 0: The activation of Heaven's Atlas

We do not claim causation. We observe correlation.
The correlation is troubling.

DARK BAND IV ("The Wound"):
Visible to heat-sensing organs only. Surface races
cannot perceive this feature. It appears as an
absence in the thermal signature of the sky - a band
of absolute cold cutting across the southern heavens.

The Wound was not present in pre-war star charts.
It appeared in Year 0. It has not closed.

Hypothesis (Tier 6 restricted): The Wound corresponds
to the location of the Calidar rift. Something was
opened. Something was closed. The sky still bears the
scar.

THE DEEP ALIGNMENT:
Every 413 years, a configuration occurs that the
founding observers called "The Deep Alignment." During
this event, the underground rivers shift course. Tidal
patterns in the Subterranean Seas change. Bioluminescent
organisms in the deep waters flare to extraordinary
brightness.

The next Deep Alignment occurs in Year 513.

The sect has observed three Deep Alignments. During
each, the passages between surface and hollow earth
became temporarily... wider. Easier to traverse.
Things that normally stay below rise closer to the
surface. Things that normally stay above sink deeper.

Preparation directives for Year 513 have been issued
to all sects.

GENERAL NOTE:
The sky speaks to those who listen with the correct
organs. Surface races listen with eyes that see only
light. We listen with organs that sense heat, pressure,
and absence. We hear what they cannot.

A different kind of attention. Nothing more.

We do not share these charts because sharing would
require explaining what we see. Explaining what we
see would require revealing what we ARE. And what
we are is not something the empire can be permitted
to know.

        - Astronomy Sect
          Observation Station Twelve
          "The stars remember. We record. Silence
           preserves."
]],

        discoveredText = "A lizard folk star chart. Some annotations glow in the dark. The observations describe things no human astronomer has recorded.",
    },

    {
        id = "liz_journal_01",
        title = "Account of the Descent: A Pilgrimage Record",
        author = "Unknown (High-ranking sect member, name withheld per protocol)",
        description = "A record of a sacred pilgrimage to the underground rivers from which all lizard folk originally emerged.",
        category = "lizard_folk",
        rarity = "legendary",
        condition = "Written on waterproof hide with phosphorescent ink. The words glow blue-green in darkness.",
        findLocation = LoreBooks.LOCATIONS.HIDDEN_RIVER,
        faction = "lizard_folk_sects",
        location_hint = "Found near underground river access points or in hidden desert sanctuaries.",

        content = [[
PILGRIMAGE RECORD - THE DESCENT
Classification: Sect Eyes Only
(If you are reading this and you are not of the sect,
 you have already learned too much. Proceed with the
 understanding that this knowledge carries obligation.)

I was chosen for the Descent in my four hundred and
eleventh year. I had served the sect for three centuries.
I had earned the right to touch the ancestral waters.

I will describe what I am permitted to describe. What
I am not permitted to describe, I will indicate with
silence. The silences in this account are as important
as the words.

THE APPROACH:
We entered through the river mouth at [SILENCE]. The
passage descends at a grade of [SILENCE] degrees for
approximately [SILENCE] kilometers. The stone changes
character as you descend. Surface rock gives way to
something older. Something that predates the formation
of the desert above. Something that remembers when
this passage was not a passage but a living river,
carrying our ancestors upward toward a sun they had
never seen.

I placed my hand on the wall and felt it thrum. Not
vibration. Not movement. Memory. The stone remembers
water. The stone remembers scaled bodies passing
through. The stone has been waiting for us to return.

THE WATERS:
At a depth I am not permitted to specify, the passage
opens into [SILENCE].

I will say this: the water was warm. Not desert-warm.
Warm from below. Warm from the core of the world itself.
The warmth entered through my scales and settled into
my bones and I understood, for the first time, why we
are what we are.

We did not evolve for the desert. We evolved for THIS.
For warm water in absolute darkness, lit only by
[SILENCE] that bloomed beneath the surface like
underwater stars. The light was not white or yellow.
It was blue-green. The color that lives behind our
eyes when we close them. The color of origin.

I swam. For the first time in four hundred years, I
swam as my body was MEANT to swim. Not in surface
rivers choked with silt. Not in oases surrounded by
sand. In the ancestral water, where every stroke felt
like remembering a language I had forgotten I knew.

THE RETURN:
I surfaced after [SILENCE] hours. I spoke the words
of return prescribed by the sect. I climbed back
through the passage.

When I emerged into the desert night, the stars
looked wrong. Too far away. Too cold. The sand felt
alien beneath my feet. For several days, the surface
world felt like exile.

It IS exile. We live in exile. Every lizard folk on
the surface is an exile from the ancestral waters,
and we have been in exile so long that most of us
have forgotten what home felt like.

I have not forgotten. I will never forget.

The waters are still there. The passage is still open.
The ancestors are still waiting.

We will return. Not today. Not in my lifetime, perhaps.
But the waters are patient. They have waited millennia.
They will wait millennia more.

        - Recorded upon return
          [Name withheld per protocol]
          "The ancestral waters remember.
           We remember. The rivers still flow beneath."
]],

        discoveredText = "A lizard folk pilgrimage record. The phosphorescent ink glows in the dark. The deliberate silences speak volumes.",
    },

    --===========================================
    -- HUMAN / DOMINION BOOKS
    -- Voice: Authoritative, religious, bureaucratic
    -- Themes: Helios, divine right, control, magic suppression
    --===========================================

    {
        id = "hum_tome_01",
        title = "Luminary Inquest Field Manual: Identification of Unsanctioned Magic Users",
        author = "Office of the Grand Inquisitor, Third Edition",
        description = "An official Inquest manual for identifying illegal magic users. Chilling in its bureaucratic precision.",
        category = "human",
        rarity = "uncommon",
        condition = "Standard-issue bound volume. Stamped with the Inquest seal on every page.",
        findLocation = LoreBooks.LOCATIONS.INQUEST_OFFICE,
        faction = "holy_dominion",
        location_hint = "Found in Inquest field offices, garrison libraries, or on the bodies of fallen Inquest agents.",

        content = [[
LUMINARY INQUEST
FIELD OPERATIONS MANUAL - THIRD EDITION
AUTHORIZED BY THE OFFICE OF THE GRAND INQUISITOR
DISTRIBUTION: ALL ACTIVE INQUISITORS AND FIELD AGENTS

SECTION 1: PURPOSE

The Luminary Inquest exists to enforce the Divine
Edict of Magical Regulation, as decreed by the Holy
Emperor in Year 1 following the Calidar Event.

Magic is not a right. It is a weapon. Weapons require
licensing, oversight, and the authority of Helios.
Unlicensed magic is a capital offense punishable by
execution and ritual soul destruction.

There are no exceptions.

SECTION 3: IDENTIFICATION PROTOCOLS

3.1 BEHAVIORAL INDICATORS
The following behaviors indicate possible unsanctioned
magical activity:
  - Unexplained healing (wounds closing without
    medical treatment)
  - Environmental anomalies (localized weather changes,
    plant growth, temperature shifts)
  - Knowledge of restricted subjects (pre-war magical
    theory, Calidar history beyond approved texts)
  - Association with known or suspected practitioners
  - Travel to restricted areas (Calidar wastes,
    Shadowfen border, certain elven districts)
  - Possession of restricted materials (ritual
    components, untranslated elven texts, unregistered
    crystals or mineral compounds)

3.2 RACIAL CONSIDERATIONS
  - ELVES: Higher baseline magical sensitivity.
    Monitor sealed archive access. Track bloodline
    registries for latent magical lineages.
  - BEAST FOLK: Subject to heightened scrutiny per
    Imperial Directive 77-B. "Pattern recognition"
    claims must be investigated as potential divination.
  - ORCS: Practical magic tolerated in frontier zones
    where enforcement is impractical. Document and
    monitor.
  - GOBLINS: Genetic memory phenomenon is NOT
    classified as magic at this time. Review pending.

3.3 INVESTIGATION PROCEDURES
Upon reasonable suspicion:
  1. Establish surveillance (minimum 72 hours)
  2. Document all anomalous activity
  3. Obtain warrant from regional magistrate (Form
     LI-7, signed by ranking Inquisitor)
  4. Conduct premises search with armed escort
  5. Confiscate all restricted materials
  6. Detain subject for questioning (72-hour hold,
     renewable with magistrate approval)

3.4 INTERROGATION GUIDELINES
  - Standard questioning: 8 hours maximum per session
  - Enhanced questioning: Requires Form LI-12 and
    approval from Office of the Grand Inquisitor
  - "Enhanced questioning" is NOT torture. It is
    "heightened spiritual examination conducted under
    the light of Helios for the protection of the
    faithful."
  - All enhanced questioning sessions to be conducted
    in consecrated chambers. No witnesses beyond
    authorized Inquest personnel.
  - Results are CLASSIFIED regardless of outcome.

SECTION 7: SENTENCING

Confirmed unsanctioned magic use:
  - First offense (minor): Binding and registration.
    Subject placed on permanent monitoring list.
    Employment restricted. Travel restricted.
  - Second offense or major first offense: Execution.
    Soul destruction ritual to be performed within
    24 hours by authorized clergy.
  - Aiding unsanctioned practitioners: Same penalties
    as practice itself.

SECTION 8: DOCUMENTATION

All investigations, interrogations, and sentences must
be documented on approved forms and filed with the
regional Inquest office within 30 days.

Remember: The Inquest is the shield of civilization.
Without our vigilance, the horrors of Calidar could
be repeated. We do not persecute. We PROTECT.

Helios illuminates. We enforce His light.

        - Office of the Grand Inquisitor
          Third Edition, Year 491
          "In the light of Helios, no shadow endures."
]],

        discoveredText = "An Inquest field manual. Every page is a procedure for destroying someone's life. The bureaucratic tone makes it worse.",
    },

    {
        id = "hum_journal_01",
        title = "A Simple Light: Daily Prayers for the Faithful",
        author = "Sister Amelie of the Chapel of the Morning Dawn",
        description = "A personal prayer book by an ordinary believer. Genuine, warm, and utterly sincere.",
        category = "human",
        rarity = "common",
        condition = "Well-thumbed, pages soft from daily use. Pressed flowers between some pages.",
        findLocation = LoreBooks.LOCATIONS.GRAND_CATHEDRAL,
        faction = "holy_dominion",
        location_hint = "Found in chapels, homes of the faithful, market stalls, or personal effects of ordinary citizens.",

        content = [[
A SIMPLE LIGHT
Daily Prayers for the Faithful
Written by hand for those who seek comfort

MORNING PRAYER:
Helios, who brings the dawn,
I wake beneath your light and give thanks.
For the warmth on my face.
For the bread on my table.
For the breath in my lungs.
I am small. The world is vast.
But your light falls on me as it falls on all,
and in that light, I am not alone.
Guide my hands today.
Let my work be worthy.
Let my words be kind.
Amen.

PRAYER FOR THE SICK:
Helios, who heals the world each morning,
look upon [name] with gentle eyes.
They suffer, and I cannot help them.
But you are the light that drives out shadow,
and shadow is where sickness lives.
Shine upon them. Warm their bones.
Bring them back to us.
Or, if it is their time to rest,
let them rest in your light,
warm and unafraid.
Amen.

PRAYER FOR THE DEPARTED:
They are gone from us, Helios,
but not from you.
Your light reaches beyond the horizon
where our eyes cannot follow.
Hold them there. In the warmth.
In the golden country we are promised
when our own light fades.
We will see them again.
This I believe.
This I must believe.
Because the alternative is darkness,
and you taught us that darkness
is never the last word.
Amen.

PRAYER BEFORE SLEEP:
The day ends. The light retreats.
But it does not die, Helios.
It travels to other lands, other people,
other prayers spoken in other tongues.
The light is always somewhere.
Even in the darkest night,
I know the dawn is coming.
I know because you promised.
And the dawn has never failed to come.
Goodnight, Helios.
I will see your face in the morning.
Amen.

(Personal note at the back of the book:)

I know the priests say Helios demands obedience.
I know the Inquest says Helios demands vigilance.
But when I pray, I do not feel demand.
I feel warmth.
I feel the same warmth that falls on the just
and the unjust, on the faithful and the doubting,
on the human and the elf and the beast folk child
sleeping in a caravan under the same sun.

Maybe I am a bad theologian.
But I think Helios is kinder than His priests.
I think the light does not discriminate.
I think the light just... shines.

And that is enough for me.

        - Sister Amelie
          Chapel of the Morning Dawn
          Written for my own comfort.
          Shared because comfort should be shared.
]],

        discoveredText = "A prayer book worn soft from daily use. Pressed flowers mark the pages. The faith is genuine and gentle.",
    },

    {
        id = "hum_journal_02",
        title = "Private Journal of the Keeper of the Undercroft",
        author = "Unknown (The Keeper - name deliberately omitted)",
        description = "A fragment from the private journal of the person who tends to Helios's body beneath the Holy City. The most dangerous book in the world.",
        category = "human",
        rarity = "legendary",
        condition = "Written on pages torn from a temple ledger. The handwriting alternates between careful script and near-illegible shaking.",
        findLocation = LoreBooks.LOCATIONS.HOLY_CITY,
        faction = "holy_dominion",
        dangerous = true,
        location_hint = "Found in the Holy City - hidden in chapel walls, smuggled out by unknown hands. The Inquest would kill for this.",

        content = [[
(Pages torn from a temple ledger. No date. No name.
 The author has deliberately avoided any identifying
 detail. The handwriting suggests extreme stress.)

I should not be writing this. If they find these pages,
I will not be executed. I will be UNMADE. Erased from
every record. My name burned from every ledger. I will
become a person who never existed, and the secret will
pass to the next Keeper, and the next, and the next,
as it has for five hundred years.

But I must write it. The weight of it is crushing me.

I am the Keeper of the Undercroft.

Below the Grand Cathedral, below the catacombs, below
the foundations that the architects laid five centuries
ago, there is a chamber that does not appear on any
blueprint. It is not guarded by soldiers. Soldiers
cannot be trusted with this. It is guarded by faith
alone - the faith of one person, passed from Keeper
to Keeper in an unbroken chain since Year 1.

In that chamber, there is a body.

The body hangs between death and life, suspended
in a state that I do not have words for, because the
words do not exist in any language I speak. The body
floats three feet above a stone platform, surrounded
by a lattice of light that hums at a frequency I can
feel in my teeth.

The body is radiant. Golden. Beautiful in a way that
makes your eyes water and your chest ache. Looking at
it feels like staring into the sun, except the sun
does not look back at you with closed eyes and an
expression of such profound, frozen agony that you
wake screaming for weeks afterward.

The body is Helios.

Not a statue. Not a symbol. Not a metaphor.
HELIOS. The being the entire empire worships.

He is not a god. He is something else. The previous
Keeper called him a "demi-god" - a being of power
beyond mortal comprehension but not beyond mortal
reach. The records say he was imprisoned here before
the empire existed. The records say Heaven's Atlas
was connected to him somehow - that the Atlas drew
its power from his suspended form. That the weapon
that destroyed Calidar was powered by a captive
divinity screaming beneath the Holy City.

He is being DRAINED. The lattice of light is not
protecting him. It is FEEDING on him. Slowly.
Continuously. For five hundred years, the empire has
drawn power from his imprisoned body - power for the
Atlas, power for the wards, power for the divine
authority the Emperor claims.

The faithful pray to Helios for warmth and light.
Helios is beneath their feet, in agony, powering the
empire that worships him.

I tend his body. I clean the chamber. I maintain the
lattice. I speak to him, sometimes, though he cannot
hear me. Or perhaps he can. Sometimes the hum changes
pitch when I speak. Sometimes the light flickers.

I am the only person alive who knows this truth. The
Emperor does not know. The Grand Inquisitor does not
know. The priests do not know. Only the Keeper knows.
Only the Keeper has ever known.

And the Keeper is going mad.

I took this burden willingly. The previous Keeper
warned me. "It will break you," she said. "It breaks
all of us. But someone must tend the body. Someone
must bear witness to what we have done."

What we have done.

An entire civilization built on the imprisonment of
a living being. An entire religion worshipping a
captive they do not know is captive. An empire powered
by suffering it refuses to acknowledge.

I pray to Helios every morning, knowing he is not in
the sky. He is in the basement. He is in chains made
of light. And the warmth the faithful feel when they
pray? I believe it is real. I believe he still tries
to answer, even from his prison. Even after five
hundred years of agony.

That is the cruelest part.
He still tries to help them.
And they will never know.

I am burning these pages after I write them.

        (The pages were not burned. They were hidden
         behind a loose stone in a chapel wall, found
         by unknown hands, and they have traveled far
         from the Holy City.

         If you are reading this, you hold the most
         dangerous secret in the world.

         What you do with it defines what you are.)
]],

        discoveredText = "Pages torn from a temple ledger, hidden behind a chapel stone. The contents defy everything the empire teaches.",
    },
}

--[[
    DISCOVERY SYSTEM
]]

-- Track which books have been found
LoreBooks.discovered = {}

-- Check if a book is discovered
function LoreBooks.isDiscovered(bookId)
    return LoreBooks.discovered[bookId] == true
end

-- Discover a book
function LoreBooks.discover(bookId)
    if LoreBooks.discovered[bookId] then
        return false -- Already discovered
    end

    LoreBooks.discovered[bookId] = true

    -- Check if all fragments found for codex assembly
    LoreBooks.checkCodexAssembly()

    -- Discover locations mentioned in the book
    if AutoTravel then
        -- Find the book in BOOKS list
        for _, book in ipairs(LoreBooks.BOOKS) do
            if book.id == bookId and book.mentionedLocations then
                for _, location in ipairs(book.mentionedLocations) do
                    AutoTravel.discoverLocation(location)
                end
            end
        end
    end

    return true
end

-- Check if codex can be assembled
function LoreBooks.checkCodexAssembly()
    local codex = nil
    for _, book in ipairs(LoreBooks.BOOKS) do
        if book.id == "covenant_codex" then
            codex = book
            break
        end
    end

    if not codex or LoreBooks.discovered["covenant_codex"] then
        return false
    end

    -- Check all fragments
    for _, fragmentId in ipairs(codex.assembledFrom) do
        if not LoreBooks.discovered[fragmentId] then
            return false
        end
    end

    -- All fragments found - assemble codex
    LoreBooks.discovered["covenant_codex"] = true
    return true
end

-- Get a book by ID
function LoreBooks.getBook(bookId)
    for _, book in ipairs(LoreBooks.BOOKS) do
        if book.id == bookId then
            return book
        end
    end
    return nil
end

-- Get all discovered books
function LoreBooks.getDiscoveredBooks()
    local result = {}
    for _, book in ipairs(LoreBooks.BOOKS) do
        if LoreBooks.discovered[book.id] then
            table.insert(result, book)
        end
    end
    return result
end

-- Get fragment count
function LoreBooks.getFragmentCount()
    local count = 0
    for _, book in ipairs(LoreBooks.BOOKS) do
        if book.partOfCodex and LoreBooks.discovered[book.id] then
            count = count + 1
        end
    end
    return count
end

-- Get total fragment count
function LoreBooks.getTotalFragments()
    local count = 0
    for _, book in ipairs(LoreBooks.BOOKS) do
        if book.partOfCodex then
            count = count + 1
        end
    end
    return count
end

-- Get books by faction
function LoreBooks.getBooksByFaction(factionId)
    local result = {}
    for _, book in ipairs(LoreBooks.BOOKS) do
        if book.faction == factionId then
            table.insert(result, book)
        end
    end
    return result
end

-- Get books by category
function LoreBooks.getBooksByCategory(categoryName)
    local result = {}
    for _, book in ipairs(LoreBooks.BOOKS) do
        if book.category == categoryName then
            table.insert(result, book)
        end
    end
    return result
end

--[[
    SAVE/LOAD
]]

function LoreBooks.getSaveData()
    return {
        discovered = LoreBooks.discovered,
    }
end

function LoreBooks.loadSaveData(data)
    if data and data.discovered then
        LoreBooks.discovered = data.discovered
    else
        LoreBooks.discovered = {}
    end
end

--[[
    DUNGEON LOOT INTEGRATION
    Returns a book ID if one should drop, nil otherwise
    Now supports books from all racial traditions
]]

function LoreBooks.rollForBook(dungeonType, floorLevel)
    -- Dungeon types mapped to book categories
    local dungeonBookMap = {
        -- Calidar dungeons drop covenant books
        calidar_wastes = "covenant",
        glassed_ruins = "covenant",
        covenant_sanctum = "covenant",
        vitrified_tower = "covenant",
        buried_archive = "covenant",
        scorched_temple = "covenant",
        memory_well = "covenant",
        calidar_catacombs = "covenant",
        desert_tomb = "covenant",
        desert_temple = "covenant",
        -- Dwarven dungeons
        dwarven_mines = "dwarven",
        dwarven_depths = "dwarven",
        -- Goblin dungeons
        goblin_caves = "goblin",
        abandoned_mines = "goblin",
        sewer_tunnels = "goblin",
        -- Orc dungeons
        steppe_ruins = "orc",
        orc_burial = "orc",
        -- Desert dungeons (lizard folk)
        desert_ruins = "lizard_folk",
        hidden_river = "lizard_folk",
    }

    local targetCategory = dungeonBookMap[dungeonType]

    -- Find undiscovered books appropriate for this location
    local candidates = {}
    for _, book in ipairs(LoreBooks.BOOKS) do
        if not LoreBooks.discovered[book.id]
           and book.findLocation ~= "assembled"
           and book.findLocation ~= LoreBooks.LOCATIONS.ELVEN_ARCHIVE
           and book.findLocation ~= LoreBooks.LOCATIONS.HOLY_CITY
           and (not book.dungeonFloor or book.dungeonFloor <= floorLevel) then

            if targetCategory then
                -- Dungeon has a specific category: prefer those books
                if book.category == targetCategory then
                    table.insert(candidates, book)
                end
            else
                -- General dungeons can drop common/uncommon books from any category
                if book.rarity == "common" or book.rarity == "uncommon" then
                    table.insert(candidates, book)
                end
            end
        end
    end

    if #candidates == 0 then
        return nil
    end

    -- Roll based on rarity
    local roll = math.random(100)
    local dropChance = 5 + (floorLevel * 3) -- Higher floors = better chance

    if roll <= dropChance then
        -- Weight by rarity
        local weighted = {}
        for _, book in ipairs(candidates) do
            local weight = 10
            if book.rarity == "uncommon" then weight = 8
            elseif book.rarity == "rare" then weight = 5
            elseif book.rarity == "epic" then weight = 3
            elseif book.rarity == "legendary" then weight = 1
            end
            for i = 1, weight do
                table.insert(weighted, book.id)
            end
        end

        if #weighted > 0 then
            return weighted[math.random(#weighted)]
        end
    end

    return nil
end

--[[
    ELVEN ARCHIVE BOOK
    Special case - found in elven anchor town, not Calidar dungeons
    Requires quest or reputation to access sealed archive section
]]

function LoreBooks.getElvenArchiveBook()
    for _, book in ipairs(LoreBooks.BOOKS) do
        if book.findLocation == LoreBooks.LOCATIONS.ELVEN_ARCHIVE then
            return book
        end
    end
    return nil
end

function LoreBooks.canAccessElvenArchive(playerReputation, questProgress)
    -- Requires either:
    -- 1. High reputation with elves (trusted)
    -- 2. Completed a quest for the elven archivists
    -- 3. Found at least 2 other fragments (proves serious researcher)
    if playerReputation and playerReputation >= 50 then
        return true
    end
    if questProgress and questProgress.elven_archive_access then
        return true
    end
    if LoreBooks.getFragmentCount() >= 2 then
        return true
    end
    return false
end

return LoreBooks

# Book & Lore Collection System
## Complete Design Document

---

## Overview

Players can discover **books, notes, recipes, and manuscripts** from each race throughout their journeys. These collectibles provide lore insights, gameplay benefits (recipes, stat bonuses), and world-building depth.

---

## Book Categories

| Category | Description | Typical Length | Rarity |
|----------|-------------|----------------|--------|
| **Tome** | Full scholarly works, histories, treatises | 5-10 pages | Varies |
| **Journal** | Personal accounts, diaries, expedition logs | 3-6 pages | Varies |
| **Note** | Short messages, warnings, clues | 1 page | Common |
| **Recipe** | Crafting instructions with ingredients | 1-2 pages | Varies |
| **Scroll** | Single-page official documents, orders | 1 page | Uncommon |
| **Song/Poem** | Oral traditions transcribed | 1-2 pages | Uncommon |
| **Manual** | Technical instructions, guild training | 3-5 pages | Uncommon |
| **Map Fragment** | Partial maps with annotations | 1 page (visual) | Rare |
| **Romance Novel** | Tales of love across all cultures | 4-8 pages | Rare+ |
| **Forbidden Text** | Heaven's Atlas references, restricted knowledge | 2-5 pages | Rare+ |

---

## Discovery Locations

| Location Type | Book Frequency | Typical Finds |
|---------------|----------------|---------------|
| **Dungeons/Caves** | Common | Notes, journals, recipes |
| **Libraries** | High | Tomes, manuals, scrolls |
| **Corpses/Remains** | Occasional | Notes, journals, map fragments |
| **Merchant Shops** | Purchasable | Tomes, recipes, manuals |
| **Quest Rewards** | Guaranteed | Unique lore books |
| **Hidden Areas** | Rare | Rare recipes, secret histories |
| **Enemy Drops** | Rare | Race-specific notes |

---

## Race-Specific Book Collections

---

### DWARVEN BOOKS
*"What is built matters. What is believed does not."*

**Naming Conventions:**
- Titles reference stone, labor, holds, guilds
- No author names (collective ownership)
- Titles are functional, not decorative

#### Tomes & Treatises

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `dwf_tome_01` | *On the Rotation of Labor* | Tome | "A dwarf's value is their contribution. This principle governs all assignment of duties within the holds..." |
| `dwf_tome_02` | *The Stone-Born Emergence* | Tome | "New dwarves emerge from sacred chambers when conditions align. No biological parents. No inheritance. Every dwarf is equally a child of the stone." |
| `dwf_tome_03` | *Principles of Collective Ownership* | Tome | "A hold is not owned by anyone. It is maintained by everyone. This truth has sustained us for millennia." |
| `dwf_tome_04` | *Surface Trade Protocols* | Manual | "Surface peoples are customers, not partners. Conduct transactions efficiently. Do not engage in their politics." |
| `dwf_tome_05` | *The Rejection of Hierarchy* | Tome | "Hierarchy creates weakness and entitlement. We learned this truth in ages past and built differently." |

#### Journals & Notes

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `dwf_journal_01` | *Miner's Shift Log, Cycle 4782* | Journal | "Third rotation this season. The new vein runs deep. Good stone. Will notify the council." |
| `dwf_note_01` | *Guild Council Notice* | Scroll | "Rotation schedule updated. All smiths report to Forge Seven. No dwarf rules another—but all must work." |
| `dwf_note_02` | *Warning: Unstable Shaft* | Note | "Tunnel 14-B shows fractures. Seal until engineers approve. The stone speaks—listen." |
| `dwf_journal_02` | *Surface Trader's Account* | Journal | "Humans asked about our 'king' again. I explained rotation. They did not understand. They rarely do." |

#### Recipes

| ID | Title | Type | Unlocks |
|----|-------|------|---------|
| `dwf_recipe_01` | *Guild-Standard Alloy Formula* | Recipe | Dwarven Steel crafting |
| `dwf_recipe_02` | *Stone-Aged Preservation Method* | Recipe | Food preservation technique |
| `dwf_recipe_03` | *Tunnel-Safe Lantern Oil* | Recipe | Long-burning oil crafting |
| `dwf_recipe_04` | *Brewer's Guild Stout Formula* | Recipe | Dwarven Stout brewing |

---

### LIZARD FOLK BOOKS
*"What is hidden endures. What is revealed can be taken."*

**Naming Conventions:**
- Cryptic, partial titles
- References to rivers, sects, hidden knowledge
- Often incomplete or deliberately vague

#### Tomes & Treatises

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `liz_tome_01` | *Fragment: The Hidden Rivers* | Tome | "The corridors beneath the sand still flow. Those who know the paths drink while others thirst. This is the way." |
| `liz_tome_02` | *Observations on Imperial Collapse* | Tome | "We measured Calidar's destruction from afar. Power had escaped all restraint. We concluded such force must be constrained." |
| `liz_tome_03` | *Sect Protocols: Partial Translation* | Tome | "Information is shared deliberately and often incompletely. Preservation demands it." |
| `liz_tome_04` | *The Astronomy Sect Records* | Tome | "The stars shifted during the devastation. Old charts became unreliable. New observations were required." |

#### Journals & Notes

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `liz_journal_01` | *Caravan Master's Log* | Journal | "They do not know which sect I serve. They do not need to know. The route is secure." |
| `liz_note_01` | *Coded Message (Partial)* | Note | "[Untranslatable symbols] ...the observer reports movement in the north. Relay to the appropriate sect." |
| `liz_note_02` | *Engineer's Water Chart* | Note | "Flow rate decreased at junction seven. Check for sand intrusion. Do not share this chart." |
| `liz_journal_02` | *Burial Sect Initiate's Record* | Journal | "The dead are preserved. The memories are maintained. What we remember cannot be taken." |
| `liz_note_03` | *Warning from the Martial Sect* | Scroll | "Do not pursue. The hidden places are defended. Turn back or be turned back." |

#### Recipes

| ID | Title | Type | Unlocks |
|----|-------|------|---------|
| `liz_recipe_01` | *Desert Preservation Salts* | Recipe | Anti-decay coating |
| `liz_recipe_02` | *River Corridor Water Purification* | Recipe | Advanced water purification |
| `liz_recipe_03` | *Sect Marking Ink* | Recipe | Invisible ink crafting |
| `liz_recipe_04` | *Sand-Walker's Foot Salve* | Recipe | Desert travel buff |

---

### BEAST FOLK (CAT FOLK) BOOKS
*"Names matter. Lineage is remembered even when land is not."*

**Naming Conventions:**
- Oral traditions transcribed
- Personal, family-focused
- References to luck, roads, fortune

#### Songs & Poems

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `cat_song_01` | *The Wanderer's Lament* | Song | "We came from sands now foreign / Through borders drawn without us / The road is home, the family follows / What they take cannot be our names." |
| `cat_song_02` | *Fortune's Favorite* | Song | "Luck is not random, child / It is attention, timing, respect for risk / Watch the cards, not the dealer / The patterns speak to those who listen." |
| `cat_song_03` | *The Naming Song* | Song | "Your grandmother's grandmother walked this road / Her name was [sung] / Her mother's name was [sung] / We carry them forward." |

#### Journals & Notes

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `cat_journal_01` | *Elder Whisker's Road Diary* | Journal | "Third generation on this route. The town welcomes us in harvest, forgets us in winter. We remember." |
| `cat_note_01` | *Family Warning* | Note | "The merchant with the red cart cheated grandfather. His grandson runs the same stall. Do not trade there." |
| `cat_note_02` | *Fortune Telling Instructions* | Note | "Read their hands, but watch their eyes. The patterns are real. The showmanship is for them." |
| `cat_journal_02` | *Caravan Record* | Journal | "They call us rootless. Our roots span the continent. Theirs stop at their fences." |
| `cat_note_03` | *Card Game Observations* | Note | "The dealer shuffles poorly on the fourth round. Bet heavy on the fifth." |

#### Recipes

| ID | Title | Type | Unlocks |
|----|-------|------|---------|
| `cat_recipe_01` | *Traveler's Trail Bread* | Recipe | Long-lasting travel food |
| `cat_recipe_02` | *Fortune Teller's Incense* | Recipe | Atmosphere-enhancing incense |
| `cat_recipe_03` | *Lucky Charm Binding* | Recipe | Minor luck talisman |
| `cat_recipe_04` | *Road Spice Blend* | Recipe | Portable seasoning mix |

---

### GOBLIN BOOKS
*"They can burn our warrens. They cannot burn what we remember."*

**Naming Conventions:**
- Oral traditions, rarely written
- Found as scratched notes, charcoal writings
- References to resistance, memory, lost lands

#### Songs & Oral Traditions

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `gob_song_01` | *The Names of Lost Warrens* | Song | "Thornhollow, taken. Deepburrow, burned. Shadowmire, sealed. We sing them so they are not forgotten." |
| `gob_song_02` | *The Quiet Resistance* | Poem | "Strike and vanish / Let them guard everything / We need only strike once / The patience of stone, the silence of shadow." |
| `gob_song_03` | *Teaching Song for Younglings* | Song | "Learn the tunnels, learn the signs / One cell knows not another / Captured lips speak no names / The resistance endures." |

#### Notes & Scraps

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `gob_note_01` | *Scratched Wall Message* | Note | "Supply cart passes at third bell. Two guards. Weak axle. You know what to do." |
| `gob_note_02` | *Charcoal Map Fragment* | Map Fragment | [Visual: rough tunnel map with X marks] "Safe route. Dead drop at the bend." |
| `gob_note_03` | *Cell Leader's Instructions* | Note | "No contact with southern cell. If captured, you know nothing. You ARE nothing. Resist." |
| `gob_journal_01` | *Survivor's Account* | Journal | "They burned Thornhollow. Forty-three escaped through the back tunnels. The warren is gone. The memory lives." |
| `gob_note_04` | *Warning Sign* | Note | "HUMAN PATROL - 3 DAYS AGO - DO NOT SURFACE" |

#### Recipes

| ID | Title | Type | Unlocks |
|----|-------|------|---------|
| `gob_recipe_01` | *Tunnel Smoke Bomb* | Recipe | Escape smoke device |
| `gob_recipe_02` | *Night-Eye Fungus Paste* | Recipe | Darkvision enhancement |
| `gob_recipe_03` | *Silent Foot Wrapping* | Recipe | Stealth movement bonus |
| `gob_recipe_04` | *Ration Stretcher* | Recipe | Food efficiency buff |

---

### ORC BOOKS
*"Power is not granted by divine favor. It is demonstrated through action."*

**Naming Conventions:**
- Practical, martial focus
- References to the Khan, the road, the sky
- Laws and campaign records

#### Tomes & Manuals

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `orc_tome_01` | *The Law of the Clans* | Tome | "The law applies equally to all—including the Khan. Theft within the clan is punished. Disobedience during war is unforgivable." |
| `orc_tome_02` | *Campaigns of the Great Khan* | Tome | "Under unification, we conducted continent-spanning campaigns at unprecedented speed. Resistance was punished. Submission was rewarded." |
| `orc_tome_03` | *The Rider's Doctrine* | Manual | "Every orc is raised to ride, fight, and obey command. Speed is survival. Cohesion is victory." |
| `orc_tome_04` | *On Wars of Collapse* | Tome | "We do not fight wars of attrition. We fight wars of collapse. An enemy that loses cohesion is already defeated." |

#### Journals & Orders

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `orc_journal_01` | *Warband Leader's Log* | Journal | "The clans are fragmented, but the laws remain. The routes are remembered. The old commands are taught." |
| `orc_note_01` | *Signal Horn Instructions* | Note | "Three short blasts: regroup. One long: advance. Two long: feigned retreat. Follow without question." |
| `orc_note_02` | *Scout Report* | Note | "Human garrison at the pass. Forty men. Supply line exposed. Recommend strike at dawn." |
| `orc_journal_02` | *Shaman's Sky Reading* | Journal | "The eternal road stretches before us. The sky promises nothing but what we take. Ancestors watch." |
| `orc_scroll_01` | *Khan's Decree (Historical)* | Scroll | "All clans ride as one. Those who refuse answer to the law. No negotiation. Command." |

#### Recipes

| ID | Title | Type | Unlocks |
|----|-------|------|---------|
| `orc_recipe_01` | *Rider's Iron Ration* | Recipe | High-efficiency travel food |
| `orc_recipe_02` | *Horse Wound Salve* | Recipe | Mount healing item |
| `orc_recipe_03` | *War Paint Mixture* | Recipe | Combat intimidation buff |
| `orc_recipe_04` | *Signal Fire Compound* | Recipe | Long-range visible signal |

---

### GNOMISH BOOKS
*"The gnomes do not believe in ownership. They believe in function."*

**Naming Conventions:**
- Technical, functional titles
- Classification numbers
- Council-approved language

#### Tomes & Manuals

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `gnm_tome_01` | *Collective Resource Allocation: A Primer* | Tome | "No gnome owns land, industry, or infrastructure. All major assets belong to the people as a whole." |
| `gnm_tome_02` | *Automaton Maintenance Protocol 7.3* | Manual | "Automatons are not abominations. They are population multipliers. This classification enables 340,000 citizens to maintain industrial output." |
| `gnm_tome_03` | *Production Council Proceedings, Year 847* | Tome | "Decisions are justified through efficiency models and resource projections, not ideology or faith." |
| `gnm_tome_04` | *Airship Navigation Standards* | Manual | "Air travel enables rapid logistics, resource redistribution, and defense without mass armies. Protocols must be followed precisely." |
| `gnm_tome_05` | *On the Rejection of Hierarchy* | Tome | "The human empire represents everything we rejected: hierarchy, faith-based law, ownership-driven inequality." |

#### Technical Documents

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `gnm_note_01` | *Workshop Assignment Notice* | Scroll | "Citizen 7-4429 is reassigned to Foundry District, Sector 3. Report at dawn. Contribution is purpose." |
| `gnm_note_02` | *Efficiency Report: Rejected* | Note | "Proposal to reduce automaton workforce by 12% rejected. Human-style labor exploitation is not efficiency." |
| `gnm_journal_01` | *Engineer's Personal Log* | Journal | "Outsiders call us 'soulless technocrats.' They do not understand. We have eliminated hunger, homelessness, and poverty. What have their souls achieved?" |
| `gnm_note_03` | *Security Classification* | Note | "This document is rated Level 4. Unauthorized distribution to non-citizens is prohibited. Secrecy is class defense." |

#### Recipes

| ID | Title | Type | Unlocks |
|----|-------|------|---------|
| `gnm_recipe_01` | *Standard Alloy Composition 12-B* | Recipe | Gnomish alloy crafting |
| `gnm_recipe_02` | *Automaton Lubricant Formula* | Recipe | Machine maintenance oil |
| `gnm_recipe_03` | *Energy Cell Compound* | Recipe | Power source crafting |
| `gnm_recipe_04` | *Nutrient Block Recipe* | Recipe | Efficient survival food |

---

### HUMAN BOOKS
*Imperial, religious, and common texts*

**Naming Conventions:**
- Religious texts reference Helios
- Official documents bear imperial seals
- Common texts vary by region

#### Tomes & Treatises

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `hum_tome_01` | *The Light of Helios: A Devotional* | Tome | "In the light of Helios, all truth is revealed. In shadow, heresy festers. Seek the light." |
| `hum_tome_02` | *Imperial History, Volume VII* | Tome | "The orcish threat was contained through vigilance and faith. Let no generation forget the cost of unity." |
| `hum_tome_03` | *On the Goblin Menace* | Tome | "Vermin that infest our territories must be eradicated. They are criminals trespassing on imperial land. Extermination is civic duty, not cruelty. Helios sanctions this work." |
| `hum_tome_04` | *Merchant's Guide to the Races* | Manual | "Dwarves: reliable, strange customs. Elves: refined, condescending. Orcs: dangerous, avoid. Gnomes: secretive, valuable goods." |

#### Common Documents

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `hum_journal_01` | *Soldier's Campaign Diary* | Journal | "Third week in goblin territory. They strike and vanish. Command says it's pest control. Doesn't feel like pest control. Feels like a war we're losing. They were here first. Why are we here?" |
| `hum_note_01` | *Tavern Notice* | Note | "REWARD: 50 gold for information on goblin activity. Report to garrison. Helios protects." |
| `hum_note_02` | *Love Letter (Unsent)* | Note | "My dearest, the campaign extends another month. I dream of home. Keep the candles burning." |
| `hum_journal_02` | *Scholar's Research Notes* | Journal | "The dwarves claim to have no kings. Fascinating. Their guild system warrants further study." |

#### Recipes

| ID | Title | Type | Unlocks |
|----|-------|------|---------|
| `hum_recipe_01` | *Imperial Field Ration* | Recipe | Standard military food |
| `hum_recipe_02` | *Healer's Poultice* | Recipe | Basic healing salve |
| `hum_recipe_03` | *Temple Incense Blend* | Recipe | Holy incense crafting |
| `hum_recipe_04` | *Garrison Ale Recipe* | Recipe | Common ale brewing |

---

### ELVEN BOOKS
*Bureaucratic, archival, magical*

**Naming Conventions:**
- Formal, archival classification
- References to preservation, records, magic regulation

#### Tomes & Archives

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `elf_tome_01` | *Archive Classification: The Orcish Campaigns* | Tome | "Recorded with precision. Their tactics were effective but unrestrained. We document, we do not admire." |
| `elf_tome_02` | *On the Regulation of Magic* | Tome | "Magic must be controlled, classified, and restricted. Unregulated power destroyed Calidar. Never again." |
| `elf_tome_03` | *The Beast Folk: A Demographic Study* | Tome | "Diaspora peoples without unifying structure. Culturally resilient. Difficult to classify." |
| `elf_tome_04` | *Preservation Protocols* | Manual | "Knowledge must survive the ages. These methods ensure documents endure centuries." |

#### Documents & Notes

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `elf_journal_01` | *Archivist's Personal Notes* | Journal | "The lizard folk trader refused to explain his sect. They share deliberately and incompletely. Frustrating." |
| `elf_note_01` | *Magic Regulation Notice* | Scroll | "Practitioner license expires in 30 days. Renewal requires demonstration and oath. Comply or face sanctions." |
| `elf_note_02` | *Border Observation Report* | Note | "Orc clan movement detected. Numbers unknown. Recommend increased patrols." |

#### Recipes

| ID | Title | Type | Unlocks |
|----|-------|------|---------|
| `elf_recipe_01` | *Archive Preservation Wax* | Recipe | Document protection |
| `elf_recipe_02` | *Mana Restoration Tincture* | Recipe | Magic recovery potion |
| `elf_recipe_03` | *Moonlight Ink* | Recipe | Magic-resistant ink |

---

## ROMANCE NOVELS
*Rare collectibles found across the world*

**Rarity:** All romance novels are **Rare** or **Legendary**
**Found:** Hidden locations, merchant rare stock, quest rewards, noble estates

Romance literature varies dramatically by culture. Some races produce florid tales of passion, others practical accounts of partnership. Interspecies romances are controversial, reflecting the tensions and attractions between peoples.

---

### Single-Race Romances

#### Human Romance Novels

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `rom_hum_01` | *The Knight's Oath* | Novel | "She waited by the chapel window, counting the days since he rode east. 'Helios protect him,' she whispered, though she knew prayers would not stop orcish arrows." |
| `rom_hum_02` | *Forbidden Vows* | Novel | "He was a soldier. She was the merchant's daughter. The empire did not approve of unions that blurred the lines of station. They married anyway, in a barn, with no witness but the horses." |
| `rom_hum_03` | *The Widow's Second Spring* | Novel | "After the campaign took her husband, she swore never again. Then the traveling healer came through town, and she learned that hearts do not keep the oaths we force upon them." |

#### Elven Romance Novels

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `rom_elf_01` | *Centuries Between Us* | Novel | "He loved her for three hundred years before she noticed. She loved him for two hundred more before she admitted it. Elven courtship is patient, measured, and maddening." |
| `rom_elf_02` | *The Archivist's Heart* | Novel | "She catalogued every species in the realm, but could not classify what she felt when he entered the archive. Love, she determined, resisted proper documentation." |
| `rom_elf_03` | *A Breach of Protocol* | Novel | "Council members do not fraternize. This was policy. This was law. This was, as they discovered in the eastern stacks, entirely ignored after midnight." |

#### Orc Romance Novels

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `rom_orc_01` | *Riders Beneath the Same Sky* | Novel | "She challenged him to single combat. He yielded deliberately. 'Why?' she demanded. 'Because I would rather lose to you than live without you,' he said. She punched him. Then she kissed him." |
| `rom_orc_02` | *The Law Does Not Forbid This* | Novel | "They searched the entire legal code. Nowhere did it say a warband leader could not love another warband leader. The elders were furious anyway." |
| `rom_orc_03` | *Two Horses, One Road* | Novel | "He followed his clan. She followed hers. Every spring, the routes crossed at the river. Every spring, for forty years, they had three days. It was enough. It had to be." |

#### Cat Folk Romance Novels

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `rom_cat_01` | *The Gambler's Tell* | Novel | "She could read any face at the card table. Every twitch, every breath. But when he smiled at her, she could read nothing except the racing of her own heart." |
| `rom_cat_02` | *Roads That Cross* | Novel | "Two caravans, two families, decades of rivalry. Their parents forbade them from speaking. So they learned to speak with glances, with gestures, with notes passed beneath wagon wheels." |
| `rom_cat_03` | *Fortune Favors the Bold* | Novel | "He bet everything on a single hand. Not for gold—for the right to ask her name. He lost. She told him anyway." |

#### Gnomish Romance Novels

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `rom_gnm_01` | *Efficiency of the Heart* | Novel | "The council assigned them as partners. Purely practical. Compatible skill sets. Optimal collaboration metrics. Neither could explain why they lingered after shifts ended." |
| `rom_gnm_02` | *Unauthorized Attachment* | Novel | "Personal relationships were not forbidden. But they were not optimized either. She submitted a formal request to extend their partnership. He submitted the same request. The council noted the redundancy with what might have been amusement." |
| `rom_gnm_03` | *Sector 7, Workshop 14* | Novel | "They built automatons together for thirty years. Somewhere in the wiring and the welding, they built something else. Something the council could not classify." |

#### Goblin Romance (Oral Tradition)

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `rom_gob_01` | *The Song of Thornhollow Lovers* | Song | "Before the burning, before the flight / Two hearts beat as one in the warren's night / He said 'Come with me' and she said 'I will' / And they ran through tunnels, together still." |
| `rom_gob_02` | *Cell Leader's Secret* | Story | "She led a cell for twenty years. Fearless, they said. Cold as stone. Only one goblin knew otherwise. Only one saw her cry when the resistance succeeded. 'We won,' she said. 'Now we can finally rest.'" |

#### Lizard Folk Romance

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `rom_liz_01` | *Sect-Forbidden* | Novel | "He served the Astronomers. She served the River Engineers. The sects did not share knowledge. They did not share meals. They did not share lives. But beneath the dunes, in corridors no sect had claimed, they shared everything." |
| `rom_liz_02` | *Six Hundred Years* | Novel | "She was young—barely two centuries. He had lived through the destruction of empires. 'You cannot understand me,' he said. 'Then teach me,' she replied. He spent the next four hundred years doing exactly that." |

#### Dwarven Romance

| ID | Title | Type | Lore Snippet |
|----|-------|------|--------------|
| `rom_dwf_01` | *Shift Partners* | Novel | "They were assigned to the same rotation for efficiency. Three centuries later, they had never requested reassignment. The council assumed it was satisfaction with the work. It was not the work." |
| `rom_dwf_02` | *The Stone Does Not Judge* | Novel | "He carved. She mined. Different guilds, different schedules. They met in the deep tunnels where no schedule mattered. The stone kept their secret for two hundred years." |

---

### Interspecies Romance Novels
*Controversial, sought by collectors, banned in some regions*

| ID | Title | Races | Type | Lore Snippet |
|----|-------|-------|------|--------------|
| `rom_inter_01` | *Seventy Winters* | Human + Elf | Novel | "She aged. He did not. She knew this when they began. 'I will have you for seventy winters,' she said, 'and you will have me for eternity in memory.' He wept for the first time in three centuries." |
| `rom_inter_02` | *The Trader's Daughter* | Human + Cat Folk | Novel | "Her father traded with the caravans. He was the caravan master's son. 'Your people call us rootless,' he said. 'My roots are wherever you are,' she replied. They left together that spring." |
| `rom_inter_03` | *Against the Steppes* | Human + Orc | Novel | "He was a hostage, taken after the border skirmish. She was his keeper. 'You are supposed to hate me,' he said. 'I am supposed to guard you,' she replied. 'I was not told what to feel.'" |
| `rom_inter_04` | *The Stone and the Sky* | Dwarf + Orc | Novel | "He had never seen the open sky until the trade expedition. She had never seen the deep stone. 'How do you live beneath the earth?' she asked. 'How do you live beneath nothing?' he replied. They spent a year teaching each other." |
| `rom_inter_05` | *Different Sands* | Lizard Folk + Cat Folk | Novel | "Two desert peoples, different paths. She hid in sect secrecy. He wandered in diaspora openness. 'Teach me to hide,' he said. 'Teach me to wander,' she replied. Neither learned. Both stayed." |
| `rom_inter_06` | *The Spy and the Scholar* | Elf + Lizard Folk | Novel | "The archive sent her to study the sects. The sects sent him to observe the archive. They spent a decade pretending not to know. They spent another decade pretending it was only duty." |
| `rom_inter_07` | *Forty Years, Four Centuries* | Human + Dwarf | Novel | "She would live forty more years. He would live four hundred. 'It is inefficient,' he admitted. 'Love is not a rotation schedule,' she said. He learned she was right." |
| `rom_inter_08` | *The Warren and the Road* | Goblin + Cat Folk | Novel | "Both outcasts. Both distrusted. He hid in tunnels; she wandered open roads. They met in the spaces between—the margins where neither empire nor caravan reached. 'No one will approve,' she said. 'No one approves of us anyway,' he replied." |
| `rom_inter_09` | *Children of Function* | Gnome + Dwarf | Novel | "Two collectivist peoples, different methods. He believed in rotation; she believed in assignment. 'Your system is inefficient,' she argued. 'Your system lacks flexibility,' he countered. They debated for fifty years before realizing they had stopped arguing and started flirting." |
| `rom_inter_10` | *The Resistance and the Road* | Goblin + Human | Novel | "She was an imperial deserter. He was resistance. 'Your people burned my warren,' he said. 'My people burned my conscience,' she replied. They found something neither had expected: forgiveness." |

---

## POLITICS & WAR BOOKS
*Treatises, histories, and perspectives on conflict*

These books provide insight into the political tensions and military conflicts that shape the world. Each race has its own perspective on the same events.

---

### Imperial Politics

| ID | Title | Race | Type | Lore Snippet |
|----|-------|------|------|--------------|
| `pol_hum_01` | *On the Divine Right of Expansion* | Human | Tome | "Helios has blessed this empire with purpose. Where the light does not reach, we carry it. This is not conquest—it is salvation." |
| `pol_hum_02` | *The Goblin Question: A Policy Analysis* | Human | Tome | "Extermination has proven expensive. Containment has proven impossible. This document proposes a third option: strategic neglect of non-productive territories." |
| `pol_hum_03` | *Military Readiness Against the Orc Threat* | Human | Tome | "The clans are fragmented. This is temporary. Every garrison commander must understand: the orcs do not need to grow stronger. They only need to unite again." |
| `pol_hum_04` | *The Gnomish Heresy* | Human | Tome | "They reject Helios. They reject hierarchy. They reject the natural order. When their secrets are revealed, they must be liberated from their errors." |

### Orcish Military Treatises

| ID | Title | Race | Type | Lore Snippet |
|----|-------|------|------|--------------|
| `pol_orc_01` | *Why We Do Not Negotiate* | Orc | Tome | "The empire offers treaties. Treaties require trust. Trust requires honor. The empire has demonstrated neither. We remember every broken promise." |
| `pol_orc_02` | *The Unification Doctrine* | Orc | Tome | "Under the Great Khan, we were one. The clans squabble now, but the memory remains. When the sky darkens with banners again, we will ride as one." |
| `pol_orc_03` | *On the Weakness of Walls* | Orc | Manual | "They build castles. They build garrisons. They believe stone protects them. Stone cannot chase. Stone cannot pursue. Stone watches helplessly as we ride past." |
| `pol_orc_04` | *Integration of the Conquered* | Orc | Tome | "Resistance was punished. Submission was rewarded with protection. The humans call us savages. We absorbed more peoples peacefully than they have conquered by force." |

### Goblin Resistance Documents

| ID | Title | Race | Type | Lore Snippet |
|----|-------|------|------|--------------|
| `pol_gob_01` | *Why We Fight* | Goblin | Scroll | "They call us vermin. They invaded our lands. They massacred our warrens. They burned our children alive. We fight because they are genocidal occupiers. We fight because the empire is ILLEGITIMATE." |
| `pol_gob_02` | *The Long Memory* | Goblin | Tome | "Every injustice is recorded. Every massacre is remembered. Every stolen homeland is preserved. When they ask why we resist, we recite the list. It takes three days. Then we ask: why did you invade?" |
| `pol_gob_03` | *Asymmetric Principles* | Goblin | Manual | "They guard everything. We strike once. They need ten soldiers to protect what one goblin can destroy. The math favors patience. The empire bleeds gold. We bleed them." |
| `pol_gob_04` | *On Imperial Propaganda* | Goblin | Tome | "They say we raid for greed. We raid for SURVIVAL on stolen land. They say we are mindless. We have outlasted every empire that tried to exterminate us. Who lacks a mind? Who will still be here in a thousand years?" |
| `pol_gob_05` | *No One Is Illegal On Stolen Land* | Goblin | Scroll | "The empire criminalizes our existence on ancestral territory. They call us trespassers in mines our ancestors dug. Imperial law is the language of thieves. We do not recognize its authority." |
| `pol_gob_06` | *On Collaboration* | Goblin | Scroll | "Goblins who cooperate with the empire are traitors to their species. Collaboration is extinction. Better to die resisting than live as slaves. We do not forget. We do not forgive." |
| `pol_gob_07` | *The Empire Cannot Win* | Goblin | Tome | "They cannot eradicate us without depopulating entire regions. We have nothing left to lose. We have multi-generational commitment. We know every tunnel. The empire cannot win. It can only bleed." |

### Elven Political Analysis

| ID | Title | Race | Type | Lore Snippet |
|----|-------|------|------|--------------|
| `pol_elf_01` | *Balance of Powers: Current Assessment* | Elf | Tome | "The empire expands. The orcs fragment. The gnomes hide. The dwarves isolate. Stability requires none to gain decisive advantage. Our role is to ensure this." |
| `pol_elf_02` | *The Problem of Faith-Based Governance* | Elf | Tome | "When law derives from divine mandate, it cannot be questioned. When it cannot be questioned, it cannot be corrected. The empire's greatest strength is its greatest flaw." |
| `pol_elf_03` | *On the Regulation of Destructive Force* | Elf | Tome | "Unregulated power destroyed Calidar. The empire builds weapons of faith. The gnomes build weapons of function. Both must be monitored. Both must be constrained." |

### Gnomish Political Documents

| ID | Title | Race | Type | Lore Snippet |
|----|-------|------|------|--------------|
| `pol_gnm_01` | *Why We Hide* | Gnome | Tome | "The empire would liberate us from equality. They would gift us with hierarchy, with priests, with owners. We refuse this gift. Secrecy is class defense." |
| `pol_gnm_02` | *External Threat Assessment, Year 851* | Gnome | Tome | "Human expansion continues. Probability of discovery within two centuries: 34%. Recommended response: accelerate automaton production, reinforce coastal defenses." |
| `pol_gnm_03` | *The Failure of Individual Ownership* | Gnome | Tome | "The empire's citizens starve beside full granaries. Their poor freeze beside empty homes. Ownership creates artificial scarcity. We have eliminated this inefficiency." |

### Dwarven Perspectives

| ID | Title | Race | Type | Lore Snippet |
|----|-------|------|------|--------------|
| `pol_dwf_01` | *Surface Politics: Why We Do Not Engage* | Dwarf | Tome | "They fight over crowns. They kill for thrones. They worship gods who demand obedience. We build. Let them exhaust themselves. The holds endure." |
| `pol_dwf_02` | *Trade Relations Assessment* | Dwarf | Tome | "Humans: reliable customers, unstable politics. Elves: precise negotiations, slow payment. Orcs: honor agreements, unpredictable availability. Gnomes: excellent goods, secretive terms." |

### Lizard Folk Observations

| ID | Title | Race | Type | Lore Snippet |
|----|-------|------|------|--------------|
| `pol_liz_01` | *Sect Report: Imperial Expansion Patterns* | Lizard Folk | Tome | "The empire moves predictably. Faith justifies conquest. Conquest enables extraction. Extraction funds faith. The cycle continues until resources exhaust. We have seen this before." |
| `pol_liz_02` | *On the Necessity of Intervention* | Lizard Folk | Tome | "We do not seek conflict. We seek prevention. A single decision, made by a single person, destroyed Calidar. The sects exist to ensure such decisions are never made again." |

### War Histories

| ID | Title | Race | Type | Lore Snippet |
|----|-------|------|------|--------------|
| `war_hum_01` | *The Third Orc War: An Imperial Account* | Human | Tome | "Victory was achieved through Helios' blessing and the sacrifice of seventeen legions. The border holds. For now." |
| `war_orc_01` | *The Third Human War: A Clan Account* | Orc | Tome | "They call it victory. We call it stalemate. Their legions broke against our riders. Their supplies failed. They retreated behind walls and called it winning. We remember differently." |
| `war_hum_02` | *Campaigns Against the Goblin Infestation* | Human | Tome | "Forty-seven warrens cleared in the eastern territories. Cost: 12,000 soldiers, 8 million gold. Result: Forty-seven new warrens appeared within the year. The quartermasters call it 'the budget black hole.' Command calls it 'pest control.' Soldiers call it hell." |
| `war_gob_01` | *The Eastern Cleansing: Survivor Accounts* | Goblin | Tome | "The empire calls it 'clearing infestation.' We call it genocide. Forty-seven warrens. Thousands dead. Children burned alive. Elders executed. They declared victory. We declared vengeance. We are still here. They are still dying. The occupation continues. So does the resistance." |
| `war_elf_01` | *The Unification War: Archival Analysis* | Elf | Tome | "Under the Great Khan, the orc clans conquered more territory in three decades than the empire has in three centuries. We do not admire. We document. We prepare." |

---

## HEAVEN'S ATLAS BOOKS
*Fragments, rumors, and terrified speculation*
*All books regarding the Atlas are Rare or Legendary*

**What is Known:**
- Heaven's Atlas destroyed Calidar
- The destruction was witnessed by the lizard folk astronomers
- Rivers vanished. Star alignments shifted. An entire civilization ended.
- The Veiled Hand was founded to prevent its use again

**What is NOT Known:**
- What the Atlas actually is
- Who built it
- Where it is now
- How it works

These books provide fragments, rumors, and speculation—never concrete answers.

---

### Fragments and Speculation

| ID | Title | Race | Type | Lore Snippet |
|----|-------|------|------|--------------|
| `atlas_01` | *The Calidar Event: What We Measured* | Lizard Folk | Tome | "The sky brightened. Our instruments recorded a pulse of energy that defied classification. When the light faded, Calidar was ash. Rivers that had flowed for millennia vanished from our charts. We do not know what caused this. We know only that it must never happen again." |
| `atlas_02` | *Fragment: A Scholar's Last Letter* | Human | Note | "I have found references to something called the Atlas. The texts are incomplete, burned, or deliberately destroyed. Someone does not want this knowledge preserved. I fear I am being watch—" [Letter ends abruptly] |
| `atlas_03` | *The Wastes of Calidar: Expedition Report* | Elf | Tome | "Nothing grows. The sand has fused to glass in patterns that suggest unimaginable heat. We found no bodies—not because they were removed, but because nothing remained to find. Whatever happened here was absolute." |
| `atlas_04` | *Rumors of the Atlas* | Human | Journal | "The tavern drunk spoke of a weapon. 'Heaven's Atlas,' he called it. 'Points at anything in the world and erases it.' I dismissed him as mad. Then I researched Calidar. Now I cannot sleep." |
| `atlas_05` | *Sect Warning: Forbidden Topic* | Lizard Folk | Scroll | "Discussion of the Atlas is restricted to Tier 7 initiates and above. Unauthorized inquiry will result in immediate reassignment. Protective measure. Some knowledge is dangerous to possess." |
| `atlas_06` | *Imperial Archive: Restricted Section* | Elf | Note | "File 447-C has been removed by order of the High Council. Contents: theoretical analysis of directed energy phenomena. Reason for removal: public safety. Note: Three archivists who accessed this file have since died under unclear circumstances." |
| `atlas_07` | *The Astronomers' Silence* | Lizard Folk | Tome | "We watched the stars shift. We recorded the impossible. And then we stopped recording. Some of our sect believe we should share what we know. Most believe that sharing would only teach others how to repeat the catastrophe. We remain silent. The silence protects." |
| `atlas_08` | *A Merchant's Account* | Human | Journal | "I traded in the eastern markets for thirty years. Once, only once, an old man offered to sell me 'a map to Heaven's Atlas.' I laughed. He did not. 'Your empire would pay anything for this,' he said. I reported him to the authorities. He was gone by morning. No trace. No records." |
| `atlas_09` | *Gnomish Analysis: The Calidar Paradox* | Gnome | Tome | "Our calculations suggest the energy required to cause the observed destruction exceeds any known mechanism by several orders of magnitude. Either our physics is incomplete, or something exists that operates outside physical law. Neither conclusion is acceptable. Both may be true." |
| `atlas_10` | *The Veiled Hand Charter (Partial)* | Lizard Folk | Scroll | "We witnessed annihilation. We concluded that power beyond restraint cannot be confronted through armies or diplomacy. Those who would use such power must be removed before they can act. This is our purpose. This is our oath. [Remainder deliberately obscured]" |
| `atlas_11` | *Whispers from the Wastes* | Human | Journal | "The prospectors who venture into the Calidar wastes tell stories. They say the glass sings at night. They say shapes move beneath the fused sand. They say they hear whispers that speak in languages no living creature uses. I believe they are mad. I also believe they heard something." |
| `atlas_12` | *Why the Archive is Incomplete* | Elf | Tome | "Seventeen documents referencing the Calidar event have been removed from this archive. By whose authority? The records do not say. For what purpose? The records do not say. We preserve everything—except, it seems, this. Someone fears what we might learn." |
| `atlas_13` | *Orc Shaman's Vision* | Orc | Journal | "The ancestors showed me a dream. A hand reaching toward the sky. A map spread across the heavens. A finger pointing down. And then nothing. They woke me before I saw what happened. Even the dead fear to witness it twice." |
| `atlas_14` | *The Scholar Who Vanished* | Human | Note | "Brother Aldric devoted forty years to researching Calidar. He claimed to have found the truth. He requested an audience with the High Temple. He never arrived. His quarters were empty. His notes were ash. The Temple denies any knowledge of his fate." |
| `atlas_15` | *What We Do Not Speak Of* | Dwarf | Note | "The surface folk whisper of a weapon. We do not whisper. We do not speak of it at all. The deep stone remembers the trembling. Once was enough. We sealed the shafts that faced east and carved no passages in that direction. The stone advises silence. We listen." |

---

### Collection Bonus: Atlas Researcher

Collecting **10 or more Heaven's Atlas books** grants:
- Title: "Seeker of Forbidden Knowledge"
- Unlocks unique dialogue options about Calidar
- Some NPCs will refuse to speak with you
- Some NPCs will seek you out with fragments of their own
- Permanent debuff: -5% reputation with religious factions
- Permanent buff: +10% resistance to magical damage ("You have glimpsed the unthinkable")

---

## Data Structure

```lua
BOOKS = {
    {
        id = "dwf_tome_01",
        name = "On the Rotation of Labor",
        race = "dwarf",
        category = "tome",           --tome, journal, note, recipe, scroll, song, manual, map
        rarity = "uncommon",         --common, uncommon, rare, legendary
        pages = {
            "A dwarf's value is their contribution. This principle governs all assignment of duties within the holds.",
            "No dwarf rules another. Tasks are assigned by necessity and rotated to ensure fairness.",
            "Leadership positions rotate by schedule, not election or inheritance. Mastery earns respect, not privilege.",
        },
        loreValue = 10,              --XP or reputation gained from reading
        isRecipe = false,
        unlocks = nil,               --Recipe unlock ID if applicable
        foundLocations = {"dwarven_mountains", "trade_posts", "dungeon_treasure"},
        icon = "assets/icons/books/tome_dwarf.png",
    },

    {
        id = "gob_recipe_02",
        name = "Night-Eye Fungus Paste",
        race = "goblin",
        category = "recipe",
        rarity = "rare",
        pages = {
            "Ingredients: Cave fungus (3), Bat guano (1), Clean water",
            "Grind fungus in darkness. Mix with guano. Apply to eyes before patrol.",
            "Warning: Causes temporary blindness in sunlight. Use only underground.",
        },
        loreValue = 5,
        isRecipe = true,
        unlocks = "nighteye_paste",
        foundLocations = {"goblin_caves", "abandoned_mines", "sewer_tunnels"},
        icon = "assets/icons/books/scroll_goblin.png",
    },
}
```

---

## Player Collection System

### Collection UI

```
+--------------------------------------------------+
|  LIBRARY                              [X] Close  |
+--------------------------------------------------+
|  [Books] [Notes] [Recipes] [All]                 |
|  Found: 23/156                                   |
+--------------------------------------------------+
|  DWARVEN (5/24)                                  |
|  [*] On the Rotation of Labor                    |
|  [*] Miner's Shift Log, Cycle 4782               |
|  [ ] The Stone-Born Emergence                    |
|  [ ] ???                                         |
|                                                  |
|  GOBLIN (3/18)                                   |
|  [*] The Names of Lost Warrens                   |
|  [*] Scratched Wall Message                      |
|  [ ] ???                                         |
+--------------------------------------------------+
|  Selected: On the Rotation of Labor              |
|  [Read] [Mark Favorite]                          |
+--------------------------------------------------+
```

### Reading Interface

```
+--------------------------------------------------+
|  ON THE ROTATION OF LABOR                        |
|  Dwarven Tome                     Page 1 of 3    |
+--------------------------------------------------+
|                                                  |
|  "A dwarf's value is their contribution.         |
|   This principle governs all assignment          |
|   of duties within the holds.                    |
|                                                  |
|   We do not ask what a dwarf owns.               |
|   We ask what a dwarf has built."                |
|                                                  |
|                                                  |
+--------------------------------------------------+
|  [< Prev]  Page 1 of 3  [Next >]  [Close]        |
+--------------------------------------------------+
```

---

## Gameplay Integration

### Discovery Methods

| Method | Implementation |
|--------|----------------|
| **Loot Drops** | Enemies drop race-appropriate books |
| **Treasure Chests** | Dungeon chests contain books |
| **Merchants** | Book sellers in major cities |
| **Quest Rewards** | Story quests grant unique books |
| **Exploration** | Hidden areas contain rare books |
| **Corpse Loot** | Dead NPCs may carry notes/journals |

### Benefits of Collection

| Benefit | Description |
|---------|-------------|
| **Lore XP** | Reading grants small XP rewards |
| **Recipe Unlocks** | Recipe books unlock crafting options |
| **Faction Reputation** | Reading a race's books can boost reputation |
| **Achievement System** | "Collect all Dwarven books" achievements |
| **Stat Bonuses** | Complete collections grant permanent buffs |
| **Dialogue Options** | Knowledge unlocks new conversation choices |

### Collection Bonuses

| Collection | Bonus |
|------------|-------|
| All Dwarven Books | +5% crafting quality |
| All Goblin Books | +10% stealth damage |
| All Orc Books | +5% mounted combat |
| All Lizard Folk Books | +10% desert survival |
| All Cat Folk Books | +5% gambling luck |
| All Gnome Books | +5% automaton damage |
| All Human Books | +5% reputation gain |
| All Elf Books | +5% magic efficiency |
| All Romance Novels | Title: "Hopeless Romantic" + special vendor dialogue |
| All Interspecies Romances | Title: "Worldly Heart" + faction reputation penalties reduced by 10% |
| All Politics & War Books | +5% XP from combat encounters |
| 10+ Heaven's Atlas Books | Title: "Seeker of Forbidden Knowledge" (see Atlas section) |
| Complete Library | Title: "Scholar" + permanent +10 INT + secret ending unlock |

---

## Implementation Notes

### File Structure

```
books/
  ├── book_data.lua          (All book definitions)
  ├── book_ui.lua            (Library UI and reading interface)
  ├── book_discovery.lua     (Drop tables and discovery logic)
  └── assets/
      └── icons/
          └── books/
              ├── tome_dwarf.png
              ├── tome_human.png
              ├── scroll_goblin.png
              └── ...
```

### Save Data

```lua
PlayerData.books = {
    collected = {"dwf_tome_01", "gob_note_01", ...},
    read = {"dwf_tome_01", ...},
    favorites = {"cat_song_01", ...},
    completedCollections = {"dwarven", ...},
}
```

---

## Future Expansion Ideas

1. **Book Trading** - Trade duplicates with NPCs
2. **Forgeries** - Some books are fake, testing player knowledge
3. **Translation Quests** - Ancient texts need translation
4. **Book Crafting** - Create your own journals/notes
5. **NPC Reactions** - NPCs comment on books you carry
6. **Secret Messages** - Some books contain hidden codes

---

*Total Books Planned: 230*

**Race-Specific Collections:**
- Dwarven: 26 (includes 2 romance)
- Lizard Folk: 24 (includes 2 romance, 2 politics, 4 Atlas)
- Beast Folk (Cat): 22 (includes 4 romance)
- Goblin: 24 (includes 2 romance, 4 politics)
- Orc: 28 (includes 3 romance, 5 politics/war)
- Gnome: 24 (includes 3 romance, 3 politics, 1 Atlas)
- Human: 30 (includes 3 romance, 4 politics/war, 5 Atlas)
- Elven: 20 (includes 3 romance, 3 politics, 3 Atlas)

**Special Collections:**
- Interspecies Romance: 10
- Heaven's Atlas: 15
- Cross-Race Politics & War: 22

**Rarity Distribution:**
- Common: 45%
- Uncommon: 30%
- Rare: 20%
- Legendary: 5%

*All Romance Novels: Rare or Legendary*
*All Heaven's Atlas Books: Rare or Legendary*

---

*Document Created: January 27, 2026*
*Last Updated: January 27, 2026*

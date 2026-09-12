# Carcassonne Roguelite — Core Design Bible

**Document status:** Canonical project-memory reference for the current game concept.  
**Purpose:** Preserve the design decisions made to date so future chats can develop tile sets, Foundations, Charters, Relics, Specialists, Legendary Projects, balance, UI, and prototype runs without having to reconstruct the core rules.

---

# 1. High Concept

A peaceful, run-based tile-placement roguelite inspired by the spatial puzzle of **Carcassonne** and the build discovery / run variation of games such as **Balatro** and **Slay the Spire**.

The player begins each run with a small, simple landscape and a finite bag of square tiles. They draw from that bag, rotate and place tiles under Carcassonne-like edge-matching rules, complete features, grow settlements, develop the landscape across three Acts, raise four cumulative **Realm Tracks**, earn new tiles and rule modifiers, fulfill **Charters**, and possibly attempt a risky multi-Act **Legendary Project**.

There is **no combat** and no need for a combat analogue. The tension comes from:

- constrained tile draws;
- permanent spatial commitments;
- limited turns per Act;
- feature-completion timing;
- Specialists being tied up on unfinished features;
- evolving Charter requirements;
- the finite opportunity to reach Realm Track thresholds;
- choosing whether to specialize or pivot;
- voluntarily taking on difficult Legendary Projects;
- balancing expansion against redevelopment;
- deciding when to close a feature now versus leave it open for future growth.

The core fantasy is not defeating a threat. It is:

> **“Look at this strange little realm I made from the tiles I was given.”**

The central roguelite revelation the design should repeatedly produce is:

> **“Oh. I know what this run is now.”**

---

# 2. Core Design Pillars

## 2.1 The Map Is the Build

The realm is the run's “character.” Its build is physically visible in the landscape rather than represented primarily by an RPG sheet or abstract deck.

Roads, rivers, forests, settlements, developments, old districts, preserved land, and major projects should visibly tell the history of the run.

## 2.2 Every Tile Matters

Placement should create immediate consequences and long-term spatial commitments. Awkward holes, disconnected routes, trapped edges, and earlier planning mistakes are part of the strategic texture.

The player should not normally be able to erase a bad decision later.

## 2.3 Develop the Past; Do Not Freely Undo It

The player generally cannot correct the past. They can:

- build on it;
- reinterpret it;
- reopen and expand it;
- specialize it;
- occasionally transform it through rare explicit effects.

This preserves the meaning of early placement.

## 2.4 Builds Should Change Rules, Not Merely Numbers

The most interesting Relics, Specialists, Developments, and upgrades change what counts as a good placement.

Examples:

- Rivers count as Roads for some Trade effects.
- Old Forests can generate Culture.
- A Specialist rewards keeping a Road open longer.
- A Relic permits one mismatched edge per Act.
- Markets make certain settlement connections count differently.

Flat “+10%” bonuses should be secondary, not the core of build identity.

## 2.5 Adaptation Over Predetermination

The player may start with a biased configuration, but should usually discover the run's true identity through:

- tile rewards;
- Relics;
- Specialists;
- Charters;
- geometry;
- what the bag happens to offer.

Starting configuration should ask a question, not dictate the answer.

## 2.6 Peaceful Does Not Mean Easy

The game should be cozy in tone but strategically demanding.

Failure comes from not building effectively enough in the available time, not from armies, monsters, starvation simulations, or punitive resource upkeep.

---

# 3. Core Turn Loop

The prototype turn structure is:

1. Choose one tile from the **3-tile active hand**.
2. Rotate it freely in 90-degree increments.
3. Place it legally.
4. Optionally assign an available Specialist to an eligible unfinished feature.
5. Resolve feature completions caused by the placement.
6. Resolve Specialist effects and returns.
7. Resolve Relic effects.
8. Apply Realm Track gains.
9. Trigger and resolve any crossed Realm Track reward gates or board milestones.
10. Add any awarded tiles to the bag.
11. Draw one replacement tile into the active hand.

A normal turn should be quick:

> **Place → resolve → draw → think.**

A strong combo turn may cascade through multiple feature completions, Specialist triggers, Relic effects, Realm Track thresholds, reward choices, and new bag additions.

Those explosive turns are desirable and form part of the roguelite payoff.

---

# 4. Tile Geometry and Carcassonne DNA

## 4.1 Square Tiles Are Locked In

The game uses square tiles.

Reasons:

- four relationships per tile are easy to parse;
- 90-degree rotation is intuitive;
- roads have clear straight / bend / branch geometry;
- square geometry produces valuable awkward holes and spatial scars;
- the geometry itself remains simple while later systems become complex;
- it reinforces the Carcassonne-like foundation without requiring the entire game to remain Carcassonne-like.

Hexes were considered and rejected as the primary geometry because they increase connectivity and reduce some of the restrictive spatial pressure. Pentagons were considered as intentionally strange geometry but are unsuitable as the base grid.

Rare late-game pieces may eventually use unusual **multi-square footprints** while still obeying the square grid, such as:

- 2×2 landmarks;
- 1×2 infrastructure;
- L-shaped structures;
- long canals or aqueducts;
- multi-square Legendary Project footprints.

## 4.2 What Can Be Lifted from Carcassonne

A substantial portion of the basic placement grammar can be deliberately borrowed:

- square tiles;
- edge matching;
- Roads continuing across compatible edges;
- Settlements spreading across connected settlement edges;
- connected features being treated as one feature;
- completion when all open connections are closed;
- optional worker/Specialist commitment after placement;
- committed worker returning when the feature completes;
- monastery-like “surrounded by eight tiles” spatial puzzles.

The design should not reinvent elegant spatial rules simply to be different.

The major departures are what those features **do**, how the board **evolves**, the roguelite progression systems, and the absence of multiplayer ownership competition.

---

# 5. Three-Act Run Structure

A run consists of three continuous Acts on **one persistent map**.

The player never throws away the board and starts a new map between Acts.

The conceptual progression is:

> **Act I creates the land.**  
> **Act II develops it.**  
> **Act III transforms it.**

Prototype placement counts are currently:

| Act | Working placement count |
|---|---:|
| Act I — Founding | ~18 |
| Act II — Development | ~22 |
| Act III — Legacy | ~26 |
| **Total** | **~66** |

These numbers are **explicitly provisional** and exist only to create a testable pacing model.

## 5.1 Act I — Founding

Act I is expansion-heavy and relatively simple.

The player establishes:

- Fields;
- Forests;
- Roads;
- Rivers;
- Hamlets / basic Settlements;
- Monasteries or simple civic sites;
- the geographic skeleton of the realm.

The Act I Charter is broad and forgiving.

## 5.2 Act II — Development

Act II increases the importance of:

- Markets;
- Ports;
- Mills;
- Housing;
- Town Squares;
- advanced settlement development;
- Urban Expansion;
- light Forest development;
- road specialization;
- settlement evolution.

This is the Act in which the run's identity should become clear.

## 5.3 Act III — Legacy

Act III becomes redevelopment-heavy and introduces:

- high-tier Developments;
- Rare Developments;
- Transformations;
- advanced civic structures;
- final Legendary Project stages;
- failed-project salvage options;
- endgame specialization around the Grand Charter.

The player is now trying to turn the realm they actually built into something capable of fulfilling the final demand.

---

# 6. Charters — The “Boss” Structure

There is no combat boss.

**Charters** serve the mechanical function of roguelite boss encounters by testing whether the realm can meet a significant civic, spatial, ecological, commercial, or settlement challenge.

A Charter should generally combine:

- one or two Realm Track targets; and
- one or more physical board conditions.

A Charter should not normally be only “reach X score.”

Examples:

### Merchant Republic
- Reach a Trade target.
- Connect a required number of Settlements in one continuous network.

### Great Metropolis
- Reach a Population target.
- Build one sufficiently large City.
- Connect it to several other Settlements.

### Garden Kingdom
- Reach a Population target.
- Preserve a specified amount of Forest / natural terrain.

### Pilgrimage
- Reach a Culture target.
- Connect several cultural sites through one Road network.

### Great Census
- Reach a high Population target.
- Ensure all major Settlements are connected.

### World's Fair
- Reach a Culture or Population target.
- Build a City containing a required number of distinct Development types.

## 6.1 Charter Randomness Philosophy

The Grand Charter should be unpredictable but not arbitrarily hostile.

Guiding principle:

> **A Charter may challenge the player's build, but should rarely invalidate it.**

The selection system should allow:

- some Charters that strongly align with the current build;
- some that require a meaningful pivot;
- a smaller number that are awkward but realistically achievable.

The game should sometimes produce the joyous roguelite moment where the final Charter is already nearly solved by the player's build, and sometimes the “I can still pull this off, but I need to change direction now” moment.

## 6.2 Act I Charter

- Revealed **before the opening hand**.
- Broad, forgiving, and readable.
- Fulfillment gives a meaningful reward.
- Exceeding gives an additional bonus.
- Failure does **not** end the run.
- Failure should not add an extra punishment beyond the missed reward.

Example structure:

> Population 20 = Fulfill  
> Population 30 = Exceed  
> Complete at least 2 Settlements

## 6.3 Act II Charter

- Revealed at the Act I → Act II transition.
- More specialized.
- Combines Realm Tracks with board-state requirements.
- Its reward is the largest guaranteed power spike before Act III.
- Exceeding can award additional Rare / Relic / Specialist opportunities.

## 6.4 Grand Charter

At the **start of Act II**, the player receives a broad forecast of the final Charter, such as:

> “The final evaluation will emphasize Population or Culture.”

The exact Grand Charter is revealed around the **midpoint of Act II**.

This gives enough time to pivot while preserving uncertainty.

Act III has no separate ordinary Charter. The Grand Charter is the final objective.

At the end of Act III:

- **Fulfilled:** run victory.
- **Exceeded:** victory with an Exemplary-style distinction and possible additional meta reward.
- **Failed:** the realm is still fully scored, records and unlocks still resolve, but the run is marked as a Charter Failure.

Failure should feel like:

> “I missed the final goal.”

not:

> “The civilization is erased because I lost.”

---

# 7. The Four Realm Tracks — Locked

The game has exactly four core Realm Tracks:

1. **Population**
2. **Trade**
3. **Culture**
4. **Ecology**

There is no Prosperity track.

There are no spendable resource currencies such as Food, Wood, Stone, Gold, or Mana.

## 7.1 Realm Tracks Are Cumulative, Not Spendable

Tracks only go upward during a run.

The player never spends Population, Trade, Culture, or Ecology.

They represent cumulative achievement and are used for:

- in-run reward gates;
- Charter requirements;
- final realm description / scoring;
- personal records;
- global unlock conditions.

A track means:

> “This realm has accomplished this much of this thing.”

## 7.2 Population

Represents:

- settlement;
- density;
- growth;
- how much civilization the landscape supports.

Spatial identity:

> **How much civilization have you supported?**

Population should come primarily from Settlements and the landscape supporting them, especially Fields and Rivers.

A high-Population realm should visibly contain:

- many inhabited areas;
- large Settlements;
- dense urban development;
- or some combination of these.

## 7.3 Trade

Represents:

- connectivity;
- Road networks;
- Markets;
- Ports;
- routes between Settlements;
- movement across the realm.

Spatial identity:

> **How well have you connected it?**

Trade should be heavily network-dependent.

A high-Trade realm should visibly contain:

- Roads;
- junctions;
- Markets;
- Ports;
- multiple connected Settlements;
- meaningful route structure.

## 7.4 Culture

Represents:

- civic identity;
- knowledge;
- religion;
- heritage;
- monuments;
- historical continuity;
- significant places.

Spatial identity:

> **What has your civilization created, remembered, and become?**

Culture is especially useful for exploiting the three-Act history of the map.

Potential Culture sources include:

- Monasteries;
- Plazas;
- Universities;
- Historic Districts;
- Monuments;
- old Roads;
- preserved Act I features;
- Ancient Groves;
- Settlements that have evolved across multiple Acts.

## 7.5 Ecology

Represents:

- preservation;
- natural continuity;
- healthy Forests;
- Rivers;
- Wetlands;
- low-impact development;
- leaving valuable land intact.

Spatial identity:

> **How much of the natural world still thrives alongside civilization?**

Ecology should often reward restraint rather than constant development.

It should create opportunity-cost tension with Population and Trade without numerically subtracting from those tracks.

## 7.6 Tracks Must Encourage Different Spatial Behaviors

This is a hard design rule.

If every “good” placement increases all four tracks, the tracks are just one score split into four colors.

Examples of desired tension:

- dense Cities are strong for Population and potentially Culture;
- Roads are strong for Trade but may fragment natural features;
- preserved Forest / Wetland corridors are strong for Ecology but occupy land that could have been developed;
- old preserved features can bridge Culture and Ecology;
- Markets and Ports can bridge Population / Trade;
- Relics can deliberately create unusual cross-track synergies.

## 7.7 Board Statistics Are Not Realm Tracks

Many important accomplishments remain physical map facts:

- Largest Settlement;
- Longest Road;
- Largest Forest;
- Longest River;
- number of Settlements;
- number of connected Settlements;
- number of preserved Act I tiles;
- district diversity;
- number of cultural sites;
- number of bridges;
- number of River Settlements.

Charters and unlocks should combine Realm Tracks with these map facts.

---

# 8. Realm Track Reward Gates

Realm Track thresholds are the game's primary “economy.”

The player raises Tracks by building the realm. At thresholds, the game gives new opportunities.

Example placeholder progression:

> 20 → reward  
> 40 → reward  
> 70 → reward  
> 100 → reward

These exact values are **prototype placeholders only**.

The thresholds do not reset between Acts.

If one effect jumps across multiple thresholds, all crossed rewards trigger.

Example:

> Population 64 → 103

should trigger both the 70 and 100 Population gates.

Reward types can vary by threshold:

- small tile reward;
- Development choice;
- Specialist offer;
- Relic offer;
- powerful advanced reward.

Track-specific reward pools should be weighted thematically but not rigidly locked to one archetype.

---

# 9. Starting Configurations — “Foundations,” Not Player Classes

Traditional RPG-style player classes are rejected as the primary run-selection model.

The preferred model is closer to **Balatro's decks**: the player chooses a starting configuration that changes the rules and starting tile mix.

Working term: **Foundation**.

A Foundation may determine:

- starting bag composition;
- starting tile / seed landscape;
- one persistent Realm Rule;
- occasional starting Specialist or rule exception;
- a distinctive downside or constraint.

The Foundation creates an opening bias, not a predetermined build.

## 9.1 Example Foundation Concepts

Potential future set:

- **Homestead** — neutral baseline.
- **Riverlands** — more Rivers and river-friendly rules.
- **Crossroads** — Road / connection bias.
- **Deepwood** — more Forests, fewer Farms, preservation bias.
- **Highlands** — Mountains / constrained development.
- **Old Country** — more developed starting Settlements, less easy expansion.
- **Frontier** — basic bag, stronger rewards for undeveloped expansion.
- **Archipelago** — Water-heavy geography, Ports / Bridges available early.

These are concepts, not fully designed final Foundations.

## 9.2 Foundation Progression Philosophy

Foundations should mostly share the same global unlock pool.

Do not rigidly tie all future rewards to the chosen Foundation.

The player should still be able to begin Riverlands and end with:

- a Trade metropolis;
- an ecological river civilization;
- a Culture-heavy monastery network;
- or something unexpected.

Meta unlocks can include new Foundations for demonstrating mastery of certain map systems.

---

# 10. Tile Collection and Meta Unlock Philosophy

The current content target is approximately:

- **72 core tile designs**
- around **24 available at the beginning**
- around **48 unlocked through play**

This is a **working content target**, not a balance-critical rule.

The starting set must contain the game's complete basic vocabulary. Unlocks add specialization, complexity, and unusual interactions rather than essential missing functionality.

An indicative eight-category unlock structure was discussed:

- Population;
- Agriculture / rural development;
- Trade;
- Roads / infrastructure;
- Rivers / water;
- Forests / Ecology;
- Industry / Highlands;
- Culture / Legacy.

However, because the final four Realm Tracks are now Population / Trade / Culture / Ecology, later content design may reorganize these categories. The important principle is the meta progression, not the exact eight-column scheme.

## 10.1 Unlocks Do Not Automatically Pollute Every Run

Unlocking a tile globally means:

> **This tile may now become available in future runs.**

It does **not** mean:

> **This tile is automatically added to every future starting bag.**

Otherwise meta progression would make future bags less coherent.

Unlocked content expands the possibility space rather than acting as permanent stat power.

---

# 11. The Run Pool, Bag, Hand, and Reserve — Locked Prototype Structure

There are three distinct concepts:

## 11.1 Global Collection

Everything the player has unlocked across all runs.

## 11.2 Run Pool

A semi-random subset of unlocked designs that are eligible to appear during this particular run.

The run pool may include:

- always-eligible core pieces;
- Foundation-guaranteed thematic pieces;
- a random selection from the global collection;
- Act-gated advanced designs.

A fully progressed player might own 72 designs while a given run only has around 30–35 eligible designs.

This keeps individual runs coherent.

## 11.3 Physical Tile Bag

The bag contains **finite physical copies** of tile designs.

If a reward says:

> Add 3 Markets

there are literally three Market copies added to the remaining bag.

The player can inspect bag composition at any time but cannot normally see draw order.

The bag persists through all three Acts.

It is **not** discarded or rebuilt at an Act transition.

The bag may eventually contain more tiles than the run has remaining placements; therefore acquiring a tile increases probability but does not guarantee that every copy will be drawn.

---

# 12. Hand and Draw Rules — Locked Prototype Structure

## 12.1 Active Hand

The player has **3 active tiles**.

At the beginning of the run:

> Draw 3.

Each turn:

> Place 1 → draw 1 replacement.

The two tiles not chosen remain in hand.

This means repeatedly avoiding an awkward tile effectively reduces the player's usable hand size.

That pressure is intentional.

## 12.2 Reserve

The player has **1 Reserve slot**.

If the Reserve is empty, the player may move one active tile into Reserve and draw a replacement.

The reserved tile stays until it is eventually placed.

The Reserve is not a discard pile.

This creates long-term planning and a meaningful cost to preserving a useful future piece.

## 12.3 Survey

Baseline:

> **1 Survey per Act**

A Survey discards one active hand tile and draws a replacement.

Unlimited discard/redraw is rejected because it would undermine the bag and spatial constraints.

Foundations, Specialists, and Relics may modify Survey rules.

## 12.4 Literally Impossible Tiles

If a tile has **zero legal placements anywhere**, it may be automatically cycled without consuming a Survey.

The distinction is:

- “I dislike every legal placement” = gameplay.
- “No legal placement exists” = procedural failure that should not punish the player.

## 12.5 One Unified Bag

Expansion and Development tiles share the same bag.

This is preferred over separate “Land” and “Development” decks because the player must decide whether a turn expands the realm or develops something already built.

This keeps the game adaptive rather than turning it into a city-builder action menu.

## 12.6 Approximate Act Mix

Working conceptual mix:

| Act | Expansion | Development / Transformation |
|---|---:|---:|
| Act I | ~85% | ~15% |
| Act II | ~60% | ~40% |
| Act III | ~40% | ~60% |

These percentages are **provisional**.

The actual bag composition also changes based on player reward choices.

## 12.7 Future Draw Information

Draw order is normally hidden.

Previewing / reordering future tiles is excellent space for:

- Relics;
- Specialists;
- Foundation rules.

## 12.8 Hand Size Is Powerful

Increasing from 3 to 4 active tiles is a major effect and should be treated accordingly.

Extra hand size, extra Reserve slots, extra Surveys, and preview effects are strong rule modifiers rather than routine bonuses.

---

# 13. In-Run Tile Rewards

Tile rewards are not purchases. There is no shop required and no currency used to buy them.

The player earns opportunities by building the realm.

Primary sources:

- Realm Track reward gates;
- Charter rewards;
- exceptional board milestones;
- contextual discoveries/events if later added.

## 13.1 Acquiring a Tile Usually Means Acquiring a Design + Copies

Typical reward:

> **Market acquired for this run**  
> Add 3 Market tiles to the bag.

Common / infrastructure pieces may add more copies.

Specialized pieces may add fewer.

Powerful Rare pieces may add one.

This is a natural rarity / frequency system.

## 13.2 Rewards Enter the Bag Before the End-of-Turn Replacement Draw

If the player earns Markets on a turn, those Markets are added before drawing the replacement tile.

Therefore the newly acquired design can immediately appear.

This creates satisfying immediacy.

## 13.3 Reward Strength Variations

Normal:

> Add 3 Markets to the bag.

Stronger:

> Add 3 Markets and draw one immediately.

Major:

> Place one Market now, then add 2 to the bag.

## 13.4 Contextual Reward Offers

Reward offers should be weighted by what the player has built, but not completely deterministic.

A useful pattern:

- one strongly synergistic option;
- one broadly useful option;
- one wildcard / pivot option.

The system should not repeatedly offer three literally unusable Developments.

## 13.5 Bag Manipulation Is Part of Build Crafting

Possible effects include:

- remove basic tiles;
- replace all members of a tile family;
- duplicate a tile;
- increase frequency of a family;
- upgrade basic copies into advanced copies;
- preview or reorder upcoming pieces.

The player is curating the vocabulary from which their landscape can be built.

---

# 14. Feature Completion — Prototype Rules

The exact balance will only emerge through playtesting.

The current purpose is to give the prototype a coherent scoring language.

Working scoring scale:

- **1–3** = small contribution;
- **4–8** = normal completed feature;
- **10–15** = strong feature;
- **20+** = exceptional / late-game combo.

## 14.1 Settlement

Prototype baseline:

> **Completed Settlement: +2 Population per Settlement tile**

Simple support bonuses:

- +1 Population per adjacent Farm;
- +1 Population per adjacent River tile.

These numbers are explicitly provisional.

## 14.2 Road

Prototype baseline:

> **Completed Road: +1 Trade per Road tile +2 Trade per distinct connected Settlement**

This makes useful connections matter more than road spam.

## 14.3 Forest

Prototype baseline:

> **Completed Forest: +1 Ecology per Forest tile**

Simple preservation bonus:

> +2 Ecology if the Forest is undeveloped.

## 14.4 Monastery / Isolated Civic Site

Prototype baseline:

> **Completed Monastery: +5 Culture +1 Culture per surrounding natural tile**

The classic Carcassonne “surrounded by eight” enclosure can be used as the completion structure.

## 14.5 River

Prototype baseline:

> **Completed River: approximately +1 Ecology per 2 River tiles**

Rivers should eventually have their own completion identity rather than merely functioning as blue Roads.

## 14.6 Fields

Fields are expected to function primarily as **support terrain**, not as Carcassonne-style endgame field scoring.

They may support:

- Population;
- River agriculture;
- settlement growth;
- specific Developments.

Fields may not require a conventional “completion” state.

## 14.7 No Passive Per-Turn Production

The game should generally avoid:

> “Farm produces +1 every turn.”

Most Track gains should happen when something meaningful happens:

- feature completion;
- Development placement;
- upgrade;
- Act transition;
- Relic trigger;
- Specialist resolution;
- board milestone.

This keeps the game punchy rather than production-cycle-driven.

## 14.8 Basic Track Associations

Early game should teach clean associations:

- Settlement → Population
- Road → Trade
- Forest → Ecology
- Monastery / civic site → Culture

Later content increasingly creates hybrid scoring.

---

# 15. Specialists — Locked System Direction

Specialists preserve the Carcassonne meeple feeling while becoming a roguelite build system.

Core rule:

> **Specialists are limited, reusable board pieces that become temporarily unavailable when committed to unfinished features. Their abilities reward or alter the spatial thing they are assigned to.**

## 15.1 Starting Pool

Current preferred prototype:

- start with **2 generic Stewards**;
- a third may become obtainable during the run;
- around **3 total** should normally be the maximum.

A tiny pool makes commitment meaningful.

## 15.2 Generic Steward

A generic Steward can be assigned to an unfinished feature and produce a modest feature-appropriate bonus when it completes.

Later reward choices can train Stewards into Specialists.

## 15.3 Training

A reward may offer:

> **Train a Steward — choose 1 of 3 Specialists.**

The Steward permanently becomes that Specialist for the remainder of the run.

## 15.4 Specialist Lifecycle

Typical flow:

1. Place tile.
2. Assign Specialist to eligible unfinished feature.
3. Specialist remains committed while the feature is open.
4. Feature completes.
5. Specialist effect resolves.
6. Specialist returns to availability.

Specialists do **not** automatically refresh at Act transitions.

A Specialist stranded on an unfinished Road at the end of Act I remains stranded in Act II.

## 15.5 Specialist Design

Each Specialist should remain compact:

- where they may be assigned;
- one meaningful effect.

Avoid stat sheets and large skill trees.

## 15.6 Example Specialist Concepts

### Merchant
Assign to a Road.  
On completion, gain additional Trade for connected Settlements.

### Naturalist
Assign to a Forest / Wetland.  
On completion, gain Ecology based on size or preservation.

### Architect
Assign to a Settlement.  
On completion, gain Culture based on Development diversity.

### Homesteader
Assign to Settlement / agricultural feature.  
Gain Population based on supporting countryside.

### Riverkeeper
Assign to a River.  
Generate Ecology and/or Trade based on river relationships.

### Historian
Assign to a Settlement.  
Generate Culture from older tiles / growth history.

### Cartographer
Assign to a Road.  
Rewards keeping the Road open and making it unusually long.

### Forester
Assign to a Forest.  
Rewards large connected Forests.

### Harbormaster
Assign to Port / River.  
Rewards water-connected Settlements.

### Gardener
Supports Population + Ecology mixed development.

### Engineer
Alters connectivity or feature-completion rules.

### Conservator
Alters preservation / development rules.

## 15.7 Push-Your-Luck Specialists

Some Specialists should deliberately tempt the player to keep a feature open longer for a stronger eventual payoff.

This creates excellent opportunity-cost tension because the Specialist remains unavailable the entire time.

## 15.8 Retraining

Retraining is possible but uncommon.

A reward might allow:

> **New Appointment — retrain one Specialist.**

This allows adaptation without making commitment meaningless.

## 15.9 No Generic Numeric Leveling

Avoid:

> Merchant I → II → III, +10% → +20% → +30%

If advanced versions exist, they should change behavior, not simply inflate numbers.

---

# 16. Relics — Locked System Direction

Relics are persistent run-wide rule modifiers.

Core distinction:

- **Specialists** change what happens when a limited piece is committed somewhere.
- **Relics** change the rules the whole realm follows.

Core Relic standard:

> **A good Relic should change what the player considers a good tile placement.**

## 16.1 Relic Capacity

Current locked prototype progression:

- **Act I:** 2 active Relic slots
- **Act II:** 4 active Relic slots
- **Act III:** 5 active Relic slots

Opening a slot does not automatically grant a Relic.

When slots are full, the player may replace an existing Relic or decline the new one.

## 16.2 Relic Acquisition

Main sources:

- Realm Track milestones;
- Charter rewards;
- major board accomplishments.

There is no shop / currency requirement.

## 16.3 Relic Families

### Conversion Relics
Make one kind of achievement feed another Track.

Example:
> Forests containing a Monastery generate Culture as well as Ecology.

### Conditional Multiplier Relics
Amplify a specific spatial pattern.

Example:
> Trade from a Road is doubled if the Road contains two junctions.

### Geometry Relics
Change placement / connectivity rules.

Example:
> Once per Act, place a tile with exactly one mismatched edge.

### Bag Manipulation Relics
Change draw probabilities, copying, removal, preview, or ordering.

### Specialist Relics
Modify Specialist commitment, retraining, sharing, return rules, etc.

### Temporal / Act Relics
Care about when a tile or feature entered the realm.

Example:
> Act I Forests preserved into Act III generate additional Culture / Ecology.

## 16.4 Relic Tiers by Act Eligibility

Prefer thematic Act eligibility over generic videogame rarity colors:

- **Foundational** — can appear in Act I.
- **Developed** — Act II onward.
- **Legacy** — Act III / major rewards.

## 16.5 Rule-Based Drawbacks

Some Relics may include drawbacks, but prefer opportunity / rule tradeoffs over numeric subtraction.

Example:

> Sacred Wilderness  
> Forests gain greatly increased Ecology and Culture, but ordinary Developments can no longer be placed within them.

## 16.6 Build-Around Relics

Some Relics should radically redefine the run.

Examples:

### One Great City
Only the largest Settlement generates Population, but it receives a huge multiplier.

### The Long Road
Only the longest Road generates Trade, with a large scaling bonus.

### The Green Belt
Compact Settlements surrounded by natural terrain generate Population + Ecology.

### The Old Ways
Act I tiles cannot be upgraded but gain increasing Culture / Ecology over time.

### City of Bridges
River crossings become the central engine of Population / Trade / Culture.

These are desirable because they create memorable run stories.

## 16.7 Emergent Synergies, Not Explicit Sets

Avoid:
> “Collect 3 Forest Relics for a Forest Set Bonus.”

Instead, Relics should naturally interact so the player discovers combinations.

## 16.8 Content Target

Working base-game target:

> **~50–60 Relics**

with only a subset initially unlocked.

This is a content target, not a mechanical requirement.

---

# 17. Development and Board Evolution — Locked Philosophy

The board has a **highly permanent geographic layer** and a more mutable **development layer**.

Core rule:

> **Development adds to the map. It normally does not erase the map.**

## 17.1 Geography — Highly Permanent

Examples:

- Fields;
- Forests;
- Rivers;
- Wetlands;
- Mountains;
- basic Road / Settlement connections.

These are established through Expansion tiles and normally remain.

## 17.2 Development — Mutable

Examples:

- Market;
- Housing;
- Monastery / Abbey;
- Port;
- Town Square;
- School / University;
- Forester's Lodge;
- civic structures.

Developments sit on eligible existing tiles / features.

## 17.3 Transformation — Exceptional

Transformations can alter underlying geography or edge logic.

Examples:

- Canal;
- Bridge;
- Rewilding;
- Land Reclamation;
- Urban Expansion;
- Reservoir.

These are rare, constrained, and powerful.

## 17.4 One Development Per Tile — Baseline

Normal rule:

> **One tile may contain one Development.**

This makes Development placement meaningful and keeps the board readable.

Relics or special rules may break this.

## 17.5 Most Developments Are Edge-Neutral

A normal Development should not change the tile's four edge-matching relationships.

Examples:

- Farm → Orchard;
- Village tile gains Market;
- River Settlement gains Port;
- Forest gains Forester's Lodge;
- Monastery becomes Abbey.

This prevents normal development from accidentally invalidating neighboring tiles.

## 17.6 Completed Features Remain Developable

Completion does not freeze a feature forever.

Completed:

- Settlements;
- Forests;
- Roads;
- Rivers

can later receive eligible Developments.

## 17.7 Development Does Not Automatically Re-Score the Whole Feature

A previously completed feature does not pay its base completion score again just because a Development is added.

The Development either:

- scores immediately according to its own rule;
- changes future scoring;
- changes a later growth phase;
- modifies Charter / Relic / Specialist interactions.

## 17.8 Timing-Specific Developments

Some Developments may only be placed on:

- unfinished features; or
- completed / Established features.

This adds strategic timing.

## 17.9 Forest Development States

Natural features can conceptually be:

- Undeveloped;
- Lightly Developed;
- Developed.

Low-impact Developments may preserve some Ecology eligibility. Heavy development may remove access to future preservation bonuses without subtracting Ecology already earned.

## 17.10 Development Upgrade Chains

Explicit upgrades are allowed:

- Market → Grand Market;
- Monastery → Abbey;
- School → University;
- Port → Grand Port;
- Forester's Lodge → Conservatory.

Most chains should be short—usually two stages, occasionally three.

Avoid deep RPG tech trees on individual squares.

---

# 18. Settlement Growth and Reopening — Locked

This is a central system.

## 18.1 Completion Ends a Growth Phase

A completed Settlement becomes **Established**.

It scores for the growth completed in that phase.

Completion does **not** mean the Settlement can never grow again.

Core principle:

> **Completion is not the death of a feature. It marks the end of one growth phase.**

## 18.2 Leaving a Settlement Open Is a Valid Strategy

If an Act I Settlement is left unfinished, the player can continue expanding it in Act II without needing a reopening effect.

The cost is:

- no completion payout yet;
- any assigned Specialist remains committed;
- unfinished geometry remains a liability.

This creates a deliberate roguelite lesson:

> Leave it open for easier future growth, or close it now for immediate scoring and Specialist recovery?

Players should discover the pros and cons through trial and error.

## 18.3 Urban Expansion

In Act II+, **Urban Expansion** tiles / effects can reopen an Established Settlement.

Rules:

- target an exterior boundary edge;
- the neighboring square must be empty;
- the resulting geometry must remain legal;
- that edge becomes an open Settlement edge;
- the Settlement becomes unfinished again;
- new Settlement tiles may connect through it.

## 18.4 Urban Expansion Tiles Can Also Start New Settlements

This is locked.

An Urban Expansion tile is not a dead draw if the player does not want to reopen an existing Settlement.

It can also be used to begin an entirely new Settlement.

This reinforces the strategic choice between:

- expanding an old core;
- founding a new center.

## 18.5 Previously Scored Tiles Do Not Score Their Base Value Again

Example:

Act I:
> 2-tile Hamlet completes → scores its Population.

Act II:
> Reopen it and add 3 new Settlement tiles.

When the five-tile Settlement completes:

- the 3 newly incorporated tiles score their base completion Population;
- the original 2 tiles do **not** score that base value again.

However, the Settlement's total current size is still 5 for:

- Hamlet / Village / Town / City classification;
- Largest Settlement records;
- Charter checks;
- Specialist abilities;
- Relic effects;
- Development eligibility;
- history-sensitive Culture effects.

## 18.6 Growth History Is Preserved

The game should internally remember a Settlement's phases.

Example:

> Established Act I — size 2  
> Expanded Act II — +3  
> Established Act II — size 5  
> Expanded Act III — +4  
> Established Act III — size 9

This can feed:

- Culture;
- historic districts;
- Charters;
- Relics;
- records;
- visual architecture.

An old Act I core absorbed into an Act III City remains historically meaningful.

## 18.7 Settlement Classification

The exact size thresholds are not yet finalized.

The design direction is that classification should emerge from actual size + development rather than requiring a generic “Town Upgrade” tile.

Possible prototype logic:

- Hamlet — very small Settlement;
- Village — modest connected Settlement;
- Town — larger Settlement with Development;
- City — large, heavily developed Settlement.

Exact thresholds are still open for prototyping.

---

# 19. Rare Developments and Legendary Projects — Locked

There are two distinct high-end content types.

## 19.1 Rare Developments

Rare Developments are:

- single-tile;
- powerful;
- specialized;
- usually high-impact but straightforward.

Examples:

- Cathedral;
- University;
- Grand Market;
- Botanical Gardens;
- Central Station;
- Great Park.

They are exciting finds, not run-long obligations.

Core feeling:

> **“Oh! Cathedral. I can do something great with this.”**

## 19.2 Legendary Projects

Legendary Projects are:

- opt-in;
- world-wonder-scale;
- multi-stage;
- multi-tile;
- potentially multi-Act;
- capable of failing;
- deliberately risky.

Core feeling:

> **“I spent this entire run trying to finish this thing, and I finally did it.”**

A Legendary Project is not merely a powerful thing that appears.

> **It is something the player decides their civilization is going to attempt.**

## 19.3 Example — Grand Cathedral

A simple prototype grammar:

### Act I
Choose **Begin the Grand Cathedral** as a reward.

- Add 2 Grand Cathedral Foundation tiles to the bag.
- They use normal hand / Reserve / placement opportunities.
- They are Bound and not normally discardable.
- Both must be placed before the Act I deadline.

### Start of Act II
If successful:

- add 2 additional Foundation / Construction pieces.

These expand the footprint and have stricter placement requirements.

They must be placed by the end of Act II.

### Start of Act III
If the full foundation / structure is complete:

- add 2 final Development / construction tiles.
- These stack onto the existing foundation / structure to progress and finish the Wonder.

The user's correction is locked: the final tiles enter in **Act III**, not Act II.

## 19.4 Project Pieces Use Normal Draw Pressure

Project pieces:

- enter the normal bag;
- occupy normal hand slots;
- can occupy the Reserve;
- consume normal placement opportunities.

The player has voluntarily clogged their own run with a major construction commitment.

That risk is intentional.

## 19.5 Bound Project Pieces

Legendary Project pieces are normally **Bound**.

They cannot be discarded through ordinary Survey.

The player opted in and must deal with them.

## 19.6 Normally One Active Legendary Project Per Run

Default:

> **1 active Legendary Project maximum.**

Rare Relics may break this rule.

## 19.7 Failure Is Permanent and Visible

If the deadline is missed:

- the Project fails;
- already placed pieces remain on the board;
- the failed structure becomes an unfinished ruin / work;
- unplaced Bound pieces for an impossible later stage are removed from hand / bag at the deadline.

The failed Project remains part of the visual history of the run.

## 19.8 Failed Project Salvage

Act III can contain a small number of options that appear **only if a failed Legendary Project exists**.

Examples:

- tourism site;
- preserved ruin;
- guided tours;
- adaptive reuse.

These must be only situationally better than ordinary Act III Development and should never approach the value of successful Legendary completion.

Example Specialist:

### Tour Guide
Assign to an unfinished Legendary Project.

> +1 Culture to each Settlement tile touching the Project.

This turns failure into an interesting board state without making failure secretly optimal.

## 19.9 Partial Project Rewards

Project stages may give modest interim effects.

Example:

- Foundation complete → small Culture reward.
- Structure phase complete → moderate effect.
- Final completion → enormous effect.

Partial progress remains meaningful, but full completion is vastly superior.

## 19.10 Legendary Completion Reward Philosophy

A completed Legendary should generally deliver:

1. a large immediate Realm Track payoff;
2. a persistent run-changing rule / effect;
3. a final-scoring or record effect;
4. meaningful meta-progression the first time it is completed.

## 19.11 Legendary Projects Need Varied Construction Grammars

The 2+2+2 Grand Cathedral model is a strong baseline, not a universal template.

Possible future Projects:

- Great Library — smaller footprint but requires different adjacent civic Developments.
- Grand Canal — a long continuous line connecting water systems.
- Royal Gardens — requires incorporating and preserving existing natural terrain.
- Great Road / ceremonial route — linear infrastructure.
- World's Fair — late-starting multi-tile urban Project.
- Great Palace — large urban footprint linked to Settlement classification.

---

# 20. Act Transitions and Reward Cadence — Locked

Acts end after a fixed number of normal tile placements.

Exact counts are prototype values only.

## 20.1 End-of-Act Resolution Order

After the final normal placement:

1. resolve feature completions;
2. resolve Specialists;
3. resolve Relics;
4. apply Realm Track gains;
5. resolve crossed thresholds / reward choices;
6. then begin the Act transition.

Transition sequence:

1. Evaluate current Charter.
2. Evaluate Legendary Project progress / deadline.
3. Award Charter rewards.
4. Open the next Act's eligible tile tier / Development options.
5. Advance the Legendary Project if applicable and add next-stage pieces.
6. Reveal the next Charter / Grand Charter information.
7. Open additional Relic capacity.
8. Continue with the existing run state.

## 20.2 Nothing Is Automatically Reset

At Act transition:

- board persists;
- hand persists;
- Reserve persists;
- bag persists;
- Realm Tracks persist;
- Specialists remain where they are;
- no automatic reshuffle;
- no free cleanup;
- no default bag-thinning / planning phase.

The run is one continuous civilization.

## 20.3 Relic Slot Progression

Locked prototype:

- Act I → 2 slots
- Act II → 4 slots
- Act III → 5 slots

## 20.4 Feature Rewards

Ordinary completion normally gives:

- Realm Track gains;
- Specialist resolution.

Exceptional once-per-run board milestones may also give a bonus reward.

Examples:

- first 10-tile Forest;
- Road connecting 5 Settlements;
- first sufficiently large City;
- River spanning a major portion of the realm.

These should be uncommon enough to remain exciting.

## 20.5 No Default Inter-Act Planning Phase

Do not automatically give:

- free tile removal;
- free bag reshuffle;
- free Specialist recall;
- generic reorganization.

Bag manipulation should generally be earned through actual build systems.

## 20.6 Act Transition Presentation

The transition should be ceremonial but brief.

Example:

> **ACT I COMPLETE — THE REALM IS ESTABLISHED**

Show:

- Population;
- Trade;
- Culture;
- Ecology;
- Charter result;
- largest Settlement;
- longest Road;
- notable board records;
- Legendary Project status.

Then reward / next Act.

The player should get a moment to appreciate the realm.

---

# 21. Meta-Progression and Records

Meta progression should be achievement / record driven rather than generic XP grinding.

End-of-run records may include:

## Realm Tracks
- highest Population;
- highest Trade;
- highest Culture;
- highest Ecology.

## Board Records
- largest Settlement;
- longest Road;
- largest Forest;
- longest River;
- most connected Settlements;
- most preserved Act I tiles;
- most diverse City;
- largest historical core;
- Legendary Project progress / completions.

These records unlock:

- new tile designs;
- Foundations;
- Specialists;
- Relics;
- Charters;
- Rare Developments;
- Legendary Projects.

Example:

> Reach Population 100 → unlock Big City content.

> Create a sufficiently large Forest → unlock Ancient Grove.

> Connect many Settlements → unlock advanced Trade infrastructure.

> Complete the Grand Cathedral → unlock another Legendary Project or relevant Relic.

The player should be able to see near-miss unlocks and feel:

> “I was only seven Population short.”

This naturally generates goals for the next run.

## 21.1 Meta Progression Should Add Complexity, Not Raw Power

A fully unlocked player should not simply start twice as strong.

Instead, they have:

- more specialized tools;
- stranger interactions;
- more possible builds;
- more difficult choices.

Unlocked content expands the possibility space.

---

# 22. Failure Philosophy

The game does not require:

- starvation;
- bankruptcy;
- combat defeat;
- resource depletion;
- punitive collapse simulation.

Most failed runs should reach the final evaluation.

A run can fail because:

- the player missed the Grand Charter;
- a Legendary Project was not completed;
- a desired unlock threshold was missed;
- the final score / records were disappointing.

This is enough pressure.

The game can still have very difficult higher tiers without becoming hostile in tone.

---

# 23. Provisional Content Targets

These are planning targets, not locked balance values.

## Core Tile Designs
~72 total, with ~24 initially available.

## Relics
~50–60 total eventually.

## Specialists
A first prototype roster around 12; eventual count can expand.

## Foundations
Potentially around 6–8 meaningful configurations rather than dozens of shallow ones.

## Charters
Enough Act I, Act II, and Grand Charter variety to prevent repetition. Exact count not yet fixed.

## Rare Developments
A first prototype could use roughly 6–10.

## Legendary Projects
A first prototype should include at least 2–3 with different construction grammars.

---

# 24. Systems Explicitly Rejected or De-Emphasized

The following directions have been deliberately rejected or strongly de-emphasized:

- tower defense;
- combat;
- enemies traveling down Roads;
- spendable resource economies;
- Wood / Food / Stone / Gold stockpile management;
- shops as the central reward mechanism;
- upkeep-heavy city simulation;
- traditional player classes;
- deep individual building tech trees;
- free arbitrary tile replacement;
- automatically resetting the map between Acts;
- automatically refreshing Specialists between Acts;
- unlimited redraw / discard;
- pure blind one-tile topdecking as the default;
- explicit Relic set bonuses;
- meta progression that simply raises permanent stats;
- generic Culture-as-science-only design;
- generic Prosperity track;
- automatic punishment on top of missing a Charter reward.

---

# 25. Open Design Areas — Not Yet Finalized

The following are still intentionally open and suitable for dedicated future chats.

## 25.1 Actual Starter Tile Set
Design the first ~24 tile designs:

- exact edge geometry;
- Expansion vs Development;
- copy counts;
- which designs are in Homestead's starting bag;
- starter River / Road / Settlement / Forest distributions.

## 25.2 Exact Feature Completion Rules
The broad completion concepts exist, but precise rules still need prototyping for:

- Roads;
- Settlements;
- Forests;
- Rivers;
- Monasteries;
- special Developments.

## 25.3 Settlement Classification Thresholds
Exact definitions for:

- Hamlet;
- Village;
- Town;
- City.

Likely based on size + Development diversity, but numbers are not locked.

## 25.4 Actual Realm Track Thresholds
20 / 40 / 70 / 100 is placeholder language, not final balance.

## 25.5 Reward Tables
Need actual pools for:

- Population gates;
- Trade gates;
- Culture gates;
- Ecology gates;
- Act I Charter fulfill / exceed;
- Act II Charter fulfill / exceed;
- exceptional board milestones.

## 25.6 Specialist Roster
Need exact first prototype Specialists, effects, unlock conditions, and starting availability.

## 25.7 Relic Pool
Need an initial 15–20 Relics suitable for prototype play before building the eventual full set.

## 25.8 Foundations
Need exact bag compositions and rule modifiers for Homestead, Riverlands, Crossroads, Deepwood, etc.

## 25.9 Charters
Need concrete Act I, Act II, and Grand Charter lists with provisional numbers and rewards.

## 25.10 Rare Developments
Need actual one-tile Rare designs and eligibility requirements.

## 25.11 Legendary Projects
Need concrete Project blueprints beyond the Grand Cathedral concept.

## 25.12 Transformation Rules
Need exact legal rules and UI expectations for Bridges, Canals, Rewilding, Reservoirs, and other geography-changing effects.

## 25.13 River Completion Identity
Rivers should not simply be “blue Roads.” Their final completion logic still needs dedicated design.

## 25.14 Final Scoring Formula
The four Tracks and board records describe the realm; an optional overall score / Renown value may be useful for high-score chasing, but the formula is not yet designed.

## 25.15 Difficulty / Ascension
Higher difficulty should likely adjust:

- placement counts;
- Charter targets;
- tile pool difficulty;
- stricter conditions;
- fewer conveniences;
- more demanding Grand Charters.

Do not solve until the base run works.

## 25.16 Presentation and Setting
Art style, exact historical / fantasy setting, narrative wrapper, UI, sound, tutorial, and flavor are secondary until the prototype is mechanically sound.

---

# 26. Recommended Next Development Workflow

The design has reached the point where further purely abstract discussion is less valuable than prototype content.

Recommended order:

1. **Design the starter 24 tile set.**
2. **Define the Homestead starting bag and physical copy counts.**
3. **Finalize prototype completion rules for Roads / Settlements / Forests / Rivers / Monasteries.**
4. **Create a small prototype reward table.**
5. **Create 6–12 prototype Specialists.**
6. **Create 15–20 prototype Relics.**
7. **Create a small Charter set.**
8. **Create 1–2 Foundations beyond Homestead.**
9. **Create a handful of Rare Developments.**
10. **Implement Grand Cathedral as the first Legendary Project.**
11. **Simulate a complete Act I manually.**
12. **Continue the same run through Acts II and III.**
13. **Record what breaks, what snowballs, what never matters, and what feels fun.**
14. **Only then begin serious numerical balancing.**

---

# 27. Canonical One-Paragraph Pitch

A peaceful three-Act tile-placement roguelite in which the player builds one continuous realm from a finite, evolving bag of square landscape and Development tiles. Carcassonne-like edge matching and feature completion provide the spatial foundation, while cumulative Population, Trade, Culture, and Ecology tracks unlock new opportunities throughout the run. Limited Specialists are committed to unfinished features, Relics rewrite the rules of the realm, Foundations alter the starting configuration, and Charters serve as non-combat “boss” evaluations. Act I establishes the landscape, Act II develops and reopens it, and Act III transforms it around a revealed Grand Charter. Powerful Rare Developments can appear as single tiles, while optional Legendary Projects create risky multi-Act world-wonder pursuits whose unfinished remains stay permanently on the map if they fail. The central principle is that **the map is the build**: every run begins with simple Carcassonne-like placement and ends with a strange, highly specialized civilization whose history is physically visible on the board.

---

# 28. Canonical Design Mantras

These short statements should be treated as high-level filters for future ideas:

> **The map is the build.**

> **The realm is the character.**

> **Act I creates the land. Act II develops it. Act III transforms it.**

> **Completion ends a growth phase; it does not kill the feature.**

> **Develop the past; do not freely erase it.**

> **A Charter may challenge a build, but should rarely invalidate it.**

> **A good Relic changes what counts as a good placement.**

> **A Foundation creates the opening question, not the final answer.**

> **Peaceful does not mean easy.**

> **Unlocks should expand possibility more than raw power.**

> **The player should begin a run playing something recognizably Carcassonne-like and finish playing the strange ruleset their own build created.**

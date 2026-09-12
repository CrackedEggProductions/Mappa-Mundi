# Carcassonne Roguelite - Relics and Specialists Prototype Specification

**Document status:** Working prototype design document  
**Scope:** Initial Relic pool, initial Specialist roster, and prototype rules for how both systems function during a run  
**Primary source:** *Carcassonne Roguelite - Core Design Bible*  
**Secondary source:** *Carcassonne Roguelite - Tile Design Specification*  
**Current design stage:** 18 prototype Relics and 12 prototype Specialists defined for manual playtesting; exact numerical balance remains provisional.

---

# 1. Purpose of This Document

This document consolidates the current design direction for **Relics** and **Specialists** and supplies a first playable prototype set for both systems.

It is intended to support manual full-run testing before the eventual content pools are expanded.

The central distinction is:

- **Relics** are persistent, realm-wide rule modifiers.
- **Specialists** are scarce reusable board pieces committed to individual unfinished features.

Both systems should reinforce the larger design principle:

> **The map is the build.**

Neither system should primarily behave like a conventional RPG stat sheet. Their strongest effects should change what the player wants to build, where they want to build it, when they want to complete it, or how they interpret geography already on the board.

---

# 2. Locked Relic Direction

## 2.1 Core Identity

Relics are persistent run-wide rule modifiers.

A strong Relic should change what the player considers a good tile placement.

Relics should therefore favor:

- altered placement incentives;
- new feature relationships;
- cross-Track conversions;
- unusual completion conditions;
- geometry exceptions;
- bag, hand, Reserve, or Survey manipulation;
- temporal relationships between Acts;
- interactions with Specialists;
- narrow rule-breaking;
- major build-around identities.

Pure effects such as "+10% Population" should not be the core of the system.

## 2.2 Relic Capacity

Current locked prototype progression:

- **Act I:** 2 active Relic slots
- **Act II:** 4 active Relic slots
- **Act III:** 5 active Relic slots

Opening a slot does not automatically grant a Relic.

When all active slots are full, a newly offered Relic may replace an existing Relic or be declined.

## 2.3 Relic Acquisition

Primary sources include:

- Realm Track milestones;
- Charter rewards;
- exceptional board accomplishments.

Relics are not purchased through a shop or spendable currency economy.

## 2.4 Relic Eligibility Tiers

Relics use thematic Act eligibility rather than conventional videogame rarity colors.

### Foundational
Can appear in Act I.

These should usually be understandable before the realm has a strong specialization and should help create or redirect the run's emerging identity.

### Developed
Can appear from Act II onward.

These may assume a more mature board containing Developments, established networks, older tiles, or a clearer strategic direction.

### Legacy
Normally Act III or major-reward territory.

These may radically restructure scoring incentives or define the final form of a run.

## 2.5 Relic Families

The following are useful design families rather than rigid card classifications.

- **Conversion Relics** - make one form of achievement feed another Realm Track.
- **Conditional Relics** - amplify a specific spatial pattern.
- **Geometry Relics** - alter placement, matching, completion, or connectivity rules.
- **Bag / Draw Relics** - alter Survey, Reserve, preview, ordering, copying, removal, or draw probability.
- **Specialist Relics** - alter commitment, return, retraining, sharing, or Specialist timing.
- **Temporal Relics** - care about which Act a tile, feature, or growth phase belongs to.
- **Build-Around Relics** - strongly redefine what the run is trying to build.

## 2.6 Drawbacks and Tradeoffs

When a Relic has a drawback, prefer a rule or opportunity cost over a flat numerical penalty.

Good tradeoffs include:

- forbidding a Development type;
- narrowing which feature can score;
- forcing preservation;
- rewarding delayed completion;
- making one geometry much more valuable than another;
- concentrating value into one feature at the expense of alternatives.

## 2.7 Emergent Synergy

Relics should not use explicit set bonuses such as:

> Collect three Forest Relics to activate a Forest set bonus.

Instead, individually coherent effects should naturally combine into stronger strategies.

---

# 3. Prototype Relic Pool

The first manual-playtest pool contains **18 Relics**:

- 8 Foundational;
- 7 Developed;
- 3 Legacy.

The exact numbers below are provisional. The first question is whether the effects create interesting spatial decisions, not whether their final values are perfectly balanced.

---

# 4. Foundational Relics

## 4.1 Boundary Stones

**Eligibility:** Foundational  
**Family:** Geometry

**Effect:** Once per Act, you may place an Expansion tile with exactly **one mismatched natural-geography edge**. Road, River, and Settlement connections must still match normally.

**Design purpose:** Tests whether a tightly constrained geometry exception can rescue or deliberately exploit awkward board spaces without destroying the placement puzzle.

**Playtest watch:** If this routinely removes meaningful spatial pressure, restrict the legal mismatch further or replace the effect.

---

## 4.2 Surveyor's Compass

**Eligibility:** Foundational  
**Family:** Bag / Draw

**Effect:** The first time you use **Survey** each Act, look at the next **3 tiles** in the bag. Choose one as the replacement draw and return the others to the bag in random order.

**Design purpose:** Creates controlled information and choice without turning Survey into unlimited cycling.

---

## 4.3 Wayfarer's Satchel

**Eligibility:** Foundational  
**Family:** Hand / Reserve

**Effect:** Gain a **second Reserve slot**.

**Design purpose:** Tests how strongly increased long-term tile storage affects the intended pressure of the three-tile hand.

**Playtest watch:** Extra Reserve capacity is expected to be very powerful. This Relic may require later restriction or promotion to Developed eligibility.

---

## 4.4 Roadside Inns

**Eligibility:** Foundational  
**Family:** Conditional / Trade

**Effect:** Each **Road End** contained in a completed Road counts as one additional connected Settlement for that Road's Trade calculation, to a maximum of **2 additional connections**.

**Design purpose:** Turns a normally utilitarian closure piece into a potentially valuable component of a commercial route.

---

## 4.5 Pilgrim's Way

**Eligibility:** Foundational  
**Family:** Conversion / Road / Culture

**Effect:** A completed Road connected to a **Monastery** treats that Monastery as a connected Settlement for Trade. If the Road connects at least one Settlement and at least one Monastery, also gain **+2 Culture**.

**Design purpose:** Gives civic geography a reason to participate in Road planning and creates an early Trade/Culture bridge.

---

## 4.6 Village Green

**Eligibility:** Foundational  
**Family:** Conditional / Settlement / Culture

**Effect:** When a Settlement completes, if its exterior touches at least one **Field**, one **Forest**, and one **River** tile, gain **Culture equal to the Settlement's current size** in addition to its normal Population rewards.

**Design purpose:** Encourages Settlements to occupy mixed geographic boundaries rather than simply consuming the easiest open space.

---

## 4.7 Woodland Paths

**Eligibility:** Foundational  
**Family:** Conversion / Road / Ecology

**Effect:** When a Road containing at least one **Woodland Road** tile completes, gain **+1 Ecology for each Woodland Road tile** in that Road.

**Design purpose:** Makes integrated Road/Forest geography valuable and creates an early Trade/Ecology bridge.

---

## 4.8 Ferry Rights

**Eligibility:** Foundational  
**Family:** Connectivity / River / Trade

**Effect:** Two Settlements touching the **same connected River** count as connected for the purpose of determining how many Settlements a Road network reaches, provided that Road network reaches at least one of those Settlements.

**Design purpose:** Allows Rivers to extend commercial connectivity without simply making Rivers score as blue Roads.

**Playtest watch:** The UI must make the inherited River connection visually obvious.

---

# 5. Developed Relics

## 5.1 Mixed-Use Charter

**Eligibility:** Developed  
**Family:** Development / Rule-breaking

**Effect:** A Settlement tile may contain **both Housing and Market**. No other pair of ordinary Developments may share a tile because of this Relic.

**Design purpose:** Creates a dense mixed-use urban archetype while breaking the one-Development-per-tile rule only in a narrow, readable way.

---

## 5.2 Cloister in the Woods

**Eligibility:** Developed  
**Family:** Geography / Culture / Ecology

**Effect:** Monasteries may be placed on an **undeveloped Forest tile**. The tile remains part of its connected Forest. When the Monastery becomes surrounded, gain its normal Culture and **+1 additional Culture for each surrounding Forest tile**.

**Design purpose:** Reinterprets Forest as civic as well as ecological space and changes the best location for a Monastery.

---

## 5.3 River Trade Compact

**Eligibility:** Developed  
**Family:** Connectivity / River / Trade

**Effect:** **Ports on the same connected River** are considered connected to one another for Market and Trade effects that care about commercial connectivity.

**Design purpose:** Allows water-heavy realms to construct a commercial network that is structurally different from a Road-only network.

**Important:** This does not define River completion or base River scoring.

---

## 5.4 Historic Routes

**Eligibility:** Developed  
**Family:** Temporal / Road / Culture

**Effect:** When a Road containing at least one **Act I Road tile** completes during Act II or Act III, gain **+1 Culture per Act I Road tile** contained in that Road.

**Design purpose:** Makes old infrastructure historically valuable and encourages the player to preserve, reconnect, or extend imperfect early Roads.

---

## 5.5 Conservator's Seal

**Eligibility:** Developed  
**Family:** Forest / Preservation

**Effect:** A Forest containing a **Forester's Lodge** is still considered **undeveloped** for preservation effects. Other Forest Developments behave normally.

**Design purpose:** Strengthens the intended identity of the Forester's Lodge as low-impact development rather than ecological destruction.

---

## 5.6 Steward's Relay

**Eligibility:** Developed  
**Family:** Specialist

**Effect:** Whenever a Specialist returns from a completed feature, you may immediately assign that Specialist to an eligible **unfinished feature touching the feature that just completed**.

**Design purpose:** Creates spatial chains of Specialist activity and makes adjacency between otherwise separate features tactically important.

---

## 5.7 The Green Belt

**Eligibility:** Developed  
**Family:** Build-Around / Population / Ecology

**Effect:** When a Settlement of **4 or fewer tiles** completes, if every Settlement tile touches at least one Field, Forest, or River tile outside the Settlement, gain **+1 Ecology per Settlement tile**.

**Restriction:** **Housing cannot be placed in that Settlement.**

**Design purpose:** Creates an alternative to urban concentration by rewarding compact settlements woven into the surrounding landscape.

---

# 6. Legacy Relics

## 6.1 One Great City

**Eligibility:** Legacy  
**Family:** Build-Around / Population

**Effect:** Only your **largest Settlement** generates base Population from Settlement completion. Whenever that Settlement completes or re-establishes, **double the Population it would normally generate** from that completion.

If another Settlement later becomes larger, it becomes the new Great City.

**Design purpose:** Radically concentrates Population strategy into one continually expanding urban center while leaving smaller Settlements useful for Trade, Charters, Ports, Markets, and other effects.

**Playtest watch:** The exact multiplier is highly provisional.

---

## 6.2 The Long Road

**Eligibility:** Legacy  
**Family:** Build-Around / Trade / Push-your-luck

**Effect:** Only completed Roads that **equal or exceed your current Longest Road record** generate base Trade. A qualifying Road generates **double its normal Trade**.

After scoring, update the Longest Road record normally.

**Design purpose:** Turns Road completion into an escalating push-your-luck problem. The player is encouraged to delay closure and construct increasingly ambitious routes.

**Playtest watch:** This should feel dangerous rather than simply punitive. Track whether the player can reasonably create qualifying Roads after acquisition.

---

## 6.3 The Old Ways

**Eligibility:** Legacy  
**Family:** Build-Around / Temporal / Culture / Ecology

**Effect:** When acquired, mark every currently undeveloped **Act I Expansion tile** as **Old Country**.

Old Country tiles:

- may not receive ordinary Developments;
- remain eligible for Transformations or Legendary Project effects unless those effects say otherwise.

At each later Act transition, gain:

- **+1 Culture for every 3 Old Country tiles** still present;
- **+1 additional Ecology for every 3 Old Country Forest tiles** still present.

**Design purpose:** Turns the surviving early landscape into protected historic geography and creates tension between redevelopment and preservation.

**Playtest note:** Because this is normally acquired in Act III, the Act-transition timing and/or final-evaluation trigger may need adjustment after testing. The conceptual identity is locked more strongly than the current trigger timing.

---

# 7. Prototype Relic Coverage

The 18-card pool intentionally tests several different design spaces.

| Design Space | Prototype Relics |
|---|---|
| Geometry | Boundary Stones |
| Survey / draw | Surveyor's Compass |
| Reserve | Wayfarer's Satchel |
| Roads / Trade | Roadside Inns, Pilgrim's Way, Ferry Rights, Historic Routes, The Long Road |
| Settlements | Village Green, Mixed-Use Charter, The Green Belt, One Great City |
| Forest / Ecology | Woodland Paths, Cloister in the Woods, Conservator's Seal, The Green Belt, The Old Ways |
| Rivers | Ferry Rights, River Trade Compact |
| Culture / history | Pilgrim's Way, Village Green, Cloister in the Woods, Historic Routes, The Old Ways |
| Specialist interaction | Steward's Relay |
| Temporal / Act history | Historic Routes, The Old Ways |
| Major build-arounds | The Green Belt, One Great City, The Long Road, The Old Ways |

The prototype does not attempt to give every Track an equal number of Relics. Its purpose is to test whether the system changes spatial decision-making in interesting ways.

---

# 8. Locked Specialist Direction

## 8.1 Core Identity

Specialists preserve the Carcassonne meeple feeling while becoming a roguelite build system.

A Specialist is a **limited, reusable board piece** that becomes temporarily unavailable when committed to an unfinished feature.

Its ability should reward or alter the particular spatial feature to which it is assigned.

Specialists should feel:

- local rather than realm-wide;
- tactical rather than permanently passive;
- powerful enough that commitment matters;
- costly enough that leaving one stranded is a real decision.

## 8.2 Starting Pool

Current preferred prototype:

- start with **2 generic Stewards**;
- a third may become obtainable during the run;
- around **3 total pieces** should normally be the maximum.

A small pool is important because Specialist commitment is supposed to create opportunity cost.

## 8.3 Training

A reward may offer:

> **Train a Steward - choose 1 of 3 Specialists.**

The selected Steward permanently becomes that Specialist for the remainder of the run.

Retraining may exist, but should be uncommon.

## 8.4 Specialist Lifecycle

Typical sequence:

1. Place a tile.
2. Optionally assign an available Specialist to an eligible unfinished feature.
3. The Specialist remains committed while that feature is open.
4. The feature completes.
5. Resolve the Specialist's effect.
6. Return the Specialist to availability.

Specialists do **not** automatically return at Act transitions.

A Specialist committed to an unfinished feature at the end of an Act remains committed into the next Act.

## 8.5 Specialist Design Standard

Each Specialist should remain compact:

- a clear assignment condition;
- one meaningful effect.

Avoid:

- large skill trees;
- generic level I / II / III progression;
- stacks of passive modifiers;
- abilities that are effectively just small Relics attached to a meeple.

---

# 9. Generic Steward

## Steward

**Assign:** Any eligible unfinished Road, Settlement, Forest, River, or Monastery.

**On completion:** Gain **+2 to the Realm Track normally associated with that feature**.

Prototype associations:

- Settlement -> +2 Population
- Road -> +2 Trade
- Forest -> +2 Ecology
- River -> +2 Ecology under the current provisional River scoring model
- Monastery -> +2 Culture

**Design purpose:** The generic Steward should be useful but intentionally plain. Training should add a new strategic identity rather than merely increasing a number.

---

# 10. Prototype Specialist Roster

The initial prototype roster contains **12 Specialists**.

They are not currently divided into Foundational, Developed, and Legacy tiers. Specialist offers should instead be weighted contextually by the board and the player's build.

---

## 10.1 Merchant

**Assign:** Road.

**On completion:** Gain **+2 Trade per distinct Settlement connected by the Road beyond the first**.

Examples:

- 1 connected Settlement -> +0 bonus Trade
- 2 connected Settlements -> +2 Trade
- 4 connected Settlements -> +6 Trade

**Design purpose:** Rewards Roads for connecting meaningful destinations rather than merely being long.

---

## 10.2 Cartographer

**Assign:** Road.

When assigned, mark the Road's current size.

**On completion:** Gain **+1 Trade for every Road tile added to this Road after the Cartographer was assigned**.

**Design purpose:** A core push-your-luck Specialist. The player may close the Road quickly for a small reward or keep the Cartographer tied up while extending it.

---

## 10.3 Courier

**Assign:** Road.

**On completion:** If this Road connects at least **3 Settlements**, regain your **Survey** for the current Act. If your Survey is still unused, instead gain **one additional Survey for this Act**.

**Design purpose:** Tests a Specialist whose reward is action flexibility rather than Realm Track gain.

**Playtest watch:** Survey restoration may be too powerful and should be monitored closely.

---

## 10.4 Architect

**Assign:** Settlement.

**On completion:** Gain **+2 Culture per distinct Development type** currently contained in the Settlement.

Examples:

- Housing + Market + Port -> +6 Culture
- three Markets -> +2 Culture

**Design purpose:** Rewards Development diversity and gives urban planning a Culture route distinct from raw Settlement size.

---

## 10.5 Homesteader

**Assign:** Settlement.

**On completion:** Gain **+1 Population for each distinct Field tile touching the Settlement**.

**Design purpose:** Makes ordinary countryside and Settlement boundaries matter to Population strategy.

---

## 10.6 Historian

**Assign:** A Settlement containing tiles from an earlier completed growth phase.

**On completion:** Gain **+1 Culture per previously established Settlement tile** currently contained in the Settlement.

Example:

An Act I three-tile Hamlet is reopened in Act II and grows to seven tiles. When the Settlement re-completes, the Historian generates **+3 Culture** from the original established core.

**Design purpose:** Gives mechanical value to Settlement history and makes older urban cores matter later in the run.

---

## 10.7 Gardener

**Assign:** Settlement.

**On completion:** Gain **+1 Ecology for each Settlement tile touching a Forest or River tile outside the Settlement**.

**Design purpose:** Rewards compact settlements integrated with natural geography and creates a Population/Ecology hybrid path.

---

## 10.8 Naturalist

**Assign:** Forest.

**On completion:** If the Forest contains **no ordinary Development**, gain **+1 Ecology per Forest tile**.

**Design purpose:** Creates a straightforward preservation Specialist and makes the decision to develop a Forest materially important.

---

## 10.9 Forester

**Assign:** Forest.

When assigned, mark the Forest's current size.

**On completion:** Gain **+1 Ecology for every Forest tile added after the Forester was assigned**.

**Design purpose:** The Forest counterpart to the Cartographer. Encourages the player to keep a Forest open and accept the cost of a committed Specialist for a larger eventual reward.

---

## 10.10 Conservator

**Assign:** Forest containing at least one Development.

**On completion:** Choose **one Development** in that Forest. For this completion, that Development does **not prevent preservation or undeveloped-Forest bonuses**.

**Design purpose:** Locally bends preservation rules without globally changing Forest development behavior.

---

## 10.11 Riverkeeper

**Assign:** River.

**On completion:** Gain **+1 Ecology for each Forest tile touching the River**.

**Design purpose:** Makes River value depend on the surrounding landscape instead of simply duplicating Road length scoring.

**Important:** River completion rules remain provisional, so this Specialist should be revisited when River identity is finalized.

---

## 10.12 Harbormaster

**Assign:** River containing at least one River-touching Settlement.

**On completion:** Gain **+2 Trade for each Settlement touching that River**, plus **+1 additional Trade for each of those Settlements containing a Port**.

**Design purpose:** Creates a water-commerce Specialist and gives Ports a reason to form a coherent River network.

**Important:** Exact River completion timing remains provisional.

---

# 11. Specialist Design Categories

The prototype roster intentionally contains several different Specialist behaviors.

## 11.1 Straight Payoff Specialists

These make a feature more rewarding when completed:

- Merchant
- Architect
- Homesteader
- Naturalist
- Riverkeeper
- Harbormaster

## 11.2 Push-Your-Luck Specialists

These specifically reward delaying completion after assignment:

- Cartographer
- Forester

These are especially important to test because they turn the temporary loss of the Specialist into the heart of the decision.

## 11.3 History / Board-Context Specialists

These reward what the realm actually looks like or how it developed:

- Historian
- Gardener

## 11.4 Rule / Action Specialists

These manipulate rules or player flexibility rather than primarily granting Track points:

- Courier
- Conservator

The eventual Specialist pool should probably contain more designs in this category once the underlying completion and transformation rules are more stable.

---

# 12. Specialist Offer Philosophy

When the player receives a training opportunity, an offer of three Specialists should usually contain:

1. **one strong synergy** with the current board;
2. **one broadly useful option**;
3. **one wildcard or pivot option**.

Avoid routinely presenting three Specialists that all solve the same problem.

Example of a useful offer for a Road-heavy realm that also contains a growing Forest:

- Merchant - direct Road synergy;
- Homesteader - generally useful Population option;
- Forester - possible Ecology pivot.

This supports adaptation rather than predetermined builds.

---

# 13. Engineer - Deliberately Deferred

The Core Design Bible identifies **Engineer** as a desirable Specialist concept that alters connectivity or feature-completion rules.

Engineer is intentionally **not included in the first 12 prototype Specialists**.

Reason:

The exact completion rules for Roads, Forests, Rivers, and Settlements are still being prototyped. A clean Engineer design should be built after those underlying rules are sufficiently stable to know exactly what the Specialist is breaking.

Potential future territory includes:

- treating one normally terminal connection as continuing;
- modifying junction behavior;
- assisting reopening;
- interacting with Bridges or Canals;
- changing local completion conditions;
- enabling unusual infrastructure connections.

The concept remains desirable, but the exact ability is deferred.

---

# 14. Relic and Specialist Boundary

This distinction should remain a hard design filter.

## Relic

> **Changes the rules followed by the realm.**

Example:

> Every Forest containing a Forester's Lodge remains eligible for preservation bonuses.

That is realm-wide and persistent, so it belongs on a Relic.

## Specialist

> **Changes what happens to one feature while a scarce piece is committed there.**

Example:

> Assign Conservator to one developed Forest; on completion, one Development does not prevent preservation bonuses.

That is local, temporary, and commitment-driven, so it belongs on a Specialist.

When an idea could fit either system, ask:

> **Does this make the entire realm obey a new rule, or does it make me care deeply about where I commit one of my few pieces?**

The answer should normally determine the system.

---

# 15. Prototype Interaction Examples

These are not explicit set bonuses. They illustrate the kind of emergent interactions the system should naturally create.

## 15.1 Woodland Trade Realm

- Woodland Paths
- Merchant
- Forester's Lodge tiles

Roads routed through woodland can contribute Trade and Ecology while still creating meaningful decisions about Forest development.

## 15.2 Historic Urban Core

- Historic Routes
- Historian
- reopened Act I Settlement

The player has reasons to preserve and extend both old Roads and old Settlement cores rather than treating early construction as disposable.

## 15.3 Compact Green Settlements

- The Green Belt
- Gardener
- Village Green

Small Settlements woven between Fields, Rivers, and Forests become an alternative civilization pattern to one giant city.

## 15.4 Great Metropolitan Run

- One Great City
- Architect
- Homesteader

Population concentrates into one major city while Specialist choices influence whether its surroundings, Development diversity, or repeated growth phases become the secondary engine.

## 15.5 Obsessive Road Network

- The Long Road
- Cartographer
- Merchant

The player becomes heavily incentivized to keep one Road open, extend it through multiple Settlements, and accept long periods with a Specialist tied up.

---

# 16. First Playtest Questions

The first manual runs should focus on behavior rather than fine balance.

## 16.1 Relics

- Does each Relic visibly change placement priorities?
- Are Foundational Relics useful before a strong build exists?
- Does Wayfarer's Satchel remove too much hand pressure?
- Does Boundary Stones preserve the integrity of edge matching?
- Is Ferry Rights understandable on the board without excessive UI explanation?
- Do Developed Relics feel like they reinterpret an existing realm rather than merely add points?
- Do build-around Relics create memorable runs without invalidating too much of the board?
- Can Legacy Relics arrive early enough in Act III to matter?
- Are any effects so broad that they should become Foundation rules instead?

## 16.2 Specialists

- Is the generic Steward worth using before training?
- Does committing one of only two Specialists create real tension?
- How often are Specialists accidentally stranded for too long?
- Do Cartographer and Forester make delaying completion exciting?
- Does training feel like a meaningful permanent choice?
- Are contextual training offers varied enough to permit pivots?
- Does Courier create too many Surveys?
- Are Riverkeeper and Harbormaster worth using under the eventual River completion rules?
- Do any Specialists behave too much like passive Relics?

## 16.3 System Interaction

- Does a Relic plus Specialist combination change spatial play more than either effect alone?
- Are obvious synergies satisfying without becoming mandatory combos?
- Can the player understand why a cascade occurred after feature completion?
- Does the turn-resolution order remain readable when completion, Specialist, Relic, and Track effects all trigger together?

---

# 17. Prototype Status Summary

The current prototype content is:

## Relics

**Foundational - 8**

1. Boundary Stones
2. Surveyor's Compass
3. Wayfarer's Satchel
4. Roadside Inns
5. Pilgrim's Way
6. Village Green
7. Woodland Paths
8. Ferry Rights

**Developed - 7**

9. Mixed-Use Charter
10. Cloister in the Woods
11. River Trade Compact
12. Historic Routes
13. Conservator's Seal
14. Steward's Relay
15. The Green Belt

**Legacy - 3**

16. One Great City
17. The Long Road
18. The Old Ways

## Specialists

**Generic piece**

- Steward

**Trainable Specialists - 12**

1. Merchant
2. Cartographer
3. Courier
4. Architect
5. Homesteader
6. Historian
7. Gardener
8. Naturalist
9. Forester
10. Conservator
11. Riverkeeper
12. Harbormaster

**Deferred concept**

- Engineer - exact design pending finalized completion/connectivity rules

---

# 18. Current Design Mantras for These Systems

> **A good Relic changes what counts as a good placement.**

> **A Specialist should make one particular unfinished feature matter more than usual.**

> **Relics rewrite the realm; Specialists reward commitment.**

> **The cost of a Specialist is not a currency. It is the time that piece is unavailable.**

> **Push-your-luck Specialists should make the player say, "one more tile."**

> **Relic synergies should be discovered, not collected as explicit sets.**

> **The map is still the build.**

---

# 19. Next Recommended Step

Use this prototype pool during manual runs with the Starter 24 and provisional Homestead bag.

The goal is to identify:

- which Relics actually alter placement decisions;
- which effects merely produce extra points;
- whether Specialist commitment creates meaningful opportunity cost;
- whether training changes the run's identity;
- which interactions create satisfying cascades;
- which rules are too difficult to communicate;
- which numerical values obviously need revision.

Only after those questions are answered should the Relic pool expand toward the eventual **50-60 Relic** target or the Specialist roster grow substantially beyond the initial prototype set.

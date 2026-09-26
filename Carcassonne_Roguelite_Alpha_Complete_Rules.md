# Carcassonne Roguelite — Complete Alpha Rules Specification

**Status:** Canonical rules handoff for the first complete three-Act playable alpha  
**Purpose:** Single source of truth for implementation by local Codex  
**Supersedes for alpha implementation:** unresolved or conflicting prototype text in the Core Design Bible, Tile Design Specification, and Relics/Specialists Prototype Specification  
**Source basis:**
- `Carcassonne_Roguelite_Core_Design_Bible(1).md`
- `Carcassonne_Roguelite_Tile_Design_Specification(1).md`
- `Carcassonne_Roguelite_Relics_and_Specialists_Prototype_Specification(1).md`
- the subsequent alpha rules pass that resolved the prototype's open questions

---

# 0. Authority, Scope, and Interpretation

## RULE-AUTH-001 — This document is the alpha rules authority
For the first playable alpha, this document is the canonical rules specification. If an older project file disagrees with this document, this document wins for alpha implementation.

Older files remain valuable design history and broader vision documents. They must not be used to reintroduce rules that this document explicitly replaces.

## RULE-AUTH-002 — Alpha scope
The alpha is a **stripped-down but complete three-Act run**, not an Act-I-only prototype and not the eventual full game.

The alpha must support:
- one persistent board across all three Acts;
- the complete normal placement cadence of Acts I–III;
- Expansion, Development, Upgrade, and Transformation play;
- feature completion and reopening where supported;
- Realm Tracks and threshold rewards;
- Stewards and the reduced alpha Specialist roster;
- the reduced alpha Relic pool;
- Act I and Act II Charters;
- Grand Charter forecast, reveal, and final evaluation;
- deterministic seeded randomness;
- final score and victory result.

## RULE-AUTH-003 — Deferred systems
The following are **not part of the first playable alpha**:
- Legendary Projects;
- meta-progression;
- the full future Relic pool;
- the full future Specialist roster;
- additional Foundations beyond the alpha Homestead baseline unless separately added later;
- advanced River reopening;
- future tile families not listed here.

The engine may retain clean extension hooks for these systems, but no alpha rule depends on them.

## RULE-AUTH-004 — Prototype numbers
The following values are locked for the alpha implementation but remain balance-test values rather than permanent final-game promises:
- Act lengths: 18 / 22 / 26 normal placements;
- Realm Track thresholds: 20 / 40 / 70 / 100;
- tile copy counts;
- scoring values;
- Charter thresholds;
- reward quantities.

Codex should implement them as data/configuration rather than burying them in irreversible logic.

---

# 1. Core Run Structure

## RULE-RUN-001 — One continuous civilization
A run is one continuous civilization built on one persistent square-grid map across three Acts.

The board, hand, Reserve, bag, Realm Tracks, Relics, feature histories, Trade Network histories, and committed Specialists persist between Acts unless a specific rule says otherwise.

## RULE-RUN-002 — Act placement limits
Normal placement limits are:
- **Act I:** 18 normal placements
- **Act II:** 22 normal placements
- **Act III:** 26 normal placements

Total normal placements in a full run: **66**.

## RULE-RUN-003 — What consumes a normal placement
Every physical tile played from the active hand or Reserve as the turn's required placement consumes exactly **1 normal Act placement**, regardless of whether the tile is played as:
- an Expansion;
- an ordinary Development;
- a Development Upgrade;
- a Transformation;
- an alternate placement mode of a tile such as Rewilding.

## RULE-RUN-004 — Bonus placements
A bonus placement does **not** increment the Act's normal placement counter.

A bonus placement:
- consumes the physical tile played;
- uses the normal placement, completion, scoring, Specialist, Relic, milestone, and threshold-resolution pipeline;
- may itself grant another bonus placement if an effect explicitly says so;
- may therefore chain.

Bonus placements are not full turns. During a bonus placement the player may place a legal tile from the active hand or Reserve, rotate it, choose a legal mode, and assign a Specialist if eligible, but may not normally:
- Survey;
- move new tiles into Reserve;
- use other start-of-turn actions;
unless the effect granting the bonus placement explicitly permits them.

**Current alpha content note:** the generic bonus-placement rules are defined for engine completeness, but the current alpha content roster does not itself require a bonus-placement-granting tile/Relic/Specialist.

## RULE-RUN-005 — End-of-Act bonus chains
If the final normal placement of an Act grants one or more bonus placements, the entire bonus-placement chain and all consequences resolve while the outgoing Act is still active.

Only after the entire event queue is exhausted does Charter evaluation and Act transition begin.

Bonus tiles played in such a chain count as belonging to the outgoing Act for tile-age/history purposes.

---

# 2. Board, Coordinates, Rotation, and Basic Placement

## RULE-BOARD-001 — Board topology
The alpha uses an effectively **unbounded square grid**.

There are no mechanical map borders. UI may render only the occupied region plus working space.

## RULE-BOARD-002 — Orthogonal placement
An Expansion tile must be placed in an empty square orthogonally adjacent to at least one existing tile.

Diagonal adjacency alone does not make an Expansion placement legal.

## RULE-BOARD-003 — Exact edge matching
After rotation, every edge facing an occupied orthogonal neighbor must exactly match that neighbor's edge type unless an explicit rule grants a mismatch or rewrite.

Alpha edge types are:
- **Field**
- **Forest**
- **River**
- **Road**
- **Settlement**

Normal matching is exact:
- Field ↔ Field
- Forest ↔ Forest
- River ↔ River
- Road ↔ Road
- Settlement ↔ Settlement

Edges facing empty squares may remain open.

## RULE-BOARD-004 — Diagonals
Diagonal neighbors impose no ordinary edge-matching restriction.

Monastery/Abbey enclosure is the explicit system that cares about all eight surrounding squares.

## RULE-BOARD-005 — Rotation
All orientation-dependent tiles may be freely rotated in **90-degree increments** before placement unless a specific tile says otherwise.

Rotation costs no resource or action.

## RULE-BOARD-006 — One connection type per edge
For the alpha, every tile edge has exactly one edge connection type from the five-type grammar above.

Multiple systems may coexist inside one tile, but an individual edge is never simultaneously Road + Forest, River + Settlement, etc.

## RULE-BOARD-007 — Same-type internal connectivity
Unless a tile explicitly says otherwise, all edges of the same feature type shown on that tile belong to one internally connected component.

Examples:
- all three Road edges of a Road Junction form one Road component;
- both Settlement edges of a Settlement Corner form one Settlement component;
- both Forest edges of a Forest Bend form one Forest component.

Different feature types remain mechanically distinct even if the tile establishes an explicit relationship between them.

## RULE-BOARD-008 — Feature-size tile counting
A physical board square contributes at most **1 tile** to any one connected feature, regardless of how many edges of that feature it contains.

A hybrid square can count once in each different feature it contains. For example, a Bridge square can count as 1 River tile and 1 Road tile simultaneously.

---

# 3. Founding Tile and Run Setup

## RULE-SETUP-001 — Founding Tile
The Homestead run begins with one special **Founding Tile** at coordinate `(0,0)`.

Its fixed canonical orientation is:
- **North:** Settlement
- **East:** Road
- **South:** River
- **West:** Forest

The player does not rotate the Founding Tile during setup.

## RULE-SETUP-002 — Founding Tile internal topology
The Founding Tile contains four separate feature stubs:
- one Settlement component;
- one Road component;
- one River component;
- one Forest component.

The Road explicitly **terminates at/connects to the Settlement** inside the tile, creating Road–Settlement access for Trade Network purposes.

Forest and River remain separate from the Settlement and Road unless a later rule or explicit tile relationship says otherwise.

## RULE-SETUP-003 — Founding Tile participation
The Founding Tile counts normally as one tile in each of the four features it contains for:
- feature size;
- completion;
- scoring;
- Charters;
- milestones;
- Specialist/Relic calculations;
- historical records.

The Founding Tile is treated as an **Act I tile** for age/heritage effects such as Historic Routes, even though it is placed during setup.

It does not consume one of Act I's 18 normal placements.

## RULE-SETUP-004 — Founding Tile Development slot
The Founding Tile has the normal one-Development slot and may receive any Development for which one of its components is eligible, subject to normal Development stacking rules and exceptions.

## RULE-SETUP-005 — Exact setup sequence
A run is initialized in this order:
1. Create the unbounded board.
2. Place the fixed-orientation Founding Tile at `(0,0)`.
3. Set Population, Trade, Culture, and Ecology to 0.
4. Create 2 generic Stewards; both begin available.
5. Set active Relic capacity to 2; begin with no Relics.
6. Grant 1 Act I Survey charge.
7. Build the 55-tile Homestead starting bag.
8. Generate/record the deterministic run seed and randomize the bag.
9. Uniformly select and reveal 1 Act I Charter.
10. Draw the opening active hand of 3 tiles.
11. Begin with the Reserve empty.
12. Begin Act I at 0/18 normal placements completed.

There is no opening mulligan beyond the normal dead-hand/stalemate rules.

---

# 4. Tile Layers and Classes

## RULE-TILE-001 — Layered tile model
A board square can contain multiple systems while those systems remain mechanically distinct.

Conceptually the alpha uses:
- persistent geography/feature geometry from its base tile;
- a normal Development overlay slot;
- zero or more compatible Transformation modifications.

## RULE-TILE-002 — Expansion tiles
Expansion tiles add a new square to the board and establish persistent edge geometry.

## RULE-TILE-003 — Development tiles
Developments are played onto eligible existing squares rather than adding a new square.

Normal rule: **one Development per tile**.

Developments are edge-neutral unless their own text explicitly says otherwise.

A completed feature may receive a Development later.

## RULE-TILE-004 — Development host association
A Development records the specific host feature or relationship it belongs to rather than automatically belonging to every feature represented on its tile.

Examples:
- Housing is hosted by its Settlement;
- Market is hosted by its Settlement;
- Forester's Lodge is hosted by its Forest;
- Port is hosted by its Settlement and additionally records its specific associated River;
- Mill is tile-based Field development and dynamically evaluates current touching features;
- Monastery/Abbey is its own enclosure object centered on the tile.

Development host associations follow feature mergers automatically unless the Development's own rule says otherwise.

## RULE-TILE-005 — Transformations
Transformations are a separate modification layer from Developments and do not consume the normal Development slot unless their specific rule says otherwise.

Compatible Transformations may stack on the same board square.

A later Transformation modifies only what its text explicitly authorizes. There is no general "latest Transformation wins" rewrite rule.

A later Transformation may alter an edge changed by an earlier Transformation only if its own rule explicitly grants that specific rewrite.

## RULE-TILE-006 — Natural geography
For all alpha rules:

**Natural geography = Field, Forest, or River.**

Road and Settlement are built features.

A hybrid tile may contain both natural and built geography.

## RULE-TILE-007 — Fields are untracked support geography
Field participates in:
- edge matching;
- natural-geography checks;
- Settlement support;
- Development eligibility;
- Rewilding;
- Boundary Stones;
- other explicit effects.

Field does **not** form a completable feature, feature lineage, Specialist target, or endgame scoring region.

## RULE-TILE-008 — Touching
Unless a rule explicitly says otherwise, two different tiles "touch" when they share an orthogonal edge.

Diagonal contact does not count.

Features explicitly shown as meeting within the same tile also count as touching for the relationship that artwork/topology establishes.

Monastery/Abbey enclosure is the explicit eight-neighbor exception.

---

# 5. Alpha Tile Catalogue

## 5.1 Act I Expansion designs

### RULE-CAT-001 — Open Fields
- Edges: Field / Field / Field / Field.
- Role: neutral support geography.
- Basic Expansion.

### RULE-CAT-002 — Forest Edge
- 1 Forest edge + 3 Field edges.
- Forest endpoint/stub.
- Can start a Forest or close an existing Forest.
- Basic Expansion.

### RULE-CAT-003 — Forest Bend
- 2 adjacent Forest edges + 2 Field edges.
- The Forest edges are internally connected.
- Basic Expansion.

### RULE-CAT-004 — Forest Belt
- 2 opposite Forest edges + 2 Field edges.
- The Forest edges are internally connected.
- Basic Expansion.

### RULE-CAT-005 — River End
- 1 River edge + 3 Field edges.
- The same tile is used for both a River start/source and a River terminus.
- There is no separate River Source tile in the alpha.
- Basic Expansion.

### RULE-CAT-006 — River Run
- 2 opposite River edges + 2 Field edges.
- The River edges are internally connected.
- Basic Expansion.

### RULE-CAT-007 — River Bend
- 2 adjacent River edges + 2 Field edges.
- The River edges are internally connected.
- Basic Expansion.

### RULE-CAT-008 — Road End
- 1 Road edge + 3 Field edges.
- The same tile can start a Road or terminate/close one.
- There is no separate Road Start tile.
- Basic Expansion.

### RULE-CAT-009 — Straight Road
- 2 opposite Road edges + 2 Field edges.
- Road edges internally connected.
- Basic Expansion.

### RULE-CAT-010 — Bending Road
- 2 adjacent Road edges + 2 Field edges.
- Road edges internally connected.
- Basic Expansion.

### RULE-CAT-011 — Road Junction
- 3 Road edges + 1 Field edge.
- All three Road edges form one connected Road Feature.
- Four-way crossroads are deferred.
- Specialized/Hybrid Expansion.

### RULE-CAT-012 — Hamlet Edge
- 1 Settlement edge + 3 Field edges.
- Settlement endpoint/stub.
- Can start a Settlement or close an existing Settlement.
- Basic Expansion.

### RULE-CAT-013 — Settlement Corner
- 2 adjacent Settlement edges + 2 Field edges.
- Settlement edges internally connected.
- Basic Expansion.

### RULE-CAT-014 — Settlement Throughway
- 2 opposite Settlement edges + 2 Field edges.
- Settlement edges internally connected.
- Basic Expansion.

### RULE-CAT-015 — Settlement Gate
- 1 Settlement edge + 1 Road edge + 2 Field edges.
- Road and Settlement remain separate feature components.
- Road terminates at/connects to the Settlement internally.
- Creates Road–Settlement access for Trade Network purposes.
- Specialized/Hybrid Expansion.

### RULE-CAT-016 — Riverside Hamlet
- 1 Settlement edge + 2 opposite River edges + 1 Field edge.
- River runs straight through the tile.
- Settlement and River are mechanically distinct but explicitly touch within the tile.
- Specialized/Hybrid Expansion.

### RULE-CAT-017 — Woodland Road
- 2 adjacent Forest edges + 2 adjacent Road edges.
- The Forest pair is internally connected.
- The Road pair is internally connected.
- Road and Forest remain distinct features.
- Specialized/Hybrid Expansion.

### RULE-CAT-018 — Woodland River
- 2 adjacent Forest edges + 2 adjacent River edges.
- The Forest pair is internally connected.
- The River pair is internally connected.
- Forest and River are distinct but explicitly touch within the tile.
- Specialized/Hybrid Expansion.

### RULE-CAT-019 — Settlement Corner Gate
- 2 adjacent Settlement edges + 1 Road edge + 1 Field edge.
- Settlement continues through its corner.
- Road terminates at/connects to the Settlement internally.
- Creates Road–Settlement access.
- Specialized/Hybrid Expansion.

### RULE-CAT-020 — Settlement Road Bend
- 2 adjacent Settlement edges + 2 adjacent Road edges.
- The two Settlement edges form one continuous Settlement component.
- The two Road edges form one continuous Road component.
- Road and Settlement remain separate features but have an explicit internal Road–Settlement access link.
- Neither feature is required to terminate on this tile.
- Specialized/Hybrid Expansion.

### RULE-CAT-021 — Settlement Road Throughway
- 2 opposite Settlement edges + 2 opposite Road edges.
- Settlement edges form one continuous Settlement component.
- Road edges form one continuous Road component.
- The components remain distinct but have an explicit internal Road–Settlement access link.
- Specialized/Hybrid Expansion.

## 5.2 Act I Development designs

### RULE-CAT-022 — Monastery
See Section 11 for full Development rules.

### RULE-CAT-023 — Housing
See Section 11.

### RULE-CAT-024 — Mill
See Section 11.

### RULE-CAT-025 — Forester's Lodge
See Section 11.

## 5.3 Act II unlocks

### RULE-CAT-026 — Market
Act II Development. See Section 11.

### RULE-CAT-027 — Port
Act II Development. See Section 11.

### RULE-CAT-028 — Urban Expansion
Act II specialized Expansion/Transformation-style design placed into an empty square. See Section 12.

### RULE-CAT-029 — Town Square
Act II Development. See Section 11.

### RULE-CAT-030 — Abbey
Act II Development Upgrade of Monastery. See Section 11.

## 5.4 Act III unlocks

### RULE-CAT-031 — Bridge
Act III Major/Rare Transformation. See Section 12.

### RULE-CAT-032 — Rewilding
Act III Major/Rare Expansion/Transformation. See Section 12.

### RULE-CAT-033 — Grand Market
Act III Major/Rare Development Upgrade of Market. See Section 11.

---

# 6. Homestead Starting Bag and Tile Reward Classes

## RULE-BAG-001 — Starting bag contains Expansion tiles only
The initial Homestead bag contains no Developments, Upgrades, or Transformations.

## RULE-BAG-002 — Starting bag size
The Homestead starting bag contains **55 physical tiles**:

| Design | Copies |
|---|---:|
| Open Fields | 4 |
| Forest Edge | 3 |
| Forest Bend | 3 |
| Forest Belt | 2 |
| River End | 2 |
| River Run | 3 |
| River Bend | 3 |
| Road End | 3 |
| Straight Road | 4 |
| Bending Road | 4 |
| Road Junction | 2 |
| Hamlet Edge | 3 |
| Settlement Corner | 3 |
| Settlement Throughway | 2 |
| Settlement Gate | 2 |
| Riverside Hamlet | 2 |
| Woodland Road | 2 |
| Woodland River | 2 |
| Settlement Corner Gate | 2 |
| Settlement Road Bend | 2 |
| Settlement Road Throughway | 2 |
| **Total** | **55** |

## RULE-BAG-003 — Basic Expansion reward class
Choosing one of these from a normal Tile Reward adds **3 copies**:
- Open Fields
- Forest Edge
- Forest Bend
- Forest Belt
- River End
- River Run
- River Bend
- Road End
- Straight Road
- Bending Road
- Hamlet Edge
- Settlement Corner
- Settlement Throughway

## RULE-BAG-004 — Specialized/Hybrid Expansion reward class
Choosing one of these from a normal Tile Reward adds **2 copies**:
- Road Junction
- Settlement Gate
- Riverside Hamlet
- Woodland Road
- Woodland River
- Settlement Corner Gate
- Settlement Road Bend
- Settlement Road Throughway
- Urban Expansion

## RULE-BAG-005 — Ordinary Development reward class
Choosing an ordinary unlocked Development from a normal Tile Reward adds **2 copies** unless that design is classified Major/Rare.

This includes alpha Act I/II Developments and Abbey.

## RULE-BAG-006 — Act III Major/Rare reward class
Bridge, Rewilding, and Grand Market are Major/Rare tile designs for normal Tile Reward quantity.

Choosing one adds **1 copy**.

Their automatic Act III transition seeding still adds 2 copies each.


---

# 7. Hand, Reserve, Survey, Bag Randomization, and Dead-Hand Rules

## RULE-HAND-001 — Active hand
The player normally has an active hand of **3 tiles**.

When a tile is played from the active hand, that hand slot remains empty through the entire placement resolution, including:
- feature completion;
- Development effects;
- Specialist effects;
- Relic effects;
- Realm Track gains;
- Relic milestones;
- threshold rewards;
- any tiles added to the bag by those rewards.

Only after the placement's consequences are fully resolved is the empty active-hand slot refilled.

This means a tile newly added to the bag as a reward can potentially be drawn immediately as that replacement.

## RULE-HAND-002 — No voluntary pass
Every normal turn must end with exactly one legal tile placement from the active hand or Reserve.

The player may use legal pre-placement actions first, but may not voluntarily pass.

## RULE-HAND-003 — Reserve baseline
The player normally has **1 Reserve slot**.

If a Reserve slot is empty, the player may move one active-hand tile into that slot as a pre-placement action. The active hand is immediately refilled to 3.

A tile placed from Reserve:
- empties only that Reserve slot;
- does not cause an active-hand replacement draw, because the active hand was not reduced.

## RULE-HAND-004 — Reserve commitment
Once a tile enters Reserve, it cannot normally:
- return to the active hand;
- swap with another Reserve tile;
- be Surveyed;
- be voluntarily discarded;
- be voluntarily removed.

It remains in Reserve until legally placed unless an explicit effect says otherwise.

## RULE-HAND-005 — Reserve and Survey same turn
The player may use Reserve and Survey during the same normal turn before the required placement, in any legal order.

## RULE-HAND-006 — Wayfarer's Satchel Reserve behavior
Wayfarer's Satchel grants a second Reserve slot.

With two Reserve slots:
- both may be filled during the same normal turn if both are empty;
- each reservation immediately refills the active hand to 3;
- either occupied Reserve tile may later be chosen for placement;
- placing one empties only its own slot;
- the other remains committed.

## RULE-HAND-007 — Provably impossible Reserve safeguard
A Reserve tile is not discarded merely because it has no legal play now.

However, if the engine can prove that the tile:
1. has no legal placement in the current board state; **and**
2. cannot become legally playable through any action still available in the run,
then that physical tile is automatically removed from the run and its Reserve slot becomes empty.

This removal gives:
- no replacement draw;
- no compensation;
- no reward.

This is an emergency legality safeguard, not a player-controlled discard system.

## RULE-SURVEY-001 — Survey charges
Each Act begins with **1 fresh Survey charge**.

Unused Survey charges expire at Act transition and do not carry over unless an explicit effect says otherwise.

## RULE-SURVEY-002 — Normal Survey
A normal Survey is a pre-placement action.

Spend 1 Survey charge to:
1. choose 1 tile from the active hand;
2. permanently remove that physical copy from the run;
3. draw 1 replacement from the bag.

Survey is genuine bag thinning.

Reserve tiles cannot be Surveyed.

## RULE-SURVEY-003 — Grand Survey is not a normal Survey
Grand Survey is a Major Reward effect, not a normal Survey action.

It:
- does not consume a Survey charge;
- does not trigger Surveyor's Compass;
- may permanently remove up to 2 active-hand tiles;
- replaces removed tiles sequentially;
- grants +1 Survey charge for the current Act.

If the bag empties before a Grand Survey replacement draw, normal emergency replenishment occurs and the effect continues.

## RULE-BAG-007 — Deterministic run seed
Every run uses a single recorded deterministic random seed.

That seed governs all random decisions, including:
- initial bag order;
- draws;
- dead-hand cycling;
- bag re-randomization;
- Tile Reward offers;
- Relic offers;
- Specialist offers;
- Charter selection;
- Grand Charter selection;
- all other alpha random choices.

The same seed plus the same sequence of player choices should reproduce the same random sequence.

## RULE-BAG-008 — Full bag randomization on add/return
Whenever tiles are added or returned to the bag, the entire remaining bag is randomized using the deterministic run RNG.

This includes:
- Tile Reward additions;
- Act-transition seeding;
- dead-hand cycling returns;
- emergency replenishment.

Surveyor's Compass follows its own look-ahead rule.

## RULE-BAG-009 — Temporarily unplayable tiles stay normal
A Development, Upgrade, or other tile with no legal target **right now** is not individually auto-cycled merely because the player cannot currently place it.

The player may build toward making it legal.

## RULE-BAG-010 — Free full-hand dead-hand cycle
If all 3 active-hand tiles have zero legal plays anywhere on the current board, the player receives a free full-hand cycle:
1. return all 3 active-hand tiles to the bag;
2. randomize the bag;
3. draw a fresh active hand of 3.

The Reserve is untouched and ignored for purposes of determining whether the active hand qualifies for this free cycle.

The player is not forced to spend a playable Reserve tile to avoid cycling a dead active hand.

## RULE-BAG-011 — Global stalemate safeguard
If the engine establishes that neither the active hand nor any tile remaining in the bag has a legal play anywhere on the current board, inject the emergency replenishment set and redraw the dead hand.

Emergency set:
- 1 Hamlet Edge
- 1 Road End
- 1 Forest Edge

This safeguard can occur even after repeated dead-hand cycling.

## RULE-BAG-012 — Empty-bag emergency replenishment
Whenever the bag is empty and a draw is required, add exactly:
- 1 Hamlet Edge
- 1 Road End
- 1 Forest Edge

Then randomize and continue the draw.

Emergency replenishment is repeatable as often as necessary.

These fallback tiles are deliberately chosen because each can either:
- close an existing Settlement/Road/Forest; or
- start a new one.

---

# 8. Feature Topology, Completion, Reopening, and Lineage

## RULE-FEAT-001 — Connected feature objects
Roads, Settlements, Forests, and Rivers are tracked as connected feature objects/lineages based on their own feature geometry.

Field is not a feature object.

Monastery/Abbey is tracked as an enclosure object centered on one tile.

## RULE-FEAT-002 — Road completion
A connected Road Feature completes when it has **no unresolved Road exits facing empty board squares**.

All branches of a Road Junction must be closed.

A loop with no open Road exits completes.

## RULE-FEAT-003 — Settlement completion
A connected Settlement Feature completes when it has **no unresolved Settlement exits facing empty board squares**.

On completion it is Established for that growth phase.

## RULE-FEAT-004 — Forest completion
A connected Forest Feature completes when it has **no unresolved Forest exits facing empty board squares**.

Any physical tile containing part of that connected Forest counts as one Forest tile for size.

## RULE-FEAT-005 — River completion
A connected River Feature completes when it has **no unresolved River exits facing empty board squares**.

This supports endpoint-to-endpoint Rivers and closed loops.

The alpha deliberately uses the same closure grammar as other connection features; River identity comes primarily from scoring and relationships.

## RULE-FEAT-006 — Completed Rivers cannot normally reopen
A completed River is permanently closed in the alpha unless a future explicit effect grants River-reopening permission.

## RULE-FEAT-007 — Genuine completion event
A genuine `feature_completed` event occurs when a feature transitions from unfinished to complete.

A completed feature that is genuinely reopened, enters a new unfinished growth phase, and later closes again creates a genuine re-completion event.

Placing a Development on an already-completed feature does **not** create a new feature-completion event even if the Development immediately resolves its own effect.

## RULE-FEAT-008 — First completion vs re-completion history
Every completion record distinguishes:
- first completion;
- re-completion after genuine reopening.

Both are genuine completion events unless a rule specifically cares about first completion only.

A completion record should include at minimum:
- feature lineage ID;
- Act;
- turn/placement index;
- first-completion vs re-completion flag;
- total feature size;
- newly added/scoring tiles;
- relevant current relationships/state;
- Realm Track gains;
- triggered effects.

## RULE-FEAT-009 — Completion history remains valid after later changes
Once a genuine completion event occurs, that historical accomplishment remains recorded even if the feature is later:
- reopened;
- expanded;
- merged;
- transformed.

## RULE-FEAT-010 — Same feature can generate multiple completion events
A single lineage can generate multiple completion events if it genuinely reopens, undergoes a new growth phase, and re-completes.

This can satisfy historical Charter requirements multiple times when those requirements count completion events.

## RULE-FEAT-011 — Feature merger event
`feature_merged` is its own event type.

A merger does not inherently score anything unless another rule explicitly listens for it.

## RULE-FEAT-012 — Feature reopening event
`feature_reopened` is its own event type when a previously completed feature becomes unfinished again.

## RULE-FEAT-013 — Indirect completion
Feature completion is determined from resulting board state, not from which tile/effect directly targeted the feature.

If a placement, Transformation, or merge indirectly causes a feature to become complete, it completes normally and all valid completion effects resolve.

## RULE-FEAT-014 — Feature merge history
When feature lineages merge, their prior scoring and event histories are preserved and combined into the resulting lineage.

Old scoring is not erased by merger.

## RULE-FEAT-015 — Historical feature-size records
The run permanently tracks:
- Largest Settlement ever Established;
- Largest Forest ever completed;
- Longest Road ever completed;
- Longest River ever completed.

These are historical records/statistics unless a rule explicitly references them.

---

# 9. Base Scoring and Scoring History

## RULE-SCORE-001 — Realm Track identity
Base feature associations are:
- Settlement → Population
- Road → Trade
- Forest → Ecology
- River → Ecology
- Monastery/civic development → Culture

Later Developments, Specialists, and Relics create cross-Track scoring.

## 9.1 Settlement scoring

### RULE-SCORE-SET-001 — Settlement base Population
On genuine Settlement completion, base Population is:
- **+2 Population per newly scoring Settlement tile**;
- **+1 Population per newly scoring distinct Field-support tile touching the Settlement**;
- **+1 Population per newly scoring distinct River-support tile touching the Settlement**.

### RULE-SCORE-SET-002 — Settlement tile scoring history
A Settlement tile can pay its +2 base Population to a given Settlement lineage only once.

When a Settlement is reopened and re-completes, previously scored Settlement tiles do not pay again. Newly incorporated Settlement tiles can pay on the new completion.

### RULE-SCORE-SET-003 — Settlement support history
A particular Field or River support tile can provide its corresponding +1 base support bonus to a particular Settlement lineage only once.

On re-completion, only newly acquired support relationships generate base support Population.

### RULE-SCORE-SET-004 — Shared support between Settlements
The same Field or River tile may support multiple different Settlement lineages independently.

Support history is tracked per:
`support tile ↔ Settlement lineage ↔ support category`.

### RULE-SCORE-SET-005 — Same-tile Field support
If a tile contains both Settlement and Field geography and those areas visibly meet, that physical tile counts as one Field-support tile for that Settlement.

### RULE-SCORE-SET-006 — Multiple support categories on one tile
A single physical tile may contribute once per distinct support category it genuinely provides.

Example: a Riverside Hamlet can contribute both:
- 1 Field-support relationship; and
- 1 River-support relationship;
to the same Settlement if both relationships are explicitly present.

### RULE-SCORE-SET-007 — Rewilding and historical support
If Rewilding converts Field geography that previously supported a Settlement into Forest:
- already earned Population is never removed;
- historical support remains recorded;
- the tile ceases to be current Field support;
- it no longer contributes to Homesteader/current Field checks;
- if it later somehow becomes Field again, old scoring history still prevents duplicate base support scoring.

Rewilding may remove the last current Field-support relationship from a Settlement.

## 9.2 Road scoring

### RULE-SCORE-ROAD-001 — Road base Trade
On genuine completion of a Road Feature, base Trade is:
- **+1 Trade per newly scoring Road tile**;
- **+2 Trade per distinct Settlement in that Road's current full Trade Network that has not previously paid that Road lineage's base connection bonus**.

Trade Network rules are in Section 10.

### RULE-SCORE-ROAD-002 — Road tile history
A Road tile can pay its +1 base Trade to a Road lineage only once.

Previously scored Road tiles do not pay again merely because Bridge reopens, merges, or extends the Road.

### RULE-SCORE-ROAD-003 — Per-Road/per-Settlement history
Each Road lineage permanently records which Settlement lineages/nodes have already paid its +2 base Trade connection bonus.

If a Settlement leaves the Road's Trade Network and later rejoins, it does not pay that Road again.

### RULE-SCORE-ROAD-004 — Merged Settlement ancestry anti-farming
If any ancestor of a merged Settlement has already paid a Road lineage's +2 base Trade connection bonus, the resulting merged Settlement is treated as already scored by that Road lineage.

A Road that had scored none of the merged Settlement's ancestors may score the current merged Settlement once.

### RULE-SCORE-ROAD-005 — Network growth and old Roads
If a Road lineage genuinely reopens and later completes after its Trade Network has expanded, newly reachable Settlements can provide that Road's +2 base connection bonus even if those Settlements joined the Trade Network through other Road Features.

Old already-scored Settlements do not pay again.

## 9.3 Forest scoring

### RULE-SCORE-FOREST-001 — Forest base Ecology
On genuine Forest completion:
- gain **+1 Ecology per newly scoring Forest tile**;
- if the completed Forest is undeveloped, gain an additional flat **+2 Ecology preservation bonus**.

### RULE-SCORE-FOREST-002 — Forest tile history
Previously scored Forest tiles do not pay their +1 base Ecology again after Rewilding reopens/merges the Forest.

New Forest growth can score on the next genuine completion.

### RULE-SCORE-FOREST-003 — Preservation reevaluation
The +2 undeveloped preservation bonus is reevaluated at every genuine Forest completion/re-completion based on the current completed Forest state.

### RULE-SCORE-FOREST-004 — Developed Forest definition
A connected Forest is considered **developed** if any tile belonging to that Forest contains any Development, except Forester's Lodge.

Forester's Lodge explicitly preserves undeveloped status.

Transformations such as Bridge and Rewilding are not Developments and do not by themselves break undeveloped status.

## 9.4 River scoring

### RULE-SCORE-RIVER-001 — River base Ecology
On River completion:
- gain **+1 Ecology per 2 River tiles, rounded down**;
- gain **+1 Ecology per distinct Forest tile touching that River**.

Because completed Rivers cannot normally reopen in the alpha, the River-length component is normally evaluated once from the River's full size at its completion.

### RULE-SCORE-RIVER-002 — River–Forest contact history
Each distinct Forest tile may provide its +1 base Ecology contact bonus to a given River lineage only once.

This history is retained for future-proofing even though ordinary alpha Rivers do not reopen.

### RULE-SCORE-RIVER-003 — Same-tile River–Forest contact
If Forest and River geography explicitly meet within the same hybrid tile, that tile counts as one Forest tile touching that River.

It can contribute to River base Ecology, Riverkeeper, and relevant checks once per applicable rule.

## 9.5 Monastery/Abbey scoring

### RULE-SCORE-MON-001 — Monastery enclosure
A Monastery completes when all **8 surrounding squares** are occupied.

Already occupied neighboring squares count immediately when the Monastery is placed.

### RULE-SCORE-MON-002 — Monastery Culture
On completion, Monastery gives:
- **+5 Culture**;
- **+1 Culture per surrounding tile containing at least one natural geography type**.

Each surrounding square contributes at most +1 natural-geography Culture even if it contains multiple natural types.

### RULE-SCORE-MON-003 — Abbey Culture
On completion, Abbey gives:
- **+8 Culture**;
- **+1 Culture per surrounding tile containing natural geography**;
- **+1 Culture per surrounding tile containing Settlement**.

A mixed surrounding tile can therefore contribute +2 to Abbey: +1 natural and +1 Settlement.

---

# 10. Road Features, Settlement Access, and Trade Networks

## RULE-TRADE-001 — Road Feature vs Trade Network
A **Road Feature** is a physically continuous component of Road geometry.

A **Trade Network** is the larger economic graph formed by:
- Road Features;
- Settlements acting as hubs;
- Ferry Rights links when that Relic is active.

These are distinct concepts.

## RULE-TRADE-002 — Road–Settlement connection requires explicit access
A Settlement is connected to a Road only if explicit geometry/topology establishes Road–Settlement access.

Examples include:
- Settlement Gate;
- Settlement Corner Gate;
- Settlement Road Bend;
- Settlement Road Throughway;
- Urban Expansion;
- Founding Tile;
- Bridge-created Road access;
- any future tile explicitly showing such a relationship.

Simple orthogonal adjacency between a Road tile and Settlement tile is not enough.

## RULE-TRADE-003 — Access link does not merge features
A Road–Settlement access relationship does not merge Road and Settlement into one feature.

Road and Settlement:
- retain separate components;
- complete independently;
- keep separate sizes and histories.

The access relationship joins them economically in the Trade Network graph.

## RULE-TRADE-004 — Settlement as hub
Separate Road Features that connect to the same Settlement remain separate Road Features but belong to the same Trade Network.

The Settlement is a trade hub between them.

## RULE-TRADE-005 — Transitive Trade Network connectivity
Trade Network connectivity propagates transitively through Settlement hubs.

Example:
Road A → Settlement 1 → Road B → Settlement 2 → Road C → Settlement 3
forms one Trade Network even if Roads A, B, and C are physically separate Road Features.

## RULE-TRADE-006 — Unfinished Roads participate immediately
A Road Feature does not need to be complete before its Road–Settlement access relationships contribute to Trade Network topology.

An unfinished Road can extend the Trade Network immediately.

## RULE-TRADE-007 — Unfinished Settlements participate immediately
A connected Settlement does not need to be Established before acting as a Trade Network hub.

Trade topology follows current physical/economic connectivity, not completion status.

## RULE-TRADE-008 — A Trade Network requires Road access
An isolated Settlement with no Road connection is not itself a Trade Network.

A Trade Network exists only when at least one Road Feature is explicitly connected to at least one Settlement.

Ferry Rights cannot create a free-standing river-only Trade Network; it extends a network that already has Road access.

## RULE-TRADE-009 — Road completion sees full network snapshot
When a Road Feature genuinely completes, its Settlement-connectivity base Trade uses the **entire current Trade Network** containing that Road at the exact completion snapshot.

This includes connectivity contributed by:
- other completed Roads;
- other unfinished Roads;
- unfinished Settlements;
- Ferry Rights, if active.

Later Trade Network expansion does not retroactively alter the completed Road's resolved base score unless that Road genuinely reopens and completes again.

## RULE-TRADE-010 — Current-state network checks
Current-state Charter/milestone conditions involving commercial connectivity evaluate the current Trade Network graph immediately.

A Road or Settlement does not need to complete before its current connectivity can satisfy a current-state network requirement.

## RULE-TRADE-011 — Trade Network persistence and genealogy
Trade Networks have persistent identity/history for run tracking.

They can:
- grow;
- merge;
- split when a connectivity-granting rule such as Ferry Rights disappears;
- later reconnect.

Split descendants retain ancestry. Reconnection recombines ancestry rather than creating a history-free network.

Individual Road/Settlement scoring histories remain authoritative for anti-farming.

## RULE-TRADE-012 — Network merger does not score by itself
Merging two Trade Networks is a topology/state change only.

It does not automatically:
- award Trade;
- retrigger Markets;
- rescore Roads;
- trigger Merchant.

Later legitimate scoring triggers use the new larger network.

## RULE-TRADE-013 — Settlement merger merges Trade Networks
If Urban Expansion merges Settlements belonging to different Trade Networks, those networks merge immediately because the resulting Settlement is one shared hub.

This is a state change only and grants no automatic Trade.

## RULE-TRADE-014 — Current distinct Settlement count
Trade Network Settlement counts use the current number of distinct Settlement nodes.

If two Settlements merge, they count as one current Settlement from then on.

Historical achievements and anti-farming ancestry remain recorded separately.

## RULE-TRADE-015 — Trade systems using full Trade Network
The following use the **full Trade Network** rather than only one physical Road Feature:
- Road completion's Settlement-connectivity base Trade;
- Merchant;
- Market;
- Grand Market;
- Ferry Rights propagation;
- Road/network Charter requirements involving connected Settlements;
- the 5-Settlement Road Relic milestone;
- Merchant Republic Grand Charter connectivity.

## RULE-TRADE-016 — Systems using individual Road Feature
The following use the physical Road Feature only:
- Road open-exit/completion status;
- Road tile count;
- Cartographer;
- Historic Routes;
- Bridge physical Road merging/reopening;
- Longest Road record;
- The Long Road qualification;
- Specialist occupancy.

## RULE-TRADE-017 — Market does not passively retrigger on network growth
Trade Network expansion alone does not retrigger Market or Grand Market.

They resolve only on their defined Development trigger events.


---

# 11. Developments and Upgrades

## RULE-DEV-001 — General placement on completed features
A Development may be placed on a feature whose relevant completion condition is already satisfied.

If the newly placed Development's trigger condition is already satisfied, **that newly placed Development resolves its own effect immediately once**.

Existing Developments on the same completed feature do not retrigger merely because a new Development was added.

This immediate Development resolution is not a new feature-completion event.

## RULE-DEV-002 — Development placement vs completion event
`development_placed` and `feature_completed` are separate event types.

An effect that listens for Development placement may respond to `development_placed`.

An effect that requires feature completion does not trigger unless a genuine `feature_completed` event occurs.

## RULE-DEV-003 — Multiple already-completed relevant features
If a newly placed Development is relevant to multiple distinct completed features and its rule triggers from each qualifying feature, it resolves once for each qualifying feature.

Mill is the primary alpha example.

## RULE-DEV-004 — Duplicate Development families
Multiple physical copies of the same Development family may exist in the same connected feature if they occupy separate legal Development slots.

Each physical copy triggers independently.

For diversity checks, duplicate copies still count as one Development family.

## RULE-DEV-005 — Upgrade prerequisite
An Upgrade tile may only be played onto its required base Development.

Alpha upgrades:
- Abbey requires an existing Monastery.
- Grand Market requires an existing Market.

An Upgrade cannot be placed directly into an empty Development slot.

## RULE-DEV-006 — Upgrade replacement
When upgraded:
- the base Development is permanently replaced and removed from the run;
- it does not return to the bag;
- the upgraded Development occupies the base Development's slot;
- historical record may retain that the base Development previously existed there.

## RULE-DEV-007 — Upgrade immediate trigger
An Upgrade represents a new Development stage.

If the upgraded form's completion/trigger condition is already satisfied at the moment of upgrade, the upgraded Development resolves immediately once.

This is the default for future upgrades unless a specific upgrade says otherwise.

## RULE-DEV-008 — Upgrade family identity
An upgraded Development retains its base Development family for diversity checks.

Examples:
- Market and Grand Market are the same family.
- Monastery and Abbey are the same family.

## RULE-DEV-009 — Development trigger batch
When several Developments trigger from the same feature-completion event:
1. calculate every applicable Development effect from the shared completion snapshot;
2. apply their results as the Development batch;
3. only then move to Specialist effects.

One Development's result does not alter what another simultaneously triggered Development sees.

## RULE-DEV-010 — Development host after merger
When host features merge, Developments follow the resulting host lineage automatically.

Port retains its specific River association.

Mill remains tile-based and dynamically evaluates current contacts.

## 11.1 Monastery

### RULE-DEV-MON-001 — Placement
Monastery may be placed on an **undeveloped tile containing Field geography**, provided the tile has no Development already occupying its normal Development slot.

### RULE-DEV-MON-002 — Enclosure starts immediately
Monastery enclosure tracking begins immediately on placement. Already occupied surrounding squares count.

If all 8 surrounding squares are already occupied, Monastery completes and scores immediately.

### RULE-DEV-MON-003 — Specialist timing
A newly placed Monastery can receive a generic Steward only if it remains unfinished after placement.

If it completes immediately, no last-second Steward may be assigned.

## 11.2 Housing

### RULE-DEV-HOUSE-001 — Placement
Housing is placed on an eligible Settlement tile with an available Development slot, subject to Mixed-Use Charter.

### RULE-DEV-HOUSE-002 — Effect
Whenever its Settlement genuinely completes, each Housing gives **+2 Population**.

If Housing is placed into an already Established Settlement, the newly placed Housing immediately gives +2 Population once.

Housing can trigger again on a later genuine re-completion of the host Settlement.

## 11.3 Market

### RULE-DEV-MARKET-001 — Unlock
Market is not in the initial bag. It unlocks at the start of Act II.

### RULE-DEV-MARKET-002 — Placement
Market is placed on an eligible Settlement tile with an available Development slot, subject to Mixed-Use Charter.

### RULE-DEV-MARKET-003 — Effect
Whenever its Settlement genuinely completes, Market gives:

**+1 Trade per distinct OTHER Settlement in the host Settlement's current full Trade Network.**

If Market is placed into an already Established Settlement, the newly placed Market resolves that calculation immediately once.

Trade Network growth alone does not retrigger Market.

Ferry Rights connections count when active.

## 11.4 Mill

### RULE-DEV-MILL-001 — Placement
Mill may be placed on any eligible **undeveloped Field tile** with an available Development slot.

### RULE-DEV-MILL-002 — Effect
Whenever a Settlement touching that Mill genuinely completes:
- gain **+2 Population**;
- if the Mill also currently touches a River, gain **+1 Trade** for that Settlement-triggered Mill resolution.

If Mill is placed while touching one or more already Established Settlements, it immediately resolves once for each such Settlement.

## 11.5 Port

### RULE-DEV-PORT-001 — Unlock
Port unlocks at the start of Act II.

### RULE-DEV-PORT-002 — Placement
Port is placed on an eligible Settlement tile that explicitly touches a River.

When placed, the Port is permanently associated with that specific connected River feature.

If separate Rivers later become one connected River, their Ports naturally become part of the same Port network.

### RULE-DEV-PORT-003 — Effect
Whenever its Settlement genuinely completes, each Port independently gives:
- **+2 Trade**;
- **+1 Trade for every other Port on the same connected River**.

If Port is placed into an already Established qualifying Settlement, the newly placed Port resolves immediately once.

Multiple Ports in one Settlement are legal if they occupy separate legal tile slots and each has a valid River association.

## 11.6 Forester's Lodge

### RULE-DEV-LODGE-001 — Placement
Forester's Lodge may be placed on a Forest tile with an available Development slot.

### RULE-DEV-LODGE-002 — Light development exception
Forester's Lodge does **not** break the host Forest's undeveloped status.

It therefore does not prevent:
- the Forest's +2 preservation bonus;
- Naturalist eligibility.

### RULE-DEV-LODGE-003 — Effect
Whenever the host Forest genuinely completes, each Forester's Lodge gives **+1 Ecology**.

If a Lodge is placed into an already completed Forest, the newly placed Lodge gives +1 Ecology immediately once.

Existing Lodges retrigger normally on genuine later Forest re-completions.

## 11.7 Town Square

### RULE-DEV-SQUARE-001 — Unlock and placement
Town Square unlocks at the start of Act II.

Place it on an eligible Settlement tile with an available Development slot.

### RULE-DEV-SQUARE-002 — Effect
Whenever its Settlement genuinely completes, Town Square gives:

**+2 Culture per distinct Development family currently present in the Settlement**, including the Town Square family itself.

If placed into an already Established Settlement, the newly placed Town Square resolves that current diversity calculation immediately once.

## 11.8 Abbey

### RULE-DEV-ABBEY-001 — Upgrade
Abbey unlocks at the start of Act II and may only replace an existing Monastery.

The Monastery physical tile is removed from the run; Abbey replaces it in the Development slot.

### RULE-DEV-ABBEY-002 — Enclosure
Abbey uses the same surrounding-eight occupancy condition as Monastery.

If the upgraded Monastery was already surrounded/completed, Abbey's enclosure condition is already satisfied and Abbey completes/scores its new stage immediately.

### RULE-DEV-ABBEY-003 — Scoring
See RULE-SCORE-MON-003.

## 11.9 Grand Market

### RULE-DEV-GMARKET-001 — Upgrade
Grand Market unlocks in Act III and may only replace an existing Market.

The Market physical tile is removed from the run; Grand Market replaces it.

### RULE-DEV-GMARKET-002 — Effect
Whenever its Settlement genuinely completes, Grand Market gives:

**+2 Trade per distinct OTHER Settlement in the host Settlement's current full Trade Network.**

If upgraded inside an already Established Settlement, Grand Market immediately performs that calculation once.

This does not retroactively alter Trade previously generated by the old Market.

Trade Network growth alone does not retrigger Grand Market.

---

# 12. Transformations and Feature Growth

## 12.1 General Transformation rules

### RULE-TRANS-001 — Separate layer
Transformations do not occupy the normal Development slot unless a specific rule says otherwise.

### RULE-TRANS-002 — Compatible stacking
Multiple Transformations may affect the same square if all prerequisites and resulting geometry remain legal.

Each Transformation preserves prior compatible modifications unless its text explicitly removes/replaces them.

## 12.2 Urban Expansion

### RULE-URBAN-001 — Unlock and class
Urban Expansion unlocks at the start of Act II.

It is a specialized Expansion/Transformation-style tile played into an **empty square**.

### RULE-URBAN-002 — Geometry
Urban Expansion has:
- 2 opposite Settlement edges;
- 1 Road edge;
- 1 Field edge.

The Road terminates at/connects to the Settlement internally, creating Road–Settlement access.

### RULE-URBAN-003 — Start a new Settlement
Urban Expansion may be placed under normal exact-matching rules to start a brand-new unfinished Settlement.

Its two opposite Settlement edges create a through Settlement component; one or both may remain open into empty squares.

### RULE-URBAN-004 — Reopen an Established Settlement
When placed into an empty square adjacent to an Established Settlement, Urban Expansion may target a facing **Field boundary edge belonging to that Settlement** and permanently rewrite that boundary edge from Field → Settlement.

The corresponding Urban Expansion Settlement edge then connects to the old Settlement.

Its opposite Settlement edge normally remains available for further growth unless already legally connected.

The combined Settlement becomes unfinished if any Settlement exits remain open.

### RULE-URBAN-005 — Rewrite up to two boundaries
Urban Expansion may rewrite up to **two opposite facing Field boundary edges** into Settlement edges during one placement if those boundaries belong to Settlements being connected.

This allows it to:
- reopen one completed Settlement;
- merge two completed Settlements;
- merge unfinished/completed Settlement components when otherwise legal.

Road and Field sides still obey their own legality rules.

### RULE-URBAN-006 — Settlement merger
Urban Expansion may merge two existing Settlements into one connected Settlement lineage.

The universal Specialist merge restriction still applies.

### RULE-URBAN-007 — Merged Settlement history
When Settlements merge:
- prior Settlement tile scoring histories combine;
- prior Field/River support histories combine;
- previously scored Settlement tiles do not base-score again;
- previously scored support relationships do not base-score again;
- Urban Expansion itself counts as new Settlement growth;
- genuinely new Settlement tiles/support can score on the next completion;
- all Developments from both ancestors belong to the merged Settlement;
- current total size determines classification, Charter checks, One Great City, etc.

### RULE-URBAN-008 — Immediate closed merger completion
If Urban Expansion merges completed Settlements and the resulting Settlement has no open Settlement exits, it immediately creates a genuine new Settlement completion.

Only new base-scoring elements pay again, but all applicable Development/completion effects can trigger normally.

The event is recorded in completion history.

### RULE-URBAN-009 — Current Trade Network identity after merge
Merged Settlements become one current Trade Network node.

Their attached Road Features and Trade Networks become connected through that merged hub.

Previously earned Trade is not removed or automatically rescored.

## 12.3 Bridge

### RULE-BRIDGE-001 — Unlock and target
Bridge is an Act III Major/Rare Transformation.

It may only be played onto an existing tile whose underlying River geometry is a **straight River Run**.

A Rewilded River Run still satisfies Bridge's underlying target prerequisite if its River remains straight; current effective-edge legality must also be satisfied.

### RULE-BRIDGE-002 — Core transformation
Bridge preserves the continuous straight River and adds a Road crossing **perpendicular** to that River. The target River Run's two Field-facing edges on that perpendicular axis become Road edges as part of the Bridge Transformation.

The Bridge Transformation itself does not occupy the normal Development slot.

Any existing Development on the target River Run is preserved.

### RULE-BRIDGE-002a — Current effective-edge legality
A Rewilded straight River Run still satisfies the underlying straight-River prerequisite. This does not grant Forest → Road rewrite permission. Bridge requires both perpendicular effective edges to be legally rewriteable under its explicit Field → Road rule. If Rewilding has converted either required edge to Forest, no legal Bridge placement exists on that square in the current alpha. The Forest and its Transformation history remain intact; underlying target eligibility never bypasses effective-edge legality.

### RULE-BRIDGE-003 — River state
Bridge does not by itself:
- reopen the River;
- re-complete the River;
- rescore the River.

The underlying River remains in its prior completion state.

### RULE-BRIDGE-004 — Bridge Road sides
For each side along the Bridge Road axis:
- **empty neighboring square:** leave an open Road exit for future growth;
- **existing Road tile with a facing Field edge:** rewrite that facing Field edge to Road and connect into the existing Road component;
- **Settlement tile with a facing Field edge:** rewrite that facing Field edge to Road and create an explicit Road–Settlement access connection;
- **other occupied nonqualifying edge/tile:** that orientation is illegal unless another explicit rule authorizes the rewrite.

### RULE-BRIDGE-005 — Bridge connection modes
A Bridge may therefore:
- connect Road ↔ Road;
- connect Road ↔ Settlement;
- connect Settlement ↔ Settlement;
- start a new Road toward one or both empty sides.

### RULE-BRIDGE-006 — Road merge
If Bridge physically connects two existing Road Features, they merge into one Road Feature lineage for:
- completion;
- Road size;
- Longest Road;
- The Long Road;
- Road Specialists;
- Historic Routes;
- future physical Road connectivity.

Their prior scoring histories combine.

### RULE-BRIDGE-007 — Reopening completed Roads
If Bridge causes a previously completed Road to gain any open Road exit, the merged Road becomes unfinished and begins a new growth phase.

If the resulting merged Road is immediately closed, it immediately generates a genuine new Road completion.

### RULE-BRIDGE-008 — Bridge tile identity
After transformation, the target square counts simultaneously as:
- 1 River tile in the original River;
- 1 Road tile in the Bridge Road Feature.

The River does not gain an extra tile.

The Bridge-created Road component is new Road growth and can provide its +1 base Trade when appropriate.

### RULE-BRIDGE-009 — Neighboring Settlement gains Road tile identity
If Bridge rewrites a facing Field edge on a Settlement tile into Road and that tile did not already contain a Road component:
- that Settlement tile gains a genuine Road component;
- it counts as 1 Road tile in the relevant Road Feature;
- it is new Road growth for scoring history;
- the new Road component explicitly connects to the Settlement on that tile;
- the Settlement immediately participates in the relevant Trade Network through that Road.

### RULE-BRIDGE-010 — Rewriting an existing Road tile
If Bridge rewrites a Field edge on a tile that already contains the connected Road component:
- the new edge joins that existing Road component;
- the tile remains only 1 Road tile;
- the old tile does not gain another +1 base Trade;
- it does not count as newly constructed Road growth merely because it gained a new exit.

### RULE-BRIDGE-011 — Previously scored Road content
Previously scored Road tiles and previously rewarded Settlement connections do not base-score again merely because Bridge merges or reopens them.

New Road growth and newly eligible per-Road Settlement connections score under normal history rules at the next genuine Road completion.

## 12.4 Rewilding

### RULE-REWILD-001 — Unlock and base geometry
Rewilding is an Act III Major/Rare tile with two explicit placement categories plus a completed-Forest boundary-extension permission.

Its basic Rewilding geometry is:
- 2 opposite Forest edges;
- 2 Field edges.

### RULE-REWILD-002 — Expansion mode
Rewilding may be placed into an empty square under normal Expansion rules.

It can:
- start a new unfinished Forest;
- extend an unfinished Forest;
- participate in a legal Forest merge.

### RULE-REWILD-003 — Completed-Forest boundary extension
When placing Rewilding into an empty square beside a completed Forest, it may target one facing Field boundary edge belonging to that Forest and permanently rewrite that edge Field → Forest as part of placement.

The Rewilding Forest edge connects to it, reopening/extending that Forest.

The opposite Rewilding Forest edge remains open unless already legally connected.

### RULE-REWILD-004 — Occupied-tile Transformation mode
A Rewilding tile may instead be consumed to transform an existing tile containing Field geography.

The player chooses a legal orientation for the Rewilding Forest axis.

The Transformation:
- converts eligible Field geography into Forest geography;
- may convert the required eligible Field edges into the Rewilding Forest edges;
- preserves existing Road and Settlement features/components;
- preserves other compatible geography such as River;
- does not consume the normal Development slot.

The play still consumes the physical Rewilding tile and counts as the turn's placement.

### RULE-REWILD-005 — Edge legality in occupied Transformation mode
Each new Forest edge created by Rewilding must replace an eligible Field edge and must face either:
- an existing Forest edge; or
- an empty neighboring square.

It may not create a Forest edge directly against an occupied non-Forest edge.

Existing built Road/Settlement edges are preserved rather than overwritten.

If no legal orientation exists, that tile is not a legal Rewilding Transformation target.

### RULE-REWILD-006 — Rewilding on Road/Settlement hybrids
A tile containing Road or Settlement may be Rewilded if:
- it contains eligible Field geography/edges;
- all Rewilding edge legality conditions can be satisfied;
- no Field-dependent Development blocks the Transformation.

The Road/Settlement feature remains intact.

### RULE-REWILD-007 — Field-dependent Development restriction
Rewilding cannot target a tile containing a Development whose continued legality depends on Field geography, including:
- Mill;
- Monastery.

Settlement Developments such as Housing or Market are not automatically destroyed merely because Field geography on their tile is Rewilded; their Settlement host is preserved.

### RULE-REWILD-007a — Abbey's continuing enclosure host
The restriction evaluates current continued legality, not historical placement prerequisites. Mill and Monastery remain Field-dependent and block Rewilding. Abbey, once upgraded, is enclosure-dependent rather than Field-dependent. Otherwise-legal Rewilding may therefore transform an Abbey square without removing or invalidating the Abbey.

Preserve the physical Abbey copy, enclosure ID and coordinate, Monastery-family identity, and prior stage completion history. Rewilding does not create another Abbey stage or retrigger its scoring. A completed Abbey stays completed; an incomplete Abbey continues to use the surrounding-eight occupancy condition. All ordinary Rewilding edge and geography restrictions still apply.

### RULE-REWILD-008 — Already-Forested hybrid
Rewilding may target a tile that already contains some Forest if it also contains eligible Field geography.

It may convert the remaining eligible Field geography/edges into Forest.

If the tile already belonged to a Forest, the physical tile does **not** become a second newly scoring Forest tile. Only the new connectivity/reopening/merger effects are new.

### RULE-REWILD-009 — New Forest growth identity
If Rewilding transforms a tile that did not previously belong to a Forest, that tile becomes new Forest growth for the resulting Forest lineage and may provide its +1 base Ecology at the next genuine Forest completion.

### RULE-REWILD-010 — Reopening Forests
If Rewilding joins an existing completed Forest and leaves any Forest exit open, that Forest becomes unfinished and begins a new growth phase.

Prior scoring history is retained.

### RULE-REWILD-011 — Merging completed Forests
If Rewilding joins previously completed Forests, they become one connected Forest lineage.

If the resulting merged Forest is immediately closed:
- it immediately generates a genuine new Forest completion;
- previously scored Forest tiles do not pay base Ecology again;
- new Rewilding growth can score;
- the +2 undeveloped preservation bonus is reevaluated;
- Forester's Lodge and other completion triggers resolve normally.

If any Forest exit remains open, the merged Forest remains unfinished.

---

# 13. Settlement Growth, Classification, and History

## RULE-SETCLASS-001 — Settlement growth phases
The first time a Settlement closes, it becomes Established and completes its first growth phase.

Urban Expansion can reopen an Established Settlement in Act II+.

A reopened Settlement is unfinished until all Settlement exits close again.

## RULE-SETCLASS-002 — Base scoring on re-establishment
Previously scored Settlement tiles do not generate their +2 base Population again.

Only newly incorporated Settlement tiles can produce new base tile Population.

Support follows its own per-relationship history rules.

## RULE-SETCLASS-003 — Developments retrigger on genuine re-completion
All applicable Settlement Developments remain part of the Settlement and trigger normally on every genuine later Settlement re-completion.

This includes old Developments from prior growth phases.

## RULE-SETCLASS-004 — Settlement classifications
Current alpha Settlement classes are:
- **Hamlet:** 1–2 Settlement tiles
- **Village:** 3–5 Settlement tiles
- **Town:** 6–8 Settlement tiles **and** at least 1 Development
- **City:** 9+ Settlement tiles **and** at least 2 distinct Development families

A Settlement retains the highest classification it has qualified for unless a future explicit rule says classification can be lost.

Current size and current Development state are still used for current-state Charter checks independently of historical highest class.

## RULE-SETCLASS-005 — Settlement completion record
Each Establishment/re-establishment record should retain at least:
- Act;
- total current size;
- newly added Settlement tiles in that growth phase;
- previously Established tiles;
- Development families present;
- current support relationships;
- Realm Track rewards generated;
- associated completion triggers.

---

# 14. Stewards and Specialists

## RULE-SPEC-001 — Starting pieces and hard cap
The player starts with **2 generic Stewards**.

A third piece may be acquired during the run.

The alpha hard cap is **3 total Steward/Specialist pieces**, counting generic and trained pieces together.

## RULE-SPEC-002 — Generic Steward
A generic Steward may be assigned to an eligible unfinished:
- Road;
- Settlement;
- Forest;
- River;
- Monastery.

On genuine completion, the Steward gives **+2 to the associated Realm Track**:
- Road → +2 Trade
- Settlement → +2 Population
- Forest → +2 Ecology
- River → +2 Ecology
- Monastery → +2 Culture

Then the Steward returns to availability.

## RULE-SPEC-003 — Generic Steward on Monastery
A generic Steward may be assigned to a newly placed unfinished Monastery.

If the Monastery is already surrounded and completes immediately, assignment is too late.

None of the eight trained alpha Specialists can work Monasteries unless their own rule explicitly says otherwise.

## RULE-SPEC-004 — One Specialist per connected unfinished feature
A connected unfinished feature may contain at most **one Steward/Specialist**.

Duplicate Specialist roles are allowed across different features.

## RULE-SPEC-005 — Universal merge legality
Any placement or Transformation that would result in one connected unfinished feature containing more than one Steward/Specialist is illegal.

This applies to normal placement, Bridge, Rewilding, Urban Expansion, and future merge effects.

## RULE-SPEC-006 — Specialist follows legal merger
If an unfinished feature containing one Specialist merges with an unfinished feature containing none, the Specialist follows the resulting merged lineage.

Original assignment timing/growth metadata is preserved.

Pre-existing absorbed tiles do not become "added after assignment."

## RULE-SPEC-007 — Assignment timing and locality
After committing a placement, the player may optionally assign **one** available eligible Steward/Specialist if the directly affected feature remains unfinished after placement.

Assignment is local to a feature the placed tile/Development/Transformation:
- belongs to;
- directly creates;
- directly reopens;
- directly alters;
- or directly affects under its rule.

The player cannot assign globally to an unrelated feature elsewhere on the board.

## RULE-SPEC-008 — No last-second assignment
If the placement itself completes the feature, it is too late to assign a Specialist to that feature.

## RULE-SPEC-009 — Development assignment opportunities
A Development placement can create the one optional Specialist-assignment opportunity on an eligible unfinished feature it directly affects.

Examples:
- Housing/Market/Town Square/Port → host Settlement;
- Forester's Lodge → host Forest;
- Monastery → the Monastery enclosure if unfinished;
- Mill → one eligible unfinished Settlement it touches.

If a Development directly affects multiple eligible unfinished features, the player chooses one.

## RULE-SPEC-010 — Transformation assignment opportunities
Bridge, Rewilding, Urban Expansion, and future Transformations can create the normal optional Specialist-assignment opportunity on eligible unfinished features they directly create/reopen/alter.

## RULE-SPEC-011 — Reopened features can receive Specialists
A genuinely reopened feature becomes unfinished again and may receive an eligible Steward/Specialist under normal assignment rules.

## RULE-SPEC-012 — Completion lifecycle
When an assigned feature genuinely completes:
1. the Specialist effect resolves in the Specialist step;
2. the piece returns to availability.

A returned piece does not remain automatically committed through future growth phases.

To benefit from a later re-completion, the player must assign the piece again after the feature is reopened.

## RULE-SPEC-013 — No ordinary same-turn reassignment
A Specialist returned by completion becomes available for future turns but cannot normally be reassigned during the same placement resolution.

Steward's Relay is the explicit alpha exception.

## RULE-SPEC-014 — Indirect completion
If the assigned feature becomes complete indirectly through a Transformation, merger, or other board-state change, the Specialist resolves and returns normally.

## RULE-SPEC-015 — Training
A 40-point threshold can offer **Train a Steward**.

Training permanently converts one generic Steward into a trained Specialist for the remainder of the run.

No free retraining exists in the alpha.

## RULE-SPEC-016 — Training an available Steward
If an available generic Steward is chosen for training, offer up to 3 distinct Specialist roles selected uniformly from the alpha Specialist pool.

## RULE-SPEC-017 — Training a committed Steward
A committed generic Steward may train **in place** only into a Specialist role that is legal for its currently occupied feature.

The piece is not recalled for training.

Filter the offer to legal roles and show up to 3 distinct choices uniformly from that filtered pool.

## RULE-SPEC-018 — Untrainable/excess training reward
If every Steward is already trained, or if no remaining generic Steward can legally be trained at the moment the reward resolves, the training reward converts into **1 normal Tile Reward**.

## RULE-SPEC-019 — Duplicate Specialist roles
Specialist roles are not unique. Multiple pieces may be trained into the same role.

They still cannot occupy the same connected feature simultaneously.

## 14.1 Alpha Specialist roster

### RULE-SPEC-MERCHANT — Merchant
**Assign:** Road.

On genuine completion of the assigned Road Feature:
- count all distinct Settlements in that Road's current full Trade Network;
- gain **+2 Trade for each distinct Settlement beyond the first**.

Merchant has no per-Settlement anti-farming history. On a genuine later re-completion after reassignment, it evaluates the full current Trade Network again.

Ferry Rights connections count when active.

### RULE-SPEC-CARTOGRAPHER — Cartographer
**Assign:** Road.

At assignment, mark the Road's current state/size.

On genuine completion, gain **+1 Trade for every genuinely new Road tile added to that Road after assignment**.

Old Road tiles absorbed through a later merger do not count as added after assignment. A newly placed Bridge can count as new growth; newly created neighboring Road components can count if genuinely new.

### RULE-SPEC-ARCHITECT — Architect
**Assign:** Settlement.

On genuine completion, gain **+2 Culture per distinct Development family currently in the Settlement**.

Upgrades count as their base family.

On later genuine re-completion after reassignment, Architect reevaluates the full current Development diversity.

### RULE-SPEC-HOMESTEADER — Homesteader
**Assign:** Settlement.

On genuine completion, gain **+1 Population per distinct Field tile currently touching the Settlement**.

This intentionally stacks with base Settlement Field-support scoring.

Homesteader is a current-state Specialist bonus and therefore reevaluates the full current Field support on each genuine completion after reassignment, even when base support scoring only pays newly scoring relationships.

### RULE-SPEC-NATURALIST — Naturalist
**Assign:** Forest.

On genuine completion, if the Forest contains no ordinary Development, gain **+1 Ecology per Forest tile**.

Forester's Lodge does not disqualify Naturalist.

Any other ordinary Development on a tile belonging to that Forest does.

### RULE-SPEC-FORESTER — Forester
**Assign:** Forest.

At assignment, mark the Forest's current state/size.

On genuine completion, gain **+1 Ecology for every genuinely new Forest tile added after assignment**.

Old Forest tiles absorbed through mergers do not count as new growth. A newly placed/created Rewilding Forest tile can count.

### RULE-SPEC-RIVERKEEPER — Riverkeeper
**Assign:** River.

On genuine completion, gain **+1 Ecology per distinct Forest tile currently touching the River**.

This intentionally stacks with River base Forest-contact Ecology.

Riverkeeper is a current-state Specialist bonus with no per-Forest anti-farming history. Alpha Rivers normally cannot reopen, but the rule is defined for future-proofing.

### RULE-SPEC-HARBORMASTER — Harbormaster
**Assign:** River containing at least one Settlement touching that River.

On genuine completion, gain:
- **+2 Trade per Settlement currently touching the River**;
- **+1 additional Trade for each of those Settlements containing a Port**.

Harbormaster reevaluates the full current River relationship on each genuine completion after reassignment.

## RULE-SPEC-020 — Deferred Specialists
Not in the alpha trainable pool:
- Courier
- Historian
- Gardener
- Conservator
- Engineer

---

# 15. Relics

## RULE-RELIC-001 — Alpha Relic capacity
Active Relic slots:
- Act I: **2**
- Act II: **4**
- Act III: **5**

Opening capacity does not itself grant a Relic.

## RULE-RELIC-002 — Immediate equip
A Relic is equipped immediately when acquired. The alpha has no inactive Relic inventory.

If all slots are full, the player may:
- decline the new Relic; or
- replace one equipped Relic.

## RULE-RELIC-003 — Illegal removal restriction
A Relic cannot be removed if removing it would make current game state illegal.

Example: Wayfarer's Satchel cannot be removed while its second Reserve slot contains a tile that would have no legal place to exist after removal.

## RULE-RELIC-004 — Replaced Relic
A replaced Relic leaves the run permanently as an equipped object.

Permanent historical state changes it created remain unless the Relic text explicitly says otherwise.

Ongoing rule effects end immediately.

## RULE-RELIC-005 — Acquired Relic exhaustion
Once a Relic has actually been acquired in a run, it is permanently exhausted from that run's Relic offer pool, even if later replaced.

A Relic merely offered and not selected remains eligible for later offers.

A Relic declined instead of acquired also remains eligible.

## RULE-RELIC-006 — Relic offer pool by Act
Relic eligibility is cumulative:
- Act I can offer Foundational alpha Relics;
- Act II can offer Foundational + Developed alpha Relics;
- Act III can offer Foundational + Developed + Legacy alpha Relics.

Earlier tiers remain eligible later.

## RULE-RELIC-007 — Relic offer generation
Whenever a Relic offer is earned:
- uniformly select up to 3 distinct eligible unowned Relics;
- player chooses 1;
- if fewer than 3 eligible Relics remain, show all remaining;
- if none remain, convert the Relic reward into 1 normal Tile Reward.

## RULE-RELIC-008 — Once-per-Act refresh
A once-per-Act Relic receives a fresh use at the beginning of each Act.

Unused uses expire at Act transition and do not carry over.

If acquired mid-Act, the Relic receives its current-Act use immediately.

## RULE-RELIC-009 — Prospective acquisition
A newly acquired Relic becomes active immediately, but never retroactively changes calculations/events that already resolved or were already snapshotted.

It may affect genuinely later events in the same larger resolution queue.

## RULE-RELIC-010 — Relic precedence
When Relic rules conflict:
1. explicit prohibition beats permission;
2. more specific rule beats more general rule;
3. if still unresolved, the later-acquired Relic wins.

## RULE-RELIC-011 — Triggered Relic batch order
Relics triggered by the same event calculate from the same snapshot.

Pure numerical effects apply together.

If sequential resolution/choices are needed, resolve in **Relic acquisition order, oldest equipped first**.

Any new events created by the batch are deferred to the child-event queue.

## 15.1 Foundational alpha Relics

### RULE-RELIC-BOUNDARY — Boundary Stones
Once per Act, one Expansion placement may ignore exactly **one Field ↔ Forest edge mismatch**.

Road, River, Settlement, and all other edges must match normally.

The mismatched boundary becomes a hard Field/Forest boundary. The Forest does not connect through that edge.

### RULE-RELIC-COMPASS — Surveyor's Compass
The first time the player uses a **normal Survey** each Act:
1. inspect up to the next 3 tiles available in the bag;
2. choose one as the Survey replacement;
3. return the unchosen inspected tiles to the bag;
4. randomize the bag.

If fewer than 3 tiles remain, inspect all available tiles.

If the bag is empty when Compass needs a replacement set, perform normal emergency replenishment first.

Grand Survey does not trigger Compass.

### RULE-RELIC-SATCHEL — Wayfarer's Satchel
Gain a second Reserve slot.

Both Reserve slots follow the Reserve rules in Section 7.

### RULE-RELIC-VGREEN — Village Green
Whenever a Settlement genuinely completes, if its **current exterior touches at least one Field, Forest, or River tile**, gain **Culture equal to the Settlement's full current size**.

This is a current-state check at each genuine completion.

On a later genuine re-completion, Village Green can score the enlarged Settlement again.

### RULE-RELIC-FERRY — Ferry Rights
If a Trade Network reaches at least one Settlement by Road, every Settlement touching the **same connected River** as that Settlement is linked into the Trade Network for commercial connectivity.

Ferry links:
- propagate transitively through those Settlements into their attached Roads and onward hubs;
- count for Road base Settlement-connectivity Trade;
- count for Merchant;
- count for Market/Grand Market;
- count for Road/network Charter conditions;
- count for the 5-Settlement Road milestone;
- do not add Road tiles;
- do not increase physical Road Feature length.

Removing Ferry Rights removes those ferry-created links immediately and can split Trade Networks. Previously earned scoring is never undone.

## 15.2 Developed alpha Relics

### RULE-RELIC-MIXED — Mixed-Use Charter
A Settlement tile may contain both:
- one Housing-family Development; and
- one Market-family Development
at the same time.

No other Development pair becomes legal because of this Relic.

Grand Market counts as the Market family for this purpose.

### RULE-RELIC-HISTORIC — Historic Routes
Whenever a Road containing at least one **Act I Road tile** genuinely completes during Act II or Act III, gain:

**+1 Culture per Act I Road tile currently contained in that physical Road Feature.**

Historic Routes evaluates the full current Road Feature each genuine completion, even if some Act I tiles were part of an earlier completion.

A later Bridge/Rewilding-style history change does not make a Transformation-created Road component an Act I Road component merely because the underlying board square was placed in Act I.

### RULE-RELIC-RELAY — Steward's Relay
Whenever a Steward/Specialist returns from a completed feature, the player may immediately reassign that same piece to an eligible **unfinished feature touching the feature that just completed**.

If multiple eligible touching features exist, the player chooses.

Normal eligibility and one-Specialist-per-feature rules still apply.

Relay is the explicit exception to the normal no-same-turn-reassignment rule.

## 15.3 Legacy alpha Relics

### RULE-RELIC-GCITY — One Great City
Only the player's **currently largest Settlement(s)** generate base Population from Settlement completion.

All Settlements tied for greatest current size count as largest.

When a qualifying largest Settlement genuinely completes/re-completes, double only its **base Population payout**:
- newly scoring Settlement tiles;
- newly scoring Field support;
- newly scoring River support.

Do not double:
- Housing;
- Mill;
- Specialist bonuses;
- other Relics;
- Charter/reward gains.

A smaller Settlement generates no base Population while One Great City is active, but all its non-base Development/Specialist/Relic effects still resolve normally.

### RULE-RELIC-LONGROAD — The Long Road
Only a completed Road Feature whose total physical Road size **equals or exceeds the existing Longest Road record before that completion resolves** generates base Trade.

A qualifying Road doubles its newly scoring base Road Trade:
- newly scoring Road tiles;
- newly scoring Settlement connections in the full Trade Network.

A nonqualifying Road receives zero from both base Trade components, but its other Development/Specialist/Relic effects still resolve normally.

After resolution, if the completed Road is larger than the historical record, update the Longest Road record.

The Longest Road record is tracked from the start of the run and does not reset when this Relic is acquired.

A Bridge-created merged Road that completes immediately can establish a new record using its total physical Road Feature size even though old Road tiles do not base-score again.

## RULE-RELIC-012 — Alpha Relic roster summary
**Foundational (Act I+):**
1. Boundary Stones
2. Surveyor's Compass
3. Wayfarer's Satchel
4. Village Green
5. Ferry Rights

**Developed (Act II+):**
6. Mixed-Use Charter
7. Historic Routes
8. Steward's Relay

**Legacy (Act III):**
9. One Great City
10. The Long Road

All other prototype Relics are deferred from the first alpha.


---

# 16. Realm Tracks, Thresholds, and Reward Systems

## RULE-TRACK-001 — Four Realm Tracks
The alpha has exactly four cumulative, nonspendable Realm Tracks:
1. Population
2. Trade
3. Culture
4. Ecology

There is no Prosperity track and no spendable resource-currency layer.

## RULE-TRACK-002 — Tracks are cumulative and uncapped
Realm Tracks normally only increase.

They are not spent.

Tracks have no hard maximum. Values may exceed 100 and their full values count toward final score and relevant Charter conditions.

## RULE-TRACK-003 — Standard thresholds
Each Track has standard one-time thresholds at:
- **20**
- **40**
- **70**
- **100**

Each threshold on each Track can trigger exactly once per run.

## RULE-TRACK-004 — Threshold rewards
For each Track:
- **20:** Normal Tile Reward — choose 1 of up to 3 tile designs.
- **40:** Train a Steward — choose 1 of up to 3 legal Specialists; converts to Tile Reward if no legal generic Steward can be trained.
- **70:** Relic offer — choose 1 of up to 3 eligible Relics.
- **100:** Major Reward offer — choose 1 of up to 3 valid Major Rewards.

There are no further standard threshold rewards beyond 100.

## RULE-TRACK-005 — Every crossed threshold awards
If one placement/effect crosses multiple thresholds, every newly crossed threshold on every Track awards separately.

There is no per-placement reward cap.

## RULE-TRACK-006 — Threshold queue order
Queued Track threshold rewards resolve in fixed Track order:
1. Population
2. Trade
3. Culture
4. Ecology

Within one Track, lower thresholds resolve before higher thresholds.

Each reward is fully resolved before moving to the next queued threshold.

A Relic acquired from an earlier threshold becomes active for genuinely later events/rewards in the queue, but never retroactively alters scoring that caused the queue.

## RULE-TRACK-007 — Thresholds never interrupt a completion
Realm Track gains from a current feature-completion package are accumulated through:
- base scoring;
- Developments;
- Specialists;
- Relics.

Threshold rewards wait until the complete completion package and Relic milestone processing finish.

## 16.1 Normal Tile Rewards

### RULE-REWARD-TILE-001 — Eligible pool
A normal Tile Reward may offer **any currently unlocked tile design**, including:
- basic Expansion tiles;
- Specialized/Hybrid Expansions;
- ordinary Developments;
- Upgrades;
- Transformations;
provided the design is unlocked in the current Act.

The design does not need to be currently playable on the board.

### RULE-REWARD-TILE-002 — Offer generation
Uniformly select up to **3 distinct eligible designs**.

The player chooses 1 design.

If fewer than 3 distinct eligible designs exist, show all that exist rather than padding with duplicates.

No contextual weighting or "helpfulness" logic exists in the alpha.

### RULE-REWARD-TILE-003 — Copy quantity
Chosen reward design adds:
- Basic Expansion: **3 copies**;
- Specialized/Hybrid Expansion: **2 copies**;
- ordinary Development/Act II Upgrade: **2 copies**;
- Major/Rare Act III design: **1 copy**.

Awarded physical copies enter the bag and the entire bag is randomized before any pending replacement draw.

### RULE-REWARD-TILE-004 — Cumulative unlock eligibility
Tile reward eligibility is cumulative by Act.

Act II offers may include Act I + Act II designs.

Act III offers may include Act I + Act II + Act III designs.

### RULE-REWARD-TILE-005 — Outgoing Charter restriction
An outgoing Act Charter reward uses only the tile pool that was already unlocked in the outgoing Act.

Next-Act designs do not become reward-eligible until after the Act advances and the new tier unlocks.

## 16.2 Major Rewards

### RULE-REWARD-MAJOR-001 — Major Reward offer
Whenever a Major Reward is earned, uniformly present up to **3 distinct currently valid Major Reward options** and let the player choose 1.

If fewer than 3 options are valid, show all valid options.

### RULE-REWARD-MAJOR-002 — Recruit a Steward
Gain 1 generic Steward if the player has fewer than the hard cap of 3 total Steward/Specialist pieces.

If already at 3, this option is invalid and excluded from the offer.

### RULE-REWARD-MAJOR-003 — Masterwork Tile Grant
Choose 1 of up to 3 currently eligible **Specialized/Hybrid, Major/Rare, or Upgrade** tile designs and add **3 copies** to the bag instead of that design's normal reward quantity.

The Masterwork pool includes Upgrades such as **Abbey**, even when their normal reward class is shared with ordinary Developments. Basic Expansions and ordinary Developments are excluded. Normal Act unlock requirements still apply; immediate board playability is not required. This is the canonical meaning of advanced for this reward.

The chosen copies enter the bag and trigger normal full-bag randomization.

### RULE-REWARD-MAJOR-004 — Relic Cache
Choose 1 of up to 3 eligible unowned Relics, acquire/equip it under normal Relic rules, then receive **1 normal Tile Reward**.

If the eligible unowned Relic pool is empty, Relic Cache is invalid and excluded from Major Reward offers.

### RULE-REWARD-MAJOR-005 — Grand Survey
Immediately:
1. permanently remove up to 2 chosen active-hand tiles from the run;
2. replace removed tiles sequentially;
3. gain +1 Survey charge for the current Act.

Grand Survey does not count as a normal Survey and does not trigger Surveyor's Compass.

## 16.3 Relic milestone rewards

### RULE-MILESTONE-001 — Once-per-run Relic milestones
Each of the following can trigger once per run:
- **Settlement milestone:** genuinely Establish a Settlement of at least 8 tiles.
- **Road milestone:** genuinely complete a Road whose current full Trade Network reaches at least 5 distinct Settlements.
- **Forest milestone:** genuinely complete a Forest of at least 10 tiles.
- **River milestone:** genuinely complete a River of at least 10 tiles.

Each newly satisfied milestone awards a Relic offer.

### RULE-MILESTONE-002 — Completion timing
A milestone is checked only on the relevant genuine feature-completion event.

Merely growing an unfinished feature past the size/connectivity threshold does not trigger the completion-based milestone until the feature closes.

### RULE-MILESTONE-003 — Multiple milestones
If one placement causes multiple newly satisfied milestones, each awards separately.

Resolve multiple milestone rewards in fixed order:
1. Settlement
2. Road
3. Forest
4. River

Each Relic offer resolves completely before the next.

### RULE-MILESTONE-004 — Milestones before threshold rewards
Within a completion package, newly triggered Relic milestone rewards resolve before the Realm Track threshold queue.

---

# 17. Charters and Grand Charter

## RULE-CHARTER-001 — Charter purpose
Charters are the run's boss/objective structure. They evaluate the persistent civilization rather than creating combat encounters.

## RULE-CHARTER-002 — Charter evaluation timing
Charters are evaluated only at their designated Act-end evaluation point:
- Act I Charter: after Act I's final normal placement and all consequences/bonus placements resolve;
- Act II Charter: after Act II's final normal placement and all consequences/bonus placements resolve;
- Grand Charter: after Act III's final normal placement and all consequences/bonus placements resolve.

Meeting a current-state condition earlier does not lock it in unless the condition is historical/event-based.

## RULE-CHARTER-003 — Current-state vs historical wording
Charter language describing what **currently exists** uses board state at evaluation time.

Examples:
- current Track value;
- current Settlement size;
- current Development families;
- current Forest/River size;
- current Trade Network connectivity.

Charter language describing what the player **did** uses persistent run history.

Examples:
- complete 2 Roads;
- complete a Forest;
- establish a Settlement;
- complete a Monastery.

## RULE-CHARTER-004 — Completion-event counting
Historical "complete X features" requirements count genuine completion events.

A single lineage can provide multiple events if it genuinely reopens, grows, and re-completes.

Immediate Development resolution on an already-completed feature does not count as another completion event.

## RULE-CHARTER-005 — Exceed requires fulfillment
A Charter can be exceeded only if **all normal fulfillment conditions are satisfied first**.

Exceed conditions are additional requirements, never alternate shortcuts.

The same rule applies to Exemplary Grand Charter results.

## 17.1 Act I Charters

### RULE-CHARTER-A1-SELECT — Selection
Before the opening hand, uniformly select 1 of the 3 Act I Charters and reveal it.

No weighting, filtering, or reroll.

### RULE-CHARTER-A1-REWARD — Rewards
If fulfilled: receive **1 normal Tile Reward**.

If exceeded: also receive **1 Relic offer**.

If failed: no additional punishment; the run continues and the missed reward is the only loss.

### RULE-CHARTER-A1-01 — Growing Realm
Fulfill:
- Population **20+**;
- at least **2 genuine Settlement completion events** during the run so far.

Exceed:
- all fulfillment conditions;
- Population **30+**.

### RULE-CHARTER-A1-02 — Open Roads
Fulfill:
- Trade **20+**;
- at least **2 genuine Road completion events** during the run so far;
- at least one relevant Road/Trade Network connectivity state reaches **2 distinct Settlements**.

Exceed:
- all fulfillment conditions;
- Trade **30+**.

Road-connected Settlement counts use the full Trade Network semantics in this document.

### RULE-CHARTER-A1-03 — Living Landscape
Fulfill:
- Ecology **20+**;
- at least **1 genuine Forest completion event**;
- at least **1 genuine River completion event**.

Exceed:
- all fulfillment conditions;
- Ecology **30+**.

## 17.2 Act II Charters

### RULE-CHARTER-A2-SELECT — Selection
At the Act I → Act II transition, uniformly select 1 of the 3 Act II Charters and reveal it.

No board-state feasibility weighting or filtering.

### RULE-CHARTER-A2-REWARD — Rewards
If fulfilled:
- receive **1 Relic offer**;
- receive **1 normal Tile Reward**.

If exceeded:
- receive the fulfillment rewards;
- additionally receive **1 Major Reward offer**.

If failed:
- receive no Charter reward;
- suffer no additional punishment;
- proceed into Act III.

### RULE-CHARTER-A2-01 — Market Towns
Fulfill:
- Trade **40+**;
- at least **2 current distinct Settlements** contain a Market-family Development;
- at least one Road lineage with a genuine completion history belongs at evaluation to a Trade Network reaching at least **3 distinct Settlements**.

Exceed:
- all fulfillment conditions;
- Trade **55+**.

### RULE-CHARTER-A2-02 — Growing Communities
Fulfill:
- Population **40+**;
- at least one current Settlement has size **6+**;
- that Settlement contains at least **2 Developments**.

Exceed:
- all fulfillment conditions;
- Population **55+**.

### RULE-CHARTER-A2-03 — Stewardship of Land
Fulfill:
- Ecology **40+**;
- at least one current Forest has size **6+**;
- at least one current River has size **6+**.

Exceed:
- all fulfillment conditions;
- Ecology **55+**.

## 17.3 Grand Charter

### RULE-GRAND-001 — Selection
At the start of Act II, uniformly select 1 of the 3 Grand Charters in secret.

No weighting based on the board, bag, Tracks, or prior choices.

### RULE-GRAND-002 — Forecast
Immediately reveal the selected Grand Charter's broad forecast, but not its exact requirements.

Forecasts:
- **Great Metropolis:** "The realm will ultimately be judged by the greatness and sophistication of its settlements."
- **Merchant Republic:** "The realm will ultimately be judged by the reach and prosperity of its trade network."
- **Living Heritage:** "The realm will ultimately be judged by its stewardship of nature and cultural legacy."

### RULE-GRAND-003 — Exact reveal
After **normal placement 11 of Act II** and all consequences of that placement (including bonus placements/queues) fully resolve, reveal the exact Grand Charter.

The exact Grand Charter remains visible for the rest of the run.

### RULE-GRAND-004 — Act III objective
Act III has no separate ordinary Charter. The Grand Charter is the final objective.

### RULE-GRAND-005 — Final outcome
At run end:
- Grand Charter failed → completed run, **no victory**;
- Grand Charter fulfilled → **Victory**;
- Grand Charter exceeded → **Exemplary Victory**.

The run is still scored even when the Grand Charter fails.

### RULE-GRAND-01 — Great Metropolis
Fulfill:
- Population **70+**;
- a Settlement of at least **8 tiles** is currently completed (Established) at evaluation; a reopened unfinished Settlement does not qualify;
- that Settlement contains at least **3 distinct Development families**;
- that Settlement belongs to a Trade Network connecting it to at least **2 other distinct Settlements**.

Exceed:
- all fulfillment conditions;
- Population **90+**;
- at least one current Settlement has size **10+**. This may be a different Settlement from the fulfillment witness and need not currently be completed.

### RULE-GRAND-02 — Merchant Republic
Fulfill:
- Trade **70+**;
- at least one current Trade Network containing a Road lineage with genuine completion history connects at least **4 distinct Settlements**; a reopened Road or descendant retaining that history qualifies;
- at least **2** of those Settlements contain a Market-family Development or Port.

Exceed:
- all fulfillment conditions;
- Trade **90+**;
- the qualifying Trade Network reaches at least **5 distinct Settlements**.

### RULE-GRAND-03 — Living Heritage
Fulfill:
- Ecology **60+**;
- Culture **40+**;
- at least one current Forest has size **8+**;
- at least one current River has size **8+**;
- at least **1 Monastery-family enclosure has genuinely completed** during the run.

Exceed:
- all fulfillment conditions;
- Ecology **80+**;
- Culture **60+**.

---

# 18. Act Unlocks, Seeding, and Transition

## RULE-ACT-001 — Act I unlocked content
Act I Tile Reward eligibility includes:
- all 21 Act I Expansion designs listed in Section 5;
- Housing;
- Mill;
- Monastery;
- Forester's Lodge.

Market and Port do not unlock until Act II even though they originated in the broader Starter 24 design set.

## RULE-ACT-002 — Act II unlocks
At the start of Act II, unlock and keep eligible thereafter:
- Market;
- Port;
- Urban Expansion;
- Town Square;
- Abbey.

Automatically add **2 copies each** to the bag:
- Market ×2
- Port ×2
- Urban Expansion ×2
- Town Square ×2
- Abbey ×2

Total automatic Act II seeding: **10 tiles**.

## RULE-ACT-003 — Act III unlocks
At the start of Act III, unlock and keep eligible:
- Bridge;
- Rewilding;
- Grand Market.

Automatically add **2 copies each**:
- Bridge ×2
- Rewilding ×2
- Grand Market ×2

Total automatic Act III seeding: **6 tiles**.

## RULE-ACT-004 — Seeded tile acquisition history
Act-transition seeded tiles are recorded as acquired in the Act in which they enter the bag.

They do not count as placements or completed objectives.

## RULE-ACT-005 — Seed before pending refill
Newly unlocked Act-transition tiles enter and randomize into the bag **before** the pending active-hand replacement draw caused by the outgoing Act's final active-hand placement.

Therefore the first draw entering a new Act can be one of the newly unlocked designs.

## RULE-ACT-006 — Canonical Act transition
After the outgoing Act's final normal placement, all bonus placements, all consequences, and the full event queue resolve. Then perform transition in this canonical order:

1. Evaluate the outgoing Act Charter.
2. Award its fulfillment/exceed rewards as applicable.
3. Legendary Project hook: no-op in the alpha.
4. Advance to the next Act.
5. Increase Relic capacity:
   - Act II → 4 slots
   - Act III → 5 slots
6. Expire unused prior-Act Survey charges and grant 1 fresh Survey charge.
7. Refresh once-per-Act Relic abilities.
8. Unlock the new Act's tile/reward eligibility.
9. Add the automatic new-Act seeded tiles to the bag.
10. Randomize the bag.
11. Reveal new Charter/Grand Charter information:
    - entering Act II: reveal Act II Charter, secretly choose Grand Charter, reveal its forecast;
    - entering Act III: no new ordinary Charter; exact Grand Charter was already revealed at Act II midpoint.
12. Reset the new Act's normal-placement counter to 0.
13. Perform the pending active-hand replacement draw from the outgoing final placement, if one is needed.
14. Begin the next Act.

## RULE-ACT-007 — Persistent state through transition
Do not automatically clear/reset:
- board;
- active hand;
- Reserve;
- bag contents;
- Realm Tracks;
- Relics;
- Specialist commitments;
- feature lineages/history;
- Trade Network lineage/history.

The only scheduled refreshes are those explicitly listed, such as Survey charge and once-per-Act Relic use.

## RULE-ACT-008 — No final Act III refill
After Act III normal placement 26 and its full consequence/bonus/event queue resolves:
- do not draw a replacement tile;
- evaluate the Grand Charter;
- calculate final score;
- display final result/statistics;
- end the run.

---

# 19. Canonical Turn, Completion, and Event Resolution

## RULE-TIMING-001 — Canonical normal-turn sequence
A normal turn proceeds:
1. Start with current active hand and Reserve.
2. Player may use legal pre-placement actions such as Reserve and Survey.
3. Apply free dead-hand cycling when the active-hand condition is met.
4. Choose a legal tile from active hand or Reserve.
5. Choose legal placement mode/rotation/target and commit the placement.
6. If an eligible directly affected feature remains unfinished, optionally assign one Steward/Specialist.
7. Identify and snapshot all genuine feature completions caused by the resulting board state.
8. Resolve the completion/effect pipeline.
9. Resolve any remaining non-completion placement effects and rewards not already resolved.
10. Resolve the queued Realm Track thresholds.
11. If this was the Act's final normal placement, resolve any remaining bonus chain and then perform Act transition; otherwise continue normally.
12. If the played tile came from active hand, refill its empty slot only after all consequences/rewards/bag additions are complete.
13. If the tile came from Reserve, no active-hand refill is needed.
14. Begin the next turn or end the run.

No effect jumps the queue unless its text explicitly says so.

## RULE-TIMING-002 — Simultaneous completion snapshot
If one placement completes multiple features:
- identify all features completed by that placement/resulting board state;
- snapshot their shared state before one completion changes another;
- calculate each effect category from that shared completion snapshot.

## RULE-TIMING-003 — Canonical feature-completion pipeline
For a simultaneous completion package:
1. Snapshot all completed features/current relevant board state.
2. Calculate/apply base feature scoring.
3. Calculate/apply Development completion effects from the shared snapshot.
4. Calculate/apply Steward/Specialist effects from the shared snapshot.
5. Return completed-feature Stewards/Specialists to availability, subject to Steward's Relay.
6. Calculate/resolve triggered Relics from the appropriate shared state.
7. Check/resolve newly earned Relic milestones.
8. Queue all newly crossed Realm Track thresholds.
9. After the completion package and milestones are finished, resolve the threshold queue.

## RULE-TIMING-004 — Specialist simultaneous calculation
If multiple Specialists trigger from simultaneously completed features, their applicable effects calculate from the same completed-feature snapshot before moving to Relics.

Any Specialist effect requiring player choice may pause within the Specialist batch, but does not cause already snapshotted peers to see a different board state.

## RULE-TIMING-005 — Relic simultaneous calculation
Triggered Relics from the same event calculate from the same state/snapshot before sequential choice handling.

Relic conflict/trigger order follows Section 15.

## RULE-TIMING-006 — Universal batch-then-queue model
Whenever multiple effects trigger from the same parent event:
- resolve them as a defined batch from a shared snapshot;
- any genuinely new events created during that batch are deferred into a child-event queue;
- child events do not interrupt the middle of the parent batch.

This applies across Developments, Specialists, Relics, Transformations, and future systems.

## RULE-TIMING-007 — FIFO child-event processing
Child events are processed **first-in, first-out (FIFO)** in creation order.

If child events are created simultaneously, established subsystem resolution order breaks the tie.

## RULE-TIMING-008 — Event types
The alpha event model should distinguish at minimum:
- `tile_placed`
- `development_placed`
- `transformation_applied`
- `feature_merged`
- `feature_reopened`
- `feature_completed`
- `specialist_returned`
- `relic_triggered`
- `milestone_earned`
- `track_threshold_crossed`
- `reward_resolved`
- `bonus_placement_granted`
- `act_transition_started`
- `act_started`
- `run_ended`

These event categories prevent placement, merger, and completion effects from being conflated.

## RULE-TIMING-009 — Bonus placement refill timing
If a bonus placement uses an active-hand tile:
- resolve the bonus placement and all its consequences/rewards;
- refill the empty hand slot;
- then proceed to the next queued bonus placement.

If a bonus placement uses Reserve, no hand refill is needed.

A tile just drawn as the refill from one bonus placement is immediately eligible for a later bonus placement in the same chain.

---

# 20. Tile Age, Historical Identity, and Transformation Metadata

## RULE-HISTORY-001 — Base tile placement Act
Every board square records the Act in which its physical base tile was originally placed.

The Founding Tile is treated as Act I.

## RULE-HISTORY-002 — Transformation Act
Each Transformation separately records the Act in which it occurred.

A later Transformation does not rewrite the historical Act identity of the underlying base tile.

## RULE-HISTORY-003 — New feature component age
If a Transformation creates a new feature component on an old board square, that new component is associated with the Transformation's Act for age/heritage purposes.

Example:
- Act I River Run receives Bridge in Act III;
- underlying square remains an Act I base tile;
- Bridge-created Road component is Act III Road growth;
- it is not an Act I Road tile for Historic Routes.

## RULE-HISTORY-004 — Genealogical lineage
Feature and Trade Network histories retain ancestry across merges/splits so scoring history cannot be reset by topology changes.

---

# 21. Final Score and Run End

## RULE-END-001 — Final numeric score
Final Score is:

**Population + Trade + Culture + Ecology**

Use the full uncapped final Track values.

## RULE-END-002 — Victory is separate from numeric score
Grand Charter result is reported separately from the numeric score:
- Failed → completed run, no victory
- Fulfilled → Victory
- Exceeded → Exemplary Victory

## RULE-END-003 — End-of-run statistics
The alpha should retain/display enough statistics for playtest review, including at minimum:
- final four Realm Tracks;
- final total score;
- Grand Charter result;
- Largest Settlement ever Established;
- Longest Road ever completed;
- Largest Forest ever completed;
- Longest River ever completed;
- Relics acquired/equipped/replaced;
- Specialist training choices;
- Charters selected and results;
- run seed.

---

# 22. Explicit Alpha Invariants for Codex

These are high-value implementation invariants that should be testable in unit/integration tests.

## RULE-INVARIANT-001 — Board legality
Outside explicit mismatch/rewrite effects, no occupied orthogonal edge pair may disagree.

## RULE-INVARIANT-002 — One Specialist per connected unfinished feature
No connected unfinished Road/Settlement/Forest/River/Monastery may contain more than one Steward/Specialist.

## RULE-INVARIANT-003 — Development slot legality
A tile normally has one Development slot. Only explicit rules such as Mixed-Use Charter permit more.

Upgrades replace, rather than stack with, their base Development.

## RULE-INVARIANT-004 — Base scoring anti-farming
Previously scored base feature elements never regain base scoring eligibility merely because of reopening, merging, network splitting, or reconnection.

History categories include:
- Settlement tiles;
- Settlement Field support;
- Settlement River support;
- Road tiles;
- per-Road Settlement connection bonuses;
- Forest tiles;
- River–Forest base contact bonuses.

## RULE-INVARIANT-005 — Bonus effects vs base history
Specialist/Relic/Development completion bonuses that explicitly evaluate full current state may score the same old board relationships again on a later **genuine** re-completion after the relevant piece/effect is legally active.

This does not reset base scoring history.

## RULE-INVARIANT-006 — No retroactive rewards
A newly acquired Relic, Specialist, Development, or newly formed Trade Network never rewrites already resolved scoring unless its text explicitly says retroactive.

No alpha rule is retroactive by default.

## RULE-INVARIANT-007 — Physical copies matter
Tiles in the bag, hand, Reserve, board, and removed-from-run state are physical copies.

Survey, upgrades, placement, and replacement physically move/remove copies according to rules.

## RULE-INVARIANT-008 — Determinism
Given the same run seed and same player decisions, all RNG-dependent choices should be reproducible.

## RULE-INVARIANT-009 — No hidden auto-help
The alpha reward generator does not silently weight offers toward the player's current needs.

Normal Tile Reward, Relic, Charter, Grand Charter, and Specialist offer selection follow their explicit uniform/filtering rules.

## RULE-INVARIANT-010 — Persistent civilization
Act transitions never clear the board or silently reset strategic commitments.

---

# 23. Superseded / Deferred Prototype Concepts

This section exists specifically to stop Codex from re-importing older prototype rules that conflict with the alpha specification.

## RULE-SUPER-001 — River Source renamed/redefined
The old `River Source` starter tile name is superseded by **River End**.

The same one-edge River tile may function as either source/start or terminus/end.

## RULE-SUPER-002 — Starting bag changed
The old provisional pre-alpha bag is superseded by the **55-tile Homestead bag** in Section 6.

## RULE-SUPER-003 — Market and Port cadence
Although Market and Port appear in the broader Starter 24 source set, the alpha unlocks/seeds them at the **start of Act II**, not in the initial bag.

## RULE-SUPER-004 — Rewilding does not automatically destroy Settlement Developments
Any earlier conversational/prototype interpretation that Rewilding automatically removes every Development on its target is superseded.

Rewilding transforms eligible Field geography. It cannot target Field-dependent Mill/Monastery locations, but it preserves Developments hosted by preserved features such as Housing/Market on Settlement geometry.

## RULE-SUPER-005 — Village Green alpha condition
For this alpha, Village Green triggers when the Settlement exterior touches **at least one Field, Forest, or River tile** at the completion snapshot.

This alpha rule supersedes any older prototype wording requiring simultaneous contact with all three natural types.

## RULE-SUPER-006 — Trade is Trade Network based
Any older wording that implies Trade connectivity requires one single physically continuous Road Feature to reach every Settlement is superseded.

The alpha distinguishes physical Road Features from the larger transitive Trade Network graph.

## RULE-SUPER-007 — Reduced Specialist roster
The alpha trainable roster is exactly:
- Merchant
- Cartographer
- Architect
- Homesteader
- Naturalist
- Forester
- Riverkeeper
- Harbormaster

Other prototype Specialists are deferred.

## RULE-SUPER-008 — Reduced Relic roster
The alpha Relic pool is exactly the 10 Relics listed in Section 15.

Other prototype Relics are deferred.

## RULE-SUPER-009 — Legendary Projects deferred
Legendary Projects are not implemented in this alpha even though older design documents define their broader direction.

## RULE-SUPER-010 — Uniform alpha offer generation
Older exploratory language about contextual Specialist/reward weighting is superseded for the alpha by the explicit uniform-random offer rules in this document.

---

# 24. Codex Handoff Checklist — Rules Complete

Before implementation is considered faithful to this specification, Codex should be able to demonstrate/test the following rule-level behaviors:

1. Three Acts run continuously at 18/22/26 normal placements.
2. The fixed Founding Tile creates four immediately extensible feature stubs.
3. Exact edge matching works on an unbounded grid.
4. The 55-tile Homestead bag is correct and deterministic under a seed.
5. Hand, Reserve, Survey, dead-hand cycle, bag exhaustion, and emergency fallback all work.
6. Road, Settlement, Forest, River, and Monastery completion are independently detected.
7. Scoring histories prevent base-score farming after reopening/merging.
8. Urban Expansion can reopen and merge Settlements.
9. Rewilding can start, reopen, merge, and transform Forest geography legally.
10. Bridge can transform straight River Runs, rewrite legal flanking Field edges, and merge/reopen Roads.
11. Trade Network topology propagates transitively through Settlements and Ferry Rights while physical Road Features remain distinct.
12. The expanded Road/Settlement connector family appears in the starting bag at the correct counts.
13. Developments can be placed on already-completed features and resolve only their own immediate trigger.
14. Upgrades replace their base Development and immediately resolve if their condition is already satisfied.
15. Stewards/Specialists obey locality, commitment, merge legality, completion return, and training rules.
16. The reduced 10-Relic alpha pool obeys tier eligibility, capacity, replacement, and acquisition history.
17. Realm Track thresholds award once per Track at 20/40/70/100 and resolve deterministically.
18. Relic milestones fire only on genuine relevant completions and only once per milestone.
19. Act I/II Charters and Grand Charter selection/evaluation behave exactly as specified.
20. Act II midpoint Grand Charter reveal happens after normal placement 11 and its full consequence queue.
21. Act-transition tile seeding happens before the pending hand refill.
22. Event processing uses shared snapshots, batches, deferred child events, and FIFO queues.
23. Bonus placement chains resolve before Act transition and do not increment normal placement counts.
24. End of Act III performs no replacement draw and produces final score + Charter result.
25. Replaying the same seed with the same decisions reproduces RNG outcomes.

---

# 25. Canonical Alpha Rules Summary

The first alpha is a peaceful, run-based tile-placement roguelite in which the **map is the build**.

The player develops one persistent civilization across three Acts. Roads and Settlements build a transitive Trade Network; Forests and Rivers create ecological structure; Developments reinterpret completed geography; Urban Expansion, Rewilding, and Bridge make later Acts capable of rewriting earlier decisions without erasing history. Stewards and Specialists create local commitment pressure, while Relics alter realm-wide rules. Four cumulative Realm Tracks drive rewards and Charters, and the Grand Charter determines victory at the end of Act III.

The core implementation principle is:

> **Current board state determines what is true now; persistent lineage/history determines what has already scored or been accomplished.**

That distinction is the foundation for reopening, merging, Transformations, Trade Network growth, and anti-farming behavior throughout the alpha.


# Carcassonne Roguelite — Tile Design Specification

**Document status:** Working project design document  
**Scope:** Starter tile vocabulary and tile-layer grammar  
**Primary source:** *Carcassonne Roguelite — Core Design Bible*  
**Current design stage:** Starter 24 defined at concept/geometry level; physical copy counts and exact Homestead starting bag remain to be prototyped.

---

# 1. Purpose of This Document

This document defines the first working tile-design framework for the Carcassonne Roguelite prototype.

It establishes:

- the layered structure of tiles;
- how Expansion tiles differ from Developments;
- the intended starter vocabulary;
- the first 24 globally available tile designs;
- which geometries are intentionally reserved for later unlocks;
- the design role of each starter tile;
- how a relatively small number of designs can support full test runs through multiple physical copies;
- the major tile-design questions that remain open for playtesting.

This document should be read alongside the **Core Design Bible**, especially its sections on:

- Tile Geometry and Carcassonne DNA;
- Tile Collection and Meta Unlock Philosophy;
- Run Pool / Physical Tile Bag;
- Development and Board Evolution;
- Open Design Areas;
- Recommended Next Development Workflow.

The Core Design Bible remains authoritative when this document does not explicitly replace or refine an unresolved tile-design question.

---

# 2. Core Tile Philosophy

The tile system should begin recognizably Carcassonne-like and gradually become more specialized through roguelite progression.

The starter set must contain the game's complete **basic spatial vocabulary**. Unlocks should not withhold fundamental functionality such as Roads, Rivers, Forests, Settlements, or Culture. Instead, later tiles should add:

- new geometries;
- new hybrid combinations;
- unusual relationships;
- stronger specialization;
- transformations;
- advanced Developments;
- rule-breaking opportunities.

The player should be able to understand the basic map almost immediately:

- Settlements support **Population**;
- Roads support **Trade**;
- Forests support **Ecology**;
- Monasteries / civic sites support **Culture**.

Later content can increasingly blur or rewrite those associations.

The starter set should therefore be simple enough to learn quickly but broad enough that the first test realm already looks like a mixed landscape rather than four isolated scoring zones.

---

# 3. Tile Classes

The prototype currently uses three broad tile classes.

## 3.1 Expansion Tiles

Expansion tiles add a new square to the board.

They establish persistent geography and persistent connection geometry.

Examples include:

- Fields;
- Forests;
- Rivers;
- Roads;
- Settlements;
- mixed natural/built tiles.

Expansion tiles obey the square grid and are rotated freely in 90-degree increments before placement.

Their geographic and connection geometry normally remains permanent once placed.

---

## 3.2 Development Tiles

Development tiles are played onto an eligible existing square instead of expanding the grid.

They add to the map without normally erasing or replacing the underlying geography.

Baseline rule:

> **One Development per tile.**

Normal Developments are **edge-neutral**. Adding Housing, a Market, a Port, or a Forester's Lodge should not suddenly make an already legal neighboring tile illegal.

Developments may:

- score immediately;
- alter future scoring;
- create new eligibility;
- interact with Specialists;
- interact with Relics;
- matter for Charters;
- change the identity of a Settlement or natural feature.

A completed feature may still receive a Development later.

---

## 3.3 Transformations

Transformations are exceptional pieces or effects that can alter underlying geography or connectivity.

Examples already contemplated by the design include:

- Bridges;
- Canals;
- Rewilding;
- Reservoirs;
- Land Reclamation;
- Urban Expansion.

Transformations are **not part of the Starter 24**.

They are intended to be rarer, more powerful, and more rules-intensive than ordinary Developments.

---

# 4. Layered Tile Model

The starter tiles should not treat Road, River, Forest, Settlement, and Field as five mutually exclusive tile colors.

A tile can contain multiple systems at once.

For implementation and design purposes, an Expansion tile should be understood as having two persistent spatial layers, plus a later mutable Development overlay.

## 4.1 Persistent Layer A — Geography / Natural Layer

This describes the natural landscape contained in the square.

Starter geography includes:

- open Field;
- Forest;
- River;
- mixtures of Field + Forest;
- mixtures of Field + River;
- mixtures of Forest + River where geometry permits.

Future geography may include:

- Wetlands;
- Mountains;
- Lakes;
- coastlines;
- islands;
- other Foundation-specific terrain.

Fields are the default open landscape and serve primarily as support terrain.

Fields are **not** currently intended to have Carcassonne-style endgame field scoring.

---

## 4.2 Persistent Layer B — Built Feature / Connection Layer

This describes persistent constructed features occupying or crossing the geography.

Starter built features include:

- Roads;
- Settlements.

A Road can cross Field geography.

A Road can share a tile with Forest without necessarily running through the Forest itself.

A Settlement can sit beside a River.

A Road can terminate at a Settlement.

These systems can coexist on one square while remaining mechanically distinct features.

---

## 4.3 Mutable Overlay — Development

A Development is not part of the initial Expansion edge geometry.

It is added later to an eligible tile.

Examples:

- Housing on a Settlement;
- Market on a Settlement;
- Port on a River Settlement;
- Forester's Lodge on Forest;
- Mill on suitable countryside;
- Monastery on suitable land.

This creates an important visual and mechanical progression:

> **Act I establishes the land.  
> Act II develops it.  
> Act III transforms it.**

---

# 5. Edge-Matching Model

Exact implementation details remain subject to prototype testing, but the working model should support multiple spatial channels on one tile.

Instead of assigning each edge one exclusive identity, an edge can carry the relevant continuity information for the features that reach it.

For example, an edge may indicate:

- open countryside;
- Forest continuity;
- River continuity;
- Road continuity;
- Settlement continuity.

Placement is legal only when every relevant edge relationship is compatible.

Examples:

- Road exit must meet Road exit.
- River exit must meet River exit.
- Forest continuation must meet compatible Forest continuation.
- Settlement edge must meet compatible Settlement edge.
- A plain open edge must meet compatible open geography unless a special rule says otherwise.

A tile may contain more than one feature without requiring those features to use the same edge.

Example:

> A Woodland Road tile might have Forest continuing north/east while a Road bends west/south through open ground.

The Road and Forest coexist in the same square but remain separate connected features.

This layered model is essential because it allows the board to become a believable mixed landscape rather than a set of isolated feature zones.

---

# 6. Feature Geometry Vocabulary

The Starter 24 should teach a deliberately restrained set of geometric ideas.

## 6.1 Fundamental Geometry

The starter vocabulary should contain:

- endpoint / cap;
- straight continuation;
- bend;
- limited branching;
- mixed-feature interaction.

These shapes are enough to create meaningful spatial puzzles without exposing every possible geometry immediately.

---

## 6.2 Geometry Reserved for Unlocks

Some obvious shapes are intentionally useful as later unlocks.

Examples include:

- four-way Road crossroads;
- three-edge Forest branch;
- three-edge Settlement block;
- four-edge dense Settlement;
- River fork;
- River confluence;
- delta;
- lake;
- Road running directly through Forest;
- Bridges;
- more complicated Road/River crossings.

These unlocks do not grant a missing core system.

Instead, they give the player **new sentences made from vocabulary they already understand**.

This supports the larger meta-progression principle:

> Unlocks should expand possibility more than raw power.

---

# 7. Starter Collection Structure

The first working collection contains approximately 24 globally available designs:

- **18 Expansion designs**
- **6 Development designs**

This does **not** mean a run begins with exactly 24 physical tiles.

A tile **design** and a physical tile **copy** are different things.

The global collection defines which designs exist.

The run pool defines which unlocked designs are eligible during a particular run.

The physical bag contains finite copies of those eligible designs.

Therefore:

- Straight Road may appear several times in the bag;
- River Bend may appear several times;
- Open Fields may appear several times;
- specialized hybrids may appear less frequently;
- Development copies may be introduced through rewards;
- new copies can enter the bag during the run.

This is why 24 starter designs are sufficient for extensive prototype play.

A test bag may contain dozens of physical tiles built from a much smaller number of repeated designs.

---

# 8. Starter Expansion Tiles

## Tile 01 — Open Fields

**Class:** Expansion  
**Geography:** Field  
**Built feature:** None  
**Complexity:** Basic  
**Starter role:** Universal expansion / support / repair

### Description

A fully open countryside tile with no Road, Settlement, River, Forest, or civic feature.

### Mechanical Purpose

Open Fields provide the simplest legal expansion space in the game.

They can:

- support nearby Settlements;
- provide agricultural countryside;
- fill difficult holes;
- preserve flexibility;
- provide natural surroundings for civic sites;
- become eligible for later rural Developments.

### Design Notes

The base geography should be called **Field** rather than automatically treating every open square as a developed Farm.

Specific agricultural states can later be created by:

- Developments;
- tags;
- tile variants;
- Foundation rules.

### Frequency Expectation

Likely common in the opening Homestead bag.

Exact copy count: **TBD through bag prototyping.**

---

## Tile 02 — Forest Edge

**Class:** Expansion  
**Geography:** Field + Forest  
**Built feature:** None  
**Complexity:** Basic  
**Starter role:** Forest endpoint / closure

### Geometry

Forest reaches one edge and closes within the square.

### Mechanical Purpose

Allows a connected Forest to begin or terminate.

This is essential for making Forest completion controllable rather than forcing all Forests to expand indefinitely.

### Realm Identity

Primary association:

> Forest → Ecology

### Frequency Expectation

Common.

Exact copy count: **TBD.**

---

## Tile 03 — Forest Bend

**Class:** Expansion  
**Geography:** Field + Forest  
**Built feature:** None  
**Complexity:** Basic  
**Starter role:** Forest turning geometry

### Geometry

A single connected Forest reaches two adjacent edges.

### Mechanical Purpose

Allows Forests to turn around obstacles and create irregular natural regions.

### Frequency Expectation

Common.

Exact copy count: **TBD.**

---

## Tile 04 — Forest Belt

**Class:** Expansion  
**Geography:** Field + Forest  
**Built feature:** None  
**Complexity:** Basic  
**Starter role:** Straight Forest continuation

### Geometry

A connected Forest reaches two opposite edges.

### Mechanical Purpose

Allows creation of corridors, belts, and long connected woodland.

### Design Notes

The starter collection intentionally omits a three-edge Forest branch.

That geometry is a strong candidate for an early unlock.

### Frequency Expectation

Common.

Exact copy count: **TBD.**

---

## Tile 05 — River Source

**Class:** Expansion  
**Geography:** Field + River  
**Built feature:** None  
**Complexity:** Basic  
**Starter role:** River endpoint

### Geometry

A River reaches one edge and terminates within the square.

### Mechanical Purpose

Allows Rivers to begin or end.

### Open Rule Question

“Source” is currently primarily flavor.

Until River flow direction is deliberately designed, this tile should probably function mechanically as a general River endpoint rather than requiring directional upstream/downstream logic.

### Frequency Expectation

Moderate.

Exact copy count: **TBD.**

---

## Tile 06 — River Run

**Class:** Expansion  
**Geography:** Field + River  
**Built feature:** None  
**Complexity:** Basic  
**Starter role:** Straight River continuation

### Geometry

River connects two opposite edges.

### Mechanical Purpose

Allows Rivers to span the map and form long geographic features.

### Design Notes

Rivers should eventually have a completion identity distinct from simply becoming “blue Roads.”

That scoring/completion identity remains intentionally unresolved.

### Frequency Expectation

Common-to-moderate.

Exact copy count: **TBD.**

---

## Tile 07 — River Bend

**Class:** Expansion  
**Geography:** Field + River  
**Built feature:** None  
**Complexity:** Basic  
**Starter role:** River turning geometry

### Geometry

River connects two adjacent edges.

### Mechanical Purpose

Allows Rivers to wind through the realm.

### Reserved Advanced Geometry

Not initially included:

- River fork;
- River confluence;
- delta;
- lake;
- canal;
- bridge.

### Frequency Expectation

Common-to-moderate.

Exact copy count: **TBD.**

---

## Tile 08 — Road End

**Class:** Expansion  
**Geography:** Field  
**Built feature:** Road  
**Complexity:** Basic  
**Starter role:** Road endpoint / closure

### Geometry

Road reaches one edge and terminates within the tile.

### Visual Possibilities

The road may visually end at:

- a farmhouse;
- a roadside inn;
- a milestone;
- a small green;
- a waystation;
- another non-scoring landmark.

The landmark need not create a separate mechanic.

### Mechanical Purpose

Provides control over Road completion.

### Realm Identity

Primary association:

> Road → Trade

### Frequency Expectation

Common.

Exact copy count: **TBD.**

---

## Tile 09 — Straight Road

**Class:** Expansion  
**Geography:** Field  
**Built feature:** Road  
**Complexity:** Basic  
**Starter role:** Basic Road continuation

### Geometry

Road connects two opposite edges.

### Mechanical Purpose

The simplest infrastructure extension.

Likely one of the most frequently repeated physical tile designs in the Homestead bag.

### Frequency Expectation

Very common.

Exact copy count: **TBD.**

---

## Tile 10 — Bending Road

**Class:** Expansion  
**Geography:** Field  
**Built feature:** Road  
**Complexity:** Basic  
**Starter role:** Road turning geometry

### Geometry

Road connects two adjacent edges.

### Mechanical Purpose

Allows Road networks to route around existing geography.

### Frequency Expectation

Very common.

Exact copy count: **TBD.**

---

## Tile 11 — Road Junction

**Class:** Expansion  
**Geography:** Field  
**Built feature:** Road  
**Complexity:** Intermediate starter  
**Starter role:** Basic network branching

### Geometry

Three connected Road exits.

### Mechanical Purpose

Introduces the idea that Roads form networks rather than merely linear chains.

### Design Decision

The Starter 24 uses a three-way junction rather than a four-way crossroads.

A true four-way crossroads:

- creates four simultaneous open obligations;
- is more geometrically demanding;
- can serve as a meaningful later Road/infrastructure unlock.

### Frequency Expectation

Uncommon-to-moderate.

Exact copy count: **TBD.**

---

## Tile 12 — Hamlet Edge

**Class:** Expansion  
**Geography:** Field  
**Built feature:** Settlement  
**Complexity:** Basic  
**Starter role:** Settlement endpoint / small-settlement building

### Geometry

Settlement occupies one edge and closes within the tile on its other sides.

### Mechanical Purpose

Provides the smallest basic Settlement component.

Compatible Settlement pieces can combine to form a completed Hamlet.

### Realm Identity

Primary association:

> Settlement → Population

### Frequency Expectation

Common.

Exact copy count: **TBD.**

---

## Tile 13 — Settlement Corner

**Class:** Expansion  
**Geography:** Field  
**Built feature:** Settlement  
**Complexity:** Basic  
**Starter role:** Settlement turning geometry

### Geometry

One connected Settlement reaches two adjacent edges.

### Mechanical Purpose

Allows Settlements to grow around corners and create less linear shapes.

### Frequency Expectation

Common.

Exact copy count: **TBD.**

---

## Tile 14 — Settlement Throughway

**Class:** Expansion  
**Geography:** Field  
**Built feature:** Settlement  
**Complexity:** Basic  
**Starter role:** Straight Settlement continuation

### Geometry

One connected Settlement reaches two opposite edges.

### Mechanical Purpose

Allows longer settlement growth phases and provides another way to create larger Villages/Towns later.

### Open Presentation Question

The art may depict:

- one continuous built district;
- two dense areas joined through the center;
- a main street or civic spine.

The visual answer does not need to alter the connectivity rule.

### Reserved Advanced Geometry

Three-edge and four-edge Settlement pieces are intentionally omitted from the initial set and are candidates for later urban unlocks.

### Frequency Expectation

Moderate.

Exact copy count: **TBD.**

---

# 9. Starter Hybrid Expansion Tiles

The hybrid tiles are important because they prevent the map from becoming a set of disconnected feature zones.

They teach that multiple systems can share one square while remaining mechanically distinct.

---

## Tile 15 — Settlement Gate

**Class:** Expansion  
**Geography:** Field  
**Built feature:** Settlement + Road  
**Complexity:** Basic hybrid  
**Starter role:** Fundamental Road/Settlement interaction

### Geometry

A Settlement occupies one portion/edge of the tile.

A Road reaches another edge and terminates at the Settlement.

### Mechanical Purpose

Creates an explicit connection between a Road network and a Settlement.

This tile visually and mechanically teaches the central Trade concept:

> **Roads are valuable because they connect places.**

### Feature Relationship

Road and Settlement remain separate features.

The tile simply establishes that this Road reaches this Settlement.

### Frequency Expectation

Moderate.

Exact copy count: **TBD.**

---

## Tile 16 — Riverside Hamlet

**Class:** Expansion  
**Geography:** Field + River  
**Built feature:** Settlement  
**Complexity:** Basic hybrid  
**Starter role:** Fundamental River/Settlement interaction

### Geometry

River crosses or bends through one portion of the square.

Settlement occupies another portion and visibly touches the River.

The Settlement does not interrupt the River.

### Mechanical Purpose

Creates natural support for:

- River-adjacent Population;
- Port eligibility;
- future river commerce;
- water-focused Foundations;
- future River Specialists and Relics.

### Design Principle

The tile should make the river relationship visible on the board rather than relying only on abstract adjacency checks.

### Frequency Expectation

Moderate-to-uncommon.

Exact copy count: **TBD.**

---

## Tile 17 — Woodland Road

**Class:** Expansion  
**Geography:** Field + Forest  
**Built feature:** Road  
**Complexity:** Basic hybrid  
**Starter role:** Infrastructure/nature coexistence

### Geometry

Forest occupies part of the tile.

Road crosses the open portion of the tile.

The Road does **not** initially need to run directly through the Forest.

Example geometry:

- Forest connects north → east;
- Road bends west → south.

### Mechanical Purpose

Allows one tile to participate in both:

- a Road network;
- a Forest feature.

This creates more integrated landscapes without needing a special “Road through Forest” rule in the starter set.

### Frequency Expectation

Uncommon.

Exact copy count: **TBD.**

---

## Tile 18 — Woodland River

**Class:** Expansion  
**Geography:** Field + Forest + River  
**Built feature:** None  
**Complexity:** Basic hybrid  
**Starter role:** Natural-system integration

### Geometry

Forest and River occupy distinct readable portions of the square.

Example:

- Forest connects north → east;
- River bends west → south.

They do not need to cross.

### Mechanical Purpose

Allows Rivers and Forests to develop as interwoven natural geography rather than separate map regions.

This creates more interesting Ecology layouts and gives future Relics/Developments natural cross-system hooks.

### Frequency Expectation

Uncommon.

Exact copy count: **TBD.**

---

# 10. Starter Developments

Starter Developments introduce the concept that the player can improve or reinterpret existing geography without replacing it.

Exact scoring numbers are intentionally deferred until the first bag and completion rules are prototyped.

---

## Tile 19 — Monastery

**Class:** Development  
**Eligible base:** Suitable Field / open tile  
**Primary Track:** Culture  
**Complexity:** Basic civic  
**Starter role:** Introductory Culture engine

### Placement

Place onto an eligible existing square.

### Spatial Identity

The Monastery uses a Carcassonne-like enclosure puzzle:

> Complete/surround the Monastery by filling all eight neighboring squares.

### Mechanical Purpose

Creates a Culture mechanic that is spatially distinct from:

- Settlement size;
- Road connectivity;
- Forest completion.

### Design Decision

The Monastery is currently treated as a **Development**, not as a dedicated Expansion tile.

This lets the player choose an existing location in the realm for the civic site rather than waiting for a geographically identical blank tile with a preprinted Monastery.

### Upgrade Possibility

Future:

> Monastery → Abbey

### Copy Count

**TBD.**

---

## Tile 20 — Housing

**Class:** Development  
**Eligible base:** Settlement tile  
**Primary Track:** Population  
**Complexity:** Basic  
**Starter role:** Introductory Settlement development

### Mechanical Identity

Represents increased residential density within an existing Settlement.

### Design Goal

Housing should make an existing Settlement more valuable without requiring an entirely new Settlement geometry.

### Exact Effect

**TBD during scoring prototype.**

Avoid reducing the final design to a generic percentage bonus.

### Copy Count

**TBD.**

---

## Tile 21 — Market

**Class:** Development  
**Eligible base:** Settlement tile  
**Primary Track:** Trade  
**Complexity:** Basic  
**Starter role:** Introductory Trade development

### Mechanical Identity

Market value should care about actual spatial connectivity.

Likely variables include:

- Road connection;
- number of connected Settlements;
- size of connected network;
- other Markets later.

### Design Goal

A Market should reinforce:

> **Trade is about connectivity.**

It should not merely become “place this for +X Trade” if a more spatial rule can remain readable.

### Upgrade Possibility

Future:

> Market → Grand Market

### Copy Count

**TBD.**

---

## Tile 22 — Mill

**Class:** Development  
**Eligible base:** Field, potentially with River or agricultural eligibility  
**Primary Tracks:** Population / Trade  
**Complexity:** Basic hybrid development  
**Starter role:** Introductory rural development

### Mechanical Identity

The Mill gives countryside a development path without introducing a spendable Food or Grain economy.

### Possible Eligibility

One of the following should be tested:

- Field tile;
- Field adjacent to River;
- Field with a Farm/agricultural tag;
- River-adjacent countryside.

### Exact Effect

**TBD.**

### Design Goal

The Mill should reward useful rural placement rather than passive per-turn production.

### Copy Count

**TBD.**

---

## Tile 23 — Port

**Class:** Development  
**Eligible base:** Settlement touching River  
**Primary Track:** Trade  
**Complexity:** Basic hybrid development  
**Starter role:** Water-based Trade development

### Mechanical Identity

Turns a River Settlement into a stronger Trade node.

### Design Goal

Ports should establish one of the earliest strong bridges between:

- Settlement geography;
- River geography;
- Trade.

### Upgrade Possibility

Future:

> Port → Grand Port

### Exact Effect

**TBD.**

### Copy Count

**TBD.**

---

## Tile 24 — Forester's Lodge

**Class:** Development  
**Eligible base:** Forest tile  
**Primary Track:** Ecology  
**Complexity:** Basic natural development  
**Starter role:** Introductory low-impact Forest development

### Mechanical Identity

Introduces the principle that development does not always mean ecological destruction.

### Forest-State Role

The Lodge is a strong candidate for classification as **Lightly Developed** rather than fully Developed.

It may preserve some Ecology or preservation eligibility while creating new benefits.

### Design Goal

Teach early that Forest decisions can involve:

- leaving land untouched;
- developing it lightly;
- developing it heavily later.

### Upgrade Possibility

Future:

> Forester's Lodge → Conservatory

### Exact Effect

**TBD.**

### Copy Count

**TBD.**

---

# 11. Starter 24 Summary Table

| # | Tile | Class | Geography | Built / Overlay | Primary Role |
|---|---|---|---|---|---|
| 01 | Open Fields | Expansion | Field | — | Flexible land / support |
| 02 | Forest Edge | Expansion | Field + Forest | — | Forest endpoint |
| 03 | Forest Bend | Expansion | Field + Forest | — | Forest turn |
| 04 | Forest Belt | Expansion | Field + Forest | — | Forest straight |
| 05 | River Source | Expansion | Field + River | — | River endpoint |
| 06 | River Run | Expansion | Field + River | — | River straight |
| 07 | River Bend | Expansion | Field + River | — | River turn |
| 08 | Road End | Expansion | Field | Road | Road endpoint |
| 09 | Straight Road | Expansion | Field | Road | Road straight |
| 10 | Bending Road | Expansion | Field | Road | Road turn |
| 11 | Road Junction | Expansion | Field | Road | Road branch |
| 12 | Hamlet Edge | Expansion | Field | Settlement | Settlement endpoint |
| 13 | Settlement Corner | Expansion | Field | Settlement | Settlement turn |
| 14 | Settlement Throughway | Expansion | Field | Settlement | Settlement straight |
| 15 | Settlement Gate | Expansion | Field | Settlement + Road | Road/Settlement link |
| 16 | Riverside Hamlet | Expansion | Field + River | Settlement | River/Settlement link |
| 17 | Woodland Road | Expansion | Field + Forest | Road | Road/Forest coexistence |
| 18 | Woodland River | Expansion | Field + Forest + River | — | Forest/River coexistence |
| 19 | Monastery | Development | Existing tile | Civic Development | Culture |
| 20 | Housing | Development | Settlement | Development | Population |
| 21 | Market | Development | Settlement | Development | Trade |
| 22 | Mill | Development | Field | Development | Rural Pop/Trade |
| 23 | Port | Development | River Settlement | Development | Water Trade |
| 24 | Forester's Lodge | Development | Forest | Development | Ecology / light development |

---

# 12. What the Starter Set Teaches

The Starter 24 should teach the player a sequence of increasingly expressive concepts.

## 12.1 First: Pure Feature Grammar

The player learns:

- Fields are flexible support terrain.
- Forests connect and complete.
- Rivers form persistent natural geography.
- Roads connect through endpoints, straights, bends, and junctions.
- Settlements grow through compatible connected edges.

---

## 12.2 Second: Track Identity

The player learns the clean early associations:

- Settlement → Population
- Road → Trade
- Forest → Ecology
- Monastery → Culture

These associations should be obvious before hybrid scoring becomes common.

---

## 12.3 Third: Systems Can Share Space

Hybrid Expansion tiles introduce:

- Settlement + Road;
- Settlement + River;
- Forest + Road;
- Forest + River.

The player should begin seeing the board as one integrated realm rather than four unrelated minigames.

---

## 12.4 Fourth: The Past Can Be Developed

Starter Developments teach:

- existing Settlement tiles can become Housing;
- connected Settlements can gain Markets;
- River Settlements can become Ports;
- countryside can gain Mills;
- Forest can be lightly developed;
- a civic site can be established within existing geography.

This prepares the player for the larger Act II and Act III development systems.

---

# 13. Why 24 Designs Are Enough for Prototype Runs

The Starter 24 are **designs**, not one-of-a-kind physical tiles.

A prototype bag may contain multiple physical copies of common designs.

For example, an opening bag might eventually include several copies each of:

- Open Fields;
- Straight Road;
- Bending Road;
- Road End;
- Forest Bend;
- Forest Belt;
- River Run;
- River Bend;
- Hamlet Edge;
- Settlement Corner.

More specialized pieces might have fewer copies.

This means a physical bag can contain 30, 40, or more tiles while still drawing from a comparatively small design vocabulary.

The game also adds new tile copies through:

- Realm Track rewards;
- Charter rewards;
- other in-run reward systems.

The same physical bag persists through all three Acts.

Therefore the prototype does not require dozens of unique tile designs before meaningful full-run testing can begin.

Repeated basic geometry is not a flaw.

It is necessary for players to actually construct:

- Roads;
- Rivers;
- Forests;
- Settlements.

The strategic variation comes from:

- which pieces are drawn together;
- which pieces remain stuck in hand;
- where pieces are committed;
- what features are left open;
- which Developments are acquired;
- which new designs/copies are added to the bag;
- how Specialists and Relics change the meaning of familiar tiles.

---

# 14. Intentional Starter Omissions

The following are deliberately **not required** for the initial basic collection.

They are strong candidates for early unlocks or Act-gated content.

## Roads

- Four-way Crossroads
- specialized junctions
- bridges
- Road/River crossings
- major infrastructure
- stations

## Settlements

- three-edge dense Settlement
- four-edge urban core
- specialized districts
- explicit City-only geometry
- Urban Expansion

## Forests

- three-edge Forest branch
- deep Forest variants
- Ancient Grove
- heavily developed Forest
- special preserved woodland

## Rivers

- forks
- confluences
- deltas
- lakes
- reservoirs
- canals
- bridges
- unusual water crossings

## Geography

- Wetlands
- Mountains
- coastlines
- islands
- Highlands-specific terrain
- Foundation-specific unusual geography

## Developments

- Town Square
- Abbey
- University
- Grand Market
- Grand Port
- Great Park
- Rare Developments
- Legendary Projects

These omissions create room for meaningful progression without making the initial game feel incomplete.

---

# 15. Naming Is Still Working-Level

Several current tile names are descriptive prototype names rather than finalized player-facing names.

Examples:

- Open Fields
- Forest Edge
- Forest Belt
- River Run
- Hamlet Edge
- Settlement Throughway
- Woodland Road
- Woodland River

Final naming should wait until:

- the exact setting is clearer;
- art direction is established;
- geography terminology is standardized;
- feature-completion rules are tested.

Mechanical clarity is more important than flavor naming at this stage.

---

# 16. Important Open Questions

The Starter 24 are ready to support the next design step, but several questions remain intentionally unresolved.

## 16.1 Exact Edge Encoding

The layered model is conceptually established, but implementation still needs a precise representation for:

- Field/open edges;
- Forest continuation;
- River continuation;
- Road continuation;
- Settlement continuation;
- multiple feature channels on one tile.

This should be formalized before digital implementation.

---

## 16.2 River Completion Identity

Rivers must not become simple blue Roads.

Still unresolved:

- what constitutes River completion;
- whether Rivers have direction;
- whether source/mouth distinction matters;
- whether River endpoints require special geography;
- whether Rivers score primarily through length, environment, relationships, or another condition.

---

## 16.3 Settlement Completion Details

Still to test:

- exact completion boundary rules;
- whether starter Settlement geometry is sufficient;
- whether Settlement Throughway is desirable;
- whether a basic three-edge Settlement should actually be included earlier;
- how classification into Hamlet / Village / Town / City should work.

---

## 16.4 Forest Completion Details

Still to test:

- exact closure rules;
- how mixed Forest tiles count toward feature size;
- how Forest Developments affect preservation bonuses;
- whether the three starter Forest geometries create enough usable Forest shapes.

---

## 16.5 Development Draw/Placement Procedure

The unified bag is locked as the direction, but prototype details still need testing for Development tiles that are drawn when no eligible tile exists.

The system should avoid repeatedly giving the player literally unusable Developments while preserving the pressure of constrained draws.

---

## 16.6 Monastery Placement

The current Starter 24 treats Monastery as a Development.

This should be explicitly tested against the alternative of a dedicated Monastery Expansion tile.

Questions include:

- Is choosing the Monastery's location too powerful?
- Does it create good enclosure planning?
- Should Monastery require an undeveloped Field?
- Can it be placed on completed or only undeveloped geography?
- Should the surrounding-eight condition begin immediately when placed?

---

## 16.7 Hybrid Tile Exact Geometry

The concept of hybrid tiles is strong, but each needs a finalized art/edge diagram.

Particularly:

- Settlement Gate;
- Riverside Hamlet;
- Woodland Road;
- Woodland River.

These should be visually readable at a glance and avoid ambiguous feature crossings.

---

# 17. Next Prototype Step — Homestead Starting Bag

The next recommended task is to define the **Homestead starting bag**.

That requires assigning physical copy counts to designs.

The goal is not numerical balance yet.

The goal is to create a bag that can answer practical questions such as:

- Can the player usually complete at least one early Settlement?
- Can Roads realistically connect multiple Settlements?
- Can Forests be completed without excessive luck?
- Do Rivers appear often enough to matter?
- Do Rivers appear so often that they dominate placement constraints?
- Are junctions useful or annoying?
- Are hybrid tiles frequent enough to integrate the map?
- Are Developments entering play at the desired Act cadence?
- Does the 3-tile hand usually offer meaningful choices?
- How often does the Reserve become important?
- How often are tiles literally impossible to place?
- Does the board develop interesting awkward spaces without constantly deadlocking?

Only after the Homestead bag and copy counts exist should the team seriously tune:

- feature scoring;
- exact completion rules;
- reward frequency;
- track thresholds.

---

# 18. Prototype Success Criteria for the Starter Set

The Starter 24 should be considered successful if early manual test games consistently produce the following.

## Readability

A new player can identify:

- Field;
- Forest;
- River;
- Road;
- Settlement;
- Development

without needing to inspect detailed text every turn.

## Spatial Pressure

Placement creates:

- commitments;
- awkward edges;
- opportunities;
- holes;
- meaningful future constraints.

## Completableness

Basic features can actually be completed at realistic frequencies.

## Mixed Landscape

The realm naturally contains interacting:

- Roads;
- Rivers;
- Forests;
- Settlements;
- countryside.

## Distinct Track Behavior

Population, Trade, Culture, and Ecology do not all reward exactly the same spatial pattern.

## Development Potential

Act I geography leaves interesting locations for later:

- Housing;
- Markets;
- Ports;
- Mills;
- Forest development;
- civic sites.

## Expandability

Later unlocks can add new geometry and combinations without invalidating or replacing the starter vocabulary.

## Repetition Without Sameness

Repeated copies of basic designs should be useful while different draw orders still produce meaningfully different maps.

---

# 19. Current Working Starter 24

### Expansion — 18

1. Open Fields  
2. Forest Edge  
3. Forest Bend  
4. Forest Belt  
5. River Source  
6. River Run  
7. River Bend  
8. Road End  
9. Straight Road  
10. Bending Road  
11. Road Junction  
12. Hamlet Edge  
13. Settlement Corner  
14. Settlement Throughway  
15. Settlement Gate  
16. Riverside Hamlet  
17. Woodland Road  
18. Woodland River  

### Development — 6

19. Monastery  
20. Housing  
21. Market  
22. Mill  
23. Port  
24. Forester's Lodge  

---

# 20. Status Summary

The Starter 24 now provide a complete first-pass vocabulary for prototype tile play.

The major improvement over the earlier concept is the restored **layered tile structure**.

Roads, Rivers, Forests, Settlements, and Fields are no longer treated as mutually exclusive tile categories. A square can participate in multiple systems at once, allowing the board to grow into an integrated landscape.

The Starter 24 should be understood as:

> **the initial design vocabulary, not the complete contents of the physical bag.**

Multiple physical copies of common designs will be used to construct the Homestead starting bag.

The immediate next step is therefore:

> **Define the Homestead starting bag and assign provisional physical copy counts.**

After that, conduct manual Act I simulations before attempting serious numerical balance.

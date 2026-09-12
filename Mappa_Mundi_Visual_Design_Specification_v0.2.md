# Mappa Mundi — Visual Design Specification
## Board and Tile Language

**Document status:** Working visual-design authority for board presentation and tile art  
**Game title:** **Mappa Mundi**  
**Former working title:** *Carcassonne Roguelite*  
**Scope:** Board visual identity, Expansion-tile art grammar, edge readability, hybrid-tile presentation, layered map presentation, and initial proof-set art direction  
**Version:** 0.2

---

# 0. Authority and Relationship to Existing Project Files

The game is now officially titled **Mappa Mundi**.

Existing project files that still use the working title *Carcassonne Roguelite* remain mechanically authoritative according to their existing source-of-truth hierarchy.

For the first playable alpha:

1. **Carcassonne Roguelite — Complete Alpha Rules Specification** remains the canonical authority for gameplay behavior.
2. **Carcassonne Roguelite — Alpha Implementation Specification** remains the canonical authority for engineering architecture and presentation-layer boundaries.
3. Older Core Design Bible / Tile Design / Relics & Specialists files remain design-history and broader-direction references where they do not conflict with the alpha rules.
4. **This document defines visual presentation only. It does not alter gameplay rules.**

If any visual description here appears to imply mechanical behavior not supported by the Complete Alpha Rules Specification, the rules specification wins.

## 0.1 Locked Visual Revision — Area Features Occupy Full Edges

**Version 0.2 supersedes the earlier centered-width guidance for Forest and Settlement edges.**

The following boundary rule is now locked:

> **Forest and Settlement are area features. When either occupies a tile edge, that feature occupies the entire edge from corner to corner.**

This is required so adjacent matching tiles merge visually into continuous woodland or continuous urban fabric rather than producing repeated rounded or four-lobed joins at tile seams.

Road and River remain linear features using centered edge sockets.

Field remains an open edge.

The resulting high-level grammar is:

> **Forest and Settlement occupy edges. Road and River cross edges. Field leaves edges open.**

---

# 1. Core Visual Thesis

The completed board should feel like:

> **A living medieval mappa mundi / illuminated manuscript that the player gradually creates during the run.**

The game should not visually imitate Carcassonne's pastoral painted-tile aesthetic.

Instead, the realm should resemble a hand-illustrated historical artifact built from:

- parchment;
- inked line work;
- stylized rivers;
- miniature forests;
- winding roads;
- iconographic settlements;
- manuscript ornament;
- map symbols;
- irregular hand-drawn geometry;
- restrained pigments;
- occasional whimsy, marginalia, and historical-map oddness.

The visual direction should support the game's core fantasy:

> **“Look at this strange little realm I made from the tiles I was given.”**

And its core design principle:

> **The map is the build.**

The realm should visibly tell the history of the run.

---

# 2. Central Board-Presentation Rule

The board should read as:

> **one continuous parchment artifact, not a pile of square cards.**

The square grid remains mechanically real and must always be recoverable for placement clarity, but the resting board state should visually prioritize the illustrated realm.

Default presentation priority:

> **Map first, grid second.**

During placement and targeting:

> **Grid first, map still readable.**

Individual placed tiles should therefore avoid:

- heavy square borders;
- beveled edges;
- card-like frames;
- drop shadows;
- raised-board-piece styling;
- visible repeated parchment rectangles.

Tile seams should be subtle or nearly invisible when the player is simply reading the completed map.

---

# 3. Continuous Parchment Treatment

Parchment should conceptually belong to the **board**, not to each individual tile.

Preferred rendering model:

1. continuous world-space parchment / vellum surface;
2. base Expansion geography and feature artwork;
3. Development overlay(s);
4. Transformation overlay(s);
5. Specialist marker;
6. selection / legality / preview layer;
7. optional debug layer.

Expansion assets should therefore avoid obvious self-contained parchment squares.

Open Field areas may use transparency or restrained wash so neighboring tiles visually inherit the same underlying parchment surface.

The parchment should have:

- warm bone / cream coloration;
- subtle tonal variation;
- faint fibers, stains, or age marks;
- restrained edge darkening only at the overall explored-map boundary if desired;
- no repeated tile-scale paper texture that reveals the grid.

---

# 4. Tile Construction Principle

Every Expansion tile should follow this principle:

> **Mechanical precision at the boundary; artistic irregularity everywhere else.**

The tile interior may be:

- asymmetrical;
- whimsical;
- hand-drawn;
- ornamented;
- iconographic;
- compositionally irregular.

The four edge interfaces may not be ambiguous.

---

# 5. Universal Tile Art Template

For asset design, treat each tile as if authored on a **1000 × 1000 design-unit square**.

The final exported resolution may differ.

## 5.1 Edge Clarity Zone

Reserve approximately the outer **12–15%** of each side as a mechanical clarity band.

Within this zone:

- visual noise should decrease;
- mechanical edge geometry should converge toward its standardized edge socket;
- decorative marks should not compete with gameplay information;
- strong non-mechanical forms should not reach the boundary.

## 5.2 Corner Quiet Zones

Keep approximately the outer **7% × 7%** corner regions relatively quiet **when those corners are not mechanically occupied by an area feature**.

This rule is subordinate to the locked Forest/Settlement edge rule.

If a Forest or Settlement edge reaches a corner, the corresponding Forest or Settlement artwork **must** occupy that corner because the feature spans the full edge from corner to corner.

For Field, Road, and River contexts, avoid visually strong decorative elements near corners that could imply false adjacency or edge continuation.

Examples to avoid in mechanically open corners:

- non-mechanical large trees;
- non-mechanical dense house clusters;
- decorative water;
- long fence lines;
- path-like marks.

---

# 6. Alpha Edge Grammar

The alpha has exactly five edge types:

- **Field**
- **Forest**
- **River**
- **Road**
- **Settlement**

Each tile edge has exactly one mechanical edge type.

Multiple systems may exist within one tile, but each individual edge remains unambiguous.

Visual design must preserve this exact grammar.

---

# 7. Standardized Edge Grammar

The five edge types do **not** all use the same boundary model.

The locked visual distinction is between **area features**, **linear features**, and **open Field**:

| Edge Type | Locked boundary treatment | Primary silhouette |
|---|---|---|
| Field | Entire edge visually open / unstructured | negative space |
| Forest | **Entire edge, corner to corner** | dense organic area mass |
| River | Centered socket, approximately **18–22%** of tile width | medium-width linear ribbon |
| Road | Centered socket, approximately **8–11%** of tile width | narrow linear track |
| Settlement | **Entire edge, corner to corner** | broad angular built area mass |

This produces the core visual grammar:

> **Forest and Settlement occupy edges. Road and River cross edges. Field leaves edges open.**

For Road and River, the feature must meet the exact midpoint of the relevant edge using a consistent width.

For Forest and Settlement, the feature must visibly occupy the **full boundary from one corner to the other**. Once inside the tile, either area feature may taper, bulge, scallop, narrow, widen, or otherwise become irregular so long as its topology remains obvious.

This full-edge rule prevents connected Forests and Settlements from forming repeated rounded joins or four-lobed / clover-like patterns at tile seams.

---

# 8. Field Visual Language

Field is the visual default and should read primarily through **openness**.

Field edges should contain:

- open parchment / countryside wash;
- sparse grasses;
- small furrow marks;
- flowers;
- occasional stones;
- restrained agricultural marks.

Field edges should not contain:

- dense tree masses;
- architecture reaching the boundary;
- blue water ribbons;
- strong parallel path marks;
- any other feature that could imply a non-Field edge.

Field should often function as negative space against which the four stronger edge types are immediately legible.

## 8.1 Open Fields Interior

Open Fields may contain decorative details such as:

- sheep;
- hayricks;
- isolated trees;
- plough marks;
- small fences;
- rocks;
- flowers;
- tiny shrines;
- one non-mechanical farmhouse;
- ruins or standing stones.

These details must remain subordinate to the mechanical grammar.

---

# 9. Forest Visual Language

Forest should be the strongest **organic textural mass** on the board.

It should not resemble realistic aerial canopy.

It should resemble an illustrated medieval wood composed of repeated upright miniature trees.

## 9.1 Forest Edge Treatment

Forest is an **area feature**, not a centered socket.

Where a tile edge is Forest:

> **The Forest occupies the entire edge from corner to corner.**

Required treatment:

- dense woodland imagery reaches the boundary across the full side;
- both corners belonging to that Forest edge are visibly wooded;
- do not draw a closing treeline along the connected edge;
- the woodland may begin tapering inward only after it has clearly established full-edge occupancy;
- matching Forest edges should visually merge into one continuous woodland mass.

Where Forest ends inside the tile:

- use an irregular visible treeline;
- scalloped / lobed woodland contours are preferred;
- the interior ending should be obvious.

For a Forest Bend with two adjacent Forest edges, the shared corner should be especially continuous and dense so the two full-edge Forest sides read as one connected woodland.

## 9.2 Tree Language

Use a small recurring library of tree glyphs, for example:

- rounded deciduous crown;
- narrow conifer;
- simplified medieval “lollipop” tree;
- occasional twisted or ancient tree.

Forests should feel clustered and illustrated rather than procedurally realistic.

## 9.3 Forest Detail

Optional close-zoom details may include:

- deer;
- boar;
- mushrooms;
- hermits;
- woodland shrines;
- birds;
- exposed roots;
- small clearings.

These should never obscure the feature boundary.

---

# 10. River Visual Language

River should read as a clearly bounded, continuous painted ribbon.

## 10.1 River Edge Socket

Recommended width:

> **approximately 18–22% of tile width**

The River enters or exits at the exact center of the relevant edge.

River banks should meet the tile boundary at standardized positions.

## 10.2 River Interior

The river may wander naturally between standardized sockets.

A mechanically straight River does not need to be ruler-straight.

It may:

- bow;
- meander slightly;
- narrow or widen subtly;
- curve organically within the square.

Its overall topology must remain instantly readable.

## 10.3 River Rendering

Preferred treatment:

- dark umber ink banks;
- translucent faded blue / verdigris wash;
- sparse horizontal wave marks;
- occasional close-zoom fish or ripple symbols.

Avoid:

- glossy water;
- 3D reflections;
- realistic aerial rendering;
- decorative blue streams elsewhere on the tile.

During the early visual language, blue linear water should strongly imply **River**.

---

# 11. Road Visual Language

Road should be visibly narrower and lighter than River.

## 11.1 Road Edge Socket

Recommended width:

> **approximately 8–11% of tile width**

The Road meets the relevant edge exactly at its midpoint.

## 11.2 Road Rendering

Preferred treatment:

- warm ochre / sienna earth track;
- slightly irregular dark boundary strokes;
- faint wagon ruts;
- occasional wheel or foot marks.

An acceptable alternative is to leave much of the road surface close to parchment color and define it mainly through its two inked edge lines.

## 11.3 Road Geometry

Mechanically straight does not mean visually perfect.

A Straight Road may gently bow.

A Bending Road may form a broad handmade curve.

The player must still understand the topology immediately.

## 11.4 Roadside Ornament

Road-adjacent decoration may include:

- milestones;
- signposts;
- wayside shrines;
- travellers;
- carts;
- inns where appropriate;
- small monuments.

These should remain clearly decorative and never create false Road exits.

---

# 12. Settlement Visual Language

Settlement should be the strongest **built angular mass** on the board.

It must not resemble merely a wider Road.

## 12.1 Settlement Edge Treatment

Settlement is an **area feature**, not a centered socket.

Where a tile edge is Settlement:

> **The Settlement occupies the entire edge from corner to corner.**

Required treatment:

- built fabric visibly reaches the boundary across the full side;
- both corners belonging to that Settlement edge contain clear settlement structure or urban fabric;
- do not leave Field-like gaps at the corners of a Settlement edge;
- the Settlement may taper, narrow, open into a green, or otherwise become irregular once it moves inward from the boundary;
- matching Settlement edges should visually merge into one continuous district rather than two rounded settlement blobs touching at their centers.

Possible visual elements along or immediately behind the full edge:

- roofs;
- houses;
- walls;
- palisades;
- gates;
- lanes;
- towers;
- dense built fabric.

## 12.2 Settlement Interior

Settlement architecture should use iconographic medieval-map perspective rather than realistic aerial perspective.

Buildings may show:

- façades;
- roofs;
- walls;
- towers;
- streets;

with intentionally inconsistent perspective.

This inconsistency is desirable if it increases manuscript character.

## 12.3 Settlement Termination

Where the Settlement ends inside a tile, its built district should visibly close.

Possible closure language:

- hedge;
- fence;
- ditch;
- palisade;
- wall;
- obvious transition back into open countryside.

The player should understand that the inhabited feature ends before the other edges.

---

# 13. Perspective and Scale

Mappa Mundi should use:

> **top-down geographic layout with iconographic upright objects**

The landscape itself should read from above so gameplay geometry remains understandable.

Individual objects may use medieval representational scale.

Examples:

- trees may stand upright;
- houses may show façades;
- churches may be dramatically oversized;
- a stag may be nearly the size of several cottages;
- a mill may be larger than geographically realistic;
- towers may dominate a small settlement.

Do not attempt realistic scale consistency.

The relevant question is:

> **How would an illuminator communicate that this place contains this thing?**

not:

> **What would this location look like from a satellite?**

---

# 14. Line-Work Style

Suggested reference line weights at a 1024 × 1024 master:

- **Primary structural line:** ~6–8 px
- **Secondary illustration line:** ~3–4 px
- **Fine hatching/detail:** ~1.5–2 px

Lines should show:

- restrained pressure variation;
- mild wobble;
- imperfect joins;
- occasional ink pooling;
- hand-drawn irregularity.

Avoid:

- sterile CAD vectors;
- perfectly uniform strokes;
- deliberately sloppy amateur drawing.

The desired impression is:

> **skilled handmade manuscript illustration**

---

# 15. Base Color Palette

The board should use restrained earth pigments rather than glossy game colors.

Working palette:

| Element | Working color |
|---|---|
| Parchment | warm bone `#E5D4AA` |
| Main ink | dark umber `#30271E` |
| Secondary ink | brown `#594535` |
| Field wash | muted straw/sage `#C4B87C` |
| Forest | olive green `#66784A` |
| Deep Forest accent | `#465735` |
| River | faded blue-verdigris `#628F92` |
| Road | warm ochre `#B68A56` |
| Settlement roof accent | oxide red `#A55E48` |
| Illumination gold | muted gold `#C69A43` |

These values are provisional art-direction references rather than immutable final asset colors.

Stronger pigments such as:

- saturated blue;
- scarlet;
- gold;
- purple;

should generally be reserved for higher-order manuscript illumination, UI emphasis, Charters, Relics, rewards, or major special presentation.

The normal board geography should remain mostly earth-pigment based.

---

# 16. Mechanical Marks vs Decorative Marks

This distinction is a hard visual rule.

## 16.1 Mechanical Marks

Mechanical features may:

- reach tile edges;
- dominate silhouette;
- use strong contrast;
- form large contiguous shapes.

Mechanical marks include:

- Forest;
- River;
- Road;
- Settlement.

## 16.2 Decorative Marks

Decorative marks should normally:

- remain inside the tile;
- use lower contrast;
- remain small;
- avoid false edge connections;
- avoid strongly imitating mechanical feature silhouettes.

### Allowed decorative examples

- isolated trees;
- sheep;
- flowers;
- haystacks;
- rocks;
- small shrines;
- tiny farmhouses;
- minor ruins;
- carts;
- animals;
- manuscript beasts.

### Avoid

- decorative streams;
- long paths that resemble Roads;
- dense tree groups that resemble Forest;
- architecture touching an edge unless Settlement is mechanically present;
- linear fences that strongly resemble Road exits;
- decorative color bands that resemble feature sockets.

---

# 17. Tile-Seam Policy

Do not bake heavy square borders into Expansion art.

At normal viewing distance:

- seams should be extremely subtle;
- the realm should read continuously;
- parchment and feature art should dominate.

At far zoom:

- seams may disappear entirely.

During placement:

- the grid may become more visible around relevant spaces;
- legal targets may gain subtle manuscript-style square outlines;
- selected / previewed squares may use stronger framing;
- mismatches may use small geometric or rubricated indicators.

Selection, legality, preview, and debug visualization must remain separate presentation layers from the base tile art.

---

# 18. Adjacent-Tile Blending

Adjacent tiles do not need to match decorative art pixel-for-pixel.

Only mechanical continuation must be exact.

## 18.1 Required Continuity

When matching features meet:

- Forest should read as one continuous woodland mass;
- River should read as one uninterrupted watercourse;
- Road should read as one continuous route;
- Settlement should read as one continuing built district.

## 18.2 Decorative Continuity

Field textures, grasses, furrows, animals, and other non-mechanical details do not need exact matching.

Two adjoining Field tiles may depict different countryside details and still feel like one map.

The asset strategy is therefore:

> **modular manuscript fragments with standardized mechanical transition grammar**

rather than:

> **one giant illustration sliced into squares**

---

# 19. Hybrid-Tile Visual Rule

When two systems share one tile:

> **Their mechanical relationship must be visible in the illustration.**

The artwork must communicate not only which systems are present, but how they relate internally.

This is especially important because visually touching systems may have explicit mechanical relationships even while remaining separate feature types.

---

# 20. Settlement Gate

Canonical visual brief:

- 1 Settlement edge;
- 1 Road edge;
- 2 Field edges;
- Road explicitly terminates at/connects to Settlement.

Recommended composition:

- Settlement occupies its entire Settlement edge from corner to corner, then may taper inward;
- Road enters from another edge using the normal narrow centered Road socket;
- Road clearly travels toward the settlement;
- Road visibly ends at a gate, street entrance, or opening between houses.

Primary visual statement:

> **This road goes to this settlement.**

The Road must not appear to continue through the Settlement unless the mechanical tile specifically supports that.

---

# 21. Riverside Hamlet

Canonical visual brief:

- 1 Settlement edge;
- 2 opposite River edges;
- 1 Field edge;
- River runs continuously through the tile;
- Settlement explicitly touches River;
- Settlement does not interrupt River.

Recommended composition:

- River travels continuously from one side to its opposite using centered River sockets;
- Settlement occupies its entire Settlement edge from corner to corner, then grows/tapers inward toward the riverbank;
- buildings, steps, washing area, small landing, or modest waterside activity can show habitation;
- the River remains visually uninterrupted.

Do not make the base tile look like an already-developed Port.

Avoid major:

- piers;
- cranes;
- warehouses;
- fortified harbors.

Primary visual statement:

> **People live beside this river.**

---

# 22. Woodland Road

Canonical visual brief:

- 2 adjacent Forest edges;
- 2 adjacent Road edges;
- Forest pair connected;
- Road pair connected;
- Road and Forest remain distinct.

Recommended composition:

- each Forest edge is occupied corner to corner, with the two adjacent Forest sides merging through their shared corner into one connected woodland mass;
- the Forest may taper inward into an irregular curved treeline;
- Road bends through the remaining open ground using centered Road sockets;
- preserve enough Field between Road and Forest that the Road does not appear to pass directly through the Forest.

Primary visual statement:

> **The road skirts the woodland.**

This distinction is useful because later content may explicitly support Road-through-Forest relationships.

---

# 23. Woodland River

Canonical visual brief:

- 2 adjacent Forest edges;
- 2 adjacent River edges;
- Forest pair connected;
- River pair connected;
- Forest and River remain separate but explicitly touch within the tile.

Recommended composition:

- each Forest edge is occupied corner to corner, with the adjacent Forest sides merging continuously through their shared corner;
- the Forest may taper inward into an irregular connected mass;
- River bends through the complementary portion using centered River sockets;
- Forest visibly reaches the riverbank somewhere inside the tile;
- roots, reeds, overhanging trees, or a drinking animal may reinforce the relationship.

Primary visual statement:

> **The woodland meets the river.**

Unlike Woodland Road, visible contact is desirable here.

---

# 24. Founding Tile

The Homestead Founding Tile is a special visual centerpiece.

Canonical orientation:

- **North:** Settlement
- **East:** Road
- **South:** River
- **West:** Forest

Internal relationship:

- Road terminates at/connects to Settlement;
- River remains separate;
- Forest remains separate.

Recommended visual interpretation:

- northern edge: Settlement occupies the full edge corner to corner, then tapers inward into a small founding hamlet / built district;
- eastern edge: narrow centered Road leaving or entering its gate;
- southern edge: centered River connection;
- western edge: Forest occupies the full edge corner to corner, then tapers inward into compact woodland;
- center: restrained founding landmark or flourish.

Possible decorative founding symbols include:

- standing stone;
- fountain;
- old tree;
- cairn;
- banner;
- tiny civic marker;
- illuminated cartographic ornament.

The Founding Tile should feel like the historical nucleus from which the entire map grew without requiring a modern “START” icon.

---

# 25. Initial Basic Tile Briefs

## 25.1 Open Fields

- four Field edges;
- lots of visual breathing room;
- pale parchment / straw / sage wash;
- optional sheep, plough marks, hayrick, isolated tree, flowers;
- no mechanical feature reaches any edge.

Purpose:

> establish what complete mechanical openness looks like.

## 25.2 Forest Edge

Assume Forest north.

- Forest occupies the entire north edge from northwest corner to northeast corner;
- woodland remains visually open across that full boundary as continuation;
- after entering the tile, the Forest may taper inward;
- irregular treeline closes internally on all other sides;
- countryside remains open elsewhere.

Immediate read:

> **Forest continues north only.**

## 25.3 Forest Bend

Assume Forest north + east.

- Forest occupies the entire north edge corner to corner;
- Forest occupies the entire east edge corner to corner;
- the northeast shared corner is continuously wooded;
- one connected woodland mass may taper inward into an irregular curved treeline;
- remaining interior region remains Field;
- the interior boundary should be irregular rather than a perfect geometric quarter-circle.

## 25.4 Straight Road

Assume west ↔ east.

- identical Road sockets at west/east midpoints;
- narrow ochre route;
- road may bow gently inside the tile;
- optional milestone, fence, sheep, or isolated tree;
- no competing linear decorative mark.

## 25.5 Bending Road

Assume west → south.

- normal Road sockets;
- broad handmade curve through tile;
- optional shrine or minor roadside detail;
- topology must remain instantly legible.

## 25.6 Hamlet Edge

Assume Settlement north.

- Settlement occupies the entire north edge from northwest corner to northeast corner;
- built fabric may taper inward after the full-edge connection is established;
- architecture may gather around a green/well in the interior;
- settlement visually closes before east/south/west edges;
- hedge, palisade, ditch, or boundary may mark its internal end;
- countryside fills remainder.

Any internal cart track must not reach a non-Road edge.

---

# 26. Zoom-Level Readability

The board should reveal different information at different scales.

## Far Zoom

The player should read:

- Field = pale/open;
- Forest = dark organic mass;
- River = blue ribbon;
- Road = narrow ochre line;
- Settlement = broad angular built mass.

Fine ornament may disappear.

## Normal Gameplay Zoom

The player should clearly understand:

- exact edge geometry;
- connected feature topology;
- major developments;
- Specialist location;
- legal placement state when relevant.

## Close Zoom

The player may discover:

- animals;
- monks;
- travellers;
- carts;
- manuscript hatching;
- architectural details;
- tiny jokes;
- strange creatures;
- marginalia-like flourishes.

Detail should be a reward for looking closely, not a tax on gameplay readability.

---

# 27. Layered Board History

The visual system must reinforce the persistent three-Act structure:

> **Act I establishes the land.**  
> **Act II develops it.**  
> **Act III transforms it.**

Old tiles should not suddenly change art style when Acts change.

Instead, the history should accumulate visibly.

## Base Expansion Layer

Should remain identifiable as the original geography and connectivity.

## Development Layer

Should visibly look like something was **added to an existing place**.

A Development should not normally erase the host artwork.

Examples:

- Housing adds density to existing Settlement art;
- Market adds stalls / square / commercial symbols;
- Forester's Lodge adds a small lodge into existing Forest;
- Monastery adds a civic/religious icon into existing geography;
- Port adds commercial waterside infrastructure to a River Settlement.

## Upgrade Layer

An Upgrade may replace the previous Development's specific visual identity while preserving evidence of the host geography and broader historical context.

Examples:

- Monastery → Abbey;
- Market → Grand Market.

## Transformation Layer

Transformation should visibly alter the old landscape while preserving whatever historical geography the rules say remains.

Examples:

- Bridge preserves River while adding a perpendicular Road crossing;
- Rewilding changes appropriate Field geography into Forest;
- Urban Expansion visibly extends or reconnects Settlement geometry.

The visual result should feel like **history written over history**, not like the tile was replaced with a brand-new card.

---

# 28. Art-Generation / Commissioning Rule

Every tile asset brief should contain:

1. tile name;
2. canonical edge types and orientation;
3. internal feature relationships;
4. required mechanical contacts;
5. required mechanical separations;
6. allowed decorative content;
7. forbidden ambiguous decorative content;
8. Development/Transformation compatibility notes where relevant.

Example:

```text
Settlement Gate
Settlement N
Road E
Field S
Field W

Road terminates at and connects to Settlement.
Settlement and Road remain distinct features.
No Road continuation beyond the Settlement.
No other mechanical feature reaches an edge.
```

This internal-topology brief is mandatory.

For edge treatment, every brief must also respect the locked area/linear distinction:

- **Forest edge:** full side, corner to corner;
- **Settlement edge:** full side, corner to corner;
- **River edge:** centered standardized socket;
- **Road edge:** centered standardized socket;
- **Field edge:** visually open.

Attractive artwork that misrepresents topology or edge occupancy is an invalid asset.

---

# 29. Initial 11-Tile Visual Proof Set

The first visual-concept sheet should contain:

1. Open Fields
2. Forest Edge
3. Forest Bend
4. Straight Road
5. Bending Road
6. Hamlet Edge
7. Settlement Gate
8. Riverside Hamlet
9. Woodland Road
10. Woodland River
11. Founding Tile

This set is intended to prove:

- five-edge readability;
- standardized sockets;
- continuous parchment treatment;
- tile-to-tile blending;
- basic feature geometry;
- mixed-feature clarity;
- explicit internal topology;
- visual distinction between mechanical and decorative marks.

Only after this set works visually should the full tile roster be commissioned or generated at scale.

---

# 30. Current Visual Design Mantras

> **The board is one parchment artifact, not a collection of cards.**

> **Mechanical precision at the boundary; artistic irregularity everywhere else.**

> **Tile boundaries are construction lines, not decorative frames.**

> **Forest and Settlement occupy edges. Road and River cross edges. Field leaves edges open.**

> **Perspective is iconographic medieval cartography, not aerial realism.**

> **Decorative detail may be whimsical, but it may never impersonate mechanical feature geometry.**

> **When two systems share a tile, their mechanical relationship must be visible in the illustration.**

> **Internal topology is art direction.**

> **Developments add to the past; Transformations visibly rewrite it.**

> **At far zoom, read the system. At close zoom, discover the world.**

> **As the run grows, the player should increasingly stop seeing tiles and start seeing a realm.**

---

# 31. Deferred Visual Topics

The following remain intentionally unresolved and should be developed in later visual-design passes:

- full Development art language;
- Upgrade art language;
- Transformation treatment beyond the principles above;
- Act-specific visual enrichment;
- UI ornamentation;
- typography;
- Realm Track iconography;
- Specialist / Steward representation;
- Relic presentation;
- Charter presentation;
- completion effects;
- legal-placement indicators;
- selection / hover / confirmation effects;
- marginalia progression;
- labels and place names;
- heraldry;
- compass roses;
- map monsters and decorative creatures;
- animation language;
- screen transitions;
- end-of-run map presentation.

These should build on the board language defined here rather than replacing it.

---

# 32. Success Test

A successful Mappa Mundi board should satisfy all of the following:

- A new player can quickly distinguish Field, Forest, River, Road, and Settlement.
- Exact edge geometry remains readable despite hand-drawn irregularity.
- Forest and Settlement connections merge corner-to-corner into continuous area features rather than repeated rounded/clover-like joins.
- Hybrid tiles clearly show both systems and their internal relationship.
- Adjacent tiles increasingly read as one continuous illustrated map.
- Decorative detail never creates false gameplay information.
- The square grid is available when needed but does not dominate the resting board.
- Developments visibly accumulate on existing geography.
- Transformations preserve visible history where mechanically appropriate.
- The board remains readable at gameplay zoom.
- Close inspection rewards the player with charming manuscript detail.
- By the end of a run, the realm resembles a unique historical artifact created by the player's decisions.


# Mappa Mundi — alpha UI usability

Current implementation: 2026-10-01, `alpha-playtest-r1`. This is a playtest
comfort pass, not Phase 11 or final production UI.

Reference: [approved mockup](../art/references/ui/ui_mockup_alpha.png).
The reference is tracked design documentation, never a runtime texture.

## Screen structure

- **Top HUD:** Act and normal-placement progress, with a secondary full seed field
  that supports selection/copy; four Track cards with uncapped
  values and the next active reward (20 Relic, 40 Train, 70 Relic, 100 Major); compact
  Charter title and fulfilled ordinary-condition count; next Draft timing; Charter toggle.
- **Board workspace:** full-width dark tabletop beneath the HUD and above the tray.
  Parchment tiles, existing art, effective geometry, legal targets and preview remain
  authoritative state projections. Floating utility panels do not reserve sidebars.
- **Relics:** upper-left capacity/slot display. Click or hover a slot for its rarity,
  unchanged effect and once-per-Act usage details. Empty sockets remain clear.
- **Stewards:** upper-right available/total count and compact role markers. Hollow
  and filled circles distinguish available/assigned pieces; click/hover gives role,
  assignment and location. Fit Board and zoom buttons sit immediately below.
- **Bottom tray:** Reserve slots and Store controls, three large hand cards, then
  Survey charges, Bag count, rotation, exact-option selector, Confirm and Cancel.
  The selected hand/Reserve card has a thick gold border. Tooltips carry tile rules;
  cards retain only art, name and optional hand hotkey.
- **Charter popout:** a bounded right-side parchment overlay with close control,
  structured conditions, checks, current/history labels, numeric progress and rewards.
  Grand Charter forecast remains secret until the rules reveal it. Closing restores
  the unobstructed board without resizing it. PendingChoice presenters remain visible underneath Charter inspection. The
  top information layer suspends input to the underlying choice; closing or Escape
  restores focus to that exact presenter without rebuilding its offer.
- **Event card:** one dismissible parchment toast above the tray. It combines a small
  number of meaningful outcomes, then expires after seven seconds. Detailed cue text
  is a tooltip. It never advances rules or blocks a consequence chain.
- **Choices/results:** existing typed choice and results flows remain. Drafts use
  parchment cards inside dark framing, artwork and short identity text; one click
  acquires the single copy. Relic offers display Common/Uncommon/Rare as text beside
  name and effect; rarity never relies only on color. Other choices retain exact
  persisted options, and results retain the run seed.

## Tile rules and reproducible New Run

Every current player-acquirable tile stores `placement_summary` and `effect_summary`
in its static `TileDefinition`. `ChoiceText.tile_tooltip` combines these with name
and category for active-hand, Reserve and Draft cards. Complex tiles put Placement
before Effect; simple Expansions give concise edge/use information. The tooltip
uses the corrected parchment background/dark-ink theme with bounded text wrapping.
Hovering does not change selection, RNG, legality, RunState or a pending choice.

The title screen's optional Seed field starts blank. New Run uses a fresh seed from
the injectable `RunSeedSource` when blank; a valid entered signed 64-bit integer is
used exactly. Malformed or out-of-range input shows an error and creates no run.
Randomize fills a candidate without starting. External seed entropy initializes
RunRNG; it never consumes the run's gameplay random stream. Explicit seed 1 remains
supported for test fixtures and human reproduction. Once playing, the full seed is
available in the compact Act card and on final results.

Tile rules explain physical placement/effects. Relic details explain persistent
modifiers and rarity. They share readable tooltip styling, not gameplay authority.

## Presentation boundary

`GameController` owns the session command path. `PresentationQueries.hud_model`
uses RunConfig, CharterProgress and the draft cadence query. `CharterPopout` reads
only visible Charter queries. Views never calculate legality, scoring or draft
prerequisites. Confirmation submits the retained exact authoritative option.
`GameShell` owns layout and transient display state; `AlphaTheme` centralizes
palette, serif fallback font, panel spacing, progress bars and action states.
Core rules and saves have no dependency on these nodes.

## Responsive behavior

Control containers use the actual resizable viewport, with a 1280×720 minimum.
At 720p hand cards retain 110-pixel artwork and the Charter scrolls; wider windows
expand the hand/board and increase artwork to 140 pixels. The top HUD stays in
one compact row. Fit Board uses the central viewport, excluding HUD and tray;
when the Charter is open it also accounts for its overlay width. Wheel zoom,
right/middle pan, Fit and zoom buttons remain available.

The mockup's wood grain, ornate shields and bespoke icons are approximated with
flat brown StyleBoxes, borders, text and existing artwork. This intentionally
avoids new art production. Founding/other missing-art fallbacks are unchanged.
An hour-long human comfort assessment remains the next step.

## Reproducible graphical checks

Run from the project root with a graphical display:

```sh
godot --path . --script res://tests/scenarios/presentation_mouse_smoke.gd -- 1280 720
godot --path . --script res://tests/scenarios/presentation_mouse_smoke.gd -- 1920 1080
godot --path . --script res://tests/scenarios/ui_usability_capture.gd -- 1280 720
godot --path . --script res://tests/scenarios/ui_usability_capture.gd -- 1920 1080
```

The smoke script injects graphical mouse/input events through the human controller
path; it is automated, not a claim of human manual testing. It covers New Run,
Starter Draft/Charter inspection, selection, rotation, legal target, preview,
cancel/confirm, Reserve, Survey, Charter toggle, camera, status and toast visibility.
Captures are written to `builds/ui-usability-{width}x{height}-{state}.png` for
`normal`, `charter`, `preview`, `starter-draft` and `mouse-smoke` states.
Selected review captures are retained under [reports/ui_usability](reports/ui_usability/).

Automated unit/controller checks are in `tests/presentation/usability_tests.gd`;
complete gameplay and natural-bag presentation runs remain part of the normal suites.

## Overlay bugfix — 2026-10-01

Information defaults to an opaque parchment background and dark ink. Shared
`ParchmentInfoOverlay` / `AlphaTheme.information()` styles cover rules/details,
Charter, notices and event cards. Godot `TooltipPanel`, `TooltipLabel`, `PopupPanel`,
`PopupMenu` and plain `Panel` receive explicit paired colors; they cannot silently
combine parchment ink with the engine's dark translucent defaults. The optional
`DarkInfoOverlay` / `information(true)` pairs dark brown with light body text.
Focus, disabled and secondary informational states have contrast checks.

Inspection is an overlay above an active required choice, never navigation away
from it. `PendingChoicePresenter.set_information_overlay_open` suspends input
without hiding, resolving or recreating the presenter. A top input layer protects
it while the Charter is open; closing restores focus. No notice/choice-resolution
signal, RNG operation, acquisition or opening draw occurs. The controller also
rejects submissions behind inspection. Escape closes only Charter; pressing it
again cannot dismiss a mandatory choice. Saves retain the authoritative choice;
cosmetic Charter visibility is not serialized. Normal-turn Charter behavior remains.

Graphical reproduction and regression:

```sh
godot --path . --script res://tests/scenarios/overlay_mouse_smoke.gd -- 1280 720
godot --path . --script res://tests/scenarios/overlay_mouse_smoke.gd -- 1920 1080
```

The script uses actual viewport mouse/key input and captures Starter Draft before,
during and after inspection, an information card and a real automatic tile tooltip.
Tracked captures in `reports/ui_usability/overlay-fix-*` document both resolutions.
Nine new presentation tests check resolved theme contrast, repeated toggles, exact
state/offer/RNG preservation, early-draw prevention, input locking, Escape and
save/load. This bugfix changes no gameplay rules, version or save schema.

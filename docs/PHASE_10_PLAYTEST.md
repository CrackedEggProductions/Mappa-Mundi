# Mappa Mundi — playable alpha checklist

Launch from the project root with `godot --path .`, or run the project in the
Godot editor. The default scene opens New Run. Enter an integer seed or keep 1.
No Save/Continue interface is included yet; closing the application ends this
play session. The existing internal save APIs remain available to tests.

## Mouse controls

- Click a hand or occupied Reserve slot to select its physical tile.
- Click a highlighted board target, or choose an exact option from the bottom list.
- Rotate Left/Right chooses available canonical orientations. The option list also
  distinguishes Development hosts, Port Rivers, Upgrades, Transformation modes and
  explicit Boundary Stones use.
- Confirm commits the displayed option. Cancel discards only the preview. There is
  no Undo and no predicted scoring-total preview.
- Store commits a selected hand tile to an empty Reserve slot. Survey removes a
  selected hand tile using an available charge. The engine enables legal actions.
- Wheel zooms; middle/right drag pans; Center / Fit Board frames the map.
- Required choices appear in a blocking, scrollable panel. Choose one exact saved
  option or the displayed Decline/Finish action. Grand Survey removes tiles one at
  a time and offers Finish; it is not a simultaneous multiselect.
- Charter & Grand Charter opens authoritative progress. Early Act II exposes only
  the forecast. Continue dismisses cosmetic notices without advancing rules.
- Results offer View the final map. Return to results restores the overlay; New Run
  starts a fresh session only after completing the previous run.

Optional shortcuts: 1/2/3 select hand slots, Q/E rotate, Enter confirms, Escape
cancels preview, F fits the board, F11 toggles fullscreen. Mouse controls cover all
required actions.

## Human smoke checklist — not yet completed by a human

Record seed, Godot version, window size and any error message. Use both 1920×1080
and 1280×720; resize during play. Do not count automated tests as this checklist.

1. Launch the default project and click New Run.
2. Select each hand tile; verify thumbnails and legal targets change.
3. Pan with middle/right drag, release outside the board, return, zoom and Fit Board.
4. Rotate a tile, click a target and inspect the ghost.
5. Cancel; confirm no tile was placed and no hand copy was consumed.
6. Preview again and Confirm once; rapid repeat clicks must not place twice.
7. Store a hand tile in Reserve; select and later place that Reserve tile.
8. Survey a selected hand tile and verify the charge/replacement.
9. Resolve an optional Steward assignment, then try Decline on a later opportunity.
10. Inspect assigned markers and an occupied tile's feature details.
11. Place a Development; upgrade it when offered. Check the visible badge changes.
12. Place a Transformation and inspect its effective geography.
13. Resolve Tile, Specialist training, Relic and Major rewards when earned.
14. Inspect a Relic's effects and available use state; exercise replacement/decline.
15. Exercise Compass, Relay, Satchel and sequential Grand Survey if acquired.
16. Inspect ordinary Charter conditions, current progress and exceed requirements.
17. Finish Act I; resolve outgoing rewards before dismissing the transition notice.
18. In Act II inspect the Grand forecast; after placement 11's consequences, verify
    the exact reveal notice and conditions become visible.
19. Finish Act II and continue into Act III with the same civilization.
20. Finish Act III placement 26, resolve any final rewards, then inspect result,
    Tracks, score, historical statistics, Charters, Relics, training and seed.
21. Confirm the final active-hand slot was not refilled. View the final map, pan/zoom,
    return to results, and verify gameplay controls remain disabled.

## Automated evidence and limitations

`./tests/run_tests.sh` verifies core gameplay without loading presentation scenes.
`./tests/run_presentation_tests.sh` runs scene/controller tests headlessly, including
two complete natural-bag three-Act runs through the same Confirm/choice handlers.
The full-run harness does not inject physical tiles or write RunState directly.

`godot --path . --script res://tests/scenarios/presentation_mouse_smoke.gd` launches
an automated graphical viewport-input smoke test. It moves the pointer within the
test window and exits. This verifies GUI routing; it is not manual human testing.

Accepted sources are cached from `art/references/`. Thirteen designs use production
anchors, seven use existing references. Founding Tile and Road End use canonical
mechanical fallbacks. Developments/Upgrades/Transformations use simple generated
thumbnails, badges and effective-geometry overlays. No source art was changed.

The `art/.gdignore` archive remains excluded from editor import. Runtime project
loading uses cached ImageTexture resources; future export packaging must explicitly
include the selected art or stage it into exported assets during Phase 12.
UI typography, fallback illustration and animation polish remain deferred. Save &
Quit, Continue and recovery UX remain Phase 11. This phase does not certify exports.

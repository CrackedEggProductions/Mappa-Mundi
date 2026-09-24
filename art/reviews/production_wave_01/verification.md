# Production wave01 verification

2026-09-24. Commands/checks exited0. Baseline merge gameplay:569 passed,0 failed;
133 GDScript files parsed without diagnostics. No gameplay edits after this check.

- Art unittest discovery with -B -W error: **144 tests passed,0 failed**.
- Art Python AST parse: **27 files**, no diagnostics.
- All16 compositions: **17/17 exact reconstruction/provenance checks** each.
- Native geometry:24/36/37 checks perdesign; independent connected components,
  exact edge arrays/sockets, explicit contacts and equivalent four rotations.
- Road126px564..689; River250px502..751; center626.5 unchanged.
- Sources/candidates:16 each,1254² native. Exactly16 generation requests/calls.
- Five production-anchor hashes match unchanged originals; no candidate promoted.
- Before/after both branch switches:all496 art/example files preserved.
- Final preservation audit:493 original files unchanged; three intended art
  docs/metadata updates backed up against premerge hashes. No original PNG changed.
- Credential-pattern audit:289 art text files,no matches.
- No final PNGs. No gameplay-path diff against main.
- Review build:94 native seamPNG,16 manifests,236 exact tile placements,
  142 declared matching seams,16 debugPNG,8 comparisonPNG+8 JSON records.
- Native seam/source/mask hashes and every saved placed tile pixel checked by
  review utility and independent post-build audit; no interpolation.

Git checkpoints:5b1127d baseline,7eed88f anchors,becb295 hybrid tooling. All pushed
on alpha-art. Final assets/docs are the commit containing this evidence file.
Timestamped backups,Python caches and regenerable import metadata stay local/ignored.
This is a review delivery,not final-asset acceptance. Three designs have neither
visual recommendation; see candidate_reviews.json and TRIAL_REPORT.md.

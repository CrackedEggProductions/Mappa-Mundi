# Trial 01 — verification evidence

2026-09-24. Verification command exited 0 after all assertions passed.

- PASS: 6 native 1254x1254 candidates match tool originals byte-for-byte; 6 requests and 24 reference attachments match manifest hashes.
- PASS: 18 seam sheets; 102 placed tiles retain every pixel after exact quarter-turn rotation, with no gaps or resampling.
- PASS: 2 comparison sheets retain all 12 source-image placements unchanged; labels lie outside asset pixels.
- PASS: 15 originals and 21 reference copies retain their recorded SHA-256 hashes.
- PASS: 3 art-tool Python files parse; art-tool suite separately ran 6 tests, all passed.
- PASS: exactly two candidate families / six PNGs; all six await human review; zero approved PNGs.
- PASS: 277 local Markdown link targets resolve (verification report created by this check).
- PASS: tracked and staged diffs empty; branch phase-6 unchanged. Gameplay tests not rerun for this art-only task.

Git status:

```text
?? art/
?? "assets/Example Tiles/"
```

Visual acceptance remains separate: all six candidates FAIL exact edge coverage.
No production approval is inferred from these infrastructure checks.

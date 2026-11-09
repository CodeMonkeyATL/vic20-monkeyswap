# MonkeySwap todo

Known issues and ideas. Nothing here is scheduled; the user picks what's worth doing.

## Other repos

- **vic20-launcher:** its cassette buffer table (`docs/design.md`, "The cassette buffer") should reserve 919-1019 as "free for a game's own use, not kept across loads". MonkeySwap keeps its board (919-982) and match list (983-1019) there (2026-11-08). Do it when work is next in that repo.

## Later

- Special pieces: match 4 clears a row or column, an L or T shape clears a 3x3 area, match 5 clears one color. A reversed glyph could mark one.
- Custom fruit characters, as memory allows (see "Pieces" in `design.md`).
- A difficulty (piece types 5/6/7, fewer moves), as extra leaderboard variants.
- The cursor move erases 8 cells and draws 8; erasing only the 5 that don't overlap the new box saves 3 pokes. Only if the plain version measures slow.

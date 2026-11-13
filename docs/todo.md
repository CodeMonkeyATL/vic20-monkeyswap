# MonkeySwap todo

Known issues and ideas. Nothing here is scheduled; the user picks what's worth doing.

## Other repos

- **leaderboard-service:** register MonkeySwap as game 2 (`games`: name MONKEYSWAP, repo `vic20-monkeyswap`, prg `monkeyswap`; `variants`: code 2, label ENDLESS; `game_fields`: PTS, number). The game already writes its result as game 2, variant 2. Also the launcher's mock list (`vic20-launcher/mock/games`) for xvic tests.

- **vic20-launcher:** its cassette buffer table (`docs/design.md`, "The cassette buffer") should reserve 919-1019 as "free for a game's own use, not kept across loads". MonkeySwap keeps its board (919-982) and match list (983-1019) there (2026-11-08). Do it when work is next in that repo.

## Next

- **Show when keys aren't taken (the user, 2026-11-12):** a keypress sometimes does nothing, or takes a second or two, and nothing says the game is busy. Wanted: a simple, cheap cue. Since the third tightening pass the cursor box is gone during a swap's cascade, which covers the time keys are dropped; judge in play whether that's enough. The other wait is a no-moves trial after 2 s idle (5005): a key pressed then isn't lost, but waits for the trial to finish, with only the spinner showing.

## Later

- **Sounds:** a lift for the swap (as RingSort's), a merge sound rising with each cascade round (as 2up11's), a game-over tone. Probably no memory left on an unexpanded VIC.
- **Title and attribution** on screen, if memory allows (the README has them).
- **A faster no-moves check:** the pattern version (pairs and gaps) took 510 bytes; only with more memory.

- Special pieces: match 4 clears a row or column, an L or T shape clears a 3x3 area, match 5 clears one color. A reversed glyph could mark one.
- Custom fruit characters, as memory allows (see "Pieces" in `design.md`).
- A difficulty (piece types 5/6/7, fewer moves), as extra leaderboard variants.
- The cursor move erases 8 cells and draws 8; erasing only the 5 that don't overlap the new box saves 3 pokes. Only if the plain version measures slow.

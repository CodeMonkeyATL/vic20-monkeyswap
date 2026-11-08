# MonkeySwap design notes

How `src/monkeyswap.bas` works. Once the source is tightened it has no comments (they cost too much memory on an unexpanded VIC-20), so this file is where the explanations live. Update it whenever the code changes.

## Decisions so far

What has been decided before the code exists (2026-11-07/08; the discussion started in `meta/ideas.md`, "Leaderboard titles"). Sections below take over each part as it gets built.

### Styles

Two styles from shared code (board, swap, match scan, gravity); only the rules around them differ:

| | Style 1: levels (Candy Crush-like) | Style 2: endless (Bejeweled-like) |
|---|---|---|
| A game | One level: reach a score target in N moves | Play until no swap is left |
| Levels | Pass one to unlock the next; each level's board and refills come from a seed, the target and move limit from a formula on the level number (no stored level data) | The level rises with the score, on the same board |
| Ends when | Moves run out (pass or fail) | No possible swap is left |
| Extra code | Target, move counter, level select | The "any move left?" check: look for the patterns one swap away from a match, once a move's cascades have settled |

No special pieces (line clearers, bombs) in the first version; add them once the core works and is measured. No difficulty to start with.

**Build order (decided 2026-11-08): core, then endless, then levels.**

1. **The shared core:** the board without initial runs, the cursor, the swap with its animation, the match scan, clearing, gravity, refills, cascades, the score. Playable but endless with no end.
2. **Endless (style 2) to completion:** the rising level and game over when no swap is left, plus the result for the launcher. Its "any move left?" check also serves levels (reshuffling a stuck board).
3. **Levels (style 1) on top:** move counter, score target, level number and seed, pass/fail, next level.

Building one style first risks leaving no memory for the other, so: measure `fre(0)` after every step, estimate what levels needs once the core is done and keep that much free, and keep the style in a variable from the start wherever the code differs.

**Initial runs:** the fill (1000) avoids them; the draw (1100) only shows `b%()` and never changes it. The board is the game state, and the screen shows it, so redraws, the match scan and seeded levels all see the same board.

**L, T and + shapes** aren't shapes of their own: a horizontal run of 3+ and a vertical run of 3+ that share a piece (at least 5 pieces, 3 wide and 3 tall). The match scan marks every piece in any run of 3+ and clears all marked pieces together, which handles crossing runs without shape detection. A special piece for these later only needs to test "marked by both a horizontal and a vertical run".

### Leaderboard

Fields `LVL` then `PTS`. One registered game, with the style as the variant: 1 = levels, 2 = endless. A difficulty can come later as more variant codes. Still needed elsewhere:

- **leaderboard-service:** it ranks by the first field and breaks ties by the time posted (`StoreSql.cs`, `ORDER BY f1 DESC, created, id`); it needs `f2 DESC` after `f1`.
- **vic20-launcher:** its board view shows only a game's first variant; it needs a way to pick one (the same open item as RingSort's sizes).

### Pieces

ROM (PETSCII) glyphs to start, to keep memory low: six distinct glyphs (♠ 97, ♥ 115, ♣ 120, ♦ 122, ● 113, and one more such as ○ 119), each in its own color. On black, white, yellow, cyan, green and red show up well; purple and blue are hard to see (seen in xvic, 2026-11-08), so the six colors still need picking on a real board. No fruit theme until there are custom characters.

**Custom characters later, as memory allows:** hi-res (colors 0-7 only), and only then the fruit: banana yellow, cherry or apple red, grapes purple, lime (whole or slice) green, blueberry blue, coconut cyan. Placed at codes 57-63 (6 pieces plus a cursor) with the top of BASIC at 7624, about 56 bytes. With `poke36869,255`, codes 128-255 show the normal ROM glyphs, so text is printed `{reverse on}`; the screen is cleared with reversed spaces, since `{clr}` fills it with code 32, whose glyph would then be random RAM (`meta/src/chartest.bas` verified the layout).

### Controls

| Key | Action |
|---|---|
| `w` `a` `s` `d` | move the cursor (it stops at the board's edges) |
| Shift + `w` `a` `s` `d` | swap the piece under the cursor with its neighbour in that direction |

- One keypress per swap; there's no "pick up" state. `get` returns a shifted letter as 128 + the plain letter (Shift+W = 215, W = 87; to verify in xvic), so `and127` gives the plain letter and both share one direction decode.
- With Shift Lock down, every WASD press swaps. "How to play" mentions it; no code for it.
- After a swap, the cursor stays on the cell the piece moved to.
- Keys typed while a move plays out are dropped: the keyboard buffer is emptied (`poke198,0`) once the board settles after every swap.

### Cursor and swap animation

The cursor is a rounded box in the gap cells around the piece: `╭ ╮ ╰ ╯` (117, 105, 106, 107) joined by `─` (96) and `│` (125), in white. These lines run through the middle of the gap cells, halfway between the piece and its neighbours (compared in xvic 2026-11-08 against an outer square, a tight box that came out as a `#`, brackets and a middle-line square).

A swap animates with the box:

1. **Grow** the box over both pieces (3x3 cells becomes 5x3 for left/right, 3x5 for up/down).
2. **Swap** the two pieces inside it.
3. **Shrink** the box to 3x3 around the piece's new position.
4. Then matches, removals and cascades.

A swap that makes no match: grow, swap, a short pause, swap back, shrink back to where it started, with a "nope" sound. It doesn't cost a move.

So the cursor is one routine: draw a box at a screen position, w by h cells (3x3, 5x3 or 3x5), and the same with spaces to erase it. The gap cells never hold a piece, so their color RAM is set to white once when the board is drawn, and the box only pokes screen RAM.

## The game

Rules, modes and scoring, as the program implements them.

## Screen layout

The screen is 22×23 characters; screen RAM starts at 7680 and color RAM at 38400. Black background.

The board is 8x8 pieces at a 2x2 pitch: one character per piece, with a gap column and a gap row between pieces. Including the cursor's outer edges that's 17 columns by 17 rows, which leaves room for the score and moves above.

| Rows | Columns | What |
|---|---|---|
| 3-19 | 2-18 | the board, with the cursor's room around it |
| 4, 6, … 18 | 3, 5, … 17 | the pieces: board row r is screen row 4+2r, board column c is screen column 3+2c |

Rows 0-2 and 20-22 are free for the score, moves and messages.

The top-left piece is at screen address 7680 + 4×22 + 3 = 7771 (`ba`). Each board row down adds 2 screen rows (44 bytes), each column right adds 2 bytes, so piece (r, c) is at `ba+r*44+c*2`. Its color RAM is 30720 higher (`co`; 38400 − 7680).

## Data model

- `b%(63)`: the board, one element per cell, holding the piece type 0-5. Cell i is board row `int(i/8)`, column `iand7`; so i = r×8 + c. An integer array: 2 bytes per element instead of 5.
- `pg%(5)`, `pc%(5)`: each piece type's screen code (for `poke`) and color, read from `data` at init:

| Type | Glyph | Screen code (PETSCII) | Color |
|---|---|---|---|
| 0 | ♠ | 65 (97) | 7 yellow |
| 1 | ♥ | 83 (115) | 2 red |
| 2 | ♣ | 88 (120) | 5 green |
| 3 | ♦ | 90 (122) | 3 cyan |
| 4 | ● | 81 (113) | 4 purple |
| 5 | ○ | 87 (119) | 1 white |

Screen codes, not PETSCII: a `poke` into screen RAM takes the screen code, and graphics glyphs 96-127 are screen codes 64-95. Purple goes on the filled ball, which has the most pixels, and white on the hollow circle; both were the hardest to see on black (2026-11-08). The colors are a first pick, to judge on the real board.

## Routines

| Lines | Routine |
|---|---|
| 100 | init: empty the keyboard buffer, black screen, seed `rnd`, read the piece table, clear the screen, fill and draw the board |
| 300 | wait for a key (after emptying the buffer), then end |
| 1000 | fill the board with random pieces 0-5 (matches allowed for now) |
| 1100 | draw the board by poking screen and color RAM |

## Variables

| Name | Meaning |
|---|---|
| `b%()` | the board (see "Data model") |
| `pg%()`, `pc%()` | piece glyph (screen code) and color, by type |
| `ba` | screen address of the top-left piece (7771) |
| `co` | color RAM offset from screen RAM (30720) |
| `i` | loop counter |
| `p` | a piece's screen address while drawing |
| `t` | throwaway result (`rnd(-ti)` seeding) |
| `a$` | last key from `get` |

## Sound

Each sound's register and values, for tuning by ear.

## Memory

Free memory measured with `?fre(0)` after quitting, with the date and what changed.

| Date | Free | After |
|---|---|---|
| 2026-11-08 | 2438 | the board: random fill and draw, with `rem`s (PRG 931 bytes) |

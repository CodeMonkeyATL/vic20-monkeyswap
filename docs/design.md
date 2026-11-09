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

**Initial runs:** the fill (1000) avoids them; the draw (1100) only shows the board and never changes it. The board is the game state, and the screen shows it, so redraws, the match scan and seeded levels all see the same board.

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

- One keypress per swap; there's no "pick up" state. `get` returns a shifted letter as 128 + the plain letter (Shift+W = 215, W = 87; tested in xvic by typing those codes into the keyboard buffer, a real Shift press still to try), so `and127` gives the plain letter and both share one direction decode.
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

**The board area is white in color RAM.** At init, `{wht}` and 17 printed rows of 19 spaces (rows 3-19, columns 0-18) set it: `print` writes the current color into every cell it prints, spaces included, while `{clr}` leaves color RAM alone (both checked in xvic, 2026-11-08). The pieces are then poked over it in their own colors, and the cursor box, which lives in the gap cells, only pokes screen RAM.

## Data model

- **The board: 64 bytes in the cassette buffer at 919-982** (`bb`=919), one byte per cell: cell i is `peek(bb+i)`, set with `pokebb+i,…`. Cell i is board row `int(i/8)`, column `iand7`; so i = r×8 + c. **Bit layout:** bits 0-2 hold the piece type (`and7`), bit 3 (+8) is the match mark (`>7` means marked; `or8` marks). A mark only exists between a check and the clearing; the board holds none between moves. It moved out of an integer array `b%(63)` (2026-11-08): an array element always takes 2 bytes, and the array cost 135 bytes of BASIC memory; the buffer costs none.
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

- **The match list: up to 37 bytes in the cassette buffer at 983-1019** (`bm`=983): the cells marked in the current round, `mn` long, each a cell number 0-63. The mark bit keeps a cell from being listed twice (crossing runs share a cell). A cross of two five-runs is 9 cells. Moved out of `mk%(35)` with the board.
- **Why the cassette buffer is safe:** 828-1019 is RAM only tape I/O uses, and a disk `LOAD` leaves it alone. The CodeMonkeyATL launcher's contract (`vic20-launcher/docs/design.md`, "The cassette buffer") uses 828-918: player and launcher location (read at start and by `l`/quit) and the result (written at game over). 919-1019 is unused there, so the board and list don't touch it, and the board isn't needed after game over anyway. The contract doesn't reserve 919-1019 yet (see `todo.md`).
- `kg%(1,5)`: the box glyphs, as screen codes. Row 1 draws: `╭` 85, `╮` 73, `╰` 74, `╯` 75, `─` 64, `│` 93 (PETSCII 117, 105, 106, 107, 96, 125). Row 0 is all spaces (32) and erases. The box routine pokes `kg%(km,…)`, so the mode `km` picks the row and one routine both draws and erases.
- The cursor is kept as a board row and column (`cr`, `cc`, 0-7), not as a screen address: the edge checks and the swap need the row and column, and the address is computed from them.

## Finding matches

Only cells that just changed are checked, never the whole board: a full scan took 166 jiffies (2.8 s); a check around one cell takes about 10-27 (2026-11-08).

**Why the windows around each changed cell find every run, whole:** the board holds no run of 3 between moves. After a swap, every new run contains a moved piece, and at most 2 matching pieces sit on either side of it (3 would have been a run before), so the 3 windows across and 3 down that contain the piece cover the whole run, five-wide included. After gravity and refills (later steps), a run can be longer and mix changed and unchanged pieces, but unchanged pieces still can't have 3 in a row among themselves, so every unchanged piece in a run is within 2 cells of a changed one: checking around every changed cell covers every cell of every run. Overlapping windows mark a cell once (the mark bit).

**Changed cells aren't stored:** a swap has exactly two (`x`, `y`); gravity will have known ranges per column (every cell from the top down to the lowest cleared one). Only the matched cells are a list (the match list at `bm`).

## Routines

| Lines | Routine |
|---|---|
| 100 | init: empty the keyboard buffer, black screen, seed `rnd`, read the piece and box tables, clear the screen and make the board area white, fill and draw the board, put the cursor at row 3, column 3 |
| 300 | play: show the cursor, empty the buffer (autostart's stray `z` and keys typed during setup, which arrive after the `poke198,0` at 110), then wait for keys. `w`/`a`/`s`/`d` move the cursor one cell (erase, move, draw); the new row and column use comparisons as numbers (−1 when true): `r=cr-(a$="s"andcr<7)+(a$="w"andcr>0)`, so at an edge nothing changes and nothing is redrawn. With Shift held (`sw`, set when `asc(a$)>127`; `and127` turns the key back into the plain letter), the same direction swaps instead (2200), and the buffer is emptied afterwards (back to 330). Any other key ends the program (for now). Typed-ahead moves are kept, so quick taps all count. |
| 1000 | fill the board with random pieces 0-5, without runs of three: a piece (`t`) that would make three with the two cells to its left (from column 2) or the two above (from row 2) is drawn again. Nested `if`s guard the edges, since `and` doesn't short-circuit and `bb+i-2` would read the previous row (or before the board). |
| 1100 | draw the board: 1200 for each of the 64 cells |
| 1200 | draw cell `i` by poking screen and color RAM: the cell's byte in `w` (`peek(bb+i)`), then glyph `pg%(wand7)` (+128, reversed, when marked) and color `pc%(wand7)` at `ba+int(i/8)*44+(iand7)*2` |
| 2000 | draw (`km=1`) or erase (`km=0`) a rounded box with its top-left corner at `ka`, `kw` by `kh` cells: four corners, then the top and bottom lines, then the sides one screen row (22) at a time |
| 2100 | the cursor: set up a 3x3 box around the piece at `cr`, `cc` (top-left one row up and one column left: −23) and call 2000 |
| 2200 | swap the piece at `cr`,`cc` with its neighbour at `r`,`c`: erase the cursor; grow the box over both cells (its top-left is the cell with the smaller index `m`, which is the upper or left one; `kw=3-2*(r=cr)` makes it 5 wide for a swap in the same row, `kh` likewise 5 high for one in the same column); pause; swap the two cells' bytes through `t` (2400) and redraw both cells; pause; erase the grown box; draw the cursor at the new spot. After the swap, 3000 checks around both cells (`x`, `y`); with no match (`mn=0`) the pieces swap back and the cursor stays. With a match, the marked cells show reversed (3200). |
| 2400 | swap the values of cells `x` and `y` through `t` and redraw both |
| 2900 | pause `n` jiffies (1/60 s), using `ti`, so the speed doesn't depend on what else runs |
| 3000 | check the windows around cell `i`: across, the windows starting at columns `lo`-`hi` (2 left of `i`'s column to its column, kept within 0-5); down, likewise for rows. A window of three equal types (`and7`) goes to 3100. |
| 3100 | mark the window at addresses `s`, `s+j`, `s+2j` (`j` 1 across, 8 down): each cell not yet marked gets `or8` and goes on the match list (as `q-bb`, its cell number) |
| 3200 | temporary, until clearing exists: show the listed cells reversed, pause 30 jiffies, unmark them and redraw |

## Variables

| Name | Meaning |
|---|---|
| `bb`, `bm` | addresses of the board (919) and the match list (983) in the cassette buffer |
| `w` | the cell's byte while drawing (1200) |
| `pg%()`, `pc%()` | piece glyph (screen code) and color, by type |
| `ba` | screen address of the top-left piece (7771) |
| `co` | color RAM offset from screen RAM (30720) |
| `kg%()` | box glyphs: row 0 erases, row 1 draws |
| `ka`, `kw`, `kh`, `km` | box: top-left screen address, width, height (cells), mode (1 draw, 0 erase) |
| `cr`, `cc` | cursor: board row and column, 0-7 |
| `r`, `c` | the cursor's new row and column while moving, and the neighbour while swapping |
| `sw` | the key was shifted: −1 swap, 0 move |
| `x`, `y` | the two cells' indexes (0-63) while swapping |
| `m` | the smaller of `x` and `y`: the grown box's top-left cell |
| `n` | pause length in jiffies (5 for each swap pause, about 1/12 s; tuned by eye 2026-11-08, first tried 10) |
| `mn` | the match list's length |
| `u`, `v` | column and row of cell `i`, inside 3000 (not `c`/`r`, which the swap still needs) |
| `lo`, `hi` | first and last window start, inside 3000 |
| `s` | a window's first cell, as a buffer address (`bb+…`, saving an addition per `peek`); `j` its step (1 across, 8 down) |
| `k`, `q` | loop counter and cell inside 3100 and 3200 |
| `e` | the box's bottom-left screen address, inside 2000 |
| `i` | loop counter (board loops) |
| `j` | loop counter (init and the box, so the box can run inside an `i` loop later) |
| `p` | a piece's screen address while drawing |
| `t` | the piece being tried while filling; also a throwaway result (`rnd(-ti)` seeding) |
| `a$` | last key from `get` |

## Sound

Each sound's register and values, for tuning by ear.

## Memory

Free memory measured with `?fre(0)` after quitting, with the date and what changed.

| Date | Free | After |
|---|---|---|
| 2026-11-08 | 2438 | the board: random fill and draw, with `rem`s (PRG 931 bytes) |
| 2026-11-08 | 2210 | fill without initial runs, with `rem`s (PRG 1159 bytes) |
| 2026-11-08 | 515 | the cursor: box routine and WASD moves, with long `rem`s (PRG 2751 bytes; 1014 without the 30 `rem` lines, so the comments took 1737) |
| 2026-11-08 | 2022 | the same, with one short `rem` per routine (PRG 1244 bytes); explanations live here instead |
| 2026-11-08 | 1524 | the swap animation, every swap allowed (PRG 1707 bytes) |
| 2026-11-08 | 635 | the match check around swapped cells, swap back without a match (PRG 2461 bytes; the 16 `rem`s take 527 of it) |
| 2026-11-08 | 1176 | the same, built without `rem`s (`strip-rems.ps1`, from `template`): PRG 1934 bytes. From here on, measured after one swap, so the swap's variables exist. |
| 2026-11-08 | 1331 | the board and match list in the cassette buffer instead of `b%()`/`mk%()`, after a swap (PRG 1958 bytes) |

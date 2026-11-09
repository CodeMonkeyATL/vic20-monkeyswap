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

**Fields: `PTS` only (changed 2026-11-08).** The level was a step function of the score (one per 500 points), so ranking by level then points is the same as ranking by points; the service or the board view can show a level computed from `PTS` if wanted. One registered game, with the style as the variant: 1 = levels, 2 = endless. A difficulty can come later as more variant codes. Still needed elsewhere:

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

**Scoring:** each cascade round counts (`rd`: 1 for the swap's own match, 2 for the first cascade, …), and a round scores 10 × the pieces cleared × `rd`, so chains pay more. No level display (memory); a level is a step function of the score, which the leaderboard can compute.

**Game over:** when no swap on the board would make a run. The result is written for the launcher at once (5700); then any key starts a new game. While the player is idle for 2 s, each pass of the key loop tries one swap (5000): swap the two bytes, run the match check in test mode (it reports a run instead of marking it), swap back. `hc` counts the 128 trials; trial `(hc+ho)and127` is tested (cell × 2 + direction: right, down), where `ho` is a random start chosen for each new board, so the search wraps around and still covers every swap. The first one that works ends the search (`hm`). **The random start keeps the spinner from giving the move away** (the user's observation, 2026-11-08): with a fixed order, counting spinner steps until it stops told the player which cell had the move. A spinner on row 21 turns while trials run and disappears on a key or a found move. Only a swap that changed the board restarts the search, so a player trying swaps on a dead board still reaches game over, after about a minute of trials. A pattern check (pairs and gaps) would be much faster but took 510 bytes against about 235 for this; with 4 bytes left, the trial version won (2026-11-08).

## Screen layout

The screen is 22×23 characters; screen RAM starts at 7680 and color RAM at 38400. Black background.

The board is 8x8 pieces at a 2x2 pitch: one character per piece, with a gap column and a gap row between pieces. Including the cursor's outer edges that's 17 columns by 17 rows, which leaves room for the score and moves above.

| Rows | Columns | What |
|---|---|---|
| 3-19 | 2-18 | the board, with the cursor's room around it |
| 4, 6, … 18 | 3, 5, … 17 | the pieces: board row r is screen row 4+2r, board column c is screen column 3+2c |

Row 1 shows the score (yellow, from column 1; no label, for memory). Row 21, column 10 (8152, `sx`) holds the spinner, which turns while the idle check runs and while pieces fall; row 21 shows GAME OVER. Rows 0, 2, 20 and 22 are free.

The top-left piece is at screen address 7680 + 4×22 + 3 = 7771 (`ba`). Each board row down adds 2 screen rows (44 bytes), each column right adds 2 bytes, so piece (r, c) is at `ba+r*44+c*2`. Its color RAM is 30720 higher (`co`; 38400 − 7680).

**The board area is white in color RAM.** At init, `{wht}` and 17 printed rows of 19 spaces (rows 3-19, columns 0-18) set it: `print` writes the current color into every cell it prints, spaces included, while `{clr}` leaves color RAM alone (both checked in xvic, 2026-11-08). The pieces are then poked over it in their own colors, and the cursor box, which lives in the gap cells, only pokes screen RAM.

## Data model

- **The board: 64 bytes in the cassette buffer at 919-982** (`bb`=919), one byte per cell: cell i is `peek(bb+i)`, set with `pokebb+i,…`. Cell i is board row `int(i/8)`, column `iand7`; so i = r×8 + c. **Bit layout:** bits 0-2 hold the piece type (`and7`), bit 3 (+8) is the match mark (`>7` means marked; `or8` marks). A mark only exists between a check and the clearing; the board holds none between moves. It moved out of an integer array `b%(63)` (2026-11-08): an array element always takes 2 bytes, and the array cost 135 bytes of BASIC memory; the buffer costs none.
- `pg%(6)`, `pc%(6)`: each piece type's screen code (for `poke`) and color, read from `data` at init. Type 6 is an **empty cell**: a space, so the draw routine shows a cleared cell with no special case.

| Type | Glyph | Screen code (PETSCII) | Color |
|---|---|---|---|
| 0 | ♠ | 65 (97) | 7 yellow |
| 1 | ♥ | 83 (115) | 2 red |
| 2 | ♣ | 88 (120) | 5 green |
| 3 | ♦ | 90 (122) | 3 cyan |
| 4 | ● | 81 (113) | 4 purple |
| 5 | ○ | 87 (119) | 1 white |
| 6 | empty | 32 (space) | 1 white |

Screen codes, not PETSCII: a `poke` into screen RAM takes the screen code, and graphics glyphs 96-127 are screen codes 64-95. Purple goes on the filled ball, which has the most pixels, and white on the hollow circle; both were the hardest to see on black (2026-11-08). The colors are a first pick, to judge on the real board.

- **The match list: up to 29 bytes in the cassette buffer at 983-1011** (`bm`=983): the cells marked in the current round, `mn` long, each a cell number 0-63. The mark bit keeps a cell from being listed twice (crossing runs share a cell). A cross of two five-runs is 9 cells. Moved out of `mk%(35)` with the board.
- **The hole bytes: 8 bytes at 1012-1019** (`bh`), one per column, filled from the match list before gravity: **128** (the column changed) + **holes left × 8** + **the lowest hole's row** (0-7). Gravity counts the holes down to 0; the 128 and the row stay, so the cascade check (step 9) knows that every cell from row 0 down to that row changed. 0 means the column had no hole.
- **Why the cassette buffer is safe:** 828-1019 is RAM only tape I/O uses, and a disk `LOAD` leaves it alone. The CodeMonkeyATL launcher's contract (`vic20-launcher/docs/design.md`, "The cassette buffer") uses 828-918: player and launcher location (read at start and by `l`/quit) and the result (written at game over). 919-1019 is unused there, so the board and list don't touch it, and the board isn't needed after game over anyway. The contract doesn't reserve 919-1019 yet (see `todo.md`).
- `kg%(1,5)`: the box glyphs, as screen codes. Row 1 draws: `╭` 85, `╮` 73, `╰` 74, `╯` 75, `─` 64, `│` 93 (PETSCII 117, 105, 106, 107, 96, 125). Row 0 is all spaces (32) and erases. The box routine pokes `kg%(km,…)`, so the mode `km` picks the row and one routine both draws and erases.
- The cursor is kept as a board row and column (`cr`, `cc`, 0-7), not as a screen address: the edge checks and the swap need the row and column, and the address is computed from them.

## Finding matches

Only cells that just changed are checked, never the whole board: a full scan took 166 jiffies (2.8 s); a check around one cell takes about 10-27 (2026-11-08).

**Why the windows around each changed cell find every run, whole:** the board holds no run of 3 between moves. After a swap, every new run contains a moved piece, and at most 2 matching pieces sit on either side of it (3 would have been a run before), so the 3 windows across and 3 down that contain the piece cover the whole run, five-wide included. After gravity and refills (later steps), a run can be longer and mix changed and unchanged pieces, but unchanged pieces still can't have 3 in a row among themselves, so every unchanged piece in a run is within 2 cells of a changed one: checking around every changed cell covers every cell of every run. Overlapping windows mark a cell once (the mark bit).

**Runs left by refills (step 8, found by the user) are gone since step 9:** a refill or a fall could form a run that stayed on the board, and a swap that extended it only cleared the part within 2 cells of the moved piece (♦ ♦ ♦ left in rows 0-2 of column 0, a ♦ swapped into row 3, only rows 1-3 cleared). The cascade loop now clears every run before the next move, so the assumption above holds again. Tested 2026-11-08: two runs of 24 random keys left 0 runs on the board.

**Changed cells aren't stored:** a swap has exactly two (`x`, `y`); after gravity, every cell from the top of a column down to its lowest hole has changed, and the hole bytes (`bh`) record that row per column. Only the matched cells are a list (the match list at `bm`).

## Routines
The source is tightened (2026-11-08): statements are joined onto as few lines as the rules allow (a jump target starts its line, nothing follows an `if` or a `goto`/`return`, 88 characters as stripped). Each line's `rem` sits at its end. Line numbers below are the routines' first lines.

| Lines | Routine |
|---|---|
| 100 | init: empty the keyboard buffer, black screen, seed `rnd`, read the piece and box tables, clear the screen and make the board area white, fill and draw the board, set the random start for the no-moves check (`ho`) and the spinner's place (`sx`), show the score (250), put the cursor at row 3, column 3 |
| 300 | play: show the cursor, empty the buffer (autostart's stray `z` and keys typed during setup, which arrive after the `poke198,0` at the start of init), then wait for keys. `w`/`a`/`s`/`d` move the cursor one cell (erase, move, draw); the new row and column use comparisons as numbers (−1 when true): `r=cr-(a$="s"andcr<7)+(a$="w"andcr>0)`, so at an edge nothing changes and nothing is redrawn. With Shift held (`sw`, set when `asc(a$)>127`; `and127` turns the key back into the plain letter), the same direction swaps instead (2200), and the buffer is emptied afterwards (back to 330). `q` twice in a row quits (345: the previous key is kept in `p$`); every other key is ignored. A key also erases the spinner and restarts the 2-second idle timer (`kt`). While no key is waiting, 5000 runs one trial of the no-moves check. Typed-ahead moves are kept, so quick taps all count. |
| 1000 | fill the board with random pieces 0-5, without runs of three: a piece (`t`) that would make three with the two cells to its left (from column 2) or the two above (from row 2) is drawn again. Nested `if`s guard the edges, since `and` doesn't short-circuit and `bb+i-2` would read the previous row (or before the board). |
| 1100 | draw the board: 1200 for each of the 64 cells |
| 1200 | draw cell `i` by poking screen and color RAM: the cell's byte in `w` (`peek(bb+i)`), then glyph `pg%(wand7)` (+128, reversed, when marked) and color `pc%(wand7)` at `ba+int(i/8)*44+(iand7)*2` |
| 2000 | draw (`km=1`) or erase (`km=0`) a rounded box with its top-left corner at `ka`, `kw` by `kh` cells: four corners, then the top and bottom lines, then the sides one screen row (22) at a time |
| 2100 | the cursor: set up a 3x3 box around the piece at `cr`, `cc` (top-left one row up and one column left: −23) and call 2000 |
| 2200 | swap the piece at `cr`,`cc` with its neighbour at `r`,`c`: erase the cursor; grow the box over both cells (its top-left is the cell with the smaller index `m`, which is the upper or left one; `kw=3-2*(r=cr)` makes it 5 wide for a swap in the same row, `kh` likewise 5 high for one in the same column); pause; swap the two cells' bytes through `t` (2400) and redraw both cells; pause; erase the grown box; draw the cursor at the new spot. After the swap, 3000 checks around both cells (`x`, `y`); with no match (`mn=0`) the pieces swap back and the cursor stays. With a match, the cascade (3500) clears, lets the columns fall and refill, and repeats while new runs form. |
| 2400 | swap the values of cells `x` and `y` through `t` and redraw both; in a trial (`ht`), swap only, no drawing |
| 2900 | pause `n` jiffies (1/60 s), using `ti`, so the speed doesn't depend on what else runs |
| 3000 | check the windows around cell `i`: across, the windows starting at columns `lo`-`hi` (2 left of `i`'s column to its column, kept within 0-5); down, likewise for rows; each through 3150 |
| 3100 | in a trial (`ht`): just report a run (`fo=1`). Otherwise mark the window at addresses `s`, `s+j`, `s+2j` (`j` 1 across, 8 down): each cell not yet marked gets `or8` and goes on the match list (as `q-bb`, its cell number), while the list has room (29) |
| 3150 | one window at address `s` with step `j` (1 across, 8 down): three equal types (`and7`) go to 3100. Shared by the swap check and the cascade check. |
| 3200 | clear the matched cells: show them reversed (marked), pause 30 jiffies, then set each to 6 (empty) and redraw it as a space |
| 3300 | gravity: fill the hole bytes from the match list (count each column's holes, keep its lowest row), then run frames until no column moves, with a 3-jiffy pause and a spinner step between frames. Each frame runs 3400 for every column with holes left (`band120`, the count bits). |
| 3400 | one frame for column `g`: find its lowest hole, searching up from the stored row (contiguous holes keep their lowest hole in place, so this usually succeeds at once); move every piece above it down one row and put a new random piece in row 0, redrawing as it goes; one hole fewer. With the hole in row 0 there's nothing above to move, so 3440 jumps past the loop: **a BASIC V2 `for` loop always runs its body once**, and `forz=0to1step-1` would copy the byte below the board into row 0 and put the new piece outside the board, drawn above it and written into the launcher's result area (found by the user, 2026-11-08). The loop keeps the board address `a` and the screen address `p` and steps them by −8 and −44, instead of calling 1200 per cell (which recomputes the address). |
| 3500 | the cascade: count the round (`rd`) and add its score (`sc`, shown by 3800), clear (3200), fall (3300), then check every window touching a changed cell (3600 for each changed column, then across); if anything matched, again. Changed cells are rows 0 to the lowest hole in each column with bit 128 in its hole byte. |
| 3600 | one changed column `g`: widen the column range (`cl`-`ch`) and the deepest row (`lm`), then check its vertical windows starting at rows 0 to its lowest hole row (at most 5). The horizontal windows are checked afterwards in 3500, rows 0 to `lm`, from 2 columns left of `cl` to `ch` (within 0-5): checking each changed cell's own windows instead would test the same windows many times over. |
| 3800 | show the score on row 1 (the value only; the label is printed once at init) |
| 4100 | set the print position to row `ty`, column `tx` with the KERNAL's PLOT (`sys65520`, row in 781, column in 782, 783=0 to set); as RingSort's 1000 |
| 5000 | one trial of the no-moves check, after 2 s idle (`ti-kt>=120`) and until a move is found (`hm`): advance the spinner, pick cell `x` and neighbour `y` (right or down) from `(hc+ho)and127`, skip it if `y` is off the board, swap the bytes, check around both cells in test mode, swap back. Cell 63's last trial done with no move: game over (5500). |
| 5500 | game over: GAME OVER on row 21, write the result for the launcher (5700), then any key starts a new game (`run`) |
| 5540 | quit (`qq`): the VIC's normal colors, clear the screen, end. The game can be resumed from `READY.` (see "Resuming after a quit") |
| 5700 | the result for the launcher in the cassette buffer: 900 game 2, 901 check 253, 902 variant 2 (endless), 903 one field, 904-906 the score, low byte first |
| 5900 | one spinner step (`sp`), from the 4-character string `─ ╱ │ ╲` (PETSCII − 32 = screen code) |

## Variables

| Name | Meaning |
|---|---|
| `bb`, `bm`, `bh` | addresses of the board (919), the match list (983) and the hole bytes (1012) in the cassette buffer |
| `w` | a cell's byte while drawing (1200) or falling (3400); also, since no two of these overlap, the box's bottom-left address (2000), the grown box's top-left cell (2240), and a trial's direction (5020: 0 right, 1 down) |
| `pg%()`, `pc%()` | piece glyph (screen code) and color, by type |
| `ba` | screen address of the top-left piece (7771) |
| `co` | color RAM offset from screen RAM (30720) |
| `kg%()` | box glyphs: row 0 erases, row 1 draws |
| `ka`, `kw`, `kh`, `km` | box: top-left screen address, width, height (cells), mode (1 draw, 0 erase) |
| `cr`, `cc` | cursor: board row and column, 0-7 |
| `r`, `c` | the cursor's new row and column while moving, and the neighbour while swapping |
| `sw` | the key was shifted: −1 swap, 0 move |
| `x`, `y` | the two cells' indexes (0-63) while swapping, or in a trial |
| `n` | pause length in jiffies (5 for each swap pause, about 1/12 s; tuned by eye 2026-11-08, first tried 10) |
| `mn` | the match list's length |
| `u`, `v` | column and row of cell `i`, inside 3000 (not `c`/`r`, which the swap still needs) |
| `lo`, `hi` | first and last window start, inside 3000 |
| `s` | a window's first cell, as a buffer address (`bb+…`, saving an addition per `peek`); `j` its step (1 across, 8 down) |
| `k`, `q` | loop counter and cell inside 3100 and 3200; `q` is also a changed column's lowest hole row in 3600 (its `for` reads the limit once) |
| `g` | column, in gravity (3300, 3400) |
| `b` | the column's hole byte (see "Data model") |
| `f` | a frame moved something (1) or not (0) |
| `a`, `z` | in 3400: the board address of the cell being filled, and its row |
| `cl`, `ch`, `lm` | in the cascade: first and last changed column, deepest changed row |
| `r` | also the row loop in the cascade's horizontal check |
| `ty`, `tx` | print position for 4100: row and column |
| `sc` | the score |
| `hm`, `hc` | no-moves check: a move was found; trials done (0-127) |
| `ho` | the no-moves check's random start (0-127), new for each board |
| `ht`, `fo` | a trial is running (test mode); it found a run |
| `kt` | `ti` at the last key or swap (2-second idle timer) |
| `p$` | the previous key, for `qq` |
| `sx` | the spinner's screen address (8152) |
| `sp` | the spinner's step count |
| `rd` | the cascade round of the current move, from 1 (reset at 330, after every swap) |
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
| 2026-11-08 | 1330 | clearing: matched cells become empty (type 6) after the flash (PRG 1958 bytes) |
| 2026-11-08 | 861 | gravity and refills, falling a row per frame (PRG 2382 bytes) |
| 2026-11-08 | 621 | the cascade loop, and the row-0 fix (PRG 2657 bytes; measured after a swap that may not have matched, so about 28 less once the cascade's variables exist) |
| 2026-11-08 | 422 | keys: `q` with confirmation, other keys ignored, print-position routine (PRG 2842 bytes) |
| 2026-11-08 | 191 | score and level on row 1 (PRG 2996 bytes; measured after a matching move) |
| 2026-11-08 | ~440 | tightened: 134 lines joined into 79 (PRG 2776 bytes, 220 less); 468 measured before any match, about 28 less once the cascade's variables exist |
| 2026-11-08 | 4 | the pattern no-moves check (510 bytes; PRG 3303): too big, not kept |
| 2026-11-08 | ~215 | the trial no-moves check with a spinner, `qq` instead of the quit prompt, PTS without a level (PRG 2985; 243 measured before any match) |
| 2026-11-09 | 36 | the launcher result, spinner during falls, no hot-variable line, no score label, four variables reused (PRG ~3105). **Measured after 30 random keys of play**, so every variable exists; earlier rows were measured soon after a start and overstate what's left (the same build showed 120 after a start and 8 after play, before the reuse). This is the ceiling: adding anything means taking something out. |


## Resuming after a quit

After `qq`, everything the game needs is still in memory: the variables (score, cursor, the no-moves check's progress) and the board, which lives in the cassette buffer that `end` doesn't touch. Only the screen was cleared and the colors reset. At `READY.`:

```
print chr$(147):poke36879,8:p$="":gosub1100:gosub3800:goto300
```

| Part | Does |
|---|---|
| `print chr$(147)` | clears the screen (147 is the clear-screen code) |
| `poke36879,8` | the black screen and border again |
| `p$=""` | forgets the last `q`, which would otherwise make the next single `q` quit |
| `gosub1100` | redraws the board from the cassette buffer |
| `gosub3800` | reprints the score |
| `goto300` | draws the cursor and continues the play loop |

The cursor box comes out white without reprinting the board area: clearing the screen leaves color RAM alone, so the gap cells keep the white from the start. `run` or editing a program line clears the variables, after which only the board survives. Tested in xvic (2026-11-09): same board, cursor and score after resuming; a move works; a single `q` doesn't quit.

## Launcher

MonkeySwap works with the CodeMonkeyATL launcher (`vic20-launcher`) through the cassette buffer, as 2up11 does (the layout is in `vic20-launcher/docs/design.md`, "The cassette buffer"). At game over it writes its result at 900-906 (5700): game 2, check 253, variant 2 (endless), one field, the score in 3 bytes. **It doesn't load the launcher back** (decided 2026-11-09, for memory: the keyboard-buffer load as in 2up11 cost about 160 bytes): the player runs the launcher when they like, and it posts the waiting result (the contract's secondary path). A new game doesn't touch 900-918, so the result waits there until the launcher reads it; a later game over replaces it. Quitting mid-game (`qq`) posts nothing. Tested in xvic (2026-11-09): a game over with the score set to 12345 left `2 253 2 1 57 48 0`.

Still needed elsewhere: register game 2 (MonkeySwap, variant 2 ENDLESS, field PTS) in `leaderboard-service`'s seed, and add it to the launcher's game list (see `todo.md`).

**Start-up tried and dropped (2026-11-09):** a random fill that the cascade then "settles" saved about 60 bytes over the no-runs fill (1000), but took 15 s at a typical start and up to 90 s, so the no-runs fill stayed.

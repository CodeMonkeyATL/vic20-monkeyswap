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

**Initial runs:** the fill (200) avoids them; the draw (1200, cell by cell) only shows the board and never changes it. The board is the game state, and the screen shows it, so redraws, the match scan and seeded levels all see the same board.

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
| `q` `q` | quit; back to the launcher if it started the game |
| `h` | hint: the cursor moves onto a piece that has a working swap (right or down) |
| `l` (game over) | back to the launcher, if it started the game; otherwise any key plays again |

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

**Game over:** when no swap on the board would make a run. The result is written for the launcher at once (5600); then any key starts a new game (or `l` goes back to a launcher, see "Launcher"). While the player is idle for 2 s, each pass of the key loop tries one swap (5000): swap the two bytes, run the match check in test mode (it reports a run instead of marking it), swap back. `hc` counts the 128 trials; trial `(hc+ho)and127` is tested (cell × 2 + direction: right, down), where `ho` is a random start chosen for each new board, so the search wraps around and still covers every swap. The first one that works ends the search (`hc` holds its cell). **The random start keeps the spinner from giving the move away** (the user's observation, 2026-11-08): with a fixed order, counting spinner steps until it stops told the player which cell had the move. A spinner on row 21 turns while trials run and disappears on a key or a found move. Only a swap that changed the board restarts the search, so a player trying swaps on a dead board still reaches game over, after about a minute of trials. A pattern check (pairs and gaps) would be much faster but took 510 bytes against about 235 for this; with 4 bytes left, the trial version won (2026-11-08).

**Hint (2026-11-10): `h` moves the cursor onto a piece of a working swap.** Nothing shows by itself, so a player who likes to work it out isn't rushed (the user's call; a first version showed it after 7 s idle). The search already knows a move: when it finds one, it keeps the cell in `hc` as `-1-x` (−1 to −64), so `hc<0` still means "found" everywhere, and the cell survives a failed swap, which overwrites `x` (2200). That bug was in the first version: after a failed swap the hint pointed at the player's own swap. A separate variable would have cost 7 bytes more. `h` sets `hw` (347, `hw=(k=72)`, so every other key clears it), and 5000 moves the cursor once both are set: at once if the search is done, or as soon as it finds the move (the `h` counts as a key, so the search waits its 2 s first). The cursor box is the "box around the piece" for free, and the player can swap straight from there. It shows the piece, not the direction; since a trial is a cell with its right or lower neighbour, the hinted piece always moves right or down (and at one cell, right is tried first). No score penalty (decided 2026-11-10); scoring by cursor moves is an idea for a possible hard mode.

## Screen layout

The screen is 22×23 characters; screen RAM starts at 7680 and color RAM at 38400. Black background.

The board is 8x8 pieces at a 2x2 pitch: one character per piece, with a gap column and a gap row between pieces. Including the cursor's outer edges that's 17 columns by 17 rows, which leaves room for the score and moves above.

| Rows | Columns | What |
|---|---|---|
| 3-19 | 2-18 | the board, with the cursor's room around it |
| 4, 6, … 18 | 3, 5, … 17 | the pieces: board row r is screen row 4+2r, board column c is screen column 3+2c |

Row 1 shows the score (yellow, from column 1; no label, for memory). Row 21, column 10 (8152) holds the spinner, a ✱ that cycles white, cyan, green and yellow while the idle check runs and while pieces fall, and is black (hidden) otherwise; row 21 shows GAME OVER, and row 22 `LEADERBOARD` under it when a launcher started the game. Rows 0, 2 and 20 are free.

The top-left piece is at screen address 7680 + 4×22 + 3 = 7771. Each board row down adds 2 screen rows (44 bytes), each column right adds 2 bytes, so piece (r, c) is at `7771+r*44+c*2`. Its color RAM is 30720 higher (38400 − 7680).

**The whole screen is white in color RAM.** `{clr}` at init does it: on the VIC-20, clearing the screen also writes white (1) into every cell's color RAM. Checked in xvic 2026-11-10: color RAM filled with red by hand, then `run`, and the cursor box came out white. (An earlier note here said `{clr}` leaves color RAM alone, and init printed 17 rows of white spaces to set it; that test started from color RAM that was already white.) The pieces are then poked in their own colors, and the cursor box, which lives in the gap cells, only pokes screen RAM. The spinner's ✱ is poked into screen RAM once at init (110), and from then on only its color changes.

## Data model

- **The board: 64 bytes in the cassette buffer at 919-982** (`bb`=919), one byte per cell: cell i is `peek(bb+i)`, set with `pokebb+i,…`. Cell i is board row `int(i/8)`, column `iand7`; so i = r×8 + c. **Bit layout:** bits 0-2 hold the piece type (`and7`), bit 3 (+8) is the match mark (`>7` means marked; `or8` marks). A mark only exists between a check and the clearing; the board holds none between moves. It moved out of an integer array `b%(63)` (2026-11-08): an array element always takes 2 bytes, and the array cost 135 bytes of BASIC memory; the buffer costs none.
- `pg%(14)`: each piece type's screen code (for `poke`) at index 0-6 and its color at 8-14, read from `data` at init (index 7 is unused: the empty `data` item reads as 0). A cell's byte `w` is its type plus 8 when marked, so the glyph is `pg%(wand7)` and the color `pg%(wor8)`, marked or not. One array instead of two saves a header and a `dim`. Type 6 is an **empty cell**: a space, so the draw routine shows a cleared cell with no special case.

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

- **The match list: up to 29 bytes in the cassette buffer at 983-1011** (a literal in the code: a variable costs 7 bytes plus its assignment, more than the 1 byte saved at each of 3 uses): the cells marked in the current round, `mn` long, each a cell number 0-63. The mark bit keeps a cell from being listed twice (crossing runs share a cell). A cross of two five-runs is 9 cells. Moved out of `mk%(35)` with the board.
- **The hole bytes: 8 bytes at 1012-1019** (`bh`), one per column, filled from the match list before gravity: **128** (the column changed) + **holes left × 8** + **the lowest hole's row** (0-7). Gravity counts the holes down to 0; the 128 and the row stay, so the cascade check (step 9) knows that every cell from row 0 down to that row changed. 0 means the column had no hole.
- **Why the cassette buffer is safe:** 828-1019 is RAM only tape I/O uses, and a disk `LOAD` leaves it alone. The CodeMonkeyATL launcher's contract (`vic20-launcher/docs/design.md`, "The cassette buffer") uses 828-918: player and launcher location (read at start and by `l`/quit) and the result (written at game over). 919-1019 is unused there, so the board and list don't touch it, and the board isn't needed after game over anyway. The contract doesn't reserve 919-1019 yet (see `todo.md`).
- **The box glyphs are computed, not stored:** each `poke` in the box routine writes `32+km*n`, where `n` is the glyph's screen code minus 32: `╭` 85 (53), `╮` 73 (41), `╰` 74 (42), `╯` 75 (43), `─` 64 (32), `│` 93 (61). With `km=0` that's a space (erase), with `km=1` the glyph (draw). `32+km*53` is a byte shorter than the array reference `kg%(km,0)` it replaced, and the array, its `data` and its read loop are gone (about 100 bytes, 2026-11-10).
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
| 100 | init: the sound registers' base `z` (see "Sound"), black screen, volume 15 (for the sounds), seed `rnd`, clear the screen (which makes color RAM white), the spinner's ✱ (screen code 42) at 8152 in black; 180 sets the board address and reads the piece table. The statements are spread over the two lines so both fit in 88 characters (which is why `bh` is on 100 and `bb` on 180). |
| 200 | fill the board with random pieces 0-5, without runs of three, drawing each cell as it's placed (1200): a piece (`t`) that would make three with the two cells before it or the two above is drawn again. The cell's address is kept in `a`, and one `if` tests both pairs, `(…and…)or(…and…)`; the parentheses are for the reader. **There are no edge guards:** in columns 0-1 the "two before" are the end of the previous row, and in rows 0-1 the "two above" are bytes before the board (903-918, only read). A match there just rerolls a piece that didn't need it, which is harmless and saves the two guards. Then the random start for the no-moves check (`ho`), the score, the cursor's position (row 3, column 3), and the launcher's device (`e`). |
| 330 | play: show the cursor, empty the buffer (autostart's stray `z` and keys typed during setup), then wait for keys. **The cursor is drawn here and nowhere else in the swap** (2026-11-12): a swap comes back to 330, so the box is gone while a cascade plays and returns when the board accepts keys again. **That is the "busy" cue:** the user had asked for a sign that keys aren't taken, played this build, and found the missing cursor says it clearly enough; nothing more is needed (2026-11-12). The key becomes a number, `k=asc(a$)and127`, which drops the Shift bit so both forms share one decode. `w`/`a`/`s`/`d` (87, 65, 83, 68) move the cursor one cell (erase, move, draw, then the woosh on 450); the new row and column use comparisons as numbers (−1 when true): `r=cr-(k=83andcr<7)+(k=87andcr>0)`, so at an edge, or for any other key, nothing changes and 420 goes back to waiting (there's no separate "is it wasd" test). With Shift held (`asc(a$)>127`) the same direction swaps instead (2200), and the buffer is emptied afterwards (back to 330). `q` twice in a row quits (345: the previous key is kept in `l`). A key also erases the spinner and restarts the 2-second idle timer (`kt`). While no key is waiting, 5000 runs one trial of the no-moves check. Typed-ahead moves are kept, so quick taps all count.  `h` asks for a hint (345: `hw` is −1 for `h`, 0 for any other key). |
| 1200 | draw cell `i` by poking screen and color RAM: the cell's byte in `w` (`peek(bb+i)`), then glyph `pg%(wand7)` (+128, reversed, when marked) and color `pg%(wor8)` at `7771+i*2+int(i/8)*28`. That's row × 44 + column × 2 written with one `int`: `i` = 8r + c, so 2i + 28r = 44r + 2c. |
| 1980 | draw the cursor: `km=1`, then falls into 1990 |
| 1990 | the cursor box in mode `km`: a 3x3 box around the piece at `cr`, `cc` (its top-left is one row up and one column left of the piece: 7771 − 23 = 7748), then falls into 2000. Erase with `km=0:gosub1990`. |
| 2000 | draw (`km=1`) or erase (`km=0`) a rounded box with its top-left corner at `ka`. `kw` is the offset to its right edge (2 or 4) and `kh` the offset to its bottom row (44 or 88), so the corners are `ka`, `ka+kw`, `ka+kh` and `ka+kh+kw` with no arithmetic on cell counts. Four corners, then the top and bottom lines, then the sides one screen row (22) at a time; each loop's glyph is worked out once, into `t`. |
| 2200 | swap the piece at `cr`,`cc` with its neighbour at `r`,`c`: erase the cursor (the swap sounds play along: see "Sound") (which leaves `ka` at the cursor box's corner); grow the box over both cells: the corner moves 2 left for a swap to the left and 44 up for a swap upward (`ka=ka+2*(c<cc)+44*(r<cr)`, true being −1), and `kw=2-2*(r=cr)` makes it 4 wide for a swap in the same row, `kh` likewise 88 for one in the same column; pause; swap the two cells' bytes through `t` (2400) and redraw both cells; pause; check around both cells (2990); erase the grown box; set the cursor's new spot (330 draws it once the move is over). With no match (`mn=0`) the pieces swap back and the cursor stays. With a match, the cascade (3500) clears, lets the columns fall and refill, and repeats while new runs form. |
| 2400 | swap the values of cells `x` and `y` through `t` and redraw both; in a trial (`ht`), swap only, no drawing |
| 2900 | pause `n` jiffies (1/60 s), using `ti`, so the speed doesn't depend on what else runs |
| 2990 | check around both swapped cells: 3000 for `x`, then falls into 3000 for `y` |
| 3000 | check the windows through cell `i`: 3020 once across (`j=1`, `u` = the column) and once down (`j=8`, `u` = the row). 3020 tries the three windows that contain the cell, starting `u-2` to `u` along the line, and skips a start outside 0-5 (the window wouldn't fit). The window's address is `bb+i+(d-u)*j`. One loop serves both directions; the version before had a clamped loop for each. |
| 3100 | one window at address `s` with step `j` (1 across, 8 down): return unless its three types (`and7`) are equal. In a trial (`ht`): just report the run (`mn=1`). Otherwise mark the cells `s`, `s+j`, `s+2j`: each one not yet marked gets `or8` (written `8ort`, since `tor8` would tokenize as `TO`) and goes on the match list (as `q-bb`, its cell number), while the list has room (29). Shared by the swap check and the cascade check. |
| 3200 | flash the matched cells: show them reversed (marked), pause 30 jiffies; then falls into 3300 |
| 3300 | clear and fall. One pass over the match list sets each cell to 6 (empty), redraws it as a space, and fills the hole bytes (count each column's holes, keep its lowest row). Then frames run until every hole is filled, with a 3-jiffy pause and a spinner step between frames. Each frame runs 3420 for every column with holes left (`band120`, the count bits). **`mn` counts the holes down:** every list entry is one hole and every 3420 call fills one, so the frames stop when `mn` is back to 0, which is also what the cascade check needs to start from. |
| 3420 | one frame for column `g`: find its lowest hole, searching up from the stored row `q` (contiguous holes keep their lowest hole in place, so this usually succeeds at once); then one loop walks the board address `a` up from the hole to row 0 (`step-8`), with the screen address `p` beside it (−44): each cell takes the piece above it, and row 0 (`a<bb+8`) a new random piece instead. In row 0 the `peek(a-8)` reads a byte before the board; it's read and then replaced. One hole fewer. Since the loop ends on row 0 itself, a hole in row 0 needs no special case (the earlier version's loop stopped at row 1 and had to be skipped, because a `for` always runs once). |
| 3500 | the cascade: count the round (`rd`) and add its score (`sc`, shown by 3800), the match ding (6000), flash, clear and fall (3200), then check every window touching a changed cell (3600 for each changed column, then across); if anything matched, again. Changed cells are rows 0 to the lowest hole in each column with bit 128 in its hole byte. The across check runs rows 0 to `lm`, window starts `cl-2` to `ch`, skipping starts outside 0-5 as 3020 does. |
| 3600 | one changed column `g`: note the column range (`ch` is simply the latest, since `g` counts up; `cl` the first) and the deepest row (`lm`), then check its vertical windows starting at rows 0 to its lowest hole row (at most 5). Checking each changed cell's own windows instead would test the same windows many times over. |
| 3800 | show the score on row 1, with cursor codes (`{home}{down}{rght}`) |
| 5000 | the hint: when `h` was pressed (`hw`) and a move is known (`hc<0`), erase the cursor, put it on the found cell (`x=-1-hc`), draw it; then falls into 5005, which returns at once while `hc<0` |
| 5005 | one trial of the no-moves check, after 2 s idle (`ti-kt>=120`) and until a move is found (`hc<0`): advance the spinner, pick cell `x` and neighbour `y` (right or down) from `(hc+ho)and127`, skip it if `y` is off the board, swap the bytes, check around both cells in test mode (a run sets `mn`), swap back. Cell 63's last trial done with no move: game over (5500). |
| 5500 | game over: GAME OVER on row 21 (`poke214,20:print` puts the cursor on row 21: 214 is the cursor's row, and the `print` moves to the next row and sets the line up properly; then `tab(6)`), the result for the launcher (5600). Started from a launcher (`e`, the device from 841, not 0), `LEADERBOARD` with a red `l` on row 22 (5510). Then the falling tone (5515). Then a key: `poke198,0:wait198,1` waits for one in the buffer and `get` takes it; `l` from a launcher goes back to it (5540), any other key starts over with `run` (5525; 330 empties the buffer; `run` clears `e`, and 230 reads it again from 841, which is still there). |
| 5530 | leave (`qq`): from a launcher, write the score so far (5600) if there is one; then 5540 |
| 5540 | the VIC's normal colors, clear the screen; started on its own, end (the game can be resumed from `READY.`, see "Resuming after a quit"); from a launcher, load it (5550-5570, see "Launcher") |
| 5600 | the result for the launcher in the cassette buffer: 900 game 2, 901 check 253, 902 variant 2 endless, 903 one field, 904-906 the score, low byte first |
| 5900 | one spinner step: `sp` counts 0, 2, 4, 6 (`(sp+2)and7`), and `spor1` turns that into the color 1, 3, 5, 7 (white, cyan, green, yellow, all clear on black) poked into the ✱'s color RAM (38872). A key or a found move hides it again with color 0. The wrap keeps `sp` small: the earlier glyph spinner counted up forever, and its `spand3` would stop with `?ILLEGAL QUANTITY` past 32767 steps, in a very long game. The odd colors also stay below 8, which would switch the cell to multicolor. |
| 6000 | the match ding for a cascade round: pitch from `mn` and `rd` (see "Sound") |

## Variables

| Name | Meaning |
|---|---|
| `z` | 36874, the base of the sound and color registers: `z` to `z+3` are the four voices, `z+4` the volume, `z+5` the screen colors |
| `e` | the launcher's device, from 841 (0: started on its own), read once at 230 |
| `bb`, `bh` | addresses of the board (919) and the hole bytes (1012) in the cassette buffer; the match list (983) is a literal |
| `w` | a cell's byte while drawing (1200) or falling (3440); also, since no two of these overlap, the box's bottom-left address (2000) and a trial's direction (5020: 0 right, 1 down) |
| `pg%()` | piece glyph (screen code) at the type's index, its color at index + 8 |
| `ka`, `kw`, `kh`, `km` | box: top-left screen address, offset to the right edge (2, 4), offset to the bottom row (44, 88), mode (1 draw, 0 erase) |
| `cr`, `cc` | cursor: board row and column, 0-7 |
| `r`, `c` | the cursor's new row and column while moving, and the neighbour while swapping |
| `x`, `y` | the two cells' indexes (0-63) while swapping, or in a trial |
| `n` | pause length in jiffies (5 for each swap pause, about 1/12 s; tuned by eye 2026-11-08, first tried 10) |
| `mn` | the match list's length; counted down to 0 as the holes fill (3460); 1 after a trial that found a run |
| `u`, `d` | in 3020: cell `i`'s place along the line (its column across, its row down) and a window's start; `d` is also the window start in the cascade's across check |
| `v` | a matched cell's row (3320); the score while writing the result (5510) |
| `s` | a window's first cell, as a buffer address (`bb+…`, saving an addition per `peek`); `j` its step (1 across, 8 down) |
| `k` | the key as a number, Shift bit dropped (345); a loop counter over the match list (3200, 3300); a trial's number (5020) |
| `l` | the previous key, for `qq` |
| `q` | a cell address while marking a window (3120); a column's lowest hole row (3340, 3420, 3600; 3640's `for` reads its limit once, so marking may reuse `q`) |
| `g` | column, in gravity (3300, 3420) |
| `b` | the column's hole byte (see "Data model") |
| `a` | the board address of the cell being filled: in the fill (200) and in 3420 |
| `cl`, `ch`, `lm` | in the cascade: first and last changed column, deepest changed row |
| `r` | also the row loop in the cascade's horizontal check |
| `sc` | the score |
| `hc` | no-moves check: trials done (0-127), or `-1-x` once a move is found at cell `x` (−1 to −64) |
| `hw` | the player asked for a hint (`h`, −1) and it isn't shown yet |
| `ho` | the no-moves check's random start (0-127), new for each board |
| `ht` | a trial is running (test mode); a run it finds sets `mn` to 1 |
| `kt` | `ti` at the last key or swap (2-second idle timer) |
| `sp` | the spinner's step: 0, 2, 4 or 6 |
| `rd` | the cascade round of the current move, from 1 (reset at 330, after every swap) |
| `i` | loop counter (board loops); the cell for 1200 and 3000 |
| `j` | loop counter in the box; a window's step |
| `p` | a piece's screen address while drawing |
| `t` | the piece being tried while filling; a cell's byte or type in a window (3100, 3120); the swap's temporary (2400); the pause's end time (2900); a box line's glyph (2050, 2070); the score's higher bytes (5610); a throwaway result (`rnd(-ti)` seeding) |
| `a$` | last key from `get` (also the key after game over) |

## Sound

Each sound's register and values, for tuning by ear. Chosen 2026-11-11 from `meta/src/soundlib.bas` (letters there): the match ding from 2up11's coin ding (`i`, `j`, `k`), the swap from RingSort's ring lift (`a`, as the box grows; the ring down `b` for the shrink was dropped, since the buzz or the match ding already ends every swap), the failed swap from RingSort's buzz (`c`; the woosh `d` after it was dropped, since the two said the same thing and the woosh cost 22 bytes more; it went to cursor moves instead), game over from 2up11's falling tone (`l`). Built one at a time: the match ding, the swap sounds, game over, then a shortened woosh on a cursor move (2026-11-12; 2up11's slide `h` was tried first, but its falling pitch sounded like a failure).

**The registers are written as `z` plus an offset (2026-11-12):** `z=36874` is the low voice, `z+1` 36875 (mid), `z+2` 36876 (high), `z+3` 36877 (noise), `z+4` 36878 (volume), and `z+5` 36879 (screen colors, not a sound register, but next in line). The code had 17 of these five-digit numbers; `z+2` takes 3 bytes instead of 5 and `z` 1, which saved about 27 bytes after the variable's own cost. The numbers below are the registers' addresses.

The volume is set to 15 at init (100) and to 0 on leaving (5540), so no note is left playing at `READY.` or in the launcher.

**Match ding (6000-6010), one per cascade round,** played after the score and before the flash (3500). The pitch comes from the round's pieces before the multiplier (`mn`), shifted up by the round (`rd`), so a bigger match sounds higher and a cascade rises: `n=175+3*mn+6*rd`, which is 190 for a 3-match in round 1 (2up11's lowest ding was 193), 196 for a 5-match, 202 for a 3-match in round 3. Capped at 254, since a voice register takes at most 255 and a cross of two long runs can list up to 29 cells. Then 2up11's ding on the high voice (36876): the note for a short `for` hold (12), a lower note (`64+.75*n`) for a longer one (40), off. `n` is the pause's length too, but 3200 sets it to 30 right after, so it's free here. The `for` holds slow down a little as the game makes more variables (`j` is found later in the list); judged in play. 118 bytes in all, with the two volume pokes.

**Swap sounds (2260-2285), written out where they play.** A shared sweep routine (`fori=ftoesteps:pokev,i:next:pokev,0`, 37 bytes) didn't pay: a call with its four parameters (`v=36875:f=200:e=240:s=4:gosub…`) is as long as the loop written out, and `f` and `e` would be two new variables. Each sweep turns its voice off at the end.

| When | Sound | Code |
|---|---|---|
| the box grows over both pieces (2260) | ring up: 200 to 240, step 4, voice 36875 | RingSort's lift (`a`) |
| a match (2280) | none of its own: the cascade's match ding follows (a ring down there was dropped, 2026-11-11: a swap ends in either the buzz or a ding) | |
| no match (2285) | buzz: 150 to 130, step −1, low voice 36874 | RingSort's invalid move (`c`) |

The buzz plays before the pieces go back; the pause after it is the one that was there before the sounds. 78 bytes in all; no new variables (`i` is the loop counter everywhere).

**Game over tone (5515):** 2up11's falling tone, 200 to 140 in steps of −0.5 on the low voice (36874), then off. It plays after GAME OVER (and LEADERBOARD) are shown, and before the key wait, whose `poke198,0` drops keys pressed during the tone. It has its own line because 5510's `if` would skip it for a game started on its own, and 5500 and 5520 have no room under 88 characters. 39 bytes.

**Woosh (450), on each cursor move:** the noise voice (36877) at 250 while the volume fades from 11 (about 75% of full, chosen by ear) in steps of −1.5 (8 steps, half the length of soundlib's `d`, so quick taps don't drag; the volume register drops the fraction), then noise off, volume 15. It stops at 0.5, not 0; the noise goes off right after. It plays after the box is redrawn, so the cursor moves at once; a key that doesn't move the cursor (an edge, any other key) goes back from 420 without it, and neither does the hint's jump (5000). Typed-ahead moves wait for it, but none are lost. It's on its own line because 440 has no room for it under 88 characters: 440 now falls into 450, which ends with 440's old `goto340`. 58 bytes; 2up11's slide (`h`) took 57 and was tried first.

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
| 2026-11-10 | 825 | second tightening pass (PRG 2442, from 3108). Measured after about 50 keys of play with matches and cascades. The game-over path adds no variable. |
| 2026-11-10 | 590 | back to the launcher: `l` at game over, `qq` leaves the score so far (PRG 2677). Measured after play with matches; no new variables. |
| 2026-11-10 | 506 | the hint on `h` (PRG 2754: 77 bytes, plus `hw`). Measured after play with matches and a hint. |
| 2026-11-11 | 388 | the match ding and the volume (PRG 2872, 118 bytes; no new variables). Measured after play with a match. |
| 2026-11-11 | ~390 | the color spinner (PRG 2870, 2 bytes smaller: the step lost 17, the ✱'s new init line cost 15). Not re-measured; no variables changed. |
| 2026-11-11 | 262 | the swap sounds: ring up, buzz, woosh (PRG 2998, 128 bytes; no new variables). Measured after play with failed swaps and a match. |
| 2026-11-11 | 312 | the woosh dropped from the failed swap, the buzz kept (PRG 2948, swap sounds 78 bytes). Measured after play with failed swaps and a match. |
| 2026-11-11 | 273 | the game-over tone (PRG 2987, 39 bytes; no new variables). Measured after play with a match. |
| 2026-11-12 | ~215 | a woosh on cursor moves (PRG 3045, 58 bytes; no new variables). 216 measured with the slide in its place (PRG 3044), after play with moves, failed swaps and a match. |
| 2026-11-12 | 293 | third tightening pass (PRG 2953, 92 less; two new variables, `z` and `e`, so 78 more free): the registers as `z` plus an offset, the fill's two tests on one line, `e` for `peek(841)`, init on two lines, the cursor drawn only at 330, and smaller savings in the box and the result writer. Measured after play with moves, failed swaps, matches and a hint. |


## Resuming after a quit

After `qq` in a game started on its own (from the launcher, `qq` loads the launcher instead), everything the game needs is still in memory: the variables (score, cursor, the no-moves check's progress) and the board, which lives in the cassette buffer that `end` doesn't touch. Only the screen was cleared and the colors reset. At `READY.`:

```
print chr$(147):poke36879,8:l=0:fori=0to63:gosub1200:next:gosub3800:goto330
```

| Part | Does |
|---|---|
| `print chr$(147)` | clears the screen (147 is the clear-screen code) |
| `poke36879,8` | the black screen and border again |
| `l=0` | forgets the last `q`, which would otherwise make the next single `q` quit |
| `fori=0to63:gosub1200:next` | redraws the board from the cassette buffer, cell by cell |
| `gosub3800` | reprints the score |
| `goto330` | draws the cursor and continues the play loop |

The cursor box comes out white: clearing the screen sets color RAM to white. The spinner doesn't show after a resume: the clear erased its ✱, and only its color is changed from then on; `poke8152,42` brings it back, but the resume line has no room for it within the 88 characters typed at the prompt. `run` or editing a program line clears the variables, after which only the board survives. Tested in xvic (2026-11-09): same board, cursor and score after resuming; a move works; a single `q` doesn't quit.

## Launcher

MonkeySwap works with the CodeMonkeyATL launcher (`vic20-launcher`) through the cassette buffer, as 2up11 does (the layout is in `vic20-launcher/docs/design.md`, "The cassette buffer"). At game over it writes its result at 900-906 (5600): game 2, check 253, variant 2 (endless), one field, the score in 3 bytes. A new game doesn't touch 900-918, so the result waits there until the launcher reads it; a later game over replaces it. Tested in xvic (2026-11-09): a game over with the score set to 12345 left `2 253 2 1 57 48 0`.

**Going back to the launcher (2026-11-10, 235 bytes: free after play 825 → 590).** Only when a launcher started the game, which it shows by leaving its device in 841 (0 when the game was started on its own, which then behaves exactly as before):

- **At game over,** row 22 shows `LEADERBOARD` with a red `l`, and `l` loads the launcher; any other key plays again. The result is already written.
- **`qq` mid-game** loads the launcher too (the contract's "quit goes back", as in 2up11), so the player never drops to `READY.` from a launched game. **It leaves the score so far** if there is one (`sc>0`): an endless game's score only grows, so a quit is a fair end, the same policy as 2up11's (`meta/research/leaderboard/README.md`). A quit before the first match posts nothing, rather than a 0.
- There's no `l` mid-game: `qq` does the same, and a single key that abandons a game would be easy to hit by accident.

The load is the launcher's own trick (`vic20-launcher/docs/design.md`, "Starting another program"), as in 2up11's 800-820: 5550 prints `load"<name>",<device>` on row 2, with the name from 843+ (length at 842) and the device from 841; 5560-5570 put Return, `r`, `u`, `n`, Return in the keyboard buffer (631-635, count 5 at 198) and `end`. `READY.` lands on row 1, the first Return enters the `load` line, and `run` starts the launcher once it's loaded.

The result writer moved into its own subroutine (5600) so both game over and `qq` use it. 5530 tests `peek(841)` before `sc>0` with a nested `if`, so a game started on its own never writes a result on quit.

**Tested in xvic (2026-11-10),** with `2,MONKEYSWAP` added for the test to the mock list `games` in `prgs-latest` (and removed again): launcher → `2` → one match (30) → `qq` → the launcher showed `/v1/s?g=2&v=2&p=1&a=30`; launcher → `2` → `qq` at once → nothing posted; a forced game over in a launched game (score 4321, `hc=128` from the prompt) → `LEADERBOARD` on row 22 → `l` → `/v1/s?g=2&v=2&p=1&a=4321`. Started on its own: `qq` ends at `READY.`, and a game over shows no `LEADERBOARD`, where `l` starts a new game.

Still needed elsewhere: register game 2 (MonkeySwap, variant 2 ENDLESS, field PTS) in `leaderboard-service`'s seed, and add it to the launcher's game list (see `todo.md`).

**Start-up tried and dropped (2026-11-09):** a random fill that the cascade then "settles" saved about 60 bytes over the no-runs fill (200), but took 15 s at a typical start and up to 90 s, so the no-runs fill stayed.

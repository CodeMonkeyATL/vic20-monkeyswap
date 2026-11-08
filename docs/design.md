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

The board is 8x8 pieces at a 2x2 pitch: one character per piece, with a gap column and a gap row between pieces. Including the cursor's outer edges that's 17 columns by 17 rows, which leaves room for the score and moves above. Exact rows and columns get mapped here when the board is drawn.

## Data model

Arrays and what each element holds. Document the bit layout of any packed value.

## Routines

| Lines | Routine |
|---|---|
| 100 | init |

## Variables

| Name | Meaning |
|---|---|
| `a$` | last key from `get` |

## Sound

Each sound's register and values, for tuning by ear.

## Memory

Free memory measured with `?fre(0)` after quitting, with the date and what changed.

| Date | Free | After |
|---|---|---|

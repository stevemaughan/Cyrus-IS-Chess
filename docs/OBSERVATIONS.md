# Observations: quirks deliberately preserved

These are weaknesses or oddities of the original that the port reproduces exactly (AGENTS.md §2.2, class C). Each points to the subsystem document with the details.

## Search ([30-search.md](arch/30-search.md))
- Mates are not distance-scored. All mates are `$FF`; the shortest root mate is chosen by a separate ply comparison, and ties go to the first move found.
- In selective plies a mate is approximated: illegal replies while in check count as value 2.
- The only draws the search knows are stalemate and repetition at the root (`$BD5E ≥ 2`). It knows nothing of the 50-move rule, repetitions inside the tree, or insufficient material.
- Forward pruning discards moves by static score (`$805F`, `$80C4`). Good moves can be pruned.
- After a key press (or `stop`) the search finishes the current line's last move list before unwinding, which takes 50–200 extra makes.

## Evaluation ([50-eval.md](arch/50-eval.md))
- Random noise: the low bit of `$BCCE` (two bits on move 1) is added to every evaluation.
- Rook and queen mobility counts only vertical and diagonal squares, never horizontal.
- Doubled pawns are checked only against the previous two pawn *records*, in original-file order.
- The "unmoved centre pawn" penalty applies to the d/e pawn records on rank 2 or 7, for either colour.
- Promoted pieces keep the pawn line mask, so they still count as pawns in several tests, including king shelter.
- 2-bit attack counters overflow into the next field (4 minors look like a rook).
- 8-bit accumulators wrap: a large material lead can saturate the wrong way.
- Material is measured relative to the search root (`$BD0D`), not absolutely.

## Move generation and rules ([20-board-movegen.md](arch/20-board-movegen.md))
- The generator is pseudo-legal. Castling through attacked squares is generated, and is caught only by the evaluation at the root (to be confirmed).
- The engine never generates under-promotions: it always promotes to a queen.
- Castling is not generated when the previous move gave check, using the last-move record's check bit.
- Castling resets the 50-move counter (main loop).

## Book ([25-book.md](arch/25-book.md))
- 1.b3 and 1.f4 are recognised when the opponent plays them, but are never chosen.
- The random choice is strongly biased towards the first sibling, and its bytes are correlated.

## Main loop and UI ([10-main-ui.md](arch/10-main-ui.md))
- A checkmated set-up position is announced as STALEMATE (UI only; a UCI port reports no move either way).
- The move number wraps at 256, after which the phase logic sees "move < 8" again.
- `$BCA0`, the last root value, persists across moves and new games, and feeds the next search's pre-search smoothing.

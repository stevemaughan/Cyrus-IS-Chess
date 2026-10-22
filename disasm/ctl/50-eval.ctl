@ $8400 label=Evaluate
c $8400 Evaluate the position after a move
D $8400 Static evaluation of the current position from the point of view of the side that has just moved (the side NOT to move in bit 0 of $BD2D). Called after every make-move in the search and at the root. It builds attack maps for both sides in the piece records (bytes +2..+5), scores mobility, development, pawn structure and king safety, runs a static exchange evaluation (SEE) on every attacked piece, and combines material change, threats, positional score and a small random term into one unsigned byte. See docs/arch/50-eval.md for the full specification.
D $8400 Register conventions inside the evaluation: main H=$BD (board page), main D = off-board mask $88 (pawn direction $11/$F1 while scanning pawns), main E = positional accumulator, main B = square of the piece being scanned, main C = ray direction. A' = king/pawn accumulator. Alternate set: H'=$BE (piece-record page), L' = record pointer (a piece code points at record+4), C' = attack weight of the scanning piece (pawn 1, minor $04, rook $10, queen $40), E' = line mask ($08 orthogonal, $C4 diagonal), B' = pass flags (bit 7 colour being scanned, bit 4 second pass, bit 5 pin list non-empty, bit 6 check seen, bit 0..bit 3 game phase from $BD2D).
D $8400 If the side to move can capture the enemy king (or the kings touch) the routine aborts through #R$8C28, which restores SP from $BD3D and returns A=0.
R $8400 IX Move-list entry of the move just made (+2 to-square read, +3 flags updated)
R $8400 O:A Score: $80 = level, higher is better for the side that has just moved; $02/$FC on large material swings; 0 if the move was illegal
R $8400 O:B Positional component (signed, mover's view), used by #R$7810
  $8400,4 Save SP so that #R$8C28 can abort from any depth
  $8404,3 A'=0 (king/pawn accumulator), E=0 (positional accumulator)
  $8407,2 H=$BD (board page)
  $8409,3 H'=$BE (piece-record page)
  $840C,4 A=side/phase flags rotated: bit 7=side to move (1=White), bit 0..bit 3=phase bits
  $8410,4 IY=pawn routine: #R$8A7A normally,
  $8414,8 #R$8A6F when total material is below $34,
  $841C,8 #R$8A2B when it is below $28
  $8424,3 B'=pass flags: bit 7=colour scanned first (side to move), Carry=side to move is White
  $8427,1 Back to the main set
  $8428,3 White to move: scan White first (#R$883A)
@ $842B label=EvBlackPieces
N $842B Scan Black's pieces (queen, rooks, bishops, knights, then pawns), accumulating attacks in the records and positional score in E/A'.
  $842B,2 D=$88 (off-board mask)
  $842D,7 Black queen (if not captured)
  $8434,14 Black rooks
  $8442,14 Black bishops
  $8450,14 Black knights
  $845E,5 D=$F1 (black pawns attack down the board); B=C=$FF (no previous pawn files)
  $8463,64 Black pawns a..h (records $BEC0..$BEF8; the d- and e-pawn records use #R$8A54)
  $84A3,1 Second pass done?
  $84A4,5 No: switch colour and scan White (#R$882C)
@ $84A9 label=EvScoreExchanges
N $84A9 Both sides scanned. Finish the positional score, then evaluate exchanges on every attacked piece.
  $84A9,4 Skip if a check was seen (bit 6 of B')
  $84AD,6 L=piece code on the move's to-square
  $84B3,4 If a piece stands there,
  $84B7,3 set bit 1 of its record +5 ('moved piece' marker for the SEE penalty)
  $84BA,5 Late endgame (bit 3 of B')?
  $84BF,12 Yes: halve E, or quarter it if there are no pawns ($BD6D=0)
  $84CB,2 Pin list non-empty (bit 5 of B')?
  $84CD,4 If so, remove the pinned pieces' illegal attacks (#R$8E74)
  $84D1,11 E = A'/4 + E + $BD4A (positional score, Black's view)
  $84DC,10 $BD39/$BD3A = 0 (best and second-best SEE gain), save IX in $BD3B
  $84E6,22 Black queen: if attacked (+2/+3 non-zero), SEE with value 9; clear its attack bytes
  $84FC,22 Black rook (a): SEE with value 5
  $8512,22 Black rook (h): SEE with value 5
  $8528,22 Black bishop (c): SEE with value 3
  $853E,22 Black bishop (f): SEE with value 3
  $8554,22 Black knight (b): SEE with value 3
  $856A,22 Black knight (g): SEE with value 3
  $8580,184 Black pawn records a..h: SEE with value = low nibble of the type byte (1, or the promoted piece's value)
  $8638,3 E = -E (White's view)
  $863B,10 Keep Black's best/second gains on the stack; reset $BD39/$BD3A
  $8645,22 White queen: SEE with value 9
  $865B,22 White rook (a): SEE with value 5
  $8671,22 White rook (h): SEE with value 5
  $8687,22 White bishop (c): SEE with value 3
  $869D,22 White bishop (f): SEE with value 3
  $86B3,22 White knight (b): SEE with value 3
  $86C9,22 White knight (g): SEE with value 3
  $86DF,184 White pawn records a..h: SEE with value from the type byte
N $8797 Combine. D,E = gains available against Black's pieces (second, best); H,L = against White's pieces (second, best). Arrange them as threats against the side to move (D,E) and against the mover (H,L), and take material from the mover's view.
  $8797,5 B = positional score (White's view); restore IX
  $879C,4 D,E = Black's pieces (second, best); H,L = White's pieces
  $87A0,6 White to move?
  $87A6,10 Yes: mover is Black: negate B, swap the threat pairs, A = $BD0D (material change, Black's view)
  $87B0,5 No: mover is White: A = -$BD0D
  $87B5,2 A = 2*(material - best gain the side to move has against the mover)
  $87B7,4 Any such gain?
  $87BB,4 Yes: flag the move (bit 1 of IX+3)
  $87BF,3 If the gain is 2 or more, A=A-1
  $87C2,1 A = A - second gain
  $87C3,4 Mover threatens something of the side to move?
  $87C7,6 Skip the bonus if the moved piece itself is en prise (bit 2 of IX+3)
  $87CD,2 B=B+2
  $87CF,4 A second threat?
  $87D3,6 Yes: flag a double threat (bit 6 of IX+3), B=B+2
  $87D9,9 A gain of 2 or more on the second threat: B=B+2
  $87E2,11 If mover's best threat exceeds the side to move's best capture, flag bit 6 of IX+3
N $87ED Scale: material outside -28..27 half-pawns saturates the score.
  $87ED,9 Material component in range?
  $87F6,7 No: return $02 (losing) or $FC (winning)
  $87FD,3 C = material * 4 (8 per pawn)
  $8800,7 D = (B + B/2 + carry)/2 (positional * 3/4)
  $8807,18 Increment the random byte $BCCE; add its bit 0 (bit 0..bit 1 on move 1)
  $8819,15 Clamp the positional term to -12..+12
  $8828,4 A = material + positional + $80
@ $882C label=EvSwitchToWhite
  $882C,4 Second pass: B' bit 4 set, colour flipped to White
  $8830,4 E = -E
  $8834,6 H=$BD; A' = -A'
@ $883A label=EvWhitePieces
N $883A Scan White's pieces, then both kings.
  $883A,9 White queen (if present)
  $8843,14 White rooks
  $8851,14 White bishops
  $885F,14 White knights
  $886D,5 D=$11 (white pawns attack up the board); B=C=$FF
  $8872,64 White pawns a..h (d- and e-pawn records use #R$8A54)
  $88B2,6 White king (#R$8978: early-queen check, then #R$897D)
  $88B8,7 A' = -A', E = -E (Black's view)
  $88BF,9 Black king (B' bit 7 set = black)
  $88C8,6 Second pass done?
  $88CE,6 No: set the second-pass flag and scan Black (#R$842B)
@ $88D4 label=EvKingCentralise
c $88D4 Late endgame king: centralisation
D $88D4 Used by #R$8943 when there are no pawns ($BD6D=0) and the king belongs to the side favoured by $BD1E. Adds a centralisation term to A': D (the king's diagonal edge distance * 8, or -10 if 0) plus 16 on files d/e or ranks 4/5, plus 8 on files c/f or ranks 3/6.
R $88D4 A $BD6D
R $88D4 D King's edge distance * 8 (from type bit 6..bit 7)
R $88D4 L King's square
  $88D4,4 Pawns on the board: just add D (#R$896F)
  $88D8,7 D=0: use -10
  $88DF,9 Files d,e?
  $88E8,11 Ranks 4,5?
  $88F3,6 Yes: A' = A' + 16 + D
  $88F9,11 Files c,f?
  $8904,11 Ranks 3,6?
  $890F,6 Yes: A' = A' + 8 + D
@ $8915 label=EvEarlyQueenCheck
c $8915 Opening: penalise early queen moves
D $8915 Used by #R$8978 before move 8. C = 9 - move number; a queen that has moved (bit 4 of its type byte) and is still on the board costs its side C points of E.
  $8915,8 C = 9 - $BD49
  $891D,17 Black queen moved and present: E=E+C
  $892E,17 White queen moved and present: E=E-C
  $893F,4 Continue with the king (#R$897D)
@ $8943 label=EvEndgameKing
c $8943 Endgame king evaluation
D $8943 Used by #R$897D in the endgame (bit 2 of B'). Pawns next to the king are worth 8 each in A'; in the late endgame (bit 3) they are worth 4 and the king may be centralised.
R $8943 A Pass flags (B')
R $8943 H King's type byte
R $8943 L King's square
  $8943,4 Late endgame?
  $8947,8 No: weight 8 per adjacent pawn
  $894F,10 Late: weight 4; D = edge distance * 8 (type bit 6..bit 7)
  $8959,6 $BD1E = 0?
  $895F,7 Same sign as the colour being scanned: centralisation (#R$88D4) with A=$BD6D
@ $8966 label=EvEndgameKing2
  $8966,2 D = D/2
  $8968,3 $BD1E set and pawns present: just add D
  $896B,4 Otherwise a king with bit 7 of its type set gets +8 (#R$890F)
  $896F,3 A' = A' + D
  $8972,6 Scan the king's neighbours (#R$89AC)
@ $8978 label=EvWhiteKing
c $8978 Evaluate the white king
D $8978 Used by #R$8400. Before move 8 (bit 0 of B' clear) first applies the early-queen penalty (#R$8915).
R $8978 H King's type byte
R $8978 L King's square
  $8978,5 Move 8 reached?
@ $897D label=EvKing
c $897D Evaluate a king (middlegame)
D $897D Used by #R$8400 (black king) and #R$8978. The king's type byte: bit 4 moved, bit 5 castled, bit 6..bit 7 distance from the edge along the diagonals (0..3, maintained by #R$8200).
R $897D H King's type byte
R $897D L King's square
  $897D,6 A=pass flags; endgame?
  $8983,5 Castled?
  $8988,5 Castled but away from the edge: exposed (#R$89FB)
  $898D,3 Castled: pawn-shelter weight 10
  $8990,11 Look two ranks ahead (or behind, if that leaves the board) on files f-1..f+1
  $899B,14 Any pawn there (piece code bit 6)?
  $89A9,2 None: E=E-2
  $89AB,1 Restore L
@ $89AC label=EvKingNeighbours
  $89AC,6 Left neighbour (no file check: may read an off-board byte)
  $89B2,6 Right neighbour
  $89B8,23 Rank above (if on the board): centre, right, left
  $89CF,19 Rank below (if on the board): centre, right, left
@ $89E2 label=EvKingNeighbourSquare
c $89E2 King: process a neighbouring piece
D $89E2 Used by #R$897D. Counts the king as a defender (+1 in record +5) of a friendly neighbour or an attacker (+1 in record +3) of an enemy one, and adds the shelter weight C to A' if the neighbour is a pawn record (either colour). Kings next to each other abort the evaluation.
R $89E2 A Piece code
R $89E2 C Shelter weight
  $89E2,3 L'=record+5
  $89E5,4 Friendly?
  $89E9,6 Enemy king next to this king: abort
  $89EF,2 Enemy: L'=record+3
  $89F1,1 Count the king attack/defence
  $89F2,5 Pawn record ($40-$7F, $C0-$FF)?
  $89F7,4 Yes: A' = A' + C
@ $89FB label=EvKingExposed
c $89FB King away from the edge or uncastled
D $89FB Continuation of #R$897D.
  $89FB,2 Shelter weight 4
  $89FD,7 Edge distance 2 or more: E=E-2
  $8A04,3 E=E-3
  $8A07,6 Scan neighbours
@ $8A0D label=EvKingUncastled
  $8A0D,4 King moved?
  $8A11,9 Never moved: weight 0, E=E+1
  $8A1A,6 Moved without castling: E=E-6, weight 8
  $8A20,5 Away from the edge: further penalty (#R$89FB)
  $8A25,6 Scan neighbours
@ $8A2B label=EvPawnLateEndgame
c $8A2B Pawn: late-endgame advancement bonus
D $8A2B Reached through JP (IY) from #R$8A5B when total material is below $28. A' gains the pawn type byte / 4 (0, 4, 12, 24 or 36 for relative ranks <=3, 4, 5, 6, 7). In the first pass a pawn on its seventh rank records the piece in front of it in $BD4E.
R $8A2B H Pawn type byte
R $8A2B L Square diagonally ahead-right (pawn square + D)
  $8A2B,7 A' = A' + type/4
  $8A32,5 Seventh-rank pawn (type bit 7)?
  $8A37,6 Only in the first pass
  $8A3D,8 $BD4E = contents of the square in front of the pawn
  $8A45,3 Mark its attacks (#R$8A7C)
@ $8A48 label=EvPawnDoubled
c $8A48 Pawn penalties
D $8A48 Continuations of #R$8A54/#R$8A5B.
  $8A48,6 Doubled pawn: E=E-3
@ $8A4E label=EvPawnCentreUnmoved
  $8A4E,6 Unmoved centre pawn: E=E-3
@ $8A54 label=EvCentrePawn
c $8A54 Evaluate a d- or e-pawn record
D $8A54 Used by #R$8400 for the d- and e-pawn records. A pawn standing on rank 2 or rank 7 (either colour) costs 3.
R $8A54 H Type byte
R $8A54 L Square
  $8A54,7 (rank+2) AND 4 = 0, i.e. on rank 2 or 7?
@ $8A5B label=EvPawn
c $8A5B Evaluate a pawn record
D $8A5B Used by #R$8400. Dispatches promoted pieces to the piece routines, penalises a pawn on the same file as either of the previous two pawn records scanned, then jumps through IY to add the phase-dependent advancement bonus and mark the pawn's two attacked squares.
R $8A5B B,C File of the previous two pawn records ($FF = none)
R $8A5B D Pawn direction $11 (White) or $F1 (Black)
R $8A5B H Type byte
R $8A5B L Square
  $8A5B,5 Promoted (type bit 1..bit 3)?
  $8A60,5 L = square diagonally ahead-right; A = its file nibble (= the pawn's file + 1)
  $8A65,6 Same file as one of the previous two pawns: doubled (#R$8A48)
@ $8A6B label=EvPawn2
  $8A6B,4 Remember the file; continue at IY
@ $8A6F label=EvPawnEndgame
c $8A6F Pawn: endgame advancement bonus
D $8A6F Reached through JP (IY) when total material is below $34: A' gains type/8 (0, 2, 6, 12 or 18 for relative ranks <=3..7).
  $8A6F,4 Unadvanced pawn: no bonus
  $8A73,7 A' = A' + type/8
@ $8A7A label=EvPawnAttacks
  $8A7A,2 H=$BD
@ $8A7C label=EvPawnAttacks2
  $8A7C,5 Piece diagonally ahead-right?
  $8A81,4 Piece diagonally ahead-left (L-2)? (no board-edge checks)
@ $8A85 label=EvPawnHit
c $8A85 Pawn attacks a piece
D $8A85 Used by #R$8A5B. Adds 1 to the defender count (+4) of a friendly piece or to the attacker count (+2) of an enemy piece.
R $8A85 A Piece code
  $8A85,2 L'=record+4
  $8A87,4 Friendly?
  $8A8B,5 Enemy king: check (#R$8ABA)
  $8A90,2 Enemy: L'=record+2
  $8A92,4 Count the pawn
@ $8A96 label=EvPromotedPawn
c $8A96 Evaluate a promoted pawn record as its new piece
D $8A96 Continuation of #R$8A5B. Saves B, C, D, pushes the return stub #R$8AB5 and dispatches on the type byte: queen, rook, bishop or knight (no development penalty).
  $8A96,6 Save pawn state; return via #R$8AB5
  $8A9C,5 C=type, H=$BD, D=$88
  $8AA1,6 Queen?
  $8AA7,5 Rook?
  $8AAC,6 Bishop?
  $8AB2,3 Knight
@ $8AB5 label=EvPromotedPawnReturn
c $8AB5 Return from a promoted piece
D $8AB5 Restores D (pawn direction) and B, C (pawn files) but keeps E.
  $8AB5,4 Restore DE but keep E
  $8AB9,1 Restore BC and return
@ $8ABA label=EvPawnGivesCheck
c $8ABA Pawn attacks the enemy king
D $8ABA Continuation of #R$8A85. In the first pass the side to move could capture the king: abort. Otherwise flag the move as a check (bit 7 of IX+3) and add 1 to E.
  $8ABA,5 First pass: abort
  $8ABF,4 Flag check on the move
  $8AC3,3 E=E+1
@ $8AC6 label=EvSeeNoDirect
c $8AC6 SEE: no direct attackers
D $8AC6 Continuation of #R$8AD6. Without direct attackers the piece counts as attacked only if the enemy king (record +3 bit 0) is among the attackers; the x-ray attackers and the king are then fed to the exchange.
  $8AC6,4 King among the x-ray attackers?
  $8ACA,3 No: nothing to do
  $8ACD,7 Yes: start the attacker generator on record +3
@ $8AD4 label=EvSeePawn
c $8AD4 SEE for a pawn record
D $8AD4 Used by #R$8400. A = type byte; the value is its low nibble.
  $8AD4,2 A = value (type AND $0F)
@ $8AD6 label=EvSee
c $8AD6 Static exchange evaluation of one piece
D $8AD6 Used by #R$8400. Plays out the capture sequence on the piece using two coroutines: #R$8B50/#R$8B6A yield attackers in the order pawn, minor, rook, queen, x-ray minor, x-ray rook, x-ray queen, king (continuation in IY); #R$8BB9 yields defenders likewise (continuation in IX). The loop works in the alternate set with A = running gain, E' = lower bound, D' = upper bound, L' = current attacker value, H' = current defender value, C' = defenders left of that value; main D = attackers left of that value.
D $8AD6 A positive result updates $BD39 (best) and $BD3A (second best). Any non-negative result costs E one point, three if the piece carries the moved/checking marker (+5 bit 1), which also flags bit 2 of IX+3.
R $8AD6 A Piece value
R $8AD6 B Record +5 (x-ray defenders, king defender bit 0, marker bit 1)
R $8AD6 C Record +4 (defenders: pawns bit 0-1, minors bit 2-3, rooks bit 4-5, queens bit 6-7)
R $8AD6 H Record +3 (x-ray attackers, king attacker bit 0)
R $8AD6 L Record +2 (attackers: pawns bit 0-1, minors bit 2-3, rooks bit 4-5, queens bit 6-7)
R $8AD6 O:HL 0 (written back to clear the record)
  $8AD6,3 D' = value (upper bound)
  $8AD9,4 No direct attackers? (#R$8AC6)
  $8ADD,3 First attacker: L' = value, main D = count
@ $8AE0 label=EvSeeStart
  $8AE0,3 First defender: H' = value, C' = count
  $8AE3,3 E' = -1 (lower bound); A = value (gain if the first attacker captures)
@ $8AE6 label=EvSeeLoop
  $8AE6,2 B' = 0
  $8AE8,4 No defender left: stop
  $8AEC,1 Defender recaptures: A = A - attacker value
  $8AED,6 One attacker of this value used; fetch the next kind when exhausted
  $8AF3,4 Below the lower bound: B'=1
  $8AF7,4 At or above the upper bound: B'=2
  $8AFB,1 Otherwise raise the lower bound
@ $8AFC label=EvSeeAttacker
  $8AFC,4 No attacker left: stop
  $8B00,1 Attacker recaptures: A = A + defender value
  $8B01,4 Below the lower bound: B'=B'-1, stop if 0
  $8B05,4 At or above the upper bound: B'=B'-2, stop if 0
  $8B09,1 Otherwise lower the upper bound
  $8B0A,4 One defender used; fetch the next kind when exhausted
  $8B0E,3 Next round
  $8B11,5 B'=2 / B'=1
  $8B16,4 B'=B'-2 / B'=B'-1; continue unless 0
@ $8B1A label=EvSeeResult
  $8B1A,5 A = max(A, lower bound)
  $8B1F,5 A = min(A, upper bound)
  $8B24,5 Negative: piece is safe, return HL=0
  $8B29,2 Zero: no gain, but still penalised
  $8B2B,9 Keep the best gain in $BD39,
  $8B34,5 and the second best in $BD3A
@ $8B39 label=EvSeePenalty
  $8B39,1 E=E-1 for a piece under attack
  $8B3A,4 Moved/checking piece (+5 bit 1)?
  $8B3E,4 No: return HL=0
  $8B42,14 Yes: restore IX, flag bit 2 of IX+3 (moved piece en prise), E=E-2
@ $8B50 label=EvAttackerGen
c $8B50 SEE coroutine: direct attackers
D $8B50 Used by #R$8AD6. Yields each non-empty attacker group of record +2 (main L) in increasing value, then continues with the x-ray byte +3 (#R$8B6A). Each yield (#R$8B84...#R$8BB1) stores the continuation in IY, sets L'=value and main D=count, and returns with the alternate set active and A/A' swapped. Exhausted: L'=0.
  $8B50,5 Pawns
  $8B55,6 Minor pieces
  $8B5B,6 Rooks
  $8B61,6 Queens
  $8B67,3 X-ray byte empty: finished
@ $8B6A label=EvXrayAttackerGen
c $8B6A SEE coroutine: x-ray attackers
D $8B6A Used by #R$8AC6 and continuation of #R$8B50. Groups of record +3 (main H): minors, rooks, queens, then the king (bit 0).
  $8B6A,5 X-ray minors
  $8B6F,6 X-ray rooks
  $8B75,6 X-ray queens
  $8B7B,5 King
@ $8B80 label=EvAttackersDone
  $8B80,4 No more attackers: L'=0
@ $8B84 label=EvYieldPawnAttackers
c $8B84 Yield pawn attackers
D $8B84 Coroutine yield used by #R$8B50.
  $8B84,3 D=count; IY=continuation
  $8B87,5 L'=1 (pawn)
@ $8B8C label=EvNextAttacker
c $8B8C Resume the attacker coroutine
D $8B8C Used by #R$8AD6 when the current attacker group is used up.
  $8B8C,5 Save the SEE state and resume at IY
@ $8B91 label=EvYieldMinorAttackers
c $8B91 Yield minor-piece attackers
D $8B91 Coroutine yield used by #R$8B50 and #R$8B6A.
  $8B91,5 D=count (bit 2-3); IY=continuation
  $8B96,5 L'=3
@ $8B9B label=EvYieldRookAttackers
c $8B9B Yield rook attackers
D $8B9B Coroutine yield used by #R$8B50 and #R$8B6A.
  $8B9B,7 D=count (bit 4-5); IY=continuation
  $8BA2,5 L'=5
@ $8BA7 label=EvYieldQueenAttackers
c $8BA7 Yield queen attackers
D $8BA7 Coroutine yield used by #R$8B50 and #R$8B6A.
  $8BA7,5 D=count (bit 6-7); IY=continuation
  $8BAC,5 L'=9
@ $8BB1 label=EvYieldKingAttacker
c $8BB1 Yield the king as attacker
D $8BB1 Coroutine yield used by #R$8B6A.
  $8BB1,3 D=1; IY=continuation
  $8BB4,5 L'=13
@ $8BB9 label=EvDefenderGen
c $8BB9 SEE coroutine: defenders
D $8BB9 Used by #R$8AD6. Yields defender groups from record +4 (main C) then x-ray defenders from +5 (main B): minors, rooks, queens and finally the king (bit 0), which also costs E one point when it is reached. Continuation in IX. Exhausted: H'=0.
  $8BB9,5 No direct defenders?
  $8BBE,5 Pawns
  $8BC3,6 Minors
  $8BC9,6 Rooks
  $8BCF,6 Queens
  $8BD5,3 X-ray byte empty: finished
  $8BD8,5 X-ray minors
  $8BDD,6 X-ray rooks
  $8BE3,6 X-ray queens
  $8BE9,5 King
@ $8BEE label=EvDefendersDone
  $8BEE,4 No more defenders: H'=0
@ $8BF2 label=EvYieldPawnDefenders
c $8BF2 Yield pawn defenders
D $8BF2 Coroutine yield used by #R$8BB9.
  $8BF2,8 C'=count, H'=1; IX=continuation
@ $8BFA label=EvNextDefender
c $8BFA Resume the defender coroutine
D $8BFA Used by #R$8AD6.
  $8BFA,5 Save the SEE state and resume at IX
@ $8BFF label=EvYieldMinorDefenders
c $8BFF Yield minor defenders
D $8BFF Coroutine yield used by #R$8BB9.
  $8BFF,10 C'=count, H'=3; IX=continuation
@ $8C09 label=EvYieldRookDefenders
c $8C09 Yield rook defenders
D $8C09 Coroutine yield used by #R$8BB9.
  $8C09,12 C'=count, H'=5; IX=continuation
@ $8C15 label=EvYieldQueenDefenders
c $8C15 Yield queen defenders
D $8C15 Coroutine yield used by #R$8BB9.
  $8C15,10 C'=count, H'=9; IX=continuation
@ $8C1F label=EvYieldKingDefender
c $8C1F Yield the king as defender
D $8C1F Coroutine yield used by #R$8BB9. Costs E one point.
  $8C1F,1 E=E-1
  $8C20,8 C'=1, H'=13; IX=continuation
@ $8C28 label=EvAbort
c $8C28 Abort the evaluation: illegal position
D $8C28 Used when the side to move attacks the enemy king or the kings touch. Clears the pin list and the attack bytes (+2..+5) of records $BE08..$BEF8 (not the white king's), restores SP from $BD3D and returns A=0 to the caller of #R$8400.
  $8C28,4 Empty the pin list
  $8C2C,18 Clear +2..+5 of 31 records
  $8C3E,5 Return 0 from #R$8400
@ $8C43 label=EvQueen
c $8C43 Queen attacks
D $8C43 Used by #R$8400 and #R$8A96. Rook lines and diagonals with weight $40.
R $8C43 A Square
  $8C43,4 B=square; C'=$40
  $8C47,3 Rook lines
  $8C4A,4 Diagonals (#R$8D89)
@ $8C4E label=EvRook
c $8C4E Rook attacks
D $8C4E Used by #R$8400 and #R$8A96.
R $8C4E A Square
  $8C4E,4 B=square; C'=$10
@ $8C52 label=EvOrthogonals
c $8C52 Scan the rook lines of a queen or rook
D $8C52 Used by #R$8C43 and #R$8C4E. Horizontal rays do not count mobility; vertical rays add 1 to E for every square up to and including the first piece. The first piece hit is processed by #R$8C98 (horizontal) or #R$8C80 (vertical).
R $8C52 B Square
R $8C52 C' Weight
  $8C52,3 E' = $08 (pieces that move orthogonally)
  $8C55,10 East
  $8C5F,5 Piece hit (C=+1)
  $8C64,10 West
  $8C6E,5 Piece hit (C=-1)
  $8C73,7 North (if not on rank 8)
  $8C7A,3 South
@ $8C7D label=EvVerticalStep
  $8C7D,3 Next square; stop off the board
@ $8C80 label=EvVerticalSquare
c $8C80 Vertical ray: next square
D $8C80 Part of #R$8C52.
  $8C80,2 Count mobility
  $8C82,4 Empty: continue
  $8C86,6 L'=record+4 of the piece; enemy (#R$8DB9)?
  $8C8C,3 Friendly: defender count +weight
  $8C8F,4 Also an orthogonal mover?
  $8C93,2 No: done
  $8C95,3 Yes: x-ray through it (#R$8DF8)
@ $8C98 label=EvHorizontalHit
c $8C98 Horizontal ray: first piece hit
D $8C98 Part of #R$8C52. Enemy pieces go to #R$8DB9; a friendly orthogonal mover is x-rayed to the next piece only (no mobility).
R $8C98 A Piece code
R $8C98 C Direction
  $8C98,6 Enemy?
  $8C9E,3 Friendly: defender count +weight
  $8CA1,4 Also an orthogonal mover?
  $8CA5,2 No: done
  $8CA7,8 Look beyond it
  $8CAF,6 Enemy beyond: x-ray attacker (#R$8E07)
  $8CB5,6 Friendly beyond: x-ray defender (+5)
@ $8CBB label=EvBlackKnight
c $8CBB Black knight
D $8CBB Used by #R$8400. A knight on its back rank costs 3.
R $8CBB A Square
  $8CBB,7 On rank 8?
@ $8CC2 label=EvKnightBackRank
  $8CC2,6 Yes: E=E-3
@ $8CC8 label=EvWhiteKnight
c $8CC8 White knight
D $8CC8 Used by #R$8400.
R $8CC8 A Square
  $8CC8,5 On rank 1: penalty (#R$8CC2)
@ $8CCD label=EvKnight
  $8CCD,5 C'=$04; E=E-1 (mobility counts target squares - 1)
@ $8CD2 label=EvKnightWalk
  $8CD2,35 Upward targets +14, +18, +31, +33 (skipped if the first leaves the top of the board)
  $8CF5,32 Downward targets -14, -18, -31, -33 (stops as soon as one leaves the bottom)
@ $8D15 label=EvKnightTarget
c $8D15 Knight target square
D $8D15 Part of #R$8CC8. Counts mobility and marks the piece found.
R $8D15 L Target square
  $8D15,3 Count mobility; empty: done
  $8D18,6 L'=record+4; friendly?
  $8D1E,5 Enemy king: check (#R$8D2A)
  $8D23,2 Enemy: L'=record+2
  $8D25,5 Add the weight
@ $8D2A label=EvKnightChecksKing
c $8D2A Knight attacks the enemy king
D $8D2A First pass: abort. Second pass: flag the move as a check (bit 7 of IX+3); a first check marks the checking piece (+5 bit 1) and adds 2 to E, a second (double check) clears $BD4E and adds $14 to A'.
  $8D2A,5 First pass: abort
  $8D2F,4 Flag check
  $8D33,7 Already a check?
  $8D3A,7 First check: mark the checking piece (+5 bit 1)
  $8D41,3 E=E+2
@ $8D44 label=EvKnightDoubleCheck
  $8D44,8 Double check: $BD4E=0, A'=A'+$14
@ $8D4C label=EvSliderChecksKing
c $8D4C Slider attacks the enemy king
D $8D4C As #R$8D2A, then the ray carries on beyond the king (#R$8DAA), counting mobility.
  $8D4C,5 First pass: abort
  $8D51,4 Flag check
  $8D55,7 Already a check?
  $8D5C,9 First check: mark the checking piece (+5 bit 1)
  $8D65,5 E=E+2; continue the ray
  $8D6A,10 Double check: $BD4E=0, A'=A'+$14; continue the ray
@ $8D74 label=EvWhiteBishop
c $8D74 White bishop
D $8D74 Used by #R$8400. A bishop on its back rank costs 3.
R $8D74 A Square
  $8D74,6 On rank 1?
@ $8D7A label=EvBishopBackRank
  $8D7A,6 E=E-3
@ $8D80 label=EvBlackBishop
c $8D80 Black bishop
D $8D80 Used by #R$8400.
R $8D80 A Square
  $8D80,6 On rank 8: penalty
@ $8D86 label=EvBishop
  $8D86,3 C'=$04
@ $8D89 label=EvDiagonals
  $8D89,3 E'=$C4 (pieces that move diagonally, and pawns)
  $8D8C,9 Up-left (+15)
  $8D95,9 Up-right (+17)
  $8D9E,9 Down-right (-17)
  $8DA7,3 Down-left (-15)
@ $8DAA label=EvRayStep
  $8DAA,5 Next square; stop off the board
@ $8DAF label=EvRaySquare
c $8DAF Diagonal ray: next square and hits
D $8DAF Part of #R$8D89 (also used after a king is passed). Every square up to and including the first piece adds 1 to E.
  $8DAF,4 Count mobility; empty: continue
  $8DB3,6 L'=record+4; friendly (#R$8DEC)?
@ $8DB9 label=EvEnemyHit
  $8DB9,5 Enemy king (#R$8D4C)?
  $8DBE,5 Attacker count +weight (record +2)
  $8DC3,6 Enemy also moves along this line (record +6 AND E', not a pawn)?
  $8DC9,3 No: look for what it shields (#R$8E19)
  $8DCC,9 Yes: look beyond it
  $8DD5,7 D'=record+6 of the first piece; friendly beyond?
  $8DDC,5 Enemy beyond: x-ray attacker (+3)
@ $8DE1 label=EvPinTest
  $8DE1,6 Piece beyond is a king (+6 bit 0): pin
  $8DE7,3 A queen (+6 bit 1): pin unless the scanning piece is a queen
  $8DEA,2 Neither
@ $8DEC label=EvFriendlyHit
  $8DEC,3 Friendly: defender count +weight
@ $8DEF label=EvFriendlyHit2
  $8DEF,4 Does it move along this line?
  $8DF3,2 No: done
  $8DF5,3 A pawn: one-square x-ray (#R$8E5C)
@ $8DF8 label=EvXrayChain
  $8DF8,9 Continue the ray, counting mobility
  $8E01,6 Enemy: x-ray attacker (+3)
@ $8E07 label=EvXrayAttacker
  $8E07,1 L'=record+3 (from +4)
  $8E08,5 Add the weight
  $8E0D,8 Friendly: x-ray defender (+5); and onwards if it also moves this way
@ $8E15 label=EvXrayDefender
  $8E15,4 L'=record+5
@ $8E19 label=EvShieldTest
  $8E19,9 Look beyond the enemy piece
  $8E22,7 D'=record+6 of the first piece; an enemy piece beyond?
  $8E29,2 Friendly or nothing: done
@ $8E2B label=EvPinQueen
c $8E2B Record a pin
D $8E2B Part of #R$8DAF. The pin list at $BD79 holds up to six (record, direction) pairs terminated by 0. A piece pinned twice gets direction 0. Adds 2 to E for a new pin (1 for a repeated one; 2 if the list is full).
  $8E2B,4 Pinned against a queen by a queen: E=E+2 only (#R$8E58)
@ $8E2F label=EvRecordPin
  $8E2F,4 D' = record base of the pinned piece
  $8E33,7 Search the pin list
  $8E3A,6 Next entry
  $8E40,7 Already pinned: direction 0, E=E+1
  $8E47,5 List full (6 entries)?
  $8E4C,9 Append (record, direction) and a terminator
  $8E55,2 Flag the pin list (B' bit 5)
  $8E57,1 H'=$BE
  $8E58,4 E=E+2
@ $8E5C label=EvPawnXray
c $8E5C Bishop or queen behind a friendly pawn
D $8E5C Part of #R$8DAF. If the ray runs in the pawn's capturing direction, the piece on the square beyond the pawn (if any) gets an x-ray defence (+5) or x-ray attack (+3).
R $8E5C A Pawn's record +6 AND $C4
R $8E5C C Direction
  $8E5C,3 Ray runs in the pawn's direction?
  $8E5F,7 Next square (on the board, occupied)
  $8E66,14 Friendly: +5, enemy: +3
@ $8E74 label=EvUndoPins
c $8E74 Remove the attacks of pinned pieces
D $8E74 Used by #R$8400 when bit 5 of B' is set. For each (record, direction) in $BD79, subtracts the pinned piece's direct attacks in every direction except the pin line. E and D are preserved; B' is overwritten with the pinned piece's colour. Finally empties the list.
  $8E74,7 IY=pin list
  $8E7B,4 L'=pinned piece's record
@ $8E7F label=EvUndoPin
  $8E7F,4 Return to #R$8F1B afterwards
  $8E83,5 B'=colour; E'=square
  $8E88,6 Type AND $8E: 0 = pawn
  $8E8E,3 Bishop (#R$8EE4)
  $8E91,4 Knight (#R$8EC9)
  $8E95,2 Rook (#R$8ED5)
  $8E97,8 Queen: weight -$40 on rook lines and diagonals
@ $8E9F label=EvUndoPawnPin
  $8E9F,11 Pawn: B=square, C=+15 or -17 (left capture)
  $8EAA,5 Left capture, then right capture
@ $8EAF label=EvUndoPawnCapture
c $8EAF Undo one pawn capture direction
D $8EAF Part of #R$8E74. Skipped if the direction is along the pin line.
R $8EAF B Square
R $8EAF C Direction
  $8EAF,9 Along the pin line: keep
  $8EB8,6 Piece on the target square?
  $8EBE,11 Friendly: defender count -1; enemy: attacker count -1
@ $8EC9 label=EvUndoKnightPin
c $8EC9 Undo a pinned knight
D $8EC9 Part of #R$8E74. Re-walks the knight with weight -4 (a pinned knight attacks nothing). B' bit 4 is set so a knight 'check' is flagged rather than aborting.
  $8EC9,4 C'=-4; B' bit 4 set
  $8ECD,8 Re-walk the knight (#R$8CD2)
@ $8ED5 label=EvUndoRookPin
  $8ED5,2 Rook: C'=-$10
@ $8ED7 label=EvUndoOrthogonals
c $8ED7 Undo rook-line attacks
D $8ED7 Part of #R$8E74.
  $8ED7,2 B=square
  $8ED9,6 Horizontal
  $8EDF,5 Vertical
@ $8EE4 label=EvUndoBishopPin
  $8EE4,4 Bishop type? (otherwise treat as a pawn)
  $8EE8,5 C'=-4
@ $8EED label=EvUndoDiagonals
  $8EED,5 Diagonal +15/-15
  $8EF2,2 Diagonal +17/-17
@ $8EF4 label=EvUndoLine
c $8EF4 Undo the attacks along one line
D $8EF4 Part of #R$8E74. Skipped if the line is the pin line; otherwise both directions.
R $8EF4 C Direction
  $8EF4,9 Along the pin line: keep
  $8EFD,5 Forward
  $8F02,3 Backward
@ $8F05 label=EvUndoRay
c $8F05 Undo the first attack along a ray
D $8F05 Part of #R$8E74.
  $8F05,9 Find the first piece
  $8F0E,13 Friendly: +4 += C'; enemy: +2 += C'
@ $8F1B label=EvNextPin
c $8F1B Next pin-list entry
D $8F1B Return point for #R$8E7F.
  $8F1B,6 Another entry?
  $8F21,9 Yes: process it
  $8F2A,5 Done: restore DE, empty the list

; Subsystem B: pre-search set-up and move generator ($7810-$7AC6).
; Specification: docs/arch/20-board-movegen.md
;
@ $7810 label=PRESEARCH
c $7810 Pre-search set-up: evaluation, material balance and game-phase flags
D $7810 Called once before each computer search (from #R$7BE1 and #R$6D4D). Evaluates the current position with the side-to-move bit temporarily flipped, then derives $BD1E (score bias), $BD4A (accumulator), $BD2E (material difference x8, clamped) and the game-phase bits 1-4 of $BD2D. Bit 0 of $BD2D is left as it was on entry.
R $7810 O:A Result of the evaluation call at $781C (flags set by OR A)
C $7810 IX = root move record at $BD58 (the last move played in the game)
C $7814 Flip bit 0 of $BD2D (side to move) for the evaluation call
C $781C Evaluate (returns score in A and a second value in B)
C $781F Keep the evaluation result for the return value
C $7820 E = ($BCA0) + $80 (signed: previous root score re-biased)
C $7826 If $BCBE is non-zero, negate B and E
C $782C B = -B
C $782F E = -E
C $7832 A = old $BD2E (material difference x8 from the previous call)
C $7835 A = A SRA 1
C $7837 E = E SRA 1
C $7839 A = A + E
C $783A A = A SRA 2
C $783E If the result is non-zero, add 1 (rounds towards +infinity)
C $7841 Store in $BD1E
C $7844 $BD4A = $BD4A + B (8-bit, wraps)
C $784B HL = White piece records from the queen ($BE08); 15 records follow
C $784E Clear the pawns-present flag $BD6D
C $7852 C = White material (sum of value nibbles)
C $7855 E = White material
C $7856 HL = Black piece records from the queen ($BE88)
C $7858 C = Black material
C $785B A = Black - White material (8-bit)
C $785D 0..13: keep
C $7861 -14..-1: keep
C $7865 Otherwise clamp: +14 if positive, -14 if negative
C $786C Multiply by 8 (range -112..+112)
C $786F Store the material difference term in $BD2E
C $7872 A = move number ($BD49)
C $7875 B = phase bits = 0
C $7877 Before move 8: phase bits stay 0 (opening)
C $787B A = total material of both sides (Black + White)
C $787D Phase bit 1: move number >= 8
C $787F Total >= 52: done (bits = %00010)
C $7883 Phase bit 2: total < 52
C $7885 Total >= 40: done (%00110)
C $7889 Phase bit 3: total < 40
C $788B Total >= 25: done (%01110)
C $788F Phase bit 4: total < 25 (%11110)
C $7891 $BD2D = (restored side bit) + phase bits
C $7895 Flip bit 0 back to its value on entry
C $7898 Add the phase bits (bits 1-4)
C $789A Return the evaluation result
@ $789D label=MATERIAL
c $789D Sum material of one side's non-king pieces
D $789D Adds the value nibble (+1 AND $0F) of 15 piece records starting at HL (stride 8), skipping records whose square byte has bit 7 set (captured). Sets $BD6D to 1 if any record has value 1 (a pawn).
R $789D HL Address of the first record to count ($BE08 or $BE88)
R $789D O:C Total material (8-bit)
C $789D C = running total
C $789F B = 15 records (Q, R, R, B, B, N, N, P x 8)
C $78A1 Skip if captured (square byte bit 7 set)
C $78A5 A = value nibble of the type byte
C $78A9 A pawn?
C $78AD Yes: $BD6D = 1 (pawns present)
C $78B0 C = C + value
C $78B2 Back to the square byte
C $78B3 Next record (+8)
@ $78BA label=POLLGEN
c $78BA Poll the keyboard, then generate moves
D $78BA Called by the search (#R$7D43) at every node where moves are generated. If no abort is pending, any key held down sets the abort flag ($BD4C bit 7) and updates the display via #R$7562. Then falls through to #R$78CE.
C $78BA Abort already pending ($BD4C bit 7)?
C $78BF Yes: just generate
C $78C1 Any key pressed? (prints *INTERRUPTED* if so)
C $78C4 No: generate
C $78C6 Set the abort flag
C $78CB Update the display for the interrupt
@ $78CE label=GENMOVES
c $78CE Generate pseudo-legal moves for the side in $BD2D bit 0
D $78CE Writes the move list for ply ($BCA9) starting at the address in the ply table ($BCA9+2*ply): a 4-byte header followed by one 4-byte entry per move (score $FF, from, to, flags) and an $FF terminator. Stores the end address in the next ply-table slot and returns the count in E.
D $78CE Generation order: castling (kingside, queenside), king steps, queen, rook ($BE10), rook ($BE18), bishop ($BE20), bishop ($BE28), knight ($BE30), knight ($BE38), then the 8 pawn slots ($BE40-$BE78) in order. A promoted piece in a pawn slot moves according to its type byte.
D $78CE Register usage: main set B = from-square, H = $BD (board page), L = target square, C = $88 off-board mask (overwritten by direction in the slide loop), DE = list write pointer. Alternate set: B = loop counter, C = side-to-move (bit 7: 1 = Black), DE = direction-table pointer, HL = pawn-record pointer. A' = $BC (list-full check in #R$7A9D).
R $78CE IX Parent move record (flags bit 7 = in check suppresses castling; bit 5 + to-square drive en passant)
R $78CE O:E Move count (only correct for fewer than 127 moves; see docs)
R $78CE O:HL Address of header byte +3
C $78CE HL = $BCA9 + 2 * ply: ply-table slot for this ply
C $78D5 DE = start of this ply's list (header address)
C $78D8 HL = next ply-table slot (will receive the end address)
C $78D9 Save the list start
C $78DA DE = start + 4 (first move entry)
C $78DE Save the next ply-table slot address
C $78DF A' = $BC: page at which the list is close to full
C $78E3 H = board page
C $78E5 IY = White piece records
C $78E9 C' = $BD2D rotated right: bit 7 = side to move (1 = Black)
C $78F0 Black to move: IY = Black piece records
C $78F6 B = king square
C $78F9 King not yet moved: try castling
C $7900 C = $88 off-board mask
C $7903 King steps: 8 directions from $7808 (diagonals, then orthogonals)
C $7909 Queen (IY+$08) present: slide in 8 directions
C $7910 Rook (IY+$10) present: slide in 4 directions
C $7917 Rook (IY+$18) present
C $791E Bishop (IY+$20) present: slide in 4 diagonals
C $7925 Bishop (IY+$28) present
C $792C Knight (IY+$30) present: 8 jumps from $7800
C $792F Restore C = $88 (the slide loops use C for the direction)
C $7935 Knight (IY+$38) present
C $793C C = pawn capture offset: +$11 (White, up-right)...
C $793F HL' = White pawn records ($BE40)
C $7942 Black to move?
C $7946 HL' = Black pawn records ($BEC0)
C $7949 ...or $F1 (Black, -15 = down-right)
N $794C Pawn-slot loop (alternate set).
C $794C Captured (square bit 7 set)?
C $794E Yes: next slot
C $7950 A = type byte
C $7953 Bits 1-3 non-zero: a promoted piece (Q 9, R 5, B $83, N 3)
C $7955 A = square
C $7957 B = from-square
C $7958 Promoted piece: generate as that piece
C $795A L = from + C (diagonal capture to the right; NOT checked for off-board)
C $795C Occupied?
C $795E Yes: add a capture if it is an enemy piece
C $7961 L = from + C - 2 (diagonal capture to the left; not checked for off-board)
C $7963 Occupied?
C $7965 Yes: add a capture if it is an enemy piece
C $7968 L = forward square
C $7969 Forward square occupied?
C $796B Yes: only en passant can follow
C $796D Add the single push (flags 0); promotion is detected later by make
C $7970 From-square on the home rank (rank 2 White / rank 7 Black)?
C $7975 No: try en passant
C $7977 L = forward + C - 1 (two squares ahead); skip if past rank 8 (sign)
C $797E Two squares ahead occupied?
C $7980 Yes: next slot
C $7982 Add the double push (flags 0)
C $7985 Square left of the landing square holds an enemy pawn?
C $7987 Yes: flag the double push $20 (en passant possible)
C $798A Square right of the landing square
C $798E Enemy pawn there: flag $20
C $7991 Next slot (no en passant from the home rank)
C $7994 Previous move a double push next to a pawn (flags bit 5)?
C $7998 Yes: try the en passant capture
C $799C Next pawn slot (+8)
C $79A0 Loop while L bit 6 is set ($40-$78 or $C0-$F8)
N $79A5 All pieces done: terminate the list and write its header.
C $79A5 Back to the main set
C $79A6 Terminator: $FF at +0 of the entry after the last move
C $79A9 HL = next ply-table slot
C $79AA Store the end address (= this terminator) there
C $79AD HL = list start
C $79AE HL = end, DE = start
C $79AF HL = end - start = 4 * (n + 1)
C $79B2 L = (H bit 0, L) >> 2: this drops H bit 1, so it is only right for n < 127
C $79B8 L = n (number of moves)
C $79B9 E = n, HL = list start (header)
C $79BA Header +0 = $FF
C $79BB Header +1 = n
C $79BD Header +2 = 0
C $79C0 Header +3 = parent flags AND $81 (bit 7 in check, bit 0 pawn to 6th/7th)
@ $79C8 label=GEN_PROMOTED
N $79C8 A promoted piece in a pawn slot. The return address is set to #R$79E0 so that the piece routine returns into the pawn loop.
C $79C8 Save B (from-square) and C (pawn capture offset)
C $79C9 C = $88 off-board mask (for knight steps)
C $79CC A = type byte
C $79CF Return to $79E0 when done
C $79D3 Bit 7 set: bishop
C $79D7 Bit 1 set: knight
C $79DB Bit 2 set: rook
C $79DE Otherwise: queen
@ $79E0 label=GEN_PROMOTED_RET
c $79E0 Return point after generating a promoted piece's moves
D $79E0 Reached by RET from a piece routine (address pushed at $79CF). Restores B and C, then continues the pawn-slot loop at #R$799C in the alternate register set.
C $79E0 Restore B (from) and C (pawn capture offset)
C $79E2 Continue the pawn-slot loop at $799C
@ $79E4 label=GEN_EP
c $79E4 Generate an en passant capture
D $79E4 Called for a pawn when the parent move's flags have bit 5 set. If that move was not itself a capture (bit 3 clear) and landed directly beside this pawn, adds the en passant capture to the square behind the enemy pawn, with flags $28.
R $79E4 B From-square of the capturing pawn
R $79E4 L Forward square of the capturing pawn
C $79E4 Parent move was a capture ($28): not a double push
C $79E9 Enemy pawn landed on from + 1?
C $79EE Yes: capture towards forward - 1
C $79F0 Enemy pawn landed on from - 1?
C $79F3 No: return
C $79F4 Target = forward + 1
C $79F6 Target = forward - 1 (or +1 after the two INCs)
C $79F7 Flags $28: capture + en passant
C $79F9 Add the move
@ $79FC label=GEN_EPFLAG
c $79FC Flag a double push next to an enemy pawn
D $79FC Called after a double push with A = piece code beside the landing square. If it is an enemy pawn (value 1, any advancement), sets the flags byte of the move just added to $20.
R $79FC A Piece code beside the landing square
R $79FC HL Address of that square
C $79FC Same colour as the mover?
C $79FF Yes: nothing to do
C $7A00 A = piece code
C $7A02 Save L'
C $7A03 L' = code - 3 = record offset + 1 (type byte); H' = $BE
C $7A06 A = type byte
C $7A07 Restore L'
C $7A09 Value 1 (pawn)?
C $7A0C No: return
C $7A0D Yes: flags of the last move entry = $20
@ $7A13 label=GEN_KNIGHT
c $7A13 Generate knight moves
R $7A13 A From-square
C $7A13 B = from-square
@ $7A15 label=GEN_KNIGHT_X
C $7A15 DE' = knight offsets at $7800
@ $7A18 label=GEN_STEPS
c $7A18 Generate single-step moves in 8 directions (king, knight)
D $7A18 For each of 8 offsets at DE': target = from + offset. Skips off-board squares (C = $88), adds a quiet move to an empty square, and adds a capture of an enemy piece.
R $7A18 DE' Direction table
R $7A18 B From-square
R $7A18 C $88
C $7A18 8 directions
C $7A1A A = offset
C $7A1D L = from + offset
C $7A1F Off the board?
C $7A22 Empty: add a quiet move (returns Z)
C $7A26 Occupied: add a capture if it is an enemy piece
@ $7A2E label=GEN_ROOK
c $7A2E Generate rook moves
R $7A2E A From-square
C $7A2E B = from-square
@ $7A30 label=GEN_ROOK_X
C $7A30 DE' = orthogonal offsets at $780C (+1, -1, +16, -16)
@ $7A33 label=GEN_SLIDE4
C $7A33 4 directions
@ $7A35 label=GEN_SLIDE
N $7A35 Slide loop: for each direction, step until off the board or blocked.
C $7A35 A = direction
C $7A38 C = direction (overwrites the $88 mask)
C $7A39 L = from-square
C $7A3A L = L + direction
C $7A3D Off the board: next direction
C $7A41 Empty: add a quiet move and keep sliding
C $7A47 Occupied: add a capture if it is an enemy piece, then stop
@ $7A4F label=GEN_BISHOP
c $7A4F Generate bishop moves
R $7A4F A From-square
C $7A4F B = from-square
@ $7A51 label=GEN_BISHOP_X
C $7A51 DE' = diagonal offsets at $7808 (+15, +17, -17, -15), 4 directions
@ $7A57 label=GEN_QUEEN
c $7A57 Generate queen moves
R $7A57 A From-square
C $7A57 B = from-square
@ $7A59 label=GEN_QUEEN_X
C $7A59 DE' = $7808: 4 diagonals, then 4 orthogonals
C $7A5C 8 directions
@ $7A61 label=GEN_CASTLE
c $7A61 Generate castling moves
D $7A61 Called only if the king's type byte has bit 4 (moved) clear. Kingside first: the rook in record +$18 must be present and unmoved, and the two squares to the king's right must be empty. Queenside: the rook in record +$10 must be present and unmoved, and the three squares to the king's left must be empty. No square is tested for attack here, and the rook's actual square is not checked. Castling moves get flags $10.
R $7A61 B King square
R $7A61 IX Parent move (flags bit 7 set = side to move is in check: no castling)
C $7A61 In check: no castling
C $7A66 Kingside rook moved?
C $7A6C Kingside rook captured?
C $7A72 King + 1 empty?
C $7A78 King + 2 empty: add O-O
C $7A7D Queenside rook moved?
C $7A82 Queenside rook captured?
C $7A87 King - 1 empty?
C $7A8C King - 2 empty?
C $7A8F King - 3 empty?
C $7A92 Target = king - 2: add O-O-O
@ $7A93 label=ADD_CASTLE
c $7A93 Add a castling move (flags $10)
C $7A93 A = $10 (castling) and add the move
@ $7A97 label=ADD_CAPTURE
c $7A97 Add a capture if the target holds an enemy piece
R $7A97 A Piece code on the target square
C $7A97 Same colour as the side to move?
C $7A9A Yes: no move
C $7A9B Flags $08: capture
@ $7A9D label=ADD_MOVE
c $7A9D Append a move to the list
D $7A9D Writes score $FF, from (B), to (L) and flags (A) at DE and advances DE by 4. When DE reaches $BC81 or beyond, the move is not written; instead the search abort flag ($BD4C bit 7) is set. The list area is therefore $B400-$BC83.
R $7A9D A Flags
R $7A9D B From-square
R $7A9D L To-square
R $7A9D DE List write pointer
R $7A9D O:A Flags (Z set if the flags are 0)
C $7A9D A = $BC (from A'); A' = flags
C $7A9E Pointer in page $BC?
@ $7AA1 label=ADD_MOVE_WRITE
C $7AA1 A = flags
C $7AA2 HL = list pointer
C $7AA3 +0 score = $FF (not yet scored)
C $7AA5 +1 from-square
C $7AA7 +2 to-square
C $7AA9 +3 flags
C $7AAB Next entry (16-bit increment)
C $7AAD Z if the flags are 0
@ $7AAF label=ADD_MOVE_FULL
C $7AAF Still room while the low byte <= $80
C $7AB6 List full: set the abort flag $BD4C bit 7
C $7ABD A = flags
@ $7AC0 label=BOOK_OFF
N $7AC0 Used by the book probe (#R$7AC7): mark the game as out of book.
C $7AC0 $BCDF = $FF: out of book
C $7AC5 Return NZ

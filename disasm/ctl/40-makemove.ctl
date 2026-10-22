; Subsystem B: search helpers at $80A7-$810E, make/unmake move ($810F-$828B).
; Specification: docs/arch/20-board-movegen.md
;
@ $80A7 label=PRUNE_TEST
c $80A7 Move-list pruning: test a low-scored move (jump target of #R$805F)
D $80A7 Part of the pruning loop in #R$805F, which reaches this code by JP (IY) when a move's score byte is below the threshold C, with A = score - C (negative) and HL pointing at the move's flags byte (+3). A pruned move gets score 0 (treated as already searched) unless its flags AND $C9 is non-zero (check, bit 6, capture or pawn-to-6th/7th). The loop continues at #R$809C.
D $80A7 There are three variants, selected by IY in #R$805F. $80A2 (default; in the search file) prunes if score < C - 16, or if score < C and flags bit 2 is set. $80A7 (game-phase bit 3 of $BD2D set) prunes if score < C and flags bit 2 is set. $80BB (ply < 3 only; it also decrements D) prunes if score < C - 16 and flags bit 2 is set. $80AB is the shared "prune unless flags AND $C9" step.
R $80A7 A Score - threshold (negative)
R $80A7 HL Address of the move's flags byte
C $80A7 Flags bit 2 clear: keep the move
@ $80AB label=PRUNE_ZERO
C $80AB Flags AND $C9 non-zero (check, bit 6, capture, pawn-to-6th/7th): keep
C $80B0 Otherwise set the score byte (+0) to 0: pruned
C $80B5 Back to the flags byte
C $80B8 Next move
@ $80BB label=PRUNE_ENDGAME
C $80BB D = D - 1
C $80BC Score >= threshold - 16: keep
C $80C1 Otherwise test flags bit 2 as at $80A7
@ $80C4 label=HORIZON_CUT
c $80C4 Search: cut-off test at the depth limit
D $80C4 Called from #R$7D43 with A = ply when the ply equals the iteration depth ($BCAA). On even plies only: if $BD09 is not negative (bit 7 clear), and $BD09 < C (unsigned), and the 8-bit difference $BD09 - C is below the byte at $BC9E + ply (unsigned), and the current list header +3 bit 0 (parent was a pawn move to the 6th/7th rank) is clear, the move just made is unmade and the search returns to the previous ply via #R$7E79 (discarding this routine's return address). Search-subsystem semantics: see docs/arch for the search.
R $80C4 A Ply
R $80C4 C Score to compare
C $80C4 Odd ply: return
C $80C7 HL = $BC9E + ply
C $80CC A = $BD09: negative means return
C $80D1 A = $BD09 - C: no borrow means return
C $80D3 A >= ($BC9E + ply): return
C $80D5 HL = header +3 of the current list
C $80D8 Bit 0 set (parent pawn move to 6th/7th): return
C $80DB Discard the return address
C $80DC Unmake the current move
C $80DF Back up one ply
@ $80E2 label=SRCH_MAKE_BEST
N $80E2 Entry from #R$7D43: make the best root-scored move ($BD1A).
C $80E2 IX = best move entry
C $80E6 Score byte = 0 (selected)
C $80EA Make it and descend
@ $80ED label=SRCH_NEXT_MOVE
N $80ED Entry from #R$7D43: select the highest-scored remaining move.
C $80ED DE = first entry with the highest score (#R$8015)
C $80F0 None left (E still odd): return from this ply
C $80F5 IX = selected move
C $80F8 Score byte = 0 (selected)
@ $80FA label=SRCH_MAKE_DESCEND
C $80FA Make the move
C $80FD Ply 1: remember the root move ($7E06)
C $8104 Otherwise set bit 7 of $BC83 + 2 * (ply - 1)
C $810C Toggle the side and descend ($7E0A)
@ $810F label=MAKEMOVE
c $810F Make a move
D $810F Applies the move at IX (+1 from, +2 to, +3 flags) to the board ($BD00) and the piece records ($BE00). Pushes restore information under its return address, so the caller's stack grows by 4 bytes (quiet move) or 6 bytes (capture, en passant, castling). Each make must be undone by #R$821C before the caller returns. Returns via JP (HL) in the main register set; the alternate set is used throughout.
D $810F Stack frame (top first): [type byte, marker] then, for captures/en passant/castling, [square, piece code] of the captured pawn/piece or the castling rook, then [from-square, moving piece code]. The marker byte is popped into F by #R$821C: $80 quiet (S), $84 quiet promotion (S, P/V), $00 capture, $04 capture-promotion (P/V), $01 en passant (C), $40 castling (Z).
D $810F Side effects: the type byte of the moving piece is updated (moved bit 4; pawn advancement nibble; promotion to $19; king centralisation bits 6-7 and castled bit 5). Captured piece: square byte bit 7 set. $BD0D (material balance, Black minus White, pawn units) is adjusted by captures and promotions. Flags bit 0 of the move is set for a pawn move to the 6th or 7th rank and cleared for a promotion. Castling with score byte +0 = $FF puts the KING's piece code (not the rook's) on the rook's destination square.
R $810F IX Move entry
C $810F HL = return address (kept in the main set)
C $8110 Work in the alternate set
C $8111 HL = board[from]
C $8116 E = moving piece code; D = from-square
C $8118 Push [from, piece]
C $8119 board[from] = 0
C $811B C = piece code on the to-square (0 if empty)
C $811F board[to] = moving piece
C $8120 B = to-square
C $8121 HL = moving piece's record ($BE00 + code AND $FB)
C $8125 Record square = to
C $8126 HL = record type byte
C $8127 E = from-square
C $8128 D = old type byte (saved for unmake)
C $8129 Value 0: king
C $812F Value 1: pawn
C $8132 Other pieces: set the moved bit 4
C $8134 Something on the to-square: capture
@ $8138 label=MK_QUIET
C $8138 Marker $80: quiet move
@ $813A label=MK_PUSHRET
C $813A Push [old type, marker]
C $813B Return
@ $813D label=MK_PAWN
N $813D Pawn move. A = relative rank of the to-square x 16 (from the mover's side).
C $813D A = to-square rank x 16
C $8140 Black (rank below the from-square): mirror the rank (XOR $70)
C $8145 Relative rank < 3 (to 2nd/3rd rank): type unchanged
C $8149 Relative rank 3 (4th rank): type $11
C $814B Relative rank 4 (5th rank): type $31
C $814F Rank 6 or more: set flags bit 0 (pawn to 6th/7th)
C $8153 Relative rank 5 (6th rank): type $61
C $8159 Relative rank 6 (7th rank): type $91
N $815D Promotion (always to a queen).
C $815D Clear flags bit 0
C $8161 Type = $19 (queen, moved)
C $8163 $BD0D: -8 for White, +8 for Black (queen 9 - pawn 1)
C $8171 Marker $84: quiet promotion
C $8173 No capture: push the marker and return
C $817A Marker $04: capture-promotion
@ $817F label=MK_PAWN_TYPE
C $817F A = $11 + $20 or $11 (type for the 5th or 4th rank)
@ $8183 label=MK_PAWN_SETTYPE
C $8183 Store the new pawn type byte
@ $8184 label=MK_PAWN_FLAGS
C $8184 Not a capture (flags bit 3 clear): quiet pawn move
C $818C Capture without bit 5: ordinary capture
N $8191 En passant: remove the pawn behind the to-square.
C $8191 Captured pawn square = to - 16 (White) or to + 16 (Black)
C $8199 C = captured pawn code; board[that square] = 0
C $819E B = captured pawn square
C $81A0 Marker $01: en passant
@ $81A5 label=MK_CAPTURE
C $81A5 Marker $00: capture
@ $81A7 label=MK_CAPTURE_X
C $81A7 Push [captured square, captured code]
C $81A8 HL = captured piece record
C $81AB Mark captured (square byte bit 7)
C $81AD Push [old type, marker]
C $81AE A = captured value; negated if the captured piece is Black
C $81B8 $BD0D = $BD0D + A
C $81BD Return
@ $81BF label=MK_KING
N $81BF King move.
C $81BF Update the king's type byte (moved, centralisation)
C $81C2 Neither capture nor castling: quiet king move
C $81CA King capture: ordinary capture
N $81CF Castling.
C $81CF Type byte bit 5: has castled
C $81D1 HL = board page
C $81D2 Queenside if to-square bit 2 is clear (c-file)
C $81D6 Kingside: rook on to + 1; C = rook code; clear its square
C $81DB Rook destination = to - 1
C $81E0 Queenside: rook on to - 2; C = rook code; clear its square
C $81E6 Rook destination = to + 1
@ $81E9 label=MK_CASTLE_ROOK
C $81E9 Rook to its destination
C $81EA Score byte $FF: put the king's code there instead (C AND $84)
@ $81F4 label=MK_CASTLE_PUSH
C $81F4 Push [rook origin, rook code]
C $81F5 Rook record square = destination
C $81FB Marker $40: castling
C $81FD Push [old type, marker] and return
@ $8200 label=KINGTYPE
c $8200 Set a king's type byte: moved bit and centralisation
D $8200 Sets the moved bit, clears bits 6-7, then adds $40 for each ring k = 1, 2, 3 for which both to + $11k and to - $11k are on the board. This gives bits 6-7 = min(file, rank, 7 - file, 7 - rank), capped at 3. #R$660A uses entry $8203 when setting up a position.
R $8200 B King square
R $8200 D Old type byte
R $8200 HL Address of the king's type byte
C $8200 A = old type + moved bit
@ $8203 label=KINGTYPE_X
C $8203 Clear bits 6-7
C $8205 E = $11 (diagonal step)
@ $8207 label=KINGTYPE_LOOP
C $8207 Store the type byte
C $8208 Square + E off the board: done
C $820D Square - E off the board: done
C $8212 E = E + $11
C $8216 Type byte + $40
@ $821C label=UNMAKE
c $821C Unmake a move
D $821C Undoes the most recent #R$810F using the data it pushed. The marker is popped into F: P/V set (promotion) reverses the $BD0D promotion adjustment; S set (quiet) restores only the mover; Z (castling) restores the rook; C (en passant) puts the captured pawn back on its square; otherwise (capture) the captured piece goes back on the to-square and its record is restored. The mover's square and type byte are restored from the frame.
C $821C HL = return address (kept in the main set)
C $821E A = old type byte, F = marker
C $821F HL = [square, code] of the captured piece/rook, or [from, mover] for a quiet move
C $8220 C = old type byte
C $8221 A = 0 (flags unchanged)
C $8223 D = board page
C $8225 Promotion: undo the $BD0D adjustment
C $8228 Quiet move
C $822B Castling
C $822D En passant
C $822F B = captured piece code
@ $8230 label=UN_RESTORE_CAP
C $8230 HL = captured piece record; clear its captured bit
C $8236 A = its value, negated if the piece is White
C $8240 $BD0D = $BD0D + A
C $8245 A = code to put back on the to-square
@ $8246 label=UN_POP_MOVER
C $8246 HL = [from, mover]
@ $8247 label=UN_RESTORE_MOVER
C $8247 board[from] = mover
C $824B HL = mover's record; B = its square (the to-square)
C $8250 Record square = from
C $8251 Record type = old type byte
C $8253 board[to] = A (captured code, or 0)
C $8256 Return
@ $8258 label=UN_EP
C $8258 En passant: board[captured square] = captured pawn
C $8259 A = 0 for the to-square
C $825C Restore the captured pawn's record and the mover
@ $825F label=UN_CASTLE
C $825F Castling: board[rook origin] = rook
C $8262 Rook record square = origin (B = destination)
C $8268 board[rook destination] = 0
C $826B Restore the king
@ $826E label=UN_PROMO_FIX
c $826E Undo the $BD0D promotion adjustment
D $826E Adds 8 to $BD0D for a White promotion, or subtracts 8 for Black. The value S of the caller's flags tells this apart: S set means a quiet promotion, so L is the mover's code; S clear means a capture-promotion, so L is the captured piece's code and the colour test is reversed. Preserves F via EX AF,AF'.
R $826E L Piece code (see above)
C $826E S clear (capture-promotion): reverse the colour test
C $8272 A = $BD0D
C $8275 Mover is White?
@ $8279 label=UN_PROMO_SUB
C $8279 A = A - $10 (then + 8 = net -8 for Black)
@ $827B label=UN_PROMO_ADD
C $827B A = A + 8
C $8280 Restore flags
@ $8282 label=UN_PROMO_CAP
C $8282 Capture-promotion: L is the captured piece (opposite colour)
s $828C Unused (zero bytes up to $8400)

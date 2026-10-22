; Cyrus IS Chess (48K) - main loop, user interface and game management
; Range $6000-$780F. See docs/arch/10-main-ui.md.
;
; Board orientation reminder: internal 0x88 row 0 is rank 8 and row 7 is rank 1
; (g1=$76, f3=$55). White pieces have piece-code bit 7 set and live in the
; piece list at $BE80; Black pieces live at $BE00. $BD2D bit 0 = 1 means White
; to move.
@ $6000 label=Start
c $6000 Program entry and title
D $6000 Entered by JP $6000 from the CLoad48 loader. Disables NEW (RAMTOP/P-RAMT set to $1111), saves IY and the CHARS system variable, clears the screen and beeps. If a key is held down at this point the copyright message is shown (with beeps) until a key is pressed again; otherwise the program falls straight through to the cold start at #R$605B.
C $6000 Set RAMTOP and P-RAMT to $1111 (makes BASIC NEW unusable)
C $6009 Interrupts stay disabled except while waiting for a key (#R$675A)
C $600A Save IY for ROM calls (restored in #R$675A)
C $600E Save CHARS; #R$7226 uses this copy for the font
C $6014 Clear the screen
C $6017 Print position (18,0)
B $601A,2 Inline arguments: row, column
C $601C Clear the command area
C $601F Beep
B $6022,2 Inline arguments: duration, pitch
C $6024 Corrupt CHARS (HL=$BCD2 left over from the beep routine); the program's own text output uses the copy at $BCD5
C $6027 No key pressed: go to the cold start
@ $602C label=TitleLoop
C $602C Print the copyright message at (0,0)
B $602F,2 Inline arguments: row, column
T $6031,31
B $6050,1 Last character (bit 7 set)
C $6051 Beep
B $6054,2 Inline arguments: duration, pitch
C $6056 Loop until a key is pressed
@ $605B label=ColdStart
c $605B Cold start: default options
D $605B Sets the default options (Level 2, sound on, listing off, normal orientation, default colours) and starts a new game.
C $605B Level index $BCCD = 1 (Level 2) and search level $BCBD = 1; listing flag $BCD4 = 1 (listing OFF)
C $6066 Orientation normal, next-best off, start move number 0 (forces a cleared record below), print-record off, replay off, sound on
C $6079 Default colour scheme
C $607C Clear the printer buffer
@ $607F label=NewGameConfirmed
c $607F New game
D $607F Entered after G and Y (#R$6985). If the last game did not start from the standard position its record is discarded ($C058=$FF); otherwise the record is kept so that F (take-forward) can replay it. Cyrus plays Black.
C $607F $C006 = start move number: 1 means the game started from the standard initial position
C $6085 Not a standard game: empty the game record
C $608A $BCC2 = 1: HUMAN v CYRUS
@ $608F label=NewGameNoConfirm
C $608F No replay target
C $6095 Clear the screen and beep
B $609B,2 Inline arguments: duration, pitch
C $609D Listing on: print a rule on the ZX Printer
@ $60A4 label=NewGameBoard
C $60A4 Set up the initial position (#R$6505)
@ $60A7 label=GameStartCommon
N $60A7 Common entry for a new game, a take-back replay (#R$68B2) and the exit from set-up mode (#R$6ECC).
C $60A7 Game record ply count $C001 = 0
C $60AD Promotion counter $C047 = 0; opening book enabled ($BCDF = 0)
C $60B4 Clear the move display lines
@ $60B7 label=MainLoop
c $60B7 Main loop
D $60B7 One iteration per ply. Handles automatic replay (R), the replay-to-target used by take-back/forward/next-best, the draw tests, the status display, and then hands control to the computer (#R$6147) or the human (#R$61C8).
D $60B7 Note that the draw tests are skipped while a replay target is set ($C003 non-zero).
C $60B7 Reset the stack (discards the undo information pushed by game moves)
C $60BA Replay mode (R key) off: skip
C $60C0 Next record byte; $FF = end of record: stop replaying
C $60CC Redraw the board
C $60CF Pause about 2.5 s between replayed moves, polling the keyboard; a key stops the replay. No pause while printing the record ($BCDB)
@ $60E3 label=MainLoopReplayCheck
C $60E3 Replay target set ($C003): replay one more ply (#R$6690)
C $60EB Stir the random accumulator $BCCE with R
C $60F6 Repetition counter $BD5E = 6: draw by repetition
C $60FE 50-move counter $BD0A >= 100 plies: draw
C $6106 Game not over
C $610A Clear the message lines and show the level, players, listing and sound status
C $611F Next-best in progress ($BCDD): Cyrus plays the side to move ($BCBE = side to move XOR 1) and moves now
C $6134 White to move: Cyrus moves if $BCBE = 0, otherwise the human moves
C $6143 Black to move: the human moves if $BCBE = 0, otherwise Cyrus moves
@ $6147 label=ComputerMove
c $6147 Computer move
D $6147 Generates and scores the legal moves (to detect mate/stalemate), runs the search (#R$7BE1) and plays the move it leaves at ($BD29).
D $6147 In problem mode (level index $BCCD >= 8) the move is only played if the search found a mate ($BCA0 >= $FE); otherwise NO MATE FOUND is shown and set-up mode is entered.
C $6147 HUMAN v HUMAN ($BCC2 = 0): just swap sides
C $614E $BD4C = $40: bit 6 = computer's move (promotions are to a queen without asking); bit 7 (abort) clear
C $6153 Generate the root moves (IX=$BD58 = last game move) and score each one with make/evaluate/unmake (#R$7B96)
C $615D Best score 0: no legal move - checkmate or stalemate
C $6164 Print-record mode off
C $6168 Unless a next-best search is in progress, clear the root exclusion list at $BF00
C $616F Redraw the board without the cursor
C $6172 Beep
B $6175,2 Inline arguments: duration, pitch
C $6177 Show "-Hit any key to restore control-" in the command area
C $617A Show LET ME THINK...
T $617D,14
B $618B,1 Last character (bit 7 set)
C $618C Search (#R$7BE1); the chosen move is left at ($BD29)
C $618F Beep
B $6192,2 Inline arguments: duration, pitch
C $6194 Next-best request completed
C $6198 Problem levels P1-P3 (level index >= 8): play the move only if a mate was found ($BCA0 >= $FE)
C $61A6 NO MATE FOUND: buzz and go to set-up mode
T $61AC,14
B $61BA,1 Last character (bit 7 set)
C $61BB Buzz, then enter set-up mode
@ $61C1 label=ComputerMovePlay
C $61C1 IX = the move chosen by the search; play it
@ $61C8 label=HumanMove
c $61C8 Human move
D $61C8 Generates and scores the legal moves (so that illegal moves have score 0), shows the command list and reads the user's from- and to-squares with the cursor. The move is accepted only if it is in the generated list with a non-zero score.
C $61C8 $BD4C = 0: human's move
C $61CC Generate and score the root moves
C $61D6 No legal move: checkmate or stalemate
C $61DD Print-record mode off
C $61E1 CYRUS v CYRUS: just swap sides so that Cyrus plays this side too
C $61E9 Not HUMAN v HUMAN: refresh $BCC2 and the players display from $BCBE
C $61EF Put the cursor on the a-file of the side to move's back rank+1 (#R$70D3)
C $61F2 Command list
T $61F5,190
B $62B3,1 Last character (bit 7 set)
C $62B4 Clear the rest of the command area
@ $62B7 label=HumanMoveInput
C $62B7 YOUR MOVE?
T $62BA,13
B $62C7,1 Last character (bit 7 set)
C $62C8 No from-square chosen yet
C $62CD Read keys (commands are handled inside #R$6800) until ENTER
C $62D4 Beep
B $62D7,2 Inline arguments: duration, pitch
C $62D9 Clear message line 12
C $62E1 First ENTER: the cursor square becomes the from-square; print it at (10,10)
B $62F0,2 Inline arguments: row, column
C $62F2 Print the square and read the to-square
C $62F7 Second ENTER: the cursor square is the to-square; print it at (10,12)
B $62FD,2 Inline arguments: row, column
C $6302 Look for the move (from, to) in the root list: B = number of moves (byte 1 of the list header at $B400)
C $6311 Not found, or found with score 0 (illegal): ILLEGAL and start again
C $6318 ILLEGAL
C $631D Start a new root exclusion list; IX = the move
@ $6323 label=PlayMove
c $6323 Play a game move
D $6323 Plays the move at IX for whichever side is to move: makes it on the board, handles promotion, re-evaluates (which sets the check flag, bit 7 of IX+3), displays and prints it, appends it to the game record, updates the 50-move and repetition counters, changes the side to move, and appends it to the root exclusion list.
R $6323 IX Move (score, from, to, flags)
C $6323 Highlight the from-square and beep
C $6326 Make the move (#R$810F). It leaves its undo information on the stack; the top entry, popped as AF, has A = the moving piece's old value/flags byte and F = a move-type code: S set = not a capture, P/V set = promotion, C set = en passant
C $6329 No promotion piece to display yet
C $632D Promotion (P/V set): choose the piece (#R$63B1)
C $6332 Clear the check flag, then re-evaluate (#R$8400), which sets it again if the move gives check
C $6339 Show the move in the message area and highlight the to-square
C $633F Listing on ($BCD4 = 0): print the move on the ZX Printer
C $6346 E = index of the move in the root list (0 = first move at $B404)
C $6359 Append (check flag | index) to the game record at $C058 and terminate it with $FF; $C001 = ply count
@ $636E label=AfterGameMove
C $636E 50-move counter: count this ply, and reset it to 0 after a capture (S clear) or a pawn move (old value 1)
C $6380 Update the repetition detector (#R$6560)
C $6383 Change the side to move; increment the move number $BD49 when it is White's turn again
C $6392 Unless next-best is in progress, append (from, to) to the root exclusion list at $BF00
C $63AE Next ply
@ $63B1 label=ChoosePromotion
c $63B1 Choose the promotion piece
D $63B1 Called after a pawn has been promoted by #R$810F (which makes it a queen, value byte $19). For the computer's move ($BD4C bit 6 set) the queen is kept without asking. Otherwise the user is asked PROMOTE TO? and R, N or B under-promote by overwriting the piece's value byte (+1) with 5, 3 or $83; any other key keeps the queen. The chosen value (9 for a queen) is appended to the promotion list at $C048 (count in $C047) so that replays can repeat it, and stored in $BCDE for the move display.
R $63B1 IX Promotion move
C $63B1 Computer's move: queen
T $63BB,10
B $63C5,1 Last character (bit 7 set)
C $63C6 Piece choices
T $63C9,28
B $63E5,1 Last character (bit 7 set)
C $63E6 Wait for a key
C $63EC R = rook (5), N = knight (3), B = bishop ($83); anything else = queen (9)
C $6402 Overwrite the promoted piece's value byte: piece list entry of the piece now on the to-square, offset +1
@ $640D label=RecordPromotion
C $640D Append the piece value to the promotion list ($C047 = count, entries from $C048). Only 16 entries fit before the game record at $C058
@ $641A label=GameOverNoMoves
c $641A Game over
D $641A No legal moves: CHECKMATE if the last move gave check (bit 7 of $BD5B), else STALEMATE. Entry #R$6448 is the draw (repetition or 50 moves). The result is printed if listing is on; afterwards only the reduced command set is available ($BCBF = 1). In demonstration mode a new game starts after about 20 s unless a key is pressed.
C $641A Last move gave check?
C $6420 STALEMATE
T $6423,8
B $642B,1 Last character (bit 7 set)
C $642C Print it if listing is on
C $6434 CHECKMATE
T $6437,8
B $643F,1 Last character (bit 7 set)
@ $6448 label=GameOverDraw
C $6448 DRAWN
T $644B,4
B $644F,1 Last character (bit 7 set)
@ $6456 label=GameOverCommon
C $6456 Game over: D, E and M are no longer accepted (#R$6800)
C $645F Clear the message lines and redraw the board; beep
B $646B,2 Inline arguments: duration, pitch
C $646D CYRUS v CYRUS: wait about 20 s (9 x 65536 keyboard polls); no key: next demonstration game
C $6488 Key pressed: hand control back to the human
@ $648B label=GameOverMenu
C $648B Reduced command list
T $648E,109
B $64FB,1 Last character (bit 7 set)
C $64FC Read and execute commands until one of them leaves via the main loop
@ $6505 label=InitBoard
c $6505 Set up the standard initial position
D $6505 Clears $BD00-$BEFF (board, its off-board variables and both piece lists - the return address is held in DE because the stack lives in this area), writes set-up codes for the initial position and assigns them to piece-list slots via #R$65E5, exactly as if the position had been entered in set-up mode with untouched (castling-capable) kings and rooks. Also sets White to move, move number 1, ply 1, start move number $C006 = 1 and the first ply's move-list pointer.
C $6505 Clear 512 bytes below $BF00
C $6512 Rank 8: black pieces (set-up codes from #R$6558 with colour 0)
C $6516 Rank 7: black pawns ($41); the zeroed piece list serves as an 8-byte zero source
C $651E Rank 2: white pawns ($C1)
C $6525 Rank 1: white pieces (codes from #R$6558 | $80)
C $652A Cyrus plays Black ($BCBE = 1); White to move ($BD2D = 1); move number 1; search ply 1; standard start ($C006 = 1)
C $653B First ply's move list starts at $B400
C $6541 Mark all piece-list entries absent, then assign the pieces to slots
@ $6547 label=InitBackRank
c $6547 Write a back rank
D $6547 Writes the eight back-rank set-up codes from #R$6558 OR'ed with C.
@ $654A label=InitRank
c $654A Write a rank of set-up codes
D $654A Writes eight bytes from (DE) OR'ed with C to the board at HL, then moves HL to the start of the next row.
@ $6558 label=BackRankCodes
b $6558 Initial back-rank set-up codes
D $6558 a-h: R N B Q K B N R as set-up codes (slot offset | 1). Bit 1 is clear, so the kings and rooks are not marked as moved when they are assigned slots.
B $6558,8
@ $6560 label=TrackRepetition
c $6560 Update the repetition detector
D $6560 Called for every game move. If the move just played (from B, to C) is the exact reverse of the move played two plies earlier, the counter $BD5E is incremented, otherwise it is reset to 0. Six consecutive reversals (e.g. Nf3 Nf6 Ng1 Ng8 Nf3 Nf6 Ng1 Ng8) give $BD5E = 6, which the main loop scores as a draw. $BD59-$BD5B = (from, to, flags) of the last move and $BD5C-$BD5D = (from, to) of the move before; the root search also reads them (#R$7D04).
R $6560 IX Move just played
C $6560 Compare the move two plies back (stored as from, to) with (to, from) of this move
C $656C Reversal: count it; otherwise reset the counter
C $6575 Shift the last move into $BD5C-$BD5D, store this move's from, to and flags at $BD59-$BD5B
@ $6587 label=SetupIllegalPop
c $6587 Reject a set-up position
D $6587 Entry #R$6587 discards one return address first. Shows ILLEGAL and returns to the set-up menu.
@ $6588 label=SetupIllegal
@ $658E label=ClearBoard
c $658E Clear the board
D $658E Empties all 64 squares, then falls into #R$659C.
@ $659C label=MarkAllAbsent
c $659C Mark all piece-list entries absent
D $659C Sets bit 7 of the square byte of all 32 piece-list entries. Value bytes and the other bytes are left as they are.
@ $65A8 label=LiftPromotedPieces
c $65A8 Turn promoted pieces back into set-up codes
D $65A8 For each occupied pawn slot from HL (stepping 8 until bit 6 of L clears) whose value is not 1 (a promoted piece), frees the slot and replaces the piece on the board by the set-up code for its type (from the value byte via #R$6F2E), with bit 1 set ("entered"), so that it is reassigned a slot by #R$65E5.
@ $65DA label=AssignSetupPieces
c $65DA Assign set-up pieces to piece-list slots (set-up exit)
D $65DA First lifts promoted pieces out of the pawn slots of both sides (#R$65A8). Then (entry #R$65E5) scans the board file by file (a-file first; within a file from row 0 = rank 8 down to rank 1) and gives each square holding a set-up code (bit 0 set) a slot via #R$6610. Finally both kings must exist; the king records' bits 6-7 get the king's distance from the edge (#R$8203).
D $65DA Pieces left untouched in set-up mode keep their slots and flags. Because move generation walks the piece lists in slot order, the slot assignment order is significant.
@ $65E5 label=AssignScan
C $65E5 Scan rows (E += $10) then files
C $65FE Black king: set its edge-distance bits; then both kings must be present
@ $660A label=KingEdgeDistance
c $660A Set a king's edge-distance bits
D $660A B = king square, A = its value byte; continues in #R$8203, which stores in bits 6-7 the number of rings (0-3) between the king and the edge of the board.
@ $6610 label=AssignSlot
c $6610 Assign one set-up piece to a slot
D $6610 A = set-up code (slot offset | 3 | $80 for White, or slot offset | 1 for an untouched initial-position piece), E = square. Rules (B = value byte, C = byte +6):
D $6610 Pawn: illegal on rank 1 or 8; B=1, C=$80 (White) / $C0 (Black); first free pawn slot. King: B=0, or $30 (moved) if entered; C=1; king slot only (a second king is illegal). Queen: B=9, C=$0E; queen slot, then pawn slots. Rook: B=5, or $15 (moved) if entered; C=8; two rook slots, then pawn slots. Bishop: B=$83, C=4; two bishop slots, then pawn slots. Knight: B=3, C=0; two knight slots, then pawn slots. No free slot: illegal.
C $6610 L = set-up code - 1 (bit 1 set = entered by the user)
C $6616 Pawn: rank 8 or rank 1 is illegal
C $661F B = 1, C = $80 for White, $C0 for Black; try the pawn slots
C $662B King: B = 0 (untouched) or $30 (entered), C = 1; only the king slot
C $663F Queen: B = 9, C = $0E; queen slot then pawn slots
C $6649 Rook: B = 5 (untouched) or $15 (entered), C = 8
C $6655 Knight: B = 3, C = 0; bishop: B = $83, C = 4
C $6661 Two slots of the piece's own type
C $6664 The piece's own (first or only) slot
C $6667 Then the pawn slots
@ $6674 label=AssignSlotFail
C $6674 No slot: ILLEGAL
@ $6678 label=TryPieceSlot
c $6678 Try one piece-list slot
D $6678 If the slot at L (bit 1 cleared) is free (square bit 7 set), stores the square E, the board code (slot | 4) at (DE), the value byte B at +1 and C at +6, then returns directly to the caller's caller. Otherwise moves L to the next slot and returns.
@ $6690 label=ReplayStep
c $6690 Replay one ply from the game record
D $6690 Used by take-back, take-forward, next-best and R (replay). Stops when the ply count $C001 reaches the target in HL. Otherwise regenerates the moves, picks the recorded index, makes the move (with the recorded promotion piece and check flag) and continues through the common after-move code (#R$636E). The evaluation (#R$8400) is not called for replayed moves.
C $6690 Reached the target ply: stop
C $669A $BCCF = plies still to replay
C $669D Next record byte: bit 7 = check, bits 0-6 = move index
C $66B5 Regenerate the moves for this position
C $66C1 Score byte $FF -> 0; restore the check flag from the record
C $66CB Replay mode: highlight the from-square
C $66D2 Make the move
C $66D9 Promotion: take the next piece from the promotion list and store it as the piece's value byte
C $66F4 Replay mode: show (and, when printing the record, print) every move
C $6709 Otherwise show only the last two replayed moves
C $6715 Unless next-best is in progress, clear the root exclusion list; then the common after-move code appends this move to it
@ $671F label=ReplayEnd
C $671F Clear the replay target and replay mode; the human plays the side to move ($BCBE = side to move bit)
@ $6734 label=PollKeyboard
c $6734 Poll the keyboard
D $6734 Reads all eight half-rows at once. Returns Z if no key is pressed. If any key is pressed shows *INTERRUPTED*, buzzes and returns NZ (A=1). This is the only keyboard test made while thinking: the search calls it at every node via #R$78BA until the abort flag (bit 7 of $BD4C) is set, and once more after the opening book probe (#R$7C23).
T $673F,14
B $674D,1 Last character (bit 7 set)
B $6751,2 Inline arguments: duration, pitch
@ $675A label=WaitKey
c $675A Wait for a key
D $675A Enables interrupts so that the ROM keyboard scan runs, incrementing the random accumulator $BCCE in the waiting loop, and returns the key code (bit 5 cleared, i.e. upper case) in A and $BCC0, with a click. Interrupts are disabled again on return; they are enabled nowhere else, so there is no real-time clock while thinking.
C $675A Restore IY for the ROM interrupt routine
C $675F Spin, counting in $BCCE, until FLAGS bit 5 (new key)
C $676A Take LAST_K, force upper case
B $6778,2 Inline arguments: duration, pitch
@ $677E label=GetCommandKey
c $677E Read a command key
D $677E Waits for a key. S toggles the sound and O the board orientation (both handled here, then waits again). While the cursor is shown ($BCCA <> $FF) the keys 5-8 move it (wrapping within the rank or file; directions follow the orientation) and are also handled here. Any other key is returned in A.
B $6793,2 Inline arguments: duration, pitch
@ $6800 label=CommandDispatch
c $6800 Read a key and execute a command
D $6800 Commands D (demo), E (enter both sides) and M (move) are only accepted while the game is not over ($BCBF = 0). A, B, C, F, G, L, N, P, R and T jump to their handlers; any other key (including ENTER) is returned in A.
@ $684D label=KeyDemo
C $684D D: CYRUS v CYRUS
@ $6858 label=KeyEnter
C $6858 E: HUMAN v HUMAN
t $6863 Printer text: Replay
@ $6869 label=KeyReplay
c $6869 R: replay the whole game
D $6869 Entry #R$6876 is also used to print the move record (P then R).
@ $6876 label=StartReplayAll
C $6876 Replay target $FFFF (to the end of the record), replay mode on
t $6897 Printer text: take-Back
@ $68A0 label=KeyTakeBack
c $68A0 B: take back one ply
D $68A0 Implemented by restoring the start position and replaying $C001 - 1 plies. Entry #R$68B2 restores the start position (new game, or the position saved at the end of set-up mode) and starts a replay to the ply count in HL.
@ $68AE label=TakeBackOnePly
@ $68B2 label=RestartAndReplay
C $68B2 Replay target
C $68B5 Start move number; 1 = standard start: reinitialise via #R$6505
C $68BF Set-up start: clear the board and restore the saved side to move and the 32 (square, value) pairs
C $68E2 Rebuild the board from the piece lists
C $68F8 Reset the 50-move counter, $BD0D and the last-move/repetition data
C $68FB Printing the record: draw and print the start position
@ $690A label=TextTakeForward
t $690A Printer text: take-Forward
@ $6916 label=KeyForward
c $6916 F: take forward one ply
D $6916 Replays the next recorded ply, if any.
@ $6932 label=KeyLevel
c $6932 L: next level
D $6932 Cycles the level index $BCCD through 0-10 (Levels 1-8, P1, P2, P3) and sets the search level $BCBD: Levels 1-8 -> 0-7, P1 -> 0, P2 -> 3, P3 -> 7. There is no time limit anywhere: a level is purely a search-size setting.
C $6932 $BCCD = (BCCD + 1) mod 11
C $693E P1 -> 0, P2 -> 3, P3 -> 7, otherwise $BCBD = $BCCD
@ $695D label=KeyMove
c $695D M: Cyrus takes over the side to move
D $695D Entry #R$696A swaps the side Cyrus plays ($BCBE) and negates the score $BCA0, then continues the main loop.
@ $696A label=SwapSides
@ $697F label=KeyNewGame
c $697F G: new game
@ $6985 label=AskNewGame
c $6985 Ask NEW GAME? and start one on Y
T $698B,8
B $6993,1 Last character (bit 7 set)
T $6997,6
B $699D,1 Last character (bit 7 set)
@ $69AA label=TextNextBest
t $69AA Printer text: Next-best
@ $69B3 label=KeyNextBest
c $69B3 N: next-best move
D $69B3 Sets $BCDD and takes back one ply. Because the root exclusion list at $BF00 is neither cleared nor extended while $BCDD is set, the retracted move stays excluded and the main loop makes Cyrus play the side to move again (#R$611F). See #R$7CBA for how the search uses the list.
@ $69C9 label=KeyPrinter
c $69C9 P: printer commands
D $69C9 Checks for the ZX Printer (port $FB bit 6), then offers B (print board), R (print record via replay) and T (toggle listing).
T $69D5,11
B $69E0,1 Last character (bit 7 set)
T $69F0,7
B $69F7,1 Last character (bit 7 set)
T $69FB,90
B $6A55,1 Last character (bit 7 set)
@ $6A8D label=KeyAlterColours
c $6A8D A: alter colours
T $6A93,154
B $6B2D,1 Last character (bit 7 set)
T $6B34,9
B $6B3D,1 Last character (bit 7 set)
T $6B41,11
B $6B4C,1 Last character (bit 7 set)
T $6B56,11
B $6B61,1 Last character (bit 7 set)
T $6B6B,12
B $6B77,1 Last character (bit 7 set)
T $6B81,12
B $6B8D,1 Last character (bit 7 set)
@ $6B97 label=GetColourKey
c $6B97 Read one colour choice
D $6B97 HL = colour variable. 0-7 set it, 8 leaves it, D restores the defaults, any other key ends the command.
@ $6BBA label=DefaultColours
c $6BBA Default colour scheme
D $6BBA Black pieces ink 0, white pieces ink 7, black squares paper 4, white squares paper 6.
@ $6BCF label=KeyTape
c $6BCF T: save or load the game record
D $6BCF Save: writes $C000 to the end of the record ($FF) as a headerless block ($C000 is set to $FF as a marker). Load: reads up to $1F00 bytes to $E000, checks the markers and copies them to $C000, then replays the game.
T $6BD5,7
B $6BDC,1 Last character (bit 7 set)
T $6BE0,58
B $6C1A,1 Last character (bit 7 set)
T $6C2F,9
B $6C38,1 Last character (bit 7 set)
T $6C3C,31
B $6C5B,1 Last character (bit 7 set)
T $6C65,9
B $6C6E,1 Last character (bit 7 set)
T $6C95,9
B $6C9E,1 Last character (bit 7 set)
@ $6CE9 label=TextTapeLoaded
t $6CE9 Printer text: Tape loaded
@ $6CF4 label=TapeError
c $6CF4 Report a tape error
T $6CFA,11
B $6D05,1 Last character (bit 7 set)
@ $6D0F label=TapeSave
c $6D0F Save via the ROM
D $6D0F Jumps into SA-BYTES ($04C6) with #R$6D25 as the return address.
@ $6D16 label=TapeLoad
c $6D16 Load via the ROM
D $6D16 Jumps into LD-BYTES ($0562) with #R$6D25 as the return address.
@ $6D25 label=TapeReturn
c $6D25 Return from the ROM tape routines
D $6D25 Reached by RET from the ROM save/load routines (address pushed at #R$6D0F/#R$6D16). Restores the border, tests BREAK (shows *ABORTED* if pressed, returning with carry clear) and clears the ROM's new-key flag.
C $6D34 *ABORTED*
T $6D37,8
B $6D3F,1 Last character (bit 7 set)
C $6D40 Buzz
@ $6D4D label=ChangePosition
c $6D4D C: change position (set-up mode)
D $6D4D Pieces are entered as set-up codes (slot offset + $83 for White or + $03 for Black; bit 0 set marks a set-up code, bit 1 set marks a piece entered by the user). Removing or overwriting a real piece marks its piece-list entry absent. On exit (E) nothing happens if neither the position nor the side to move changed; otherwise #R$6ECC validates and installs the position.
C $6D4D Clear the message lines; cursor to the start rank; nothing changed yet ($BD4D = 0)
C $6D5D Colour for new pieces $BCA2: $83 (WHITE) if White is to move, else $03 (BLACK)
@ $6D6A label=SetupMenu
C $6D6A Redraw the board with the cursor; set-up menu
T $6D70,185
B $6E29,1 Last character (bit 7 set)
T $6E30,14
B $6E3E,1 Last character (bit 7 set)
T $6E49,4
B $6E4D,1 Last character (bit 7 set)
T $6E53,4
B $6E57,1 Last character (bit 7 set)
@ $6E58 label=SetupKey
C $6E58 Read a key (cursor keys, S and O are handled by #R$677E)
C $6E66 G: new game prompt, then back to set-up
C $6E73 T: toggle the colour (and the side to move on exit)
C $6E82 A: all clear (every piece-list entry absent)
C $6E8B U: empty the cursor square
C $6E98 K, Q, R, B, N, P: look up the slot offset for the key; any other key just redraws
C $6EA6 Put the set-up code (offset + colour) on the cursor square
C $6EB4 If a real piece was there (bit 0 clear, bit 2 set), mark its piece-list entry absent
C $6EC4 Position changed
@ $6ECC label=SetupExit
C $6ECC E: side to move = colour shown. White: Cyrus plays Black ($BCBE = $80), HUMAN v CYRUS; Black: Cyrus plays White ($BCBE = 0), CYRUS v HUMAN
C $6EE5 Store the side to move; a change counts as a change of position
C $6EEF Nothing changed: back to the game (history kept)
C $6EF6 Give the set-up pieces slots (checks pawns on rank 1/8, piece counts and both kings)
C $6EF9 Reset the 50-move counter, $BD0D and the last-move/repetition data (so no en passant is possible)
C $6EFC Move number 10; score $BCA0 = $80
C $6F06 Pre-search set-up (#R$7810): returns Z if the side not to move is in check - ILLEGAL
C $6F0C Save this as the start position; empty the game record
C $6F14 Listing on: print a rule and the board
C $6F20 Start the game from here
@ $6F23 label=FindPieceRow
c $6F23 Search the piece table
D $6F23 Compares A with every third byte from HL (6 entries). Returns with HL at the match, or carry set if none.
@ $6F2E label=PieceTable
b $6F2E Piece table and hidden copyright
D $6F2E Six rows of (value byte, key, slot offset): K, Q, R, B, N, P. Searched by value from $6F2E and by key from $6F2F.
B $6F2E,18,3
T $6F40,55 Copyright notice (never printed)
@ $6F77 label=SaveStartPosition
c $6F77 Save the start position
D $6F77 $C005 = side to move ($BD2D), $C006 = move number, $C007-$C046 = (square, value) of the 32 piece-list entries.
@ $6F99 label=ResetGameCounters
c $6F99 Reset per-game counters
D $6F99 Zeroes the 50-move counter $BD0A, $BD0D, and $BD59-$BD5E (last two moves and the repetition counter). As a result no en passant capture is possible after set-up, and a side that is checkmated in the set-up position is reported as stalemated.
@ $6FAA label=ClearExclusionList
c $6FAA Clear the root exclusion list
D $6FAA Writes the $FF terminator at $BF00.
@ $6FB0 label=Beep
c $6FB0 Beep
D $6FB0 Two inline bytes follow the CALL: duration (outer count) and pitch (half-period). Silent if $BCD3 is set (sound off), but takes the same time.
@ $6FDD label=SetPrintPosInline
c $6FDD Set the print position from two inline bytes
@ $6FE4 label=ReadPrintPos
c $6FE4 Read the print position (row, column) at HL
@ $6FEF label=ClearCommandArea
c $6FEF Clear from the print position to the bottom of the screen (attribute $28)
@ $7004 label=ClearScreen
c $7004 Clear the top 18 rows (attribute $38)
B $7007,2 Inline arguments: row, column
@ $701D label=ClearMoveLines
c $701D Clear the move display lines (5 and 6)
B $7020,2 Inline arguments: row, column
T $7022,11
B $702D,1 Last character (bit 7 set)
B $7031,2 Inline arguments: row, column
T $7033,10
B $703D,1 Last character (bit 7 set)
@ $703F label=ClearLine12
c $703F Clear message line 12
B $7042,2 Inline arguments: row, column
@ $7046 label=ClearLine11
c $7046 Clear message line 11
B $7049,2 Inline arguments: row, column
@ $704D label=ClearLine10
c $704D Clear message line 10
B $7050,2 Inline arguments: row, column
T $7055,14
B $7063,1 Last character (bit 7 set)
@ $7065 label=PrinterRule
c $7065 Print a rule of '=' on the ZX Printer
@ $7071 label=PrinterFlushLine
c $7071 Send the printer buffer ($5B00) to the ZX Printer and clear it
@ $709C label=PrinterClearBuffer
c $709C Clear the printer buffer
@ $70A9 label=PrinterSendByte
c $70A9 Send one byte of pixels to the ZX Printer
@ $70BF label=ShowFromSquare
c $70BF Highlight the move's from-square and beep
@ $70C7 label=ShowToSquare
c $70C7 Highlight the move's to-square and beep
B $70D0,2 Inline arguments: duration, pitch
@ $70D3 label=CursorToStartRank
c $70D3 Put the cursor on the a-file square in front of the side to move's pieces
D $70D3 $60 (a2) for White, $10 (a7) for Black.
@ $70DF label=DrawBoardNoCursor
c $70DF Draw the board without the cursor
@ $70E1 label=DrawBoardCursor
c $70E1 Draw the board with the cursor at A
@ $70E4 label=DrawBoard
c $70E4 Draw the board
D $70E4 Draws each square as a 2x2 block (#R$7200) chosen from the piece's value byte, flashing the cursor square, then the rank and file labels.
B $7131,4 Inline: empty square
B $715C,4 Inline: king
B $7169,4 Inline: pawn
B $7176,4 Inline: rook
B $7181,4 Inline: queen
B $718E,4 Inline: knight
B $7197,4 Inline: bishop
C $719B Next square
@ $7200 label=DrawGlyph2x2
c $7200 Draw a 2x2 character block
D $7200 Four inline character codes follow the CALL (top-left, top-right, bottom-left, bottom-right).
@ $7224 label=PrintCharHL
c $7224 Print the character at HL and advance HL
@ $7226 label=PrintChar
c $7226 Print a character on the screen
D $7226 At (row $BCC5, column $BCC6) with attribute $BCC4. Codes $90 and above are piece graphics at #R$75CC; others use the font at (CHARS copy $BCD5).
@ $729B label=OutputVector
c $729B Print a character via the output vector in IY
@ $729D label=PrinterBoard
c $729D Print the board on the ZX Printer
@ $734D label=PrinterChar
c $734D Put a character into the printer buffer
@ $737C label=ShowLevel
c $737C Show LEVEL n or LEVEL Pn
B $737F,2 Inline arguments: row, column
T $7381,5
B $7386,1 Last character (bit 7 set)
@ $739E label=ShowIllegal
c $739E Show ILLEGAL and buzz
T $73A1,6
B $73A7,1 Last character (bit 7 set)
@ $73A8 label=Buzz
c $73A8 Error buzz
B $73AB,2 Inline arguments: duration, pitch
@ $73AE label=ShowHitAnyKey
c $73AE Show "-Hit any key to restore control-"
T $73B1,31
B $73D0,1 Last character (bit 7 set)
@ $73D4 label=ShowHitBreak
c $73D4 Show "--Hit BREAK key to abort-"
T $73D7,28
B $73F3,1 Last character (bit 7 set)
@ $73F7 label=PrintLine12
c $73F7 Print an inline string at (12,0)
B $73FA,2 Inline arguments: row, column
@ $73FE label=PrintLine11
c $73FE Print an inline string at (11,0)
B $7401,2 Inline arguments: row, column
@ $7405 label=PrintCommandArea
c $7405 Print an inline string at (18,0) in the command area colours
B $7408,2 Inline arguments: row, column
@ $740E label=PrintLine10
c $740E Print an inline string at (10,0)
B $7411,2 Inline arguments: row, column
@ $7415 label=PrintAtInline
c $7415 Print an inline string at an inline position
D $7415 Two inline bytes (row, column) then a string whose last character has bit 7 set.
@ $741A label=PrintInline
c $741A Print an inline string at the current position
D $741A Entry #R$741C uses the attribute in A instead of $38.
@ $741C label=PrintInlineAttr
@ $742C label=PrinterResult
c $742C Print the game result on the ZX Printer (listing on, or while printing the record)
@ $743B label=PrinterString
c $743B Print the string at HL on the ZX Printer if listing is on
@ $7452 label=PrinterMove
c $7452 Print the move at IX on the ZX Printer
@ $746E label=ShowMove
c $746E Show the move at IX in the message area
B $7483,2 Inline arguments: row, column
T $7485,10
B $748F,1 Last character (bit 7 set)
B $7493,2 Inline arguments: row, column
B $749A,2 Inline arguments: row, column
T $749C,2
B $749E,1 Last character (bit 7 set)
@ $749F label=FormatMove
c $749F Output a move
D $749F From-square, '-' or 'x' (capture flag, bit 3 of IX+3), to-square, '/' and the promotion piece if $BCDE is set, '+' if bit 7 of IX+3 (check) is set.
@ $74F7 label=ShowSquare
c $74F7 Show a square on the screen
@ $74FB label=FormatSquare
c $74FB Output a square
D $74FB File letter A-H from bits 0-2; rank digit = '8' - row.
@ $7511 label=PrinterMoveNumber
c $7511 Print the move number on the ZX Printer
@ $751B label=ShowMoveNumber
c $751B Show the move number at (5,0)
B $7522,2 Inline arguments: row, column
@ $7524 label=FormatMoveNumber
@ $7562 label=SetPlayers
c $7562 Set the players from the side Cyrus plays
D $7562 $BCC2 = 1 (HUMAN v CYRUS) if $BCBE is non-zero, else 2 (CYRUS v HUMAN); then shows the players.
@ $756E label=ShowPlayers
c $756E Show the players line
D $756E Bit 1 of $BCC2 selects CYRUS/HUMAN for White, bit 0 for Black.
B $7571,2 Inline arguments: row, column
T $757E,2
B $7580,1 Last character (bit 7 set)
@ $7586 label=PrintPlayerName
c $7586 Print CYRUS (NZ) or HUMAN (Z)
T $758B,4
B $758F,1 Last character (bit 7 set)
T $7594,4
B $7598,1 Last character (bit 7 set)
@ $759A label=ShowListing
c $759A Show LISTING ON/OFF
B $759D,2 Inline arguments: row, column
T $759F,7
B $75A6,1 Last character (bit 7 set)
T $75B0,2
B $75B2,1 Last character (bit 7 set)
@ $75B4 label=ShowSound
c $75B4 Show SOUND ON/OFF
B $75B7,2 Inline arguments: row, column
T $75B9,5
B $75BE,1 Last character (bit 7 set)
T $75C8,2
B $75CA,1 Last character (bit 7 set)
@ $75CC label=PieceGraphics
b $75CC Piece graphics
D $75CC 22 characters ($90-$A5) of 8 bytes: pawn $90-$93, knight $94-$97, bishop $98-$9B, rook $9C-$9F, queen $A0-$A3, king top $A4-$A5 (it shares the queen's bottom half).
B $75CC,176,8
s $767C Unused
@ $7800 label=KnightOffsets
b $7800 Knight move offsets
D $7800 0x88 offsets used by the move generator: +14, +18, +31, +33, -14, -18, -31, -33.
B $7800,8
@ $7808 label=DiagonalOffsets
b $7808 Diagonal and orthogonal direction offsets
D $7808 $7808: diagonals +15, +17, -17, -15; $780C: orthogonals +1, -1, +16, -16. King and queen use all eight from $7808; bishops $7808-$780B; rooks $780C-$780F.
B $7808,4
@ $780C label=OrthogonalOffsets
B $780C,4

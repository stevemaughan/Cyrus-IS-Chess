  ORG $6000

; Program entry and title
;
; Entered by JP $6000 from the CLoad48 loader. Disables NEW (RAMTOP/P-RAMT set
; to $1111), saves IY and the CHARS system variable, clears the screen and
; beeps. If a key is held down at this point the copyright message is shown
; (with beeps) until a key is pressed again; otherwise the program falls
; straight through to the cold start at ColdStart.
Start:
  LD HL,$1111             ; Set RAMTOP and P-RAMT to $1111 (makes BASIC NEW
  LD ($5CB2),HL           ; unusable)
  LD ($5CB4),HL           ;
  DI                      ; Interrupts stay disabled except while waiting for a
                          ; key (WaitKey)
  LD ($BCC8),IY           ; Save IY for ROM calls (restored in WaitKey)
  LD HL,($5C36)           ; Save CHARS; PrintChar uses this copy for the font
  LD ($BCD5),HL           ;
  CALL ClearScreen        ; Clear the screen
  CALL SetPrintPosInline  ; Print position (18,0)
  DEFB $12,$00            ; Inline arguments: row, column
  CALL ClearCommandArea   ; Clear the command area
  CALL Beep               ; Beep
  DEFB $50,$0C            ; Inline arguments: duration, pitch
  LD ($5C36),HL           ; Corrupt CHARS (HL=$BCD2 left over from the beep
                          ; routine); the program's own text output uses the
                          ; copy at $BCD5
  CALL PollKeyboard       ; No key pressed: go to the cold start
  JR Z,ColdStart          ;
TitleLoop:
  CALL PrintAtInline      ; Print the copyright message at (0,0)
  DEFB $00,$00            ; Inline arguments: row, column
  DEFM $7F," 1982 Intelligent Software Ltd"
  DEFB $AE                ; Last character (bit 7 set)
  CALL Beep               ; Beep
  DEFB $FF,$10            ; Inline arguments: duration, pitch
  CALL PollKeyboard       ; Loop until a key is pressed
  JR Z,TitleLoop          ;

; Cold start: default options
;
; Sets the default options (Level 2, sound on, listing off, normal orientation,
; default colours) and starts a new game.
ColdStart:
  LD A,$01                ; Level index $BCCD = 1 (Level 2) and search level
  LD ($BCBD),A            ; $BCBD = 1; listing flag $BCD4 = 1 (listing OFF)
  LD ($BCCD),A            ;
  LD ($BCD4),A            ;
  XOR A                   ; Orientation normal, next-best off, start move
  LD ($BCC7),A            ; number 0 (forces a cleared record below),
  LD ($BCDD),A            ; print-record off, replay off, sound on
  LD ($C006),A            ;
  LD ($BCDB),A            ;
  LD ($BCC3),A            ;
  LD ($BCD3),A            ;
  CALL DefaultColours     ; Default colour scheme
  CALL PrinterClearBuffer ; Clear the printer buffer

; New game
;
; Entered after G and Y (AskNewGame). If the last game did not start from the
; standard position its record is discarded ($C058=$FF); otherwise the record
; is kept so that F (take-forward) can replay it. Cyrus plays Black.
NewGameConfirmed:
  LD A,($C006)            ; $C006 = start move number: 1 means the game started
  DEC A                   ; from the standard initial position
  JR Z,NewGameConfirmed_0 ;
  LD A,$FF                ; Not a standard game: empty the game record
  LD ($C058),A            ;
NewGameConfirmed_0:
  LD A,$01                ; $BCC2 = 1: HUMAN v CYRUS
  LD ($BCC2),A            ;
; This entry point is used by the routine at GameOverNoMoves.
NewGameNoConfirm:
  LD HL,$0000             ; No replay target
  LD ($C003),HL           ;
  CALL ClearScreen        ; Clear the screen and beep
  CALL Beep               ;
  DEFB $32,$10            ; Inline arguments: duration, pitch
  LD A,($BCD4)            ; Listing on: print a rule on the ZX Printer
  OR A                    ;
  CALL Z,PrinterRule      ;
; This entry point is used by the routine at KeyTakeBack.
NewGameBoard:
  CALL InitBoard          ; Set up the initial position (InitBoard)
; Common entry for a new game, a take-back replay (RestartAndReplay) and the
; exit from set-up mode (SetupExit).
GameStartCommon:
  LD HL,$0000             ; Game record ply count $C001 = 0
  LD ($C001),HL           ;
  XOR A                   ; Promotion counter $C047 = 0; opening book enabled
  LD ($C047),A            ; ($BCDF = 0)
  LD ($BCDF),A            ;
  CALL ClearMoveLines     ; Clear the move display lines

; Main loop
;
; One iteration per ply. Handles automatic replay (R), the replay-to-target
; used by take-back/forward/next-best, the draw tests, the status display, and
; then hands control to the computer (ComputerMove) or the human (HumanMove).
;
; Note that the draw tests are skipped while a replay target is set ($C003
; non-zero).
MainLoop:
  LD SP,$BDF4             ; Reset the stack (discards the undo information
                          ; pushed by game moves)
  LD A,($BCC3)             ; Replay mode (R key) off: skip
  OR A                     ;
  JR Z,MainLoopReplayCheck ;
  LD BC,$C058             ; Next record byte; $FF = end of record: stop
  LD HL,($C001)           ; replaying
  ADD HL,BC               ;
  LD A,(HL)               ;
  INC A                   ;
  JP Z,ReplayEnd          ;
  CALL DrawBoardNoCursor  ; Redraw the board
  LD HL,$C000               ; Pause about 2.5 s between replayed moves, polling
MainLoop_0:
  CALL PollKeyboard         ; the keyboard; a key stops the replay. No pause
  JP NZ,ReplayEnd           ; while printing the record ($BCDB)
  LD A,($BCDB)              ;
  OR A                      ;
  JR NZ,MainLoopReplayCheck ;
  DEC HL                    ;
  LD A,L                    ;
  OR H                      ;
  JR NZ,MainLoop_0          ;
MainLoopReplayCheck:
  LD HL,($C003)           ; Replay target set ($C003): replay one more ply
  LD A,L                  ; (ReplayStep)
  OR H                    ;
  JP NZ,ReplayStep        ;
  LD A,R                  ; Stir the random accumulator $BCCE with R
  LD B,A                  ;
  RRA                     ;
  RRA                     ;
  ADD A,B                 ;
  LD HL,$BCCE             ;
  ADD A,(HL)              ;
  LD (HL),A               ;
  LD A,($BD5E)            ; Repetition counter $BD5E = 6: draw by repetition
  CP $06                  ;
  JP Z,GameOverDraw       ;
  LD A,($BD0A)            ; 50-move counter $BD0A >= 100 plies: draw
  CP $64                  ;
  JP NC,GameOverDraw      ;
  XOR A                   ; Game not over
  LD ($BCBF),A            ;
  CALL ClearLine11        ; Clear the message lines and show the level,
  CALL ClearLine12        ; players, listing and sound status
  CALL ClearLine10        ;
  CALL ShowLevel          ;
  CALL ShowPlayers        ;
  CALL ShowListing        ;
  CALL ShowSound          ;
  LD A,($BCDD)            ; Next-best in progress ($BCDD): Cyrus plays the side
  OR A                    ; to move ($BCBE = side to move XOR 1) and moves now
  JR Z,MainLoop_1         ;
  LD A,($BD2D)            ;
  AND $01                 ;
  XOR $01                 ;
  LD ($BCBE),A            ;
  CALL SetPlayers         ;
  JR ComputerMove         ;
MainLoop_1:
  LD A,($BD2D)            ; White to move: Cyrus moves if $BCBE = 0, otherwise
  RRA                     ; the human moves
  LD A,($BCBE)            ;
  JR NC,MainLoop_2        ;
  OR A                    ;
  JR Z,ComputerMove       ;
  JP HumanMove            ;
MainLoop_2:
  OR A                    ; Black to move: the human moves if $BCBE = 0,
  JP Z,HumanMove          ; otherwise Cyrus moves

; Computer move
;
; Generates and scores the legal moves (to detect mate/stalemate), runs the
; search (S_THINK) and plays the move it leaves at ($BD29).
;
; In problem mode (level index $BCCD >= 8) the move is only played if the
; search found a mate ($BCA0 >= $FE); otherwise NO MATE FOUND is shown and
; set-up mode is entered.
ComputerMove:
  LD A,($BCC2)            ; HUMAN v HUMAN ($BCC2 = 0): just swap sides
  OR A                    ;
  JP Z,SwapSides          ;
  LD A,$40                ; $BD4C = $40: bit 6 = computer's move (promotions
  LD ($BD4C),A            ; are to a queen without asking); bit 7 (abort) clear
  LD IX,$BD58             ; Generate the root moves (IX=$BD58 = last game move)
  CALL GENMOVES           ; and score each one with make/evaluate/unmake
  CALL S_SCOREMOVES       ; (S_SCOREMOVES)
  LD A,($BD19)            ; Best score 0: no legal move - checkmate or
  OR A                    ; stalemate
  JP Z,GameOverNoMoves    ;
  XOR A                   ; Print-record mode off
  LD ($BCDB),A            ;
  LD A,($BCDD)              ; Unless a next-best search is in progress, clear
  OR A                      ; the root exclusion list at $BF00
  CALL Z,ClearExclusionList ;
  CALL DrawBoardNoCursor  ; Redraw the board without the cursor
  CALL Beep               ; Beep
  DEFB $14,$10            ; Inline arguments: duration, pitch
  CALL ShowHitAnyKey      ; Show "-Hit any key to restore control-" in the
                          ; command area
  CALL PrintLine12        ; Show LET ME THINK...
  DEFM "LET ME THINK.."
  DEFB $AE                ; Last character (bit 7 set)
  CALL S_THINK            ; Search (S_THINK); the chosen move is left at
                          ; ($BD29)
  CALL Beep               ; Beep
  DEFB $14,$20            ; Inline arguments: duration, pitch
  XOR A                   ; Next-best request completed
  LD ($BCDD),A            ;
  LD A,($BCCD)            ; Problem levels P1-P3 (level index >= 8): play the
  CP $08                  ; move only if a mate was found ($BCA0 >= $FE)
  JR C,ComputerMovePlay   ;
  LD A,($BCA0)            ;
  CP $FE                  ;
  JR NC,ComputerMovePlay  ;
  CALL ClearLine12        ; NO MATE FOUND: buzz and go to set-up mode
  CALL PrintLine12        ;
  DEFM "*NO MATE FOUND"
  DEFB $AA                ; Last character (bit 7 set)
  CALL Buzz               ; Buzz, then enter set-up mode
  JP ChangePosition       ;
ComputerMovePlay:
  LD IX,($BD29)           ; IX = the move chosen by the search; play it
  JP PlayMove             ;

; Human move
;
; Generates and scores the legal moves (so that illegal moves have score 0),
; shows the command list and reads the user's from- and to-squares with the
; cursor. The move is accepted only if it is in the generated list with a
; non-zero score.
HumanMove:
  XOR A                   ; $BD4C = 0: human's move
  LD ($BD4C),A            ;
  LD IX,$BD58             ; Generate and score the root moves
  CALL GENMOVES           ;
  CALL S_SCOREMOVES       ;
  LD A,($BD19)            ; No legal move: checkmate or stalemate
  OR A                    ;
  JP Z,GameOverNoMoves    ;
  XOR A                   ; Print-record mode off
  LD ($BCDB),A            ;
  LD A,($BCC2)            ; CYRUS v CYRUS: just swap sides so that Cyrus plays
  CP $03                  ; this side too
  JP Z,SwapSides          ;
  OR A                    ; Not HUMAN v HUMAN: refresh $BCC2 and the players
  JR Z,HumanMove_0        ; display from $BCBE
  CALL SetPlayers         ;
HumanMove_0:
  CALL CursorToStartRank  ; Put the cursor on the a-file of the side to move's
                          ; back rank+1 (CursorToStartRank)
  CALL PrintCommandArea   ; Command list
  DEFM "Alter     take-Back Change-pos'nDemo      Enter     take-Forwardn"
  DEFM "ew-Game  Level     Move        Next-best Orient'n  Printer     Re"
  DEFM "play    Sound     Tape        5-left 6-down 7-up 8-right <cr"
  DEFB $BE                ; Last character (bit 7 set)
  CALL ClearCommandArea   ; Clear the rest of the command area
HumanMoveInput:
  CALL PrintLine10        ; YOUR MOVE?
  DEFM "YOUR MOVE?   "
  DEFB $A0                ; Last character (bit 7 set)
  LD A,$FF                ; No from-square chosen yet
  LD ($BCCB),A            ;
HumanMove_1:
  CALL CommandDispatch    ; Read keys (commands are handled inside
  CP $0D                  ; CommandDispatch) until ENTER
  JR NZ,HumanMove_1       ;
  CALL Beep               ; Beep
  DEFB $32,$20            ; Inline arguments: duration, pitch
  CALL ClearLine12        ; Clear message line 12
  LD A,$38                ;
  LD ($BCC4),A            ;
  LD A,($BCCB)            ; First ENTER: the cursor square becomes the
  INC A                   ; from-square; print it at (10,10)
  LD A,($BCCA)            ;
  JR NZ,HumanMove_2       ;
  LD ($BCCB),A            ;
  CALL SetPrintPosInline  ;
  DEFB $0A,$0A            ; Inline arguments: row, column
  CALL ShowSquare         ; Print the square and read the to-square
  JR HumanMove_1          ;
HumanMove_2:
  LD ($BCCC),A            ; Second ENTER: the cursor square is the to-square;
  CALL SetPrintPosInline  ; print it at (10,12)
  DEFB $0A,$0C            ; Inline arguments: row, column
  CALL ShowSquare
  LD A,($BCCB)            ; Look for the move (from, to) in the root list: B =
  EX AF,AF'               ; number of moves (byte 1 of the list header at
  LD A,($BCCC)            ; $B400)
  LD HL,$B401             ;
  LD B,(HL)               ;
  INC L                   ;
  CALL S_FINDMOVE         ;
  JR C,HumanMove_3        ; Not found, or found with score 0 (illegal): ILLEGAL
  DEC L                   ; and start again
  XOR A                   ;
  OR (HL)                 ;
  JR NZ,HumanMove_4       ;
HumanMove_3:
  CALL ShowIllegal        ; ILLEGAL
  JR HumanMoveInput       ;
HumanMove_4:
  CALL ClearExclusionList ; Start a new root exclusion list; IX = the move
  PUSH HL                 ;
  POP IX                  ;

; Play a game move
;
; Plays the move at IX for whichever side is to move: makes it on the board,
; handles promotion, re-evaluates (which sets the check flag, bit 7 of IX+3),
; displays and prints it, appends it to the game record, updates the 50-move
; and repetition counters, changes the side to move, and appends it to the root
; exclusion list.
;
; IX Move (score, from, to, flags)
PlayMove:
  CALL ShowFromSquare     ; Highlight the from-square and beep
  CALL MAKEMOVE           ; Make the move (MAKEMOVE). It leaves its undo
                          ; information on the stack; the top entry, popped as
                          ; AF, has A = the moving piece's old value/flags byte
                          ; and F = a move-type code: S set = not a capture,
                          ; P/V set = promotion, C set = en passant
  XOR A                   ; No promotion piece to display yet
  LD ($BCDE),A            ;
  POP AF                  ; Promotion (P/V set): choose the piece
  PUSH AF                 ; (ChoosePromotion)
  CALL PE,ChoosePromotion ;
  RES 7,(IX+$03)          ; Clear the check flag, then re-evaluate (Evaluate),
  CALL Evaluate           ; which sets it again if the move gives check
  CALL ShowMove           ; Show the move in the message area and highlight the
  CALL ShowToSquare       ; to-square
  LD A,($BCD4)            ; Listing on ($BCD4 = 0): print the move on the ZX
  OR A                    ; Printer
  CALL Z,PrinterMove      ;
  PUSH IX                 ; E = index of the move in the root list (0 = first
  POP HL                  ; move at $B404)
  LD BC,$B400             ;
  XOR A                   ;
  LD E,A                  ;
  SBC HL,BC               ;
  LD BC,$0004             ;
PlayMove_0:
  INC E                   ;
  SBC HL,BC               ;
  JR NZ,PlayMove_0        ;
  DEC E                   ;
  LD HL,($C001)           ; Append (check flag | index) to the game record at
  INC HL                  ; $C058 and terminate it with $FF; $C001 = ply count
  LD ($C001),HL           ;
  LD A,(IX+$03)           ;
  AND $80                 ;
  OR E                    ;
  LD BC,$C057             ;
  ADD HL,BC               ;
  LD (HL),A               ;
  INC HL                  ;
  LD (HL),$FF             ;
; This entry point is used by the routine at ReplayStep.
AfterGameMove:
  LD HL,$BD0A             ; 50-move counter: count this ply, and reset it to 0
  INC (HL)                ; after a capture (S clear) or a pawn move (old value
  POP AF                  ; 1)
  PUSH AF                 ;
  JP P,PlayMove_1         ;
  AND $0F                 ;
  DEC A                   ;
  JR NZ,PlayMove_2        ;
PlayMove_1:
  XOR A                   ;
  LD ($BD0A),A            ;
PlayMove_2:
  CALL TrackRepetition    ; Update the repetition detector (TrackRepetition)
  LD A,($BD2D)            ; Change the side to move; increment the move number
  XOR $01                 ; $BD49 when it is White's turn again
  LD ($BD2D),A            ;
  RRA                     ;
  JR NC,PlayMove_3        ;
  LD HL,$BD49             ;
  INC (HL)                ;
PlayMove_3:
  LD A,($BCDD)            ; Unless next-best is in progress, append (from, to)
  OR A                    ; to the root exclusion list at $BF00
  JR NZ,PlayMove_6        ;
  LD HL,$BF00             ;
PlayMove_4:
  LD A,(HL)               ;
  INC A                   ;
  JR Z,PlayMove_5         ;
  INC HL                  ;
  JR PlayMove_4           ;
PlayMove_5:
  LD A,(IX+$01)           ;
  LD (HL),A               ;
  INC HL                  ;
  LD A,(IX+$02)           ;
  LD (HL),A               ;
  INC HL                  ;
  LD (HL),$FF             ;
PlayMove_6:
  JP MainLoop             ; Next ply

; Choose the promotion piece
;
; Called after a pawn has been promoted by MAKEMOVE (which makes it a queen,
; value byte $19). For the computer's move ($BD4C bit 6 set) the queen is kept
; without asking. Otherwise the user is asked PROMOTE TO? and R, N or B
; under-promote by overwriting the piece's value byte (+1) with 5, 3 or $83;
; any other key keeps the queen. The chosen value (9 for a queen) is appended
; to the promotion list at $C048 (count in $C047) so that replays can repeat
; it, and stored in $BCDE for the move display.
;
; IX Promotion move
ChoosePromotion:
  LD A,($BD4C)            ; Computer's move: queen
  BIT 6,A                 ;
  JR NZ,ChoosePromotion_0 ;
  CALL PrintLine12        ;
  DEFM "PROMOTE TO"
  DEFB $BF                ; Last character (bit 7 set)
  CALL PrintCommandArea   ; Piece choices
  DEFM "kNight  Bishop  Rook    Quee"
  DEFB $EE                ; Last character (bit 7 set)
  CALL ClearCommandArea   ; Wait for a key
  CALL WaitKey            ;
  LD B,$05                ; R = rook (5), N = knight (3), B = bishop ($83);
  CP $52                  ; anything else = queen (9)
  JR Z,ChoosePromotion_1  ;
  LD B,$03                ;
  CP $4E                  ;
  JR Z,ChoosePromotion_1  ;
  LD B,$83                ;
  CP $42                  ;
  JR Z,ChoosePromotion_1  ;
ChoosePromotion_0:
  LD B,$09                ;
  JR RecordPromotion      ;
ChoosePromotion_1:
  LD L,(IX+$02)           ; Overwrite the promoted piece's value byte: piece
  LD H,$BD                ; list entry of the piece now on the to-square,
  LD L,(HL)               ; offset +1
  RES 2,L                 ;
  INC L                   ;
  INC H                   ;
  LD (HL),B               ;
RecordPromotion:
  LD HL,$C047             ; Append the piece value to the promotion list ($C047
  INC (HL)                ; = count, entries from $C048). Only 16 entries fit
  LD A,(HL)               ; before the game record at $C058
  ADD A,L                 ;
  LD L,A                  ;
  LD (HL),B               ;
  LD A,B                  ;
  LD ($BCDE),A            ;
  RET                     ;

; Game over
;
; No legal moves: CHECKMATE if the last move gave check (bit 7 of $BD5B), else
; STALEMATE. Entry GameOverDraw is the draw (repetition or 50 moves). The
; result is printed if listing is on; afterwards only the reduced command set
; is available ($BCBF = 1). In demonstration mode a new game starts after about
; 20 s unless a key is pressed.
GameOverNoMoves:
  LD A,($BD5B)            ; Last move gave check?
  RLA                     ;
  JR C,GameOverNoMoves_0  ;
  CALL PrintLine11        ; STALEMATE
  DEFM "STALEMAT"
  DEFB $C5                ; Last character (bit 7 set)
  LD HL,$6423             ; Print it if listing is on
  CALL PrinterResult      ;
  JR GameOverCommon       ;
GameOverNoMoves_0:
  CALL PrintLine11        ; CHECKMATE
  DEFM "CHECKMAT"
  DEFB $C5                ; Last character (bit 7 set)
  LD HL,$6437
  CALL PrinterResult
  JR GameOverCommon
; This entry point is used by the routine at MainLoop.
GameOverDraw:
  CALL PrintLine11        ; DRAWN
  DEFM "DRAW"
  DEFB $CE                ; Last character (bit 7 set)
  LD HL,$644B
  CALL PrinterResult
GameOverCommon:
  LD A,$01                ; Game over: D, E and M are no longer accepted
  LD ($BCBF),A            ; (CommandDispatch)
  XOR A                   ;
  LD ($BCDB),A            ;
  CALL ClearLine12        ; Clear the message lines and redraw the board; beep
  CALL ClearLine10        ;
  CALL DrawBoardNoCursor  ;
  CALL Beep               ;
  DEFB $C8,$18            ; Inline arguments: duration, pitch
  LD A,($BCC2)            ; CYRUS v CYRUS: wait about 20 s (9 x 65536 keyboard
  CP $03                  ; polls); no key: next demonstration game
  JR NZ,GameOverMenu      ;
  LD B,$09                ;
  LD HL,$0000             ;
GameOverNoMoves_1:
  CALL PollKeyboard       ;
  JR NZ,GameOverNoMoves_2 ;
  DEC HL                  ;
  LD A,L                  ;
  OR H                    ;
  JR NZ,GameOverNoMoves_1 ;
  DJNZ GameOverNoMoves_1  ;
  JP NewGameNoConfirm     ;
GameOverNoMoves_2:
  CALL SetPlayers         ; Key pressed: hand control back to the human
GameOverMenu:
  CALL PrintCommandArea   ; Reduced command list
  DEFM "Alter     take-Back Change-pos'nnew-Game  Level     Next-best   O"
  DEFM "rient'n  Printer   Replay      Sound     Tap"
  DEFB $E5                ; Last character (bit 7 set)
  CALL ClearCommandArea   ; Read and execute commands until one of them leaves
  CALL CommandDispatch    ; via the main loop
  JP GameOverMenu         ;

; Set up the standard initial position
;
; Clears $BD00-$BEFF (board, its off-board variables and both piece lists - the
; return address is held in DE because the stack lives in this area), writes
; set-up codes for the initial position and assigns them to piece-list slots
; via AssignScan, exactly as if the position had been entered in set-up mode
; with untouched (castling-capable) kings and rooks. Also sets White to move,
; move number 1, ply 1, start move number $C006 = 1 and the first ply's
; move-list pointer.
InitBoard:
  POP DE                  ; Clear 512 bytes below $BF00
  XOR A                   ;
  LD B,A                  ;
  LD HL,$BF00             ;
InitBoard_0:
  DEC HL                  ;
  LD (HL),A               ;
  DEC HL                  ;
  LD (HL),A               ;
  DJNZ InitBoard_0        ;
  PUSH DE                 ;
  LD C,A                  ; Rank 8: black pieces (set-up codes from
  CALL InitBackRank       ; BackRankCodes with colour 0)
  LD DE,$BE00             ; Rank 7: black pawns ($41); the zeroed piece list
  LD C,$41                ; serves as an 8-byte zero source
  CALL InitRank           ;
  LD L,$60                ; Rank 2: white pawns ($C1)
  LD C,$C1                ;
  CALL InitRank           ;
  LD C,$81                ; Rank 1: white pieces (codes from BackRankCodes |
  CALL InitBackRank       ; $80)
  LD A,$01                ; Cyrus plays Black ($BCBE = 1); White to move ($BD2D
  LD ($BCBE),A            ; = 1); move number 1; search ply 1; standard start
  LD ($BD2D),A            ; ($C006 = 1)
  LD ($BD49),A            ;
  LD ($BCA9),A            ;
  LD ($C006),A            ;
  LD HL,$B400             ; First ply's move list starts at $B400
  LD ($BCAB),HL           ;
  CALL MarkAllAbsent      ; Mark all piece-list entries absent, then assign the
  JP AssignScan           ; pieces to slots

; Write a back rank
;
; Writes the eight back-rank set-up codes from BackRankCodes OR'ed with C.
InitBackRank:
  LD DE,BackRankCodes

; Write a rank of set-up codes
;
; Writes eight bytes from (DE) OR'ed with C to the board at HL, then moves HL
; to the start of the next row.
InitRank:
  LD B,$08
InitRank_0:
  LD A,(DE)
  OR C
  LD (HL),A
  INC L
  INC DE
  DJNZ InitRank_0
  LD A,$08
  ADD A,L
  LD L,A
  RET

; Initial back-rank set-up codes
;
; a-h: R N B Q K B N R as set-up codes (slot offset | 1). Bit 1 is clear, so
; the kings and rooks are not marked as moved when they are assigned slots.
BackRankCodes:
  DEFB $11,$31,$21,$09,$01,$21,$31,$11

; Update the repetition detector
;
; Called for every game move. If the move just played (from B, to C) is the
; exact reverse of the move played two plies earlier, the counter $BD5E is
; incremented, otherwise it is reset to 0. Six consecutive reversals (e.g. Nf3
; Nf6 Ng1 Ng8 Nf3 Nf6 Ng1 Ng8) give $BD5E = 6, which the main loop scores as a
; draw. $BD59-$BD5B = (from, to, flags) of the last move and $BD5C-$BD5D =
; (from, to) of the move before; the root search also reads them (7D04).
;
; IX Move just played
TrackRepetition:
  LD HL,($BD5C)           ; Compare the move two plies back (stored as from,
  LD B,(IX+$01)           ; to) with (to, from) of this move
  LD C,(IX+$02)           ;
  XOR A                   ;
  SBC HL,BC               ;
  LD HL,$BD5E             ; Reversal: count it; otherwise reset the counter
  JR NZ,TrackRepetition_0 ;
  INC (HL)                ;
  JR TrackRepetition_1    ;
TrackRepetition_0:
  LD (HL),A               ;
TrackRepetition_1:
  LD HL,($BD59)           ; Shift the last move into $BD5C-$BD5D, store this
  LD ($BD5C),HL           ; move's from, to and flags at $BD59-$BD5B
  LD A,B                  ;
  LD ($BD59),A            ;
  LD H,(IX+$03)           ;
  LD L,C                  ;
  LD ($BD5A),HL           ;
  RET                     ;

; Reject a set-up position
;
; Entry SetupIllegalPop discards one return address first. Shows ILLEGAL and
; returns to the set-up menu.
SetupIllegalPop:
  POP HL
; This entry point is used by the routine at ChangePosition.
SetupIllegal:
  CALL ShowIllegal
  JP SetupMenu

; Clear the board
;
; Empties all 64 squares, then falls into MarkAllAbsent.
ClearBoard:
  XOR A
  LD HL,$BD00
ClearBoard_0:
  LD (HL),A
ClearBoard_1:
  INC L
  BIT 3,L
  JR Z,ClearBoard_0
  BIT 7,L
  JR Z,ClearBoard_1

; Mark all piece-list entries absent
;
; Sets bit 7 of the square byte of all 32 piece-list entries. Value bytes and
; the other bytes are left as they are.
MarkAllAbsent:
  XOR A
  LD HL,$BE00
MarkAllAbsent_0:
  SET 7,(HL)
  ADD A,$08
  LD L,A
  JR NC,MarkAllAbsent_0
  RET

; Turn promoted pieces back into set-up codes
;
; For each occupied pawn slot from HL (stepping 8 until bit 6 of L clears)
; whose value is not 1 (a promoted piece), frees the slot and replaces the
; piece on the board by the set-up code for its type (from the value byte via
; PieceTable), with bit 1 set ("entered"), so that it is reassigned a slot by
; AssignScan.
LiftPromotedPieces:
  LD D,(HL)
  BIT 7,D
  JR NZ,LiftPromotedPieces_0
  INC L
  LD B,(HL)
  DEC L
  LD A,B
  AND $0F
  DEC A
  JR Z,LiftPromotedPieces_0
  SET 7,(HL)
  LD A,L
  AND $80
  OR $03
  LD E,A
  LD A,B
  AND $8F
  PUSH HL
  LD HL,PieceTable
  CALL FindPieceRow
  INC HL
  INC HL
  LD A,(HL)
  OR E
  LD H,$BD
  LD L,D
  LD (HL),A
  POP HL
LiftPromotedPieces_0:
  LD A,L
  ADD A,$08
  LD L,A
  BIT 6,A
  JR NZ,LiftPromotedPieces
  RET

; Assign set-up pieces to piece-list slots (set-up exit)
;
; First lifts promoted pieces out of the pawn slots of both sides
; (LiftPromotedPieces). Then (entry AssignScan) scans the board file by file
; (a-file first; within a file from row 0 = rank 8 down to rank 1) and gives
; each square holding a set-up code (bit 0 set) a slot via AssignSlot. Finally
; both kings must exist; the king records' bits 6-7 get the king's distance
; from the edge (KINGTYPE_X).
;
; Pieces left untouched in set-up mode keep their slots and flags. Because move
; generation walks the piece lists in slot order, the slot assignment order is
; significant.
AssignSetupPieces:
  LD HL,$BE40
  CALL LiftPromotedPieces
  LD L,$C0
  CALL LiftPromotedPieces
; This entry point is used by the routine at InitBoard.
AssignScan:
  LD DE,$BD00              ; Scan rows (E += $10) then files
  LD H,$BE                 ;
AssignSetupPieces_0:
  LD A,(DE)                ;
  BIT 0,A                  ;
  CALL NZ,AssignSlot       ;
  LD A,$10                 ;
  ADD A,E                  ;
  LD E,A                   ;
  JP P,AssignSetupPieces_0 ;
  RES 7,E                  ;
  INC E                    ;
  BIT 3,A                  ;
  JR Z,AssignSetupPieces_0 ;
  LD L,$00                ; Black king: set its edge-distance bits; then both
  CALL KingEdgeDistance   ; kings must be present
  LD L,$80                ;
  LD A,B                  ;
  OR (HL)                 ;
  JP M,SetupIllegalPop    ;

; Set a king's edge-distance bits
;
; B = king square, A = its value byte; continues in KINGTYPE_X, which stores in
; bits 6-7 the number of rings (0-3) between the king and the edge of the
; board.
KingEdgeDistance:
  LD B,(HL)
  INC L
  LD A,(HL)
  JP KINGTYPE_X

; Assign one set-up piece to a slot
;
; A = set-up code (slot offset | 3 | $80 for White, or slot offset | 1 for an
; untouched initial-position piece), E = square. Rules (B = value byte, C =
; byte +6):
;
; Pawn: illegal on rank 1 or 8; B=1, C=$80 (White) / $C0 (Black); first free
; pawn slot. King: B=0, or $30 (moved) if entered; C=1; king slot only (a
; second king is illegal). Queen: B=9, C=$0E; queen slot, then pawn slots.
; Rook: B=5, or $15 (moved) if entered; C=8; two rook slots, then pawn slots.
; Bishop: B=$83, C=4; two bishop slots, then pawn slots. Knight: B=3, C=0; two
; knight slots, then pawn slots. No free slot: illegal.
AssignSlot:
  LD L,A                  ; L = set-up code - 1 (bit 1 set = entered by the
  DEC L                   ; user)
  BIT 6,L                 ;
  JR Z,AssignSlot_0       ;
  LD A,$70                ; Pawn: rank 8 or rank 1 is illegal
  AND E                   ;
  JR Z,AssignSlotFail     ;
  CP $70                  ;
  JR Z,AssignSlotFail     ;
  LD B,$01                ; B = 1, C = $80 for White, $C0 for Black; try the
  LD A,$80                ; pawn slots
  AND L                   ;
  XOR $80                 ;
  SCF                     ;
  RRA                     ;
  LD C,A                  ;
  JR AssignSlot_6         ;
AssignSlot_0:
  LD A,$78                ; King: B = 0 (untouched) or $30 (entered), C = 1;
  AND L                   ; only the king slot
  JR NZ,AssignSlot_2      ;
  LD C,$01                ;
  LD B,$00                ;
  BIT 1,L                 ;
  JR Z,AssignSlot_1       ;
  LD B,$30                ;
AssignSlot_1:
  CALL TryPieceSlot       ;
  JR AssignSlotFail       ;
AssignSlot_2:
  CP $10                  ; Queen: B = 9, C = $0E; queen slot then pawn slots
  LD C,$0E                ;
  LD B,$09                ;
  JR C,AssignSlot_5       ;
  JR NZ,AssignSlot_3      ;
  LD C,$08                ; Rook: B = 5 (untouched) or $15 (entered), C = 8
  LD B,$05                ;
  BIT 1,L                 ;
  JR Z,AssignSlot_4       ;
  LD B,$15                ;
  JR AssignSlot_4         ;
AssignSlot_3:
  LD B,$03                ; Knight: B = 3, C = 0; bishop: B = $83, C = 4
  LD C,$00                ;
  CP $20                  ;
  JR NZ,AssignSlot_4      ;
  LD B,$83                ;
  LD C,$04                ;
AssignSlot_4:
  CALL TryPieceSlot       ; Two slots of the piece's own type
AssignSlot_5:
  CALL TryPieceSlot       ; The piece's own (first or only) slot
  LD A,$82                ; Then the pawn slots
  AND L                   ;
  SET 6,A                 ;
  LD L,A                  ;
AssignSlot_6:
  CALL TryPieceSlot       ;
  BIT 6,L                 ;
  JR NZ,AssignSlot_6      ;
AssignSlotFail:
  POP HL                  ; No slot: ILLEGAL
  JP SetupIllegalPop      ;

; Try one piece-list slot
;
; If the slot at L (bit 1 cleared) is free (square bit 7 set), stores the
; square E, the board code (slot | 4) at (DE), the value byte B at +1 and C at
; +6, then returns directly to the caller's caller. Otherwise moves L to the
; next slot and returns.
TryPieceSlot:
  RES 1,L
  LD A,(HL)
  RLA
  JR C,TryPieceSlot_0
  LD A,$08
  ADD A,L
  LD L,A
  RET
TryPieceSlot_0:
  LD (HL),E
  LD A,L
  SET 2,A
  LD (DE),A
  INC L
  LD (HL),B
  SET 2,L
  INC L
  LD (HL),C
  POP BC
  RET

; Replay one ply from the game record
;
; Used by take-back, take-forward, next-best and R (replay). Stops when the ply
; count $C001 reaches the target in HL. Otherwise regenerates the moves, picks
; the recorded index, makes the move (with the recorded promotion piece and
; check flag) and continues through the common after-move code (AfterGameMove).
; The evaluation (Evaluate) is not called for replayed moves.
ReplayStep:
  LD BC,($C001)           ; Reached the target ply: stop
  XOR A                   ;
  SBC HL,BC               ;
  JP Z,ReplayEnd          ;
  LD ($BCCF),HL           ; $BCCF = plies still to replay
  LD HL,($C001)           ; Next record byte: bit 7 = check, bits 0-6 = move
  INC HL                  ; index
  LD ($C001),HL           ;
  LD BC,$C057             ;
  ADD HL,BC               ;
  LD C,(HL)               ;
  LD A,C                  ;
  RES 7,C                 ;
  LD B,$00                ;
  LD HL,$B404             ;
  ADD HL,BC               ;
  ADD HL,BC               ;
  ADD HL,BC               ;
  ADD HL,BC               ;
  PUSH AF                 ; Regenerate the moves for this position
  PUSH HL                 ;
  LD IX,$BD58             ;
  CALL GENMOVES           ;
  POP IX                  ;
  POP AF                  ;
  INC (IX+$00)            ; Score byte $FF -> 0; restore the check flag from
  RLA                     ; the record
  JR NC,ReplayStep_0      ;
  SET 7,(IX+$03)          ;
ReplayStep_0:
  LD A,($BCC3)            ; Replay mode: highlight the from-square
  OR A                    ;
  CALL NZ,ShowFromSquare  ;
  CALL MAKEMOVE           ; Make the move
  XOR A                   ;
  LD ($BCDE),A            ;
  POP AF                  ; Promotion: take the next piece from the promotion
  PUSH AF                 ; list and store it as the piece's value byte
  JP PO,ReplayStep_1      ;
  LD HL,$C047             ;
  INC (HL)                ;
  LD A,(HL)               ;
  ADD A,L                 ;
  LD L,A                  ;
  LD A,(HL)               ;
  LD L,(IX+$02)           ;
  LD H,$BD                ;
  LD L,(HL)               ;
  RES 2,L                 ;
  INC L                   ;
  INC H                   ;
  LD (HL),A               ;
  LD ($BCDE),A            ;
ReplayStep_1:
  LD A,($BCC3)            ; Replay mode: show (and, when printing the record,
  OR A                    ; print) every move
  JR Z,ReplayStep_2       ;
  CALL ShowMove           ;
  CALL ShowToSquare       ;
  LD A,($BCDB)            ;
  OR A                    ;
  CALL NZ,PrinterMove     ;
  JR ReplayStep_3         ;
ReplayStep_2:
  LD HL,($BCCF)           ; Otherwise show only the last two replayed moves
  XOR A                   ;
  LD BC,$0003             ;
  SBC HL,BC               ;
  CALL C,ShowMove         ;
ReplayStep_3:
  LD A,($BCDD)              ; Unless next-best is in progress, clear the root
  OR A                      ; exclusion list; then the common after-move code
  CALL Z,ClearExclusionList ; appends this move to it
  JP AfterGameMove          ;
; This entry point is used by the routine at MainLoop.
ReplayEnd:
  LD HL,$0000             ; Clear the replay target and replay mode; the human
  LD ($C003),HL           ; plays the side to move ($BCBE = side to move bit)
  XOR A                   ;
  LD ($BCC3),A            ;
  LD A,($BD2D)            ;
  AND $01                 ;
  LD ($BCBE),A            ;
  JP MainLoop             ;

; Poll the keyboard
;
; Reads all eight half-rows at once. Returns Z if no key is pressed. If any key
; is pressed shows *INTERRUPTED*, buzzes and returns NZ (A=1). This is the only
; keyboard test made while thinking: the search calls it at every node via
; POLLGEN until the abort flag (bit 7 of $BD4C) is set, and once more after the
; opening book probe (7C23).
PollKeyboard:
  XOR A
  IN A,($FE)
  AND $1F
  CP $1F
  RET Z
  CALL PrintLine12
  DEFM "**INTERRUPTED*"
  DEFB $AA                ; Last character (bit 7 set)
  CALL Beep
  DEFB $C8,$50            ; Inline arguments: duration, pitch
  CALL ClearLine12
  LD A,$01
  OR A
  RET

; Wait for a key
;
; Enables interrupts so that the ROM keyboard scan runs, incrementing the
; random accumulator $BCCE in the waiting loop, and returns the key code (bit 5
; cleared, i.e. upper case) in A and $BCC0, with a click. Interrupts are
; disabled again on return; they are enabled nowhere else, so there is no
; real-time clock while thinking.
WaitKey:
  LD IY,($BCC8)           ; Restore IY for the ROM interrupt routine
  EI                      ;
WaitKey_0:
  LD HL,$BCCE             ; Spin, counting in $BCCE, until FLAGS bit 5 (new
  INC (HL)                ; key)
  LD HL,$5C3B             ;
  BIT 5,(HL)              ;
  JR Z,WaitKey_0          ;
  DI                      ; Take LAST_K, force upper case
  LD A,($5C08)            ;
  RES 5,(HL)              ;
  AND $DF                 ;
  LD ($BCC0),A            ;
  CALL Beep               ;
  DEFB $02,$04            ; Inline arguments: duration, pitch
  LD A,($BCC0)
  RET

; Read a command key
;
; Waits for a key. S toggles the sound and O the board orientation (both
; handled here, then waits again). While the cursor is shown ($BCCA <> $FF) the
; keys 5-8 move it (wrapping within the rank or file; directions follow the
; orientation) and are also handled here. Any other key is returned in A.
GetCommandKey:
  CALL WaitKey
  CP $53
  JR NZ,GetCommandKey_0
  LD A,($BCD3)
  XOR $01
  LD ($BCD3),A
  CALL ShowSound
  CALL Beep
  DEFB $08,$14            ; Inline arguments: duration, pitch
  JR GetCommandKey
GetCommandKey_0:
  CP $4F
  JR NZ,GetCommandKey_1
  LD A,($BCC7)
  XOR $01
  LD ($BCC7),A
  CALL DrawBoard
  JR GetCommandKey
GetCommandKey_1:
  CP $19
  RET NC
  CP $15
  RET C
  LD B,A
  LD A,($BCCA)
  INC A
  LD A,B
  RET Z
  LD A,($BCC7)
  OR A
  LD A,B
  JR Z,GetCommandKey_2
  XOR $01
GetCommandKey_2:
  CP $16
  JR Z,GetCommandKey_4
  CP $17
  JR Z,GetCommandKey_5
  AND $03
  JR Z,GetCommandKey_3
  LD A,($BCCA)
  DEC A
  BIT 3,A
  JR Z,GetCommandKey_6
  ADD A,$08
  JR GetCommandKey_6
GetCommandKey_3:
  LD A,($BCCA)
  INC A
  BIT 3,A
  JR Z,GetCommandKey_6
  SUB $08
  JR GetCommandKey_6
GetCommandKey_4:
  LD A,($BCCA)
  ADD A,$10
  BIT 7,A
  JR Z,GetCommandKey_6
  SUB $80
  JR GetCommandKey_6
GetCommandKey_5:
  LD A,($BCCA)
  SUB $10
  BIT 7,A
  JR Z,GetCommandKey_6
  ADD A,$80
GetCommandKey_6:
  CALL DrawBoardCursor
  JP GetCommandKey

; Read a key and execute a command
;
; Commands D (demo), E (enter both sides) and M (move) are only accepted while
; the game is not over ($BCBF = 0). A, B, C, F, G, L, N, P, R and T jump to
; their handlers; any other key (including ENTER) is returned in A.
CommandDispatch:
  CALL GetCommandKey
  LD A,($BCBF)
  OR A
  LD A,($BCC0)
  JP NZ,CommandDispatch_0
  CP $44
  JR Z,KeyDemo
  CP $45
  JR Z,KeyEnter
  CP $4D
  JP Z,KeyMove
CommandDispatch_0:
  CP $41
  JP Z,KeyAlterColours
  CP $42
  JP Z,KeyTakeBack
  CP $43
  JP Z,ChangePosition
  CP $46
  JP Z,KeyForward
  CP $47
  JP Z,KeyNewGame
  CP $4C
  JP Z,KeyLevel
  CP $4E
  JP Z,KeyNextBest
  CP $50
  JP Z,KeyPrinter
  CP $52
  JP Z,KeyReplay
  CP $54
  JP Z,KeyTape
  RET
KeyDemo:
  LD A,$03                ; D: CYRUS v CYRUS
  LD ($BCC2),A            ;
  CALL ShowHitAnyKey      ;
  JP MainLoop             ;
KeyEnter:
  LD A,$00                ; E: HUMAN v HUMAN
  LD ($BCC2),A            ;
  CALL ShowPlayers        ;
  JP CommandDispatch      ;

; Printer text: Replay
  DEFM "Repla",$F9

; R: replay the whole game
;
; Entry StartReplayAll is also used to print the move record (P then R).
KeyReplay:
  LD A,($C058)
  INC A
  JP Z,CommandDispatch
  LD HL,$6863
  CALL PrinterString
; This entry point is used by the routine at KeyPrinter.
StartReplayAll:
  CALL ClearLine11        ; Replay target $FFFF (to the end of the record),
  CALL ClearLine10        ; replay mode on
  CALL PrintLine12        ;
  LD HL,($4552)           ;
  LD D,B                  ;
  LD C,H                  ;
  LD B,C                  ;
  LD E,C                  ;
  LD C,C                  ;
  LD C,(HL)               ;
  LD B,A                  ;
  XOR D                   ;
  CALL ShowHitAnyKey      ;
  LD A,$01                ;
  LD ($BCC3),A            ;
  LD HL,$FFFF             ;
  JR RestartAndReplay     ;

; Printer text: take-Back
  DEFM "take-Bac",$EB

; B: take back one ply
;
; Implemented by restoring the start position and replaying $C001 - 1 plies.
; Entry RestartAndReplay restores the start position (new game, or the position
; saved at the end of set-up mode) and starts a replay to the ply count in HL.
KeyTakeBack:
  LD HL,($C001)
  LD A,L
  OR H
  JP Z,CommandDispatch
  LD HL,$6897
  CALL PrinterString
; This entry point is used by the routine at KeyNextBest.
TakeBackOnePly:
  LD HL,($C001)
  DEC HL
; This entry point is used by the routines at KeyReplay and KeyTape.
RestartAndReplay:
  LD ($C003),HL           ; Replay target
  LD A,($C006)            ; Start move number; 1 = standard start: reinitialise
  LD ($BD49),A            ; via InitBoard
  DEC A                   ;
  JP Z,NewGameBoard       ;
  CALL ClearBoard         ; Set-up start: clear the board and restore the saved
  LD A,($C005)            ; side to move and the 32 (square, value) pairs
  LD ($BD2D),A            ;
  AND $01                 ;
  LD ($BCBE),A            ;
  LD DE,$C007             ;
  LD HL,$BE00             ;
  LD B,$20                ;
KeyTakeBack_0:
  LD A,(DE)               ;
  LD (HL),A               ;
  INC HL                  ;
  INC DE                  ;
  LD A,(DE)               ;
  LD (HL),A               ;
  INC DE                  ;
  LD A,L                  ;
  ADD A,$07               ;
  LD L,A                  ;
  DJNZ KeyTakeBack_0      ;
  LD HL,$BE00             ; Rebuild the board from the piece lists
  LD DE,$BD00             ;
KeyTakeBack_1:
  LD A,(HL)               ;
  OR A                    ;
  JP M,KeyTakeBack_2      ;
  LD E,A                  ;
  LD A,L                  ;
  OR $04                  ;
  LD (DE),A               ;
KeyTakeBack_2:
  LD A,L                  ;
  ADD A,$08               ;
  LD L,A                  ;
  JR NC,KeyTakeBack_1     ;
  CALL ResetGameCounters  ; Reset the 50-move counter, $BD0D and the
                          ; last-move/repetition data
  LD A,($BCDB)            ; Printing the record: draw and print the start
  OR A                    ; position
  JR Z,KeyTakeBack_3      ;
  CALL DrawBoardNoCursor  ;
  CALL PrinterBoard       ;
KeyTakeBack_3:
  JP GameStartCommon      ;

; Printer text: take-Forward
TextTakeForward:
  DEFM "take-Forwar",$E4

; F: take forward one ply
;
; Replays the next recorded ply, if any.
KeyForward:
  LD HL,($C001)
  LD BC,$C058
  ADD HL,BC
  LD A,(HL)
  INC A
  JP Z,CommandDispatch
  LD HL,TextTakeForward
  CALL PrinterString
  LD HL,($C001)
  INC HL
  LD ($C003),HL
  JP MainLoop

; L: next level
;
; Cycles the level index $BCCD through 0-10 (Levels 1-8, P1, P2, P3) and sets
; the search level $BCBD: Levels 1-8 -> 0-7, P1 -> 0, P2 -> 3, P3 -> 7. There
; is no time limit anywhere: a level is purely a search-size setting.
KeyLevel:
  LD A,($BCCD)            ; $BCCD = (BCCD + 1) mod 11
  INC A                   ;
  CP $0B                  ;
  JR NZ,KeyLevel_0        ;
  XOR A                   ;
KeyLevel_0:
  LD ($BCCD),A            ;
  CP $08                  ; P1 -> 0, P2 -> 3, P3 -> 7, otherwise $BCBD = $BCCD
  JR NZ,KeyLevel_1        ;
  LD A,$00                ;
  JR KeyLevel_3           ;
KeyLevel_1:
  CP $09                  ;
  JR NZ,KeyLevel_2        ;
  LD A,$03                ;
  JR KeyLevel_3           ;
KeyLevel_2:
  CP $0A                  ;
  JR NZ,KeyLevel_3        ;
  LD A,$07                ;
KeyLevel_3:
  LD ($BCBD),A            ;
  CALL ShowLevel          ;
  JP CommandDispatch      ;

; M: Cyrus takes over the side to move
;
; Entry SwapSides swaps the side Cyrus plays ($BCBE) and negates the score
; $BCA0, then continues the main loop.
KeyMove:
  LD A,($BCBE)
  OR A
  LD A,$01
  JR Z,KeyMove_0
  LD A,$02
KeyMove_0:
  LD ($BCC2),A
; This entry point is used by the routines at ComputerMove and HumanMove.
SwapSides:
  LD A,($BCBE)
  OR A
  LD A,$01
  JR Z,KeyMove_1
  XOR A
KeyMove_1:
  LD ($BCBE),A
  LD HL,$BCA0
  XOR A
  SUB (HL)
  LD (HL),A
  JP MainLoop

; G: new game
;
; Used by the routine at CommandDispatch.
KeyNewGame:
  CALL AskNewGame
  JP MainLoop

; Ask NEW GAME? and start one on Y
;
; Used by the routines at KeyNewGame and ChangePosition.
AskNewGame:
  CALL ClearLine10
  CALL PrintLine10
  DEFM "NEW GAME"
  DEFB $BF                ; Last character (bit 7 set)
  CALL PrintCommandArea
  DEFM "Yes  N"
  DEFB $EF                ; Last character (bit 7 set)
  CALL ClearCommandArea
  CALL WaitKey
  CP $59
  JP Z,NewGameConfirmed
  RET

; Printer text: Next-best
TextNextBest:
  DEFM "Next-bes",$F4

; N: next-best move
;
; Sets $BCDD and takes back one ply. Because the root exclusion list at $BF00
; is neither cleared nor extended while $BCDD is set, the retracted move stays
; excluded and the main loop makes Cyrus play the side to move again (611F).
; See S_PASS_EXCLUDE for how the search uses the list.
KeyNextBest:
  LD HL,($C001)
  LD A,L
  OR H
  JP Z,CommandDispatch
  LD HL,TextNextBest
  CALL PrinterString
  LD A,$01
  LD ($BCDD),A
  JP TakeBackOnePly

; P: printer commands
;
; Checks for the ZX Printer (port $FB bit 6), then offers B (print board), R
; (print record via replay) and T (toggle listing).
KeyPrinter:
  IN A,($FB)
  AND $40
  JR Z,KeyPrinter_0
  CALL ClearLine12
  CALL PrintLine12
  DEFM "*NO PRINTER"
  DEFB $AA                ; Last character (bit 7 set)
  CALL Buzz
  CALL ClearLine12
  JP CommandDispatch
KeyPrinter_0:
  CALL ClearLine10
  CALL PrintLine10
  DEFM "COMMAND"
  DEFB $BF                ; Last character (bit 7 set)
  CALL PrintCommandArea
  DEFM "print-Board        print-Record          Toggle-listing          "
  DEFM "   -any other key to exit"
  DEFB $AD                ; Last character (bit 7 set)
  CALL ClearCommandArea
  CALL WaitKey
  CP $42
  JR NZ,KeyPrinter_1
  CALL PrinterBoard
  JP MainLoop
KeyPrinter_1:
  CP $52
  JR NZ,KeyPrinter_2
  LD A,($C058)
  INC A
  JP Z,MainLoop
  LD ($BCDB),A
  CALL PrinterRule
  JP StartReplayAll
KeyPrinter_2:
  CP $54
  JP NZ,MainLoop
  LD A,($BCD4)
  XOR $01
  LD ($BCD4),A
  CALL ShowListing
  JP MainLoop

; A: alter colours
;
; Used by the routine at CommandDispatch.
KeyAlterColours:
  CALL ClearLine10
  CALL PrintCommandArea
  DEFM "0-black 1-blue 2-red 3-magenta  4-green 5-cyan 6-yellow 7-white  "
  DEFM "         8-no change                  D-default colours          "
  DEFM "  -any other key to exit"
  DEFB $AD                ; Last character (bit 7 set)
  CALL ClearCommandArea
  CALL PrintLine10
  DEFM "COLOUR FO"
  DEFB $D2                ; Last character (bit 7 set)
  CALL PrintLine11
  DEFM "BLACK PIECE"
  DEFB $BF                ; Last character (bit 7 set)
  LD HL,$BCD7
  CALL GetColourKey
  CALL PrintLine11
  DEFM "WHITE PIECE"
  DEFB $BF                ; Last character (bit 7 set)
  LD HL,$BCD8
  CALL GetColourKey
  CALL PrintLine11
  DEFM "BLACK SQUARE"
  DEFB $BF                ; Last character (bit 7 set)
  LD HL,$BCD9
  CALL GetColourKey
  CALL PrintLine11
  DEFM "WHITE SQUARE"
  DEFB $BF                ; Last character (bit 7 set)
  LD HL,$BCDA
  CALL GetColourKey
  JP MainLoop

; Read one colour choice
;
; HL = colour variable. 0-7 set it, 8 leaves it, D restores the defaults, any
; other key ends the command.
GetColourKey:
  PUSH HL
GetColourKey_0:
  CALL WaitKey
  CP $44
  JR NZ,GetColourKey_1
  CALL DefaultColours
  CALL DrawBoardNoCursor
  JR GetColourKey_0
GetColourKey_1:
  SUB $10
  JP M,MainLoop
  CP $09
  JP P,MainLoop
  POP HL
  CP $08
  RET Z
  LD (HL),A
  CALL DrawBoardNoCursor
  RET

; Default colour scheme
;
; Black pieces ink 0, white pieces ink 7, black squares paper 4, white squares
; paper 6.
DefaultColours:
  LD A,$00
  LD ($BCD7),A
  LD A,$07
  LD ($BCD8),A
  LD A,$04
  LD ($BCD9),A
  LD A,$06
  LD ($BCDA),A
  RET

; T: save or load the game record
;
; Save: writes $C000 to the end of the record ($FF) as a headerless block
; ($C000 is set to $FF as a marker). Load: reads up to $1F00 bytes to $E000,
; checks the markers and copies them to $C000, then replays the game.
KeyTape:
  CALL ClearLine10
  CALL PrintLine10
  DEFM "COMMAND"
  DEFB $BF                ; Last character (bit 7 set)
  CALL PrintCommandArea
  DEFM "Save-record         Load-record     -any other key to exit"
  DEFB $AD                ; Last character (bit 7 set)
  CALL ClearCommandArea
  CALL WaitKey
  CP $53
  JR NZ,KeyTape_1
  LD A,($C058)
  INC A
  JP Z,MainLoop
  CALL PrintLine10
  DEFM "START TAP"
  DEFB $C5                ; Last character (bit 7 set)
  CALL PrintCommandArea
  DEFM "--Hit any key to initiate save-"
  DEFB $AD                ; Last character (bit 7 set)
  CALL ClearCommandArea
  CALL WaitKey
  CALL PrintLine10
  DEFM "SAVING..."
  DEFB $A0                ; Last character (bit 7 set)
  CALL ShowHitBreak
  LD DE,$0058
  LD HL,$C058
KeyTape_0:
  INC DE
  LD A,(HL)
  INC HL
  INC A
  JR NZ,KeyTape_0
  LD IX,$C000
  LD A,$FF
  LD ($C000),A
  CALL TapeSave
  JP MainLoop
KeyTape_1:
  CP $4C
  JP NZ,MainLoop
  CALL PrintLine10
  DEFM "LOADING.."
  DEFB $AE                ; Last character (bit 7 set)
  CALL ShowHitBreak
  LD DE,$1F00
  SCF
  LD IX,$E000
  LD A,$FF
  CALL TapeLoad
  JR NC,TapeError_0
  LD HL,$E058
  OR A
  PUSH IX
  POP BC
  SBC HL,BC
  LD A,H
  OR A
  JP P,TapeError
  LD A,(IX-$02)
  INC A
  JR NZ,TapeError
  LD A,($E000)
  INC A
  JR NZ,TapeError
  LD HL,$C000
  LD DE,$E000
  LD BC,$1F00
KeyTape_2:
  LD A,(DE)
  LD (HL),A
  INC DE
  INC HL
  DEC BC
  LD A,B
  OR C
  JR NZ,KeyTape_2
  LD HL,TextTapeLoaded
  CALL PrinterString
  LD HL,($C001)
  JP RestartAndReplay

; Printer text: Tape loaded
TextTapeLoaded:
  DEFM "Tape loade",$E4

; Report a tape error
;
; Used by the routine at KeyTape.
TapeError:
  CALL ClearLine12
  CALL PrintLine12
  DEFM "*TAPE ERROR"
  DEFB $AA                ; Last character (bit 7 set)
  CALL Buzz
  CALL ClearLine12
; This entry point is used by the routine at KeyTape.
TapeError_0:
  JP MainLoop

; Save via the ROM
;
; Jumps into SA-BYTES ($04C6) with TapeReturn as the return address.
TapeSave:
  LD HL,TapeReturn
  PUSH HL
  JP $04C6

; Load via the ROM
;
; Jumps into LD-BYTES ($0562) with TapeReturn as the return address.
TapeLoad:
  INC D
  EX AF,AF'
  DEC D
  DI
  LD A,$0F
  OUT ($FE),A
  LD HL,TapeReturn
  PUSH HL
  JP $0562

; Return from the ROM tape routines
;
; Reached by RET from the ROM save/load routines (address pushed at
; TapeSave/TapeLoad). Restores the border, tests BREAK (shows *ABORTED* if
; pressed, returning with carry clear) and clears the ROM's new-key flag.
TapeReturn:
  LD A,$07
  OUT ($FE),A
  LD A,$7F
  IN A,($FE)
  RRA
  EI
  JR C,TapeReturn_0
  CALL ClearLine12
  CALL PrintLine12        ; *ABORTED*
  DEFM "*ABORTED"
  DEFB $AA                ; Last character (bit 7 set)
  CALL Buzz               ; Buzz
  CALL ClearLine12        ;
  LD HL,$5C3B             ;
  RES 5,(HL)              ;
  OR A                    ;
TapeReturn_0:
  RET                     ;

; C: change position (set-up mode)
;
; Pieces are entered as set-up codes (slot offset + $83 for White or + $03 for
; Black; bit 0 set marks a set-up code, bit 1 set marks a piece entered by the
; user). Removing or overwriting a real piece marks its piece-list entry
; absent. On exit (E) nothing happens if neither the position nor the side to
; move changed; otherwise SetupExit validates and installs the position.
ChangePosition:
  CALL ClearLine11        ; Clear the message lines; cursor to the start rank;
  CALL ClearLine12        ; nothing changed yet ($BD4D = 0)
  CALL ClearMoveLines     ;
  CALL CursorToStartRank  ;
  XOR A                   ;
  LD ($BD4D),A            ;
  LD A,($BD2D)            ; Colour for new pieces $BCA2: $83 (WHITE) if White
  RRA                     ; is to move, else $03 (BLACK)
  LD A,$83                ;
  JR C,ChangePosition_0   ;
  LD A,$03                ;
ChangePosition_0:
  LD ($BCA2),A            ;
; This entry point is used by the routine at SetupIllegalPop.
SetupMenu:
  CALL DrawBoard          ; Redraw the board with the cursor; set-up menu
  CALL PrintCommandArea   ;
  DEFM "All-clear     Exit      new-GameOrient'n      Sound             T"
  DEFM "oggle-colour Unoccupied        Pawn       kNight     Bishop    Ro"
  DEFM "ok       Queen      King      5-left 6-down 7-up 8-righ"
  DEFB $F4                ; Last character (bit 7 set)
  CALL ClearCommandArea
  CALL PrintLine10
  DEFM "CHANGE POSITIO"
  DEFB $CE                ; Last character (bit 7 set)
  LD A,($BCA2)
  CP $03
  JR Z,ChangePosition_1
  CALL PrintLine11
  DEFM "WHIT"
  DEFB $C5                ; Last character (bit 7 set)
  JR SetupKey
ChangePosition_1:
  CALL PrintLine11
  DEFM "BLAC"
  DEFB $CB                ; Last character (bit 7 set)
SetupKey:
  CALL GetCommandKey      ; Read a key (cursor keys, S and O are handled by
  CALL ClearLine12        ; GetCommandKey)
  LD A,($BCC0)            ;
  CP $45                  ;
  JP Z,SetupExit          ;
  CP $47                  ; G: new game prompt, then back to set-up
  JR NZ,ChangePosition_2  ;
  CALL ClearLine11        ;
  CALL AskNewGame         ;
  JP SetupMenu            ;
ChangePosition_2:
  CP $54                  ; T: toggle the colour (and the side to move on exit)
  JR NZ,ChangePosition_3  ;
  LD A,($BCA2)            ;
  XOR $80                 ;
  LD ($BCA2),A            ;
  JP SetupMenu            ;
ChangePosition_3:
  CP $41                  ; A: all clear (every piece-list entry absent)
  JR NZ,ChangePosition_4  ;
  CALL ClearBoard         ;
  JR ChangePosition_7     ;
ChangePosition_4:
  CP $55                  ; U: empty the cursor square
  JR NZ,ChangePosition_5  ;
  LD A,($BCCA)            ;
  LD L,A                  ;
  LD H,$BD                ;
  XOR A                   ;
  JR ChangePosition_6     ;
ChangePosition_5:
  LD HL,$6F2F             ; K, Q, R, B, N, P: look up the slot offset for the
  CALL FindPieceRow       ; key; any other key just redraws
  JP C,SetupMenu          ;
  INC HL                  ;
  LD A,(HL)               ;
  LD ($BCA3),A            ;
  LD A,($BCCA)            ; Put the set-up code (offset + colour) on the cursor
  LD L,A                  ; square
  LD H,$BD                ;
  LD A,($BCA3)            ;
  LD B,A                  ;
  LD A,($BCA2)            ;
  ADD A,B                 ;
ChangePosition_6:
  LD C,(HL)               ; If a real piece was there (bit 0 clear, bit 2 set),
  LD (HL),A               ; mark its piece-list entry absent
  BIT 0,C                 ;
  JR NZ,ChangePosition_7  ;
  BIT 2,C                 ;
  JR Z,ChangePosition_7   ;
  RES 2,C                 ;
  LD L,C                  ;
  INC H                   ;
  SET 7,(HL)              ;
ChangePosition_7:
  LD A,$02                ; Position changed
  LD ($BD4D),A            ;
  JP SetupMenu            ;
SetupExit:
  LD A,($BCA2)            ; E: side to move = colour shown. White: Cyrus plays
  LD HL,$BD2D             ; Black ($BCBE = $80), HUMAN v CYRUS; Black: Cyrus
  LD B,(HL)               ; plays White ($BCBE = 0), CYRUS v HUMAN
  RES 0,B                 ;
  SUB $03                 ;
  LD ($BCBE),A            ;
  LD A,$02                ;
  JR Z,ChangePosition_8   ;
  SET 0,B                 ;
  LD A,$01                ;
ChangePosition_8:
  LD ($BCC2),A            ;
  LD A,B                  ; Store the side to move; a change counts as a change
  CP (HL)                 ; of position
  JR Z,ChangePosition_9   ;
  LD (HL),B               ;
  LD A,$02                ;
  LD ($BD4D),A            ;
ChangePosition_9:
  LD A,($BD4D)            ; Nothing changed: back to the game (history kept)
  OR A                    ;
  JP Z,MainLoop           ;
  CALL AssignSetupPieces  ; Give the set-up pieces slots (checks pawns on rank
                          ; 1/8, piece counts and both kings)
  CALL ResetGameCounters  ; Reset the 50-move counter, $BD0D and the
                          ; last-move/repetition data (so no en passant is
                          ; possible)
  LD A,$0A                ; Move number 10; score $BCA0 = $80
  LD ($BD49),A            ;
  LD A,$80                ;
  LD ($BCA0),A            ;
  CALL PRESEARCH          ; Pre-search set-up (PRESEARCH): returns Z if the
  JP Z,SetupIllegal       ; side not to move is in check - ILLEGAL
  CALL SaveStartPosition  ; Save this as the start position; empty the game
  LD A,$FF                ; record
  LD ($C058),A            ;
  LD A,($BCD4)            ; Listing on: print a rule and the board
  OR A                    ;
  JR NZ,ChangePosition_10 ;
  CALL PrinterRule        ;
  CALL PrinterBoard       ;
ChangePosition_10:
  JP GameStartCommon      ; Start the game from here

; Search the piece table
;
; Compares A with every third byte from HL (6 entries). Returns with HL at the
; match, or carry set if none.
FindPieceRow:
  LD B,$06
FindPieceRow_0:
  CP (HL)
  RET Z
  INC HL
  INC HL
  INC HL
  DJNZ FindPieceRow_0
  SCF
  RET

; Piece table and hidden copyright
;
; Six rows of (value byte, key, slot offset): K, Q, R, B, N, P. Searched by
; value from $6F2E and by key from $6F2F.
PieceTable:
  DEFB $00,$4B,$00
  DEFB $09,$51,$08
  DEFB $05,$52,$10
  DEFB $83,$42,$20
  DEFB $03,$4E,$30
  DEFB $01,$50,$40
  DEFM "(C) 1982 Intelligent Software Ltd.Author : Richard Lang" ; Copyright
                                                                 ; notice
                                                                 ; (never
                                                                 ; printed)

; Save the start position
;
; $C005 = side to move ($BD2D), $C006 = move number, $C007-$C046 = (square,
; value) of the 32 piece-list entries.
SaveStartPosition:
  LD A,($BD2D)
  LD ($C005),A
  LD A,($BD49)
  LD ($C006),A
  LD HL,$BE00
  LD DE,$C007
  LD B,$20
SaveStartPosition_0:
  LD A,(HL)
  LD (DE),A
  INC HL
  INC DE
  LD A,(HL)
  LD (DE),A
  INC DE
  LD A,L
  ADD A,$07
  LD L,A
  DJNZ SaveStartPosition_0
  RET

; Reset per-game counters
;
; Zeroes the 50-move counter $BD0A, $BD0D, and $BD59-$BD5E (last two moves and
; the repetition counter). As a result no en passant capture is possible after
; set-up, and a side that is checkmated in the set-up position is reported as
; stalemated.
ResetGameCounters:
  XOR A
  LD ($BD0A),A
  LD ($BD0D),A
  LD HL,$BD59
  LD B,$06
ResetGameCounters_0:
  LD (HL),A
  INC L
  DJNZ ResetGameCounters_0
  RET

; Clear the root exclusion list
;
; Writes the $FF terminator at $BF00.
ClearExclusionList:
  LD A,$FF
  LD ($BF00),A
  RET

; Beep
;
; Two inline bytes follow the CALL: duration (outer count) and pitch
; (half-period). Silent if $BCD3 is set (sound off), but takes the same time.
Beep:
  POP HL
  LD A,(HL)
  INC HL
  LD ($BCD1),A
  LD A,(HL)
  INC HL
  LD ($BCD2),A
  PUSH HL
  LD A,$07
  LD HL,$BCD1
  LD D,(HL)
  LD E,$00
  LD HL,$BCD2
Beep_0:
  LD B,(HL)
  XOR $10
  LD C,A
  LD A,($BCD3)
  OR A
  LD A,C
  JR NZ,Beep_1
  OUT ($FE),A
Beep_1:
  DEC E
  JR NZ,Beep_2
  DEC D
  RET Z
Beep_2:
  DJNZ Beep_1
  JR Beep_0

; Set the print position from two inline bytes
;
; Used by the routines at Start, HumanMove, ClearScreen, ClearLine12,
; ClearLine11, ClearLine10, PrintLine12, PrintLine11, PrintCommandArea,
; PrintLine10, ShowMove, ShowMoveNumber and ShowPlayers.
SetPrintPosInline:
  POP HL
  PUSH AF
  CALL ReadPrintPos
  POP AF
  JP (HL)

; Read the print position (row, column) at HL
;
; Used by the routines at SetPrintPosInline and PrintAtInline.
ReadPrintPos:
  LD A,(HL)
  LD ($BCC5),A
  INC HL
  LD A,(HL)
  LD ($BCC6),A
  INC HL
  RET

; Clear from the print position to the bottom of the screen (attribute $28)
;
; Used by the routines at Start, HumanMove, ChoosePromotion, GameOverNoMoves,
; AskNewGame, KeyPrinter, KeyAlterColours, KeyTape, ChangePosition,
; ShowHitAnyKey and ShowHitBreak.
ClearCommandArea:
  LD A,$18
  LD HL,$BCC5
  SUB (HL)
  LD C,A
  LD A,$20
  LD HL,$BCC6
  SUB (HL)
  LD B,A
  LD A,$28
  LD ($BCC4),A
  JR ClearScreen_1

; Clear the top 18 rows (attribute $38)
;
; Used by the routines at Start and NewGameConfirmed.
ClearScreen:
  CALL SetPrintPosInline
  DEFB $00,$00            ; Inline arguments: row, column
  LD A,$38
  LD ($BCC4),A
  LD C,$12
ClearScreen_0:
  LD B,$20
; This entry point is used by the routine at ClearCommandArea.
ClearScreen_1:
  LD A,$20
  CALL PrintChar
  DJNZ ClearScreen_1
  DEC C
  JR NZ,ClearScreen_0
  RET

; Clear the move display lines (5 and 6)
;
; Used by the routines at NewGameConfirmed and ChangePosition.
ClearMoveLines:
  CALL PrintAtInline
  DEFB $05,$00            ; Inline arguments: row, column
  DEFM "           "
  DEFB $A0                ; Last character (bit 7 set)
  CALL PrintAtInline
  DEFB $06,$04            ; Inline arguments: row, column
  DEFM "          "
  DEFB $A0                ; Last character (bit 7 set)
  RET

; Clear message line 12
;
; Used by the routines at MainLoop, ComputerMove, HumanMove, GameOverNoMoves,
; PollKeyboard, KeyPrinter, TapeError, TapeReturn and ChangePosition.
ClearLine12:
  CALL SetPrintPosInline
  DEFB $0C,$00            ; Inline arguments: row, column
  JR ClearLine10_0

; Clear message line 11
;
; Used by the routines at MainLoop, KeyReplay and ChangePosition.
ClearLine11:
  CALL SetPrintPosInline
  DEFB $0B,$00            ; Inline arguments: row, column
  JR ClearLine10_0

; Clear message line 10
;
; Used by the routines at MainLoop, GameOverNoMoves, KeyReplay, AskNewGame,
; KeyPrinter, KeyAlterColours, KeyTape and S_PASS.
ClearLine10:
  CALL SetPrintPosInline
  DEFB $0A,$00            ; Inline arguments: row, column
; This entry point is used by the routines at ClearLine12 and ClearLine11.
ClearLine10_0:
  CALL PrintInline
  DEFM "              "
  DEFB $A0                ; Last character (bit 7 set)
  RET

; Print a rule of '=' on the ZX Printer
;
; Used by the routines at NewGameConfirmed, KeyPrinter and ChangePosition.
PrinterRule:
  CALL PrinterFlushLine
  LD A,$3D
  LD B,$20
PrinterRule_0:
  CALL PrinterChar
  DJNZ PrinterRule_0

; Send the printer buffer ($5B00) to the ZX Printer and clear it
;
; Used by the routines at PrinterRule, PrinterBoard, PrinterString and
; PrinterMove.
PrinterFlushLine:
  PUSH AF
  PUSH BC
  PUSH HL
  LD HL,$5B00
  XOR A
  OUT ($FB),A
  LD B,$08
PrinterFlushLine_0:
  IN A,($FB)
  AND $80
  JR Z,PrinterFlushLine_0
  LD C,$20
PrinterFlushLine_1:
  CALL PrinterSendByte
  LD A,L
  ADD A,$08
  LD L,A
  DEC C
  JR NZ,PrinterFlushLine_1
  INC HL
  DJNZ PrinterFlushLine_0
  LD A,$04
  OUT ($FB),A
  CALL PrinterClearBuffer
  POP HL
  POP BC
  POP AF
  RET

; Clear the printer buffer
;
; Used by the routines at ColdStart and PrinterFlushLine.
PrinterClearBuffer:
  XOR A
  LD ($BCDC),A
  LD B,A
  LD HL,$5B00
PrinterClearBuffer_0:
  LD (HL),A
  INC HL
  DJNZ PrinterClearBuffer_0
  RET

; Send one byte of pixels to the ZX Printer
;
; Used by the routine at PrinterFlushLine.
PrinterSendByte:
  PUSH BC
  LD B,$08
PrinterSendByte_0:
  IN A,($FB)
  AND $01
  JR Z,PrinterSendByte_0
  XOR A
  RL (HL)
  JR NC,PrinterSendByte_1
  SET 7,A
PrinterSendByte_1:
  OUT ($FB),A
  DJNZ PrinterSendByte_0
  POP BC
  RET

; Highlight the move's from-square and beep
;
; Used by the routines at PlayMove and ReplayStep.
ShowFromSquare:
  LD A,(IX+$01)
  CALL DrawBoardCursor
  JR ShowToSquare_0

; Highlight the move's to-square and beep
;
; Used by the routines at PlayMove and ReplayStep.
ShowToSquare:
  LD A,(IX+$02)
  CALL DrawBoardCursor
; This entry point is used by the routine at ShowFromSquare.
ShowToSquare_0:
  CALL Beep
  DEFB $96,$28            ; Inline arguments: duration, pitch
  RET

; Put the cursor on the a-file square in front of the side to move's pieces
;
; $60 (a2) for White, $10 (a7) for Black.
CursorToStartRank:
  LD A,($BD2D)
  RRA
  LD A,$10
  JR NC,DrawBoardCursor
  LD A,$60
  JR DrawBoardCursor

; Draw the board without the cursor
;
; Used by the routines at MainLoop, ComputerMove, GameOverNoMoves, KeyTakeBack
; and GetColourKey.
DrawBoardNoCursor:
  LD A,$FF

; Draw the board with the cursor at A
;
; Used by the routines at GetCommandKey, ShowFromSquare, ShowToSquare and
; CursorToStartRank.
DrawBoardCursor:
  LD ($BCCA),A

; Draw the board
;
; Draws each square as a 2x2 block (DrawGlyph2x2) chosen from the piece's value
; byte, flashing the cursor square, then the rank and file labels.
DrawBoard:
  EXX
  LD H,$BE
  EXX
  LD HL,$BD00
  LD B,$00
DrawBoard_0:
  LD C,$10
DrawBoard_1:
  LD A,L
  AND $11
  OR A
  JR Z,DrawBoard_2
  CP $11
DrawBoard_2:
  LD A,($BCDA)
  JR Z,DrawBoard_3
  LD A,($BCD9)
DrawBoard_3:
  SLA A
  SLA A
  SLA A
  LD D,A
  LD A,($BCD7)
  ADD A,D
  OR $40
  LD ($BCC4),A
  PUSH HL
  LD A,($BCC7)
  OR A
  JR Z,DrawBoard_4
  LD A,$77
  SUB L
  LD L,A
DrawBoard_4:
  LD A,($BCCA)
  CP L
  JR NZ,DrawBoard_5
  LD A,($BCC4)
  OR $80
  LD ($BCC4),A
DrawBoard_5:
  LD A,(HL)
  POP HL
  EXX
  OR A
  JR NZ,DrawBoard_6
  CALL DrawGlyph2x2
  DEFB $20,$20,$20,$20    ; Inline: empty square
  JR DrawBoard_14
DrawBoard_6:
  LD D,A
  AND $F8
  INC A
  LD L,A
  BIT 7,L
  JR Z,DrawBoard_7
  LD A,($BCC4)
  AND $F8
  LD E,A
  LD A,($BCD8)
  OR E
  LD ($BCC4),A
DrawBoard_7:
  LD A,D
  AND $7F
  CP $43
  JR Z,DrawBoard_9
  LD A,$0F
  AND (HL)
  JR NZ,DrawBoard_8
  CALL DrawGlyph2x2
  DEFB $A4,$A5,$A2,$A3    ; Inline: king
  JR DrawBoard_14
DrawBoard_8:
  CP $01
  JR NZ,DrawBoard_10
DrawBoard_9:
  CALL DrawGlyph2x2
  DEFB $90,$91,$92,$93    ; Inline: pawn
  JR DrawBoard_14
DrawBoard_10:
  CP $05
  JR NZ,DrawBoard_11
  CALL DrawGlyph2x2
  DEFB $9C,$9D,$9E,$9F    ; Inline: rook
  JR DrawBoard_14
DrawBoard_11:
  JR C,DrawBoard_12
  CALL DrawGlyph2x2
  DEFB $A0,$A1,$A2,$A3    ; Inline: queen
  JR DrawBoard_14
DrawBoard_12:
  BIT 7,(HL)
  JR NZ,DrawBoard_13
  CALL DrawGlyph2x2
  DEFB $94,$95,$96,$97    ; Inline: knight
  JR DrawBoard_14
DrawBoard_13:
  CALL DrawGlyph2x2
  DEFB $98,$99,$9A,$9B    ; Inline: bishop
DrawBoard_14:
  EXX                     ; Next square
  INC C                   ;
  INC C                   ;
  INC HL                  ;
  BIT 3,L                 ;
  JP Z,DrawBoard_1        ;
  INC B                   ;
  INC B                   ;
  LD DE,$0008             ;
  ADD HL,DE               ;
  BIT 7,L                 ;
  JP Z,DrawBoard_0        ;
  LD A,$01                ;
  LD ($BCC5),A            ;
  LD A,$0F                ;
  LD ($BCC6),A            ;
  LD A,$38                ;
  LD ($BCC4),A            ;
  LD B,$08                ;
  LD C,$00                ;
DrawBoard_15:
  LD A,($BCC7)            ;
  OR A                    ;
  LD A,C                  ;
  JR NZ,DrawBoard_16      ;
  LD A,$07                ;
  SUB C                   ;
DrawBoard_16:
  ADD A,$31               ;
  CALL PrintChar          ;
  LD HL,$BCC6             ;
  DEC (HL)                ;
  LD HL,$BCC5             ;
  INC (HL)                ;
  INC (HL)                ;
  INC C                   ;
  DJNZ DrawBoard_15       ;
  LD A,$10                ;
  LD ($BCC5),A            ;
  LD ($BCC6),A            ;
  LD B,$08                ;
  LD C,$00                ;
DrawBoard_17:
  LD A,($BCC7)            ;
  OR A                    ;
  LD A,C                  ;
  JR Z,DrawBoard_18       ;
  LD A,$07                ;
  SUB C                   ;
DrawBoard_18:
  ADD A,$41               ;
  CALL PrintChar          ;
  LD HL,$BCC6             ;
  INC (HL)                ;
  INC C                   ;
  DJNZ DrawBoard_17       ;
  RET                     ;

; Draw a 2x2 character block
;
; Four inline character codes follow the CALL (top-left, top-right,
; bottom-left, bottom-right).
DrawGlyph2x2:
  EXX
  LD A,B
  LD ($BCC5),A
  LD A,C
  LD ($BCC6),A
  EXX
  EX (SP),HL
  CALL PrintCharHL
  CALL PrintCharHL
  EXX
  LD A,B
  INC A
  LD ($BCC5),A
  LD A,C
  LD ($BCC6),A
  EXX
  CALL PrintCharHL
  CALL PrintCharHL
  EX (SP),HL
  RET

; Print the character at HL and advance HL
;
; Used by the routine at DrawGlyph2x2.
PrintCharHL:
  LD A,(HL)
  INC HL

; Print a character on the screen
;
; At (row $BCC5, column $BCC6) with attribute $BCC4. Codes $90 and above are
; piece graphics at PieceGraphics; others use the font at (CHARS copy $BCD5).
PrintChar:
  LD ($BCC1),A
  PUSH AF
  PUSH BC
  PUSH DE
  PUSH HL
  LD H,$00
  LD A,($BCC5)
  LD L,A
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  LD A,($BCC6)
  ADD A,L
  LD L,A
  LD BC,$5800
  ADD HL,BC
  LD A,($BCC4)
  LD (HL),A
  LD A,($BCC1)
  LD H,$00
  LD L,A
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  CP $90
  JR NC,PrintChar_0
  LD BC,($BCD5)
  JP PrintChar_1
PrintChar_0:
  LD BC,$714C
PrintChar_1:
  ADD HL,BC
  LD D,H
  LD E,L
  LD A,($BCC5)
  AND $18
  LD H,A
  LD A,($BCC5)
  AND $07
  SLA A
  SLA A
  SLA A
  SLA A
  SLA A
  LD L,A
  LD A,($BCC6)
  ADD A,L
  LD L,A
  LD BC,$4000
  ADD HL,BC
  LD B,$08
PrintChar_2:
  LD A,(DE)
  LD (HL),A
  INC DE
  INC H
  DJNZ PrintChar_2
  LD A,($BCC6)
  INC A
  CP $20
  JR C,PrintChar_3
  XOR A
  LD HL,$BCC5
  INC (HL)
PrintChar_3:
  LD ($BCC6),A
  POP HL
  POP DE
  POP BC
  POP AF
  RET

; Print a character via the output vector in IY
;
; Used by the routines at FormatMove, FormatSquare and ShowMoveNumber.
OutputVector:
  JP (IY)

; Print the board on the ZX Printer
;
; Used by the routines at KeyTakeBack, KeyPrinter and ChangePosition.
PrinterBoard:
  EXX
  LD H,$BE
  EXX
  LD HL,$BD00
  CALL PrinterFlushLine
  LD B,$08
PrinterBoard_0:
  DEC B
  LD A,$20
  CALL PrinterChar
  CALL PrinterChar
  LD A,($BCC7)
  OR A
  LD A,B
  JR Z,PrinterBoard_1
  LD A,$07
  SUB B
PrinterBoard_1:
  ADD A,$31
  CALL PrinterChar
PrinterBoard_2:
  LD A,$20
  CALL PrinterChar
  PUSH HL
  LD A,($BCC7)
  OR A
  JR Z,PrinterBoard_3
  LD A,$77
  SUB L
  LD L,A
PrinterBoard_3:
  LD A,(HL)
  POP HL
  EXX
  OR A
  JR NZ,PrinterBoard_4
  LD A,$2E
  JR PrinterBoard_6
PrinterBoard_4:
  AND $F8
  INC A
  LD L,A
  LD A,$0F
  AND (HL)
  LD C,$4B
  JR Z,PrinterBoard_5
  CP $01
  LD C,$50
  JR Z,PrinterBoard_5
  CP $05
  LD C,$52
  JR Z,PrinterBoard_5
  LD C,$51
  JR NC,PrinterBoard_5
  BIT 7,(HL)
  LD C,$4E
  JR Z,PrinterBoard_5
  LD C,$42
PrinterBoard_5:
  LD A,C
  BIT 7,L
  JR NZ,PrinterBoard_6
  OR $20
PrinterBoard_6:
  CALL PrinterChar
  EXX
  INC HL
  BIT 3,L
  JR Z,PrinterBoard_2
  CALL PrinterFlushLine
  CALL PrinterFlushLine
  LD DE,$0008
  ADD HL,DE
  BIT 7,L
  JP Z,PrinterBoard_0
  LD A,$20
  CALL PrinterChar
  CALL PrinterChar
  CALL PrinterChar
  LD B,$08
  LD C,$00
PrinterBoard_7:
  LD A,$20
  CALL PrinterChar
  LD A,($BCC7)
  OR A
  LD A,C
  JR Z,PrinterBoard_8
  LD A,$07
  SUB C
PrinterBoard_8:
  ADD A,$41
  CALL PrinterChar
  LD HL,$BCC6
  INC (HL)
  INC C
  DJNZ PrinterBoard_7
  CALL PrinterFlushLine
  JP PrinterFlushLine

; Put a character into the printer buffer
;
; Used by the routines at PrinterRule, PrinterBoard and PrinterString.
PrinterChar:
  PUSH AF
  PUSH BC
  PUSH DE
  PUSH HL
  LD H,$00
  LD L,A
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  LD BC,($BCD5)
  ADD HL,BC
  LD D,H
  LD E,L
  LD A,($BCDC)
  LD H,$00
  LD L,A
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  LD BC,$5B00
  ADD HL,BC
  LD B,$08
PrinterChar_0:
  LD A,(DE)
  LD (HL),A
  INC DE
  INC HL
  DJNZ PrinterChar_0
  LD HL,$BCDC
  INC (HL)
  POP HL
  POP DE
  POP BC
  POP AF
  RET

; Show LEVEL n or LEVEL Pn
;
; Used by the routines at MainLoop and KeyLevel.
ShowLevel:
  CALL PrintAtInline
  DEFB $0E,$00            ; Inline arguments: row, column
  DEFM "LEVEL"
  DEFB $A0                ; Last character (bit 7 set)
  LD A,($BCCD)
  PUSH AF
  AND $08
  LD A,$20
  JR Z,ShowLevel_0
  LD A,$50
ShowLevel_0:
  CALL PrintChar
  POP AF
  AND $07
  ADD A,$31
  JP PrintChar

; Show ILLEGAL and buzz
;
; Used by the routines at HumanMove and SetupIllegalPop.
ShowIllegal:
  CALL PrintLine12
  DEFM "ILLEGA"
  DEFB $CC                ; Last character (bit 7 set)

; Error buzz
;
; Used by the routines at ComputerMove, KeyPrinter, TapeError and TapeReturn.
Buzz:
  CALL Beep
  DEFB $FF,$80            ; Inline arguments: duration, pitch
  RET

; Show "-Hit any key to restore control-"
;
; Used by the routines at ComputerMove, CommandDispatch and KeyReplay.
ShowHitAnyKey:
  CALL PrintCommandArea
  DEFM "-Hit any key to restore control"
  DEFB $AD                ; Last character (bit 7 set)
  JP ClearCommandArea

; Show "--Hit BREAK key to abort-"
;
; Used by the routine at KeyTape.
ShowHitBreak:
  CALL PrintCommandArea
  DEFM "   --Hit BREAK key to abort-"
  DEFB $AD                ; Last character (bit 7 set)
  JP ClearCommandArea

; Print an inline string at (12,0)
;
; Used by the routines at ComputerMove, ChoosePromotion, PollKeyboard,
; KeyReplay, KeyPrinter, TapeError, TapeReturn and ShowIllegal.
PrintLine12:
  CALL SetPrintPosInline
  DEFB $0C,$00            ; Inline arguments: row, column
  JR PrintInline

; Print an inline string at (11,0)
;
; Used by the routines at GameOverNoMoves, KeyAlterColours and ChangePosition.
PrintLine11:
  CALL SetPrintPosInline
  DEFB $0B,$00            ; Inline arguments: row, column
  JR PrintInline

; Print an inline string at (18,0) in the command area colours
;
; Used by the routines at HumanMove, ChoosePromotion, GameOverNoMoves,
; AskNewGame, KeyPrinter, KeyAlterColours, KeyTape, ChangePosition,
; ShowHitAnyKey and ShowHitBreak.
PrintCommandArea:
  CALL SetPrintPosInline
  DEFB $12,$00            ; Inline arguments: row, column
  LD A,$28
  JR PrintInlineAttr

; Print an inline string at (10,0)
;
; Used by the routines at HumanMove, AskNewGame, KeyPrinter, KeyAlterColours,
; KeyTape, ChangePosition and S_PASS.
PrintLine10:
  CALL SetPrintPosInline
  DEFB $0A,$00            ; Inline arguments: row, column
  JR PrintInline

; Print an inline string at an inline position
;
; Two inline bytes (row, column) then a string whose last character has bit 7
; set.
PrintAtInline:
  POP HL
  CALL ReadPrintPos
  PUSH HL

; Print an inline string at the current position
;
; Entry PrintInlineAttr uses the attribute in A instead of $38.
PrintInline:
  LD A,$38
; This entry point is used by the routine at PrintCommandArea.
PrintInlineAttr:
  LD ($BCC4),A
  POP HL
PrintInline_0:
  LD A,(HL)
  AND $7F
  CALL PrintChar
  BIT 7,(HL)
  INC HL
  JR Z,PrintInline_0
  JP (HL)

; Print the game result on the ZX Printer (listing on, or while printing the
; record)
;
; Used by the routine at GameOverNoMoves.
PrinterResult:
  LD A,($BCD4)
  OR A
  JR Z,PrinterResult_0
  LD A,($BCDB)
  OR A
  RET Z
PrinterResult_0:
  LD A,$07
  JR PrinterString_0

; Print the string at HL on the ZX Printer if listing is on
;
; Used by the routines at KeyReplay, KeyTakeBack, KeyForward, KeyNextBest and
; KeyTape.
PrinterString:
  LD A,($BCD4)
  OR A
  RET NZ
  XOR A
; This entry point is used by the routine at PrinterResult.
PrinterString_0:
  LD ($BCDC),A
PrinterString_1:
  LD A,(HL)
  AND $7F
  CALL PrinterChar
  BIT 7,(HL)
  INC HL
  JR Z,PrinterString_1
  JP PrinterFlushLine

; Print the move at IX on the ZX Printer
;
; Used by the routines at PlayMove and ReplayStep.
PrinterMove:
  LD IY,PrinterChar
  LD A,($BD2D)
  RRA
  JR NC,PrinterMove_0
  CALL PrinterMoveNumber
  LD A,$04
  JR PrinterMove_1
PrinterMove_0:
  LD A,$0E
PrinterMove_1:
  LD ($BCDC),A
  CALL FormatMove
  JP PrinterFlushLine

; Show the move at IX in the message area
;
; Used by the routines at PlayMove and ReplayStep.
ShowMove:
  LD IY,PrintChar
  LD A,$38
  LD ($BCC4),A
  CALL ShowMoveNumber
  LD A,($BD2D)
  RRA
  JR NC,ShowMove_0
  CALL PrintAtInline
  DEFB $06,$04            ; Inline arguments: row, column
  DEFM "          "
  DEFB $A0                ; Last character (bit 7 set)
  CALL SetPrintPosInline
  DEFB $05,$04            ; Inline arguments: row, column
  JR FormatMove
ShowMove_0:
  CALL PrintAtInline
  DEFB $06,$04            ; Inline arguments: row, column
  DEFM ".."
  DEFB $AE                ; Last character (bit 7 set)

; Output a move
;
; From-square, '-' or 'x' (capture flag, bit 3 of IX+3), to-square, '/' and the
; promotion piece if $BCDE is set, '+' if bit 7 of IX+3 (check) is set.
FormatMove:
  LD A,(IX+$01)
  CALL FormatSquare
  LD A,$2D
  BIT 3,(IX+$03)
  JR Z,FormatMove_0
  LD A,$78
FormatMove_0:
  CALL OutputVector
  LD A,(IX+$02)
  CALL FormatSquare
  LD HL,$BCDE
  LD A,(HL)
  OR A
  JR Z,FormatMove_2
  LD A,$2F
  CALL OutputVector
  LD A,(HL)
  AND $0F
  CP $05
  LD C,$52
  JR Z,FormatMove_1
  LD C,$51
  JR NC,FormatMove_1
  BIT 7,(HL)
  LD C,$4E
  JR Z,FormatMove_1
  LD C,$42
FormatMove_1:
  LD A,C
  CALL OutputVector
FormatMove_2:
  BIT 7,(IX+$03)
  LD A,$20
  JR Z,FormatMove_3
  LD A,$2B
FormatMove_3:
  CALL OutputVector
  LD A,($BCDE)
  OR A
  LD A,$20
  CALL Z,OutputVector
  CALL Z,OutputVector
  RET

; Show a square on the screen
;
; Used by the routine at HumanMove.
ShowSquare:
  LD IY,PrintChar

; Output a square
;
; File letter A-H from bits 0-2; rank digit = '8' - row.
FormatSquare:
  LD B,A
  AND $07
  ADD A,$41
  CALL OutputVector
  LD A,$70
  AND B
  RRA
  RRA
  RRA
  RRA
  NEG
  ADD A,$38
  JP OutputVector

; Print the move number on the ZX Printer
;
; Used by the routine at PrinterMove.
PrinterMoveNumber:
  LD IY,PrinterChar
  XOR A
  LD ($BCDC),A
  JR FormatMoveNumber

; Show the move number at (5,0)
;
; Used by the routine at ShowMove.
ShowMoveNumber:
  LD IY,PrintChar
  CALL SetPrintPosInline
  DEFB $05,$00            ; Inline arguments: row, column
; This entry point is used by the routine at PrinterMoveNumber.
FormatMoveNumber:
  LD A,($BD49)
  LD B,$FF
ShowMoveNumber_0:
  INC B
  SUB $0A
  JR NC,ShowMoveNumber_0
  PUSH AF
  LD A,B
  CP $0A
  JR C,ShowMoveNumber_2
  LD B,$FF
ShowMoveNumber_1:
  INC B
  SUB $0A
  JR NC,ShowMoveNumber_1
  PUSH AF
  LD A,B
  ADD A,$30
  CALL OutputVector
  POP AF
  ADD A,$0A
  JP ShowMoveNumber_3
ShowMoveNumber_2:
  PUSH AF
  LD A,$20
  CALL OutputVector
  POP AF
  OR A
  JR Z,ShowMoveNumber_4
ShowMoveNumber_3:
  ADD A,$30
  CALL OutputVector
ShowMoveNumber_4:
  POP AF
  ADD A,$3A
  CALL OutputVector
  LD A,$20
  JP OutputVector

; Set the players from the side Cyrus plays
;
; $BCC2 = 1 (HUMAN v CYRUS) if $BCBE is non-zero, else 2 (CYRUS v HUMAN); then
; shows the players.
SetPlayers:
  LD A,($BCBE)
  OR A
  LD A,$02
  JR Z,SetPlayers_0
  DEC A
SetPlayers_0:
  LD ($BCC2),A

; Show the players line
;
; Bit 1 of $BCC2 selects CYRUS/HUMAN for White, bit 0 for Black.
ShowPlayers:
  CALL SetPrintPosInline
  DEFB $00,$01            ; Inline arguments: row, column
  LD A,($BCC2)
  AND $02
  CALL PrintPlayerName
  CALL PrintInline
  DEFM " v"
  DEFB $A0                ; Last character (bit 7 set)
  LD A,($BCC2)
  AND $01

; Print CYRUS (NZ) or HUMAN (Z)
;
; Used by the routine at ShowPlayers.
PrintPlayerName:
  JR Z,PrintPlayerName_0
  CALL PrintInline
  DEFM "CYRU"
  DEFB $D3                ; Last character (bit 7 set)
  RET
PrintPlayerName_0:
  CALL PrintInline
  DEFM "HUMA"
  DEFB $CE                ; Last character (bit 7 set)
  RET

; Show LISTING ON/OFF
;
; Used by the routines at MainLoop and KeyPrinter.
ShowListing:
  CALL PrintAtInline
  DEFB $10,$00            ; Inline arguments: row, column
  DEFM "LISTING"
  DEFB $A0                ; Last character (bit 7 set)
  LD A,($BCD4)
  OR A
  JR Z,ShowSound_0
; This entry point is used by the routine at ShowSound.
ShowListing_0:
  CALL PrintInline
  DEFM "OF"
  DEFB $C6                ; Last character (bit 7 set)
  RET

; Show SOUND ON/OFF
;
; Used by the routines at MainLoop and GetCommandKey.
ShowSound:
  CALL PrintAtInline
  DEFB $0F,$00            ; Inline arguments: row, column
  DEFM "SOUND"
  DEFB $A0                ; Last character (bit 7 set)
  LD A,($BCD3)
  OR A
  JR NZ,ShowListing_0
; This entry point is used by the routine at ShowListing.
ShowSound_0:
  CALL PrintInline
  DEFM "ON"
  DEFB $A0                ; Last character (bit 7 set)
  RET

; Piece graphics
;
; 22 characters ($90-$A5) of 8 bytes: pawn $90-$93, knight $94-$97, bishop
; $98-$9B, rook $9C-$9F, queen $A0-$A3, king top $A4-$A5 (it shares the queen's
; bottom half).
PieceGraphics:
  DEFB $00,$00,$00,$00,$01,$03,$03,$01
  DEFB $00,$00,$00,$00,$80,$C0,$C0,$80
  DEFB $03,$01,$01,$01,$03,$07,$00,$00
  DEFB $C0,$80,$80,$80,$C0,$E0,$00,$00
  DEFB $00,$00,$01,$03,$06,$0F,$1F,$1E
  DEFB $00,$00,$40,$E0,$F0,$F0,$F0,$F0
  DEFB $0D,$01,$03,$03,$07,$07,$00,$00
  DEFB $F0,$F8,$F8,$F8,$F8,$F8,$00,$00
  DEFB $00,$00,$01,$03,$06,$0E,$18,$18
  DEFB $00,$00,$80,$C0,$60,$70,$18,$18
  DEFB $0E,$06,$03,$01,$1D,$37,$00,$00
  DEFB $70,$60,$C0,$80,$B8,$EC,$00,$00
  DEFB $00,$00,$00,$00,$0A,$0F,$07,$03
  DEFB $00,$00,$00,$00,$50,$F0,$E0,$C0
  DEFB $03,$03,$03,$07,$0F,$1F,$00,$00
  DEFB $C0,$C0,$C0,$E0,$F0,$F8,$00,$00
  DEFB $00,$00,$04,$0E,$24,$74,$24,$3F
  DEFB $00,$00,$20,$70,$24,$2E,$24,$FC
  DEFB $3F,$3F,$10,$1F,$08,$0F,$00,$00
  DEFB $FC,$FC,$08,$F8,$10,$F0,$00,$00
  DEFB $00,$00,$01,$01,$07,$37,$31,$3D
  DEFB $00,$00,$80,$80,$E0,$EC,$8C,$BC

; Unused
  DEFS $0184

; Knight move offsets
;
; 0x88 offsets used by the move generator: +14, +18, +31, +33, -14, -18, -31,
; -33.
KnightOffsets:
  DEFB $0E,$12,$1F,$21,$F2,$EE,$E1,$DF

; Diagonal and orthogonal direction offsets
;
; $7808: diagonals +15, +17, -17, -15; $780C: orthogonals +1, -1, +16, -16.
; King and queen use all eight from $7808; bishops $7808-$780B; rooks
; $780C-$780F.
DiagonalOffsets:
  DEFB $0F,$11,$EF,$F1
OrthogonalOffsets:
  DEFB $01,$FF,$10,$F0

; Pre-search set-up: evaluation, material balance and game-phase flags
;
; Called once before each computer search (from S_THINK and ChangePosition).
; Evaluates the current position with the side-to-move bit temporarily flipped,
; then derives $BD1E (score bias), $BD4A (accumulator), $BD2E (material
; difference x8, clamped) and the game-phase bits 1-4 of $BD2D. Bit 0 of $BD2D
; is left as it was on entry.
;
; O:A Result of the evaluation call at $781C (flags set by OR A)
PRESEARCH:
  LD IX,$BD58             ; IX = root move record at $BD58 (the last move
                          ; played in the game)
  LD A,($BD2D)            ; Flip bit 0 of $BD2D (side to move) for the
  XOR $01                 ; evaluation call
  LD ($BD2D),A            ;
  CALL Evaluate           ; Evaluate (returns score in A and a second value in
                          ; B)
  PUSH AF                 ; Keep the evaluation result for the return value
  LD A,($BCA0)            ; E = ($BCA0) + $80 (signed: previous root score
  ADD A,$80               ; re-biased)
  LD E,A                  ;
  LD A,($BCBE)            ; If $BCBE is non-zero, negate B and E
  OR A                    ;
  JR Z,PRESEARCH_0        ;
  XOR A                   ; B = -B
  SUB B                   ;
  LD B,A                  ;
  XOR A                   ; E = -E
  SUB E                   ;
  LD E,A                  ;
PRESEARCH_0:
  LD A,($BD2E)            ; A = old $BD2E (material difference x8 from the
                          ; previous call)
  SRA A                   ; A = A SRA 1
  SRA E                   ; E = E SRA 1
  ADD A,E                 ; A = A + E
  SRA A                   ; A = A SRA 2
  SRA A                   ;
  JR Z,PRESEARCH_1        ; If the result is non-zero, add 1 (rounds towards
  INC A                   ; +infinity)
PRESEARCH_1:
  LD ($BD1E),A            ; Store in $BD1E
  LD A,($BD4A)            ; $BD4A = $BD4A + B (8-bit, wraps)
  ADD A,B                 ;
  LD ($BD4A),A            ;
  LD HL,$BE08             ; HL = White piece records from the queen ($BE08); 15
                          ; records follow
  XOR A                   ; Clear the pawns-present flag $BD6D
  LD ($BD6D),A            ;
  CALL MATERIAL           ; C = White material (sum of value nibbles)
  LD E,C                  ; E = White material
  LD L,$88                ; HL = Black piece records from the queen ($BE88)
  CALL MATERIAL           ; C = Black material
  LD A,C                  ; A = Black - White material (8-bit)
  SUB E                   ;
  CP $0E                  ; 0..13: keep
  JR C,PRESEARCH_2        ;
  CP $F2                  ; -14..-1: keep
  JR NC,PRESEARCH_2       ;
  RLA                     ; Otherwise clamp: +14 if positive, -14 if negative
  LD A,$0E                ;
  JR NC,PRESEARCH_2       ;
  LD A,$F2                ;
PRESEARCH_2:
  ADD A,A                 ; Multiply by 8 (range -112..+112)
  ADD A,A                 ;
  ADD A,A                 ;
  LD ($BD2E),A            ; Store the material difference term in $BD2E
  LD A,($BD49)            ; A = move number ($BD49)
  LD B,$00                ; B = phase bits = 0
  CP $08                  ; Before move 8: phase bits stay 0 (opening)
  JR C,PRESEARCH_3        ;
  LD A,C                  ; A = total material of both sides (Black + White)
  ADD A,E                 ;
  SET 1,B                 ; Phase bit 1: move number >= 8
  CP $34                  ; Total >= 52: done (bits = %00010)
  JR NC,PRESEARCH_3       ;
  SET 2,B                 ; Phase bit 2: total < 52
  CP $28                  ; Total >= 40: done (%00110)
  JR NC,PRESEARCH_3       ;
  SET 3,B                 ; Phase bit 3: total < 40
  CP $19                  ; Total >= 25: done (%01110)
  JR NC,PRESEARCH_3       ;
  SET 4,B                 ; Phase bit 4: total < 25 (%11110)
PRESEARCH_3:
  LD HL,$BD2D             ; $BD2D = (restored side bit) + phase bits
  LD A,(HL)               ;
  INC A                   ; Flip bit 0 back to its value on entry
  AND $01                 ;
  ADD A,B                 ; Add the phase bits (bits 1-4)
  LD (HL),A               ;
  POP AF                  ; Return the evaluation result
  OR A                    ;
  RET                     ;

; Sum material of one side's non-king pieces
;
; Adds the value nibble (+1 AND $0F) of 15 piece records starting at HL (stride
; 8), skipping records whose square byte has bit 7 set (captured). Sets $BD6D
; to 1 if any record has value 1 (a pawn).
;
;   HL Address of the first record to count ($BE08 or $BE88)
; O:C Total material (8-bit)
MATERIAL:
  LD C,$00                ; C = running total
  LD B,$0F                ; B = 15 records (Q, R, R, B, B, N, N, P x 8)
MATERIAL_0:
  BIT 7,(HL)              ; Skip if captured (square byte bit 7 set)
  JR NZ,MATERIAL_2        ;
  INC L                   ; A = value nibble of the type byte
  LD A,(HL)               ;
  AND $0F                 ;
  CP $01                  ; A pawn?
  JR NZ,MATERIAL_1        ;
  LD ($BD6D),A            ; Yes: $BD6D = 1 (pawns present)
MATERIAL_1:
  ADD A,C                 ; C = C + value
  LD C,A                  ;
  DEC L                   ; Back to the square byte
MATERIAL_2:
  LD A,$08                ; Next record (+8)
  ADD A,L                 ;
  LD L,A                  ;
  DJNZ MATERIAL_0         ;
  RET                     ;

; Poll the keyboard, then generate moves
;
; Called by the search (S_NODE) at every node where moves are generated. If no
; abort is pending, any key held down sets the abort flag ($BD4C bit 7) and
; updates the display via SetPlayers. Then falls through to GENMOVES.
POLLGEN:
  LD HL,$BD4C             ; Abort already pending ($BD4C bit 7)?
  BIT 7,(HL)              ;
  JR NZ,GENMOVES          ; Yes: just generate
  CALL PollKeyboard       ; Any key pressed? (prints *INTERRUPTED* if so)
  JR Z,GENMOVES           ; No: generate
  LD HL,$BD4C             ; Set the abort flag
  SET 7,(HL)              ;
  CALL SetPlayers         ; Update the display for the interrupt

; Generate pseudo-legal moves for the side in $BD2D bit 0
;
; Writes the move list for ply ($BCA9) starting at the address in the ply table
; ($BCA9+2*ply): a 4-byte header followed by one 4-byte entry per move (score
; $FF, from, to, flags) and an $FF terminator. Stores the end address in the
; next ply-table slot and returns the count in E.
;
; Generation order: castling (kingside, queenside), king steps, queen, rook
; ($BE10), rook ($BE18), bishop ($BE20), bishop ($BE28), knight ($BE30), knight
; ($BE38), then the 8 pawn slots ($BE40-$BE78) in order. A promoted piece in a
; pawn slot moves according to its type byte.
;
; Register usage: main set B = from-square, H = $BD (board page), L = target
; square, C = $88 off-board mask (overwritten by direction in the slide loop),
; DE = list write pointer. Alternate set: B = loop counter, C = side-to-move
; (bit 7: 1 = Black), DE = direction-table pointer, HL = pawn-record pointer.
; A' = $BC (list-full check in ADD_MOVE).
;
;   IX Parent move record (flags bit 7 = in check suppresses castling; bit 5 +
;      to-square drive en passant)
; O:E Move count (only correct for fewer than 127 moves; see docs)
; O:HL Address of header byte +3
GENMOVES:
  LD HL,$BCA9             ; HL = $BCA9 + 2 * ply: ply-table slot for this ply
  LD A,(HL)               ;
  ADD A,A                 ;
  ADD A,L                 ;
  LD L,A                  ;
  LD E,(HL)               ; DE = start of this ply's list (header address)
  INC L                   ;
  LD D,(HL)               ;
  INC L                   ; HL = next ply-table slot (will receive the end
                          ; address)
  PUSH DE                 ; Save the list start
  INC E                   ; DE = start + 4 (first move entry)
  INC E                   ;
  INC E                   ;
  INC DE                  ;
  PUSH HL                 ; Save the next ply-table slot address
  EX AF,AF'               ; A' = $BC: page at which the list is close to full
  LD A,$BC                ;
  EX AF,AF'               ;
  LD H,$BD                ; H = board page
  LD IY,$BE00             ; IY = White piece records
  LD A,($BD2D)            ; C' = $BD2D rotated right: bit 7 = side to move (1 =
  EXX                     ; Black)
  RRCA                    ;
  LD C,A                  ;
  EXX                     ;
  JR NC,GENMOVES_0        ; Black to move: IY = Black piece records
  LD IY,$BE80             ;
GENMOVES_0:
  LD B,(IY+$00)           ; B = king square
  BIT 4,(IY+$01)          ; King not yet moved: try castling
  CALL Z,GEN_CASTLE       ;
  LD C,$88                ; C = $88 off-board mask
  EXX                     ;
  LD DE,DiagonalOffsets   ; King steps: 8 directions from $7808 (diagonals,
  CALL GEN_STEPS          ; then orthogonals)
  LD A,(IY+$08)           ; Queen (IY+$08) present: slide in 8 directions
  OR A                    ;
  CALL P,GEN_QUEEN        ;
  LD A,(IY+$10)           ; Rook (IY+$10) present: slide in 4 directions
  OR A                    ;
  CALL P,GEN_ROOK         ;
  LD A,(IY+$18)           ; Rook (IY+$18) present
  OR A                    ;
  CALL P,GEN_ROOK         ;
  LD A,(IY+$20)           ; Bishop (IY+$20) present: slide in 4 diagonals
  OR A                    ;
  CALL P,GEN_BISHOP       ;
  LD A,(IY+$28)           ; Bishop (IY+$28) present
  OR A                    ;
  CALL P,GEN_BISHOP       ;
  LD A,(IY+$30)           ; Knight (IY+$30) present: 8 jumps from $7800
  LD C,$88                ; Restore C = $88 (the slide loops use C for the
  OR A                    ; direction)
  CALL P,GEN_KNIGHT       ;
  LD A,(IY+$38)           ; Knight (IY+$38) present
  OR A                    ;
  CALL P,GEN_KNIGHT       ;
  LD C,$11                ; C = pawn capture offset: +$11 (White, up-right)...
  EXX                     ;
  LD HL,$BE40             ; HL' = White pawn records ($BE40)
  BIT 7,C                 ; Black to move?
  JR Z,GENMOVES_1         ;
  LD L,$C0                ; HL' = Black pawn records ($BEC0)
  EXX                     ;
  LD C,$F1                ; ...or $F1 (Black, -15 = down-right)
  EXX                     ;
; Pawn-slot loop (alternate set).
GENMOVES_1:
  LD A,(HL)               ; Captured (square bit 7 set)?
  RLA                     ;
  JR C,GENMOVES_4         ; Yes: next slot
  INC L                   ; A = type byte
  LD A,(HL)               ;
  DEC L                   ;
  AND $0E                 ; Bits 1-3 non-zero: a promoted piece (Q 9, R 5, B
                          ; $83, N 3)
  LD A,(HL)               ; A = square
  EXX                     ;
  LD B,A                  ; B = from-square
  JR NZ,GEN_PROMOTED      ; Promoted piece: generate as that piece
  ADD A,C                 ; L = from + C (diagonal capture to the right; NOT
  LD L,A                  ; checked for off-board)
  XOR A                   ; Occupied?
  OR (HL)                 ;
  CALL NZ,ADD_CAPTURE     ; Yes: add a capture if it is an enemy piece
  DEC L                   ; L = from + C - 2 (diagonal capture to the left; not
  DEC L                   ; checked for off-board)
  XOR A                   ; Occupied?
  OR (HL)                 ;
  CALL NZ,ADD_CAPTURE     ; Yes: add a capture if it is an enemy piece
  INC L                   ; L = forward square
  XOR A                   ; Forward square occupied?
  OR (HL)                 ;
  JR NZ,GENMOVES_2        ; Yes: only en passant can follow
  CALL ADD_MOVE           ; Add the single push (flags 0); promotion is
                          ; detected later by make
  LD A,B                  ; From-square on the home rank (rank 2 White / rank 7
  ADD A,$20               ; Black)?
  BIT 6,A                 ;
  JR NZ,GENMOVES_2        ; No: try en passant
  LD A,C                  ; L = forward + C - 1 (two squares ahead); skip if
  DEC A                   ; past rank 8 (sign)
  ADD A,L                 ;
  JP M,GENMOVES_3         ;
  LD L,A                  ;
  XOR A                   ; Two squares ahead occupied?
  OR (HL)                 ;
  JR NZ,GENMOVES_3        ; Yes: next slot
  CALL ADD_MOVE           ; Add the double push (flags 0)
  DEC L                   ; Square left of the landing square holds an enemy
  OR (HL)                 ; pawn?
  CALL NZ,GEN_EPFLAG      ; Yes: flag the double push $20 (en passant possible)
  INC L                   ; Square right of the landing square
  INC L                   ;
  LD A,(HL)               ;
  OR A                    ;
  CALL NZ,GEN_EPFLAG      ; Enemy pawn there: flag $20
  JP GENMOVES_3           ; Next slot (no en passant from the home rank)
GENMOVES_2:
  BIT 5,(IX+$03)          ; Previous move a double push next to a pawn (flags
                          ; bit 5)?
  CALL NZ,GEN_EP          ; Yes: try the en passant capture
GENMOVES_3:
  EXX                     ;
; This entry point is used by the routine at GEN_PROMOTED_RET.
GENMOVES_4:
  LD A,$08                ; Next pawn slot (+8)
  ADD A,L                 ;
  LD L,A                  ;
  BIT 6,A                 ; Loop while L bit 6 is set ($40-$78 or $C0-$F8)
  JP NZ,GENMOVES_1        ;
; All pieces done: terminate the list and write its header.
  EXX                     ; Back to the main set
  LD A,$FF                ; Terminator: $FF at +0 of the entry after the last
  LD (DE),A               ; move
  POP HL                  ; HL = next ply-table slot
  LD (HL),E               ; Store the end address (= this terminator) there
  INC L                   ;
  LD (HL),D               ;
  POP HL                  ; HL = list start
  EX DE,HL                ; HL = end, DE = start
  OR A                    ; HL = end - start = 4 * (n + 1)
  SBC HL,DE               ;
  RR H                    ; L = (H bit 0, L) >> 2: this drops H bit 1, so it is
  RR L                    ; only right for n < 127
  RR L                    ;
  DEC L                   ; L = n (number of moves)
  EX DE,HL                ; E = n, HL = list start (header)
  LD (HL),A               ; Header +0 = $FF
  INC L                   ; Header +1 = n
  LD (HL),E               ;
  INC L                   ; Header +2 = 0
  LD (HL),$00             ;
  INC L                   ; Header +3 = parent flags AND $81 (bit 7 in check,
  LD A,(IX+$03)           ; bit 0 pawn to 6th/7th)
  AND $81                 ;
  LD (HL),A               ;
  RET                     ;
; A promoted piece in a pawn slot. The return address is set to
; GEN_PROMOTED_RET so that the piece routine returns into the pawn loop.
GEN_PROMOTED:
  PUSH BC                 ; Save B (from-square) and C (pawn capture offset)
  LD C,$88                ; C = $88 off-board mask (for knight steps)
  EXX                     ;
  INC L                   ; A = type byte
  LD A,(HL)               ;
  DEC L                   ;
  LD DE,GEN_PROMOTED_RET  ; Return to $79E0 when done
  PUSH DE                 ;
  OR A                    ; Bit 7 set: bishop
  JP M,GEN_BISHOP_X       ;
  RRA                     ; Bit 1 set: knight
  RRA                     ;
  JR C,GEN_KNIGHT_X       ;
  RRA                     ; Bit 2 set: rook
  JR C,GEN_ROOK_X         ;
  JR GEN_QUEEN_X          ; Otherwise: queen

; Return point after generating a promoted piece's moves
;
; Reached by RET from a piece routine (address pushed at $79CF). Restores B and
; C, then continues the pawn-slot loop at GENMOVES_4 in the alternate register
; set.
GEN_PROMOTED_RET:
  POP BC                  ; Restore B (from) and C (pawn capture offset)
  EXX                     ;
  JR GENMOVES_4           ; Continue the pawn-slot loop at $799C

; Generate an en passant capture
;
; Called for a pawn when the parent move's flags have bit 5 set. If that move
; was not itself a capture (bit 3 clear) and landed directly beside this pawn,
; adds the en passant capture to the square behind the enemy pawn, with flags
; $28.
;
; B From-square of the capturing pawn
; L Forward square of the capturing pawn
GEN_EP:
  BIT 3,(IX+$03)          ; Parent move was a capture ($28): not a double push
  RET NZ                  ;
  LD A,(IX+$02)           ; Enemy pawn landed on from + 1?
  INC A                   ;
  CP B                    ;
  JR Z,GEN_EP_0           ; Yes: capture towards forward - 1
  DEC A                   ; Enemy pawn landed on from - 1?
  DEC A                   ;
  CP B                    ;
  RET NZ                  ; No: return
  INC L                   ; Target = forward + 1
  INC L                   ;
GEN_EP_0:
  DEC L                   ; Target = forward - 1 (or +1 after the two INCs)
  LD A,$28                ; Flags $28: capture + en passant
  JP ADD_MOVE             ; Add the move

; Flag a double push next to an enemy pawn
;
; Called after a double push with A = piece code beside the landing square. If
; it is an enemy pawn (value 1, any advancement), sets the flags byte of the
; move just added to $20.
;
; A Piece code beside the landing square
; HL Address of that square
GEN_EPFLAG:
  EXX                     ; Same colour as the mover?
  XOR C                   ;
  EXX                     ;
  RET P                   ; Yes: nothing to do
  LD A,(HL)               ; A = piece code
  EXX                     ;
  LD B,L                  ; Save L'
  SUB $03                 ; L' = code - 3 = record offset + 1 (type byte); H' =
  LD L,A                  ; $BE
  LD A,(HL)               ; A = type byte
  LD L,B                  ; Restore L'
  EXX                     ;
  AND $0F                 ; Value 1 (pawn)?
  DEC A                   ;
  RET NZ                  ; No: return
  LD A,$20                ; Yes: flags of the last move entry = $20
  DEC DE                  ;
  LD (DE),A               ;
  INC DE                  ;
  RET                     ;

; Generate knight moves
;
; Used by the routine at GENMOVES.
;
; A From-square
GEN_KNIGHT:
  LD B,A                  ; B = from-square
  EXX                     ;
; This entry point is used by the routine at GENMOVES.
GEN_KNIGHT_X:
  LD DE,KnightOffsets     ; DE' = knight offsets at $7800

; Generate single-step moves in 8 directions (king, knight)
;
; For each of 8 offsets at DE': target = from + offset. Skips off-board squares
; (C = $88), adds a quiet move to an empty square, and adds a capture of an
; enemy piece.
;
; DE' Direction table
; B From-square
; C $88
GEN_STEPS:
  LD B,$08                ; 8 directions
GEN_STEPS_0:
  LD A,(DE)               ; A = offset
  INC E                   ;
  EXX                     ;
  ADD A,B                 ; L = from + offset
  LD L,A                  ;
  AND C                   ; Off the board?
  JR NZ,GEN_STEPS_1       ;
  OR (HL)                 ; Empty: add a quiet move (returns Z)
  CALL Z,ADD_MOVE         ;
  CALL NZ,ADD_CAPTURE     ; Occupied: add a capture if it is an enemy piece
GEN_STEPS_1:
  EXX                     ;
  DJNZ GEN_STEPS_0        ;
  EXX                     ;
  RET                     ;

; Generate rook moves
;
; Used by the routine at GENMOVES.
;
; A From-square
GEN_ROOK:
  LD B,A                  ; B = from-square
  EXX                     ;
; This entry point is used by the routine at GENMOVES.
GEN_ROOK_X:
  LD DE,OrthogonalOffsets ; DE' = orthogonal offsets at $780C (+1, -1, +16,
                          ; -16)
; This entry point is used by the routine at GEN_BISHOP.
GEN_SLIDE4:
  LD B,$04                ; 4 directions
; Slide loop: for each direction, step until off the board or blocked.
GEN_SLIDE:
  LD A,(DE)               ; A = direction
  INC E                   ;
  EXX                     ;
  LD C,A                  ; C = direction (overwrites the $88 mask)
  LD L,B                  ; L = from-square
GEN_ROOK_0:
  LD A,L                  ; L = L + direction
  ADD A,C                 ;
  LD L,A                  ;
  AND $88                 ; Off the board: next direction
  JR NZ,GEN_ROOK_1        ;
  OR (HL)                 ; Empty: add a quiet move and keep sliding
  CALL Z,ADD_MOVE         ;
  JR Z,GEN_ROOK_0         ;
  CALL ADD_CAPTURE        ; Occupied: add a capture if it is an enemy piece,
GEN_ROOK_1:
  EXX                     ; then stop
  DJNZ GEN_SLIDE          ;
  EXX                     ;
  RET                     ;

; Generate bishop moves
;
; Used by the routine at GENMOVES.
;
; A From-square
GEN_BISHOP:
  LD B,A                  ; B = from-square
  EXX                     ;
; This entry point is used by the routine at GENMOVES.
GEN_BISHOP_X:
  LD DE,DiagonalOffsets   ; DE' = diagonal offsets at $7808 (+15, +17, -17,
  JP GEN_SLIDE4           ; -15), 4 directions

; Generate queen moves
;
; Used by the routine at GENMOVES.
;
; A From-square
GEN_QUEEN:
  LD B,A                  ; B = from-square
  EXX                     ;
; This entry point is used by the routine at GENMOVES.
GEN_QUEEN_X:
  LD DE,DiagonalOffsets   ; DE' = $7808: 4 diagonals, then 4 orthogonals
  LD B,$08                ; 8 directions
  JP GEN_SLIDE            ;

; Generate castling moves
;
; Called only if the king's type byte has bit 4 (moved) clear. Kingside first:
; the rook in record +$18 must be present and unmoved, and the two squares to
; the king's right must be empty. Queenside: the rook in record +$10 must be
; present and unmoved, and the three squares to the king's left must be empty.
; No square is tested for attack here, and the rook's actual square is not
; checked. Castling moves get flags $10.
;
; B King square
; IX Parent move (flags bit 7 set = side to move is in check: no castling)
GEN_CASTLE:
  BIT 7,(IX+$03)          ; In check: no castling
  RET NZ                  ;
  BIT 4,(IY+$19)          ; Kingside rook moved?
  JR NZ,GEN_CASTLE_0      ;
  BIT 7,(IY+$18)          ; Kingside rook captured?
  JR NZ,GEN_CASTLE_0      ;
  XOR A                   ; King + 1 empty?
  LD L,B                  ;
  INC L                   ;
  OR (HL)                 ;
  JR NZ,GEN_CASTLE_0      ;
  INC L                   ; King + 2 empty: add O-O
  OR (HL)                 ;
  CALL Z,ADD_CASTLE       ;
GEN_CASTLE_0:
  BIT 4,(IY+$11)          ; Queenside rook moved?
  RET NZ                  ;
  BIT 7,(IY+$10)          ; Queenside rook captured?
  RET NZ                  ;
  LD L,B                  ; King - 1 empty?
  XOR A                   ;
  DEC L                   ;
  OR (HL)                 ;
  RET NZ                  ;
  DEC L                   ; King - 2 empty?
  OR (HL)                 ;
  RET NZ                  ;
  DEC L                   ; King - 3 empty?
  OR (HL)                 ;
  RET NZ                  ;
  INC L                   ; Target = king - 2: add O-O-O

; Add a castling move (flags $10)
;
; Used by the routine at GEN_CASTLE.
ADD_CASTLE:
  LD A,$10                ; A = $10 (castling) and add the move
  JR ADD_MOVE             ;

; Add a capture if the target holds an enemy piece
;
; Used by the routines at GENMOVES, GEN_STEPS and GEN_ROOK.
;
; A Piece code on the target square
ADD_CAPTURE:
  EXX                     ; Same colour as the side to move?
  XOR C                   ;
  EXX                     ;
  RET P                   ; Yes: no move
  LD A,$08                ; Flags $08: capture

; Append a move to the list
;
; Writes score $FF, from (B), to (L) and flags (A) at DE and advances DE by 4.
; When DE reaches $BC81 or beyond, the move is not written; instead the search
; abort flag ($BD4C bit 7) is set. The list area is therefore $B400-$BC83.
;
;   A Flags
;   B From-square
;   L To-square
;   DE List write pointer
; O:A Flags (Z set if the flags are 0)
ADD_MOVE:
  EX AF,AF'               ; A = $BC (from A'); A' = flags
  CP D                    ; Pointer in page $BC?
  JR Z,ADD_MOVE_FULL      ;
ADD_MOVE_WRITE:
  EX AF,AF'               ; A = flags
  EX DE,HL                ; HL = list pointer
  LD (HL),$FF             ; +0 score = $FF (not yet scored)
  INC L                   ; +1 from-square
  LD (HL),B               ;
  INC L                   ; +2 to-square
  LD (HL),E               ;
  INC L                   ; +3 flags
  LD (HL),A               ;
  INC HL                  ; Next entry (16-bit increment)
  EX DE,HL                ;
  OR A                    ; Z if the flags are 0
  RET                     ;
ADD_MOVE_FULL:
  LD A,$80                ; Still room while the low byte <= $80
  CP E                    ;
  LD A,$BC                ;
  JR NC,ADD_MOVE_WRITE    ;
  PUSH HL                 ; List full: set the abort flag $BD4C bit 7
  LD HL,$BD4C             ;
  SET 7,(HL)              ;
  POP HL                  ;
  EX AF,AF'               ; A = flags
  OR A                    ;
  RET                     ;
; Used by the book probe (BOOK_PROBE): mark the game as out of book.
BOOK_OFF:
  LD A,$FF                ; $BCDF = $FF: out of book
  LD ($BCDF),A            ;
  OR A                    ; Return NZ
  RET                     ;

; Opening book: probe for a book move
;
; Called from the search driver ($7C1E) after the root move list for the
; current position has been generated at $B404 (and scored by $7B96), unless
; the problem/next-best flag $BCDD is set. Walks the book tree ($9000, see
; BOOK_DATA) from the root along the moves of the game so far (indices in the
; game record at $C058), then picks one of the stored replies at random.
;
; The book is used only when $BCDF=0 (book not yet abandoned) and $C006=1 (the
; game started from the standard initial position; a set-up position stores its
; move number there). Book moves are taken straight from the pseudo-legal root
; list without any legality check (see docs/arch/25-book.md: the stored reply
; 6...Be7 after 1.e4 e5 2.Nf3 Nf6 3.Nxe5 d6 4.Nf3 Nxe4 5.d4 d5 6.Bb5+ is
; illegal and is played).
;
; O:F Z set: book move found; NZ: no book move
; O:($BD29) Address of the chosen move in the root list ($B404+4*index), when Z
BOOK_PROBE:
  LD A,($BCDF)            ; Book already abandoned in this game (BCDF
                          ; non-zero)?
  OR A
  RET NZ                  ; Return NZ if so
  LD A,($C006)            ; Did the game start from the standard initial
                          ; position ($C006=1)?
  DEC A
  RET NZ                  ; Return NZ if not
  CALL BOOK_RANDOM        ; B=random byte (also updates $BCCE); B is not used
                          ; before the next call
  LD HL,$FFFF             ; HL=-1: entry number, pre-incremented below
; Follow one game move down the tree. HL points (after the increment) at the
; first entry of the sibling list for the position reached so far; on entry to
; the loop, $BCDF counts the plies already matched.
BOOKP_PLY:
  INC HL                  ; Next entry (first child of the matched move; the
                          ; root list on the first pass)
  LD A,($C001)            ; C=number of plies played in the game (low byte of
                          ; $C001 only)
  LD C,A
  LD A,($BCDF)            ; Increment the ply counter $BCDF...
  INC A
  LD ($BCDF),A
  DEC A                   ; ...and get its old value i
  CP C                    ; Have all i game plies been matched?
  JR Z,BOOKP_CHOOSE       ; If so, choose a reply from this sibling list
  LD BC,$C058             ; BC=$C058+i: game record byte for ply i
  ADD A,C
  LD C,A
  JR NC,BOOK_PROBE_0
  INC B
BOOK_PROBE_0:
  LD A,(BC)               ; A=record byte (list index; bit 7 = move gave check)
  AND $7F                 ; Discard the check bit
  LD C,A                  ; C=index of the game move played at ply i
  CALL BOOK_READ          ; A=book entry HL (bit 7=leaf, bit 6=more siblings,
                          ; bits 0-5=list index)
BOOKP_CMP:
  LD B,A                  ; B=entry
  RES 6,A                 ; Clear the 'more siblings' bit; the leaf bit stays,
                          ; so a leaf entry never matches
  CP C                    ; Does the entry name the game move (and have a
                          ; continuation)?
  JR Z,BOOKP_PLY          ; If so, descend to its children and follow the next
                          ; ply
  BIT 6,B                 ; Any more siblings to try?
  JR Z,BOOK_OFF           ; If not, the game has left the book: set $BCDF=$FF
                          ; and return NZ (BOOK_OFF)
  CALL BOOK_SKIP          ; Skip this entry's subtree; HL=next sibling, A=its
                          ; entry
  JR BOOKP_CMP            ; Compare again
; All game plies matched: choose one of the moves in the sibling list at HL.
BOOKP_CHOOSE:
  CALL BOOK_RANDOM        ; B=fresh random byte (bit 7 always 0)
  CALL BOOK_READ          ; A=first entry of the list, CF=its leading (9th) bit
                          ; 'M'
  LD C,A                  ; C=entry (candidate move)
  BIT 6,A                 ; Is it the only move in the list?
  JR Z,BOOKP_TAKE         ; If so, take it
  LD A,$01                ; A=2 (or 3 if M is set)
  RLA
  AND B                   ; Take the first move if random bit 1 is set, or
                          ; (when M is set) bit 0: probability 1/2, or 3/4 when
                          ; M is set
  JR NZ,BOOKP_TAKE
BOOKP_SIB:
  PUSH HL                 ; Save the address of the current candidate
  CALL BOOK_RANDOM        ; B=fresh random byte
  CALL BOOK_SKIP          ; Skip the candidate's subtree: HL=next sibling,
                          ; A=its entry, CF=its M bit
  JR C,BOOKP_PREV         ; If the next sibling has M set, stop here and take
                          ; the previous candidate
  POP DE                  ; Discard the saved address
  LD C,A                  ; C=entry of the new candidate
  BIT 6,A                 ; Is it the last sibling?
  JR Z,BOOKP_TAKE         ; If so, take it
  RR B                    ; Random bit 0 into the carry flag
  JR C,BOOKP_SIB          ; If set, move on to the next sibling
  JR BOOKP_TAKE           ; Otherwise take this one
BOOKP_PREV:
  POP HL                  ; Restore the previous candidate's address
  CALL BOOK_READ          ; Re-read its entry
  LD C,A                  ; C=entry
BOOKP_TAKE:
  LD A,C                  ; A=list index of the chosen move (bits 0-5)
  AND $3F
  RLA                     ; x4 (carry is clear after AND)
  RLA
  LD E,A                  ; DE=4*index
  LD D,$00
  LD IX,$B404             ; IX=$B404+4*index: the chosen entry in the root move
                          ; list
  ADD IX,DE
  LD ($BD29),IX           ; Store it for the caller
  XOR A                   ; A=0
  BIT 7,C                 ; Is the chosen move a leaf (no stored continuation)?
  JR NZ,BOOKP_DONE        ; If so, leave $BCDF non-zero (= plies matched + 1):
                          ; the book is not consulted again this game
  LD ($BCDF),A            ; Otherwise reset $BCDF to 0 so the book is probed
                          ; again next move
BOOKP_DONE:
  XOR A                   ; Return Z: book move found
  RET

; Opening book: skip a subtree
;
; Skips book entry HL and all its descendants, returning the entry of its next
; sibling. Only called for an entry whose 'more siblings' bit (6) is set. Uses
; DE as a signed counter: DE=-1, then for each entry read in pre-order DE is
; decremented if bit 7 (leaf) is set and incremented if bit 6 (more siblings)
; is set; the walk stops after the first entry that leaves DE negative.
;
; I:HL Entry number of the subtree root
; O:HL Entry number of the next sibling
; O:A That sibling's entry (from BOOK_READ); CF=its leading bit M; Z if it has
;     no further siblings
BOOK_SKIP:
  LD DE,$FFFF             ; DE=-1
BOOKS_LOOP:
  CALL BOOK_READ          ; Read entry HL and adjust DE
  INC HL                  ; Next entry
  BIT 7,D                 ; Continue while DE is not negative
  JR Z,BOOKS_LOOP

; Opening book: read an entry and update the subtree counter
;
; Reads book entry HL via BOOK_BITS and adjusts the subtree counter DE used by
; BOOK_SKIP.
;
; I:HL Entry number
; I:DE Subtree counter
; O:A Entry bits 0-7: bit 7=leaf (no children), bit 6=more siblings follow,
;     bits 0-5=index in the generated move list
; O:F CF=entry bit 8 (the leading bit, 'M'); Z if bit 6 is clear
; O:DE DE-1 if bit 7 is set, then DE+1 if bit 6 is set
;
; Falls through into BOOK_READ to read the sibling's entry.
BOOK_READ:
  CALL BOOK_BITS          ; A=entry bits 0-7, CF=bit 8
  BIT 7,A                 ; Leaf?
  JR Z,BOOK_READ_0
  DEC DE                  ; If so, DE=DE-1
BOOK_READ_0:
  BIT 6,A                 ; More siblings?
  RET Z                   ; Return Z if not
  INC DE                  ; If so, DE=DE+1
  RET                     ; Return NZ (carry unchanged)

; Opening book: fetch the 9-bit entry HL
;
; The book at $9000 is a bit stream of 9-bit entries, most significant bit
; first: entry n occupies stream bits 9n to 9n+8, which start at bit (n AND 7)
; of byte n+INT(n/8). The routine reads the two bytes from that address into A
; and C and shifts the pair left (n AND 7)+1 times, so that A holds entry bits
; 0-7 and the carry flag holds bit 8.
;
; I:HL Entry number n
; O:A Entry bits 0-7
; O:F CF=entry bit 8
BOOK_BITS:
  PUSH BC                 ; Preserve BC and HL
  PUSH HL
  LD A,L                  ; BC=n/8 (shift HL right three times)
  SRL H
  RRA
  SRL H
  RRA
  SRL H
  RRA
  LD B,H
  LD C,A
  POP HL                  ; Restore HL=n (and keep it on the stack)
  PUSH HL
  LD A,$07                ; A=n AND 7 (clears the carry flag)
  AND L
  ADD HL,BC               ; HL=n+n/8 (=byte offset of the entry)
  LD BC,BOOK_DATA         ; HL=$9000+n+n/8
  ADD HL,BC
  LD B,A                  ; B=(n AND 7)+1: number of shifts
  INC B
  LD A,(HL)               ; A=first byte
  INC HL                  ; C=second byte
  LD C,(HL)
BOOKB_SHIFT:
  RL C                    ; Shift C into A, one bit at a time; the last bit
                          ; shifted out of A (entry bit 8) is left in the carry
                          ; flag
  RLA
  DJNZ BOOKB_SHIFT
  POP HL                  ; Restore HL and BC
  POP BC
  RET

; Opening book: generate a random byte
;
; Mixes the Z80 refresh register R into the random accumulator at $BCCE and
; halves it: $BCCE = (R XOR $BCCE) >> 1. The result (0-127; bit 7 is always 0)
; is returned in B. $BCCE is also incremented while the program waits for a key
; (WaitKey), mixed with R in the main loop ($60EB) and incremented by every
; evaluation ($8807).
;
; O:B Random byte (0-127)
; O:A Same as B
BOOK_RANDOM:
  LD A,R                  ; B=R
  LD B,A
  LD A,($BCCE)            ; A=($BCCE) XOR R (clears the carry flag)
  XOR B
  RRA                     ; Shift right; bit 7 becomes 0
  LD ($BCCE),A            ; Store the new value of the accumulator
  LD B,A                  ; B=random byte
  RET

; Score every unscored move in a list by make/evaluate/unmake
;
; Each entry whose score byte is $FF is made, evaluated with Evaluate and
; unmade; the evaluation (0 = illegal) becomes its score. The best score is
; kept in $BD19 and its entry in $BD1A; ties go to the later entry (>=
; comparison).
;
;   HL List header+3
;   E Number of moves in the list
; O:$BD19 Best score (0 if no legal move)
; O:$BD1A Address of the best entry
S_SCOREMOVES:
  INC HL                  ; Point HL at the first move entry
  PUSH HL                 ; IX=first move entry
  POP IX                  ;
  XOR A                   ; Best score so far = 0
  LD ($BD19),A            ;
  INC E                   ; Loop counter = count+1 (pre-decremented below)
  LD A,E                  ;
  LD ($BD0E),A            ;
S_SCORE_LOOP:
  LD HL,$BD0E             ; Count down the moves
  DEC (HL)                ;
  RET Z                   ; Return when all moves have been visited
  LD B,(IX+$00)           ; Score byte of this move
  INC B                   ; Is it $FF (unscored)?
  JR NZ,S_SCORE_NEXT      ; Skip moves already scored, searched or pruned
  CALL MAKEMOVE           ; Make the move
  CALL Evaluate           ; Evaluate the resulting position (0 = illegal)
  LD (IX+$00),A           ; Store the evaluation as the move's score
  LD HL,$BD19             ; Compare with the best score so far
  CP (HL)                 ;
  JR C,S_SCORE_UNMAKE     ; Lower: keep the old best
  LD (HL),A               ; New best (or equal): record score
  LD ($BD1A),IX           ; ...and the entry address
S_SCORE_UNMAKE:
  CALL UNMAKE             ; Unmake the move
S_SCORE_NEXT:
  LD BC,$0004             ; Advance IX to the next entry
  ADD IX,BC               ;
  JP S_SCORE_LOOP         ; Loop

; Find a move in a list by its squares
;
; Scans B entries starting with the entry after the one HL points into. A is
; compared with the to-square (+2) and A' with the from-square (+1).
;
;   HL Address of byte +2 of the entry before the first to test
;   B Number of entries to test
;   A To-square
;   A' From-square
; O:F Carry clear and Z set if found; carry set if not found
; O:HL Found: byte +1 of the matching entry. Not found: byte +2 of the last
;      entry tested
S_FINDMOVE:
  LD DE,$0004             ; Entry stride
S_FIND_LOOP:
  ADD HL,DE               ; Next entry's to-square
  CP (HL)                 ; Does the to-square match?
  JR Z,S_FIND_CHKFROM     ; Yes: check the from-square
S_FIND_NEXT:
  DJNZ S_FIND_LOOP        ; Loop over B entries
  SCF                     ; Not found
  RET                     ; Return with carry set
S_FIND_CHKFROM:
  EX AF,AF'               ; A=from-square
  DEC L                   ; Point at byte +1
  CP (HL)                 ; Does the from-square match?
  RET Z                   ; Yes: return with HL at byte +1
  INC L                   ; Restore HL to byte +2
  EX AF,AF'               ; A=to-square again
  JP S_FIND_NEXT          ; Continue the scan

; Think: compute the computer's move
;
; Calls the pre-search set-up PRESEARCH, then one search pass (S_PASS). Levels
; whose search parameter $BCBD is 5-7 set $BD6E during the first pass, which
; makes a second pass run here.
;
; O:$BD29 Address of the chosen root move entry
; O:F Carry set if there is no legal move (via S_THINK_NOMOVE)
S_THINK:
  CALL PRESEARCH          ; Pre-search set-up (phase flags, material balance,
                          ; etc.)
S_THINK_PASS:
  CALL S_PASS             ; Run one search pass
  LD A,($BD6E)            ; Is a second pass pending?
  OR A                    ;
  JR NZ,S_THINK_PASS      ; Yes: run it
  RET                     ; Done
; This entry point is used by the routine at S_PASS.
S_THINK_NOMOVE:
  POP HL                  ; No legal move: discard the return address into
                          ; S_THINK...
  SCF                     ; ...and return to its caller with carry set
  RET                     ; Return

; One search pass from the root
;
; Initialises the per-search tables, generates and statically scores the root
; moves, probes the opening book, sets the depth and pruning parameters from
; the level, applies next-best exclusions and the repetition rule, then enters
; the search loop at the best statically-scored root move. The search loop
; exits by returning to S_THINK_PASS.
;
; O:$BD29 Address of the chosen root move entry
S_PASS:
  LD IX,$BD58             ; IX=root "move" record (last game move)
  LD HL,$BC91             ; Killer table $BC91-$BC9D
  LD A,$FF                ; Fill with $FF (no killer)
  LD ($BD0C),A            ; Shortest mate ply found so far = $FF
  LD B,$0D                ; 13 bytes
S_PASS_FILLFF:
  LD (HL),A               ; Fill the killer table
  INC L                   ; Next byte
  DJNZ S_PASS_FILLFF      ; Loop
  INC A                   ; A=0
  LD ($BD0D),A            ; Incremental material balance = 0
  LD HL,$BC9F             ; Value table V(0)..V(8) at $BC9F-$BCA7
  LD B,$09                ; 9 bytes
S_PASS_FILL0:
  LD (HL),A               ; Zero the value table (V(1)=0 is -infinity)
  INC L                   ; Next byte
  DJNZ S_PASS_FILL0       ; Loop
  CALL GENMOVES           ; Generate the root moves (ply 1, list at $B400)
  SET 5,(HL)              ; Mark the root list as scored
  CALL S_SCOREMOVES       ; Score every root move statically
  LD A,($BCDD)            ; Next-best mode?
  OR A                    ; Yes: skip the opening book
  JR NZ,S_PASS_SEARCH     ;
  CALL BOOK_PROBE         ; Probe the opening book
  JR NZ,S_PASS_SEARCH     ; NZ: no book move, so search
  CALL PollKeyboard       ; Book move found: check the keyboard
  RET Z                   ; No key: return with the book move in $BD29
  JP SetPlayers           ; Key pressed: leave demo mode (SetPlayers) and
                          ; return with the book move
S_PASS_SEARCH:
  LD A,($BD19)            ; Best static root score
  OR A                    ; Zero means no legal move
  JP Z,S_THINK_NOMOVE     ; No legal root move: return carry set
  LD D,A                  ; D=best static root score
  LD A,($BD6E)            ; Second pass of a two-pass level?
  OR A                    ; No: first pass
  JR Z,S_PASS_FIRST       ;
  LD HL,($BD29)           ; Second pass: HL=first pass's chosen move
  LD (HL),$FD             ; Give it score $FD so it is searched first
  LD ($BD1A),HL           ; It is also the static best
  XOR A                   ; Clear the second-pass flag
  LD ($BD6E),A            ;
  LD A,($BCBD)            ; A=search parameter of the level
  JR S_PASS_PARAMS        ; Set the parameters
S_PASS_FIRST:
  LD HL,($BD1A)           ; First pass: the static best move...
  LD ($BD29),HL           ; ...is the move to play until the search finds
                          ; better
  LD A,($BCBD)            ; A=search parameter of the level (0-7)
  CP $05                  ; Parameters 5-7 (Levels 6-8, P3)?
  JR C,S_PASS_PARAMS      ; No: one pass with this parameter
  LD A,$01                ; Yes: first pass uses parameter 1 (as Level 2)...
  LD ($BD6E),A            ; ...and flag that a second pass will follow
S_PASS_PARAMS:
  LD HL,$BDF6             ; Threat-extension switch $BDF6...
  LD (HL),$00             ; ...defaults to 0 (off)
  LD ($BD09),A            ; Pruning margin byte = parameter for now
  BIT 1,A                 ; Parameter bit 1 set (2, 3, 6, 7)?
  JR Z,S_PASS_DEPTH       ; No: extensions stay off
  LD (HL),A               ; Yes: enable threat extensions ($BDF6=parameter)
  BIT 0,A                 ; Parameter bit 0 set too (3, 7)?
  JR Z,S_PASS_DEPTH       ; No: keep forward pruning
  LD HL,$BD09             ; Yes: set bit 7 of $BD09...
  SET 7,(HL)              ; ...which disables all forward pruning
S_PASS_DEPTH:
  LD HL,$BCAA             ; Full-width depth D...
  LD (HL),$01             ; ...is 1 for parameter 0
  OR A                    ; Parameter 0?
  JR Z,S_PASS_MARGIN      ; Yes: D=1
  INC (HL)                ; D=2
  CP $04                  ; Parameters 1-3?
  JR C,S_PASS_MARGIN      ; Yes: D=2
  LD (HL),$03             ; D=3...
  JR Z,S_PASS_MARGIN      ; ...for parameter 4
  INC (HL)                ; D=4 for parameters 5-7
S_PASS_MARGIN:
  LD B,$07                ; Default margin base 7 (used when in check)
  LD A,($BD09)            ; Forward pruning disabled?
  RLA                     ; Bit 7 into carry
  JR C,S_PASS_EXCLUDE     ; Yes: leave $BD09 as is
  LD A,D                  ; A=best static root score
  LD HL,$B403             ; Root list header flags
  BIT 7,(HL)              ; Side to move in check?
  JR NZ,S_MARGIN_SET      ; Yes: margin = 7+2
  CALL S_PRUNE            ; Prune weak root moves; D=2*count minus moves below
                          ; best-9
  SRL D                   ; D=D/4...
  SRL D                   ; ...
  DEC D                   ; ...-1...
  SRL D                   ; .../2 (all unsigned)
  LD B,$0B                ; Base 11...
  LD A,($BD2D)            ; ...for deep endgame ($BD2D bit 4)
  BIT 4,A                 ; Bit 4 set?
  JR NZ,S_MARGIN_LOOP     ; Yes: base 11
  DEC B                   ; Base 10
  SRA A                   ; Phase bits >> 1
  DEC A                   ; Exactly bit 1 (past move 8, no endgame bit)?
  JR NZ,S_MARGIN_LOOP     ; No: base 10
  DEC B                   ; Middlegame: base 8
  DEC B                   ; ...
S_MARGIN_LOOP:
  DEC D                   ; Count D down...
  JP M,S_MARGIN_SET       ; ...until it goes negative...
  DJNZ S_MARGIN_LOOP      ; ...decrementing the base each time (stops at 0)
S_MARGIN_SET:
  LD A,$02                ; Margin = base + 2
  ADD A,B                 ; ...
  LD ($BD09),A            ; Store the pruning margin
S_PASS_EXCLUDE:
  LD HL,$BF00             ; Next-best exclusion list (from,to pairs,
                          ; $FF-terminated)
S_EXCL_LOOP:
  LD A,(HL)               ; From-square of the next pair
  CP $FF                  ; End of list?
  JR Z,S_PASS_FIRSTMOVE   ; Yes: done
  INC HL                  ; Point at the to-square
  EX AF,AF'               ; A'=from-square
  LD A,(HL)               ; A=to-square
  INC HL                  ; Next pair
  PUSH HL                 ; Save the list pointer
  LD HL,$B401             ; Root list header+1
  LD B,(HL)               ; B=number of root moves
  INC L                   ; HL=header+2
  CALL S_FINDMOVE         ; Find the move (assumed present: see 30-search.md)
  DEC L                   ; Point at its score byte
  LD (HL),$00             ; Exclude it (score 0)
  POP HL                  ; Restore the list pointer
  JR S_EXCL_LOOP          ; Next pair
S_PASS_FIRSTMOVE:
  LD HL,$B403             ; Root list header+3
  CALL S_PICKBEST         ; Pick the best-scored remaining root move
  BIT 0,E                 ; Odd E: none left (every move excluded)
  JR Z,S_PASS_REPCHK      ; Found one: continue
  CALL PrintLine10        ; Print the message
  DEFM "*NO MORE MOVES"   ; "*NO MORE MOVES"
  DEFB $AA                ; Last character (bit 7 set)
  CALL Beep               ; Beep
  DEFB $FF,$40            ; Inline arguments: duration, pitch
  CALL ClearExclusionList ; Clear the exclusion list
  CALL ClearLine10        ; Clear the message line
  POP HL                  ; Discard the return address into S_THINK
  JP S_THINK              ; Think again from scratch without exclusions
S_PASS_REPCHK:
  LD ($BD1A),DE           ; $BD1A=first root move to search
  LD A,($BD5E)            ; Consecutive reversing-move counter
  LD C,A                  ; C=counter
  CP $02                  ; Fewer than 2?
  JP C,S_PLAYBEST         ; Yes: start searching the first root move
  LD HL,($BD5C)           ; L=to, H=from of the move that undoes our last move
  LD A,H                  ; A'=from-square
  EX AF,AF'               ; ...
  LD A,L                  ; A=to-square
  LD HL,$B401             ; Root list header+1
  LD B,(HL)               ; B=number of root moves
  INC L                   ; HL=header+2
  CALL S_FINDMOVE         ; Find the repeating move
  DEC L                   ; Point at its score byte
  LD A,(HL)               ; Already excluded?
  OR A                    ; ...
  JP Z,S_PLAYBEST         ; Yes: search normally
  LD (HL),$00             ; Take it out of the move ordering
  LD A,($BD2D)            ; Draw value: material term $BD2E, sign by side to
                          ; move
  RRA                     ; Bit 0 into carry
  LD A,($BD2E)            ; A=$BD2E
  JR NC,S_REP_DRAWVAL     ; Side bit clear: keep the sign
  NEG                     ; Negate
S_REP_DRAWVAL:
  ADD A,$7E               ; Draw value = +-$BD2E + $7E
  BIT 2,C                 ; Counter is 4 or 5?
  JR Z,S_REP_SET          ; No
  SUB $08                 ; Yes: draw is 8 points less attractive
S_REP_SET:
  LD ($BCA0),A            ; Root alpha V(1)=draw value
  LD ($BD2B),HL           ; The repeating move is the current best root move
  JP S_ROOTBEST_SET       ; Record it in $BD29 and start the search loop

; Unused
;
; Not referenced from anywhere.
S_UNUSED_7D3F:
  LD ($BCA0),A            ; Store A in V(1)
  RET                     ; Return

; Enter a new node: generate its moves and try the killer move
;
; Reached by jumping from S_DESCEND_PLY after a move has been made and the ply
; incremented. POLLGEN polls the keyboard (unless the abort flag is already
; set) and falls into the move generator GENMOVES. If the move leading here has
; flag bit 2 set, the recapture on its to-square is tried first (S_RECAPTURE);
; otherwise, unless the side to move is in check, the killer move for this ply
; is tried first.
;
; IX Entry of the move that led to this node
S_NODE:
  CALL POLLGEN            ; Poll keyboard; generate the moves for ply p
  LD A,E                  ; E=number of moves
  OR A                    ; Any?
  JR Z,S_NEXTMOVE         ; No: go straight to the move loop
  LD A,($BCA9)            ; A=p
  LD B,E                  ; B=number of moves
  BIT 2,(IX+$03)          ; Did the last move threaten a recapture (flag bit
                          ; 2)?
  JP NZ,S_RECAPTURE       ; Yes: try the recapture first
  BIT 7,(HL)              ; Side to move in check?
  JR NZ,S_NEXTMOVE        ; Yes: no killer
  DEC A                   ; A=p-1
  LD DE,$BC91             ; Killer table
  ADD A,A                 ; A=2(p-1)
  ADD A,E                 ; ...
  LD E,A                  ; DE=killer(p)
  LD A,(DE)               ; From-square of the killer
  OR A                    ; Bit 7 set means no killer
  JP M,S_NEXTMOVE         ; No killer: go to the move loop
  INC E                   ; Point at its to-square
  EX AF,AF'               ; A'=from-square
  LD A,(DE)               ; A=to-square
  DEC L                   ; HL=header+2
  CALL S_FINDMOVE         ; Is the killer in this list?
  JR C,S_NEXTMOVE         ; No: go to the move loop
  DEC L                   ; Point at its score byte
  LD (HL),$00             ; Mark it searched
  PUSH HL                 ; IX=killer entry
  POP IX                  ; ...
  CALL MAKEMOVE           ; Make the killer move
; This entry point is used by the routine at S_RECAPTURE.
S_NODE_EVAL:
  CALL Evaluate           ; Evaluate the position after the move
  OR A                    ; Illegal?
  JR Z,S_NODE_UNDO        ; Yes: unmake and go to the move loop
  LD C,A                  ; C=evaluation
  EX AF,AF'               ; A'=evaluation
  LD HL,$BCAA             ; A=D
  LD A,(HL)               ; ...
  DEC L                   ; ...
  LD B,(HL)               ; B=p
  CP B                    ; Beyond the full-width depth?
  JP C,S_QEVAL            ; Yes: treat as a selective node
  CALL Z,HORIZON_CUT      ; At the depth (D=p): futility test, may fail high
  CALL S_PLYINFO          ; HL=header+3 of this ply's list
  SET 6,(HL)              ; Mark the killer as searched
  EX AF,AF'               ; A=evaluation
  DEC L                   ; HL=header+2
  LD (HL),A               ; Record the killer's evaluation in the header
  BIT 1,(IX+$03)          ; Move flag bit 1 (threat)?
  JP Z,S_DESCEND_MADE     ; No: search the killer now
  BIT 3,(IX+$03)          ; Capture?
  JP NZ,S_DESCEND_MADE    ; Yes: search the killer now
  LD (IX+$00),A           ; Quiet threat: give it its evaluation as score; it
                          ; is ordered later
S_NODE_UNDO:
  CALL UNMAKE             ; Unmake it

; Choose the next move at the current node
;
; At plies up to the full-width depth: the first visit scores every move
; statically (S_SCOREMOVES), detects mate/stalemate, applies forward pruning
; (S_PRUNE) and searches the static best; later visits take the highest-scored
; remaining move (S_PICKBEST). Beyond the depth, control passes to the
; selective move loop at S_QNEXT_HL.
S_NEXTMOVE:
  LD HL,$BCAA             ; A=D
  LD A,(HL)               ; ...
  DEC L                   ; HL=$BCA9
  CP (HL)                 ; Compare D with p
  JP C,S_QNEXT_HL         ; p>D: selective node
  CALL S_PLYINFO_HL       ; B=p, HL=header+3, E=count, C=header+2
  BIT 5,(HL)              ; Moves already scored?
  JP NZ,S_NEXT_SCORED     ; Yes: take the next best
  SET 5,(HL)              ; Mark the list scored
  PUSH HL                 ; Save HL
  CALL S_SCOREMOVES       ; Score every unscored move
  POP HL                  ; Restore HL
  LD A,($BD19)            ; Best static score
  OR A                    ; Zero: no legal move (except perhaps the killer)
  JP Z,S_NOMOVES          ; Handle mate/stalemate
  BIT 7,(HL)              ; In check?
  JP NZ,SRCH_MAKE_BEST    ; Yes: no pruning, search the static best
  CALL S_PRUNE            ; Forward-prune weak moves (A=best static score)
; This entry point is used by the routine at S_PASS.
S_PLAYBEST:
  LD IX,($BD1A)           ; IX=static best entry
  LD (IX+$00),$00         ; Mark it searched
  JP S_DESCEND            ; Make it and descend
S_NEXT_SCORED:
  BIT 7,(HL)              ; In check?
  JP NZ,SRCH_NEXT_MOVE    ; Yes: next move without recording it
  CALL S_PICKBEST         ; Pick the highest-scored remaining move
  BIT 0,E                 ; Odd E: none left
  JR NZ,S_RETURN          ; Return to the parent
  PUSH DE                 ; IX=chosen entry
  POP IX                  ; ...
  XOR A                   ; Mark it searched
  LD (DE),A               ; ...
S_DESCEND:
  CALL MAKEMOVE           ; Make the move
; This entry point is used by the routines at S_NODE, S_QUNDO and S_QLEAF.
S_DESCEND_MADE:
  LD A,($BCA9)            ; A=p
  DEC A                   ; p-1
  JR Z,S_DESCEND_ROOT     ; Root: record the root move instead
  ADD A,A                 ; 2(p-1)
  LD HL,$BC83             ; Current-move table
  ADD A,L                 ; ...
  LD L,A                  ; HL=curmove(p)
  LD A,(IX+$01)           ; Record the from-square...
  LD (HL),A               ; ...
  INC L                   ; ...
  LD A,(IX+$02)           ; ...and the to-square
  LD (HL),A               ; ...
  JP S_DESCEND_PLY        ; Descend
; This entry point is used by the routine at HORIZON_CUT.
S_DESCEND_ROOT:
  LD ($BD2B),IX           ; $BD2B=root move being searched
; This entry point is used by the routine at HORIZON_CUT.
S_DESCEND_PLY:
  LD A,($BD2D)            ; Flip the side to move
  XOR $01                 ; ...
  LD ($BD2D),A            ; ...
  LD HL,$BCA9             ; Ply counter
  LD A,(HL)               ; A=p
  INC (HL)                ; p=p+1
  DEC A                   ; A=p-2
  DEC A                   ; ...
  LD HL,$BCA0             ; Value table
  ADD A,L                 ; ...
  LD L,A                  ; HL=$BCA0+p-2 = V(p-1)
  LD A,(HL)               ; A=V(p-1)
  INC L                   ; ...
  INC L                   ; HL=$BCA0+p = V(p+1)
  LD (HL),A               ; The child starts with V(p+1)=V(p-1) (its alpha)
  JP S_NODE               ; Enter the new node

; Return from a node to its parent and back up the value
;
; Decrements the ply and unmakes the move that led to the finished node. If the
; abort flag ($BD4C bit 7) is set, keeps unwinding to the root without
; comparing values. Leaving ply 1 exits the search pass (RET to S_THINK_PASS).
; Otherwise the child's value is negated and compared: if it reaches the
; parent's beta it is a fail-high (S_FAILHIGH); if it improves alpha, alpha is
; updated and the move becomes the killer for its ply (or the best root move at
; ply 1).
S_RETURN:
  LD A,($BCA9)            ; A=p-1
  DEC A                   ; ...
  RET Z                   ; Leaving the root: the search pass is over
  LD ($BCA9),A            ; Ply p-1
  CALL UNMAKE             ; Unmake the move that led to the finished node
  LD A,($BD2D)            ; Flip the side to move
  XOR $01                 ; ...
  LD ($BD2D),A            ; ...
  LD A,($BD4C)            ; Abort flag (key pressed or move list full)?
  RLA                     ; Bit 7 into carry
  JR C,S_RETURN           ; Set: keep unwinding
  LD A,($BCA9)            ; A=p (the parent)
  LD HL,$BCA0             ; Value table
  ADD A,L                 ; ...
  LD L,A                  ; HL=$BCA0+p = V(p+1), the child's value
  LD A,(HL)               ; A=V(p+1)
  NEG                     ; Negate: value for the side to move at p
; This entry point is used by the routine at S_STALEMATE.
S_BACKUP:
  DEC L                   ; HL=V(p-1) (minus beta of ply p)
  DEC L                   ; ...
  CPL                     ; ~A = value-1 in the parent's sign
  CP (HL)                 ; value >= beta?
  JR C,S_FAILHIGH         ; Yes: fail high at ply p
  CPL                     ; A=value again
  INC L                   ; HL=V(p), alpha
  CP (HL)                 ; Compare with alpha
  JP C,S_NEXTMOVE         ; Lower: no improvement
  JP Z,S_NEXTMOVE         ; Equal: no improvement
  LD (HL),A               ; New alpha
  LD A,($BCA9)            ; A=p-1
  DEC A                   ; ...
  JR Z,S_ROOTBEST         ; Root: new best root move
S_KILLER:
  ADD A,A                 ; A=2(p-1)
  LD B,A                  ; B=2(p-1)
  LD HL,$BC91             ; Killer table
  ADD A,L                 ; ...
  LD L,A                  ; HL=killer(p)
  LD DE,$BC83             ; Current-move table
  LD A,B                  ; ...
  ADD A,E                 ; ...
  LD E,A                  ; DE=curmove(p)
  LD A,(DE)               ; From-square
  OR A                    ; Bit 7 set (not recorded, e.g. in-check node)?
  JP M,S_NEXTMOVE         ; Yes: no killer update
  LD (HL),A               ; Killer from-square
  INC E                   ; ...
  INC L                   ; ...
  LD A,(DE)               ; Killer to-square
  LD (HL),A               ; ...
  JP S_NEXTMOVE           ; Continue with the next move at this ply
; This entry point is used by the routine at HORIZON_CUT.
S_FAILHIGH:
  CALL UNMAKE             ; Fail high: unmake the move that led to this node
  LD HL,$BCA9             ; ...
  DEC (HL)                ; Back to the parent's ply
  LD A,($BD2D)            ; Flip the side to move
  XOR $01                 ; ...
  LD ($BD2D),A            ; ...
  LD A,(HL)               ; A=new ply
  JP S_KILLER             ; The refutation becomes the killer of the node that
                          ; failed high

; Record the best root move
;
; Copies the root move being searched ($BD2B) to $BD29, the move to play. Also
; used as an exit: reached by JR from S_ROOTMATE when a mate in one is found,
; its RET ends the search pass.
S_SETBEST:
  LD IX,($BD2B)           ; IX=root move being searched
  LD ($BD29),IX           ; It becomes the move to play
  RET                     ; Return
; This entry point is used by the routine at S_RETURN.
S_ROOTBEST:
  LD A,($BCA0)            ; New root alpha V(1)
  INC A                   ; $FF means forced mate
  JR Z,S_ROOTMATE         ; Mate: check its length
; This entry point is used by the routine at S_PASS.
S_ROOTBEST_SET:
  CALL S_SETBEST          ; Record the best root move
  JP S_NEXTMOVE           ; Continue with the next root move
S_ROOTMATE:
  LD HL,$BD0B             ; Ply at which the mate was detected
  LD A,$FE                ; Lower root alpha to $FE so later mates can still be
                          ; compared
  LD ($BCA0),A            ; ...
  LD A,(HL)               ; A=mate ply
  CP $02                  ; Mate at ply 2 (mate in one)?
  JR Z,S_SETBEST          ; Yes: record the move and end the search pass
  INC L                   ; $BD0C=shortest mate ply so far
  CP (HL)                 ; Not shorter?
  JP NC,S_NEXTMOVE        ; Then keep the earlier move
  LD (HL),A               ; Shorter: remember the ply
  JR S_ROOTBEST_SET       ; Record this root move

; Selective extension checks for small move lists
;
; Reached from S_QEVAL when the list of ply 4 starts in page $B4 (few moves
; generated along the current line). With D>=3, allows one extra ply (two if
; the ply-6 list also starts in page $B4), without the threat test of
; S_QEXTCHK. The list addresses read here may be stale (left from earlier lines
; or searches).
S_EXT_LISTS:
  LD A,($BCB6)            ; High byte of slot(6)
  CP $B4                  ; Ply-6 list in page $B4?
  LD A,($BCAA)            ; A=D
  JR Z,S_EXT_DEEP         ; Yes: two-ply extension test
  CP $03                  ; D<3?
  JR C,S_QEXTCHK          ; Yes: normal test
  LD L,A                  ; L=D
  LD A,($BCB3)            ; Low byte of slot(5)
  CP $58                  ; Ply-5 list starts below $B458?
  JR NC,S_QEXTCHK         ; No: normal test
  LD A,L                  ; A=D
  LD HL,$BCA9             ; HL=$BCA9
  JP S_QEXT_CMP           ; Extend if p<=D+1
S_EXT_DEEP:
  CP $03                  ; D<3?
  JR C,S_QEXTCHK          ; Yes: normal test
  INC A                   ; A=D+1
  LD HL,$BCA9             ; HL=$BCA9
  JP S_QEXT_CMP           ; Extend if p<=D+2

; Selective node: try the next move in generation order
;
; Used at plies beyond the full-width depth. Moves are taken in generation
; order, each made and evaluated statically; a value that fails high cuts off
; (S_QFAILHIGH), a better value raises alpha and becomes the killer. Selected
; moves descend further (S_QEXTCHK, S_QTHREAT). When the list is exhausted the
; node returns (S_RETURN).
S_QUNDO:
  CALL UNMAKE             ; Unmake the previous move
S_QNEXT:
  LD HL,$BCA9             ; Ply counter
; This entry point is used by the routine at S_NEXTMOVE.
S_QNEXT_HL:
  LD A,(HL)               ; A=p
  ADD A,A                 ; 2p
  ADD A,L                 ; ...
  LD L,A                  ; L=$A9+2p: slot(p)
  LD ($BD4E),A            ; $BD4E=slot offset (non-zero: "selective node")
  LD E,(HL)               ; DE=header of this ply's list
  INC L                   ; ...
  LD D,(HL)               ; ...
  EX DE,HL                ; HL=header
  INC L                   ; A=count
  LD A,(HL)               ; ...
  INC L                   ; C=moves taken so far
  LD C,(HL)               ; ...
  SUB C                   ; All taken?
  JP Z,S_RETURN           ; Yes: return to the parent
  INC (HL)                ; One more taken
  INC L                   ; Header flags...
  LD A,(HL)               ; ...
  LD ($BD4B),A            ; ...saved in $BD4B (bit 7: in check)
  INC HL                  ; HL=first entry
  LD B,$00                ; BC=2*taken
  SLA C                   ; ...
  RL B                    ; ...
  ADD HL,BC               ; HL=entry number 'taken'
  ADD HL,BC               ; ...
  INC (HL)                ; Score byte +1: $FF becomes 0 (marks it taken)
  JR NZ,S_QNEXT           ; Already scored/searched: skip it
  PUSH HL                 ; IX=entry
  POP IX                  ; ...
  CALL MAKEMOVE           ; Make the move
  CALL Evaluate           ; Evaluate
  LD C,A                  ; C=evaluation
  OR A                    ; Legal?
  JR NZ,S_QEVAL           ; Yes
  LD A,($BD4B)            ; Illegal: header flags
  INC C                   ; C=1
  RLA                     ; In check?
  JR C,S_QLEAF            ; Yes: counts as value 2 (just above being mated)
  JP S_QUNDO              ; No: ignore the move
; This entry point is used by the routine at S_NODE.
S_QEVAL:
  LD A,($BCB2)            ; High byte of slot(4)
  CP $B4                  ; Ply-4 list in page $B4?
  JR Z,S_EXT_LISTS        ; Yes: small-list extension tests
; This entry point is used by the routine at S_EXT_LISTS.
S_QEXTCHK:
  LD A,($BD4E)            ; $BD4E (set by the evaluation)
  OR A                    ; Zero?
  JR Z,S_QEXT1            ; Yes: extension test
  LD A,(IX+$03)           ; Move flags
  OR A                    ; Bit 7 clear?
  JP P,S_QLEAF            ; Yes: leaf
  BIT 2,A                 ; Bit 2 set?
  JP NZ,S_QLEAF           ; Yes: leaf
S_QEXT1:
  LD HL,$BCAA             ; A=D
  LD A,(HL)               ; ...
  DEC L                   ; HL=$BCA9
; This entry point is used by the routine at S_EXT_LISTS.
S_QEXT_CMP:
  INC A                   ; Limit+1
  CP (HL)                 ; Compare with p
  JP NC,S_DESCEND_MADE    ; p<=limit+1: search this move one ply deeper

; Selective node: back up a static value
;
; C holds the evaluation of the move just made (from the mover's point of view,
; offset by 1). Fail high if it reaches beta; otherwise raise alpha.
; Threatening moves (flags $42) may instead be searched deeper when $BDF6 is
; set.
;
; C Evaluation of the position after the move
; IX Entry of the move
S_QLEAF:
  LD A,($BCA9)            ; A=p
  LD HL,$BCA0             ; Value table
  ADD A,L                 ; ...
  LD L,A                  ; HL=$BCA0+p
  INC C                   ; value = evaluation+1
  LD A,C                  ; ...
  DEC L                   ; HL=V(p-1) (minus beta)
  DEC L                   ; ...
  CPL                     ; ~value
  CP (HL)                 ; value >= beta?
  JR C,S_QFAILHIGH        ; Yes: fail high
  INC L                   ; HL=V(p) (alpha)
  LD A,(IX+$03)           ; Move flags
  AND $42                 ; Threat bits 1 or 6?
  JR NZ,S_QTHREAT         ; Yes: may extend
S_QBEST:
  LD A,C                  ; A=value
  CP (HL)                 ; Compare with alpha
  JP C,S_QUNDO            ; Lower: next move
  JP Z,S_QUNDO            ; Equal: next move
  LD (HL),A               ; New alpha
  LD A,($BD4B)            ; In-check node?
  RLA                     ; Bit 7 into carry
  JP C,S_QUNDO            ; Yes: no killer update
  LD A,($BCA9)            ; A=p
  LD HL,$BC91             ; Killer table
  DEC A                   ; p-1
  ADD A,A                 ; ...
  ADD A,L                 ; ...
  LD L,A                  ; HL=killer(p)
  LD A,(IX+$01)           ; Killer from-square
  LD (HL),A               ; ...
  INC L                   ; ...
  LD A,(IX+$02)           ; Killer to-square
  LD (HL),A               ; ...
  JP S_QUNDO              ; Next move
S_QFAILHIGH:
  CALL UNMAKE             ; Fail high: unmake the move just made...
  CALL UNMAKE             ; ...and the move that led to this node
  LD A,($BD2D)            ; Flip the side to move
  XOR $01                 ; ...
  LD ($BD2D),A            ; ...
  LD HL,$BCA9             ; Ply counter
  DEC (HL)                ; Back to the parent
  LD A,($BD4B)            ; In-check node?
  RLA                     ; Bit 7 into carry
  JP C,S_NEXTMOVE         ; Yes: no killer update
  LD A,(HL)               ; A=new ply q
  LD HL,$BC91             ; Killer table
  ADD A,A                 ; 2q
  ADD A,L                 ; ...
  LD L,A                  ; HL=killer(q+1)
  LD A,(IX+$01)           ; The refutation's from-square
  LD (HL),A               ; ...
  INC L                   ; ...
  LD A,(IX+$02)           ; ...and to-square
  LD (HL),A               ; ...
  JP S_NEXTMOVE           ; Next move at the parent
S_QTHREAT:
  LD A,($BCA9)            ; A=p
  LD B,A                  ; B=p
  LD A,($BCAA)            ; A=D
  INC A                   ; D+2
  INC A                   ; ...
  CP B                    ; p>D+2?
  JR C,S_QBEST            ; Yes: plain leaf
  LD A,C                  ; A=value
  JR Z,S_QTHREAT_CMP      ; p=D+2: use value as is
  ADD A,$01               ; p<D+2: value+1
  JR C,S_QBEST            ; Overflow: plain leaf
S_QTHREAT_CMP:
  CP (HL)                 ; Below alpha?
  JP C,S_QUNDO            ; Yes: next move
  LD A,($BDF6)            ; Threat extensions enabled?
  OR A                    ; ...
  JR Z,S_QBEST            ; No: plain leaf
  LD A,C                  ; A=value
  CP $02                  ; Value 2 (illegal move while in check)?
  JR Z,S_QBEST            ; Yes: plain leaf
  JP S_DESCEND_MADE       ; Search this move one ply deeper

; No legal moves: stalemate or checkmate
;
; S_NOMOVES is reached from S_NEXTMOVE when no move at a full-width node is
; legal. If the killer was legal the node simply returns. Not in check: the
; node's value is the stalemate draw value. In check: the value is 1 (mated)
; and the ply is recorded in $BD0B.
S_STALEMATE:
  LD A,($BCA9)            ; A=p
  LD HL,$BCA0             ; Value table
  ADD A,L                 ; ...
  LD L,A                  ; HL=$BCA0+p
  LD A,($BD2D)            ; Side to move
  RRA                     ; Bit 0 into carry
  LD A,($BD2E)            ; A=$BD2E (material term)
  JR NC,S_STALEMATE_VAL   ; Side bit clear: keep the sign
  NEG                     ; Negate
S_STALEMATE_VAL:
  ADD A,$78               ; Stalemate value = +-$BD2E + $78
  JP S_BACKUP             ; Back it up as this node's value
; This entry point is used by the routine at S_NEXTMOVE.
S_NOMOVES:
  BIT 6,(HL)              ; Was the killer searched (so there was a legal
                          ; move)?
  JP NZ,S_RETURN          ; Yes: just return
  BIT 7,(HL)              ; In check?
  JR Z,S_STALEMATE        ; No: stalemate
  LD A,($BCA9)            ; A=p
  LD ($BD0B),A            ; Record the ply of the mate
  LD HL,$BCA0             ; Value table
  ADD A,L                 ; ...
  LD L,A                  ; HL=$BCA0+p
  LD A,$01                ; Value 1: mated
  JP S_BACKUP             ; Back it up as this node's value

; Get the current ply's list
;
; S_PLYINFO_HL does the same for the ply counter at (HL).
;
; O:B Ply p
; O:HL Header+3 of ply p's list
; O:E Number of moves
; O:C Header byte +2
S_PLYINFO:
  LD HL,$BCA9             ; Ply counter

; Get the list of the ply at (HL)
;
; Used by the routine at S_NEXTMOVE.
;
; HL $BCA9
S_PLYINFO_HL:
  LD A,(HL)               ; A=p
  LD B,A                  ; B=p
  ADD A,A                 ; 2p
  ADD A,L                 ; ...
  LD L,A                  ; L=$A9+2p: slot(p)
  LD E,(HL)               ; DE=header address
  INC L                   ; ...
  LD D,(HL)               ; ...
  EX DE,HL                ; HL=header
  INC L                   ; E=count
  LD E,(HL)               ; ...
  INC L                   ; C=byte +2
  LD C,(HL)               ; ...
  INC L                   ; HL=header+3
  RET                     ; Return

; Pick the highest-scored remaining move
;
; Scans the list until the first entry with score $FF (the next list's header),
; keeping the first entry with the strictly highest score. Scores of 0
; (searched, pruned or illegal) are never picked.
;
;   HL Header+3
; O:DE Chosen entry
; O:E Bit 0 set if no move has a non-zero score
S_PICKBEST:
  XOR A                   ; Best score so far = 0
  LD BC,$0004             ; Entry stride
  DEC L                   ; HL=header+1
  DEC L                   ; ...
  LD E,L                  ; E odd: "nothing found"
  DEC L                   ; HL=header
S_PICK_LOOP:
  ADD HL,BC               ; Next entry's score
  CP (HL)                 ; Not higher than the best?
  JP NC,S_PICK_LOOP       ; Skip it
  LD A,(HL)               ; New best score
  CP $FF                  ; $FF: end of the list
  RET Z                   ; Return
  LD D,H                  ; DE=best entry
  LD E,L                  ; ...
  JP S_PICK_LOOP          ; Continue

; Try the recapture first
;
; Reached from S_NODE when the move leading to this node has flag bit 2 set.
; Searches the new list backwards for a move to the same square; if found it is
; searched first like a killer, but never recorded as one ($BD4B=$80).
;
; A Ply p
; B Number of moves
; IX Entry of the move leading here
S_RECAPTURE:
  LD HL,$BCA9             ; Ply counter
  INC A                   ; p+1
  ADD A,A                 ; ...
  ADD A,L                 ; ...
  LD L,A                  ; L=slot(p+1): end of this list
  LD E,(HL)               ; HL=end of the list
  INC L                   ; ...
  LD D,(HL)               ; ...
  EX DE,HL                ; ...
  INC L                   ; HL=end+2
  INC L                   ; ...
  LD DE,$FFFC             ; Stride -4
  LD A,(IX+$02)           ; A=square the opponent moved to
S_RECAP_LOOP:
  ADD HL,DE               ; Previous entry's to-square
  CP (HL)                 ; Same square?
  JR Z,S_RECAP_FOUND      ; Yes
  DJNZ S_RECAP_LOOP       ; Scan backwards
  JP S_NEXTMOVE           ; No recapture: normal move loop
S_RECAP_FOUND:
  LD D,$01                ; (unused)
  DEC L                   ; HL=score byte of the recapture
  DEC L                   ; ...
  PUSH HL                 ; IX=entry
  POP IX                  ; ...
  LD (HL),$00             ; Mark it searched
  CALL MAKEMOVE           ; Make the recapture
  SET 7,(IX+$01)          ; Set bit 7 of its from-square (never matches as a
                          ; killer)
  LD A,$80                ; $BD4B bit 7: do not record as killer
  LD ($BD4B),A            ; ...
  JP S_NODE_EVAL          ; Evaluate and handle like a killer

; Forward pruning of weak moves
;
; Called after static scoring at a full-width node, and at the root to compute
; the pruning margin. Threshold C = max(best static score, killer evaluation) -
; 9; moves scoring below it may get score 0 (never searched) through
; S_PRUNE_NEAR, PRUNE_ENDGAME or PRUNE_TEST, unless their flags include any of
; bits 7, 6, 3 or 0 ($C9). Disabled when $BD09 bit 7 is set.
;
;   A Best static score of the node
; O:D Plies 1-2 only: 2*count minus the number of moves below the threshold
S_PRUNE:
  LD HL,$BD09             ; Pruning disabled?
  BIT 7,(HL)              ; ...
  RET NZ                  ; Yes
  LD IY,S_PRUNE_NEAR      ; Default test routine
  EX AF,AF'               ; A'=best score
  CALL S_PLYINFO          ; B=p, HL=header+3, E=count, C=header+2
  LD A,B                  ; A=p
  CP $03                  ; Ply 3 or deeper?
  LD A,($BD2D)            ; A=phase flags
  JR NC,S_PRUNE_SEL       ; Yes: test depends on the phase
  LD A,E                  ; Plies 1-2: D=2*count
  ADD A,A                 ; ...
  LD D,A                  ; ...
  LD A,$10                ; ...and the lenient test
S_PRUNE_SEL:
  LD B,E                  ; B=count
  BIT 4,A                 ; Deep endgame (or plies 1-2)?
  JR Z,S_PRUNE_SEL2       ; No
  LD IY,PRUNE_ENDGAME     ; Lenient test
S_PRUNE_SEL2:
  BIT 3,A                 ; Endgame bit 3?
  JR Z,S_PRUNE_THR        ; No
  LD IY,PRUNE_TEST        ; Strict test
S_PRUNE_THR:
  EX AF,AF'               ; A=best score
  CP C                    ; Killer evaluation higher?
  JR NC,S_PRUNE_C         ; No
  LD A,C                  ; Use it
S_PRUNE_C:
  SUB $09                 ; Threshold = best-9
  RET C                   ; Below 9: no pruning
  LD C,A                  ; C=threshold
  INC HL                  ; HL=first entry
S_PRUNE_LOOP:
  LD A,(HL)               ; A=score
  INC L                   ; HL=flags byte
  INC L                   ; ...
  INC L                   ; ...
  SUB C                   ; Below the threshold?
  JR C,S_PRUNE_TEST       ; Yes: apply the test
; This entry point is used by the routine at PRUNE_TEST.
S_PRUNE_NEXT:
  INC HL                  ; Next entry
  DJNZ S_PRUNE_LOOP       ; Loop over the moves
  RET                     ; Return
S_PRUNE_TEST:
  JP (IY)                 ; Jump to the selected test (A=score-threshold)

; Forward pruning test: default
;
; Within 16 of the threshold: prune only if flag bit 2 is set (PRUNE_TEST).
; Further below: prune (PRUNE_ZERO). In both cases moves with any of flags $C9
; are kept. The comparison is done modulo 256.
;
; A Score minus threshold
; HL Flags byte of the entry
S_PRUNE_NEAR:
  ADD A,$10               ; A+16
  JP M,PRUNE_ZERO         ; Negative: more than 16 below, prune

; Move-list pruning: test a low-scored move (jump target of S_PRUNE)
;
; Part of the pruning loop in S_PRUNE, which reaches this code by JP (IY) when
; a move's score byte is below the threshold C, with A = score - C (negative)
; and HL pointing at the move's flags byte (+3). A pruned move gets score 0
; (treated as already searched) unless its flags AND $C9 is non-zero (check,
; bit 6, capture or pawn-to-6th/7th). The loop continues at S_PRUNE_NEXT.
;
; There are three variants, selected by IY in S_PRUNE. $80A2 (default; in the
; search file) prunes if score < C - 16, or if score < C and flags bit 2 is
; set. $80A7 (game-phase bit 3 of $BD2D set) prunes if score < C and flags bit
; 2 is set. $80BB (ply < 3 only; it also decrements D) prunes if score < C - 16
; and flags bit 2 is set. $80AB is the shared "prune unless flags AND $C9"
; step.
;
; A Score - threshold (negative)
; HL Address of the move's flags byte
PRUNE_TEST:
  BIT 2,(HL)              ; Flags bit 2 clear: keep the move
  JR Z,S_PRUNE_NEXT       ;
; This entry point is used by the routine at S_PRUNE_NEAR.
PRUNE_ZERO:
  LD A,$C9                ; Flags AND $C9 non-zero (check, bit 6, capture,
  AND (HL)                ; pawn-to-6th/7th): keep
  JR NZ,S_PRUNE_NEXT      ;
  DEC L                   ; Otherwise set the score byte (+0) to 0: pruned
  DEC L                   ;
  DEC L                   ;
  LD (HL),$00             ;
  INC L                   ; Back to the flags byte
  INC L                   ;
  INC L                   ;
  JP S_PRUNE_NEXT         ; Next move
PRUNE_ENDGAME:
  DEC D                   ; D = D - 1
  ADD A,$10               ; Score >= threshold - 16: keep
  JP P,S_PRUNE_NEXT       ;
  JP PRUNE_TEST           ; Otherwise test flags bit 2 as at $80A7

; Search: cut-off test at the depth limit
;
; Called from S_NODE with A = ply when the ply equals the iteration depth
; ($BCAA). On even plies only: if $BD09 is not negative (bit 7 clear), and
; $BD09 < C (unsigned), and the 8-bit difference $BD09 - C is below the byte at
; $BC9E + ply (unsigned), and the current list header +3 bit 0 (parent was a
; pawn move to the 6th/7th rank) is clear, the move just made is unmade and the
; search returns to the previous ply via S_FAILHIGH (discarding this routine's
; return address). Search-subsystem semantics: see docs/arch for the search.
;
; A Ply
; C Score to compare
HORIZON_CUT:
  BIT 0,A                 ; Odd ply: return
  RET NZ                  ;
  LD HL,$BC9E             ; HL = $BC9E + ply
  ADD A,L                 ;
  LD L,A                  ;
  LD A,($BD09)            ; A = $BD09: negative means return
  OR A                    ;
  RET M                   ;
  SUB C                   ; A = $BD09 - C: no borrow means return
  RET NC                  ;
  CP (HL)                 ; A >= ($BC9E + ply): return
  RET NC                  ;
  CALL S_PLYINFO          ; HL = header +3 of the current list
  BIT 0,(HL)              ; Bit 0 set (parent pawn move to 6th/7th): return
  RET NZ                  ;
  POP HL                  ; Discard the return address
  CALL UNMAKE             ; Unmake the current move
  JP S_FAILHIGH           ; Back up one ply
; Entry from S_NODE: make the best root-scored move ($BD1A).
SRCH_MAKE_BEST:
  LD IX,($BD1A)           ; IX = best move entry
  LD (IX+$00),$00         ; Score byte = 0 (selected)
  JP SRCH_MAKE_DESCEND    ; Make it and descend
; Entry from S_NODE: select the highest-scored remaining move.
SRCH_NEXT_MOVE:
  CALL S_PICKBEST         ; DE = first entry with the highest score
                          ; (S_PICKBEST)
  BIT 0,E                 ; None left (E still odd): return from this ply
  JP NZ,S_RETURN          ;
  PUSH DE                 ; IX = selected move
  POP IX                  ;
  XOR A                   ; Score byte = 0 (selected)
  LD (DE),A               ;
SRCH_MAKE_DESCEND:
  CALL MAKEMOVE           ; Make the move
  LD A,($BCA9)            ; Ply 1: remember the root move ($7E06)
  DEC A                   ;
  JP Z,S_DESCEND_ROOT     ;
  ADD A,A                 ; Otherwise set bit 7 of $BC83 + 2 * (ply - 1)
  LD HL,$BC83             ;
  ADD A,L                 ;
  LD L,A                  ;
  SET 7,(HL)              ;
  JP S_DESCEND_PLY        ; Toggle the side and descend ($7E0A)

; Make a move
;
; Applies the move at IX (+1 from, +2 to, +3 flags) to the board ($BD00) and
; the piece records ($BE00). Pushes restore information under its return
; address, so the caller's stack grows by 4 bytes (quiet move) or 6 bytes
; (capture, en passant, castling). Each make must be undone by UNMAKE before
; the caller returns. Returns via JP (HL) in the main register set; the
; alternate set is used throughout.
;
; Stack frame (top first): [type byte, marker] then, for captures/en
; passant/castling, [square, piece code] of the captured pawn/piece or the
; castling rook, then [from-square, moving piece code]. The marker byte is
; popped into F by UNMAKE: $80 quiet (S), $84 quiet promotion (S, P/V), $00
; capture, $04 capture-promotion (P/V), $01 en passant (C), $40 castling (Z).
;
; Side effects: the type byte of the moving piece is updated (moved bit 4; pawn
; advancement nibble; promotion to $19; king centralisation bits 6-7 and
; castled bit 5). Captured piece: square byte bit 7 set. $BD0D (material
; balance, Black minus White, pawn units) is adjusted by captures and
; promotions. Flags bit 0 of the move is set for a pawn move to the 6th or 7th
; rank and cleared for a promotion. Castling with score byte +0 = $FF puts the
; KING's piece code (not the rook's) on the rook's destination square.
;
; IX Move entry
MAKEMOVE:
  POP HL                  ; HL = return address (kept in the main set)
  EXX                     ; Work in the alternate set
  LD H,$BD                ; HL = board[from]
  LD L,(IX+$01)           ;
  LD E,(HL)               ; E = moving piece code; D = from-square
  LD D,L                  ;
  PUSH DE                 ; Push [from, piece]
  LD (HL),$00             ; board[from] = 0
  LD L,(IX+$02)           ; C = piece code on the to-square (0 if empty)
  LD C,(HL)               ;
  LD (HL),E               ; board[to] = moving piece
  LD B,L                  ; B = to-square
  INC H                   ; HL = moving piece's record ($BE00 + code AND $FB)
  RES 2,E                 ;
  LD L,E                  ;
  LD (HL),B               ; Record square = to
  INC L                   ; HL = record type byte
  LD E,D                  ; E = from-square
  LD D,(HL)               ; D = old type byte (saved for unmake)
  LD A,$0F                ; Value 0: king
  AND D                   ;
  JP Z,MK_KING            ;
  DEC A                   ; Value 1: pawn
  JR Z,MK_PAWN            ;
  SET 4,(HL)              ; Other pieces: set the moved bit 4
  DEC C                   ; Something on the to-square: capture
  INC C                   ;
  JR NZ,MK_CAPTURE        ;
MK_QUIET:
  LD E,$80                ; Marker $80: quiet move
MK_PUSHRET:
  PUSH DE                 ; Push [old type, marker]
  EXX                     ; Return
  JP (HL)                 ;
; Pawn move. A = relative rank of the to-square x 16 (from the mover's side).
MK_PAWN:
  LD A,B                  ; A = to-square rank x 16
  AND $70                 ;
  CP E                    ; Black (rank below the from-square): mirror the rank
  JR NC,MAKEMOVE_0        ; (XOR $70)
  XOR $70                 ;
MAKEMOVE_0:
  SUB $30                 ; Relative rank < 3 (to 2nd/3rd rank): type unchanged
  JR C,MK_PAWN_FLAGS      ;
  JR Z,MAKEMOVE_2         ; Relative rank 3 (4th rank): type $11
  SUB $10                 ; Relative rank 4 (5th rank): type $31
  JR Z,MK_PAWN_TYPE       ;
  SET 0,(IX+$03)          ; Rank 6 or more: set flags bit 0 (pawn to 6th/7th)
  SUB $20                 ; Relative rank 5 (6th rank): type $61
  LD A,$61                ;
  JR C,MK_PAWN_SETTYPE    ;
  LD A,$91                ; Relative rank 6 (7th rank): type $91
  JR Z,MK_PAWN_SETTYPE    ;
; Promotion (always to a queen).
  RES 0,(IX+$03)          ; Clear flags bit 0
  LD (HL),$19             ; Type = $19 (queen, moved)
  LD A,($BD0D)            ; $BD0D: -8 for White, +8 for Black (queen 9 - pawn
  BIT 7,L                 ; 1)
  JR Z,MAKEMOVE_1         ;
  ADD A,$10               ;
MAKEMOVE_1:
  SUB $08                 ;
  LD ($BD0D),A            ;
  LD E,$84                ; Marker $84: quiet promotion
  BIT 3,(IX+$03)          ; No capture: push the marker and return
  JP Z,MK_PUSHRET         ;
  LD E,$04                ; Marker $04: capture-promotion
  JP MK_CAPTURE_X         ;
MK_PAWN_TYPE:
  ADD A,$20               ; A = $11 + $20 or $11 (type for the 5th or 4th rank)
MAKEMOVE_2:
  ADD A,$11               ;
MK_PAWN_SETTYPE:
  LD (HL),A               ; Store the new pawn type byte
MK_PAWN_FLAGS:
  LD A,(IX+$03)           ; Not a capture (flags bit 3 clear): quiet pawn move
  BIT 3,A                 ;
  JP Z,MK_QUIET           ;
  BIT 5,A                 ; Capture without bit 5: ordinary capture
  JP Z,MK_CAPTURE         ;
; En passant: remove the pawn behind the to-square.
  LD A,B                  ; Captured pawn square = to - 16 (White) or to + 16
  CP E                    ; (Black)
  JR NC,MAKEMOVE_3        ;
  ADD A,$20               ;
MAKEMOVE_3:
  SUB $10                 ;
  DEC H                   ; C = captured pawn code; board[that square] = 0
  LD L,A                  ;
  LD C,(HL)               ;
  LD (HL),$00             ;
  INC H                   ; B = captured pawn square
  LD B,L                  ;
  LD E,$01                ; Marker $01: en passant
  JP MK_CAPTURE_X         ;
MK_CAPTURE:
  LD E,$00                ; Marker $00: capture
MK_CAPTURE_X:
  PUSH BC                 ; Push [captured square, captured code]
  RES 2,C                 ; HL = captured piece record
  LD L,C                  ;
  SET 7,(HL)              ; Mark captured (square byte bit 7)
  PUSH DE                 ; Push [old type, marker]
  INC L                   ; A = captured value; negated if the captured piece
  LD A,$0F                ; is Black
  AND (HL)                ;
  BIT 7,L                 ;
  JR Z,MAKEMOVE_4         ;
  NEG                     ;
MAKEMOVE_4:
  LD HL,$BD0D             ; $BD0D = $BD0D + A
  ADD A,(HL)              ;
  LD (HL),A               ;
  EXX                     ; Return
  JP (HL)                 ;
; King move.
MK_KING:
  CALL KINGTYPE           ; Update the king's type byte (moved, centralisation)
  LD A,(IX+$03)           ; Neither capture nor castling: quiet king move
  AND $18                 ;
  JP Z,MK_QUIET           ;
  AND $08                 ; King capture: ordinary capture
  JP NZ,MK_CAPTURE        ;
; Castling.
  SET 5,(HL)              ; Type byte bit 5: has castled
  DEC H                   ; HL = board page
  BIT 2,B                 ; Queenside if to-square bit 2 is clear (c-file)
  JR Z,MAKEMOVE_5         ;
  INC B                   ; Kingside: rook on to + 1; C = rook code; clear its
  LD L,B                  ; square
  LD C,(HL)               ;
  LD (HL),$00             ;
  DEC L                   ; Rook destination = to - 1
  DEC L                   ;
  JP MK_CASTLE_ROOK       ;
MAKEMOVE_5:
  DEC B                   ; Queenside: rook on to - 2; C = rook code; clear its
  DEC B                   ; square
  LD L,B                  ;
  LD C,(HL)               ;
  LD (HL),$00             ;
  INC L                   ; Rook destination = to + 1
  INC L                   ;
  INC L                   ;
MK_CASTLE_ROOK:
  LD (HL),C               ; Rook to its destination
  LD A,(IX+$00)           ; Score byte $FF: put the king's code there instead
  INC A                   ; (C AND $84)
  JR NZ,MK_CASTLE_PUSH    ;
  LD A,$84                ;
  AND C                   ;
  LD (HL),A               ;
MK_CASTLE_PUSH:
  PUSH BC                 ; Push [rook origin, rook code]
  RES 2,C                 ; Rook record square = destination
  LD B,$BE                ;
  LD A,L                  ;
  LD (BC),A               ;
  LD E,$40                ; Marker $40: castling
  PUSH DE                 ; Push [old type, marker] and return
  EXX                     ;
  JP (HL)                 ;

; Set a king's type byte: moved bit and centralisation
;
; Sets the moved bit, clears bits 6-7, then adds $40 for each ring k = 1, 2, 3
; for which both to + $11k and to - $11k are on the board. This gives bits 6-7
; = min(file, rank, 7 - file, 7 - rank), capped at 3. KingEdgeDistance uses
; entry $8203 when setting up a position.
;
; B King square
; D Old type byte
; HL Address of the king's type byte
KINGTYPE:
  LD A,D                  ; A = old type + moved bit
  OR $10                  ;
; This entry point is used by the routine at KingEdgeDistance.
KINGTYPE_X:
  AND $3F                 ; Clear bits 6-7
  LD E,$11                ; E = $11 (diagonal step)
KINGTYPE_LOOP:
  LD (HL),A               ; Store the type byte
  LD A,B                  ; Square + E off the board: done
  ADD A,E                 ;
  AND $88                 ;
  RET NZ                  ;
  LD A,B                  ; Square - E off the board: done
  SUB E                   ;
  AND $88                 ;
  RET NZ                  ;
  LD A,$11                ; E = E + $11
  ADD A,E                 ;
  LD E,A                  ;
  LD A,$40                ; Type byte + $40
  ADD A,(HL)              ;
  JP KINGTYPE_LOOP        ;

; Unmake a move
;
; Undoes the most recent MAKEMOVE using the data it pushed. The marker is
; popped into F: P/V set (promotion) reverses the $BD0D promotion adjustment; S
; set (quiet) restores only the mover; Z (castling) restores the rook; C (en
; passant) puts the captured pawn back on its square; otherwise (capture) the
; captured piece goes back on the to-square and its record is restored. The
; mover's square and type byte are restored from the frame.
UNMAKE:
  POP HL                  ; HL = return address (kept in the main set)
  EXX                     ;
  POP AF                  ; A = old type byte, F = marker
  POP HL                  ; HL = [square, code] of the captured piece/rook, or
                          ; [from, mover] for a quiet move
  LD C,A                  ; C = old type byte
  LD A,$00                ; A = 0 (flags unchanged)
  LD D,$BD                ; D = board page
  CALL PE,UN_PROMO_FIX    ; Promotion: undo the $BD0D adjustment
  JP M,UN_RESTORE_MOVER   ; Quiet move
  JR Z,UN_CASTLE          ; Castling
  JR C,UN_EP              ; En passant
  LD B,L                  ; B = captured piece code
UN_RESTORE_CAP:
  RES 2,L                 ; HL = captured piece record; clear its captured bit
  LD H,$BE                ;
  RES 7,(HL)              ;
  INC L                   ; A = its value, negated if the piece is White
  LD A,$0F                ;
  AND (HL)                ;
  BIT 7,L                 ;
  JR NZ,UNMAKE_0          ;
  NEG                     ;
UNMAKE_0:
  LD HL,$BD0D             ; $BD0D = $BD0D + A
  ADD A,(HL)              ;
  LD (HL),A               ;
  LD A,B                  ; A = code to put back on the to-square
UN_POP_MOVER:
  POP HL                  ; HL = [from, mover]
UN_RESTORE_MOVER:
  LD E,H                  ; board[from] = mover
  EX DE,HL                ;
  LD (HL),E               ;
  EX DE,HL                ;
  RES 2,L                 ; HL = mover's record; B = its square (the to-square)
  LD H,$BE                ;
  LD B,(HL)               ;
  LD (HL),E               ; Record square = from
  INC L                   ; Record type = old type byte
  LD (HL),C               ;
  LD L,B                  ; board[to] = A (captured code, or 0)
  DEC H                   ;
  LD (HL),A               ;
  EXX                     ; Return
  JP (HL)                 ;
UN_EP:
  LD E,H                  ; En passant: board[captured square] = captured pawn
  LD B,A                  ; A = 0 for the to-square
  LD A,L                  ;
  LD (DE),A               ;
  JP UN_RESTORE_CAP       ; Restore the captured pawn's record and the mover
UN_CASTLE:
  LD E,H                  ; Castling: board[rook origin] = rook
  LD A,L                  ;
  LD (DE),A               ;
  RES 2,L                 ; Rook record square = origin (B = destination)
  LD H,$BE                ;
  LD B,(HL)               ;
  LD (HL),E               ;
  XOR A                   ; board[rook destination] = 0
  LD E,B                  ;
  LD (DE),A               ;
  JP UN_POP_MOVER         ; Restore the king

; Undo the $BD0D promotion adjustment
;
; Adds 8 to $BD0D for a White promotion, or subtracts 8 for Black. The value S
; of the caller's flags tells this apart: S set means a quiet promotion, so L
; is the mover's code; S clear means a capture-promotion, so L is the captured
; piece's code and the colour test is reversed. Preserves F via EX AF,AF'.
;
; L Piece code (see above)
UN_PROMO_FIX:
  JP P,UN_PROMO_CAP       ; S clear (capture-promotion): reverse the colour
  EX AF,AF'               ; test
  LD A,($BD0D)            ; A = $BD0D
  BIT 7,L                 ; Mover is White?
  JR Z,UN_PROMO_ADD       ;
UN_PROMO_SUB:
  SUB $10                 ; A = A - $10 (then + 8 = net -8 for Black)
UN_PROMO_ADD:
  ADD A,$08               ; A = A + 8
  LD ($BD0D),A            ;
  EX AF,AF'               ; Restore flags
  RET                     ;
UN_PROMO_CAP:
  EX AF,AF'               ; Capture-promotion: L is the captured piece
  LD A,($BD0D)            ; (opposite colour)
  BIT 7,L                 ;
  JR NZ,UN_PROMO_ADD      ;
  JR UN_PROMO_SUB         ;

; Unused (zero bytes up to $8400)
  DEFS $0174

; Evaluate the position after a move
;
; Static evaluation of the current position from the point of view of the side
; that has just moved (the side NOT to move in bit 0 of $BD2D). Called after
; every make-move in the search and at the root. It builds attack maps for both
; sides in the piece records (bytes +2..+5), scores mobility, development, pawn
; structure and king safety, runs a static exchange evaluation (SEE) on every
; attacked piece, and combines material change, threats, positional score and a
; small random term into one unsigned byte. See docs/arch/50-eval.md for the
; full specification.
;
; Register conventions inside the evaluation: main H=$BD (board page), main D =
; off-board mask $88 (pawn direction $11/$F1 while scanning pawns), main E =
; positional accumulator, main B = square of the piece being scanned, main C =
; ray direction. A' = king/pawn accumulator. Alternate set: H'=$BE
; (piece-record page), L' = record pointer (a piece code points at record+4),
; C' = attack weight of the scanning piece (pawn 1, minor $04, rook $10, queen
; $40), E' = line mask ($08 orthogonal, $C4 diagonal), B' = pass flags (bit 7
; colour being scanned, bit 4 second pass, bit 5 pin list non-empty, bit 6
; check seen, bit 0..bit 3 game phase from $BD2D).
;
; If the side to move can capture the enemy king (or the kings touch) the
; routine aborts through EvAbort, which restores SP from $BD3D and returns A=0.
;
;   IX Move-list entry of the move just made (+2 to-square read, +3 flags
;      updated)
; O:A Score: $80 = level, higher is better for the side that has just moved;
;     $02/$FC on large material swings; 0 if the move was illegal
; O:B Positional component (signed, mover's view), used by PRESEARCH
Evaluate:
  LD ($BD3D),SP           ; Save SP so that EvAbort can abort from any depth
  XOR A                   ; A'=0 (king/pawn accumulator), E=0 (positional
  LD E,A                  ; accumulator)
  EX AF,AF'               ;
  LD H,$BD                ; H=$BD (board page)
  EXX                     ; H'=$BE (piece-record page)
  LD H,$BE                ;
  LD A,($BD2D)            ; A=side/phase flags rotated: bit 7=side to move
  RRCA                    ; (1=White), bit 0..bit 3=phase bits
  LD IY,EvPawnAttacks     ; IY=pawn routine: EvPawnAttacks normally,
  BIT 1,A                 ; EvPawnEndgame when total material is below $34,
  JR Z,Evaluate_0         ;
  LD IY,EvPawnEndgame     ;
  BIT 2,A                 ; EvPawnLateEndgame when it is below $28
  JR Z,Evaluate_0         ;
  LD IY,EvPawnLateEndgame ;
Evaluate_0:
  ADD A,$80               ; B'=pass flags: bit 7=colour scanned first (side to
  LD B,A                  ; move), Carry=side to move is White
  EXX                     ; Back to the main set
  JP C,EvWhitePieces      ; White to move: scan White first (EvWhitePieces)
; Scan Black's pieces (queen, rooks, bishops, knights, then pawns),
; accumulating attacks in the records and positional score in E/A'.
EvBlackPieces:
  LD D,$88                ; D=$88 (off-board mask)
  LD A,($BE88)            ; Black queen (if not captured)
  OR A                    ;
  CALL P,EvQueen          ;
  LD A,($BE90)            ; Black rooks
  OR A                    ;
  CALL P,EvRook           ;
  LD A,($BE98)            ;
  OR A                    ;
  CALL P,EvRook           ;
  LD A,($BEA0)            ; Black bishops
  OR A                    ;
  CALL P,EvBlackBishop    ;
  LD A,($BEA8)            ;
  OR A                    ;
  CALL P,EvBlackBishop    ;
  LD A,($BEB0)            ; Black knights
  OR A                    ;
  CALL P,EvBlackKnight    ;
  LD A,($BEB8)            ;
  OR A                    ;
  CALL P,EvBlackKnight    ;
  LD D,$F1                ; D=$F1 (black pawns attack down the board); B=C=$FF
  LD BC,$FFFF             ; (no previous pawn files)
  LD HL,($BEC0)           ; Black pawns a..h (records $BEC0..$BEF8; the d- and
  BIT 7,L                 ; e-pawn records use EvCentrePawn)
  CALL Z,EvPawn           ;
  LD HL,($BEC8)           ;
  BIT 7,L                 ;
  CALL Z,EvPawn           ;
  LD HL,($BED0)           ;
  BIT 7,L                 ;
  CALL Z,EvPawn           ;
  LD HL,($BED8)           ;
  BIT 7,L                 ;
  CALL Z,EvCentrePawn     ;
  LD HL,($BEE0)           ;
  BIT 7,L                 ;
  CALL Z,EvCentrePawn     ;
  LD HL,($BEE8)           ;
  BIT 7,L                 ;
  CALL Z,EvPawn           ;
  LD HL,($BEF0)           ;
  BIT 7,L                 ;
  CALL Z,EvPawn           ;
  LD HL,($BEF8)           ;
  BIT 7,L                 ;
  CALL Z,EvPawn           ;
  EXX                     ; Second pass done?
  BIT 4,B                 ; No: switch colour and scan White (EvSwitchToWhite)
  JP Z,EvSwitchToWhite    ;
; Both sides scanned. Finish the positional score, then evaluate exchanges on
; every attacked piece.
EvScoreExchanges:
  BIT 6,B                 ; Skip if a check was seen (bit 6 of B')
  JR NZ,Evaluate_1        ;
  LD L,(IX+$02)           ; L=piece code on the move's to-square
  DEC H                   ;
  LD L,(HL)               ;
  INC H                   ;
  BIT 2,L                 ; If a piece stands there,
  JR Z,Evaluate_1         ;
  INC L                   ; set bit 1 of its record +5 ('moved piece' marker
  SET 1,(HL)              ; for the SEE penalty)
Evaluate_1:
  BIT 3,B                 ; Late endgame (bit 3 of B')?
  JP Z,Evaluate_3         ;
  EXX                     ; Yes: halve E, or quarter it if there are no pawns
  LD A,($BD6D)            ; ($BD6D=0)
  OR A                    ;
  JR NZ,Evaluate_2        ;
  SRA E                   ;
Evaluate_2:
  SRA E                   ;
  EXX                     ;
Evaluate_3:
  BIT 5,B                 ; Pin list non-empty (bit 5 of B')?
  EXX                     ; If so, remove the pinned pieces' illegal attacks
  CALL NZ,EvUndoPins      ; (EvUndoPins)
  LD HL,$BD4A             ; E = A'/4 + E + $BD4A (positional score, Black's
  EX AF,AF'               ; view)
  SRA A                   ;
  SRA A                   ;
  ADD A,E                 ;
  ADD A,(HL)              ;
  LD E,A                  ;
  LD HL,$0000             ; $BD39/$BD3A = 0 (best and second-best SEE gain),
  LD ($BD39),HL           ; save IX in $BD3B
  LD ($BD3B),IX           ;
  LD HL,($BE8A)           ; Black queen: if attacked (+2/+3 non-zero), SEE with
  LD A,H                  ; value 9; clear its attack bytes
  OR L                    ;
  JR Z,Evaluate_4         ;
  LD BC,($BE8C)           ;
  LD A,$09                ;
  CALL EvSee              ;
  LD ($BE8A),HL           ;
Evaluate_4:
  LD ($BE8C),HL           ;
  LD HL,($BE92)           ; Black rook (a): SEE with value 5
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_5         ;
  LD BC,($BE94)           ;
  LD A,$05                ;
  CALL EvSee              ;
  LD ($BE92),HL           ;
Evaluate_5:
  LD ($BE94),HL           ;
  LD HL,($BE9A)           ; Black rook (h): SEE with value 5
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_6         ;
  LD BC,($BE9C)           ;
  LD A,$05                ;
  CALL EvSee              ;
  LD ($BE9A),HL           ;
Evaluate_6:
  LD ($BE9C),HL           ;
  LD HL,($BEA2)           ; Black bishop (c): SEE with value 3
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_7         ;
  LD BC,($BEA4)           ;
  LD A,$03                ;
  CALL EvSee              ;
  LD ($BEA2),HL           ;
Evaluate_7:
  LD ($BEA4),HL           ;
  LD HL,($BEAA)           ; Black bishop (f): SEE with value 3
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_8         ;
  LD BC,($BEAC)           ;
  LD A,$03                ;
  CALL EvSee              ;
  LD ($BEAA),HL           ;
Evaluate_8:
  LD ($BEAC),HL           ;
  LD HL,($BEB2)           ; Black knight (b): SEE with value 3
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_9         ;
  LD BC,($BEB4)           ;
  LD A,$03                ;
  CALL EvSee              ;
  LD ($BEB2),HL           ;
Evaluate_9:
  LD ($BEB4),HL           ;
  LD HL,($BEBA)           ; Black knight (g): SEE with value 3
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_10        ;
  LD BC,($BEBC)           ;
  LD A,$03                ;
  CALL EvSee              ;
  LD ($BEBA),HL           ;
Evaluate_10:
  LD ($BEBC),HL           ;
  LD HL,($BEC2)           ; Black pawn records a..h: SEE with value = low
  LD A,H                  ; nibble of the type byte (1, or the promoted piece's
  OR L                    ; value)
  JR Z,Evaluate_11        ;
  LD BC,($BEC4)           ;
  LD A,($BEC1)            ;
  CALL EvSeePawn          ;
  LD ($BEC2),HL           ;
Evaluate_11:
  LD ($BEC4),HL           ;
  LD HL,($BECA)           ;
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_12        ;
  LD BC,($BECC)           ;
  LD A,($BEC9)            ;
  CALL EvSeePawn          ;
  LD ($BECA),HL           ;
Evaluate_12:
  LD ($BECC),HL           ;
  LD HL,($BED2)           ;
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_13        ;
  LD BC,($BED4)           ;
  LD A,($BED1)            ;
  CALL EvSeePawn          ;
  LD ($BED2),HL           ;
Evaluate_13:
  LD ($BED4),HL           ;
  LD HL,($BEDA)           ;
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_14        ;
  LD BC,($BEDC)           ;
  LD A,($BED9)            ;
  CALL EvSeePawn          ;
  LD ($BEDA),HL           ;
Evaluate_14:
  LD ($BEDC),HL           ;
  LD HL,($BEE2)           ;
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_15        ;
  LD BC,($BEE4)           ;
  LD A,($BEE1)            ;
  CALL EvSeePawn          ;
  LD ($BEE2),HL           ;
Evaluate_15:
  LD ($BEE4),HL           ;
  LD HL,($BEEA)           ;
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_16        ;
  LD BC,($BEEC)           ;
  LD A,($BEE9)            ;
  CALL EvSeePawn          ;
  LD ($BEEA),HL           ;
Evaluate_16:
  LD ($BEEC),HL           ;
  LD HL,($BEF2)           ;
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_17        ;
  LD BC,($BEF4)           ;
  LD A,($BEF1)            ;
  CALL EvSeePawn          ;
  LD ($BEF2),HL           ;
Evaluate_17:
  LD ($BEF4),HL           ;
  LD HL,($BEFA)           ;
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_18        ;
  LD BC,($BEFC)           ;
  LD A,($BEF9)            ;
  CALL EvSeePawn          ;
  LD ($BEFA),HL           ;
Evaluate_18:
  LD ($BEFC),HL           ;
  XOR A                   ; E = -E (White's view)
  SUB E                   ;
  LD E,A                  ;
  LD HL,($BD39)           ; Keep Black's best/second gains on the stack; reset
  PUSH HL                 ; $BD39/$BD3A
  LD HL,$0000             ;
  LD ($BD39),HL           ;
  LD HL,($BE0A)           ; White queen: SEE with value 9
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_19        ;
  LD BC,($BE0C)           ;
  LD A,$09                ;
  CALL EvSee              ;
  LD ($BE0A),HL           ;
Evaluate_19:
  LD ($BE0C),HL           ;
  LD HL,($BE12)           ; White rook (a): SEE with value 5
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_20        ;
  LD BC,($BE14)           ;
  LD A,$05                ;
  CALL EvSee              ;
  LD ($BE12),HL           ;
Evaluate_20:
  LD ($BE14),HL           ;
  LD HL,($BE1A)           ; White rook (h): SEE with value 5
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_21        ;
  LD BC,($BE1C)           ;
  LD A,$05                ;
  CALL EvSee              ;
  LD ($BE1A),HL           ;
Evaluate_21:
  LD ($BE1C),HL           ;
  LD HL,($BE22)           ; White bishop (c): SEE with value 3
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_22        ;
  LD BC,($BE24)           ;
  LD A,$03                ;
  CALL EvSee              ;
  LD ($BE22),HL           ;
Evaluate_22:
  LD ($BE24),HL           ;
  LD HL,($BE2A)           ; White bishop (f): SEE with value 3
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_23        ;
  LD BC,($BE2C)           ;
  LD A,$03                ;
  CALL EvSee              ;
  LD ($BE2A),HL           ;
Evaluate_23:
  LD ($BE2C),HL           ;
  LD HL,($BE32)           ; White knight (b): SEE with value 3
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_24        ;
  LD BC,($BE34)           ;
  LD A,$03                ;
  CALL EvSee              ;
  LD ($BE32),HL           ;
Evaluate_24:
  LD ($BE34),HL           ;
  LD HL,($BE3A)           ; White knight (g): SEE with value 3
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_25        ;
  LD BC,($BE3C)           ;
  LD A,$03                ;
  CALL EvSee              ;
  LD ($BE3A),HL           ;
Evaluate_25:
  LD ($BE3C),HL           ;
  LD HL,($BE42)           ; White pawn records a..h: SEE with value from the
  LD A,H                  ; type byte
  OR L                    ;
  JR Z,Evaluate_26        ;
  LD BC,($BE44)           ;
  LD A,($BE41)            ;
  CALL EvSeePawn          ;
  LD ($BE42),HL           ;
Evaluate_26:
  LD ($BE44),HL           ;
  LD HL,($BE4A)           ;
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_27        ;
  LD BC,($BE4C)           ;
  LD A,($BE49)            ;
  CALL EvSeePawn          ;
  LD ($BE4A),HL           ;
Evaluate_27:
  LD ($BE4C),HL           ;
  LD HL,($BE52)           ;
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_28        ;
  LD BC,($BE54)           ;
  LD A,($BE51)            ;
  CALL EvSeePawn          ;
  LD ($BE52),HL           ;
Evaluate_28:
  LD ($BE54),HL           ;
  LD HL,($BE5A)           ;
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_29        ;
  LD BC,($BE5C)           ;
  LD A,($BE59)            ;
  CALL EvSeePawn          ;
  LD ($BE5A),HL           ;
Evaluate_29:
  LD ($BE5C),HL           ;
  LD HL,($BE62)           ;
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_30        ;
  LD BC,($BE64)           ;
  LD A,($BE61)            ;
  CALL EvSeePawn          ;
  LD ($BE62),HL           ;
Evaluate_30:
  LD ($BE64),HL           ;
  LD HL,($BE6A)           ;
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_31        ;
  LD BC,($BE6C)           ;
  LD A,($BE69)            ;
  CALL EvSeePawn          ;
  LD ($BE6A),HL           ;
Evaluate_31:
  LD ($BE6C),HL           ;
  LD HL,($BE72)           ;
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_32        ;
  LD BC,($BE74)           ;
  LD A,($BE71)            ;
  CALL EvSeePawn          ;
  LD ($BE72),HL           ;
Evaluate_32:
  LD ($BE74),HL           ;
  LD HL,($BE7A)           ;
  LD A,H                  ;
  OR L                    ;
  JR Z,Evaluate_33        ;
  LD BC,($BE7C)           ;
  LD A,($BE79)            ;
  CALL EvSeePawn          ;
  LD ($BE7A),HL           ;
Evaluate_33:
  LD ($BE7C),HL           ;
; Combine. D,E = gains available against Black's pieces (second, best); H,L =
; against White's pieces (second, best). Arrange them as threats against the
; side to move (D,E) and against the mover (H,L), and take material from the
; mover's view.
  LD B,E                  ; B = positional score (White's view); restore IX
  LD IX,($BD3B)           ;
  POP DE                  ; D,E = Black's pieces (second, best); H,L = White's
  LD HL,($BD39)           ; pieces
  LD A,($BD2D)            ; White to move?
  RRA                     ;
  JR NC,Evaluate_34       ;
  XOR A                   ; Yes: mover is Black: negate B, swap the threat
  SUB B                   ; pairs, A = $BD0D (material change, Black's view)
  LD B,A                  ;
  EX DE,HL                ;
  LD A,($BD0D)            ;
  JP Evaluate_35          ;
Evaluate_34:
  LD A,($BD0D)            ; No: mover is White: A = -$BD0D
  NEG                     ;
Evaluate_35:
  SUB L                   ; A = 2*(material - best gain the side to move has
  ADD A,A                 ; against the mover)
  DEC L                   ; Any such gain?
  JP M,Evaluate_37        ;
  SET 1,(IX+$03)          ; Yes: flag the move (bit 1 of IX+3)
  JR Z,Evaluate_36        ; If the gain is 2 or more, A=A-1
  DEC A                   ;
Evaluate_36:
  SUB H                   ; A = A - second gain
Evaluate_37:
  DEC E                   ; Mover threatens something of the side to move?
  JP M,Evaluate_40        ;
  BIT 2,(IX+$03)          ; Skip the bonus if the moved piece itself is en
  JR NZ,Evaluate_38       ; prise (bit 2 of IX+3)
  INC B                   ; B=B+2
  INC B                   ;
  DEC D                   ; A second threat?
  JP M,Evaluate_38        ;
  SET 6,(IX+$03)          ; Yes: flag a double threat (bit 6 of IX+3), B=B+2
  INC B                   ;
  INC B                   ;
  DEC D                   ; A gain of 2 or more on the second threat: B=B+2
  JP M,Evaluate_40        ;
  INC B                   ;
  INC B                   ;
  JP Evaluate_40          ;
Evaluate_38:
  EX AF,AF'               ; If mover's best threat exceeds the side to move's
  LD A,E                  ; best capture, flag bit 6 of IX+3
  INC L                   ;
  CP L                    ;
  JR C,Evaluate_39        ;
  SET 6,(IX+$03)          ;
Evaluate_39:
  EX AF,AF'               ;
; Scale: material outside -28..27 half-pawns saturates the score.
Evaluate_40:
  CP $1C                  ; Material component in range?
  JR C,Evaluate_41        ;
  CP $E4                  ;
  JP NC,Evaluate_41       ;
  RLA                     ; No: return $02 (losing) or $FC (winning)
  LD A,$02                ;
  RET C                   ;
  LD A,$FC                ;
  RET                     ;
Evaluate_41:
  ADD A,A                 ; C = material * 4 (8 per pawn)
  ADD A,A                 ;
  LD C,A                  ;
  LD A,B                  ; D = (B + B/2 + carry)/2 (positional * 3/4)
  SRA A                   ;
  ADC A,B                 ;
  SRA A                   ;
  LD D,A                  ;
  LD HL,$BCCE             ; Increment the random byte $BCCE; add its bit 0 (bit
  INC (HL)                ; 0..bit 1 on move 1)
  LD A,($BD49)            ;
  DEC A                   ;
  LD A,(HL)               ;
  JR NZ,Evaluate_42       ;
  AND $03                 ;
  JR Evaluate_43          ;
Evaluate_42:
  AND $01                 ;
Evaluate_43:
  ADD A,D                 ;
  CP $0C                  ; Clamp the positional term to -12..+12
  JR C,Evaluate_44        ;
  CP $F4                  ;
  JR NC,Evaluate_44       ;
  RLA                     ;
  LD A,$0C                ;
  JR NC,Evaluate_44       ;
  LD A,$F4                ;
Evaluate_44:
  ADD A,C                 ; A = material + positional + $80
  ADD A,$80               ;
  RET                     ;
EvSwitchToWhite:
  LD A,$90                ; Second pass: B' bit 4 set, colour flipped to White
  ADD A,B                 ;
  LD B,A                  ;
  EXX                     ; E = -E
  XOR A                   ;
  SUB E                   ;
  LD E,A                  ;
  LD H,$BD                ; H=$BD; A' = -A'
  EX AF,AF'               ;
  NEG                     ;
  EX AF,AF'               ;
; Scan White's pieces, then both kings.
EvWhitePieces:
  LD A,($BE08)            ; White queen (if present)
  LD D,$88                ;
  OR A                    ;
  CALL P,EvQueen          ;
  LD A,($BE10)            ; White rooks
  OR A                    ;
  CALL P,EvRook           ;
  LD A,($BE18)            ;
  OR A                    ;
  CALL P,EvRook           ;
  LD A,($BE20)            ; White bishops
  OR A                    ;
  CALL P,EvWhiteBishop    ;
  LD A,($BE28)            ;
  OR A                    ;
  CALL P,EvWhiteBishop    ;
  LD A,($BE30)            ; White knights
  OR A                    ;
  CALL P,EvWhiteKnight    ;
  LD A,($BE38)            ;
  OR A                    ;
  CALL P,EvWhiteKnight    ;
  LD D,$11                ; D=$11 (white pawns attack up the board); B=C=$FF
  LD BC,$FFFF             ;
  LD HL,($BE40)           ; White pawns a..h (d- and e-pawn records use
  BIT 7,L                 ; EvCentrePawn)
  CALL Z,EvPawn           ;
  LD HL,($BE48)           ;
  BIT 7,L                 ;
  CALL Z,EvPawn           ;
  LD HL,($BE50)           ;
  BIT 7,L                 ;
  CALL Z,EvPawn           ;
  LD HL,($BE58)           ;
  BIT 7,L                 ;
  CALL Z,EvCentrePawn     ;
  LD HL,($BE60)           ;
  BIT 7,L                 ;
  CALL Z,EvCentrePawn     ;
  LD HL,($BE68)           ;
  BIT 7,L                 ;
  CALL Z,EvPawn           ;
  LD HL,($BE70)           ;
  BIT 7,L                 ;
  CALL Z,EvPawn           ;
  LD HL,($BE78)           ;
  BIT 7,L                 ;
  CALL Z,EvPawn           ;
  LD HL,($BE00)           ; White king (EvWhiteKing: early-queen check, then
  CALL EvWhiteKing        ; EvKing)
  EX AF,AF'               ; A' = -A', E = -E (Black's view)
  NEG                     ;
  EX AF,AF'               ;
  XOR A                   ;
  SUB E                   ;
  LD E,A                  ;
  LD HL,($BE80)           ; Black king (B' bit 7 set = black)
  EXX                     ;
  SET 7,B                 ;
  CALL EvKing             ;
  EXX                     ; Second pass done?
  BIT 4,B                 ;
  JP NZ,EvScoreExchanges  ;
  SET 4,B                 ; No: set the second-pass flag and scan Black
  EXX                     ; (EvBlackPieces)
  JP EvBlackPieces        ;

; Late endgame king: centralisation
;
; Used by EvEndgameKing when there are no pawns ($BD6D=0) and the king belongs
; to the side favoured by $BD1E. Adds a centralisation term to A': D (the
; king's diagonal edge distance * 8, or -10 if 0) plus 16 on files d/e or ranks
; 4/5, plus 8 on files c/f or ranks 3/6.
;
; A $BD6D
; D King's edge distance * 8 (from type bit 6..bit 7)
; L King's square
EvKingCentralise:
  OR A                    ; Pawns on the board: just add D (EvEndgameKing_1)
  JP NZ,EvEndgameKing_1   ;
  LD A,D                   ; D=0: use -10
  OR A                     ;
  JR NZ,EvKingCentralise_0 ;
  SUB $0A                  ;
  LD D,A                   ;
EvKingCentralise_0:
  LD A,$07                ; Files d,e?
  AND L                   ;
  INC A                   ;
  RRA                     ;
  CP $02                  ;
  JR Z,EvKingCentralise_1 ;
  LD A,$70                 ; Ranks 4,5?
  AND L                    ;
  CP $30                   ;
  JR Z,EvKingCentralise_1  ;
  CP $40                   ;
  JR NZ,EvKingCentralise_2 ;
EvKingCentralise_1:
  EX AF,AF'               ; Yes: A' = A' + 16 + D
  ADD A,$10               ;
  JP EvEndgameKing_2      ;
EvKingCentralise_2:
  LD A,$07                ; Files c,f?
  AND L                   ;
  CP $02                  ;
  JR Z,EvKingCentralise_3 ;
  CP $05                  ;
  JR Z,EvKingCentralise_3 ;
  LD A,$70                ; Ranks 3,6?
  AND L                   ;
  CP $20                  ;
  JR Z,EvKingCentralise_3 ;
  CP $50                  ;
  JR NZ,EvEndgameKing_1   ;
; This entry point is used by the routine at EvEndgameKing.
EvKingCentralise_3:
  EX AF,AF'               ; Yes: A' = A' + 8 + D
  ADD A,$08               ;
  JP EvEndgameKing_2      ;

; Opening: penalise early queen moves
;
; Used by EvWhiteKing before move 8. C = 9 - move number; a queen that has
; moved (bit 4 of its type byte) and is still on the board costs its side C
; points of E.
EvEarlyQueenCheck:
  LD A,($BD49)            ; C = 9 - $BD49
  CPL                     ;
  ADD A,$0A               ;
  EXX                     ;
  LD C,A                  ;
  LD A,($BE89)             ; Black queen moved and present: E=E+C
  BIT 4,A                  ;
  JR Z,EvEarlyQueenCheck_0 ;
  LD A,($BE88)             ;
  OR A                     ;
  JP M,EvEarlyQueenCheck_0 ;
  LD A,E                   ;
  ADD A,C                  ;
  LD E,A                   ;
EvEarlyQueenCheck_0:
  LD A,($BE09)             ; White queen moved and present: E=E-C
  BIT 4,A                  ;
  JR Z,EvEarlyQueenCheck_1 ;
  LD A,($BE08)             ;
  OR A                     ;
  JP M,EvEarlyQueenCheck_1 ;
  LD A,E                   ;
  SUB C                    ;
  LD E,A                   ;
EvEarlyQueenCheck_1:
  EXX                     ; Continue with the king (EvKing)
  JP EvKing               ;

; Endgame king evaluation
;
; Used by EvKing in the endgame (bit 2 of B'). Pawns next to the king are worth
; 8 each in A'; in the late endgame (bit 3) they are worth 4 and the king may
; be centralised.
;
; A Pass flags (B')
; H King's type byte
; L King's square
EvEndgameKing:
  BIT 3,A                 ; Late endgame?
  JR NZ,EvEndgameKing_0   ;
  LD H,$BD                ; No: weight 8 per adjacent pawn
  LD B,L                  ;
  LD C,$08                ;
  JP EvKingNeighbours     ;
EvEndgameKing_0:
  LD B,A                  ; Late: weight 4; D = edge distance * 8 (type bit
  LD C,$04                ; 6..bit 7)
  LD A,$C0                ;
  AND H                   ;
  RRA                     ;
  RRA                     ;
  RRA                     ;
  LD D,A                  ;
  LD A,($BD1E)            ; $BD1E = 0?
  OR A                    ;
  JR Z,EvEndgameKing2     ;
  XOR B                   ; Same sign as the colour being scanned:
  LD A,($BD6D)            ; centralisation (EvKingCentralise) with A=$BD6D
  JP P,EvKingCentralise   ;
EvEndgameKing2:
  RR D                    ; D = D/2
  OR A                    ; $BD1E set and pawns present: just add D
  JR NZ,EvEndgameKing_1   ;
  BIT 7,H                  ; Otherwise a king with bit 7 of its type set gets
  JR NZ,EvKingCentralise_3 ; +8 (EvKingCentralise_3)
; This entry point is used by the routine at EvKingCentralise.
EvEndgameKing_1:
  EX AF,AF'               ; A' = A' + D
; This entry point is used by the routine at EvKingCentralise.
EvEndgameKing_2:
  ADD A,D
  EX AF,AF'               ; }
  LD H,$BD                ; Scan the king's neighbours (EvKingNeighbours)
  LD B,L                  ;
  JP EvKingNeighbours     ;

; Evaluate the white king
;
; Used by Evaluate. Before move 8 (bit 0 of B' clear) first applies the
; early-queen penalty (EvEarlyQueenCheck).
;
; H King's type byte
; L King's square
EvWhiteKing:
  EXX                     ; Move 8 reached?
  BIT 0,B                 ;
  JR Z,EvEarlyQueenCheck  ;

; Evaluate a king (middlegame)
;
; Used by Evaluate (black king) and EvWhiteKing. The king's type byte: bit 4
; moved, bit 5 castled, bit 6..bit 7 distance from the edge along the diagonals
; (0..3, maintained by KINGTYPE).
;
; H King's type byte
; L King's square
EvKing:
  LD A,B                  ; A=pass flags; endgame?
  EXX                     ;
  BIT 2,A                 ;
  JR NZ,EvEndgameKing     ;
  BIT 5,H                 ; Castled?
  JP Z,EvKingUncastled    ;
  LD A,$C0                ; Castled but away from the edge: exposed
  AND H                   ; (EvKingExposed)
  JR NZ,EvKingExposed     ;
  LD C,$0A                ; Castled: pawn-shelter weight 10
  LD B,L                  ;
  LD H,$BD                ; Look two ranks ahead (or behind, if that leaves the
  LD A,$1F                ; board) on files f-1..f+1
  ADD A,B                 ;
  JP P,EvKing_0           ;
  SUB $40                 ;
EvKing_0:
  LD L,A                  ;
  BIT 6,(HL)              ; Any pawn there (piece code bit 6)?
  JR NZ,EvKing_1          ;
  INC L                   ;
  BIT 6,(HL)              ;
  JR NZ,EvKing_1          ;
  INC L                   ;
  BIT 6,(HL)              ;
  JR NZ,EvKing_1          ;
  DEC E                   ; None: E=E-2
  DEC E                   ;
EvKing_1:
  LD L,B                  ; Restore L
; This entry point is used by the routines at EvEndgameKing and EvKingExposed.
EvKingNeighbours:
  DEC L                         ; Left neighbour (no file check: may read an
  XOR A                         ; off-board byte)
  OR (HL)                       ;
  CALL NZ,EvKingNeighbourSquare ;
  INC L                         ; Right neighbour
  INC L                         ;
  OR (HL)                       ;
  CALL NZ,EvKingNeighbourSquare ;
  LD A,$10                      ; Rank above (if on the board): centre, right,
  ADD A,B                       ; left
  JP M,EvKing_2                 ;
  LD L,A                        ;
  XOR A                         ;
  OR (HL)                       ;
  CALL NZ,EvKingNeighbourSquare ;
  INC L                         ;
  OR (HL)                       ;
  CALL NZ,EvKingNeighbourSquare ;
  DEC L                         ;
  DEC L                         ;
  OR (HL)                       ;
  CALL NZ,EvKingNeighbourSquare ;
EvKing_2:
  LD A,$F0                      ; Rank below (if on the board): centre, right,
  ADD A,B                       ; left
  RET M                         ;
  LD L,A                        ;
  XOR A                         ;
  OR (HL)                       ;
  CALL NZ,EvKingNeighbourSquare ;
  INC L                         ;
  OR (HL)                       ;
  CALL NZ,EvKingNeighbourSquare ;
  DEC L                         ;
  DEC L                         ;
  OR (HL)                       ;
  RET Z                         ;

; King: process a neighbouring piece
;
; Used by EvKing. Counts the king as a defender (+1 in record +5) of a friendly
; neighbour or an attacker (+1 in record +3) of an enemy one, and adds the
; shelter weight C to A' if the neighbour is a pawn record (either colour).
; Kings next to each other abort the evaluation.
;
; A Piece code
; C Shelter weight
EvKingNeighbourSquare:
  EXX                     ; L'=record+5
  LD L,A                  ;
  INC L                   ;
  XOR B                        ; Friendly?
  JP P,EvKingNeighbourSquare_0 ;
  LD A,$78                ; Enemy king next to this king: abort
  AND L                   ;
  JP Z,EvAbort            ;
  DEC L                   ; Enemy: L'=record+3
  DEC L                   ;
EvKingNeighbourSquare_0:
  INC (HL)                ; Count the king attack/defence
  XOR A                   ; Pawn record ($40-$7F, $C0-$FF)?
  BIT 6,L                 ;
  EXX                     ;
  RET Z                   ;
  EX AF,AF'               ; Yes: A' = A' + C
  ADD A,C                 ;
  EX AF,AF'               ;
  RET                     ;

; King away from the edge or uncastled
;
; Continuation of EvKing.
EvKingExposed:
  LD C,$04                ; Shelter weight 4
  BIT 7,H                 ; Edge distance 2 or more: E=E-2
  JP Z,EvKingExposed_0    ;
  DEC E                   ;
  DEC E                   ;
EvKingExposed_0:
  DEC E                   ; E=E-3
  DEC E                   ;
  DEC E                   ;
  LD B,L                  ; Scan neighbours
  LD H,$BD                ;
  JP EvKingNeighbours     ;
; This entry point is used by the routine at EvKing.
EvKingUncastled:
  BIT 4,H                 ; King moved?
  JR NZ,EvKingExposed_1   ;
  LD H,$BD                ; Never moved: weight 0, E=E+1
  LD B,L                  ;
  LD C,$00                ;
  INC E                   ;
  JP EvKingNeighbours     ;
EvKingExposed_1:
  LD A,E                  ; Moved without castling: E=E-6, weight 8
  SUB $06                 ;
  LD E,A                  ;
  LD C,$08                ;
  LD A,$C0                ; Away from the edge: further penalty (EvKingExposed)
  AND H                   ;
  JR NZ,EvKingExposed     ;
  LD H,$BD                ; Scan neighbours
  LD B,L                  ;
  JP EvKingNeighbours     ;

; Pawn: late-endgame advancement bonus
;
; Reached through JP (IY) from EvPawn when total material is below $28. A'
; gains the pawn type byte / 4 (0, 4, 12, 24 or 36 for relative ranks <=3, 4,
; 5, 6, 7). In the first pass a pawn on its seventh rank records the piece in
; front of it in $BD4E.
;
; H Pawn type byte
; L Square diagonally ahead-right (pawn square + D)
EvPawnLateEndgame:
  SRL H                   ; A' = A' + type/4
  SRL H                   ;
  EX AF,AF'               ;
  ADD A,H                 ;
  EX AF,AF'               ;
  BIT 5,H                 ; Seventh-rank pawn (type bit 7)?
  JP Z,EvPawnAttacks      ;
  EXX                     ; Only in the first pass
  BIT 4,B                 ;
  EXX                     ;
  JR NZ,EvPawnAttacks     ;
  LD H,$BD                ; $BD4E = contents of the square in front of the pawn
  DEC L                   ;
  LD A,(HL)               ;
  INC L                   ;
  LD ($BD4E),A            ;
  JP EvPawnAttacks2       ; Mark its attacks (EvPawnAttacks2)

; Pawn penalties
;
; Continuations of EvCentrePawn/EvPawn.
EvPawnDoubled:
  DEC E                   ; Doubled pawn: E=E-3
  DEC E                   ;
  DEC E                   ;
  JP EvPawn2              ;
; This entry point is used by the routine at EvCentrePawn.
EvPawnCentreUnmoved:
  DEC E                   ; Unmoved centre pawn: E=E-3
  DEC E                   ;
  DEC E                   ;
  JP EvPawn               ;

; Evaluate a d- or e-pawn record
;
; Used by Evaluate for the d- and e-pawn records. A pawn standing on rank 2 or
; rank 7 (either colour) costs 3.
;
; H Type byte
; L Square
EvCentrePawn:
  LD A,L                   ; (rank+2) AND 4 = 0, i.e. on rank 2 or 7?
  ADD A,$20                ;
  BIT 6,A                  ;
  JR Z,EvPawnCentreUnmoved ;

; Evaluate a pawn record
;
; Used by Evaluate. Dispatches promoted pieces to the piece routines, penalises
; a pawn on the same file as either of the previous two pawn records scanned,
; then jumps through IY to add the phase-dependent advancement bonus and mark
; the pawn's two attacked squares.
;
; B,C File of the previous two pawn records ($FF = none)
; D Pawn direction $11 (White) or $F1 (Black)
; H Type byte
; L Square
EvPawn:
  LD A,$0E                ; Promoted (type bit 1..bit 3)?
  AND H                   ;
  JR NZ,EvPromotedPawn    ;
  LD A,D                  ; L = square diagonally ahead-right; A = its file
  ADD A,L                 ; nibble (= the pawn's file + 1)
  LD L,A                  ;
  AND $0F                 ;
  CP B                    ; Same file as one of the previous two pawns: doubled
  JR Z,EvPawnDoubled      ; (EvPawnDoubled)
  CP C                    ;
  JR Z,EvPawnDoubled      ;
; This entry point is used by the routine at EvPawnDoubled.
EvPawn2:
  LD C,B                  ; Remember the file; continue at IY
  LD B,A                  ;
  JP (IY)                 ;

; Pawn: endgame advancement bonus
;
; Reached through JP (IY) when total material is below $34: A' gains type/8 (0,
; 2, 6, 12 or 18 for relative ranks <=3..7).
EvPawnEndgame:
  SRL H                   ; Unadvanced pawn: no bonus
  JR Z,EvPawnAttacks      ;
  SRL H                   ; A' = A' + type/8
  SRL H                   ;
  EX AF,AF'               ;
  ADD A,H                 ;
  EX AF,AF'               ;
; This entry point is used by the routine at EvPawnLateEndgame.
EvPawnAttacks:
  LD H,$BD                ; H=$BD
; This entry point is used by the routine at EvPawnLateEndgame.
EvPawnAttacks2:
  LD A,(HL)               ; Piece diagonally ahead-right?
  OR A                    ;
  CALL NZ,EvPawnHit       ;
  DEC L                   ; Piece diagonally ahead-left (L-2)? (no board-edge
  DEC L                   ; checks)
  OR (HL)                 ;
  RET Z                   ;

; Pawn attacks a piece
;
; Used by EvPawn. Adds 1 to the defender count (+4) of a friendly piece or to
; the attacker count (+2) of an enemy piece.
;
; A Piece code
EvPawnHit:
  EXX                     ; L'=record+4
  LD L,A                  ;
  XOR B                   ; Friendly?
  JP P,EvPawnHit_0        ;
  LD A,$78                ; Enemy king: check (EvPawnGivesCheck)
  AND L                   ;
  JR Z,EvPawnGivesCheck   ;
  DEC L                   ; Enemy: L'=record+2
  DEC L                   ;
EvPawnHit_0:
  INC (HL)                ; Count the pawn
  EXX                     ;
  XOR A                   ;
  RET                     ;

; Evaluate a promoted pawn record as its new piece
;
; Continuation of EvPawn. Saves B, C, D, pushes the return stub
; EvPromotedPawnReturn and dispatches on the type byte: queen, rook, bishop or
; knight (no development penalty).
EvPromotedPawn:
  PUSH BC                    ; Save pawn state; return via EvPromotedPawnReturn
  PUSH DE                    ;
  LD BC,EvPromotedPawnReturn ;
  PUSH BC                    ;
  LD C,H                  ; C=type, H=$BD, D=$88
  LD H,$BD                ;
  LD D,$88                ;
  LD A,L                  ; Queen?
  BIT 3,C                 ;
  JP NZ,EvQueen           ;
  BIT 2,C                 ; Rook?
  JP NZ,EvRook            ;
  BIT 7,C                 ; Bishop?
  LD B,A                  ;
  JP NZ,EvBishop          ;
  JP EvKnight             ; Knight

; Return from a promoted piece
;
; Restores D (pawn direction) and B, C (pawn files) but keeps E.
EvPromotedPawnReturn:
  LD L,E                  ; Restore DE but keep E
  POP DE                  ;
  LD E,L                  ;
  POP BC                  ;
  RET                     ; Restore BC and return

; Pawn attacks the enemy king
;
; Continuation of EvPawnHit. In the first pass the side to move could capture
; the king: abort. Otherwise flag the move as a check (bit 7 of IX+3) and add 1
; to E.
EvPawnGivesCheck:
  BIT 4,B                 ; First pass: abort
  JP Z,EvAbort            ;
  SET 7,(IX+$03)          ; Flag check on the move
  EXX                     ; E=E+1
  INC E                   ;
  RET                     ;

; SEE: no direct attackers
;
; Continuation of EvSee. Without direct attackers the piece counts as attacked
; only if the enemy king (record +3 bit 0) is among the attackers; the x-ray
; attackers and the king are then fed to the exchange.
EvSeeNoDirect:
  BIT 0,H                 ; King among the x-ray attackers?
  JR NZ,EvSeeNoDirect_0   ;
  LD H,$00                ; No: nothing to do
  RET                     ;
EvSeeNoDirect_0:
  LD A,H                  ; Yes: start the attacker generator on record +3
  CALL EvXrayAttackerGen  ;
  JP EvSeeStart           ;

; SEE for a pawn record
;
; Used by Evaluate. A = type byte; the value is its low nibble.
EvSeePawn:
  AND $0F                 ; A = value (type AND $0F)

; Static exchange evaluation of one piece
;
; Used by Evaluate. Plays out the capture sequence on the piece using two
; coroutines: EvAttackerGen/EvXrayAttackerGen yield attackers in the order
; pawn, minor, rook, queen, x-ray minor, x-ray rook, x-ray queen, king
; (continuation in IY); EvDefenderGen yields defenders likewise (continuation
; in IX). The loop works in the alternate set with A = running gain, E' = lower
; bound, D' = upper bound, L' = current attacker value, H' = current defender
; value, C' = defenders left of that value; main D = attackers left of that
; value.
;
; A positive result updates $BD39 (best) and $BD3A (second best). Any
; non-negative result costs E one point, three if the piece carries the
; moved/checking marker (+5 bit 1), which also flags bit 2 of IX+3.
;
;   A Piece value
;   B Record +5 (x-ray defenders, king defender bit 0, marker bit 1)
;   C Record +4 (defenders: pawns bit 0-1, minors bit 2-3, rooks bit 4-5,
;     queens bit 6-7)
;   H Record +3 (x-ray attackers, king attacker bit 0)
;   L Record +2 (attackers: pawns bit 0-1, minors bit 2-3, rooks bit 4-5,
;     queens bit 6-7)
; O:HL 0 (written back to clear the record)
EvSee:
  EXX                     ; D' = value (upper bound)
  LD D,A                  ;
  EXX                     ;
  LD A,L                  ; No direct attackers? (EvSeeNoDirect)
  OR A                    ;
  JR Z,EvSeeNoDirect      ;
  CALL EvAttackerGen      ; First attacker: L' = value, main D = count
; This entry point is used by the routine at EvSeeNoDirect.
EvSeeStart:
  CALL EvDefenderGen      ; First defender: H' = value, C' = count
  LD E,$FF                ; E' = -1 (lower bound); A = value (gain if the first
  LD A,D                  ; attacker captures)
EvSeeLoop:
  LD B,$00                ; B' = 0
  BIT 0,H                 ; No defender left: stop
  JR Z,EvSeeResult        ;
  SUB L                   ; Defender recaptures: A = A - attacker value
  EXX                     ; One attacker of this value used; fetch the next
  DEC D                   ; kind when exhausted
  EXX                     ;
  CALL Z,EvNextAttacker   ;
  CP E                    ; Below the lower bound: B'=1
  JP M,EvSee_2            ;
  CP D                    ; At or above the upper bound: B'=2
  JP P,EvSee_1            ;
  LD E,A                  ; Otherwise raise the lower bound
EvSeeAttacker:
  BIT 0,L                 ; No attacker left: stop
  JR Z,EvSeeResult        ;
  ADD A,H                 ; Attacker recaptures: A = A + defender value
  CP E                    ; Below the lower bound: B'=B'-1, stop if 0
  JP M,EvSee_4            ;
  CP D                    ; At or above the upper bound: B'=B'-2, stop if 0
  JP P,EvSee_3            ;
  LD D,A                  ; Otherwise lower the upper bound
EvSee_0:
  DEC C                   ; One defender used; fetch the next kind when
  CALL Z,EvNextDefender   ; exhausted
  JP EvSeeLoop            ; Next round
EvSee_1:
  INC B                   ; B'=2 / B'=1
EvSee_2:
  INC B                   ;
  JP EvSeeAttacker        ;
EvSee_3:
  DEC B                   ; B'=B'-2 / B'=B'-1; continue unless 0
EvSee_4:
  DEC B                   ;
  JR NZ,EvSee_0           ;
EvSeeResult:
  CP E                    ; A = max(A, lower bound)
  JP P,EvSee_5            ;
  LD A,E                  ;
EvSee_5:
  CP D                    ; A = min(A, upper bound)
  JP M,EvSee_6            ;
  LD A,D                  ;
EvSee_6:
  OR A                    ; Negative: piece is safe, return HL=0
  EXX                     ;
  JP M,EvSee_8            ;
  JR Z,EvSeePenalty       ; Zero: no gain, but still penalised
  LD HL,$BD39             ; Keep the best gain in $BD39,
  CP (HL)                 ;
  JR C,EvSee_7            ;
  LD C,A                  ;
  LD A,(HL)               ;
  LD (HL),C               ;
EvSee_7:
  INC L                   ; and the second best in $BD3A
  CP (HL)                 ;
  JR C,EvSeePenalty       ;
  LD (HL),A               ;
EvSeePenalty:
  DEC E                   ; E=E-1 for a piece under attack
  BIT 1,B                 ; Moved/checking piece (+5 bit 1)?
  JR NZ,EvSee_9           ;
EvSee_8:
  LD HL,$0000             ; No: return HL=0
  RET                     ;
EvSee_9:
  LD IX,($BD3B)           ; Yes: restore IX, flag bit 2 of IX+3 (moved piece en
  SET 2,(IX+$03)          ; prise), E=E-2
  LD HL,$0000             ;
  DEC E                   ;
  DEC E                   ;
  RET                     ;

; SEE coroutine: direct attackers
;
; Used by EvSee. Yields each non-empty attacker group of record +2 (main L) in
; increasing value, then continues with the x-ray byte +3 (EvXrayAttackerGen).
; Each yield (EvYieldPawnAttackers...EvYieldKingAttacker) stores the
; continuation in IY, sets L'=value and main D=count, and returns with the
; alternate set active and A/A' swapped. Exhausted: L'=0.
EvAttackerGen:
  AND $03                      ; Pawns
  CALL NZ,EvYieldPawnAttackers ;
  LD A,$0C                      ; Minor pieces
  AND L                         ;
  CALL NZ,EvYieldMinorAttackers ;
  LD A,$30                     ; Rooks
  AND L                        ;
  CALL NZ,EvYieldRookAttackers ;
  LD A,$C0                      ; Queens
  AND L                         ;
  CALL NZ,EvYieldQueenAttackers ;
  OR H                    ; X-ray byte empty: finished
  JR Z,EvAttackersDone    ;

; SEE coroutine: x-ray attackers
;
; Used by EvSeeNoDirect and continuation of EvAttackerGen. Groups of record +3
; (main H): minors, rooks, queens, then the king (bit 0).
EvXrayAttackerGen:
  AND $0C                       ; X-ray minors
  CALL NZ,EvYieldMinorAttackers ;
  LD A,$30                     ; X-ray rooks
  AND H                        ;
  CALL NZ,EvYieldRookAttackers ;
  LD A,$C0                      ; X-ray queens
  AND H                         ;
  CALL NZ,EvYieldQueenAttackers ;
  INC A                       ; King
  AND H                       ;
  CALL NZ,EvYieldKingAttacker ;
; This entry point is used by the routine at EvAttackerGen.
EvAttackersDone:
  EXX                     ; No more attackers: L'=0
  LD L,A                  ;
  EX AF,AF'               ;
  RET                     ;

; Yield pawn attackers
;
; Coroutine yield used by EvAttackerGen.
EvYieldPawnAttackers:
  LD D,A                  ; D=count; IY=continuation
  POP IY                  ;
  EXX                     ; L'=1 (pawn)
  LD L,$01                ;
  EX AF,AF'               ;
  RET                     ;

; Resume the attacker coroutine
;
; Used by EvSee when the current attacker group is used up.
EvNextAttacker:
  EX AF,AF'               ; Save the SEE state and resume at IY
  EXX                     ;
  XOR A                   ;
  JP (IY)                 ;

; Yield minor-piece attackers
;
; Coroutine yield used by EvAttackerGen and EvXrayAttackerGen.
EvYieldMinorAttackers:
  RRA                     ; D=count (bit 2-3); IY=continuation
  RRA                     ;
  LD D,A                  ;
  POP IY                  ;
  EXX                     ; L'=3
  LD L,$03                ;
  EX AF,AF'               ;
  RET                     ;

; Yield rook attackers
;
; Coroutine yield used by EvAttackerGen and EvXrayAttackerGen.
EvYieldRookAttackers:
  RRA                     ; D=count (bit 4-5); IY=continuation
  RRA                     ;
  RRA                     ;
  RRA                     ;
  LD D,A                  ;
  POP IY                  ;
  EXX                     ; L'=5
  LD L,$05                ;
  EX AF,AF'               ;
  RET                     ;

; Yield queen attackers
;
; Coroutine yield used by EvAttackerGen and EvXrayAttackerGen.
EvYieldQueenAttackers:
  RLCA                    ; D=count (bit 6-7); IY=continuation
  RLCA                    ;
  LD D,A                  ;
  POP IY                  ;
  EXX                     ; L'=9
  LD L,$09                ;
  EX AF,AF'               ;
  RET                     ;

; Yield the king as attacker
;
; Coroutine yield used by EvXrayAttackerGen.
EvYieldKingAttacker:
  LD D,A                  ; D=1; IY=continuation
  POP IY                  ;
  EXX                     ; L'=13
  LD L,$0D                ;
  EX AF,AF'               ;
  RET                     ;

; SEE coroutine: defenders
;
; Used by EvSee. Yields defender groups from record +4 (main C) then x-ray
; defenders from +5 (main B): minors, rooks, queens and finally the king (bit
; 0), which also costs E one point when it is reached. Continuation in IX.
; Exhausted: H'=0.
EvDefenderGen:
  EXX                     ; No direct defenders?
  LD A,C                  ;
  OR A                    ;
  JR Z,EvDefenderGen_0    ;
  AND $03                      ; Pawns
  CALL NZ,EvYieldPawnDefenders ;
  LD A,$0C                      ; Minors
  AND C                         ;
  CALL NZ,EvYieldMinorDefenders ;
  LD A,$30                     ; Rooks
  AND C                        ;
  CALL NZ,EvYieldRookDefenders ;
  LD A,$C0                      ; Queens
  AND C                         ;
  CALL NZ,EvYieldQueenDefenders ;
EvDefenderGen_0:
  OR B                    ; X-ray byte empty: finished
  JR Z,EvDefendersDone    ;
  AND $0C                       ; X-ray minors
  CALL NZ,EvYieldMinorDefenders ;
  LD A,$30                     ; X-ray rooks
  AND B                        ;
  CALL NZ,EvYieldRookDefenders ;
  LD A,$C0                      ; X-ray queens
  AND B                         ;
  CALL NZ,EvYieldQueenDefenders ;
  INC A                       ; King
  AND B                       ;
  CALL NZ,EvYieldKingDefender ;
EvDefendersDone:
  EXX                     ; No more defenders: H'=0
  LD H,A                  ;
  EX AF,AF'               ;
  RET                     ;

; Yield pawn defenders
;
; Coroutine yield used by EvDefenderGen.
EvYieldPawnDefenders:
  EXX                     ; C'=count, H'=1; IX=continuation
  LD C,A                  ;
  LD H,$01                ;
  POP IX                  ;
  EX AF,AF'               ;
  RET                     ;

; Resume the defender coroutine
;
; Used by EvSee.
EvNextDefender:
  EX AF,AF'               ; Save the SEE state and resume at IX
  EXX                     ;
  XOR A                   ;
  JP (IX)                 ;

; Yield minor defenders
;
; Coroutine yield used by EvDefenderGen.
EvYieldMinorDefenders:
  RRA                     ; C'=count, H'=3; IX=continuation
  RRA                     ;
  POP IX                  ;
  EXX                     ;
  LD H,$03                ;
  LD C,A                  ;
  EX AF,AF'               ;
  RET                     ;

; Yield rook defenders
;
; Coroutine yield used by EvDefenderGen.
EvYieldRookDefenders:
  RRA                     ; C'=count, H'=5; IX=continuation
  RRA                     ;
  RRA                     ;
  RRA                     ;
  POP IX                  ;
  EXX                     ;
  LD H,$05                ;
  LD C,A                  ;
  EX AF,AF'               ;
  RET                     ;

; Yield queen defenders
;
; Coroutine yield used by EvDefenderGen.
EvYieldQueenDefenders:
  RLCA                    ; C'=count, H'=9; IX=continuation
  RLCA                    ;
  POP IX                  ;
  EXX                     ;
  LD H,$09                ;
  LD C,A                  ;
  EX AF,AF'               ;
  RET                     ;

; Yield the king as defender
;
; Coroutine yield used by EvDefenderGen. Costs E one point.
EvYieldKingDefender:
  DEC E                   ; E=E-1
  POP IX                  ; C'=1, H'=13; IX=continuation
  EXX                     ;
  LD H,$0D                ;
  LD C,A                  ;
  EX AF,AF'               ;
  RET                     ;

; Abort the evaluation: illegal position
;
; Used when the side to move attacks the enemy king or the kings touch. Clears
; the pin list and the attack bytes (+2..+5) of records $BE08..$BEF8 (not the
; white king's), restores SP from $BD3D and returns A=0 to the caller of
; Evaluate.
EvAbort:
  XOR A                   ; Empty the pin list
  LD ($BD79),A            ;
  LD B,$1F                ; Clear +2..+5 of 31 records
  LD DE,$0005             ;
  LD HL,$BE0A             ;
EvAbort_0:
  LD (HL),A               ;
  INC L                   ;
  LD (HL),A               ;
  INC L                   ;
  LD (HL),A               ;
  INC L                   ;
  LD (HL),A               ;
  ADD HL,DE               ;
  DJNZ EvAbort_0          ;
  LD SP,($BD3D)           ; Return 0 from Evaluate
  RET                     ;

; Queen attacks
;
; Used by Evaluate and EvPromotedPawn. Rook lines and diagonals with weight
; $40.
;
; A Square
EvQueen:
  LD B,A                  ; B=square; C'=$40
  EXX                     ;
  LD C,$40                ;
  CALL EvOrthogonals      ; Rook lines
  EXX                     ; Diagonals (EvDiagonals)
  JP EvDiagonals          ;

; Rook attacks
;
; Used by Evaluate and EvPromotedPawn.
;
; A Square
EvRook:
  LD B,A                  ; B=square; C'=$10
  EXX                     ;
  LD C,$10                ;

; Scan the rook lines of a queen or rook
;
; Used by EvQueen and EvRook. Horizontal rays do not count mobility; vertical
; rays add 1 to E for every square up to and including the first piece. The
; first piece hit is processed by EvHorizontalHit (horizontal) or
; EvVerticalSquare (vertical).
;
; B Square
; C' Weight
EvOrthogonals:
  LD E,$08                ; E' = $08 (pieces that move orthogonally)
  EXX                     ;
  LD L,B                  ; East
  XOR A                   ;
EvOrthogonals_0:
  INC L                   ;
  BIT 3,L                 ;
  JR NZ,EvOrthogonals_1   ;
  OR (HL)                 ;
  JR Z,EvOrthogonals_0    ;
  LD C,$01                ; Piece hit (C=+1)
  CALL EvHorizontalHit    ;
  XOR A                   ; West
EvOrthogonals_1:
  LD L,B                  ;
EvOrthogonals_2:
  DEC L                   ;
  BIT 3,L                 ;
  JR NZ,EvOrthogonals_3   ;
  OR (HL)                 ;
  JR Z,EvOrthogonals_2    ;
  LD C,$FF                ; Piece hit (C=-1)
  CALL EvHorizontalHit    ;
EvOrthogonals_3:
  LD C,$10                ; North (if not on rank 8)
  LD A,B                  ;
  ADD A,C                 ;
  CALL P,EvVerticalSquare ;
  LD C,$F0                ; South
  LD L,B                  ;
; This entry point is used by the routine at EvVerticalSquare.
EvVerticalStep:
  LD A,L                  ; Next square; stop off the board
  ADD A,C                 ;
  RET M                   ;

; Vertical ray: next square
;
; Part of EvOrthogonals.
EvVerticalSquare:
  LD L,A                  ; Count mobility
  INC E                   ;
  XOR A                   ; Empty: continue
  OR (HL)                 ;
  JR Z,EvVerticalStep     ;
  EXX                     ; L'=record+4 of the piece; enemy (EvEnemyHit)?
  LD L,A                  ;
  XOR B                   ;
  JP M,EvEnemyHit         ;
  LD A,C                  ; Friendly: defender count +weight
  ADD A,(HL)              ;
  LD (HL),A               ;
  SET 1,L                 ; Also an orthogonal mover?
  LD A,(HL)               ;
  AND E                   ;
  EXX                     ; No: done
  RET Z                   ;
  JP EvXrayChain          ; Yes: x-ray through it (EvXrayChain)

; Horizontal ray: first piece hit
;
; Part of EvOrthogonals. Enemy pieces go to EvEnemyHit; a friendly orthogonal
; mover is x-rayed to the next piece only (no mobility).
;
; A Piece code
; C Direction
EvHorizontalHit:
  EXX                     ; Enemy?
  LD L,A                  ;
  XOR B                   ;
  JP M,EvEnemyHit         ;
  LD A,C                  ; Friendly: defender count +weight
  ADD A,(HL)              ;
  LD (HL),A               ;
  SET 1,L                 ; Also an orthogonal mover?
  LD A,(HL)               ;
  AND E                   ;
  EXX                     ; No: done
  RET Z                   ;
EvHorizontalHit_0:
  LD A,L                  ; Look beyond it
  ADD A,C                 ;
  LD L,A                  ;
  AND D                   ;
  RET NZ                  ;
  OR (HL)                 ;
  JR Z,EvHorizontalHit_0  ;
  EXX                     ; Enemy beyond: x-ray attacker (EvXrayAttacker)
  LD L,A                  ;
  XOR B                   ;
  JP M,EvXrayAttacker     ;
  INC L                   ; Friendly beyond: x-ray defender (+5)
  LD A,C                  ;
  ADD A,(HL)              ;
  LD (HL),A               ;
  EXX                     ;
  RET                     ;

; Black knight
;
; Used by Evaluate. A knight on its back rank costs 3.
;
; A Square
EvBlackKnight:
  LD B,A                  ; On rank 8?
  OR $70                  ;
  CP B                    ;
  JP NZ,EvKnight          ;
; This entry point is used by the routine at EvWhiteKnight.
EvKnightBackRank:
  DEC E                   ; Yes: E=E-3
  DEC E                   ;
  DEC E                   ;
  JP EvKnight             ;

; White knight
;
; Used by Evaluate.
;
; A Square
EvWhiteKnight:
  LD B,A                  ; On rank 1: penalty (EvKnightBackRank)
  AND $70                 ;
  JR Z,EvKnightBackRank   ;
; This entry point is used by the routines at EvPromotedPawn and EvBlackKnight.
EvKnight:
  EXX                     ; C'=$04; E=E-1 (mobility counts target squares - 1)
  LD C,$04                ;
  EXX                     ;
  DEC E                   ;
; This entry point is used by the routine at EvUndoKnightPin.
EvKnightWalk:
  LD A,$0E                ; Upward targets +14, +18, +31, +33 (skipped if the
  ADD A,B                 ; first leaves the top of the board)
  JP M,EvWhiteKnight_0    ;
  LD L,A                  ;
  AND D                   ;
  CALL Z,EvKnightTarget   ;
  LD A,$12                ;
  ADD A,B                 ;
  LD L,A                  ;
  AND D                   ;
  CALL Z,EvKnightTarget   ;
  LD A,$1F                ;
  ADD A,B                 ;
  LD L,A                  ;
  AND D                   ;
  CALL Z,EvKnightTarget   ;
  LD A,$21                ;
  ADD A,B                 ;
  LD L,A                  ;
  AND D                   ;
  CALL Z,EvKnightTarget   ;
EvWhiteKnight_0:
  LD A,$F2                ; Downward targets -14, -18, -31, -33 (stops as soon
  ADD A,B                 ; as one leaves the bottom)
  RET M                   ;
  LD L,A                  ;
  AND D                   ;
  CALL Z,EvKnightTarget   ;
  LD A,$EE                ;
  ADD A,B                 ;
  LD L,A                  ;
  AND D                   ;
  CALL Z,EvKnightTarget   ;
  LD A,$E1                ;
  ADD A,B                 ;
  RET M                   ;
  LD L,A                  ;
  AND D                   ;
  CALL Z,EvKnightTarget   ;
  LD A,$DF                ;
  ADD A,B                 ;
  LD L,A                  ;
  AND D                   ;
  RET NZ                  ;

; Knight target square
;
; Part of EvWhiteKnight. Counts mobility and marks the piece found.
;
; L Target square
EvKnightTarget:
  INC E                   ; Count mobility; empty: done
  OR (HL)                 ;
  RET Z                   ;
  EXX                     ; L'=record+4; friendly?
  LD L,A                  ;
  XOR B                   ;
  JP P,EvKnightTarget_0   ;
  LD A,$78                ; Enemy king: check (EvKnightChecksKing)
  AND L                   ;
  JR Z,EvKnightChecksKing ;
  DEC L                   ; Enemy: L'=record+2
  DEC L                   ;
EvKnightTarget_0:
  LD A,C                  ; Add the weight
  ADD A,(HL)              ;
  LD (HL),A               ;
  EXX                     ;
  RET                     ;

; Knight attacks the enemy king
;
; First pass: abort. Second pass: flag the move as a check (bit 7 of IX+3); a
; first check marks the checking piece (+5 bit 1) and adds 2 to E, a second
; (double check) clears $BD4E and adds $14 to A'.
EvKnightChecksKing:
  BIT 4,B                 ; First pass: abort
  JP Z,EvAbort            ;
  SET 7,(IX+$03)          ; Flag check
  BIT 6,B                   ; Already a check?
  SET 6,B                   ;
  EXX                       ;
  JR NZ,EvKnightDoubleCheck ;
  LD L,B                  ; First check: mark the checking piece (+5 bit 1)
  LD L,(HL)               ;
  INC L                   ;
  INC H                   ;
  SET 1,(HL)              ;
  DEC H                   ;
  INC E                   ; E=E+2
  INC E                   ;
  RET                     ;
EvKnightDoubleCheck:
  LD ($BD4E),A            ; Double check: $BD4E=0, A'=A'+$14
  EX AF,AF'               ;
  ADD A,$14               ;
  EX AF,AF'               ;
  RET                     ;

; Slider attacks the enemy king
;
; As EvKnightChecksKing, then the ray carries on beyond the king (EvRayStep),
; counting mobility.
EvSliderChecksKing:
  BIT 4,B                 ; First pass: abort
  JP Z,EvAbort            ;
  SET 7,(IX+$03)          ; Flag check
  BIT 6,B                    ; Already a check?
  SET 6,B                    ;
  EXX                        ;
  JR NZ,EvSliderChecksKing_0 ;
  LD A,L                  ; First check: mark the checking piece (+5 bit 1)
  LD L,B                  ;
  LD L,(HL)               ;
  INC L                   ;
  INC H                   ;
  SET 1,(HL)              ;
  DEC H                   ;
  LD L,A                  ;
  INC E                   ; E=E+2; continue the ray
  INC E                   ;
  JP EvRayStep            ;
EvSliderChecksKing_0:
  LD ($BD4E),A            ; Double check: $BD4E=0, A'=A'+$14; continue the ray
  EX AF,AF'               ;
  ADD A,$14               ;
  EX AF,AF'               ;
  JP EvRayStep            ;

; White bishop
;
; Used by Evaluate. A bishop on its back rank costs 3.
;
; A Square
EvWhiteBishop:
  LD B,A                  ; On rank 1?
  AND $70                 ;
  JP NZ,EvBishop          ;
; This entry point is used by the routine at EvBlackBishop.
EvBishopBackRank:
  DEC E                   ; E=E-3
  DEC E                   ;
  DEC E                   ;
  JP EvBishop             ;

; Black bishop
;
; Used by Evaluate.
;
; A Square
EvBlackBishop:
  LD B,A                  ; On rank 8: penalty
  OR $70                  ;
  CP B                    ;
  JR Z,EvBishopBackRank   ;
; This entry point is used by the routines at EvPromotedPawn and EvWhiteBishop.
EvBishop:
  EXX                     ; C'=$04
  LD C,$04                ;
; This entry point is used by the routine at EvQueen.
EvDiagonals:
  LD E,$C4                ; E'=$C4 (pieces that move diagonally, and pawns)
  EXX                     ;
  LD C,$0F                ; Up-left (+15)
  LD A,B                  ;
  ADD A,C                 ;
  LD L,A                  ;
  AND D                   ;
  CALL Z,EvRaySquare      ;
  LD C,$11                ; Up-right (+17)
  LD A,B                  ;
  ADD A,C                 ;
  LD L,A                  ;
  AND D                   ;
  CALL Z,EvRaySquare      ;
  LD C,$EF                ; Down-right (-17)
  LD A,B                  ;
  ADD A,C                 ;
  LD L,A                  ;
  AND D                   ;
  CALL Z,EvRaySquare      ;
  LD C,$F1                ; Down-left (-15)
  LD L,B                  ;
; This entry point is used by the routines at EvSliderChecksKing and
; EvRaySquare.
EvRayStep:
  LD A,L                  ; Next square; stop off the board
  ADD A,C                 ;
  LD L,A                  ;
  AND D                   ;
  RET NZ                  ;

; Diagonal ray: next square and hits
;
; Part of EvDiagonals (also used after a king is passed). Every square up to
; and including the first piece adds 1 to E.
EvRaySquare:
  INC E                   ; Count mobility; empty: continue
  OR (HL)                 ;
  JR Z,EvRayStep          ;
  EXX                     ; L'=record+4; friendly (EvFriendlyHit)?
  LD L,A                  ;
  XOR B                   ;
  JP P,EvFriendlyHit      ;
; This entry point is used by the routines at EvVerticalSquare and
; EvHorizontalHit.
EvEnemyHit:
  LD A,$78                ; Enemy king (EvSliderChecksKing)?
  AND L                   ;
  JR Z,EvSliderChecksKing ;
  DEC L                   ; Attacker count +weight (record +2)
  DEC L                   ;
  LD A,C                  ;
  ADD A,(HL)              ;
  LD (HL),A               ;
  SET 2,L                 ; Enemy also moves along this line (record +6 AND E',
  LD A,(HL)               ; not a pawn)?
  AND E                   ;
  JR Z,EvShieldTest       ;
  JP M,EvShieldTest       ; No: look for what it shields (EvShieldTest)
  EXX                     ; Yes: look beyond it
EvRaySquare_0:
  LD A,L                  ;
  ADD A,C                 ;
  LD L,A                  ;
  AND D                   ;
  RET NZ                  ;
  OR (HL)                 ;
  JR Z,EvRaySquare_0      ;
  EXX                     ; D'=record+6 of the first piece; friendly beyond?
  LD D,L                  ;
  LD L,A                  ;
  XOR B                   ;
  JP P,EvXrayDefender     ;
  DEC L                   ; Enemy beyond: x-ray attacker (+3)
  LD A,C                  ;
  ADD A,(HL)              ;
  LD (HL),A               ;
  INC L                   ;
EvPinTest:
  INC L                   ; Piece beyond is a king (+6 bit 0): pin
  INC L                   ;
  LD A,(HL)               ;
  RRA                     ;
  JR C,EvRecordPin        ;
  RRA                     ; A queen (+6 bit 1): pin unless the scanning piece
  JR C,EvPinQueen         ; is a queen
  EXX                     ; Neither
  RET                     ;
EvFriendlyHit:
  LD A,C                  ; Friendly: defender count +weight
  ADD A,(HL)              ;
  LD (HL),A               ;
EvFriendlyHit2:
  SET 1,L                 ; Does it move along this line?
  LD A,(HL)               ;
  AND E                   ;
  EXX                     ; No: done
  RET Z                   ;
  JP M,EvPawnXray         ; A pawn: one-square x-ray (EvPawnXray)
; This entry point is used by the routine at EvVerticalSquare.
EvXrayChain:
  LD A,L                  ; Continue the ray, counting mobility
  ADD A,C                 ;
  LD L,A                  ;
  AND D                   ;
  RET NZ                  ;
  INC E                   ;
  OR (HL)                 ;
  JR Z,EvXrayChain        ;
  EXX                     ; Enemy: x-ray attacker (+3)
  LD L,A                  ;
  XOR B                   ;
  JP P,EvRaySquare_2      ;
; This entry point is used by the routine at EvHorizontalHit.
EvXrayAttacker:
  DEC L                   ; L'=record+3 (from +4)
EvRaySquare_1:
  LD A,C                  ; Add the weight
  ADD A,(HL)              ;
  LD (HL),A               ;
  EXX                     ;
  RET                     ;
EvRaySquare_2:
  INC L                   ; Friendly: x-ray defender (+5); and onwards if it
  LD A,C                  ; also moves this way
  ADD A,(HL)              ;
  LD (HL),A               ;
  DEC L                   ;
  JP EvFriendlyHit2       ;
EvXrayDefender:
  INC L                   ; L'=record+5
  JP EvRaySquare_1        ;
EvShieldTest:
  EXX                     ; Look beyond the enemy piece
EvRaySquare_3:
  LD A,L                  ;
  ADD A,C                 ;
  LD L,A                  ;
  AND D                   ;
  RET NZ                  ;
  OR (HL)                 ;
  JR Z,EvRaySquare_3      ;
  EXX                     ; D'=record+6 of the first piece; an enemy piece
  LD D,L                  ; beyond?
  LD L,A                  ;
  XOR B                   ;
  JP M,EvPinTest          ;
  EXX                     ; Friendly or nothing: done
  RET                     ;

; Record a pin
;
; Part of EvRaySquare. The pin list at $BD79 holds up to six (record,
; direction) pairs terminated by 0. A piece pinned twice gets direction 0. Adds
; 2 to E for a new pin (1 for a repeated one; 2 if the list is full).
EvPinQueen:
  BIT 6,C                 ; Pinned against a queen by a queen: E=E+2 only
  JR NZ,EvPinQueen_3      ; (EvPinQueen_3)
; This entry point is used by the routine at EvRaySquare.
EvRecordPin:
  RES 1,D                 ; D' = record base of the pinned piece
  RES 2,D                 ;
  LD HL,$BD79             ; Search the pin list
EvPinQueen_0:
  LD A,(HL)               ;
  OR A                    ;
  JR Z,EvPinQueen_1       ;
  INC L                   ; Next entry
  INC L                   ;
  CP D                    ;
  JP NZ,EvPinQueen_0      ;
  DEC L                   ; Already pinned: direction 0, E=E+1
  LD (HL),$00             ;
  INC H                   ;
  EXX                     ;
  INC E                   ;
  RET                     ;
EvPinQueen_1:
  LD A,L                  ; List full (6 entries)?
  CP $84                  ;
  JR NC,EvPinQueen_2      ;
  LD (HL),D               ; Append (record, direction) and a terminator
  INC L                   ;
  EXX                     ;
  LD A,C                  ;
  EXX                     ;
  LD (HL),A               ;
  INC L                   ;
  LD (HL),$00             ;
  SET 5,B                 ; Flag the pin list (B' bit 5)
EvPinQueen_2:
  INC H                   ; H'=$BE
EvPinQueen_3:
  EXX                     ; E=E+2
  INC E                   ;
  INC E                   ;
  RET                     ;

; Bishop or queen behind a friendly pawn
;
; Part of EvRaySquare. If the ray runs in the pawn's capturing direction, the
; piece on the square beyond the pawn (if any) gets an x-ray defence (+5) or
; x-ray attack (+3).
;
; A Pawn's record +6 AND $C4
; C Direction
EvPawnXray:
  RLA                     ; Ray runs in the pawn's direction?
  XOR C                   ;
  RET P                   ;
  LD A,L                  ; Next square (on the board, occupied)
  ADD A,C                 ;
  LD L,A                  ;
  AND D                   ;
  RET NZ                  ;
  OR (HL)                 ;
  RET Z                   ;
  EXX                     ; Friendly: +5, enemy: +3
  LD L,A                  ;
  INC L                   ;
  XOR B                   ;
  JP P,EvPawnXray_0       ;
  DEC L                   ;
  DEC L                   ;
EvPawnXray_0:
  LD A,C                  ;
  ADD A,(HL)              ;
  LD (HL),A               ;
  EXX                     ;
  RET                     ;

; Remove the attacks of pinned pieces
;
; Used by Evaluate when bit 5 of B' is set. For each (record, direction) in
; $BD79, subtracts the pinned piece's direct attacks in every direction except
; the pin line. E and D are preserved; B' is overwritten with the pinned
; piece's colour. Finally empties the list.
EvUndoPins:
  LD IY,$BD79             ; IY=pin list
  PUSH DE                 ;
  LD H,$BD                ;
  EXX                     ; L'=pinned piece's record
  LD L,(IY+$00)           ;
; This entry point is used by the routine at EvNextPin.
EvUndoPin:
  LD BC,EvNextPin         ; Return to EvNextPin afterwards
  PUSH BC                 ;
  LD A,L                  ; B'=colour; E'=square
  AND $80                 ;
  LD B,A                  ;
  LD E,(HL)               ;
  INC L                   ; Type AND $8E: 0 = pawn
  LD A,(HL)               ;
  AND $8E                 ;
  JR Z,EvUndoPawnPin      ;
  JP M,EvUndoBishopPin    ; Bishop (EvUndoBishopPin)
  CP $04                  ; Knight (EvUndoKnightPin)
  JR C,EvUndoKnightPin    ;
  JR Z,EvUndoRookPin      ; Rook (EvUndoRookPin)
  LD C,$C0                ; Queen: weight -$40 on rook lines and diagonals
  CALL EvUndoOrthogonals  ;
  JP EvUndoDiagonals      ;
; This entry point is used by the routine at EvUndoOrthogonals.
EvUndoPawnPin:
  BIT 7,B                 ; Pawn: B=square, C=+15 or -17 (left capture)
  LD A,E                  ;
  EXX                     ;
  LD B,A                  ;
  LD C,$0F                ;
  JR Z,EvUndoPins_0       ;
  LD C,$EF                ;
EvUndoPins_0:
  CALL EvUndoPawnCapture  ; Left capture, then right capture
  INC C                   ;
  INC C                   ;

; Undo one pawn capture direction
;
; Part of EvUndoPins. Skipped if the direction is along the pin line.
;
; B Square
; C Direction
EvUndoPawnCapture:
  LD A,(IY+$01)           ; Along the pin line: keep
  CP C                    ;
  RET Z                   ;
  NEG                     ;
  CP C                    ;
  RET Z                   ;
  LD A,C                  ; Piece on the target square?
  ADD A,B                 ;
  LD L,A                  ;
  XOR A                   ;
  OR (HL)                 ;
  RET Z                   ;
  EXX                      ; Friendly: defender count -1; enemy: attacker count
  LD L,A                   ; -1
  XOR B                    ;
  JP P,EvUndoPawnCapture_0 ;
  DEC L                    ;
  DEC L                    ;
EvUndoPawnCapture_0:
  DEC (HL)                 ;
  EXX                      ;
  RET                      ;

; Undo a pinned knight
;
; Part of EvUndoPins. Re-walks the knight with weight -4 (a pinned knight
; attacks nothing). B' bit 4 is set so a knight 'check' is flagged rather than
; aborting.
EvUndoKnightPin:
  LD C,$FC                ; C'=-4; B' bit 4 set
  SET 4,B                 ;
  LD A,E                  ; Re-walk the knight (EvKnightWalk)
  EXX                     ;
  LD D,$88                ;
  LD B,A                  ;
  JP EvKnightWalk         ;
; This entry point is used by the routine at EvUndoPins.
EvUndoRookPin:
  LD C,$F0                ; Rook: C'=-$10

; Undo rook-line attacks
;
; Part of EvUndoPins.
EvUndoOrthogonals:
  LD A,E                  ; B=square
  EXX                     ;
  LD C,$01                ; Horizontal
  LD B,A                  ;
  CALL EvUndoLine         ;
  LD C,$10                ; Vertical
  JP EvUndoLine           ;
; This entry point is used by the routine at EvUndoPins.
EvUndoBishopPin:
  AND $02                 ; Bishop type? (otherwise treat as a pawn)
  JR Z,EvUndoPawnPin      ;
  LD C,$FC                ; C'=-4
  LD A,E                  ;
  EXX                     ;
  LD B,A                  ;
; This entry point is used by the routine at EvUndoPins.
EvUndoDiagonals:
  LD C,$0F                ; Diagonal +15/-15
  CALL EvUndoLine         ;
  LD C,$11                ; Diagonal +17/-17

; Undo the attacks along one line
;
; Part of EvUndoPins. Skipped if the line is the pin line; otherwise both
; directions.
;
; C Direction
EvUndoLine:
  LD A,(IY+$01)           ; Along the pin line: keep
  CP C                    ;
  RET Z                   ;
  NEG                     ;
  CP C                    ;
  RET Z                   ;
  LD D,$88                ; Forward
  CALL EvUndoRay          ;
  XOR A                   ; Backward
  SUB C                   ;
  LD C,A                  ;

; Undo the first attack along a ray
;
; Part of EvUndoPins.
EvUndoRay:
  LD L,B                  ; Find the first piece
EvUndoRay_0:
  LD A,L                  ;
  ADD A,C                 ;
  LD L,A                  ;
  AND D                   ;
  RET NZ                  ;
  OR (HL)                 ;
  JR Z,EvUndoRay_0        ;
  EXX                     ; Friendly: +4 += C'; enemy: +2 += C'
  LD L,A                  ;
  XOR B                   ;
  JP P,EvUndoRay_1        ;
  DEC L                   ;
  DEC L                   ;
EvUndoRay_1:
  LD A,C                  ;
  ADD A,(HL)              ;
  LD (HL),A               ;
  EXX                     ;
  RET                     ;

; Next pin-list entry
;
; Return point for EvUndoPin.
EvNextPin:
  LD A,(IY+$02)           ; Another entry?
  OR A                    ;
  JR Z,EvNextPin_0        ;
  INC IY                  ; Yes: process it
  INC IY                  ;
  EXX                     ;
  LD L,A                  ;
  JP EvUndoPin            ;
EvNextPin_0:
  POP DE                  ; Done: restore DE, empty the list
  LD ($BD79),A            ;
  RET                     ;

; Unused
;
; Zero padding up to the start of the opening book at $9000.
  DEFS $D1

; Opening book
;
; A pre-order tree of 2685 9-bit entries (24165 bits, $9000-$9BCC), read by
; BOOK_BITS and walked by BOOK_PROBE. Entry n occupies bit-stream bits 9n to
; 9n+8 (most significant bit first); each DEFB line below holds 9 bytes, i.e.
; entries 8k to 8k+7, where k is the line number counting from 0.
;
; Entry layout, from the most significant bit: bit 8 'M' (on the first entry of
; a sibling list it raises that move's chance of being chosen from 1/2 to 3/4;
; on any later entry it stops the random choice before that entry, so it and
; all later siblings are never chosen, only followed when the opponent plays
; them); bit 7 = leaf (no stored continuation); bit 6 = more siblings follow;
; bits 0-5 = index of the move in the list produced by the move generator
; GENMOVES for that position (move = $B404+4*index). A non-leaf entry is
; followed immediately by the sibling list of its replies. The root list (entry
; 0) holds White's first moves: 1.e4, 1.d4, 1.c4, 1.Nf3, 1.b3 (M), 1.f4 (M).
;
; The decoded tree is in docs/arch/book-tree.txt (generated by
; tools/scripts/book_dump.py): 396 leaves, 123 entries with M set, maximum
; depth 31 plies.
BOOK_DATA:
  DEFB $26,$92,$69,$C4,$CA,$B0,$4C,$2E,$0D ; Entries 0-2684
  DEFB $0A,$16,$49,$E0,$90,$00,$34,$0E,$97 ;
  DEFB $13,$03,$01,$80,$A0,$22,$70,$B6,$4B ;
  DEFB $05,$94,$80,$00,$00,$80,$64,$12,$29 ;
  DEFB $4A,$8A,$00,$00,$60,$80,$51,$10,$4F ;
  DEFB $05,$82,$42,$40,$00,$00,$64,$12,$29 ;
  DEFB $4A,$C9,$81,$62,$20,$A0,$40,$10,$28 ;
  DEFB $0D,$08,$42,$02,$30,$30,$71,$00,$14 ;
  DEFB $26,$86,$05,$60,$A0,$20,$0C,$00,$92 ;
  DEFB $27,$86,$43,$28,$E2,$58,$64,$38,$0A ;
  DEFB $04,$24,$CC,$C1,$90,$C0,$08,$1C,$1E ;
  DEFB $00,$25,$C2,$21,$80,$90,$54,$00,$8B ;
  DEFB $03,$12,$90,$04,$C4,$C0,$14,$1A,$05 ;
  DEFB $40,$11,$2A,$C0,$F0,$B9,$24,$28,$53 ;
  DEFB $26,$87,$01,$05,$70,$00,$28,$48,$9B ;
  DEFB $05,$00,$00,$02,$40,$60,$19,$06,$51 ;
  DEFB $0E,$53,$81,$40,$40,$02,$04,$A4,$0A ;
  DEFB $07,$00,$00,$81,$40,$0A,$04,$00,$0A ;
  DEFB $05,$80,$02,$40,$81,$2A,$3C,$1E,$1D ;
  DEFB $2D,$08,$40,$00,$F0,$42,$00,$32,$0E ;
  DEFB $00,$20,$0A,$A5,$D2,$50,$7C,$16,$18 ;
  DEFB $0D,$08,$03,$E1,$30,$00,$01,$42,$5A ;
  DEFB $07,$86,$C2,$A1,$A0,$FA,$3E,$12,$1C ;
  DEFB $00,$A3,$8B,$E1,$31,$08,$38,$30,$9E ;
  DEFB $A7,$82,$80,$00,$B0,$D0,$48,$1A,$A0 ;
  DEFB $93,$86,$C2,$80,$E0,$52,$28,$2C,$5D ;
  DEFB $2C,$94,$03,$41,$50,$D8,$61,$16,$18 ;
  DEFB $0A,$08,$02,$A1,$E4,$7C,$74,$38,$09 ;
  DEFB $05,$01,$94,$95,$90,$50,$54,$3C,$00 ;
  DEFB $46,$D6,$81,$41,$20,$58,$8D,$0B,$5B ;
  DEFB $45,$57,$03,$62,$70,$68,$79,$1D,$1F ;
  DEFB $49,$94,$4B,$41,$A1,$10,$50,$2E,$17 ;
  DEFB $0E,$02,$C2,$A0,$04,$04,$50,$2E,$5F ;
  DEFB $09,$85,$12,$C4,$B0,$B8,$4D,$3A,$4C ;
  DEFB $4E,$03,$C2,$C1,$90,$90,$35,$1A,$55 ;
  DEFB $31,$11,$01,$A0,$F0,$AA,$48,$16,$14 ;
  DEFB $0A,$84,$82,$20,$84,$60,$50,$08,$0B ;
  DEFB $07,$95,$00,$80,$00,$00,$48,$46,$29 ;
  DEFB $4A,$18,$82,$22,$80,$81,$AC,$26,$2A ;
  DEFB $08,$09,$D0,$E1,$30,$78,$38,$02,$13 ;
  DEFB $08,$87,$10,$A6,$80,$00,$19,$30,$69 ;
  DEFB $0C,$08,$83,$22,$74,$B1,$70,$00,$1A ;
  DEFB $4A,$04,$80,$06,$80,$B8,$71,$36,$45 ;
  DEFB $0C,$09,$C2,$C1,$C0,$B8,$88,$08,$10 ;
  DEFB $0D,$83,$92,$60,$00,$C0,$8C,$2C,$18 ;
  DEFB $03,$84,$91,$A1,$22,$D1,$58,$36,$0B ;
  DEFB $05,$11,$82,$41,$80,$C0,$00,$1E,$1A ;
  DEFB $04,$20,$E0,$A9,$38,$C8,$88,$20,$97 ;
  DEFB $AE,$04,$C2,$88,$AA,$C8,$6C,$12,$0B ;
  DEFB $0F,$A1,$AB,$01,$40,$92,$26,$AC,$94 ;
  DEFB $8B,$A2,$C0,$C4,$92,$68,$20,$3A,$0A ;
  DEFB $0B,$81,$C2,$88,$52,$E1,$28,$1A,$90 ;
  DEFB $86,$83,$02,$28,$08,$1A,$54,$A2,$40 ;
  DEFB $08,$85,$41,$C0,$74,$A9,$30,$20,$00 ;
  DEFB $06,$84,$50,$E0,$D2,$88,$00,$1C,$0A ;
  DEFB $03,$25,$09,$C0,$00,$90,$48,$1A,$0F ;
  DEFB $05,$01,$11,$A5,$20,$00,$1C,$14,$11 ;
  DEFB $09,$85,$51,$20,$10,$68,$2C,$2C,$14 ;
  DEFB $03,$86,$80,$01,$24,$AD,$54,$30,$4B ;
  DEFB $43,$11,$13,$84,$10,$80,$1D,$00,$4D ;
  DEFB $07,$83,$92,$81,$20,$28,$64,$2C,$16 ;
  DEFB $04,$03,$40,$E1,$14,$A5,$01,$31,$41 ;
  DEFB $0A,$85,$00,$01,$20,$C8,$49,$17,$47 ;
  DEFB $09,$02,$42,$E0,$64,$7C,$2C,$18,$48 ;
  DEFB $48,$83,$13,$04,$E0,$B0,$4C,$2E,$50 ;
  DEFB $0A,$52,$43,$A1,$40,$20,$54,$4C,$12 ;
  DEFB $0D,$83,$83,$20,$55,$28,$58,$9E,$93 ;
  DEFB $33,$24,$E5,$00,$C1,$38,$38,$10,$8F ;
  DEFB $27,$06,$83,$40,$E2,$D2,$34,$1C,$89 ;
  DEFB $09,$15,$00,$28,$F2,$7A,$3A,$44,$10 ;
  DEFB $0A,$02,$82,$69,$18,$38,$4C,$0A,$98 ;
  DEFB $25,$01,$0B,$81,$60,$58,$10,$2C,$97 ;
  DEFB $0D,$84,$82,$61,$A0,$40,$54,$3C,$17 ;
  DEFB $42,$14,$C8,$A1,$80,$30,$5C,$22,$9F ;
  DEFB $06,$86,$00,$C1,$71,$10,$65,$30,$59 ;
  DEFB $07,$03,$D2,$B1,$60,$58,$74,$16,$1A ;
  DEFB $02,$08,$52,$24,$DA,$71,$2C,$8C,$53 ;
  DEFB $A3,$14,$C8,$04,$50,$18,$5C,$0C,$58 ;
  DEFB $09,$80,$0B,$24,$C0,$40,$60,$2C,$81 ;
  DEFB $2A,$86,$10,$C4,$80,$B8,$2C,$2E,$84 ;
  DEFB $88,$06,$01,$69,$50,$B0,$28,$BC,$90 ;
  DEFB $10,$02,$40,$A1,$70,$20,$5C,$38,$09 ;
  DEFB $0B,$02,$04,$81,$34,$D5,$18,$26,$1C ;
  DEFB $0A,$86,$02,$21,$60,$58,$5C,$40,$1F ;
  DEFB $42,$40,$0A,$C1,$80,$F8,$4C,$22,$01 ;
  DEFB $09,$04,$02,$88,$72,$90,$14,$AE,$0D ;
  DEFB $47,$43,$51,$E1,$30,$B8,$54,$AE,$11 ;
  DEFB $0A,$82,$C3,$81,$60,$D0,$70,$20,$12 ;
  DEFB $03,$A9,$03,$E1,$50,$E0,$10,$1E,$87 ;
  DEFB $29,$05,$0B,$A0,$B0,$F8,$68,$1A,$41 ;
  DEFB $09,$82,$80,$02,$35,$28,$68,$26,$12 ;
  DEFB $40,$18,$00,$C1,$F0,$B8,$44,$3A,$18 ;
  DEFB $00,$81,$C1,$C2,$24,$7C,$21,$02,$18 ;
  DEFB $23,$05,$02,$41,$00,$28,$74,$36,$19 ;
  DEFB $4A,$C4,$50,$E4,$80,$98,$4C,$22,$0D ;
  DEFB $45,$95,$8B,$40,$00,$28,$74,$24,$55 ;
  DEFB $08,$82,$02,$61,$C0,$00,$4D,$24,$06 ;
  DEFB $0C,$04,$42,$81,$44,$CC,$48,$08,$22 ;
  DEFB $12,$84,$C4,$00,$31,$00,$51,$2F,$49 ;
  DEFB $02,$92,$42,$81,$00,$C8,$31,$0C,$00 ;
  DEFB $0B,$81,$53,$10,$30,$B8,$2C,$10,$18 ;
  DEFB $02,$06,$43,$E1,$80,$00,$78,$3C,$25 ;
  DEFB $53,$16,$0A,$64,$90,$B8,$5C,$00,$0D ;
  DEFB $08,$A0,$23,$A1,$80,$62,$00,$AC,$1A ;
  DEFB $07,$04,$83,$41,$80,$E2,$24,$90,$13 ;
  DEFB $0A,$05,$C1,$40,$E0,$82,$30,$A8,$0C ;
  DEFB $0D,$03,$00,$C9,$48,$00,$30,$2C,$12 ;
  DEFB $09,$85,$C2,$E9,$72,$49,$00,$32,$11 ;
  DEFB $07,$05,$42,$E0,$D4,$18,$4C,$3A,$08 ;
  DEFB $01,$05,$C2,$00,$04,$DD,$6C,$2C,$1B ;
  DEFB $10,$82,$80,$01,$60,$60,$60,$38,$05 ;
  DEFB $43,$45,$C0,$C0,$D0,$B8,$64,$0E,$0E ;
  DEFB $52,$83,$0A,$64,$02,$38,$48,$3C,$12 ;
  DEFB $0A,$83,$D0,$05,$F0,$90,$34,$32,$0C ;
  DEFB $01,$06,$C0,$A1,$14,$84,$44,$28,$29 ;
  DEFB $09,$80,$C0,$E1,$54,$19,$4D,$28,$54 ;
  DEFB $0E,$81,$C1,$21,$20,$28,$20,$00,$0C ;
  DEFB $46,$01,$83,$E1,$60,$D0,$1C,$0E,$16 ;
  DEFB $43,$44,$02,$81,$44,$39,$58,$36,$08 ;
  DEFB $2B,$06,$C3,$C1,$60,$02,$32,$46,$9B ;
  DEFB $26,$84,$82,$A0,$00,$88,$20,$1E,$41 ;
  DEFB $4B,$01,$92,$C4,$82,$C0,$58,$00,$00 ;
  DEFB $0C,$82,$04,$01,$20,$48,$60,$26,$84 ;
  DEFB $89,$84,$C1,$48,$4A,$88,$00,$20,$18 ;
  DEFB $03,$80,$43,$01,$40,$78,$80,$1E,$92 ;
  DEFB $8C,$86,$83,$22,$00,$90,$00,$2E,$15 ;
  DEFB $06,$26,$08,$A4,$82,$D1,$08,$3A,$0D ;
  DEFB $00,$05,$51,$05,$60,$E8,$78,$4E,$07 ;
  DEFB $05,$82,$42,$89,$78,$E0,$74,$3E,$27 ;
  DEFB $07,$00,$42,$40,$54,$D9,$6C,$2C,$14 ;
  DEFB $0F,$03,$04,$A1,$10,$28,$54,$12,$84 ;
  DEFB $A0,$05,$83,$20,$90,$D0,$24,$40,$9A ;
  DEFB $8C,$81,$C3,$40,$90,$E8,$50,$0A,$07 ;
  DEFB $14,$06,$40,$09,$20,$89,$50,$B0,$1E ;
  DEFB $09,$03,$43,$A2,$01,$09,$30,$4C,$0F ;
  DEFB $13,$03,$D2,$C4,$40,$58,$74,$42,$08 ;
  DEFB $52,$42,$44,$C0,$F1,$30,$3D,$11,$06 ;
  DEFB $08,$80,$81,$40,$A0,$00,$7D,$40,$5C ;
  DEFB $0C,$90,$0A,$00,$60,$F0,$54,$10,$10 ;
  DEFB $06,$84,$82,$C0,$A5,$18,$18,$44,$1C ;
  DEFB $0F,$87,$C0,$C0,$C0,$B8,$28,$26,$0A ;
  DEFB $0A,$A0,$4C,$C1,$80,$98,$5C,$38,$0A ;
  DEFB $0B,$87,$C0,$01,$14,$55,$7C,$30,$24 ;
  DEFB $01,$00,$D2,$D1,$E0,$89,$1D,$02,$19 ;
  DEFB $00,$01,$C4,$C0,$D0,$18,$94,$34,$07 ;
  DEFB $44,$43,$D0,$C5,$60,$C9,$5C,$84,$1A ;
  DEFB $4A,$94,$82,$80,$70,$F8,$54,$28,$99 ;
  DEFB $24,$02,$80,$62,$25,$00,$10,$2E,$0A ;
  DEFB $47,$93,$81,$01,$F0,$98,$80,$30,$1A ;
  DEFB $00,$01,$C4,$80,$E4,$E4,$78,$B2,$18 ;
  DEFB $0C,$05,$11,$25,$81,$10,$20,$40,$1D ;
  DEFB $0A,$06,$41,$E1,$90,$AA,$14,$34,$0F ;
  DEFB $4C,$12,$02,$25,$84,$38,$1D,$16,$13 ;
  DEFB $2C,$00,$C3,$21,$94,$68,$44,$2E,$19 ;
  DEFB $11,$03,$83,$E9,$D2,$69,$58,$AE,$20 ;
  DEFB $06,$01,$43,$82,$90,$D1,$78,$20,$0E ;
  DEFB $47,$18,$C2,$00,$B0,$F8,$58,$1E,$00 ;
  DEFB $40,$46,$C1,$E0,$30,$E0,$44,$06,$19 ;
  DEFB $47,$43,$01,$81,$C0,$D0,$3D,$00,$4E ;
  DEFB $2A,$84,$02,$05,$60,$F0,$38,$1C,$00 ;
  DEFB $0B,$01,$11,$60,$10,$10,$58,$30,$0D ;
  DEFB $04,$02,$D1,$30,$C0,$08,$04,$14,$14 ;
  DEFB $15,$06,$83,$81,$71,$08,$0C,$50,$20 ;
  DEFB $4B,$41,$41,$80,$F0,$98,$69,$2C,$55 ;
  DEFB $0B,$13,$41,$A1,$20,$02,$24,$A2,$11 ;
  DEFB $05,$83,$80,$80,$04,$04,$70,$1A,$19 ;
  DEFB $0F,$96,$80,$E0,$00,$68,$01,$1E,$1B ;
  DEFB $03,$88,$44,$81,$90,$58,$30,$38,$1B ;
  DEFB $52,$D6,$01,$C0,$30,$E0,$7C,$2C,$1D ;
  DEFB $47,$45,$82,$E1,$F0,$09,$08,$1A,$0C ;
  DEFB $08,$88,$53,$22,$20,$B0,$54,$36,$1E ;
  DEFB $48,$92,$89,$A1,$A0,$B0,$6C,$28,$54 ;
  DEFB $07,$06,$40,$00,$E1,$18,$91,$23,$43 ;
  DEFB $0A,$85,$53,$51,$90,$B0,$51,$38,$0B ;
  DEFB $24,$04,$43,$80,$70,$60,$78,$22,$8A ;
  DEFB $8D,$02,$03,$41,$E0,$D0,$20,$26,$98 ;
  DEFB $23,$83,$43,$41,$70,$E9,$58,$48,$0F ;
  DEFB $10,$01,$00,$22,$A0,$BA,$02,$18,$07 ;
  DEFB $09,$86,$C0,$62,$90,$A0,$04,$30,$96 ;
  DEFB $2B,$05,$C9,$00,$B0,$21,$48,$A6,$98 ;
  DEFB $2D,$01,$C2,$20,$00,$02,$12,$4A,$12 ;
  DEFB $09,$87,$45,$08,$B8,$48,$68,$A6,$11 ;
  DEFB $00,$00,$02,$88,$90,$A0,$44,$00,$80 ;
  DEFB $8E,$A0,$63,$00,$70,$78,$44,$A8,$9E ;
  DEFB $0C,$07,$82,$E8,$82,$61,$58,$2C,$52 ;
  DEFB $2C,$86,$43,$64,$90,$A0,$58,$24,$00 ;
  DEFB $0F,$86,$41,$E0,$C4,$A8,$48,$3A,$04 ;
  DEFB $0B,$80,$12,$45,$20,$C8,$48,$0E,$16 ;
  DEFB $0E,$83,$03,$69,$A2,$81,$44,$2C,$17 ;
  DEFB $0B,$02,$80,$E0,$F4,$88,$58,$3A,$1B ;
  DEFB $04,$05,$45,$00,$90,$40,$01,$30,$1A ;
  DEFB $07,$05,$03,$01,$94,$51,$4C,$98,$5F ;
  DEFB $0E,$07,$09,$C1,$82,$82,$5C,$06,$17 ;
  DEFB $08,$23,$89,$E2,$02,$C0,$10,$24,$2B ;
  DEFB $4A,$86,$43,$61,$60,$E8,$3D,$1E,$1A ;
  DEFB $0F,$85,$D3,$A4,$F0,$E0,$7C,$18,$09 ;
  DEFB $0A,$82,$D3,$C5,$B0,$58,$60,$2C,$04 ;
  DEFB $08,$04,$11,$34,$90,$E8,$0C,$14,$00 ;
  DEFB $54,$D7,$83,$C0,$34,$1D,$10,$2A,$0F ;
  DEFB $03,$81,$01,$20,$55,$14,$60,$3A,$12 ;
  DEFB $08,$83,$52,$45,$22,$61,$1C,$4A,$13 ;
  DEFB $29,$00,$C3,$E0,$00,$D0,$5C,$3C,$0B ;
  DEFB $07,$27,$25,$69,$22,$50,$90,$40,$0E ;
  DEFB $06,$06,$41,$E8,$30,$D0,$68,$12,$11 ;
  DEFB $07,$26,$A4,$01,$21,$08,$58,$3C,$8D ;
  DEFB $8D,$05,$42,$81,$80,$CA,$28,$BE,$19 ;
  DEFB $2E,$04,$03,$20,$32,$72,$5A,$1E,$1B ;
  DEFB $12,$A3,$8A,$E1,$80,$28,$4C,$12,$A1 ;
  DEFB $22,$04,$04,$01,$51,$20,$3C,$28,$A1 ;
  DEFB $0F,$04,$43,$20,$F0,$72,$9A,$3C,$1B ;
  DEFB $07,$05,$0B,$28,$F0,$DA,$32,$2A,$16 ;
  DEFB $06,$84,$83,$21,$A0,$BA,$7C,$90,$56 ;
  DEFB $06,$14,$C2,$81,$52,$50,$50,$22,$64 ;
  DEFB $0D,$86,$C2,$02,$30,$68,$40,$14,$06 ;
  DEFB $00,$26,$82,$01,$70,$E0,$6D,$32,$4D ;
  DEFB $2E,$02,$42,$41,$34,$68,$40,$12,$1B ;
  DEFB $09,$80,$C1,$89,$30,$79,$60,$AA,$10 ;
  DEFB $08,$26,$03,$01,$30,$62,$08,$28,$0E ;
  DEFB $4C,$97,$82,$85,$D0,$70,$4D,$1C,$0E ;
  DEFB $46,$97,$C1,$04,$E0,$42,$20,$2A,$19 ;
  DEFB $46,$C4,$92,$84,$A0,$60,$48,$12,$9C ;
  DEFB $AA,$03,$02,$E1,$40,$9A,$46,$1C,$8C ;
  DEFB $21,$15,$C0,$65,$60,$79,$5C,$0C,$0B ;
  DEFB $06,$80,$03,$C1,$A0,$E0,$6D,$41,$0F ;
  DEFB $08,$03,$92,$85,$40,$41,$54,$14,$61 ;
  DEFB $09,$87,$42,$A1,$E0,$A0,$54,$2E,$23 ;
  DEFB $0D,$A7,$83,$C1,$54,$60,$4C,$06,$0D ;
  DEFB $07,$84,$82,$29,$70,$50,$14,$A6,$8B ;
  DEFB $08,$22,$E1,$40,$F0,$D2,$3C,$96,$17 ;
  DEFB $26,$15,$81,$A1,$D2,$8A,$88,$20,$17 ;
  DEFB $04,$A3,$81,$00,$50,$38,$1C,$30,$08 ;
  DEFB $45,$00,$C1,$45,$60,$C8,$64,$20,$0A ;
  DEFB $50,$44,$03,$26,$04,$D8,$60,$36,$14 ;
  DEFB $51,$10,$42,$C4,$D0,$98,$51,$40,$0F ;
  DEFB $0F,$03,$01,$C1,$A4,$CD,$40,$2C,$00 ;
  DEFB $09,$84,$0C,$41,$74,$E9,$68,$0C,$8C ;
  DEFB $08,$04,$10,$70,$A0,$B0,$28,$26,$1A ;
  DEFB $2D,$02,$11,$84,$A0,$40,$90,$00,$86 ;
  DEFB $31,$02,$03,$04,$04,$F0,$6D,$3C,$4C ;
  DEFB $04,$22,$02,$00,$80,$F8,$00,$08,$07 ;
  DEFB $53,$92,$C9,$75,$22,$89,$50,$28,$0F ;
  DEFB $07,$03,$41,$C0,$A0,$DA,$8C,$98,$0D ;
  DEFB $09,$06,$0B,$A1,$91,$08,$48,$3A,$1C ;
  DEFB $0E,$86,$03,$C9,$A0,$C0,$2C,$38,$21 ;
  DEFB $07,$05,$80,$08,$00,$78,$34,$1A,$59 ;
  DEFB $0E,$A3,$C3,$01,$80,$58,$70,$42,$0E ;
  DEFB $0B,$00,$10,$04,$A2,$61,$38,$14,$10 ;
  DEFB $0E,$A4,$02,$81,$70,$50,$0C,$22,$19 ;
  DEFB $08,$81,$C0,$61,$30,$68,$2D,$1C,$4F ;
  DEFB $03,$90,$C0,$E1,$A0,$98,$59,$1E,$58 ;
  DEFB $04,$04,$C1,$A0,$D0,$B0,$61,$2C,$1A ;
  DEFB $4D,$45,$00,$65,$41,$38,$48,$34,$0C ;
  DEFB $0C,$86,$04,$A1,$75,$18,$3C,$4C,$58 ;
  DEFB $08,$00,$40,$E0,$64,$D0,$34,$32,$5B ;
  DEFB $0A,$82,$D5,$E1,$A0,$E0,$59,$1A,$53 ;
  DEFB $A7,$93,$43,$21,$B0,$60,$70,$00,$17 ;
  DEFB $02,$24,$09,$E1,$A0,$48,$40,$2E,$00 ;
  DEFB $4A,$C4,$82,$A1,$50,$D0,$08,$2C,$17 ;
  DEFB $0D,$03,$D4,$24,$C0,$B0,$60,$32,$14 ;
  DEFB $49,$55,$82,$E1,$81,$0A,$46,$2A,$17 ;
  DEFB $07,$08,$04,$29,$20,$A5,$30,$A4,$0A ;
  DEFB $23,$87,$80,$01,$D0,$50,$2C,$28,$11 ;
  DEFB $4D,$83,$03,$C1,$51,$10,$6C,$28,$87 ;
  DEFB $0C,$85,$C3,$61,$20,$A0,$78,$34,$8D ;
  DEFB $0A,$06,$C1,$81,$64,$49,$30,$16,$17 ;
  DEFB $0B,$82,$03,$21,$E0,$72,$58,$12,$0B ;
  DEFB $03,$92,$4A,$81,$30,$60,$48,$32,$1C ;
  DEFB $05,$24,$08,$80,$F1,$40,$40,$1C,$93 ;
  DEFB $0D,$83,$83,$41,$21,$18,$50,$4A,$83 ;
  DEFB $23,$03,$12,$E5,$50,$62,$4C,$B4,$8C ;
  DEFB $0B,$03,$13,$04,$22,$91,$42,$98,$46 ;
  DEFB $2C,$15,$89,$C8,$60,$A9,$1D,$1E,$06 ;
  DEFB $48,$90,$01,$C1,$80,$E8,$68,$00,$5A ;
  DEFB $06,$A3,$C1,$E1,$C0,$60,$60,$36,$0F ;
  DEFB $40,$96,$4A,$A1,$90,$88,$38,$18,$19 ;
  DEFB $0F,$06,$42,$A1,$10,$92,$00,$1C,$0D ;
  DEFB $0E,$82,$C3,$61,$A1,$02,$7C,$9C,$15 ;
  DEFB $0E,$84,$52,$01,$B4,$C1,$4C,$0E,$10 ;
  DEFB $20,$05,$52,$45,$20,$A8,$58,$22,$9D ;
  DEFB $07,$85,$41,$21,$44,$41,$28,$3C,$0E ;
  DEFB $0D,$A6,$08,$21,$90,$EA,$00,$A4,$99 ;
  DEFB $21,$06,$42,$E8,$E0,$D0,$6C,$26,$8F ;
  DEFB $8A,$06,$02,$85,$10,$52,$1C,$32,$14 ;
  DEFB $0C,$07,$0B,$A8,$E3,$22,$38,$26,$8E ;
  DEFB $07,$D4,$49,$20,$30,$FA,$28,$38,$03 ;
  DEFB $06,$02,$80,$08,$00,$30,$1C,$06,$19 ;
  DEFB $00,$03,$11,$25,$22,$61,$04,$B4,$13 ;
  DEFB $2D,$00,$01,$E1,$CA,$01,$38,$3C,$10 ;
  DEFB $29,$A6,$8B,$81,$00,$F2,$40,$28,$13 ;
  DEFB $0B,$05,$41,$08,$D0,$60,$78,$10,$01 ;
  DEFB $4D,$98,$42,$C0,$F0,$E0,$4D,$1F,$20 ;
  DEFB $0D,$83,$00,$40,$A0,$10,$5C,$22,$1F ;
  DEFB $4B,$14,$40,$00,$B2,$C8,$88,$3A,$8C ;
  DEFB $0E,$83,$03,$A2,$14,$61,$88,$00,$0B ;
  DEFB $2E,$16,$93,$22,$24,$C9,$34,$34,$17 ;
  DEFB $03,$A0,$C3,$09,$41,$18,$00,$30,$19 ;
  DEFB $26,$86,$C3,$09,$00,$F0,$6C,$1C,$18 ;
  DEFB $50,$44,$82,$61,$F0,$00,$34,$16,$00 ;
  DEFB $0B,$88,$82,$62,$34,$10,$44,$AE,$0F ;
  DEFB $0C,$04,$03,$60,$B0,$A8,$00,$3A,$59 ;
  DEFB $40,$14,$D0,$00,$24,$01,$48,$12,$42 ;
  DEFB $0E,$01,$40,$02,$64,$51,$75,$00,$0A ;
  DEFB $40,$12,$41,$22,$04,$00,$28,$1E,$0E ;
  DEFB $07,$04,$91,$34,$F4,$0C,$69,$02,$4D ;
  DEFB $0A,$94,$01,$A1,$40,$C8,$50,$B0,$1C ;
  DEFB $2E,$83,$92,$06,$40,$72,$4C,$26,$0E ;
  DEFB $4E,$06,$C3,$80,$D0,$72,$5C,$1C,$12 ;
  DEFB $07,$83,$81,$E1,$80,$3A,$8A,$22,$15 ;
  DEFB $26,$A4,$C1,$81,$30,$62,$42,$92,$0F ;
  DEFB $03,$82,$4A,$81,$30,$60,$48,$32,$1C ;
  DEFB $05,$24,$0B,$60,$E0,$D0,$48,$46,$14 ;
  DEFB $12,$A0,$C0,$80,$F1,$40,$40,$1C,$93 ;
  DEFB $A6,$14,$10,$C4,$F4,$30,$35,$33,$06 ;
  DEFB $02,$82,$03,$01,$30,$C0,$44,$14,$12 ;
  DEFB $40,$D2,$42,$84,$C0,$50,$61,$2A,$0E ;
  DEFB $0B,$85,$13,$D0,$F2,$90,$0C,$34,$11 ;
  DEFB $05,$81,$02,$E0,$00,$00,$59,$20,$09 ;
  DEFB $01,$A1,$C9,$24,$D0,$19,$34,$94,$49 ;
  DEFB $2C,$01,$C1,$41,$D0,$80,$2C,$0A,$9E ;
  DEFB $0B,$01,$C0,$20,$00,$A2,$12,$2E,$0D ;
  DEFB $08,$85,$83,$09,$A0,$B1,$58,$22,$14 ;
  DEFB $02,$26,$C8,$C0,$40,$00,$48,$06,$00 ;
  DEFB $4D,$84,$D1,$81,$52,$52,$70,$2C,$11 ;
  DEFB $42,$12,$48,$C0,$50,$20,$14,$28,$13 ;
  DEFB $0B,$25,$40,$60,$40,$A8,$54,$08,$04 ;
  DEFB $09,$04,$80,$80,$44,$A0,$08,$06,$10 ;
  DEFB $09,$95,$03,$20,$E0,$C8,$4C,$16,$0E ;
  DEFB $03,$86,$D4,$41,$60,$E0,$6C,$34,$17 ;
  DEFB $08,$00,$C2,$81,$E0,$B8,$65,$20,$43 ;
  DEFB $25,$83,$4A,$81,$10,$58,$54,$1C,$0C ;
  DEFB $02,$02,$C4,$61,$74,$E9,$44,$1A,$0D ;
  DEFB $01,$22,$62,$68,$52,$10,$48,$24,$01 ;
  DEFB $00,$80,$00,$01,$10,$90,$21,$39,$09 ;
  DEFB $29,$23,$41,$48,$DA,$31,$34,$00,$8B ;
  DEFB $05,$80,$11,$70,$F0,$59,$10,$16,$11 ;
  DEFB $43,$83,$41,$60,$F4,$38             ;

; Unused
;
; Data after the end of the book tree. It is never read: every walk through the
; book stays within entries 0-2684 (bytes $9000-$9BCC). The first 52 bytes do
; not parse as a continuation of the tree (probably left over from
; development).
  DEFB $40,$00,$48,$06,$00,$4D,$84,$D1,$81,$52,$52,$70,$2C,$11,$42,$12 ; Stale data
  DEFB $48,$C0,$50,$20,$14,$28,$13,$0B,$25,$40,$60,$40,$A8,$54,$08,$04 ;
  DEFB $09,$04,$80,$80,$44,$A0,$08,$06,$10,$09,$95,$03,$20,$E0,$C8,$4C ;
  DEFB $16,$0E,$03,$EF                                                 ;
; From here to the end the bytes follow the repeating pattern $FF,$FF,$01,$01
; (a typical power-on RAM pattern, captured when the tape was mastered), apart
; from 18 isolated bytes that differ (e.g. $9C10=$EB, $9C20=$B3, $9E00=$DB).
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$EB ; Uninitialised
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$B3 ; memory
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$D3 ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$97 ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$77 ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$6F ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$05,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$DB ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FB,$FF,$01,$01,$87 ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$9F ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$8B ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$0F ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$B3 ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$57 ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$05,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$05,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FB,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF ;
  DEFB $FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01,$FF,$FF,$01,$01     ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $F3,$0D,$CE,$0B,$E3,$50,$CE,$0B
  DEFB $E4,$50,$1D,$17,$DC,$0A,$CE,$0B
  DEFB $E7,$50,$1A,$17,$DC,$0A,$D7,$18
  DEFB $38,$00,$38,$00,$0D,$19,$DB,$02
  DEFB $4D,$00,$34,$57,$CC,$00,$33,$57
  DEFB $8C,$08,$5C,$0E,$00,$47,$C0,$57
  DEFB $71,$0E,$F3,$0D,$21,$17,$C6,$1E
  DEFB $FF,$5E,$76,$1B,$03,$13,$00,$3E
  DEFB $00,$3C,$42,$42,$7E,$42,$42,$00
  DEFB $00,$7C,$42,$7C,$42,$42,$7C,$00
  DEFB $00,$3C,$42,$40,$40,$42,$3C,$00
  DEFB $00,$78,$44,$42,$42,$44,$78,$00
  DEFB $00,$7E,$40,$7C,$40,$40,$7E,$00
  DEFB $00,$7E,$40,$7C,$40,$40,$40,$00
  DEFB $00,$3C,$42,$40,$4E,$42,$3C,$00
  DEFB $00,$42,$42,$7E,$42,$42,$42,$00
  DEFB $00,$3E,$08,$08,$08,$08,$3E,$00
  DEFB $00,$02,$02,$02,$42,$42,$3C,$00
  DEFB $00,$44,$48,$70,$48,$44,$42,$00
  DEFB $00,$40,$40,$40,$40,$40,$7E,$00
  DEFB $00,$42,$66,$5A,$42,$42,$42,$00
  DEFB $00,$42,$62,$52,$4A,$46,$42,$00
  DEFB $00,$3C,$42,$42,$42,$42,$3C,$00
  DEFB $00,$7C,$42,$42,$7C,$40,$40,$00
  DEFB $00,$3C,$42,$42,$52,$4A,$3C,$00
  DEFB $00,$7C,$42,$42,$7C,$44,$42,$00
  DEFB $00,$3C,$40,$3C,$02,$42,$3C,$00
  DEFB $00,$FE,$10,$10,$10,$10,$10,$00
  DEFB $00,$42,$42,$42,$42,$42,$3C,$00


; Search subsystem ($7B96-$80A6). See docs/arch/30-search.md.
;
; Conventions used in comments:
;   p        current ply ($BCA9); the root list is ply 1
;   D        full-width depth ($BCAA)
;   V(q)     node value / alpha of ply q, stored at $BCA0+q-1 (V(0) at $BC9F)
;   slot(q)  word at $BCA9+2q: address of the header of ply q's move list
;   hdr      4-byte list header: +0 $FF, +1 count, +2 tried/killer score, +3 flags
;            (flags: b7 side to move in check, b6 killer searched, b5 moves
;            scored, b0 copied from the move leading here)
;   move     4-byte entry: +0 score ($FF unscored, 0 done/pruned), +1 from,
;            +2 to, +3 flags
;   killer   $BC91+2(q-1): from,to of the best/refuting move found at ply q
;   curmove  $BC83+2(q-1): from,to of the move being searched at ply q (q>=2)
@ $7B96 label=S_SCOREMOVES
c $7B96 Score every unscored move in a list by make/evaluate/unmake
D $7B96 Each entry whose score byte is $FF is made, evaluated with #R$8400 and unmade; the evaluation (0 = illegal) becomes its score. The best score is kept in $BD19 and its entry in $BD1A; ties go to the later entry (>= comparison).
R $7B96 HL List header+3
R $7B96 E Number of moves in the list
R $7B96 O:$BD19 Best score (0 if no legal move)
R $7B96 O:$BD1A Address of the best entry
 $7B96 Point HL at the first move entry
 $7B97 IX=first move entry
 $7B9A Best score so far = 0
 $7B9E Loop counter = count+1 (pre-decremented below)
@ $7BA3 label=S_SCORE_LOOP
 $7BA3 Count down the moves
 $7BA7 Return when all moves have been visited
 $7BA8 Score byte of this move
 $7BAB Is it $FF (unscored)?
 $7BAC Skip moves already scored, searched or pruned
 $7BAE Make the move
 $7BB1 Evaluate the resulting position (0 = illegal)
 $7BB4 Store the evaluation as the move's score
 $7BB7 Compare with the best score so far
 $7BBB Lower: keep the old best
 $7BBD New best (or equal): record score
 $7BBE ...and the entry address
@ $7BC2 label=S_SCORE_UNMAKE
 $7BC2 Unmake the move
@ $7BC5 label=S_SCORE_NEXT
 $7BC5 Advance IX to the next entry
 $7BCA Loop
@ $7BCD label=S_FINDMOVE
c $7BCD Find a move in a list by its squares
D $7BCD Scans B entries starting with the entry after the one HL points into. A is compared with the to-square (+2) and A' with the from-square (+1).
R $7BCD HL Address of byte +2 of the entry before the first to test
R $7BCD B Number of entries to test
R $7BCD A To-square
R $7BCD A' From-square
R $7BCD O:F Carry clear and Z set if found; carry set if not found
R $7BCD O:HL Found: byte +1 of the matching entry. Not found: byte +2 of the last entry tested
 $7BCD Entry stride
@ $7BD0 label=S_FIND_LOOP
 $7BD0 Next entry's to-square
 $7BD1 Does the to-square match?
 $7BD2 Yes: check the from-square
@ $7BD4 label=S_FIND_NEXT
 $7BD4 Loop over B entries
 $7BD6 Not found
 $7BD7 Return with carry set
@ $7BD8 label=S_FIND_CHKFROM
 $7BD8 A=from-square
 $7BD9 Point at byte +1
 $7BDA Does the from-square match?
 $7BDB Yes: return with HL at byte +1
 $7BDC Restore HL to byte +2
 $7BDD A=to-square again
 $7BDE Continue the scan
@ $7BE1 label=S_THINK
c $7BE1 Think: compute the computer's move
D $7BE1 Calls the pre-search set-up #R$7810, then one search pass (#R$7BF1). Levels whose search parameter $BCBD is 5-7 set $BD6E during the first pass, which makes a second pass run here.
R $7BE1 O:$BD29 Address of the chosen root move entry
R $7BE1 O:F Carry set if there is no legal move (via #R$7BEE)
 $7BE1 Pre-search set-up (phase flags, material balance, etc.)
@ $7BE4 label=S_THINK_PASS
 $7BE4 Run one search pass
 $7BE7 Is a second pass pending?
 $7BEB Yes: run it
 $7BED Done
@ $7BEE label=S_THINK_NOMOVE
 $7BEE No legal move: discard the return address into #R$7BE1...
 $7BEF ...and return to its caller with carry set
 $7BF0 Return
@ $7BF1 label=S_PASS
c $7BF1 One search pass from the root
D $7BF1 Initialises the per-search tables, generates and statically scores the root moves, probes the opening book, sets the depth and pruning parameters from the level, applies next-best exclusions and the repetition rule, then enters the search loop at the best statically-scored root move. The search loop exits by returning to #R$7BE4.
R $7BF1 O:$BD29 Address of the chosen root move entry
 $7BF1 IX=root "move" record (last game move)
 $7BF5 Killer table $BC91-$BC9D
 $7BF8 Fill with $FF (no killer)
 $7BFA Shortest mate ply found so far = $FF
 $7BFD 13 bytes
@ $7BFF label=S_PASS_FILLFF
 $7BFF Fill the killer table
 $7C00 Next byte
 $7C01 Loop
 $7C03 A=0
 $7C04 Incremental material balance = 0
 $7C07 Value table V(0)..V(8) at $BC9F-$BCA7
 $7C0A 9 bytes
@ $7C0C label=S_PASS_FILL0
 $7C0C Zero the value table (V(1)=0 is -infinity)
 $7C0D Next byte
 $7C0E Loop
 $7C10 Generate the root moves (ply 1, list at $B400)
 $7C13 Mark the root list as scored
 $7C15 Score every root move statically
 $7C18 Next-best mode?
 $7C1B Yes: skip the opening book
 $7C1E Probe the opening book
 $7C21 NZ: no book move, so search
 $7C23 Book move found: check the keyboard
 $7C26 No key: return with the book move in $BD29
 $7C27 Key pressed: leave demo mode (#R$7562) and return with the book move
@ $7C2A label=S_PASS_SEARCH
 $7C2A Best static root score
 $7C2D Zero means no legal move
 $7C2E No legal root move: return carry set
 $7C31 D=best static root score
 $7C32 Second pass of a two-pass level?
 $7C35 No: first pass
 $7C38 Second pass: HL=first pass's chosen move
 $7C3B Give it score $FD so it is searched first
 $7C3D It is also the static best
 $7C40 Clear the second-pass flag
 $7C44 A=search parameter of the level
 $7C47 Set the parameters
@ $7C49 label=S_PASS_FIRST
 $7C49 First pass: the static best move...
 $7C4C ...is the move to play until the search finds better
 $7C4F A=search parameter of the level (0-7)
 $7C52 Parameters 5-7 (Levels 6-8, P3)?
 $7C54 No: one pass with this parameter
 $7C56 Yes: first pass uses parameter 1 (as Level 2)...
 $7C58 ...and flag that a second pass will follow
@ $7C5B label=S_PASS_PARAMS
 $7C5B Threat-extension switch $BDF6...
 $7C5E ...defaults to 0 (off)
 $7C60 Pruning margin byte = parameter for now
 $7C63 Parameter bit 1 set (2, 3, 6, 7)?
 $7C65 No: extensions stay off
 $7C67 Yes: enable threat extensions ($BDF6=parameter)
 $7C68 Parameter bit 0 set too (3, 7)?
 $7C6A No: keep forward pruning
 $7C6C Yes: set bit 7 of $BD09...
 $7C6F ...which disables all forward pruning
@ $7C71 label=S_PASS_DEPTH
 $7C71 Full-width depth D...
 $7C74 ...is 1 for parameter 0
 $7C76 Parameter 0?
 $7C77 Yes: D=1
 $7C79 D=2
 $7C7A Parameters 1-3?
 $7C7C Yes: D=2
 $7C7E D=3...
 $7C80 ...for parameter 4
 $7C82 D=4 for parameters 5-7
@ $7C83 label=S_PASS_MARGIN
 $7C83 Default margin base 7 (used when in check)
 $7C85 Forward pruning disabled?
 $7C88 Bit 7 into carry
 $7C89 Yes: leave $BD09 as is
 $7C8B A=best static root score
 $7C8C Root list header flags
 $7C8F Side to move in check?
 $7C91 Yes: margin = 7+2
 $7C93 Prune weak root moves; D=2*count minus moves below best-9
 $7C96 D=D/4...
 $7C98 ...
 $7C9A ...-1...
 $7C9B .../2 (all unsigned)
 $7C9D Base 11...
 $7C9F ...for deep endgame ($BD2D bit 4)
 $7CA2 Bit 4 set?
 $7CA4 Yes: base 11
 $7CA6 Base 10
 $7CA7 Phase bits >> 1
 $7CA9 Exactly bit 1 (past move 8, no endgame bit)?
 $7CAA No: base 10
 $7CAC Middlegame: base 8
 $7CAD ...
@ $7CAE label=S_MARGIN_LOOP
 $7CAE Count D down...
 $7CAF ...until it goes negative...
 $7CB2 ...decrementing the base each time (stops at 0)
@ $7CB4 label=S_MARGIN_SET
 $7CB4 Margin = base + 2
 $7CB6 ...
 $7CB7 Store the pruning margin
@ $7CBA label=S_PASS_EXCLUDE
 $7CBA Next-best exclusion list (from,to pairs, $FF-terminated)
@ $7CBD label=S_EXCL_LOOP
 $7CBD From-square of the next pair
 $7CBE End of list?
 $7CC0 Yes: done
 $7CC2 Point at the to-square
 $7CC3 A'=from-square
 $7CC4 A=to-square
 $7CC5 Next pair
 $7CC6 Save the list pointer
 $7CC7 Root list header+1
 $7CCA B=number of root moves
 $7CCB HL=header+2
 $7CCC Find the move (assumed present: see 30-search.md)
 $7CCF Point at its score byte
 $7CD0 Exclude it (score 0)
 $7CD2 Restore the list pointer
 $7CD3 Next pair
@ $7CD5 label=S_PASS_FIRSTMOVE
 $7CD5 Root list header+3
 $7CD8 Pick the best-scored remaining root move
 $7CDB Odd E: none left (every move excluded)
 $7CDD Found one: continue
 $7CDF Print the message
T $7CE2,14 "*NO MORE MOVES"
B $7CF0,1 Last character (bit 7 set)
 $7CF1 Beep
B $7CF4,2 Inline arguments: duration, pitch
 $7CF6 Clear the exclusion list
 $7CF9 Clear the message line
 $7CFC Discard the return address into #R$7BE1
 $7CFD Think again from scratch without exclusions
@ $7D00 label=S_PASS_REPCHK
 $7D00 $BD1A=first root move to search
 $7D04 Consecutive reversing-move counter
 $7D07 C=counter
 $7D08 Fewer than 2?
 $7D0A Yes: start searching the first root move
 $7D0D L=to, H=from of the move that undoes our last move
 $7D10 A'=from-square
 $7D11 ...
 $7D12 A=to-square
 $7D13 Root list header+1
 $7D16 B=number of root moves
 $7D17 HL=header+2
 $7D18 Find the repeating move
 $7D1B Point at its score byte
 $7D1C Already excluded?
 $7D1D ...
 $7D1E Yes: search normally
 $7D21 Take it out of the move ordering
 $7D23 Draw value: material term $BD2E, sign by side to move
 $7D26 Bit 0 into carry
 $7D27 A=$BD2E
 $7D2A Side bit clear: keep the sign
 $7D2C Negate
@ $7D2E label=S_REP_DRAWVAL
 $7D2E Draw value = +-$BD2E + $7E
 $7D30 Counter is 4 or 5?
 $7D32 No
 $7D34 Yes: draw is 8 points less attractive
@ $7D36 label=S_REP_SET
 $7D36 Root alpha V(1)=draw value
 $7D39 The repeating move is the current best root move
 $7D3C Record it in $BD29 and start the search loop
@ $7D3F label=S_UNUSED_7D3F
c $7D3F Unused
D $7D3F Not referenced from anywhere.
 $7D3F Store A in V(1)
 $7D42 Return
@ $7D43 label=S_NODE
c $7D43 Enter a new node: generate its moves and try the killer move
D $7D43 Reached by jumping from #R$7E0A after a move has been made and the ply incremented. #R$78BA polls the keyboard (unless the abort flag is already set) and falls into the move generator #R$78CE. If the move leading here has flag bit 2 set, the recapture on its to-square is tried first (#R$802B); otherwise, unless the side to move is in check, the killer move for this ply is tried first.
R $7D43 IX Entry of the move that led to this node
 $7D43 Poll keyboard; generate the moves for ply p
 $7D46 E=number of moves
 $7D47 Any?
 $7D48 No: go straight to the move loop
 $7D4A A=p
 $7D4D B=number of moves
 $7D4E Did the last move threaten a recapture (flag bit 2)?
 $7D52 Yes: try the recapture first
 $7D55 Side to move in check?
 $7D57 Yes: no killer
 $7D59 A=p-1
 $7D5A Killer table
 $7D5D A=2(p-1)
 $7D5E ...
 $7D5F DE=killer(p)
 $7D60 From-square of the killer
 $7D61 Bit 7 set means no killer
 $7D62 No killer: go to the move loop
 $7D65 Point at its to-square
 $7D66 A'=from-square
 $7D67 A=to-square
 $7D68 HL=header+2
 $7D69 Is the killer in this list?
 $7D6C No: go to the move loop
 $7D6E Point at its score byte
 $7D6F Mark it searched
 $7D71 IX=killer entry
 $7D72 ...
 $7D74 Make the killer move
@ $7D77 label=S_NODE_EVAL
 $7D77 Evaluate the position after the move
 $7D7A Illegal?
 $7D7B Yes: unmake and go to the move loop
 $7D7D C=evaluation
 $7D7E A'=evaluation
 $7D7F A=D
 $7D82 ...
 $7D83 ...
 $7D84 B=p
 $7D85 Beyond the full-width depth?
 $7D86 Yes: treat as a selective node
 $7D89 At the depth (D=p): futility test, may fail high
 $7D8C HL=header+3 of this ply's list
 $7D8F Mark the killer as searched
 $7D91 A=evaluation
 $7D92 HL=header+2
 $7D93 Record the killer's evaluation in the header
 $7D94 Move flag bit 1 (threat)?
 $7D98 No: search the killer now
 $7D9B Capture?
 $7D9F Yes: search the killer now
 $7DA2 Quiet threat: give it its evaluation as score; it is ordered later
@ $7DA5 label=S_NODE_UNDO
 $7DA5 Unmake it
@ $7DA8 label=S_NEXTMOVE
c $7DA8 Choose the next move at the current node
D $7DA8 At plies up to the full-width depth: the first visit scores every move statically (#R$7B96), detects mate/stalemate, applies forward pruning (#R$805F) and searches the static best; later visits take the highest-scored remaining move (#R$8015). Beyond the depth, control passes to the selective move loop at #R$7EE4.
 $7DA8 A=D
 $7DAB ...
 $7DAC HL=$BCA9
 $7DAD Compare D with p
 $7DAE p>D: selective node
 $7DB1 B=p, HL=header+3, E=count, C=header+2
 $7DB4 Moves already scored?
 $7DB6 Yes: take the next best
 $7DB9 Mark the list scored
 $7DBB Save HL
 $7DBC Score every unscored move
 $7DBF Restore HL
 $7DC0 Best static score
 $7DC3 Zero: no legal move (except perhaps the killer)
 $7DC4 Handle mate/stalemate
 $7DC7 In check?
 $7DC9 Yes: no pruning, search the static best
 $7DCC Forward-prune weak moves (A=best static score)
@ $7DCF label=S_PLAYBEST
 $7DCF IX=static best entry
 $7DD3 Mark it searched
 $7DD7 Make it and descend
@ $7DDA label=S_NEXT_SCORED
 $7DDA In check?
 $7DDC Yes: next move without recording it
 $7DDF Pick the highest-scored remaining move
 $7DE2 Odd E: none left
 $7DE4 Return to the parent
 $7DE6 IX=chosen entry
 $7DE7 ...
 $7DE9 Mark it searched
 $7DEA ...
@ $7DEB label=S_DESCEND
 $7DEB Make the move
@ $7DEE label=S_DESCEND_MADE
 $7DEE A=p
 $7DF1 p-1
 $7DF2 Root: record the root move instead
 $7DF4 2(p-1)
 $7DF5 Current-move table
 $7DF8 ...
 $7DF9 HL=curmove(p)
 $7DFA Record the from-square...
 $7DFD ...
 $7DFE ...
 $7DFF ...and the to-square
 $7E02 ...
 $7E03 Descend
@ $7E06 label=S_DESCEND_ROOT
 $7E06 $BD2B=root move being searched
@ $7E0A label=S_DESCEND_PLY
 $7E0A Flip the side to move
 $7E0D ...
 $7E0F ...
 $7E12 Ply counter
 $7E15 A=p
 $7E16 p=p+1
 $7E17 A=p-2
 $7E18 ...
 $7E19 Value table
 $7E1C ...
 $7E1D HL=$BCA0+p-2 = V(p-1)
 $7E1E A=V(p-1)
 $7E1F ...
 $7E20 HL=$BCA0+p = V(p+1)
 $7E21 The child starts with V(p+1)=V(p-1) (its alpha)
 $7E22 Enter the new node
@ $7E25 label=S_RETURN
c $7E25 Return from a node to its parent and back up the value
D $7E25 Decrements the ply and unmakes the move that led to the finished node. If the abort flag ($BD4C bit 7) is set, keeps unwinding to the root without comparing values. Leaving ply 1 exits the search pass (RET to #R$7BE4). Otherwise the child's value is negated and compared: if it reaches the parent's beta it is a fail-high (#R$7E79); if it improves alpha, alpha is updated and the move becomes the killer for its ply (or the best root move at ply 1).
 $7E25 A=p-1
 $7E28 ...
 $7E29 Leaving the root: the search pass is over
 $7E2A Ply p-1
 $7E2D Unmake the move that led to the finished node
 $7E30 Flip the side to move
 $7E33 ...
 $7E35 ...
 $7E38 Abort flag (key pressed or move list full)?
 $7E3B Bit 7 into carry
 $7E3C Set: keep unwinding
 $7E3E A=p (the parent)
 $7E41 Value table
 $7E44 ...
 $7E45 HL=$BCA0+p = V(p+1), the child's value
 $7E46 A=V(p+1)
 $7E47 Negate: value for the side to move at p
@ $7E49 label=S_BACKUP
 $7E49 HL=V(p-1) (minus beta of ply p)
 $7E4A ...
 $7E4B ~A = value-1 in the parent's sign
 $7E4C value >= beta?
 $7E4D Yes: fail high at ply p
 $7E4F A=value again
 $7E50 HL=V(p), alpha
 $7E51 Compare with alpha
 $7E52 Lower: no improvement
 $7E55 Equal: no improvement
 $7E58 New alpha
 $7E59 A=p-1
 $7E5C ...
 $7E5D Root: new best root move
@ $7E5F label=S_KILLER
 $7E5F A=2(p-1)
 $7E60 B=2(p-1)
 $7E61 Killer table
 $7E64 ...
 $7E65 HL=killer(p)
 $7E66 Current-move table
 $7E69 ...
 $7E6A ...
 $7E6B DE=curmove(p)
 $7E6C From-square
 $7E6D Bit 7 set (not recorded, e.g. in-check node)?
 $7E6E Yes: no killer update
 $7E71 Killer from-square
 $7E72 ...
 $7E73 ...
 $7E74 Killer to-square
 $7E75 ...
 $7E76 Continue with the next move at this ply
@ $7E79 label=S_FAILHIGH
 $7E79 Fail high: unmake the move that led to this node
 $7E7C ...
 $7E7F Back to the parent's ply
 $7E80 Flip the side to move
 $7E83 ...
 $7E85 ...
 $7E88 A=new ply
 $7E89 The refutation becomes the killer of the node that failed high
@ $7E8C label=S_SETBEST
c $7E8C Record the best root move
D $7E8C Copies the root move being searched ($BD2B) to $BD29, the move to play. Also used as an exit: reached by JR from #R$7EA1 when a mate in one is found, its RET ends the search pass.
 $7E8C IX=root move being searched
 $7E90 It becomes the move to play
 $7E94 Return
@ $7E95 label=S_ROOTBEST
 $7E95 New root alpha V(1)
 $7E98 $FF means forced mate
 $7E99 Mate: check its length
@ $7E9B label=S_ROOTBEST_SET
 $7E9B Record the best root move
 $7E9E Continue with the next root move
@ $7EA1 label=S_ROOTMATE
 $7EA1 Ply at which the mate was detected
 $7EA4 Lower root alpha to $FE so later mates can still be compared
 $7EA6 ...
 $7EA9 A=mate ply
 $7EAA Mate at ply 2 (mate in one)?
 $7EAC Yes: record the move and end the search pass
 $7EAE $BD0C=shortest mate ply so far
 $7EAF Not shorter?
 $7EB0 Then keep the earlier move
 $7EB3 Shorter: remember the ply
 $7EB4 Record this root move
@ $7EB6 label=S_EXT_LISTS
c $7EB6 Selective extension checks for small move lists
D $7EB6 Reached from #R$7F20 when the list of ply 4 starts in page $B4 (few moves generated along the current line). With D>=3, allows one extra ply (two if the ply-6 list also starts in page $B4), without the threat test of #R$7F27. The list addresses read here may be stale (left from earlier lines or searches).
 $7EB6 High byte of slot(6)
 $7EB9 Ply-6 list in page $B4?
 $7EBB A=D
 $7EBE Yes: two-ply extension test
 $7EC0 D<3?
 $7EC2 Yes: normal test
 $7EC4 L=D
 $7EC5 Low byte of slot(5)
 $7EC8 Ply-5 list starts below $B458?
 $7ECA No: normal test
 $7ECC A=D
 $7ECD HL=$BCA9
 $7ED0 Extend if p<=D+1
@ $7ED3 label=S_EXT_DEEP
 $7ED3 D<3?
 $7ED5 Yes: normal test
 $7ED7 A=D+1
 $7ED8 HL=$BCA9
 $7EDB Extend if p<=D+2
@ $7EDE label=S_QUNDO
c $7EDE Selective node: try the next move in generation order
D $7EDE Used at plies beyond the full-width depth. Moves are taken in generation order, each made and evaluated statically; a value that fails high cuts off (#R$7F81), a better value raises alpha and becomes the killer. Selected moves descend further (#R$7F27, #R$7FAD). When the list is exhausted the node returns (#R$7E25).
 $7EDE Unmake the previous move
@ $7EE1 label=S_QNEXT
 $7EE1 Ply counter
@ $7EE4 label=S_QNEXT_HL
 $7EE4 A=p
 $7EE5 2p
 $7EE6 ...
 $7EE7 L=$A9+2p: slot(p)
 $7EE8 $BD4E=slot offset (non-zero: "selective node")
 $7EEB DE=header of this ply's list
 $7EEC ...
 $7EED ...
 $7EEE HL=header
 $7EEF A=count
 $7EF0 ...
 $7EF1 C=moves taken so far
 $7EF2 ...
 $7EF3 All taken?
 $7EF4 Yes: return to the parent
 $7EF7 One more taken
 $7EF8 Header flags...
 $7EF9 ...
 $7EFA ...saved in $BD4B (bit 7: in check)
 $7EFD HL=first entry
 $7EFE BC=2*taken
 $7F00 ...
 $7F02 ...
 $7F04 HL=entry number 'taken'
 $7F05 ...
 $7F06 Score byte +1: $FF becomes 0 (marks it taken)
 $7F07 Already scored/searched: skip it
 $7F09 IX=entry
 $7F0A ...
 $7F0C Make the move
 $7F0F Evaluate
 $7F12 C=evaluation
 $7F13 Legal?
 $7F14 Yes
 $7F16 Illegal: header flags
 $7F19 C=1
 $7F1A In check?
 $7F1B Yes: counts as value 2 (just above being mated)
 $7F1D No: ignore the move
@ $7F20 label=S_QEVAL
 $7F20 High byte of slot(4)
 $7F23 Ply-4 list in page $B4?
 $7F25 Yes: small-list extension tests
@ $7F27 label=S_QEXTCHK
 $7F27 $BD4E (set by the evaluation)
 $7F2A Zero?
 $7F2B Yes: extension test
 $7F2D Move flags
 $7F30 Bit 7 clear?
 $7F31 Yes: leaf
 $7F34 Bit 2 set?
 $7F36 Yes: leaf
@ $7F39 label=S_QEXT1
 $7F39 A=D
 $7F3C ...
 $7F3D HL=$BCA9
@ $7F3E label=S_QEXT_CMP
 $7F3E Limit+1
 $7F3F Compare with p
 $7F40 p<=limit+1: search this move one ply deeper
@ $7F43 label=S_QLEAF
c $7F43 Selective node: back up a static value
D $7F43 C holds the evaluation of the move just made (from the mover's point of view, offset by 1). Fail high if it reaches beta; otherwise raise alpha. Threatening moves (flags $42) may instead be searched deeper when $BDF6 is set.
R $7F43 C Evaluation of the position after the move
R $7F43 IX Entry of the move
 $7F43 A=p
 $7F46 Value table
 $7F49 ...
 $7F4A HL=$BCA0+p
 $7F4B value = evaluation+1
 $7F4C ...
 $7F4D HL=V(p-1) (minus beta)
 $7F4E ...
 $7F4F ~value
 $7F50 value >= beta?
 $7F51 Yes: fail high
 $7F53 HL=V(p) (alpha)
 $7F54 Move flags
 $7F57 Threat bits 1 or 6?
 $7F59 Yes: may extend
@ $7F5B label=S_QBEST
 $7F5B A=value
 $7F5C Compare with alpha
 $7F5D Lower: next move
 $7F60 Equal: next move
 $7F63 New alpha
 $7F64 In-check node?
 $7F67 Bit 7 into carry
 $7F68 Yes: no killer update
 $7F6B A=p
 $7F6E Killer table
 $7F71 p-1
 $7F72 ...
 $7F73 ...
 $7F74 HL=killer(p)
 $7F75 Killer from-square
 $7F78 ...
 $7F79 ...
 $7F7A Killer to-square
 $7F7D ...
 $7F7E Next move
@ $7F81 label=S_QFAILHIGH
 $7F81 Fail high: unmake the move just made...
 $7F84 ...and the move that led to this node
 $7F87 Flip the side to move
 $7F8A ...
 $7F8C ...
 $7F8F Ply counter
 $7F92 Back to the parent
 $7F93 In-check node?
 $7F96 Bit 7 into carry
 $7F97 Yes: no killer update
 $7F9A A=new ply q
 $7F9B Killer table
 $7F9E 2q
 $7F9F ...
 $7FA0 HL=killer(q+1)
 $7FA1 The refutation's from-square
 $7FA4 ...
 $7FA5 ...
 $7FA6 ...and to-square
 $7FA9 ...
 $7FAA Next move at the parent
@ $7FAD label=S_QTHREAT
 $7FAD A=p
 $7FB0 B=p
 $7FB1 A=D
 $7FB4 D+2
 $7FB5 ...
 $7FB6 p>D+2?
 $7FB7 Yes: plain leaf
 $7FB9 A=value
 $7FBA p=D+2: use value as is
 $7FBC p<D+2: value+1
 $7FBE Overflow: plain leaf
@ $7FC0 label=S_QTHREAT_CMP
 $7FC0 Below alpha?
 $7FC1 Yes: next move
 $7FC4 Threat extensions enabled?
 $7FC7 ...
 $7FC8 No: plain leaf
 $7FCA A=value
 $7FCB Value 2 (illegal move while in check)?
 $7FCD Yes: plain leaf
 $7FCF Search this move one ply deeper
@ $7FD2 label=S_STALEMATE
c $7FD2 No legal moves: stalemate or checkmate
D $7FD2 #R$7FEA is reached from #R$7DA8 when no move at a full-width node is legal. If the killer was legal the node simply returns. Not in check: the node's value is the stalemate draw value. In check: the value is 1 (mated) and the ply is recorded in $BD0B.
 $7FD2 A=p
 $7FD5 Value table
 $7FD8 ...
 $7FD9 HL=$BCA0+p
 $7FDA Side to move
 $7FDD Bit 0 into carry
 $7FDE A=$BD2E (material term)
 $7FE1 Side bit clear: keep the sign
 $7FE3 Negate
@ $7FE5 label=S_STALEMATE_VAL
 $7FE5 Stalemate value = +-$BD2E + $78
 $7FE7 Back it up as this node's value
@ $7FEA label=S_NOMOVES
 $7FEA Was the killer searched (so there was a legal move)?
 $7FEC Yes: just return
 $7FEF In check?
 $7FF1 No: stalemate
 $7FF3 A=p
 $7FF6 Record the ply of the mate
 $7FF9 Value table
 $7FFC ...
 $7FFD HL=$BCA0+p
 $7FFE Value 1: mated
 $8000 Back it up as this node's value
@ $8003 label=S_PLYINFO
c $8003 Get the current ply's list
D $8003 #R$8006 does the same for the ply counter at (HL).
R $8003 O:B Ply p
R $8003 O:HL Header+3 of ply p's list
R $8003 O:E Number of moves
R $8003 O:C Header byte +2
 $8003 Ply counter
@ $8006 label=S_PLYINFO_HL
c $8006 Get the list of the ply at (HL)
R $8006 HL $BCA9
 $8006 A=p
 $8007 B=p
 $8008 2p
 $8009 ...
 $800A L=$A9+2p: slot(p)
 $800B DE=header address
 $800C ...
 $800D ...
 $800E HL=header
 $800F E=count
 $8010 ...
 $8011 C=byte +2
 $8012 ...
 $8013 HL=header+3
 $8014 Return
@ $8015 label=S_PICKBEST
c $8015 Pick the highest-scored remaining move
D $8015 Scans the list until the first entry with score $FF (the next list's header), keeping the first entry with the strictly highest score. Scores of 0 (searched, pruned or illegal) are never picked.
R $8015 HL Header+3
R $8015 O:DE Chosen entry
R $8015 O:E Bit 0 set if no move has a non-zero score
 $8015 Best score so far = 0
 $8016 Entry stride
 $8019 HL=header+1
 $801A ...
 $801B E odd: "nothing found"
 $801C HL=header
@ $801D label=S_PICK_LOOP
 $801D Next entry's score
 $801E Not higher than the best?
 $801F Skip it
 $8022 New best score
 $8023 $FF: end of the list
 $8025 Return
 $8026 DE=best entry
 $8027 ...
 $8028 Continue
@ $802B label=S_RECAPTURE
c $802B Try the recapture first
D $802B Reached from #R$7D43 when the move leading to this node has flag bit 2 set. Searches the new list backwards for a move to the same square; if found it is searched first like a killer, but never recorded as one ($BD4B=$80).
R $802B A Ply p
R $802B B Number of moves
R $802B IX Entry of the move leading here
 $802B Ply counter
 $802E p+1
 $802F ...
 $8030 ...
 $8031 L=slot(p+1): end of this list
 $8032 HL=end of the list
 $8033 ...
 $8034 ...
 $8035 ...
 $8036 HL=end+2
 $8037 ...
 $8038 Stride -4
 $803B A=square the opponent moved to
@ $803E label=S_RECAP_LOOP
 $803E Previous entry's to-square
 $803F Same square?
 $8040 Yes
 $8042 Scan backwards
 $8044 No recapture: normal move loop
@ $8047 label=S_RECAP_FOUND
 $8047 (unused)
 $8049 HL=score byte of the recapture
 $804A ...
 $804B IX=entry
 $804C ...
 $804E Mark it searched
 $8050 Make the recapture
 $8053 Set bit 7 of its from-square (never matches as a killer)
 $8057 $BD4B bit 7: do not record as killer
 $8059 ...
 $805C Evaluate and handle like a killer
@ $805F label=S_PRUNE
c $805F Forward pruning of weak moves
D $805F Called after static scoring at a full-width node, and at the root to compute the pruning margin. Threshold C = max(best static score, killer evaluation) - 9; moves scoring below it may get score 0 (never searched) through #R$80A2, #R$80BB or #R$80A7, unless their flags include any of bits 7, 6, 3 or 0 ($C9). Disabled when $BD09 bit 7 is set.
R $805F A Best static score of the node
R $805F O:D Plies 1-2 only: 2*count minus the number of moves below the threshold
 $805F Pruning disabled?
 $8062 ...
 $8064 Yes
 $8065 Default test routine
 $8069 A'=best score
 $806A B=p, HL=header+3, E=count, C=header+2
 $806D A=p
 $806E Ply 3 or deeper?
 $8070 A=phase flags
 $8073 Yes: test depends on the phase
 $8075 Plies 1-2: D=2*count
 $8076 ...
 $8077 ...
 $8078 ...and the lenient test
@ $807A label=S_PRUNE_SEL
 $807A B=count
 $807B Deep endgame (or plies 1-2)?
 $807D No
 $807F Lenient test
@ $8083 label=S_PRUNE_SEL2
 $8083 Endgame bit 3?
 $8085 No
 $8087 Strict test
@ $808B label=S_PRUNE_THR
 $808B A=best score
 $808C Killer evaluation higher?
 $808D No
 $808F Use it
@ $8090 label=S_PRUNE_C
 $8090 Threshold = best-9
 $8092 Below 9: no pruning
 $8093 C=threshold
 $8094 HL=first entry
@ $8095 label=S_PRUNE_LOOP
 $8095 A=score
 $8096 HL=flags byte
 $8097 ...
 $8098 ...
 $8099 Below the threshold?
 $809A Yes: apply the test
@ $809C label=S_PRUNE_NEXT
 $809C Next entry
 $809D Loop over the moves
 $809F Return
@ $80A0 label=S_PRUNE_TEST
 $80A0 Jump to the selected test (A=score-threshold)
@ $80A2 label=S_PRUNE_NEAR
c $80A2 Forward pruning test: default
D $80A2 Within 16 of the threshold: prune only if flag bit 2 is set (#R$80A7). Further below: prune (#R$80AB). In both cases moves with any of flags $C9 are kept. The comparison is done modulo 256.
R $80A2 A Score minus threshold
R $80A2 HL Flags byte of the entry
 $80A2 A+16
 $80A4 Negative: more than 16 below, prune

@ $7AC7 label=BOOK_PROBE
c $7AC7 Opening book: probe for a book move
D $7AC7 Called from the search driver ($7C1E) after the root move list for the current position has been generated at $B404 (and scored by $7B96), unless the problem/next-best flag $BCDD is set. Walks the book tree ($9000, see #R$9000) from the root along the moves of the game so far (indices in the game record at $C058), then picks one of the stored replies at random.
D $7AC7 The book is used only when $BCDF=0 (book not yet abandoned) and $C006=1 (the game started from the standard initial position; a set-up position stores its move number there). Book moves are taken straight from the pseudo-legal root list without any legality check (see docs/arch/25-book.md: the stored reply 6...Be7 after 1.e4 e5 2.Nf3 Nf6 3.Nxe5 d6 4.Nf3 Nxe4 5.d4 d5 6.Bb5+ is illegal and is played).
R $7AC7 O:F Z set: book move found; NZ: no book move
R $7AC7 O:($BD29) Address of the chosen move in the root list ($B404+4*index), when Z
  $7AC7 Book already abandoned in this game (BCDF non-zero)?
  $7ACA
  $7ACB Return NZ if so
  $7ACC Did the game start from the standard initial position ($C006=1)?
  $7ACF
  $7AD0 Return NZ if not
  $7AD1 B=random byte (also updates $BCCE); B is not used before the next call
  $7AD4 HL=-1: entry number, pre-incremented below
N $7AD7 Follow one game move down the tree. HL points (after the increment) at the first entry of the sibling list for the position reached so far; on entry to the loop, $BCDF counts the plies already matched.
@ $7AD7 label=BOOKP_PLY
  $7AD7 Next entry (first child of the matched move; the root list on the first pass)
  $7AD8 C=number of plies played in the game (low byte of $C001 only)
  $7ADB
  $7ADC Increment the ply counter $BCDF...
  $7ADF
  $7AE0
  $7AE3 ...and get its old value i
  $7AE4 Have all i game plies been matched?
  $7AE5 If so, choose a reply from this sibling list
  $7AE7 BC=$C058+i: game record byte for ply i
  $7AEA
  $7AEB
  $7AEC
  $7AEE
  $7AEF A=record byte (list index; bit 7 = move gave check)
  $7AF0 Discard the check bit
  $7AF2 C=index of the game move played at ply i
  $7AF3 A=book entry HL (bit 7=leaf, bit 6=more siblings, bits 0-5=list index)
@ $7AF6 label=BOOKP_CMP
  $7AF6 B=entry
  $7AF7 Clear the 'more siblings' bit; the leaf bit stays, so a leaf entry never matches
  $7AF9 Does the entry name the game move (and have a continuation)?
  $7AFA If so, descend to its children and follow the next ply
  $7AFC Any more siblings to try?
  $7AFE If not, the game has left the book: set $BCDF=$FF and return NZ (#R$7AC0)
  $7B00 Skip this entry's subtree; HL=next sibling, A=its entry
  $7B03 Compare again
N $7B05 All game plies matched: choose one of the moves in the sibling list at HL.
@ $7B05 label=BOOKP_CHOOSE
  $7B05 B=fresh random byte (bit 7 always 0)
  $7B08 A=first entry of the list, CF=its leading (9th) bit 'M'
  $7B0B C=entry (candidate move)
  $7B0C Is it the only move in the list?
  $7B0E If so, take it
  $7B10 A=2 (or 3 if M is set)
  $7B12
  $7B13 Take the first move if random bit 1 is set, or (when M is set) bit 0: probability 1/2, or 3/4 when M is set
  $7B14
@ $7B16 label=BOOKP_SIB
  $7B16 Save the address of the current candidate
  $7B17 B=fresh random byte
  $7B1A Skip the candidate's subtree: HL=next sibling, A=its entry, CF=its M bit
  $7B1D If the next sibling has M set, stop here and take the previous candidate
  $7B1F Discard the saved address
  $7B20 C=entry of the new candidate
  $7B21 Is it the last sibling?
  $7B23 If so, take it
  $7B25 Random bit 0 into the carry flag
  $7B27 If set, move on to the next sibling
  $7B29 Otherwise take this one
@ $7B2B label=BOOKP_PREV
  $7B2B Restore the previous candidate's address
  $7B2C Re-read its entry
  $7B2F C=entry
@ $7B30 label=BOOKP_TAKE
  $7B30 A=list index of the chosen move (bits 0-5)
  $7B31
  $7B33 x4 (carry is clear after AND)
  $7B34
  $7B35 DE=4*index
  $7B36
  $7B38 IX=$B404+4*index: the chosen entry in the root move list
  $7B3C
  $7B3E Store it for the caller
  $7B42 A=0
  $7B43 Is the chosen move a leaf (no stored continuation)?
  $7B45 If so, leave $BCDF non-zero (= plies matched + 1): the book is not consulted again this game
  $7B47 Otherwise reset $BCDF to 0 so the book is probed again next move
@ $7B4A label=BOOKP_DONE
  $7B4A Return Z: book move found
  $7B4B
@ $7B4C label=BOOK_SKIP
c $7B4C Opening book: skip a subtree
D $7B4C Skips book entry HL and all its descendants, returning the entry of its next sibling. Only called for an entry whose 'more siblings' bit (6) is set. Uses DE as a signed counter: DE=-1, then for each entry read in pre-order DE is decremented if bit 7 (leaf) is set and incremented if bit 6 (more siblings) is set; the walk stops after the first entry that leaves DE negative.
R $7B4C I:HL Entry number of the subtree root
R $7B4C O:HL Entry number of the next sibling
R $7B4C O:A That sibling's entry (from #R$7B57); CF=its leading bit M; Z if it has no further siblings
  $7B4C DE=-1
@ $7B4F label=BOOKS_LOOP
  $7B4F Read entry HL and adjust DE
  $7B52 Next entry
  $7B53 Continue while DE is not negative
  $7B55
N $7B57 Falls through into #R$7B57 to read the sibling's entry.
@ $7B57 label=BOOK_READ
c $7B57 Opening book: read an entry and update the subtree counter
D $7B57 Reads book entry HL via #R$7B64 and adjusts the subtree counter DE used by #R$7B4C.
R $7B57 I:HL Entry number
R $7B57 I:DE Subtree counter
R $7B57 O:A Entry bits 0-7: bit 7=leaf (no children), bit 6=more siblings follow, bits 0-5=index in the generated move list
R $7B57 O:F CF=entry bit 8 (the leading bit, 'M'); Z if bit 6 is clear
R $7B57 O:DE DE-1 if bit 7 is set, then DE+1 if bit 6 is set
  $7B57 A=entry bits 0-7, CF=bit 8
  $7B5A Leaf?
  $7B5C
  $7B5E If so, DE=DE-1
  $7B5F More siblings?
  $7B61 Return Z if not
  $7B62 If so, DE=DE+1
  $7B63 Return NZ (carry unchanged)
@ $7B64 label=BOOK_BITS
c $7B64 Opening book: fetch the 9-bit entry HL
D $7B64 The book at $9000 is a bit stream of 9-bit entries, most significant bit first: entry n occupies stream bits 9n to 9n+8, which start at bit (n AND 7) of byte n+INT(n/8). The routine reads the two bytes from that address into A and C and shifts the pair left (n AND 7)+1 times, so that A holds entry bits 0-7 and the carry flag holds bit 8.
R $7B64 I:HL Entry number n
R $7B64 O:A Entry bits 0-7
R $7B64 O:F CF=entry bit 8
  $7B64 Preserve BC and HL
  $7B65
  $7B66 BC=n/8 (shift HL right three times)
  $7B67
  $7B69
  $7B6A
  $7B6C
  $7B6D
  $7B6F
  $7B70
  $7B71
  $7B72 Restore HL=n (and keep it on the stack)
  $7B73
  $7B74 A=n AND 7 (clears the carry flag)
  $7B76
  $7B77 HL=n+n/8 (=byte offset of the entry)
  $7B78 HL=$9000+n+n/8
  $7B7B
  $7B7C B=(n AND 7)+1: number of shifts
  $7B7D
  $7B7E A=first byte
  $7B7F C=second byte
  $7B80
@ $7B81 label=BOOKB_SHIFT
  $7B81 Shift C into A, one bit at a time; the last bit shifted out of A (entry bit 8) is left in the carry flag
  $7B83
  $7B84
  $7B86 Restore HL and BC
  $7B87
  $7B88
@ $7B89 label=BOOK_RANDOM
c $7B89 Opening book: generate a random byte
D $7B89 Mixes the Z80 refresh register R into the random accumulator at $BCCE and halves it: $BCCE = (R XOR $BCCE) >> 1. The result (0-127; bit 7 is always 0) is returned in B. $BCCE is also incremented while the program waits for a key (#R$675A), mixed with R in the main loop ($60EB) and incremented by every evaluation ($8807).
R $7B89 O:B Random byte (0-127)
R $7B89 O:A Same as B
  $7B89 B=R
  $7B8B
  $7B8C A=($BCCE) XOR R (clears the carry flag)
  $7B8F
  $7B90 Shift right; bit 7 becomes 0
  $7B91 Store the new value of the accumulator
  $7B94 B=random byte
  $7B95

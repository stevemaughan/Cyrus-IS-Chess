  ORG $6000

; Routine at 6000
  LD HL,$1111
  LD ($5CB2),HL
  LD ($5CB4),HL
  DI
  LD ($BCC8),IY
  LD HL,($5C36)
  LD ($BCD5),HL
  CALL $7004
  CALL $6FDD
  DEFB $12,$00            ; Inline arguments
  CALL $6FEF
  CALL $6FB0
  DEFB $50,$0C            ; Inline arguments
  LD ($5C36),HL
  CALL $6734
  JR Z,$605B
  CALL $7415
  DEFB $00,$00            ; Inline arguments
  DEFM $7F," 1982 Intelligent Software Ltd"
  DEFB $AE                ; Last character (bit 7 set)
  CALL $6FB0
  DEFB $FF,$10            ; Inline arguments
  CALL $6734
  JR Z,$602C
  LD A,$01
  LD ($BCBD),A
  LD ($BCCD),A
  LD ($BCD4),A
  XOR A
  LD ($BCC7),A
  LD ($BCDD),A
  LD ($C006),A
  LD ($BCDB),A
  LD ($BCC3),A
  LD ($BCD3),A
  CALL $6BBA
  CALL $709C
; This entry point is used by the routine at 6985.
  LD A,($C006)
  DEC A
  JR Z,$608A
  LD A,$FF
  LD ($C058),A
  LD A,$01
  LD ($BCC2),A
; This entry point is used by the routine at 63B1.
  LD HL,$0000
  LD ($C003),HL
  CALL $7004
  CALL $6FB0
  DEFB $32,$10            ; Inline arguments
  LD A,($BCD4)
  OR A
  CALL Z,$7065
; This entry point is used by the routine at 68A0.
  CALL $6505
; This entry point is used by the routines at 68A0 and 6D4D.
  LD HL,$0000
  LD ($C001),HL
  XOR A
  LD ($C047),A
  LD ($BCDF),A
  CALL $701D
; This entry point is used by the routines at 6678, 6800, 6916, 69B3, 6B97,
; 6BBA, 6CF4 and 6D4D.
  LD SP,$BDF4
  LD A,($BCC3)
  OR A
  JR Z,$60E3
  LD BC,$C058
  LD HL,($C001)
  ADD HL,BC
  LD A,(HL)
  INC A
  JP Z,$671F
  CALL $70DF
  LD HL,$C000
  CALL $6734
  JP NZ,$671F
  LD A,($BCDB)
  OR A
  JR NZ,$60E3
  DEC HL
  LD A,L
  OR H
  JR NZ,$60D2
  LD HL,($C003)
  LD A,L
  OR H
  JP NZ,$6690
  LD A,R
  LD B,A
  RRA
  RRA
  ADD A,B
  LD HL,$BCCE
  ADD A,(HL)
  LD (HL),A
  LD A,($BD5E)
  CP $06
  JP Z,$6448
  LD A,($BD0A)
  CP $64
  JP NC,$6448
  XOR A
  LD ($BCBF),A
  CALL $7046
  CALL $703F
  CALL $704D
  CALL $737C
  CALL $756E
  CALL $759A
  CALL $75B4
  LD A,($BCDD)
  OR A
  JR Z,$6134
  LD A,($BD2D)
  AND $01
  XOR $01
  LD ($BCBE),A
  CALL $7562
  JR $6147
  LD A,($BD2D)
  RRA
  LD A,($BCBE)
  JR NC,$6143
  OR A
  JR Z,$6147
  JP $61C8
  OR A
  JP Z,$61C8
  LD A,($BCC2)
  OR A
  JP Z,$696A
  LD A,$40
  LD ($BD4C),A
  LD IX,$BD58
  CALL $78CE
  CALL $7B96
  LD A,($BD19)
  OR A
  JP Z,$641A
  XOR A
  LD ($BCDB),A
  LD A,($BCDD)
  OR A
  CALL Z,$6FAA
  CALL $70DF
  CALL $6FB0
  DEFB $14,$10            ; Inline arguments
  CALL $73AE
  CALL $73F7
  DEFM "LET ME THINK.."
  DEFB $AE                ; Last character (bit 7 set)
  CALL $7BE1
  CALL $6FB0
  DEFB $14,$20            ; Inline arguments
  XOR A
  LD ($BCDD),A
  LD A,($BCCD)
  CP $08
  JR C,$61C1
  LD A,($BCA0)
  CP $FE
  JR NC,$61C1
  CALL $703F
  CALL $73F7
  DEFM "*NO MATE FOUND"
  DEFB $AA                ; Last character (bit 7 set)
  CALL $73A8
  JP $6D4D
  LD IX,($BD29)
  JP $6323
  XOR A
  LD ($BD4C),A
  LD IX,$BD58
  CALL $78CE
  CALL $7B96
  LD A,($BD19)
  OR A
  JP Z,$641A
  XOR A
  LD ($BCDB),A
  LD A,($BCC2)
  CP $03
  JP Z,$696A
  OR A
  JR Z,$61EF
  CALL $7562
  CALL $70D3
  CALL $7405
  DEFM "Alter     take-Back Change-pos'nDemo      Enter     take-Forwardn"
  DEFM "ew-Game  Level     Move        Next-best Orient'n  Printer     Re"
  DEFM "play    Sound     Tape        5-left 6-down 7-up 8-right <cr"
  DEFB $BE                ; Last character (bit 7 set)
  CALL $6FEF
  CALL $740E
  DEFM "YOUR MOVE?   "
  DEFB $A0                ; Last character (bit 7 set)
  LD A,$FF
  LD ($BCCB),A
  CALL $6800
  CP $0D
  JR NZ,$62CD
  CALL $6FB0
  DEFB $32,$20            ; Inline arguments
  CALL $703F
  LD A,$38
  LD ($BCC4),A
  LD A,($BCCB)
  INC A
  LD A,($BCCA)
  JR NZ,$62F7
  LD ($BCCB),A
  CALL $6FDD
  DEFB $0A,$0A            ; Inline arguments
  CALL $74F7
  JR $62CD
  LD ($BCCC),A
  CALL $6FDD
  DEFB $0A,$0C            ; Inline arguments
  CALL $74F7
  LD A,($BCCB)
  EX AF,AF'
  LD A,($BCCC)
  LD HL,$B401
  LD B,(HL)
  INC L
  CALL $7BCD
  JR C,$6318
  DEC L
  XOR A
  OR (HL)
  JR NZ,$631D
  CALL $739E
  JR $62B7
  CALL $6FAA
  PUSH HL
  POP IX
  CALL $70BF
  CALL $810F
  XOR A
  LD ($BCDE),A
  POP AF
  PUSH AF
  CALL PE,$63B1
  RES 7,(IX+$03)
  CALL $8400
  CALL $746E
  CALL $70C7
  LD A,($BCD4)
  OR A
  CALL Z,$7452
  PUSH IX
  POP HL
  LD BC,$B400
  XOR A
  LD E,A
  SBC HL,BC
  LD BC,$0004
  INC E
  SBC HL,BC
  JR NZ,$6353
  DEC E
  LD HL,($C001)
  INC HL
  LD ($C001),HL
  LD A,(IX+$03)
  AND $80
  OR E
  LD BC,$C057
  ADD HL,BC
  LD (HL),A
  INC HL
  LD (HL),$FF
; This entry point is used by the routine at 6678.
  LD HL,$BD0A
  INC (HL)
  POP AF
  PUSH AF
  JP P,$637C
  AND $0F
  DEC A
  JR NZ,$6380
  XOR A
  LD ($BD0A),A
  CALL $6560
  LD A,($BD2D)
  XOR $01
  LD ($BD2D),A
  RRA
  JR NC,$6392
  LD HL,$BD49
  INC (HL)
  LD A,($BCDD)
  OR A
  JR NZ,$63AE
  LD HL,$BF00
  LD A,(HL)
  INC A
  JR Z,$63A2
  INC HL
  JR $639B
  LD A,(IX+$01)
  LD (HL),A
  INC HL
  LD A,(IX+$02)
  LD (HL),A
  INC HL
  LD (HL),$FF
  JP $60B7

; Routine at 63B1
;
; Used by the routine at 6000.
  LD A,($BD4C)
  BIT 6,A
  JR NZ,$63FE
  CALL $73F7
  DEFM "PROMOTE TO"
  DEFB $BF                ; Last character (bit 7 set)
  CALL $7405
  DEFM "kNight  Bishop  Rook    Quee"
  DEFB $EE                ; Last character (bit 7 set)
  CALL $6FEF
  CALL $675A
  LD B,$05
  CP $52
  JR Z,$6402
  LD B,$03
  CP $4E
  JR Z,$6402
  LD B,$83
  CP $42
  JR Z,$6402
  LD B,$09
  JR $640D
  LD L,(IX+$02)
  LD H,$BD
  LD L,(HL)
  RES 2,L
  INC L
  INC H
  LD (HL),B
  LD HL,$C047
  INC (HL)
  LD A,(HL)
  ADD A,L
  LD L,A
  LD (HL),B
  LD A,B
  LD ($BCDE),A
  RET
; This entry point is used by the routine at 6000.
  LD A,($BD5B)
  RLA
  JR C,$6434
  CALL $73FE
  DEFM "STALEMAT"
  DEFB $C5                ; Last character (bit 7 set)
  LD HL,$6423
  CALL $742C
  JR $6456
  CALL $73FE
  DEFM "CHECKMAT"
  DEFB $C5                ; Last character (bit 7 set)
  LD HL,$6437
  CALL $742C
  JR $6456
; This entry point is used by the routine at 6000.
  CALL $73FE
  DEFM "DRAW"
  DEFB $CE                ; Last character (bit 7 set)
  LD HL,$644B
  CALL $742C
  LD A,$01
  LD ($BCBF),A
  XOR A
  LD ($BCDB),A
  CALL $703F
  CALL $704D
  CALL $70DF
  CALL $6FB0
  DEFB $C8,$18            ; Inline arguments
  LD A,($BCC2)
  CP $03
  JR NZ,$648B
  LD B,$09
  LD HL,$0000
  CALL $6734
  JR NZ,$6488
  DEC HL
  LD A,L
  OR H
  JR NZ,$6479
  DJNZ $6479
  JP $608F
  CALL $7562
  CALL $7405
  DEFM "Alter     take-Back Change-pos'nnew-Game  Level     Next-best   O"
  DEFM "rient'n  Printer   Replay      Sound     Tap"
  DEFB $E5                ; Last character (bit 7 set)
  CALL $6FEF
  CALL $6800
  JP $648B

; Routine at 6505
;
; Used by the routine at 6000.
  POP DE
  XOR A
  LD B,A
  LD HL,$BF00
  DEC HL
  LD (HL),A
  DEC HL
  LD (HL),A
  DJNZ $650B
  PUSH DE
  LD C,A
  CALL $6547
  LD DE,$BE00
  LD C,$41
  CALL $654A
  LD L,$60
  LD C,$C1
  CALL $654A
  LD C,$81
  CALL $6547
  LD A,$01
  LD ($BCBE),A
  LD ($BD2D),A
  LD ($BD49),A
  LD ($BCA9),A
  LD ($C006),A
  LD HL,$B400
  LD ($BCAB),HL
  CALL $659C
  JP $65E5

; Routine at 6547
;
; Used by the routine at 6505.
  LD DE,$6558

; Routine at 654A
;
; Used by the routine at 6505.
  LD B,$08
  LD A,(DE)
  OR C
  LD (HL),A
  INC L
  INC DE
  DJNZ $654C
  LD A,$08
  ADD A,L
  LD L,A
  RET

; Data block at 6558
  DEFB $11,$31,$21,$09,$01,$21,$31,$11

; Routine at 6560
;
; Used by the routine at 6000.
  LD HL,($BD5C)
  LD B,(IX+$01)
  LD C,(IX+$02)
  XOR A
  SBC HL,BC
  LD HL,$BD5E
  JR NZ,$6574
  INC (HL)
  JR $6575
  LD (HL),A
  LD HL,($BD59)
  LD ($BD5C),HL
  LD A,B
  LD ($BD59),A
  LD H,(IX+$03)
  LD L,C
  LD ($BD5A),HL
  RET
; This entry point is used by the routines at 65DA and 6610.
  POP HL
; This entry point is used by the routine at 6D4D.
  CALL $739E
  JP $6D6A

; Routine at 658E
;
; Used by the routines at 68A0 and 6D4D.
  XOR A
  LD HL,$BD00
  LD (HL),A
  INC L
  BIT 3,L
  JR Z,$6592
  BIT 7,L
  JR Z,$6593

; Routine at 659C
;
; Used by the routine at 6505.
  XOR A
  LD HL,$BE00
  SET 7,(HL)
  ADD A,$08
  LD L,A
  JR NC,$65A0
  RET

; Routine at 65A8
;
; Used by the routine at 65DA.
  LD D,(HL)
  BIT 7,D
  JR NZ,$65D1
  INC L
  LD B,(HL)
  DEC L
  LD A,B
  AND $0F
  DEC A
  JR Z,$65D1
  SET 7,(HL)
  LD A,L
  AND $80
  OR $03
  LD E,A
  LD A,B
  AND $8F
  PUSH HL
  LD HL,$6F2E
  CALL $6F23
  INC HL
  INC HL
  LD A,(HL)
  OR E
  LD H,$BD
  LD L,D
  LD (HL),A
  POP HL
  LD A,L
  ADD A,$08
  LD L,A
  BIT 6,A
  JR NZ,$65A8
  RET

; Routine at 65DA
;
; Used by the routine at 6D4D.
  LD HL,$BE40
  CALL $65A8
  LD L,$C0
  CALL $65A8
; This entry point is used by the routine at 6505.
  LD DE,$BD00
  LD H,$BE
  LD A,(DE)
  BIT 0,A
  CALL NZ,$6610
  LD A,$10
  ADD A,E
  LD E,A
  JP P,$65EA
  RES 7,E
  INC E
  BIT 3,A
  JR Z,$65EA
  LD L,$00
  CALL $660A
  LD L,$80
  LD A,B
  OR (HL)
  JP M,$6587

; Routine at 660A
;
; Used by the routine at 65DA.
  LD B,(HL)
  INC L
  LD A,(HL)
  JP $8203

; Routine at 6610
;
; Used by the routine at 65DA.
  LD L,A
  DEC L
  BIT 6,L
  JR Z,$662B
  LD A,$70
  AND E
  JR Z,$6674
  CP $70
  JR Z,$6674
  LD B,$01
  LD A,$80
  AND L
  XOR $80
  SCF
  RRA
  LD C,A
  JR $666D
  LD A,$78
  AND L
  JR NZ,$663F
  LD C,$01
  LD B,$00
  BIT 1,L
  JR Z,$663A
  LD B,$30
  CALL $6678
  JR $6674
  CP $10
  LD C,$0E
  LD B,$09
  JR C,$6664
  JR NZ,$6655
  LD C,$08
  LD B,$05
  BIT 1,L
  JR Z,$6661
  LD B,$15
  JR $6661
  LD B,$03
  LD C,$00
  CP $20
  JR NZ,$6661
  LD B,$83
  LD C,$04
  CALL $6678
  CALL $6678
  LD A,$82
  AND L
  SET 6,A
  LD L,A
  CALL $6678
  BIT 6,L
  JR NZ,$666D
  POP HL
  JP $6587

; Routine at 6678
;
; Used by the routine at 6610.
  RES 1,L
  LD A,(HL)
  RLA
  JR C,$6683
  LD A,$08
  ADD A,L
  LD L,A
  RET
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
; This entry point is used by the routine at 6000.
  LD BC,($C001)
  XOR A
  SBC HL,BC
  JP Z,$671F
  LD ($BCCF),HL
  LD HL,($C001)
  INC HL
  LD ($C001),HL
  LD BC,$C057
  ADD HL,BC
  LD C,(HL)
  LD A,C
  RES 7,C
  LD B,$00
  LD HL,$B404
  ADD HL,BC
  ADD HL,BC
  ADD HL,BC
  ADD HL,BC
  PUSH AF
  PUSH HL
  LD IX,$BD58
  CALL $78CE
  POP IX
  POP AF
  INC (IX+$00)
  RLA
  JR NC,$66CB
  SET 7,(IX+$03)
  LD A,($BCC3)
  OR A
  CALL NZ,$70BF
  CALL $810F
  XOR A
  LD ($BCDE),A
  POP AF
  PUSH AF
  JP PO,$66F4
  LD HL,$C047
  INC (HL)
  LD A,(HL)
  ADD A,L
  LD L,A
  LD A,(HL)
  LD L,(IX+$02)
  LD H,$BD
  LD L,(HL)
  RES 2,L
  INC L
  INC H
  LD (HL),A
  LD ($BCDE),A
  LD A,($BCC3)
  OR A
  JR Z,$6709
  CALL $746E
  CALL $70C7
  LD A,($BCDB)
  OR A
  CALL NZ,$7452
  JR $6715
  LD HL,($BCCF)
  XOR A
  LD BC,$0003
  SBC HL,BC
  CALL C,$746E
  LD A,($BCDD)
  OR A
  CALL Z,$6FAA
  JP $636E
; This entry point is used by the routine at 6000.
  LD HL,$0000
  LD ($C003),HL
  XOR A
  LD ($BCC3),A
  LD A,($BD2D)
  AND $01
  LD ($BCBE),A
  JP $60B7

; Routine at 6734
;
; Used by the routines at 6000, 63B1, 78BA and 7BF1.
  XOR A
  IN A,($FE)
  AND $1F
  CP $1F
  RET Z
  CALL $73F7
  DEFM "**INTERRUPTED*"
  DEFB $AA                ; Last character (bit 7 set)
  CALL $6FB0
  DEFB $C8,$50            ; Inline arguments
  CALL $703F
  LD A,$01
  OR A
  RET

; Routine at 675A
;
; Used by the routines at 63B1, 677E, 6985, 69B3, 6B97 and 6BBA.
  LD IY,($BCC8)
  EI
  LD HL,$BCCE
  INC (HL)
  LD HL,$5C3B
  BIT 5,(HL)
  JR Z,$675F
  DI
  LD A,($5C08)
  RES 5,(HL)
  AND $DF
  LD ($BCC0),A
  CALL $6FB0
  DEFB $02,$04            ; Inline arguments
  LD A,($BCC0)
  RET

; Routine at 677E
;
; Used by the routines at 6800 and 6D4D.
  CALL $675A
  CP $53
  JR NZ,$6797
  LD A,($BCD3)
  XOR $01
  LD ($BCD3),A
  CALL $75B4
  CALL $6FB0
  DEFB $08,$14            ; Inline arguments
  JR $677E
  CP $4F
  JR NZ,$67A8
  LD A,($BCC7)
  XOR $01
  LD ($BCC7),A
  CALL $70E4
  JR $677E
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
  JR Z,$67BE
  XOR $01
  CP $16
  JR Z,$67E2
  CP $17
  JR Z,$67EF
  AND $03
  JR Z,$67D6
  LD A,($BCCA)
  DEC A
  BIT 3,A
  JR Z,$67FA
  ADD A,$08
  JR $67FA
  LD A,($BCCA)
  INC A
  BIT 3,A
  JR Z,$67FA
  SUB $08
  JR $67FA
  LD A,($BCCA)
  ADD A,$10
  BIT 7,A
  JR Z,$67FA
  SUB $80
  JR $67FA
  LD A,($BCCA)
  SUB $10
  BIT 7,A
  JR Z,$67FA
  ADD A,$80
  CALL $70E1
  JP $677E

; Routine at 6800
;
; Used by the routines at 6000, 63B1, 6869, 68A0, 6916 and 69B3.
  CALL $677E
  LD A,($BCBF)
  OR A
  LD A,($BCC0)
  JP NZ,$681A
  CP $44
  JR Z,$684D
  CP $45
  JR Z,$6858
  CP $4D
  JP Z,$695D
  CP $41
  JP Z,$6A8D
  CP $42
  JP Z,$68A0
  CP $43
  JP Z,$6D4D
  CP $46
  JP Z,$6916
  CP $47
  JP Z,$697F
  CP $4C
  JP Z,$6932
  CP $4E
  JP Z,$69B3
  CP $50
  JP Z,$69C9
  CP $52
  JP Z,$6869
  CP $54
  JP Z,$6BCF
  RET
  LD A,$03
  LD ($BCC2),A
  CALL $73AE
  JP $60B7
  LD A,$00
  LD ($BCC2),A
  CALL $756E
  JP $6800

; Message at 6863
  DEFM "Repla",$F9

; Routine at 6869
;
; Used by the routine at 6800.
  LD A,($C058)
  INC A
  JP Z,$6800
  LD HL,$6863
  CALL $743B
; This entry point is used by the routine at 69B3.
  CALL $7046
  CALL $704D
  CALL $73F7
  DEFM "*REPLAYING"
  DEFB $AA                ; Last character (bit 7 set)
  CALL $73AE
  LD A,$01
  LD ($BCC3),A
  LD HL,$FFFF
  JR $68B2

; Message at 6897
  DEFM "take-Bac",$EB

; Routine at 68A0
;
; Used by the routine at 6800.
  LD HL,($C001)
  LD A,L
  OR H
  JP Z,$6800
  LD HL,$6897
  CALL $743B
; This entry point is used by the routine at 69B3.
  LD HL,($C001)
  DEC HL
; This entry point is used by the routines at 6869 and 6BBA.
  LD ($C003),HL
  LD A,($C006)
  LD ($BD49),A
  DEC A
  JP Z,$60A4
  CALL $658E
  LD A,($C005)
  LD ($BD2D),A
  AND $01
  LD ($BCBE),A
  LD DE,$C007
  LD HL,$BE00
  LD B,$20
  LD A,(DE)
  LD (HL),A
  INC HL
  INC DE
  LD A,(DE)
  LD (HL),A
  INC DE
  LD A,L
  ADD A,$07
  LD L,A
  DJNZ $68D5
  LD HL,$BE00
  LD DE,$BD00
  LD A,(HL)
  OR A
  JP M,$68F2
  LD E,A
  LD A,L
  OR $04
  LD (DE),A
  LD A,L
  ADD A,$08
  LD L,A
  JR NC,$68E8
  CALL $6F99
  LD A,($BCDB)
  OR A
  JR Z,$6907
  CALL $70DF
  CALL $729D
  JP $60A7

; Message at 690A
  DEFM "take-Forwar",$E4

; Routine at 6916
;
; Used by the routine at 6800.
  LD HL,($C001)
  LD BC,$C058
  ADD HL,BC
  LD A,(HL)
  INC A
  JP Z,$6800
  LD HL,$690A
  CALL $743B
  LD HL,($C001)
  INC HL
  LD ($C003),HL
  JP $60B7
; This entry point is used by the routine at 6800.
  LD A,($BCCD)
  INC A
  CP $0B
  JR NZ,$693B
  XOR A
  LD ($BCCD),A
  CP $08
  JR NZ,$6946
  LD A,$00
  JR $6954
  CP $09
  JR NZ,$694E
  LD A,$03
  JR $6954
  CP $0A
  JR NZ,$6954
  LD A,$07
  LD ($BCBD),A
  CALL $737C
  JP $6800
; This entry point is used by the routine at 6800.
  LD A,($BCBE)
  OR A
  LD A,$01
  JR Z,$6967
  LD A,$02
  LD ($BCC2),A
; This entry point is used by the routine at 6000.
  LD A,($BCBE)
  OR A
  LD A,$01
  JR Z,$6973
  XOR A
  LD ($BCBE),A
  LD HL,$BCA0
  XOR A
  SUB (HL)
  LD (HL),A
  JP $60B7
; This entry point is used by the routine at 6800.
  CALL $6985
  JP $60B7

; Routine at 6985
;
; Used by the routines at 6916 and 6D4D.
  CALL $704D
  CALL $740E
  DEFM "NEW GAME"
  DEFB $BF                ; Last character (bit 7 set)
  CALL $7405
  DEFM "Yes  N"
  DEFB $EF                ; Last character (bit 7 set)
  CALL $6FEF
  CALL $675A
  CP $59
  JP Z,$607F
  RET

; Message at 69AA
  DEFM "Next-bes",$F4

; Routine at 69B3
;
; Used by the routine at 6800.
  LD HL,($C001)
  LD A,L
  OR H
  JP Z,$6800
  LD HL,$69AA
  CALL $743B
  LD A,$01
  LD ($BCDD),A
  JP $68AE
; This entry point is used by the routine at 6800.
  IN A,($FB)
  AND $40
  JR Z,$69EA
  CALL $703F
  CALL $73F7
  DEFM "*NO PRINTER"
  DEFB $AA                ; Last character (bit 7 set)
  CALL $73A8
  CALL $703F
  JP $6800
  CALL $704D
  CALL $740E
  DEFM "COMMAND"
  DEFB $BF                ; Last character (bit 7 set)
  CALL $7405
  DEFM "print-Board        print-Record          Toggle-listing          "
  DEFM "   -any other key to exit"
  DEFB $AD                ; Last character (bit 7 set)
  CALL $6FEF
  CALL $675A
  CP $42
  JR NZ,$6A66
  CALL $729D
  JP $60B7
  CP $52
  JR NZ,$6A7A
  LD A,($C058)
  INC A
  JP Z,$60B7
  LD ($BCDB),A
  CALL $7065
  JP $6876
  CP $54
  JP NZ,$60B7
  LD A,($BCD4)
  XOR $01
  LD ($BCD4),A
  CALL $759A
  JP $60B7
; This entry point is used by the routine at 6800.
  CALL $704D
  CALL $7405
  DEFM "0-black 1-blue 2-red 3-magenta  4-green 5-cyan 6-yellow 7-white  "
  DEFM "         8-no change                  D-default colours          "
  DEFM "  -any other key to exit"
  DEFB $AD                ; Last character (bit 7 set)
  CALL $6FEF
  CALL $740E
  DEFM "COLOUR FO"
  DEFB $D2                ; Last character (bit 7 set)
  CALL $73FE
  DEFM "BLACK PIECE"
  DEFB $BF                ; Last character (bit 7 set)
  LD HL,$BCD7
  CALL $6B97
  CALL $73FE
  DEFM "WHITE PIECE"
  DEFB $BF                ; Last character (bit 7 set)
  LD HL,$BCD8
  CALL $6B97
  CALL $73FE
  DEFM "BLACK SQUARE"
  DEFB $BF                ; Last character (bit 7 set)
  LD HL,$BCD9
  CALL $6B97
  CALL $73FE
  DEFM "WHITE SQUARE"
  DEFB $BF                ; Last character (bit 7 set)
  LD HL,$BCDA
  CALL $6B97
  JP $60B7

; Routine at 6B97
;
; Used by the routine at 69B3.
  PUSH HL
  CALL $675A
  CP $44
  JR NZ,$6BA7
  CALL $6BBA
  CALL $70DF
  JR $6B98
  SUB $10
  JP M,$60B7
  CP $09
  JP P,$60B7
  POP HL
  CP $08
  RET Z
  LD (HL),A
  CALL $70DF
  RET

; Routine at 6BBA
;
; Used by the routines at 6000 and 6B97.
  LD A,$00
  LD ($BCD7),A
  LD A,$07
  LD ($BCD8),A
  LD A,$04
  LD ($BCD9),A
  LD A,$06
  LD ($BCDA),A
  RET
; This entry point is used by the routine at 6800.
  CALL $704D
  CALL $740E
  DEFM "COMMAND"
  DEFB $BF                ; Last character (bit 7 set)
  CALL $7405
  DEFM "Save-record         Load-record     -any other key to exit"
  DEFB $AD                ; Last character (bit 7 set)
  CALL $6FEF
  CALL $675A
  CP $53
  JR NZ,$6C8D
  LD A,($C058)
  INC A
  JP Z,$60B7
  CALL $740E
  DEFM "START TAP"
  DEFB $C5                ; Last character (bit 7 set)
  CALL $7405
  DEFM "--Hit any key to initiate save-"
  DEFB $AD                ; Last character (bit 7 set)
  CALL $6FEF
  CALL $675A
  CALL $740E
  DEFM "SAVING..."
  DEFB $A0                ; Last character (bit 7 set)
  CALL $73D4
  LD DE,$0058
  LD HL,$C058
  INC DE
  LD A,(HL)
  INC HL
  INC A
  JR NZ,$6C78
  LD IX,$C000
  LD A,$FF
  LD ($C000),A
  CALL $6D0F
  JP $60B7
  CP $4C
  JP NZ,$60B7
  CALL $740E
  DEFM "LOADING.."
  DEFB $AE                ; Last character (bit 7 set)
  CALL $73D4
  LD DE,$1F00
  SCF
  LD IX,$E000
  LD A,$FF
  CALL $6D16
  JR NC,$6D0C
  LD HL,$E058
  OR A
  PUSH IX
  POP BC
  SBC HL,BC
  LD A,H
  OR A
  JP P,$6CF4
  LD A,(IX-$02)
  INC A
  JR NZ,$6CF4
  LD A,($E000)
  INC A
  JR NZ,$6CF4
  LD HL,$C000
  LD DE,$E000
  LD BC,$1F00
  LD A,(DE)
  LD (HL),A
  INC DE
  INC HL
  DEC BC
  LD A,B
  OR C
  JR NZ,$6CD4
  LD HL,$6CE9
  CALL $743B
  LD HL,($C001)
  JP $68B2

; Message at 6CE9
  DEFM "Tape loade",$E4

; Routine at 6CF4
;
; Used by the routine at 6BBA.
  CALL $703F
  CALL $73F7
  DEFM "*TAPE ERROR"
  DEFB $AA                ; Last character (bit 7 set)
  CALL $73A8
  CALL $703F
; This entry point is used by the routine at 6BBA.
  JP $60B7

; Routine at 6D0F
;
; Used by the routine at 6BBA.
  LD HL,$6D25
  PUSH HL
  JP $04C6

; Routine at 6D16
;
; Used by the routine at 6BBA.
  INC D
  EX AF,AF'
  DEC D
  DI
  LD A,$0F
  OUT ($FE),A
  LD HL,$6D25
  PUSH HL
  JP $0562

; Data block at 6D25
  DEFB $3E,$07,$D3,$FE,$3E,$7F,$DB,$FE
  DEFB $1F,$FB,$38,$1B,$CD,$3F,$70,$CD
  DEFB $F7,$73,$2A,$41,$42,$4F,$52,$54
  DEFB $45,$44,$AA,$CD,$A8,$73,$CD,$3F
  DEFB $70,$21,$3B,$5C,$CB,$AE,$B7,$C9

; Routine at 6D4D
;
; Used by the routines at 6000 and 6800.
  CALL $7046
  CALL $703F
  CALL $701D
  CALL $70D3
  XOR A
  LD ($BD4D),A
  LD A,($BD2D)
  RRA
  LD A,$83
  JR C,$6D67
  LD A,$03
  LD ($BCA2),A
; This entry point is used by the routine at 6560.
  CALL $70E4
  CALL $7405
  DEFM "All-clear     Exit      new-GameOrient'n      Sound             T"
  DEFM "oggle-colour Unoccupied        Pawn       kNight     Bishop    Ro"
  DEFM "ok       Queen      King      5-left 6-down 7-up 8-righ"
  DEFB $F4                ; Last character (bit 7 set)
  CALL $6FEF
  CALL $740E
  DEFM "CHANGE POSITIO"
  DEFB $CE                ; Last character (bit 7 set)
  LD A,($BCA2)
  CP $03
  JR Z,$6E50
  CALL $73FE
  DEFM "WHIT"
  DEFB $C5                ; Last character (bit 7 set)
  JR $6E58
  CALL $73FE
  DEFM "BLAC"
  DEFB $CB                ; Last character (bit 7 set)
  CALL $677E
  CALL $703F
  LD A,($BCC0)
  CP $45
  JP Z,$6ECC
  CP $47
  JR NZ,$6E73
  CALL $7046
  CALL $6985
  JP $6D6A
  CP $54
  JR NZ,$6E82
  LD A,($BCA2)
  XOR $80
  LD ($BCA2),A
  JP $6D6A
  CP $41
  JR NZ,$6E8B
  CALL $658E
  JR $6EC4
  CP $55
  JR NZ,$6E98
  LD A,($BCCA)
  LD L,A
  LD H,$BD
  XOR A
  JR $6EB4
  LD HL,$6F2F
  CALL $6F23
  JP C,$6D6A
  INC HL
  LD A,(HL)
  LD ($BCA3),A
  LD A,($BCCA)
  LD L,A
  LD H,$BD
  LD A,($BCA3)
  LD B,A
  LD A,($BCA2)
  ADD A,B
  LD C,(HL)
  LD (HL),A
  BIT 0,C
  JR NZ,$6EC4
  BIT 2,C
  JR Z,$6EC4
  RES 2,C
  LD L,C
  INC H
  SET 7,(HL)
  LD A,$02
  LD ($BD4D),A
  JP $6D6A
  LD A,($BCA2)
  LD HL,$BD2D
  LD B,(HL)
  RES 0,B
  SUB $03
  LD ($BCBE),A
  LD A,$02
  JR Z,$6EE2
  SET 0,B
  LD A,$01
  LD ($BCC2),A
  LD A,B
  CP (HL)
  JR Z,$6EEF
  LD (HL),B
  LD A,$02
  LD ($BD4D),A
  LD A,($BD4D)
  OR A
  JP Z,$60B7
  CALL $65DA
  CALL $6F99
  LD A,$0A
  LD ($BD49),A
  LD A,$80
  LD ($BCA0),A
  CALL $7810
  JP Z,$6588
  CALL $6F77
  LD A,$FF
  LD ($C058),A
  LD A,($BCD4)
  OR A
  JR NZ,$6F20
  CALL $7065
  CALL $729D
  JP $60A7

; Routine at 6F23
;
; Used by the routines at 65A8 and 6D4D.
  LD B,$06
  CP (HL)
  RET Z
  INC HL
  INC HL
  INC HL
  DJNZ $6F25
  SCF
  RET

; Data block at 6F2E
  DEFB $00,$4B,$00,$09,$51,$08,$05,$52
  DEFB $10,$83,$42,$20,$03,$4E,$30,$01
  DEFB $50,$40,$28,$43,$29,$20,$31,$39
  DEFB $38,$32,$20,$49,$6E,$74,$65,$6C
  DEFB $6C,$69,$67,$65,$6E,$74,$20,$53
  DEFB $6F,$66,$74,$77,$61,$72,$65,$20
  DEFB $4C,$74,$64,$2E,$41,$75,$74,$68
  DEFB $6F,$72,$20,$3A,$20,$52,$69,$63
  DEFB $68,$61,$72,$64,$20,$4C,$61,$6E
  DEFB $67

; Routine at 6F77
;
; Used by the routine at 6D4D.
  LD A,($BD2D)
  LD ($C005),A
  LD A,($BD49)
  LD ($C006),A
  LD HL,$BE00
  LD DE,$C007
  LD B,$20
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
  DJNZ $6F8B
  RET

; Routine at 6F99
;
; Used by the routines at 68A0 and 6D4D.
  XOR A
  LD ($BD0A),A
  LD ($BD0D),A
  LD HL,$BD59
  LD B,$06
  LD (HL),A
  INC L
  DJNZ $6FA5
  RET

; Routine at 6FAA
;
; Used by the routines at 6000, 6678 and 7BF1.
  LD A,$FF
  LD ($BF00),A
  RET

; Routine at 6FB0
;
; Used by the routines at 6000, 63B1, 6734, 675A, 677E, 70C7, 73A8 and 7BF1.
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
  LD B,(HL)
  XOR $10
  LD C,A
  LD A,($BCD3)
  OR A
  LD A,C
  JR NZ,$6FD4
  OUT ($FE),A
  DEC E
  JR NZ,$6FD9
  DEC D
  RET Z
  DJNZ $6FD4
  JR $6FC7

; Routine at 6FDD
;
; Used by the routines at 6000, 7004, 703F, 7046, 704D, 73F7, 73FE, 7405, 740E,
; 746E, 751B and 756E.
  POP HL
  PUSH AF
  CALL $6FE4
  POP AF
  JP (HL)

; Routine at 6FE4
;
; Used by the routines at 6FDD and 7415.
  LD A,(HL)
  LD ($BCC5),A
  INC HL
  LD A,(HL)
  LD ($BCC6),A
  INC HL
  RET

; Routine at 6FEF
;
; Used by the routines at 6000, 63B1, 6985, 69B3, 6BBA, 6D4D, 73AE and 73D4.
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
  JR $7012

; Routine at 7004
;
; Used by the routine at 6000.
  CALL $6FDD
  DEFB $00,$00            ; Inline arguments
  LD A,$38
  LD ($BCC4),A
  LD C,$12
  LD B,$20
; This entry point is used by the routine at 6FEF.
  LD A,$20
  CALL $7226
  DJNZ $7012
  DEC C
  JR NZ,$7010
  RET

; Routine at 701D
;
; Used by the routines at 6000 and 6D4D.
  CALL $7415
  DEFB $05,$00            ; Inline arguments
  DEFM "           "
  DEFB $A0                ; Last character (bit 7 set)
  CALL $7415
  DEFB $06,$04            ; Inline arguments
  DEFM "          "
  DEFB $A0                ; Last character (bit 7 set)
  RET

; Routine at 703F
;
; Used by the routines at 6000, 63B1, 6734, 69B3, 6CF4 and 6D4D.
  CALL $6FDD
  DEFB $0C,$00            ; Inline arguments
  JR $7052

; Routine at 7046
;
; Used by the routines at 6000, 6869 and 6D4D.
  CALL $6FDD
  DEFB $0B,$00            ; Inline arguments
  JR $7052

; Routine at 704D
;
; Used by the routines at 6000, 63B1, 6869, 6985, 69B3, 6BBA and 7BF1.
  CALL $6FDD
  DEFB $0A,$00            ; Inline arguments
; This entry point is used by the routines at 703F and 7046.
  CALL $741A
  DEFM "              "
  DEFB $A0                ; Last character (bit 7 set)
  RET

; Routine at 7065
;
; Used by the routines at 6000, 69B3 and 6D4D.
  CALL $7071
  LD A,$3D
  LD B,$20
  CALL $734D
  DJNZ $706C

; Routine at 7071
;
; Used by the routines at 7065, 729D, 743B and 7452.
  PUSH AF
  PUSH BC
  PUSH HL
  LD HL,$5B00
  XOR A
  OUT ($FB),A
  LD B,$08
  IN A,($FB)
  AND $80
  JR Z,$707C
  LD C,$20
  CALL $70A9
  LD A,L
  ADD A,$08
  LD L,A
  DEC C
  JR NZ,$7084
  INC HL
  DJNZ $707C
  LD A,$04
  OUT ($FB),A
  CALL $709C
  POP HL
  POP BC
  POP AF
  RET

; Routine at 709C
;
; Used by the routines at 6000 and 7071.
  XOR A
  LD ($BCDC),A
  LD B,A
  LD HL,$5B00
  LD (HL),A
  INC HL
  DJNZ $70A4
  RET

; Routine at 70A9
;
; Used by the routine at 7071.
  PUSH BC
  LD B,$08
  IN A,($FB)
  AND $01
  JR Z,$70AC
  XOR A
  RL (HL)
  JR NC,$70B9
  SET 7,A
  OUT ($FB),A
  DJNZ $70AC
  POP BC
  RET

; Routine at 70BF
;
; Used by the routines at 6000 and 6678.
  LD A,(IX+$01)
  CALL $70E1
  JR $70CD

; Routine at 70C7
;
; Used by the routines at 6000 and 6678.
  LD A,(IX+$02)
  CALL $70E1
; This entry point is used by the routine at 70BF.
  CALL $6FB0
  DEFB $96,$28            ; Inline arguments
  RET

; Routine at 70D3
;
; Used by the routines at 6000 and 6D4D.
  LD A,($BD2D)
  RRA
  LD A,$10
  JR NC,$70E1
  LD A,$60
  JR $70E1

; Routine at 70DF
;
; Used by the routines at 6000, 63B1, 68A0 and 6B97.
  LD A,$FF

; Routine at 70E1
;
; Used by the routines at 677E, 70BF, 70C7 and 70D3.
  LD ($BCCA),A

; Routine at 70E4
;
; Used by the routines at 677E and 6D4D.
  EXX
  LD H,$BE
  EXX
  LD HL,$BD00
  LD B,$00
  LD C,$10
  LD A,L
  AND $11
  OR A
  JR Z,$70F7
  CP $11
  LD A,($BCDA)
  JR Z,$70FF
  LD A,($BCD9)
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
  JR Z,$711A
  LD A,$77
  SUB L
  LD L,A
  LD A,($BCCA)
  CP L
  JR NZ,$7128
  LD A,($BCC4)
  OR $80
  LD ($BCC4),A
  LD A,(HL)
  POP HL
  EXX
  OR A
  JR NZ,$7137
  CALL $7200
  JR NZ,$7153
  JR NZ,$7155
  JR $719B
  LD D,A
  AND $F8
  INC A
  LD L,A
  BIT 7,L
  JR Z,$714D
  LD A,($BCC4)
  AND $F8
  LD E,A
  LD A,($BCD8)
  OR E
  LD ($BCC4),A
  LD A,D
  AND $7F
  CP $43
  JR Z,$7166
  LD A,$0F
  AND (HL)
  JR NZ,$7162
  CALL $7200
  AND H
  AND L
  AND D
  AND E
  JR $719B
  CP $01
  JR NZ,$716F
  CALL $7200
  SUB B
  SUB C
  SUB D
  SUB E
  JR $719B
  CP $05
  JR NZ,$717C
  CALL $7200
  SBC A,H
  SBC A,L
  SBC A,(HL)
  SBC A,A
  JR $719B
  JR C,$7187
  CALL $7200
  AND B
  AND C
  AND D
  AND E
  JR $719B
  BIT 7,(HL)
  JR NZ,$7194
  CALL $7200
  SUB H
  SUB L
  SUB (HL)
  SUB A
  JR $719B
  CALL $7200
  SBC A,B
  SBC A,C
  SBC A,D
  SBC A,E
  EXX
  INC C
  INC C
  INC HL
  BIT 3,L
  JP Z,$70EF
  INC B
  INC B
  LD DE,$0008
  ADD HL,DE
  BIT 7,L
  JP Z,$70ED
  LD A,$01
  LD ($BCC5),A
  LD A,$0F
  LD ($BCC6),A
  LD A,$38
  LD ($BCC4),A
  LD B,$08
  LD C,$00
  LD A,($BCC7)
  OR A
  LD A,C
  JR NZ,$71CC
  LD A,$07
  SUB C
  ADD A,$31
  CALL $7226
  LD HL,$BCC6
  DEC (HL)
  LD HL,$BCC5
  INC (HL)
  INC (HL)
  INC C
  DJNZ $71C2
  LD A,$10
  LD ($BCC5),A
  LD ($BCC6),A
  LD B,$08
  LD C,$00
  LD A,($BCC7)
  OR A
  LD A,C
  JR Z,$71F3
  LD A,$07
  SUB C
  ADD A,$41
  CALL $7226
  LD HL,$BCC6
  INC (HL)
  INC C
  DJNZ $71E9
  RET

; Routine at 7200
;
; Used by the routine at 70E4.
  EXX
  LD A,B
  LD ($BCC5),A
  LD A,C
  LD ($BCC6),A
  EXX
  EX (SP),HL
  CALL $7224
  CALL $7224
  EXX
  LD A,B
  INC A
  LD ($BCC5),A
  LD A,C
  LD ($BCC6),A
  EXX
  CALL $7224
  CALL $7224
  EX (SP),HL
  RET

; Routine at 7224
;
; Used by the routine at 7200.
  LD A,(HL)
  INC HL

; Routine at 7226
;
; Used by the routines at 7004, 70E4, 737C and 741A.
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
  JR NC,$7259
  LD BC,($BCD5)
  JP $725C
  LD BC,$714C
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
  LD A,(DE)
  LD (HL),A
  INC DE
  INC H
  DJNZ $7280
  LD A,($BCC6)
  INC A
  CP $20
  JR C,$7293
  XOR A
  LD HL,$BCC5
  INC (HL)
  LD ($BCC6),A
  POP HL
  POP DE
  POP BC
  POP AF
  RET

; Routine at 729B
;
; Used by the routines at 749F, 74FB and 751B.
  JP (IY)

; Routine at 729D
;
; Used by the routines at 68A0, 69B3 and 6D4D.
  EXX
  LD H,$BE
  EXX
  LD HL,$BD00
  CALL $7071
  LD B,$08
  DEC B
  LD A,$20
  CALL $734D
  CALL $734D
  LD A,($BCC7)
  OR A
  LD A,B
  JR Z,$72BC
  LD A,$07
  SUB B
  ADD A,$31
  CALL $734D
  LD A,$20
  CALL $734D
  PUSH HL
  LD A,($BCC7)
  OR A
  JR Z,$72D1
  LD A,$77
  SUB L
  LD L,A
  LD A,(HL)
  POP HL
  EXX
  OR A
  JR NZ,$72DB
  LD A,$2E
  JR $7305
  AND $F8
  INC A
  LD L,A
  LD A,$0F
  AND (HL)
  LD C,$4B
  JR Z,$72FE
  CP $01
  LD C,$50
  JR Z,$72FE
  CP $05
  LD C,$52
  JR Z,$72FE
  LD C,$51
  JR NC,$72FE
  BIT 7,(HL)
  LD C,$4E
  JR Z,$72FE
  LD C,$42
  LD A,C
  BIT 7,L
  JR NZ,$7305
  OR $20
  CALL $734D
  EXX
  INC HL
  BIT 3,L
  JR Z,$72C1
  CALL $7071
  CALL $7071
  LD DE,$0008
  ADD HL,DE
  BIT 7,L
  JP Z,$72A9
  LD A,$20
  CALL $734D
  CALL $734D
  CALL $734D
  LD B,$08
  LD C,$00
  LD A,$20
  CALL $734D
  LD A,($BCC7)
  OR A
  LD A,C
  JR Z,$733B
  LD A,$07
  SUB C
  ADD A,$41
  CALL $734D
  LD HL,$BCC6
  INC (HL)
  INC C
  DJNZ $732C
  CALL $7071
  JP $7071

; Routine at 734D
;
; Used by the routines at 7065, 729D and 743B.
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
  LD A,(DE)
  LD (HL),A
  INC DE
  INC HL
  DJNZ $736D
  LD HL,$BCDC
  INC (HL)
  POP HL
  POP DE
  POP BC
  POP AF
  RET

; Routine at 737C
;
; Used by the routines at 6000 and 6916.
  CALL $7415
  DEFB $0E,$00            ; Inline arguments
  DEFM "LEVEL"
  DEFB $A0                ; Last character (bit 7 set)
  LD A,($BCCD)
  PUSH AF
  AND $08
  LD A,$20
  JR Z,$7393
  LD A,$50
  CALL $7226
  POP AF
  AND $07
  ADD A,$31
  JP $7226

; Routine at 739E
;
; Used by the routines at 6000 and 6560.
  CALL $73F7
  DEFM "ILLEGA"
  DEFB $CC                ; Last character (bit 7 set)

; Routine at 73A8
;
; Used by the routines at 6000, 69B3 and 6CF4.
  CALL $6FB0
  DEFB $FF,$80            ; Inline arguments
  RET

; Routine at 73AE
;
; Used by the routines at 6000, 6800 and 6869.
  CALL $7405
  DEFM "-Hit any key to restore control"
  DEFB $AD                ; Last character (bit 7 set)
  JP $6FEF

; Routine at 73D4
;
; Used by the routine at 6BBA.
  CALL $7405
  DEFM "   --Hit BREAK key to abort-"
  DEFB $AD                ; Last character (bit 7 set)
  JP $6FEF

; Routine at 73F7
;
; Used by the routines at 6000, 63B1, 6734, 6869, 69B3, 6CF4 and 739E.
  CALL $6FDD
  DEFB $0C,$00            ; Inline arguments
  JR $741A

; Routine at 73FE
;
; Used by the routines at 63B1, 69B3 and 6D4D.
  CALL $6FDD
  DEFB $0B,$00            ; Inline arguments
  JR $741A

; Routine at 7405
;
; Used by the routines at 6000, 63B1, 6985, 69B3, 6BBA, 6D4D, 73AE and 73D4.
  CALL $6FDD
  DEFB $12,$00            ; Inline arguments
  LD A,$28
  JR $741C

; Routine at 740E
;
; Used by the routines at 6000, 6985, 69B3, 6BBA, 6D4D and 7BF1.
  CALL $6FDD
  DEFB $0A,$00            ; Inline arguments
  JR $741A

; Routine at 7415
;
; Used by the routines at 6000, 701D, 737C, 746E, 759A and 75B4.
  POP HL
  CALL $6FE4
  PUSH HL

; Routine at 741A
;
; Used by the routines at 704D, 73F7, 73FE, 740E, 756E, 7586, 759A and 75B4.
  LD A,$38
; This entry point is used by the routine at 7405.
  LD ($BCC4),A
  POP HL
  LD A,(HL)
  AND $7F
  CALL $7226
  BIT 7,(HL)
  INC HL
  JR Z,$7420
  JP (HL)

; Routine at 742C
;
; Used by the routine at 63B1.
  LD A,($BCD4)
  OR A
  JR Z,$7437
  LD A,($BCDB)
  OR A
  RET Z
  LD A,$07
  JR $7441

; Routine at 743B
;
; Used by the routines at 6869, 68A0, 6916, 69B3 and 6BBA.
  LD A,($BCD4)
  OR A
  RET NZ
  XOR A
; This entry point is used by the routine at 742C.
  LD ($BCDC),A
  LD A,(HL)
  AND $7F
  CALL $734D
  BIT 7,(HL)
  INC HL
  JR Z,$7444
  JP $7071

; Routine at 7452
;
; Used by the routines at 6000 and 6678.
  LD IY,$734D
  LD A,($BD2D)
  RRA
  JR NC,$7463
  CALL $7511
  LD A,$04
  JR $7465
  LD A,$0E
  LD ($BCDC),A
  CALL $749F
  JP $7071

; Routine at 746E
;
; Used by the routines at 6000 and 6678.
  LD IY,$7226
  LD A,$38
  LD ($BCC4),A
  CALL $751B
  LD A,($BD2D)
  RRA
  JR NC,$7497
  CALL $7415
  DEFB $06,$04            ; Inline arguments
  DEFM "          "
  DEFB $A0                ; Last character (bit 7 set)
  CALL $6FDD
  DEFB $05,$04            ; Inline arguments
  JR $749F
  CALL $7415
  DEFB $06,$04            ; Inline arguments
  DEFM ".."
  DEFB $AE                ; Last character (bit 7 set)

; Routine at 749F
;
; Used by the routines at 7452 and 746E.
  LD A,(IX+$01)
  CALL $74FB
  LD A,$2D
  BIT 3,(IX+$03)
  JR Z,$74AF
  LD A,$78
  CALL $729B
  LD A,(IX+$02)
  CALL $74FB
  LD HL,$BCDE
  LD A,(HL)
  OR A
  JR Z,$74DD
  LD A,$2F
  CALL $729B
  LD A,(HL)
  AND $0F
  CP $05
  LD C,$52
  JR Z,$74D9
  LD C,$51
  JR NC,$74D9
  BIT 7,(HL)
  LD C,$4E
  JR Z,$74D9
  LD C,$42
  LD A,C
  CALL $729B
  BIT 7,(IX+$03)
  LD A,$20
  JR Z,$74E7
  LD A,$2B
  CALL $729B
  LD A,($BCDE)
  OR A
  LD A,$20
  CALL Z,$729B
  CALL Z,$729B
  RET

; Routine at 74F7
;
; Used by the routine at 6000.
  LD IY,$7226

; Routine at 74FB
;
; Used by the routine at 749F.
  LD B,A
  AND $07
  ADD A,$41
  CALL $729B
  LD A,$70
  AND B
  RRA
  RRA
  RRA
  RRA
  NEG
  ADD A,$38
  JP $729B

; Routine at 7511
;
; Used by the routine at 7452.
  LD IY,$734D
  XOR A
  LD ($BCDC),A
  JR $7524

; Routine at 751B
;
; Used by the routine at 746E.
  LD IY,$7226
  CALL $6FDD
  DEFB $05,$00            ; Inline arguments
; This entry point is used by the routine at 7511.
  LD A,($BD49)
  LD B,$FF
  INC B
  SUB $0A
  JR NC,$7529
  PUSH AF
  LD A,B
  CP $0A
  JR C,$7548
  LD B,$FF
  INC B
  SUB $0A
  JR NC,$7536
  PUSH AF
  LD A,B
  ADD A,$30
  CALL $729B
  POP AF
  ADD A,$0A
  JP $7552
  PUSH AF
  LD A,$20
  CALL $729B
  POP AF
  OR A
  JR Z,$7557
  ADD A,$30
  CALL $729B
  POP AF
  ADD A,$3A
  CALL $729B
  LD A,$20
  JP $729B

; Routine at 7562
;
; Used by the routines at 6000, 63B1, 78BA and 7BF1.
  LD A,($BCBE)
  OR A
  LD A,$02
  JR Z,$756B
  DEC A
  LD ($BCC2),A

; Routine at 756E
;
; Used by the routines at 6000 and 6800.
  CALL $6FDD
  DEFB $00,$01            ; Inline arguments
  LD A,($BCC2)
  AND $02
  CALL $7586
  CALL $741A
  DEFM " v"
  DEFB $A0                ; Last character (bit 7 set)
  LD A,($BCC2)
  AND $01

; Routine at 7586
;
; Used by the routine at 756E.
  JR Z,$7591
  CALL $741A
  DEFM "CYRU"
  DEFB $D3                ; Last character (bit 7 set)
  RET
  CALL $741A
  DEFM "HUMA"
  DEFB $CE                ; Last character (bit 7 set)
  RET

; Routine at 759A
;
; Used by the routines at 6000 and 69B3.
  CALL $7415
  DEFB $10,$00            ; Inline arguments
  DEFM "LISTING"
  DEFB $A0                ; Last character (bit 7 set)
  LD A,($BCD4)
  OR A
  JR Z,$75C5
; This entry point is used by the routine at 75B4.
  CALL $741A
  DEFM "OF"
  DEFB $C6                ; Last character (bit 7 set)
  RET

; Routine at 75B4
;
; Used by the routines at 6000 and 677E.
  CALL $7415
  DEFB $0F,$00            ; Inline arguments
  DEFM "SOUND"
  DEFB $A0                ; Last character (bit 7 set)
  LD A,($BCD3)
  OR A
  JR NZ,$75AD
; This entry point is used by the routine at 759A.
  CALL $741A
  DEFM "ON"
  DEFB $A0                ; Last character (bit 7 set)
  RET

; Data block at 75CC
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
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$0E,$12,$1F,$21
  DEFB $F2,$EE,$E1,$DF,$0F,$11,$EF,$F1
  DEFB $01,$FF,$10,$F0

; Routine at 7810
;
; Used by the routines at 6D4D and 7BE1.
  LD IX,$BD58
  LD A,($BD2D)
  XOR $01
  LD ($BD2D),A
  CALL $8400
  PUSH AF
  LD A,($BCA0)
  ADD A,$80
  LD E,A
  LD A,($BCBE)
  OR A
  JR Z,$7832
  XOR A
  SUB B
  LD B,A
  XOR A
  SUB E
  LD E,A
  LD A,($BD2E)
  SRA A
  SRA E
  ADD A,E
  SRA A
  SRA A
  JR Z,$7841
  INC A
  LD ($BD1E),A
  LD A,($BD4A)
  ADD A,B
  LD ($BD4A),A
  LD HL,$BE08
  XOR A
  LD ($BD6D),A
  CALL $789D
  LD E,C
  LD L,$88
  CALL $789D
  LD A,C
  SUB E
  CP $0E
  JR C,$786C
  CP $F2
  JR NC,$786C
  RLA
  LD A,$0E
  JR NC,$786C
  LD A,$F2
  ADD A,A
  ADD A,A
  ADD A,A
  LD ($BD2E),A
  LD A,($BD49)
  LD B,$00
  CP $08
  JR C,$7891
  LD A,C
  ADD A,E
  SET 1,B
  CP $34
  JR NC,$7891
  SET 2,B
  CP $28
  JR NC,$7891
  SET 3,B
  CP $19
  JR NC,$7891
  SET 4,B
  LD HL,$BD2D
  LD A,(HL)
  INC A
  AND $01
  ADD A,B
  LD (HL),A
  POP AF
  OR A
  RET

; Routine at 789D
;
; Used by the routine at 7810.
  LD C,$00
  LD B,$0F
  BIT 7,(HL)
  JR NZ,$78B3
  INC L
  LD A,(HL)
  AND $0F
  CP $01
  JR NZ,$78B0
  LD ($BD6D),A
  ADD A,C
  LD C,A
  DEC L
  LD A,$08
  ADD A,L
  LD L,A
  DJNZ $78A1
  RET

; Routine at 78BA
;
; Used by the routine at 7D43.
  LD HL,$BD4C
  BIT 7,(HL)
  JR NZ,$78CE
  CALL $6734
  JR Z,$78CE
  LD HL,$BD4C
  SET 7,(HL)
  CALL $7562

; Routine at 78CE
;
; Used by the routines at 6000, 6678, 78BA and 7BF1.
  LD HL,$BCA9
  LD A,(HL)
  ADD A,A
  ADD A,L
  LD L,A
  LD E,(HL)
  INC L
  LD D,(HL)
  INC L
  PUSH DE
  INC E
  INC E
  INC E
  INC DE
  PUSH HL
  EX AF,AF'
  LD A,$BC
  EX AF,AF'
  LD H,$BD
  LD IY,$BE00
  LD A,($BD2D)
  EXX
  RRCA
  LD C,A
  EXX
  JR NC,$78F6
  LD IY,$BE80
  LD B,(IY+$00)
  BIT 4,(IY+$01)
  CALL Z,$7A61
  LD C,$88
  EXX
  LD DE,$7808
  CALL $7A18
  LD A,(IY+$08)
  OR A
  CALL P,$7A57
  LD A,(IY+$10)
  OR A
  CALL P,$7A2E
  LD A,(IY+$18)
  OR A
  CALL P,$7A2E
  LD A,(IY+$20)
  OR A
  CALL P,$7A4F
  LD A,(IY+$28)
  OR A
  CALL P,$7A4F
  LD A,(IY+$30)
  LD C,$88
  OR A
  CALL P,$7A13
  LD A,(IY+$38)
  OR A
  CALL P,$7A13
  LD C,$11
  EXX
  LD HL,$BE40
  BIT 7,C
  JR Z,$794C
  LD L,$C0
  EXX
  LD C,$F1
  EXX
  LD A,(HL)
  RLA
  JR C,$799C
  INC L
  LD A,(HL)
  DEC L
  AND $0E
  LD A,(HL)
  EXX
  LD B,A
  JR NZ,$79C8
  ADD A,C
  LD L,A
  XOR A
  OR (HL)
  CALL NZ,$7A97
  DEC L
  DEC L
  XOR A
  OR (HL)
  CALL NZ,$7A97
  INC L
  XOR A
  OR (HL)
  JR NZ,$7994
  CALL $7A9D
  LD A,B
  ADD A,$20
  BIT 6,A
  JR NZ,$7994
  LD A,C
  DEC A
  ADD A,L
  JP M,$799B
  LD L,A
  XOR A
  OR (HL)
  JR NZ,$799B
  CALL $7A9D
  DEC L
  OR (HL)
  CALL NZ,$79FC
  INC L
  INC L
  LD A,(HL)
  OR A
  CALL NZ,$79FC
  JP $799B
  BIT 5,(IX+$03)
  CALL NZ,$79E4
  EXX
  LD A,$08
  ADD A,L
  LD L,A
  BIT 6,A
  JP NZ,$794C
  EXX
  LD A,$FF
  LD (DE),A
  POP HL
  LD (HL),E
  INC L
  LD (HL),D
  POP HL
  EX DE,HL
  OR A
  SBC HL,DE
  RR H
  RR L
  RR L
  DEC L
  EX DE,HL
  LD (HL),A
  INC L
  LD (HL),E
  INC L
  LD (HL),$00
  INC L
  LD A,(IX+$03)
  AND $81
  LD (HL),A
  RET
  PUSH BC
  LD C,$88
  EXX
  INC L
  LD A,(HL)
  DEC L
  LD DE,$79E0
  PUSH DE
  OR A
  JP M,$7A51
  RRA
  RRA
  JR C,$7A15
  RRA
  JR C,$7A30
  JR $7A59

; Data block at 79E0
  DEFB $C1,$D9,$18,$B8

; Routine at 79E4
;
; Used by the routine at 78CE.
  BIT 3,(IX+$03)
  RET NZ
  LD A,(IX+$02)
  INC A
  CP B
  JR Z,$79F6
  DEC A
  DEC A
  CP B
  RET NZ
  INC L
  INC L
  DEC L
  LD A,$28
  JP $7A9D

; Routine at 79FC
;
; Used by the routine at 78CE.
  EXX
  XOR C
  EXX
  RET P
  LD A,(HL)
  EXX
  LD B,L
  SUB $03
  LD L,A
  LD A,(HL)
  LD L,B
  EXX
  AND $0F
  DEC A
  RET NZ
  LD A,$20
  DEC DE
  LD (DE),A
  INC DE
  RET

; Routine at 7A13
;
; Used by the routine at 78CE.
  LD B,A
  EXX
; This entry point is used by the routine at 78CE.
  LD DE,$7800

; Routine at 7A18
;
; Used by the routine at 78CE.
  LD B,$08
  LD A,(DE)
  INC E
  EXX
  ADD A,B
  LD L,A
  AND C
  JR NZ,$7A29
  OR (HL)
  CALL Z,$7A9D
  CALL NZ,$7A97
  EXX
  DJNZ $7A1A
  EXX
  RET

; Routine at 7A2E
;
; Used by the routine at 78CE.
  LD B,A
  EXX
; This entry point is used by the routine at 78CE.
  LD DE,$780C
; This entry point is used by the routine at 7A4F.
  LD B,$04
; This entry point is used by the routine at 7A57.
  LD A,(DE)
  INC E
  EXX
  LD C,A
  LD L,B
  LD A,L
  ADD A,C
  LD L,A
  AND $88
  JR NZ,$7A4A
  OR (HL)
  CALL Z,$7A9D
  JR Z,$7A3A
  CALL $7A97
  EXX
  DJNZ $7A35
  EXX
  RET

; Routine at 7A4F
;
; Used by the routine at 78CE.
  LD B,A
  EXX
; This entry point is used by the routine at 78CE.
  LD DE,$7808
  JP $7A33

; Routine at 7A57
;
; Used by the routine at 78CE.
  LD B,A
  EXX
; This entry point is used by the routine at 78CE.
  LD DE,$7808
  LD B,$08
  JP $7A35

; Routine at 7A61
;
; Used by the routine at 78CE.
  BIT 7,(IX+$03)
  RET NZ
  BIT 4,(IY+$19)
  JR NZ,$7A7D
  BIT 7,(IY+$18)
  JR NZ,$7A7D
  XOR A
  LD L,B
  INC L
  OR (HL)
  JR NZ,$7A7D
  INC L
  OR (HL)
  CALL Z,$7A93
  BIT 4,(IY+$11)
  RET NZ
  BIT 7,(IY+$10)
  RET NZ
  LD L,B
  XOR A
  DEC L
  OR (HL)
  RET NZ
  DEC L
  OR (HL)
  RET NZ
  DEC L
  OR (HL)
  RET NZ
  INC L

; Routine at 7A93
;
; Used by the routine at 7A61.
  LD A,$10
  JR $7A9D

; Routine at 7A97
;
; Used by the routines at 78CE, 7A18 and 7A2E.
  EXX
  XOR C
  EXX
  RET P
  LD A,$08

; Routine at 7A9D
;
; Used by the routines at 78CE, 79E4, 7A18, 7A2E and 7A93.
  EX AF,AF'
  CP D
  JR Z,$7AAF
  EX AF,AF'
  EX DE,HL
  LD (HL),$FF
  INC L
  LD (HL),B
  INC L
  LD (HL),E
  INC L
  LD (HL),A
  INC HL
  EX DE,HL
  OR A
  RET
  LD A,$80
  CP E
  LD A,$BC
  JR NC,$7AA1
  PUSH HL
  LD HL,$BD4C
  SET 7,(HL)
  POP HL
  EX AF,AF'
  OR A
  RET
; This entry point is used by the routine at 7AC7.
  LD A,$FF
  LD ($BCDF),A
  OR A
  RET

; Routine at 7AC7
;
; Used by the routine at 7BF1.
  LD A,($BCDF)
  OR A
  RET NZ
  LD A,($C006)
  DEC A
  RET NZ
  CALL $7B89
  LD HL,$FFFF
  INC HL
  LD A,($C001)
  LD C,A
  LD A,($BCDF)
  INC A
  LD ($BCDF),A
  DEC A
  CP C
  JR Z,$7B05
  LD BC,$C058
  ADD A,C
  LD C,A
  JR NC,$7AEF
  INC B
  LD A,(BC)
  AND $7F
  LD C,A
  CALL $7B57
  LD B,A
  RES 6,A
  CP C
  JR Z,$7AD7
  BIT 6,B
  JR Z,$7AC0
  CALL $7B4C
  JR $7AF6
  CALL $7B89
  CALL $7B57
  LD C,A
  BIT 6,A
  JR Z,$7B30
  LD A,$01
  RLA
  AND B
  JR NZ,$7B30
  PUSH HL
  CALL $7B89
  CALL $7B4C
  JR C,$7B2B
  POP DE
  LD C,A
  BIT 6,A
  JR Z,$7B30
  RR B
  JR C,$7B16
  JR $7B30
  POP HL
  CALL $7B57
  LD C,A
  LD A,C
  AND $3F
  RLA
  RLA
  LD E,A
  LD D,$00
  LD IX,$B404
  ADD IX,DE
  LD ($BD29),IX
  XOR A
  BIT 7,C
  JR NZ,$7B4A
  LD ($BCDF),A
  XOR A
  RET

; Routine at 7B4C
;
; Used by the routine at 7AC7.
  LD DE,$FFFF
  CALL $7B57
  INC HL
  BIT 7,D
  JR Z,$7B4F

; Routine at 7B57
;
; Used by the routines at 7AC7 and 7B4C.
  CALL $7B64
  BIT 7,A
  JR Z,$7B5F
  DEC DE
  BIT 6,A
  RET Z
  INC DE
  RET

; Routine at 7B64
;
; Used by the routine at 7B57.
  PUSH BC
  PUSH HL
  LD A,L
  SRL H
  RRA
  SRL H
  RRA
  SRL H
  RRA
  LD B,H
  LD C,A
  POP HL
  PUSH HL
  LD A,$07
  AND L
  ADD HL,BC
  LD BC,$9000
  ADD HL,BC
  LD B,A
  INC B
  LD A,(HL)
  INC HL
  LD C,(HL)
  RL C
  RLA
  DJNZ $7B81
  POP HL
  POP BC
  RET

; Routine at 7B89
;
; Used by the routine at 7AC7.
  LD A,R
  LD B,A
  LD A,($BCCE)
  XOR B
  RRA
  LD ($BCCE),A
  LD B,A
  RET

; Routine at 7B96
;
; Used by the routines at 6000, 7BF1 and 7D43.
  INC HL
  PUSH HL
  POP IX
  XOR A
  LD ($BD19),A
  INC E
  LD A,E
  LD ($BD0E),A
  LD HL,$BD0E
  DEC (HL)
  RET Z
  LD B,(IX+$00)
  INC B
  JR NZ,$7BC5
  CALL $810F
  CALL $8400
  LD (IX+$00),A
  LD HL,$BD19
  CP (HL)
  JR C,$7BC2
  LD (HL),A
  LD ($BD1A),IX
  CALL $821C
  LD BC,$0004
  ADD IX,BC
  JP $7BA3

; Routine at 7BCD
;
; Used by the routines at 6000, 7BF1 and 7D43.
  LD DE,$0004
  ADD HL,DE
  CP (HL)
  JR Z,$7BD8
  DJNZ $7BD0
  SCF
  RET
  EX AF,AF'
  DEC L
  CP (HL)
  RET Z
  INC L
  EX AF,AF'
  JP $7BD4

; Routine at 7BE1
;
; Used by the routines at 6000 and 7BF1.
  CALL $7810
  CALL $7BF1
  LD A,($BD6E)
  OR A
  JR NZ,$7BE4
  RET
; This entry point is used by the routine at 7BF1.
  POP HL
  SCF
  RET

; Routine at 7BF1
;
; Used by the routine at 7BE1.
  LD IX,$BD58
  LD HL,$BC91
  LD A,$FF
  LD ($BD0C),A
  LD B,$0D
  LD (HL),A
  INC L
  DJNZ $7BFF
  INC A
  LD ($BD0D),A
  LD HL,$BC9F
  LD B,$09
  LD (HL),A
  INC L
  DJNZ $7C0C
  CALL $78CE
  SET 5,(HL)
  CALL $7B96
  LD A,($BCDD)
  OR A
  JR NZ,$7C2A
  CALL $7AC7
  JR NZ,$7C2A
  CALL $6734
  RET Z
  JP $7562
  LD A,($BD19)
  OR A
  JP Z,$7BEE
  LD D,A
  LD A,($BD6E)
  OR A
  JR Z,$7C49
  LD HL,($BD29)
  LD (HL),$FD
  LD ($BD1A),HL
  XOR A
  LD ($BD6E),A
  LD A,($BCBD)
  JR $7C5B
  LD HL,($BD1A)
  LD ($BD29),HL
  LD A,($BCBD)
  CP $05
  JR C,$7C5B
  LD A,$01
  LD ($BD6E),A
  LD HL,$BDF6
  LD (HL),$00
  LD ($BD09),A
  BIT 1,A
  JR Z,$7C71
  LD (HL),A
  BIT 0,A
  JR Z,$7C71
  LD HL,$BD09
  SET 7,(HL)
  LD HL,$BCAA
  LD (HL),$01
  OR A
  JR Z,$7C83
  INC (HL)
  CP $04
  JR C,$7C83
  LD (HL),$03
  JR Z,$7C83
  INC (HL)
  LD B,$07
  LD A,($BD09)
  RLA
  JR C,$7CBA
  LD A,D
  LD HL,$B403
  BIT 7,(HL)
  JR NZ,$7CB4
  CALL $805F
  SRL D
  SRL D
  DEC D
  SRL D
  LD B,$0B
  LD A,($BD2D)
  BIT 4,A
  JR NZ,$7CAE
  DEC B
  SRA A
  DEC A
  JR NZ,$7CAE
  DEC B
  DEC B
  DEC D
  JP M,$7CB4
  DJNZ $7CAE
  LD A,$02
  ADD A,B
  LD ($BD09),A
  LD HL,$BF00
  LD A,(HL)
  CP $FF
  JR Z,$7CD5
  INC HL
  EX AF,AF'
  LD A,(HL)
  INC HL
  PUSH HL
  LD HL,$B401
  LD B,(HL)
  INC L
  CALL $7BCD
  DEC L
  LD (HL),$00
  POP HL
  JR $7CBD
  LD HL,$B403
  CALL $8015
  BIT 0,E
  JR Z,$7D00
  CALL $740E
  DEFM "*NO MORE MOVES"
  DEFB $AA                ; Last character (bit 7 set)
  CALL $6FB0
  DEFB $FF,$40            ; Inline arguments
  CALL $6FAA
  CALL $704D
  POP HL
  JP $7BE1
  LD ($BD1A),DE
  LD A,($BD5E)
  LD C,A
  CP $02
  JP C,$7DCF
  LD HL,($BD5C)
  LD A,H
  EX AF,AF'
  LD A,L
  LD HL,$B401
  LD B,(HL)
  INC L
  CALL $7BCD
  DEC L
  LD A,(HL)
  OR A
  JP Z,$7DCF
  LD (HL),$00
  LD A,($BD2D)
  RRA
  LD A,($BD2E)
  JR NC,$7D2E
  NEG
  ADD A,$7E
  BIT 2,C
  JR Z,$7D36
  SUB $08
  LD ($BCA0),A
  LD ($BD2B),HL
  JP $7E9B

; Message at 7D3F
  DEFM "2",$A0,$BC,$C9

; Routine at 7D43
  CALL $78BA
  LD A,E
  OR A
  JR Z,$7DA8
  LD A,($BCA9)
  LD B,E
  BIT 2,(IX+$03)
  JP NZ,$802B
  BIT 7,(HL)
  JR NZ,$7DA8
  DEC A
  LD DE,$BC91
  ADD A,A
  ADD A,E
  LD E,A
  LD A,(DE)
  OR A
  JP M,$7DA8
  INC E
  EX AF,AF'
  LD A,(DE)
  DEC L
  CALL $7BCD
  JR C,$7DA8
  DEC L
  LD (HL),$00
  PUSH HL
  POP IX
  CALL $810F
; This entry point is used by the routine at 8015.
  CALL $8400
  OR A
  JR Z,$7DA5
  LD C,A
  EX AF,AF'
  LD HL,$BCAA
  LD A,(HL)
  DEC L
  LD B,(HL)
  CP B
  JP C,$7F20
  CALL Z,$80C4
  CALL $8003
  SET 6,(HL)
  EX AF,AF'
  DEC L
  LD (HL),A
  BIT 1,(IX+$03)
  JP Z,$7DEE
  BIT 3,(IX+$03)
  JP NZ,$7DEE
  LD (IX+$00),A
  CALL $821C
; This entry point is used by the routines at 7E8C and 8015.
  LD HL,$BCAA
  LD A,(HL)
  DEC L
  CP (HL)
  JP C,$7EE4
  CALL $8006
  BIT 5,(HL)
  JP NZ,$7DDA
  SET 5,(HL)
  PUSH HL
  CALL $7B96
  POP HL
  LD A,($BD19)
  OR A
  JP Z,$7FEA
  BIT 7,(HL)
  JP NZ,$80E2
  CALL $805F
; This entry point is used by the routine at 7BF1.
  LD IX,($BD1A)
  LD (IX+$00),$00
  JP $7DEB
  BIT 7,(HL)
  JP NZ,$80ED
  CALL $8015
  BIT 0,E
  JR NZ,$7E25
  PUSH DE
  POP IX
  XOR A
  LD (DE),A
  CALL $810F
; This entry point is used by the routine at 7E8C.
  LD A,($BCA9)
  DEC A
  JR Z,$7E06
  ADD A,A
  LD HL,$BC83
  ADD A,L
  LD L,A
  LD A,(IX+$01)
  LD (HL),A
  INC L
  LD A,(IX+$02)
  LD (HL),A
  JP $7E0A
; This entry point is used by the routine at 80C4.
  LD ($BD2B),IX
; This entry point is used by the routine at 80C4.
  LD A,($BD2D)
  XOR $01
  LD ($BD2D),A
  LD HL,$BCA9
  LD A,(HL)
  INC (HL)
  DEC A
  DEC A
  LD HL,$BCA0
  ADD A,L
  LD L,A
  LD A,(HL)
  INC L
  INC L
  LD (HL),A
  JP $7D43
; This entry point is used by the routines at 7E8C and 80C4.
  LD A,($BCA9)
  DEC A
  RET Z
  LD ($BCA9),A
  CALL $821C
  LD A,($BD2D)
  XOR $01
  LD ($BD2D),A
  LD A,($BD4C)
  RLA
  JR C,$7E25
  LD A,($BCA9)
  LD HL,$BCA0
  ADD A,L
  LD L,A
  LD A,(HL)
  NEG
; This entry point is used by the routine at 7E8C.
  DEC L
  DEC L
  CPL
  CP (HL)
  JR C,$7E79
  CPL
  INC L
  CP (HL)
  JP C,$7DA8
  JP Z,$7DA8
  LD (HL),A
  LD A,($BCA9)
  DEC A
  JR Z,$7E95
  ADD A,A
  LD B,A
  LD HL,$BC91
  ADD A,L
  LD L,A
  LD DE,$BC83
  LD A,B
  ADD A,E
  LD E,A
  LD A,(DE)
  OR A
  JP M,$7DA8
  LD (HL),A
  INC E
  INC L
  LD A,(DE)
  LD (HL),A
  JP $7DA8
; This entry point is used by the routine at 80C4.
  CALL $821C
  LD HL,$BCA9
  DEC (HL)
  LD A,($BD2D)
  XOR $01
  LD ($BD2D),A
  LD A,(HL)
  JP $7E5F

; Routine at 7E8C
  LD IX,($BD2B)
  LD ($BD29),IX
  RET
; This entry point is used by the routine at 7D43.
  LD A,($BCA0)
  INC A
  JR Z,$7EA1
; This entry point is used by the routine at 7BF1.
  CALL $7E8C
  JP $7DA8
  LD HL,$BD0B
  LD A,$FE
  LD ($BCA0),A
  LD A,(HL)
  CP $02
  JR Z,$7E8C
  INC L
  CP (HL)
  JP NC,$7DA8
  LD (HL),A
  JR $7E9B
  LD A,($BCB6)
  CP $B4
  LD A,($BCAA)
  JR Z,$7ED3
  CP $03
  JR C,$7F27
  LD L,A
  LD A,($BCB3)
  CP $58
  JR NC,$7F27
  LD A,L
  LD HL,$BCA9
  JP $7F3E
  CP $03
  JR C,$7F27
  INC A
  LD HL,$BCA9
  JP $7F3E
  CALL $821C
  LD HL,$BCA9
; This entry point is used by the routine at 7D43.
  LD A,(HL)
  ADD A,A
  ADD A,L
  LD L,A
  LD ($BD4E),A
  LD E,(HL)
  INC L
  LD D,(HL)
  EX DE,HL
  INC L
  LD A,(HL)
  INC L
  LD C,(HL)
  SUB C
  JP Z,$7E25
  INC (HL)
  INC L
  LD A,(HL)
  LD ($BD4B),A
  INC HL
  LD B,$00
  SLA C
  RL B
  ADD HL,BC
  ADD HL,BC
  INC (HL)
  JR NZ,$7EE1
  PUSH HL
  POP IX
  CALL $810F
  CALL $8400
  LD C,A
  OR A
  JR NZ,$7F20
  LD A,($BD4B)
  INC C
  RLA
  JR C,$7F43
  JP $7EDE
; This entry point is used by the routine at 7D43.
  LD A,($BCB2)
  CP $B4
  JR Z,$7EB6
  LD A,($BD4E)
  OR A
  JR Z,$7F39
  LD A,(IX+$03)
  OR A
  JP P,$7F43
  BIT 2,A
  JP NZ,$7F43
  LD HL,$BCAA
  LD A,(HL)
  DEC L
  INC A
  CP (HL)
  JP NC,$7DEE
  LD A,($BCA9)
  LD HL,$BCA0
  ADD A,L
  LD L,A
  INC C
  LD A,C
  DEC L
  DEC L
  CPL
  CP (HL)
  JR C,$7F81
  INC L
  LD A,(IX+$03)
  AND $42
  JR NZ,$7FAD
  LD A,C
  CP (HL)
  JP C,$7EDE
  JP Z,$7EDE
  LD (HL),A
  LD A,($BD4B)
  RLA
  JP C,$7EDE
  LD A,($BCA9)
  LD HL,$BC91
  DEC A
  ADD A,A
  ADD A,L
  LD L,A
  LD A,(IX+$01)
  LD (HL),A
  INC L
  LD A,(IX+$02)
  LD (HL),A
  JP $7EDE
  CALL $821C
  CALL $821C
  LD A,($BD2D)
  XOR $01
  LD ($BD2D),A
  LD HL,$BCA9
  DEC (HL)
  LD A,($BD4B)
  RLA
  JP C,$7DA8
  LD A,(HL)
  LD HL,$BC91
  ADD A,A
  ADD A,L
  LD L,A
  LD A,(IX+$01)
  LD (HL),A
  INC L
  LD A,(IX+$02)
  LD (HL),A
  JP $7DA8
  LD A,($BCA9)
  LD B,A
  LD A,($BCAA)
  INC A
  INC A
  CP B
  JR C,$7F5B
  LD A,C
  JR Z,$7FC0
  ADD A,$01
  JR C,$7F5B
  CP (HL)
  JP C,$7EDE
  LD A,($BDF6)
  OR A
  JR Z,$7F5B
  LD A,C
  CP $02
  JR Z,$7F5B
  JP $7DEE
  LD A,($BCA9)
  LD HL,$BCA0
  ADD A,L
  LD L,A
  LD A,($BD2D)
  RRA
  LD A,($BD2E)
  JR NC,$7FE5
  NEG
  ADD A,$78
  JP $7E49
; This entry point is used by the routine at 7D43.
  BIT 6,(HL)
  JP NZ,$7E25
  BIT 7,(HL)
  JR Z,$7FD2
  LD A,($BCA9)
  LD ($BD0B),A
  LD HL,$BCA0
  ADD A,L
  LD L,A
  LD A,$01
  JP $7E49

; Routine at 8003
;
; Used by the routines at 7D43, 805F and 80C4.
  LD HL,$BCA9

; Routine at 8006
;
; Used by the routine at 7D43.
  LD A,(HL)
  LD B,A
  ADD A,A
  ADD A,L
  LD L,A
  LD E,(HL)
  INC L
  LD D,(HL)
  EX DE,HL
  INC L
  LD E,(HL)
  INC L
  LD C,(HL)
  INC L
  RET

; Routine at 8015
;
; Used by the routines at 7BF1, 7D43 and 80C4.
  XOR A
  LD BC,$0004
  DEC L
  DEC L
  LD E,L
  DEC L
  ADD HL,BC
  CP (HL)
  JP NC,$801D
  LD A,(HL)
  CP $FF
  RET Z
  LD D,H
  LD E,L
  JP $801D
; This entry point is used by the routine at 7D43.
  LD HL,$BCA9
  INC A
  ADD A,A
  ADD A,L
  LD L,A
  LD E,(HL)
  INC L
  LD D,(HL)
  EX DE,HL
  INC L
  INC L
  LD DE,$FFFC
  LD A,(IX+$02)
  ADD HL,DE
  CP (HL)
  JR Z,$8047
  DJNZ $803E
  JP $7DA8
  LD D,$01
  DEC L
  DEC L
  PUSH HL
  POP IX
  LD (HL),$00
  CALL $810F
  SET 7,(IX+$01)
  LD A,$80
  LD ($BD4B),A
  JP $7D77

; Routine at 805F
;
; Used by the routines at 7BF1 and 7D43.
  LD HL,$BD09
  BIT 7,(HL)
  RET NZ
  LD IY,$80A2
  EX AF,AF'
  CALL $8003
  LD A,B
  CP $03
  LD A,($BD2D)
  JR NC,$807A
  LD A,E
  ADD A,A
  LD D,A
  LD A,$10
  LD B,E
  BIT 4,A
  JR Z,$8083
  LD IY,$80BB
  BIT 3,A
  JR Z,$808B
  LD IY,$80A7
  EX AF,AF'
  CP C
  JR NC,$8090
  LD A,C
  SUB $09
  RET C
  LD C,A
  INC HL
  LD A,(HL)
  INC L
  INC L
  INC L
  SUB C
  JR C,$80A0
; This entry point is used by the routine at 80A7.
  INC HL
  DJNZ $8095
  RET
  JP (IY)

; Data block at 80A2
  DEFB $C6,$10,$FA,$AB,$80

; Routine at 80A7
  BIT 2,(HL)
  JR Z,$809C
  LD A,$C9
  AND (HL)
  JR NZ,$809C
  DEC L
  DEC L
  DEC L
  LD (HL),$00
  INC L
  INC L
  INC L
  JP $809C
  DEC D
  ADD A,$10
  JP P,$809C
  JP $80A7

; Routine at 80C4
;
; Used by the routine at 7D43.
  BIT 0,A
  RET NZ
  LD HL,$BC9E
  ADD A,L
  LD L,A
  LD A,($BD09)
  OR A
  RET M
  SUB C
  RET NC
  CP (HL)
  RET NC
  CALL $8003
  BIT 0,(HL)
  RET NZ
  POP HL
  CALL $821C
  JP $7E79
; This entry point is used by the routine at 7D43.
  LD IX,($BD1A)
  LD (IX+$00),$00
  JP $80FA
; This entry point is used by the routine at 7D43.
  CALL $8015
  BIT 0,E
  JP NZ,$7E25
  PUSH DE
  POP IX
  XOR A
  LD (DE),A
  CALL $810F
  LD A,($BCA9)
  DEC A
  JP Z,$7E06
  ADD A,A
  LD HL,$BC83
  ADD A,L
  LD L,A
  SET 7,(HL)
  JP $7E0A

; Routine at 810F
;
; Used by the routines at 6000, 6678, 7B96, 7D43, 7E8C, 8015 and 80C4.
  POP HL
  EXX
  LD H,$BD
  LD L,(IX+$01)
  LD E,(HL)
  LD D,L
  PUSH DE
  LD (HL),$00
  LD L,(IX+$02)
  LD C,(HL)
  LD (HL),E
  LD B,L
  INC H
  RES 2,E
  LD L,E
  LD (HL),B
  INC L
  LD E,D
  LD D,(HL)
  LD A,$0F
  AND D
  JP Z,$81BF
  DEC A
  JR Z,$813D
  SET 4,(HL)
  DEC C
  INC C
  JR NZ,$81A5
  LD E,$80
  PUSH DE
  EXX
  JP (HL)
  LD A,B
  AND $70
  CP E
  JR NC,$8145
  XOR $70
  SUB $30
  JR C,$8184
  JR Z,$8181
  SUB $10
  JR Z,$817F
  SET 0,(IX+$03)
  SUB $20
  LD A,$61
  JR C,$8183
  LD A,$91
  JR Z,$8183
  RES 0,(IX+$03)
  LD (HL),$19
  LD A,($BD0D)
  BIT 7,L
  JR Z,$816C
  ADD A,$10
  SUB $08
  LD ($BD0D),A
  LD E,$84
  BIT 3,(IX+$03)
  JP Z,$813A
  LD E,$04
  JP $81A7
  ADD A,$20
  ADD A,$11
  LD (HL),A
  LD A,(IX+$03)
  BIT 3,A
  JP Z,$8138
  BIT 5,A
  JP Z,$81A5
  LD A,B
  CP E
  JR NC,$8197
  ADD A,$20
  SUB $10
  DEC H
  LD L,A
  LD C,(HL)
  LD (HL),$00
  INC H
  LD B,L
  LD E,$01
  JP $81A7
  LD E,$00
  PUSH BC
  RES 2,C
  LD L,C
  SET 7,(HL)
  PUSH DE
  INC L
  LD A,$0F
  AND (HL)
  BIT 7,L
  JR Z,$81B8
  NEG
  LD HL,$BD0D
  ADD A,(HL)
  LD (HL),A
  EXX
  JP (HL)
  CALL $8200
  LD A,(IX+$03)
  AND $18
  JP Z,$8138
  AND $08
  JP NZ,$81A5
  SET 5,(HL)
  DEC H
  BIT 2,B
  JR Z,$81E0
  INC B
  LD L,B
  LD C,(HL)
  LD (HL),$00
  DEC L
  DEC L
  JP $81E9
  DEC B
  DEC B
  LD L,B
  LD C,(HL)
  LD (HL),$00
  INC L
  INC L
  INC L
  LD (HL),C
  LD A,(IX+$00)
  INC A
  JR NZ,$81F4
  LD A,$84
  AND C
  LD (HL),A
  PUSH BC
  RES 2,C
  LD B,$BE
  LD A,L
  LD (BC),A
  LD E,$40
  PUSH DE
  EXX
  JP (HL)

; Routine at 8200
;
; Used by the routine at 810F.
  LD A,D
  OR $10
; This entry point is used by the routine at 660A.
  AND $3F
  LD E,$11
  LD (HL),A
  LD A,B
  ADD A,E
  AND $88
  RET NZ
  LD A,B
  SUB E
  AND $88
  RET NZ
  LD A,$11
  ADD A,E
  LD E,A
  LD A,$40
  ADD A,(HL)
  JP $8207

; Routine at 821C
;
; Used by the routines at 7B96, 7D43, 7E8C and 80C4.
  POP HL
  EXX
  POP AF
  POP HL
  LD C,A
  LD A,$00
  LD D,$BD
  CALL PE,$826E
  JP M,$8247
  JR Z,$825F
  JR C,$8258
  LD B,L
  RES 2,L
  LD H,$BE
  RES 7,(HL)
  INC L
  LD A,$0F
  AND (HL)
  BIT 7,L
  JR NZ,$8240
  NEG
  LD HL,$BD0D
  ADD A,(HL)
  LD (HL),A
  LD A,B
  POP HL
  LD E,H
  EX DE,HL
  LD (HL),E
  EX DE,HL
  RES 2,L
  LD H,$BE
  LD B,(HL)
  LD (HL),E
  INC L
  LD (HL),C
  LD L,B
  DEC H
  LD (HL),A
  EXX
  JP (HL)
  LD E,H
  LD B,A
  LD A,L
  LD (DE),A
  JP $8230
  LD E,H
  LD A,L
  LD (DE),A
  RES 2,L
  LD H,$BE
  LD B,(HL)
  LD (HL),E
  XOR A
  LD E,B
  LD (DE),A
  JP $8246

; Routine at 826E
;
; Used by the routine at 821C.
  JP P,$8282
  EX AF,AF'
  LD A,($BD0D)
  BIT 7,L
  JR Z,$827B
  SUB $10
  ADD A,$08
  LD ($BD0D),A
  EX AF,AF'
  RET
  EX AF,AF'
  LD A,($BD0D)
  BIT 7,L
  JR NZ,$827B
  JR $8279

; Data block at 828C
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00

; Routine at 8400
;
; Used by the routines at 6000, 7810, 7B96, 7D43 and 7E8C.
  LD ($BD3D),SP
  XOR A
  LD E,A
  EX AF,AF'
  LD H,$BD
  EXX
  LD H,$BE
  LD A,($BD2D)
  RRCA
  LD IY,$8A7A
  BIT 1,A
  JR Z,$8424
  LD IY,$8A6F
  BIT 2,A
  JR Z,$8424
  LD IY,$8A2B
  ADD A,$80
  LD B,A
  EXX
  JP C,$883A
  LD D,$88
  LD A,($BE88)
  OR A
  CALL P,$8C43
  LD A,($BE90)
  OR A
  CALL P,$8C4E
  LD A,($BE98)
  OR A
  CALL P,$8C4E
  LD A,($BEA0)
  OR A
  CALL P,$8D80
  LD A,($BEA8)
  OR A
  CALL P,$8D80
  LD A,($BEB0)
  OR A
  CALL P,$8CBB
  LD A,($BEB8)
  OR A
  CALL P,$8CBB
  LD D,$F1
  LD BC,$FFFF
  LD HL,($BEC0)
  BIT 7,L
  CALL Z,$8A5B
  LD HL,($BEC8)
  BIT 7,L
  CALL Z,$8A5B
  LD HL,($BED0)
  BIT 7,L
  CALL Z,$8A5B
  LD HL,($BED8)
  BIT 7,L
  CALL Z,$8A54
  LD HL,($BEE0)
  BIT 7,L
  CALL Z,$8A54
  LD HL,($BEE8)
  BIT 7,L
  CALL Z,$8A5B
  LD HL,($BEF0)
  BIT 7,L
  CALL Z,$8A5B
  LD HL,($BEF8)
  BIT 7,L
  CALL Z,$8A5B
  EXX
  BIT 4,B
  JP Z,$882C
  BIT 6,B
  JR NZ,$84BA
  LD L,(IX+$02)
  DEC H
  LD L,(HL)
  INC H
  BIT 2,L
  JR Z,$84BA
  INC L
  SET 1,(HL)
  BIT 3,B
  JP Z,$84CB
  EXX
  LD A,($BD6D)
  OR A
  JR NZ,$84C8
  SRA E
  SRA E
  EXX
  BIT 5,B
  EXX
  CALL NZ,$8E74
  LD HL,$BD4A
  EX AF,AF'
  SRA A
  SRA A
  ADD A,E
  ADD A,(HL)
  LD E,A
  LD HL,$0000
  LD ($BD39),HL
  LD ($BD3B),IX
  LD HL,($BE8A)
  LD A,H
  OR L
  JR Z,$84F9
  LD BC,($BE8C)
  LD A,$09
  CALL $8AD6
  LD ($BE8A),HL
  LD ($BE8C),HL
  LD HL,($BE92)
  LD A,H
  OR L
  JR Z,$850F
  LD BC,($BE94)
  LD A,$05
  CALL $8AD6
  LD ($BE92),HL
  LD ($BE94),HL
  LD HL,($BE9A)
  LD A,H
  OR L
  JR Z,$8525
  LD BC,($BE9C)
  LD A,$05
  CALL $8AD6
  LD ($BE9A),HL
  LD ($BE9C),HL
  LD HL,($BEA2)
  LD A,H
  OR L
  JR Z,$853B
  LD BC,($BEA4)
  LD A,$03
  CALL $8AD6
  LD ($BEA2),HL
  LD ($BEA4),HL
  LD HL,($BEAA)
  LD A,H
  OR L
  JR Z,$8551
  LD BC,($BEAC)
  LD A,$03
  CALL $8AD6
  LD ($BEAA),HL
  LD ($BEAC),HL
  LD HL,($BEB2)
  LD A,H
  OR L
  JR Z,$8567
  LD BC,($BEB4)
  LD A,$03
  CALL $8AD6
  LD ($BEB2),HL
  LD ($BEB4),HL
  LD HL,($BEBA)
  LD A,H
  OR L
  JR Z,$857D
  LD BC,($BEBC)
  LD A,$03
  CALL $8AD6
  LD ($BEBA),HL
  LD ($BEBC),HL
  LD HL,($BEC2)
  LD A,H
  OR L
  JR Z,$8594
  LD BC,($BEC4)
  LD A,($BEC1)
  CALL $8AD4
  LD ($BEC2),HL
  LD ($BEC4),HL
  LD HL,($BECA)
  LD A,H
  OR L
  JR Z,$85AB
  LD BC,($BECC)
  LD A,($BEC9)
  CALL $8AD4
  LD ($BECA),HL
  LD ($BECC),HL
  LD HL,($BED2)
  LD A,H
  OR L
  JR Z,$85C2
  LD BC,($BED4)
  LD A,($BED1)
  CALL $8AD4
  LD ($BED2),HL
  LD ($BED4),HL
  LD HL,($BEDA)
  LD A,H
  OR L
  JR Z,$85D9
  LD BC,($BEDC)
  LD A,($BED9)
  CALL $8AD4
  LD ($BEDA),HL
  LD ($BEDC),HL
  LD HL,($BEE2)
  LD A,H
  OR L
  JR Z,$85F0
  LD BC,($BEE4)
  LD A,($BEE1)
  CALL $8AD4
  LD ($BEE2),HL
  LD ($BEE4),HL
  LD HL,($BEEA)
  LD A,H
  OR L
  JR Z,$8607
  LD BC,($BEEC)
  LD A,($BEE9)
  CALL $8AD4
  LD ($BEEA),HL
  LD ($BEEC),HL
  LD HL,($BEF2)
  LD A,H
  OR L
  JR Z,$861E
  LD BC,($BEF4)
  LD A,($BEF1)
  CALL $8AD4
  LD ($BEF2),HL
  LD ($BEF4),HL
  LD HL,($BEFA)
  LD A,H
  OR L
  JR Z,$8635
  LD BC,($BEFC)
  LD A,($BEF9)
  CALL $8AD4
  LD ($BEFA),HL
  LD ($BEFC),HL
  XOR A
  SUB E
  LD E,A
  LD HL,($BD39)
  PUSH HL
  LD HL,$0000
  LD ($BD39),HL
  LD HL,($BE0A)
  LD A,H
  OR L
  JR Z,$8658
  LD BC,($BE0C)
  LD A,$09
  CALL $8AD6
  LD ($BE0A),HL
  LD ($BE0C),HL
  LD HL,($BE12)
  LD A,H
  OR L
  JR Z,$866E
  LD BC,($BE14)
  LD A,$05
  CALL $8AD6
  LD ($BE12),HL
  LD ($BE14),HL
  LD HL,($BE1A)
  LD A,H
  OR L
  JR Z,$8684
  LD BC,($BE1C)
  LD A,$05
  CALL $8AD6
  LD ($BE1A),HL
  LD ($BE1C),HL
  LD HL,($BE22)
  LD A,H
  OR L
  JR Z,$869A
  LD BC,($BE24)
  LD A,$03
  CALL $8AD6
  LD ($BE22),HL
  LD ($BE24),HL
  LD HL,($BE2A)
  LD A,H
  OR L
  JR Z,$86B0
  LD BC,($BE2C)
  LD A,$03
  CALL $8AD6
  LD ($BE2A),HL
  LD ($BE2C),HL
  LD HL,($BE32)
  LD A,H
  OR L
  JR Z,$86C6
  LD BC,($BE34)
  LD A,$03
  CALL $8AD6
  LD ($BE32),HL
  LD ($BE34),HL
  LD HL,($BE3A)
  LD A,H
  OR L
  JR Z,$86DC
  LD BC,($BE3C)
  LD A,$03
  CALL $8AD6
  LD ($BE3A),HL
  LD ($BE3C),HL
  LD HL,($BE42)
  LD A,H
  OR L
  JR Z,$86F3
  LD BC,($BE44)
  LD A,($BE41)
  CALL $8AD4
  LD ($BE42),HL
  LD ($BE44),HL
  LD HL,($BE4A)
  LD A,H
  OR L
  JR Z,$870A
  LD BC,($BE4C)
  LD A,($BE49)
  CALL $8AD4
  LD ($BE4A),HL
  LD ($BE4C),HL
  LD HL,($BE52)
  LD A,H
  OR L
  JR Z,$8721
  LD BC,($BE54)
  LD A,($BE51)
  CALL $8AD4
  LD ($BE52),HL
  LD ($BE54),HL
  LD HL,($BE5A)
  LD A,H
  OR L
  JR Z,$8738
  LD BC,($BE5C)
  LD A,($BE59)
  CALL $8AD4
  LD ($BE5A),HL
  LD ($BE5C),HL
  LD HL,($BE62)
  LD A,H
  OR L
  JR Z,$874F
  LD BC,($BE64)
  LD A,($BE61)
  CALL $8AD4
  LD ($BE62),HL
  LD ($BE64),HL
  LD HL,($BE6A)
  LD A,H
  OR L
  JR Z,$8766
  LD BC,($BE6C)
  LD A,($BE69)
  CALL $8AD4
  LD ($BE6A),HL
  LD ($BE6C),HL
  LD HL,($BE72)
  LD A,H
  OR L
  JR Z,$877D
  LD BC,($BE74)
  LD A,($BE71)
  CALL $8AD4
  LD ($BE72),HL
  LD ($BE74),HL
  LD HL,($BE7A)
  LD A,H
  OR L
  JR Z,$8794
  LD BC,($BE7C)
  LD A,($BE79)
  CALL $8AD4
  LD ($BE7A),HL
  LD ($BE7C),HL
  LD B,E
  LD IX,($BD3B)
  POP DE
  LD HL,($BD39)
  LD A,($BD2D)
  RRA
  JR NC,$87B0
  XOR A
  SUB B
  LD B,A
  EX DE,HL
  LD A,($BD0D)
  JP $87B5
  LD A,($BD0D)
  NEG
  SUB L
  ADD A,A
  DEC L
  JP M,$87C3
  SET 1,(IX+$03)
  JR Z,$87C2
  DEC A
  SUB H
  DEC E
  JP M,$87ED
  BIT 2,(IX+$03)
  JR NZ,$87E2
  INC B
  INC B
  DEC D
  JP M,$87E2
  SET 6,(IX+$03)
  INC B
  INC B
  DEC D
  JP M,$87ED
  INC B
  INC B
  JP $87ED
  EX AF,AF'
  LD A,E
  INC L
  CP L
  JR C,$87EC
  SET 6,(IX+$03)
  EX AF,AF'
  CP $1C
  JR C,$87FD
  CP $E4
  JP NC,$87FD
  RLA
  LD A,$02
  RET C
  LD A,$FC
  RET
  ADD A,A
  ADD A,A
  LD C,A
  LD A,B
  SRA A
  ADC A,B
  SRA A
  LD D,A
  LD HL,$BCCE
  INC (HL)
  LD A,($BD49)
  DEC A
  LD A,(HL)
  JR NZ,$8816
  AND $03
  JR $8818
  AND $01
  ADD A,D
  CP $0C
  JR C,$8828
  CP $F4
  JR NC,$8828
  RLA
  LD A,$0C
  JR NC,$8828
  LD A,$F4
  ADD A,C
  ADD A,$80
  RET
  LD A,$90
  ADD A,B
  LD B,A
  EXX
  XOR A
  SUB E
  LD E,A
  LD H,$BD
  EX AF,AF'
  NEG
  EX AF,AF'
  LD A,($BE08)
  LD D,$88
  OR A
  CALL P,$8C43
  LD A,($BE10)
  OR A
  CALL P,$8C4E
  LD A,($BE18)
  OR A
  CALL P,$8C4E
  LD A,($BE20)
  OR A
  CALL P,$8D74
  LD A,($BE28)
  OR A
  CALL P,$8D74
  LD A,($BE30)
  OR A
  CALL P,$8CC8
  LD A,($BE38)
  OR A
  CALL P,$8CC8
  LD D,$11
  LD BC,$FFFF
  LD HL,($BE40)
  BIT 7,L
  CALL Z,$8A5B
  LD HL,($BE48)
  BIT 7,L
  CALL Z,$8A5B
  LD HL,($BE50)
  BIT 7,L
  CALL Z,$8A5B
  LD HL,($BE58)
  BIT 7,L
  CALL Z,$8A54
  LD HL,($BE60)
  BIT 7,L
  CALL Z,$8A54
  LD HL,($BE68)
  BIT 7,L
  CALL Z,$8A5B
  LD HL,($BE70)
  BIT 7,L
  CALL Z,$8A5B
  LD HL,($BE78)
  BIT 7,L
  CALL Z,$8A5B
  LD HL,($BE00)
  CALL $8978
  EX AF,AF'
  NEG
  EX AF,AF'
  XOR A
  SUB E
  LD E,A
  LD HL,($BE80)
  EXX
  SET 7,B
  CALL $897D
  EXX
  BIT 4,B
  JP NZ,$84A9
  SET 4,B
  EXX
  JP $842B
  OR A
  JP NZ,$896F
  LD A,D
  OR A
  JR NZ,$88DF
  SUB $0A
  LD D,A
  LD A,$07
  AND L
  INC A
  RRA
  CP $02
  JR Z,$88F3
  LD A,$70
  AND L
  CP $30
  JR Z,$88F3
  CP $40
  JR NZ,$88F9
  EX AF,AF'
  ADD A,$10
  JP $8970
  LD A,$07
  AND L
  CP $02
  JR Z,$890F
  CP $05
  JR Z,$890F
  LD A,$70
  AND L
  CP $20
  JR Z,$890F
  CP $50
  JR NZ,$896F
  EX AF,AF'
  ADD A,$08
  JP $8970
; This entry point is used by the routine at 8978.
  LD A,($BD49)
  CPL
  ADD A,$0A
  EXX
  LD C,A
  LD A,($BE89)
  BIT 4,A
  JR Z,$892E
  LD A,($BE88)
  OR A
  JP M,$892E
  LD A,E
  ADD A,C
  LD E,A
  LD A,($BE09)
  BIT 4,A
  JR Z,$893F
  LD A,($BE08)
  OR A
  JP M,$893F
  LD A,E
  SUB C
  LD E,A
  EXX
  JP $897D
; This entry point is used by the routine at 897D.
  BIT 3,A
  JR NZ,$894F
  LD H,$BD
  LD B,L
  LD C,$08
  JP $89AC
  LD B,A
  LD C,$04
  LD A,$C0
  AND H
  RRA
  RRA
  RRA
  LD D,A
  LD A,($BD1E)
  OR A
  JR Z,$8966
  XOR B
  LD A,($BD6D)
  JP P,$88D4
  RR D
  OR A
  JR NZ,$896F
  BIT 7,H
  JR NZ,$890F
  EX AF,AF'
  ADD A,D
  EX AF,AF'
  LD H,$BD
  LD B,L
  JP $89AC

; Routine at 8978
;
; Used by the routine at 8400.
  EXX
  BIT 0,B
  JR Z,$8915

; Routine at 897D
;
; Used by the routine at 8400.
  LD A,B
  EXX
  BIT 2,A
  JR NZ,$8943
  BIT 5,H
  JP Z,$8A0D
  LD A,$C0
  AND H
  JR NZ,$89FB
  LD C,$0A
  LD B,L
  LD H,$BD
  LD A,$1F
  ADD A,B
  JP P,$899A
  SUB $40
  LD L,A
  BIT 6,(HL)
  JR NZ,$89AB
  INC L
  BIT 6,(HL)
  JR NZ,$89AB
  INC L
  BIT 6,(HL)
  JR NZ,$89AB
  DEC E
  DEC E
  LD L,B
; This entry point is used by the routines at 8400 and 89E2.
  DEC L
  XOR A
  OR (HL)
  CALL NZ,$89E2
  INC L
  INC L
  OR (HL)
  CALL NZ,$89E2
  LD A,$10
  ADD A,B
  JP M,$89CF
  LD L,A
  XOR A
  OR (HL)
  CALL NZ,$89E2
  INC L
  OR (HL)
  CALL NZ,$89E2
  DEC L
  DEC L
  OR (HL)
  CALL NZ,$89E2
  LD A,$F0
  ADD A,B
  RET M
  LD L,A
  XOR A
  OR (HL)
  CALL NZ,$89E2
  INC L
  OR (HL)
  CALL NZ,$89E2
  DEC L
  DEC L
  OR (HL)
  RET Z

; Routine at 89E2
;
; Used by the routine at 897D.
  EXX
  LD L,A
  INC L
  XOR B
  JP P,$89F1
  LD A,$78
  AND L
  JP Z,$8C28
  DEC L
  DEC L
  INC (HL)
  XOR A
  BIT 6,L
  EXX
  RET Z
  EX AF,AF'
  ADD A,C
  EX AF,AF'
  RET
; This entry point is used by the routine at 897D.
  LD C,$04
  BIT 7,H
  JP Z,$8A04
  DEC E
  DEC E
  DEC E
  DEC E
  DEC E
  LD B,L
  LD H,$BD
  JP $89AC
; This entry point is used by the routine at 897D.
  BIT 4,H
  JR NZ,$8A1A
  LD H,$BD
  LD B,L
  LD C,$00
  INC E
  JP $89AC
  LD A,E
  SUB $06
  LD E,A
  LD C,$08
  LD A,$C0
  AND H
  JR NZ,$89FB
  LD H,$BD
  LD B,L
  JP $89AC
  SRL H
  SRL H
  EX AF,AF'
  ADD A,H
  EX AF,AF'
  BIT 5,H
  JP Z,$8A7A
  EXX
  BIT 4,B
  EXX
  JR NZ,$8A7A
  LD H,$BD
  DEC L
  LD A,(HL)
  INC L
  LD ($BD4E),A
  JP $8A7C
; This entry point is used by the routine at 8A5B.
  DEC E
  DEC E
  DEC E
  JP $8A6B
; This entry point is used by the routine at 8A54.
  DEC E
  DEC E
  DEC E
  JP $8A5B

; Routine at 8A54
;
; Used by the routine at 8400.
  LD A,L
  ADD A,$20
  BIT 6,A
  JR Z,$8A4E

; Routine at 8A5B
;
; Used by the routines at 8400 and 89E2.
  LD A,$0E
  AND H
  JR NZ,$8A96
  LD A,D
  ADD A,L
  LD L,A
  AND $0F
  CP B
  JR Z,$8A48
  CP C
  JR Z,$8A48
; This entry point is used by the routine at 89E2.
  LD C,B
  LD B,A
  JP (IY)
  SRL H
  JR Z,$8A7A
  SRL H
  SRL H
  EX AF,AF'
  ADD A,H
  EX AF,AF'
; This entry point is used by the routine at 89E2.
  LD H,$BD
; This entry point is used by the routine at 89E2.
  LD A,(HL)
  OR A
  CALL NZ,$8A85
  DEC L
  DEC L
  OR (HL)
  RET Z

; Routine at 8A85
;
; Used by the routine at 8A5B.
  EXX
  LD L,A
  XOR B
  JP P,$8A92
  LD A,$78
  AND L
  JR Z,$8ABA
  DEC L
  DEC L
  INC (HL)
  EXX
  XOR A
  RET
; This entry point is used by the routine at 8A5B.
  PUSH BC
  PUSH DE
  LD BC,$8AB5
  PUSH BC
  LD C,H
  LD H,$BD
  LD D,$88
  LD A,L
  BIT 3,C
  JP NZ,$8C43
  BIT 2,C
  JP NZ,$8C4E
  BIT 7,C
  LD B,A
  JP NZ,$8D86
  JP $8CCD

; Message at 8AB5
  DEFM "k",$D1,"]",$C1,$C9

; Routine at 8ABA
;
; Used by the routine at 8A85.
  BIT 4,B
  JP Z,$8C28
  SET 7,(IX+$03)
  EXX
  INC E
  RET
; This entry point is used by the routine at 8AD6.
  BIT 0,H
  JR NZ,$8ACD
  LD H,$00
  RET
  LD A,H
  CALL $8B6A
  JP $8AE0

; Routine at 8AD4
;
; Used by the routine at 8400.
  AND $0F

; Routine at 8AD6
;
; Used by the routine at 8400.
  EXX
  LD D,A
  EXX
  LD A,L
  OR A
  JR Z,$8AC6
  CALL $8B50
; This entry point is used by the routine at 8ABA.
  CALL $8BB9
  LD E,$FF
  LD A,D
  LD B,$00
  BIT 0,H
  JR Z,$8B1A
  SUB L
  EXX
  DEC D
  EXX
  CALL Z,$8B8C
  CP E
  JP M,$8B12
  CP D
  JP P,$8B11
  LD E,A
  BIT 0,L
  JR Z,$8B1A
  ADD A,H
  CP E
  JP M,$8B17
  CP D
  JP P,$8B16
  LD D,A
  DEC C
  CALL Z,$8BFA
  JP $8AE6
  INC B
  INC B
  JP $8AFC
  DEC B
  DEC B
  JR NZ,$8B0A
  CP E
  JP P,$8B1F
  LD A,E
  CP D
  JP M,$8B24
  LD A,D
  OR A
  EXX
  JP M,$8B3E
  JR Z,$8B39
  LD HL,$BD39
  CP (HL)
  JR C,$8B34
  LD C,A
  LD A,(HL)
  LD (HL),C
  INC L
  CP (HL)
  JR C,$8B39
  LD (HL),A
  DEC E
  BIT 1,B
  JR NZ,$8B42
  LD HL,$0000
  RET
  LD IX,($BD3B)
  SET 2,(IX+$03)
  LD HL,$0000
  DEC E
  DEC E
  RET

; Routine at 8B50
;
; Used by the routine at 8AD6.
  AND $03
  CALL NZ,$8B84
  LD A,$0C
  AND L
  CALL NZ,$8B91
  LD A,$30
  AND L
  CALL NZ,$8B9B
  LD A,$C0
  AND L
  CALL NZ,$8BA7
  OR H
  JR Z,$8B80

; Routine at 8B6A
;
; Used by the routine at 8ABA.
  AND $0C
  CALL NZ,$8B91
  LD A,$30
  AND H
  CALL NZ,$8B9B
  LD A,$C0
  AND H
  CALL NZ,$8BA7
  INC A
  AND H
  CALL NZ,$8BB1
; This entry point is used by the routine at 8B50.
  EXX
  LD L,A
  EX AF,AF'
  RET

; Routine at 8B84
;
; Used by the routine at 8B50.
  LD D,A
  POP IY
  EXX
  LD L,$01
  EX AF,AF'
  RET

; Routine at 8B8C
;
; Used by the routine at 8AD6.
  EX AF,AF'
  EXX
  XOR A
  JP (IY)

; Routine at 8B91
;
; Used by the routines at 8B50 and 8B6A.
  RRA
  RRA
  LD D,A
  POP IY
  EXX
  LD L,$03
  EX AF,AF'
  RET

; Routine at 8B9B
;
; Used by the routines at 8B50 and 8B6A.
  RRA
  RRA
  RRA
  RRA
  LD D,A
  POP IY
  EXX
  LD L,$05
  EX AF,AF'
  RET

; Routine at 8BA7
;
; Used by the routines at 8B50 and 8B6A.
  RLCA
  RLCA
  LD D,A
  POP IY
  EXX
  LD L,$09
  EX AF,AF'
  RET

; Routine at 8BB1
;
; Used by the routine at 8B6A.
  LD D,A
  POP IY
  EXX
  LD L,$0D
  EX AF,AF'
  RET

; Routine at 8BB9
;
; Used by the routine at 8AD6.
  EXX
  LD A,C
  OR A
  JR Z,$8BD5
  AND $03
  CALL NZ,$8BF2
  LD A,$0C
  AND C
  CALL NZ,$8BFF
  LD A,$30
  AND C
  CALL NZ,$8C09
  LD A,$C0
  AND C
  CALL NZ,$8C15
  OR B
  JR Z,$8BEE
  AND $0C
  CALL NZ,$8BFF
  LD A,$30
  AND B
  CALL NZ,$8C09
  LD A,$C0
  AND B
  CALL NZ,$8C15
  INC A
  AND B
  CALL NZ,$8C1F
  EXX
  LD H,A
  EX AF,AF'
  RET

; Routine at 8BF2
;
; Used by the routine at 8BB9.
  EXX
  LD C,A
  LD H,$01
  POP IX
  EX AF,AF'
  RET

; Routine at 8BFA
;
; Used by the routine at 8AD6.
  EX AF,AF'
  EXX
  XOR A
  JP (IX)

; Routine at 8BFF
;
; Used by the routine at 8BB9.
  RRA
  RRA
  POP IX
  EXX
  LD H,$03
  LD C,A
  EX AF,AF'
  RET

; Routine at 8C09
;
; Used by the routine at 8BB9.
  RRA
  RRA
  RRA
  RRA
  POP IX
  EXX
  LD H,$05
  LD C,A
  EX AF,AF'
  RET

; Routine at 8C15
;
; Used by the routine at 8BB9.
  RLCA
  RLCA
  POP IX
  EXX
  LD H,$09
  LD C,A
  EX AF,AF'
  RET

; Routine at 8C1F
;
; Used by the routine at 8BB9.
  DEC E
  POP IX
  EXX
  LD H,$0D
  LD C,A
  EX AF,AF'
  RET
; This entry point is used by the routines at 89E2, 8ABA and 8D15.
  XOR A
  LD ($BD79),A
  LD B,$1F
  LD DE,$0005
  LD HL,$BE0A
  LD (HL),A
  INC L
  LD (HL),A
  INC L
  LD (HL),A
  INC L
  LD (HL),A
  ADD HL,DE
  DJNZ $8C34
  LD SP,($BD3D)
  RET

; Routine at 8C43
;
; Used by the routines at 8400 and 8A85.
  LD B,A
  EXX
  LD C,$40
  CALL $8C52
  EXX
  JP $8D89

; Routine at 8C4E
;
; Used by the routines at 8400 and 8A85.
  LD B,A
  EXX
  LD C,$10

; Routine at 8C52
;
; Used by the routine at 8C43.
  LD E,$08
  EXX
  LD L,B
  XOR A
  INC L
  BIT 3,L
  JR NZ,$8C65
  OR (HL)
  JR Z,$8C57
  LD C,$01
  CALL $8C98
  XOR A
  LD L,B
  DEC L
  BIT 3,L
  JR NZ,$8C73
  OR (HL)
  JR Z,$8C66
  LD C,$FF
  CALL $8C98
  LD C,$10
  LD A,B
  ADD A,C
  CALL P,$8C80
  LD C,$F0
  LD L,B
; This entry point is used by the routine at 8C80.
  LD A,L
  ADD A,C
  RET M

; Routine at 8C80
;
; Used by the routine at 8C52.
  LD L,A
  INC E
  XOR A
  OR (HL)
  JR Z,$8C7D
  EXX
  LD L,A
  XOR B
  JP M,$8DB9
  LD A,C
  ADD A,(HL)
  LD (HL),A
  SET 1,L
  LD A,(HL)
  AND E
  EXX
  RET Z
  JP $8DF8

; Routine at 8C98
;
; Used by the routine at 8C52.
  EXX
  LD L,A
  XOR B
  JP M,$8DB9
  LD A,C
  ADD A,(HL)
  LD (HL),A
  SET 1,L
  LD A,(HL)
  AND E
  EXX
  RET Z
  LD A,L
  ADD A,C
  LD L,A
  AND D
  RET NZ
  OR (HL)
  JR Z,$8CA7
  EXX
  LD L,A
  XOR B
  JP M,$8E07
  INC L
  LD A,C
  ADD A,(HL)
  LD (HL),A
  EXX
  RET

; Routine at 8CBB
;
; Used by the routine at 8400.
  LD B,A
  OR $70
  CP B
  JP NZ,$8CCD
; This entry point is used by the routine at 8CC8.
  DEC E
  DEC E
  DEC E
  JP $8CCD

; Routine at 8CC8
;
; Used by the routine at 8400.
  LD B,A
  AND $70
  JR Z,$8CC2
; This entry point is used by the routines at 8A85 and 8CBB.
  EXX
  LD C,$04
  EXX
  DEC E
; This entry point is used by the routine at 8EAF.
  LD A,$0E
  ADD A,B
  JP M,$8CF5
  LD L,A
  AND D
  CALL Z,$8D15
  LD A,$12
  ADD A,B
  LD L,A
  AND D
  CALL Z,$8D15
  LD A,$1F
  ADD A,B
  LD L,A
  AND D
  CALL Z,$8D15
  LD A,$21
  ADD A,B
  LD L,A
  AND D
  CALL Z,$8D15
  LD A,$F2
  ADD A,B
  RET M
  LD L,A
  AND D
  CALL Z,$8D15
  LD A,$EE
  ADD A,B
  LD L,A
  AND D
  CALL Z,$8D15
  LD A,$E1
  ADD A,B
  RET M
  LD L,A
  AND D
  CALL Z,$8D15
  LD A,$DF
  ADD A,B
  LD L,A
  AND D
  RET NZ

; Routine at 8D15
;
; Used by the routine at 8CC8.
  INC E
  OR (HL)
  RET Z
  EXX
  LD L,A
  XOR B
  JP P,$8D25
  LD A,$78
  AND L
  JR Z,$8D2A
  DEC L
  DEC L
  LD A,C
  ADD A,(HL)
  LD (HL),A
  EXX
  RET
  BIT 4,B
  JP Z,$8C28
  SET 7,(IX+$03)
  BIT 6,B
  SET 6,B
  EXX
  JR NZ,$8D44
  LD L,B
  LD L,(HL)
  INC L
  INC H
  SET 1,(HL)
  DEC H
  INC E
  INC E
  RET
  LD ($BD4E),A
  EX AF,AF'
  ADD A,$14
  EX AF,AF'
  RET
; This entry point is used by the routine at 8DAF.
  BIT 4,B
  JP Z,$8C28
  SET 7,(IX+$03)
  BIT 6,B
  SET 6,B
  EXX
  JR NZ,$8D6A
  LD A,L
  LD L,B
  LD L,(HL)
  INC L
  INC H
  SET 1,(HL)
  DEC H
  LD L,A
  INC E
  INC E
  JP $8DAA
  LD ($BD4E),A
  EX AF,AF'
  ADD A,$14
  EX AF,AF'
  JP $8DAA

; Routine at 8D74
;
; Used by the routine at 8400.
  LD B,A
  AND $70
  JP NZ,$8D86
; This entry point is used by the routine at 8D80.
  DEC E
  DEC E
  DEC E
  JP $8D86

; Routine at 8D80
;
; Used by the routine at 8400.
  LD B,A
  OR $70
  CP B
  JR Z,$8D7A
; This entry point is used by the routines at 8A85 and 8D74.
  EXX
  LD C,$04
; This entry point is used by the routine at 8C43.
  LD E,$C4
  EXX
  LD C,$0F
  LD A,B
  ADD A,C
  LD L,A
  AND D
  CALL Z,$8DAF
  LD C,$11
  LD A,B
  ADD A,C
  LD L,A
  AND D
  CALL Z,$8DAF
  LD C,$EF
  LD A,B
  ADD A,C
  LD L,A
  AND D
  CALL Z,$8DAF
  LD C,$F1
  LD L,B
; This entry point is used by the routines at 8D15 and 8DAF.
  LD A,L
  ADD A,C
  LD L,A
  AND D
  RET NZ

; Routine at 8DAF
;
; Used by the routine at 8D80.
  INC E
  OR (HL)
  JR Z,$8DAA
  EXX
  LD L,A
  XOR B
  JP P,$8DEC
; This entry point is used by the routines at 8C80 and 8C98.
  LD A,$78
  AND L
  JR Z,$8D4C
  DEC L
  DEC L
  LD A,C
  ADD A,(HL)
  LD (HL),A
  SET 2,L
  LD A,(HL)
  AND E
  JR Z,$8E19
  JP M,$8E19
  EXX
  LD A,L
  ADD A,C
  LD L,A
  AND D
  RET NZ
  OR (HL)
  JR Z,$8DCD
  EXX
  LD D,L
  LD L,A
  XOR B
  JP P,$8E15
  DEC L
  LD A,C
  ADD A,(HL)
  LD (HL),A
  INC L
  INC L
  INC L
  LD A,(HL)
  RRA
  JR C,$8E2F
  RRA
  JR C,$8E2B
  EXX
  RET
  LD A,C
  ADD A,(HL)
  LD (HL),A
  SET 1,L
  LD A,(HL)
  AND E
  EXX
  RET Z
  JP M,$8E5C
; This entry point is used by the routine at 8C80.
  LD A,L
  ADD A,C
  LD L,A
  AND D
  RET NZ
  INC E
  OR (HL)
  JR Z,$8DF8
  EXX
  LD L,A
  XOR B
  JP P,$8E0D
; This entry point is used by the routine at 8C98.
  DEC L
  LD A,C
  ADD A,(HL)
  LD (HL),A
  EXX
  RET
  INC L
  LD A,C
  ADD A,(HL)
  LD (HL),A
  DEC L
  JP $8DEF
  INC L
  JP $8E08
  EXX
  LD A,L
  ADD A,C
  LD L,A
  AND D
  RET NZ
  OR (HL)
  JR Z,$8E1A
  EXX
  LD D,L
  LD L,A
  XOR B
  JP M,$8DE1
  EXX
  RET
  BIT 6,C
  JR NZ,$8E58
  RES 1,D
  RES 2,D
  LD HL,$BD79
  LD A,(HL)
  OR A
  JR Z,$8E47
  INC L
  INC L
  CP D
  JP NZ,$8E36
  DEC L
  LD (HL),$00
  INC H
  EXX
  INC E
  RET
  LD A,L
  CP $84
  JR NC,$8E57
  LD (HL),D
  INC L
  EXX
  LD A,C
  EXX
  LD (HL),A
  INC L
  LD (HL),$00
  SET 5,B
  INC H
  EXX
  INC E
  INC E
  RET
  RLA
  XOR C
  RET P
  LD A,L
  ADD A,C
  LD L,A
  AND D
  RET NZ
  OR (HL)
  RET Z
  EXX
  LD L,A
  INC L
  XOR B
  JP P,$8E6F
  DEC L
  DEC L
  LD A,C
  ADD A,(HL)
  LD (HL),A
  EXX
  RET

; Routine at 8E74
;
; Used by the routine at 8400.
  LD IY,$BD79
  PUSH DE
  LD H,$BD
  EXX
  LD L,(IY+$00)
; This entry point is used by the routine at 8F05.
  LD BC,$8F1B
  PUSH BC
  LD A,L
  AND $80
  LD B,A
  LD E,(HL)
  INC L
  LD A,(HL)
  AND $8E
  JR Z,$8E9F
  JP M,$8EE4
  CP $04
  JR C,$8EC9
  JR Z,$8ED5
  LD C,$C0
  CALL $8ED7
  JP $8EED
; This entry point is used by the routine at 8ED7.
  BIT 7,B
  LD A,E
  EXX
  LD B,A
  LD C,$0F
  JR Z,$8EAA
  LD C,$EF
  CALL $8EAF
  INC C
  INC C

; Routine at 8EAF
;
; Used by the routine at 8E74.
  LD A,(IY+$01)
  CP C
  RET Z
  NEG
  CP C
  RET Z
  LD A,C
  ADD A,B
  LD L,A
  XOR A
  OR (HL)
  RET Z
  EXX
  LD L,A
  XOR B
  JP P,$8EC6
  DEC L
  DEC L
  DEC (HL)
  EXX
  RET
; This entry point is used by the routine at 8E74.
  LD C,$FC
  SET 4,B
  LD A,E
  EXX
  LD D,$88
  LD B,A
  JP $8CD2
; This entry point is used by the routine at 8E74.
  LD C,$F0

; Routine at 8ED7
;
; Used by the routine at 8E74.
  LD A,E
  EXX
  LD C,$01
  LD B,A
  CALL $8EF4
  LD C,$10
  JP $8EF4
; This entry point is used by the routine at 8E74.
  AND $02
  JR Z,$8E9F
  LD C,$FC
  LD A,E
  EXX
  LD B,A
; This entry point is used by the routine at 8E74.
  LD C,$0F
  CALL $8EF4
  LD C,$11

; Routine at 8EF4
;
; Used by the routine at 8ED7.
  LD A,(IY+$01)
  CP C
  RET Z
  NEG
  CP C
  RET Z
  LD D,$88
  CALL $8F05
  XOR A
  SUB C
  LD C,A

; Routine at 8F05
;
; Used by the routine at 8EF4.
  LD L,B
  LD A,L
  ADD A,C
  LD L,A
  AND D
  RET NZ
  OR (HL)
  JR Z,$8F06
  EXX
  LD L,A
  XOR B
  JP P,$8F16
  DEC L
  DEC L
  LD A,C
  ADD A,(HL)
  LD (HL),A
  EXX
  RET
  LD A,(IY+$02)
  OR A
  JR Z,$8F2A
  INC IY
  INC IY
  EXX
  LD L,A
  JP $8E7F
  POP DE
  LD ($BD79),A
  RET

; Data block at 8F2F
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$26,$92,$69,$C4,$CA,$B0,$4C
  DEFB $2E,$0D,$0A,$16,$49,$E0,$90,$00
  DEFB $34,$0E,$97,$13,$03,$01,$80,$A0
  DEFB $22,$70,$B6,$4B,$05,$94,$80,$00
  DEFB $00,$80,$64,$12,$29,$4A,$8A,$00
  DEFB $00,$60,$80,$51,$10,$4F,$05,$82
  DEFB $42,$40,$00,$00,$64,$12,$29,$4A
  DEFB $C9,$81,$62,$20,$A0,$40,$10,$28
  DEFB $0D,$08,$42,$02,$30,$30,$71,$00
  DEFB $14,$26,$86,$05,$60,$A0,$20,$0C
  DEFB $00,$92,$27,$86,$43,$28,$E2,$58
  DEFB $64,$38,$0A,$04,$24,$CC,$C1,$90
  DEFB $C0,$08,$1C,$1E,$00,$25,$C2,$21
  DEFB $80,$90,$54,$00,$8B,$03,$12,$90
  DEFB $04,$C4,$C0,$14,$1A,$05,$40,$11
  DEFB $2A,$C0,$F0,$B9,$24,$28,$53,$26
  DEFB $87,$01,$05,$70,$00,$28,$48,$9B
  DEFB $05,$00,$00,$02,$40,$60,$19,$06
  DEFB $51,$0E,$53,$81,$40,$40,$02,$04
  DEFB $A4,$0A,$07,$00,$00,$81,$40,$0A
  DEFB $04,$00,$0A,$05,$80,$02,$40,$81
  DEFB $2A,$3C,$1E,$1D,$2D,$08,$40,$00
  DEFB $F0,$42,$00,$32,$0E,$00,$20,$0A
  DEFB $A5,$D2,$50,$7C,$16,$18,$0D,$08
  DEFB $03,$E1,$30,$00,$01,$42,$5A,$07
  DEFB $86,$C2,$A1,$A0,$FA,$3E,$12,$1C
  DEFB $00,$A3,$8B,$E1,$31,$08,$38,$30
  DEFB $9E,$A7,$82,$80,$00,$B0,$D0,$48
  DEFB $1A,$A0,$93,$86,$C2,$80,$E0,$52
  DEFB $28,$2C,$5D,$2C,$94,$03,$41,$50
  DEFB $D8,$61,$16,$18,$0A,$08,$02,$A1
  DEFB $E4,$7C,$74,$38,$09,$05,$01,$94
  DEFB $95,$90,$50,$54,$3C,$00,$46,$D6
  DEFB $81,$41,$20,$58,$8D,$0B,$5B,$45
  DEFB $57,$03,$62,$70,$68,$79,$1D,$1F
  DEFB $49,$94,$4B,$41,$A1,$10,$50,$2E
  DEFB $17,$0E,$02,$C2,$A0,$04,$04,$50
  DEFB $2E,$5F,$09,$85,$12,$C4,$B0,$B8
  DEFB $4D,$3A,$4C,$4E,$03,$C2,$C1,$90
  DEFB $90,$35,$1A,$55,$31,$11,$01,$A0
  DEFB $F0,$AA,$48,$16,$14,$0A,$84,$82
  DEFB $20,$84,$60,$50,$08,$0B,$07,$95
  DEFB $00,$80,$00,$00,$48,$46,$29,$4A
  DEFB $18,$82,$22,$80,$81,$AC,$26,$2A
  DEFB $08,$09,$D0,$E1,$30,$78,$38,$02
  DEFB $13,$08,$87,$10,$A6,$80,$00,$19
  DEFB $30,$69,$0C,$08,$83,$22,$74,$B1
  DEFB $70,$00,$1A,$4A,$04,$80,$06,$80
  DEFB $B8,$71,$36,$45,$0C,$09,$C2,$C1
  DEFB $C0,$B8,$88,$08,$10,$0D,$83,$92
  DEFB $60,$00,$C0,$8C,$2C,$18,$03,$84
  DEFB $91,$A1,$22,$D1,$58,$36,$0B,$05
  DEFB $11,$82,$41,$80,$C0,$00,$1E,$1A
  DEFB $04,$20,$E0,$A9,$38,$C8,$88,$20
  DEFB $97,$AE,$04,$C2,$88,$AA,$C8,$6C
  DEFB $12,$0B,$0F,$A1,$AB,$01,$40,$92
  DEFB $26,$AC,$94,$8B,$A2,$C0,$C4,$92
  DEFB $68,$20,$3A,$0A,$0B,$81,$C2,$88
  DEFB $52,$E1,$28,$1A,$90,$86,$83,$02
  DEFB $28,$08,$1A,$54,$A2,$40,$08,$85
  DEFB $41,$C0,$74,$A9,$30,$20,$00,$06
  DEFB $84,$50,$E0,$D2,$88,$00,$1C,$0A
  DEFB $03,$25,$09,$C0,$00,$90,$48,$1A
  DEFB $0F,$05,$01,$11,$A5,$20,$00,$1C
  DEFB $14,$11,$09,$85,$51,$20,$10,$68
  DEFB $2C,$2C,$14,$03,$86,$80,$01,$24
  DEFB $AD,$54,$30,$4B,$43,$11,$13,$84
  DEFB $10,$80,$1D,$00,$4D,$07,$83,$92
  DEFB $81,$20,$28,$64,$2C,$16,$04,$03
  DEFB $40,$E1,$14,$A5,$01,$31,$41,$0A
  DEFB $85,$00,$01,$20,$C8,$49,$17,$47
  DEFB $09,$02,$42,$E0,$64,$7C,$2C,$18
  DEFB $48,$48,$83,$13,$04,$E0,$B0,$4C
  DEFB $2E,$50,$0A,$52,$43,$A1,$40,$20
  DEFB $54,$4C,$12,$0D,$83,$83,$20,$55
  DEFB $28,$58,$9E,$93,$33,$24,$E5,$00
  DEFB $C1,$38,$38,$10,$8F,$27,$06,$83
  DEFB $40,$E2,$D2,$34,$1C,$89,$09,$15
  DEFB $00,$28,$F2,$7A,$3A,$44,$10,$0A
  DEFB $02,$82,$69,$18,$38,$4C,$0A,$98
  DEFB $25,$01,$0B,$81,$60,$58,$10,$2C
  DEFB $97,$0D,$84,$82,$61,$A0,$40,$54
  DEFB $3C,$17,$42,$14,$C8,$A1,$80,$30
  DEFB $5C,$22,$9F,$06,$86,$00,$C1,$71
  DEFB $10,$65,$30,$59,$07,$03,$D2,$B1
  DEFB $60,$58,$74,$16,$1A,$02,$08,$52
  DEFB $24,$DA,$71,$2C,$8C,$53,$A3,$14
  DEFB $C8,$04,$50,$18,$5C,$0C,$58,$09
  DEFB $80,$0B,$24,$C0,$40,$60,$2C,$81
  DEFB $2A,$86,$10,$C4,$80,$B8,$2C,$2E
  DEFB $84,$88,$06,$01,$69,$50,$B0,$28
  DEFB $BC,$90,$10,$02,$40,$A1,$70,$20
  DEFB $5C,$38,$09,$0B,$02,$04,$81,$34
  DEFB $D5,$18,$26,$1C,$0A,$86,$02,$21
  DEFB $60,$58,$5C,$40,$1F,$42,$40,$0A
  DEFB $C1,$80,$F8,$4C,$22,$01,$09,$04
  DEFB $02,$88,$72,$90,$14,$AE,$0D,$47
  DEFB $43,$51,$E1,$30,$B8,$54,$AE,$11
  DEFB $0A,$82,$C3,$81,$60,$D0,$70,$20
  DEFB $12,$03,$A9,$03,$E1,$50,$E0,$10
  DEFB $1E,$87,$29,$05,$0B,$A0,$B0,$F8
  DEFB $68,$1A,$41,$09,$82,$80,$02,$35
  DEFB $28,$68,$26,$12,$40,$18,$00,$C1
  DEFB $F0,$B8,$44,$3A,$18,$00,$81,$C1
  DEFB $C2,$24,$7C,$21,$02,$18,$23,$05
  DEFB $02,$41,$00,$28,$74,$36,$19,$4A
  DEFB $C4,$50,$E4,$80,$98,$4C,$22,$0D
  DEFB $45,$95,$8B,$40,$00,$28,$74,$24
  DEFB $55,$08,$82,$02,$61,$C0,$00,$4D
  DEFB $24,$06,$0C,$04,$42,$81,$44,$CC
  DEFB $48,$08,$22,$12,$84,$C4,$00,$31
  DEFB $00,$51,$2F,$49,$02,$92,$42,$81
  DEFB $00,$C8,$31,$0C,$00,$0B,$81,$53
  DEFB $10,$30,$B8,$2C,$10,$18,$02,$06
  DEFB $43,$E1,$80,$00,$78,$3C,$25,$53
  DEFB $16,$0A,$64,$90,$B8,$5C,$00,$0D
  DEFB $08,$A0,$23,$A1,$80,$62,$00,$AC
  DEFB $1A,$07,$04,$83,$41,$80,$E2,$24
  DEFB $90,$13,$0A,$05,$C1,$40,$E0,$82
  DEFB $30,$A8,$0C,$0D,$03,$00,$C9,$48
  DEFB $00,$30,$2C,$12,$09,$85,$C2,$E9
  DEFB $72,$49,$00,$32,$11,$07,$05,$42
  DEFB $E0,$D4,$18,$4C,$3A,$08,$01,$05
  DEFB $C2,$00,$04,$DD,$6C,$2C,$1B,$10
  DEFB $82,$80,$01,$60,$60,$60,$38,$05
  DEFB $43,$45,$C0,$C0,$D0,$B8,$64,$0E
  DEFB $0E,$52,$83,$0A,$64,$02,$38,$48
  DEFB $3C,$12,$0A,$83,$D0,$05,$F0,$90
  DEFB $34,$32,$0C,$01,$06,$C0,$A1,$14
  DEFB $84,$44,$28,$29,$09,$80,$C0,$E1
  DEFB $54,$19,$4D,$28,$54,$0E,$81,$C1
  DEFB $21,$20,$28,$20,$00,$0C,$46,$01
  DEFB $83,$E1,$60,$D0,$1C,$0E,$16,$43
  DEFB $44,$02,$81,$44,$39,$58,$36,$08
  DEFB $2B,$06,$C3,$C1,$60,$02,$32,$46
  DEFB $9B,$26,$84,$82,$A0,$00,$88,$20
  DEFB $1E,$41,$4B,$01,$92,$C4,$82,$C0
  DEFB $58,$00,$00,$0C,$82,$04,$01,$20
  DEFB $48,$60,$26,$84,$89,$84,$C1,$48
  DEFB $4A,$88,$00,$20,$18,$03,$80,$43
  DEFB $01,$40,$78,$80,$1E,$92,$8C,$86
  DEFB $83,$22,$00,$90,$00,$2E,$15,$06
  DEFB $26,$08,$A4,$82,$D1,$08,$3A,$0D
  DEFB $00,$05,$51,$05,$60,$E8,$78,$4E
  DEFB $07,$05,$82,$42,$89,$78,$E0,$74
  DEFB $3E,$27,$07,$00,$42,$40,$54,$D9
  DEFB $6C,$2C,$14,$0F,$03,$04,$A1,$10
  DEFB $28,$54,$12,$84,$A0,$05,$83,$20
  DEFB $90,$D0,$24,$40,$9A,$8C,$81,$C3
  DEFB $40,$90,$E8,$50,$0A,$07,$14,$06
  DEFB $40,$09,$20,$89,$50,$B0,$1E,$09
  DEFB $03,$43,$A2,$01,$09,$30,$4C,$0F
  DEFB $13,$03,$D2,$C4,$40,$58,$74,$42
  DEFB $08,$52,$42,$44,$C0,$F1,$30,$3D
  DEFB $11,$06,$08,$80,$81,$40,$A0,$00
  DEFB $7D,$40,$5C,$0C,$90,$0A,$00,$60
  DEFB $F0,$54,$10,$10,$06,$84,$82,$C0
  DEFB $A5,$18,$18,$44,$1C,$0F,$87,$C0
  DEFB $C0,$C0,$B8,$28,$26,$0A,$0A,$A0
  DEFB $4C,$C1,$80,$98,$5C,$38,$0A,$0B
  DEFB $87,$C0,$01,$14,$55,$7C,$30,$24
  DEFB $01,$00,$D2,$D1,$E0,$89,$1D,$02
  DEFB $19,$00,$01,$C4,$C0,$D0,$18,$94
  DEFB $34,$07,$44,$43,$D0,$C5,$60,$C9
  DEFB $5C,$84,$1A,$4A,$94,$82,$80,$70
  DEFB $F8,$54,$28,$99,$24,$02,$80,$62
  DEFB $25,$00,$10,$2E,$0A,$47,$93,$81
  DEFB $01,$F0,$98,$80,$30,$1A,$00,$01
  DEFB $C4,$80,$E4,$E4,$78,$B2,$18,$0C
  DEFB $05,$11,$25,$81,$10,$20,$40,$1D
  DEFB $0A,$06,$41,$E1,$90,$AA,$14,$34
  DEFB $0F,$4C,$12,$02,$25,$84,$38,$1D
  DEFB $16,$13,$2C,$00,$C3,$21,$94,$68
  DEFB $44,$2E,$19,$11,$03,$83,$E9,$D2
  DEFB $69,$58,$AE,$20,$06,$01,$43,$82
  DEFB $90,$D1,$78,$20,$0E,$47,$18,$C2
  DEFB $00,$B0,$F8,$58,$1E,$00,$40,$46
  DEFB $C1,$E0,$30,$E0,$44,$06,$19,$47
  DEFB $43,$01,$81,$C0,$D0,$3D,$00,$4E
  DEFB $2A,$84,$02,$05,$60,$F0,$38,$1C
  DEFB $00,$0B,$01,$11,$60,$10,$10,$58
  DEFB $30,$0D,$04,$02,$D1,$30,$C0,$08
  DEFB $04,$14,$14,$15,$06,$83,$81,$71
  DEFB $08,$0C,$50,$20,$4B,$41,$41,$80
  DEFB $F0,$98,$69,$2C,$55,$0B,$13,$41
  DEFB $A1,$20,$02,$24,$A2,$11,$05,$83
  DEFB $80,$80,$04,$04,$70,$1A,$19,$0F
  DEFB $96,$80,$E0,$00,$68,$01,$1E,$1B
  DEFB $03,$88,$44,$81,$90,$58,$30,$38
  DEFB $1B,$52,$D6,$01,$C0,$30,$E0,$7C
  DEFB $2C,$1D,$47,$45,$82,$E1,$F0,$09
  DEFB $08,$1A,$0C,$08,$88,$53,$22,$20
  DEFB $B0,$54,$36,$1E,$48,$92,$89,$A1
  DEFB $A0,$B0,$6C,$28,$54,$07,$06,$40
  DEFB $00,$E1,$18,$91,$23,$43,$0A,$85
  DEFB $53,$51,$90,$B0,$51,$38,$0B,$24
  DEFB $04,$43,$80,$70,$60,$78,$22,$8A
  DEFB $8D,$02,$03,$41,$E0,$D0,$20,$26
  DEFB $98,$23,$83,$43,$41,$70,$E9,$58
  DEFB $48,$0F,$10,$01,$00,$22,$A0,$BA
  DEFB $02,$18,$07,$09,$86,$C0,$62,$90
  DEFB $A0,$04,$30,$96,$2B,$05,$C9,$00
  DEFB $B0,$21,$48,$A6,$98,$2D,$01,$C2
  DEFB $20,$00,$02,$12,$4A,$12,$09,$87
  DEFB $45,$08,$B8,$48,$68,$A6,$11,$00
  DEFB $00,$02,$88,$90,$A0,$44,$00,$80
  DEFB $8E,$A0,$63,$00,$70,$78,$44,$A8
  DEFB $9E,$0C,$07,$82,$E8,$82,$61,$58
  DEFB $2C,$52,$2C,$86,$43,$64,$90,$A0
  DEFB $58,$24,$00,$0F,$86,$41,$E0,$C4
  DEFB $A8,$48,$3A,$04,$0B,$80,$12,$45
  DEFB $20,$C8,$48,$0E,$16,$0E,$83,$03
  DEFB $69,$A2,$81,$44,$2C,$17,$0B,$02
  DEFB $80,$E0,$F4,$88,$58,$3A,$1B,$04
  DEFB $05,$45,$00,$90,$40,$01,$30,$1A
  DEFB $07,$05,$03,$01,$94,$51,$4C,$98
  DEFB $5F,$0E,$07,$09,$C1,$82,$82,$5C
  DEFB $06,$17,$08,$23,$89,$E2,$02,$C0
  DEFB $10,$24,$2B,$4A,$86,$43,$61,$60
  DEFB $E8,$3D,$1E,$1A,$0F,$85,$D3,$A4
  DEFB $F0,$E0,$7C,$18,$09,$0A,$82,$D3
  DEFB $C5,$B0,$58,$60,$2C,$04,$08,$04
  DEFB $11,$34,$90,$E8,$0C,$14,$00,$54
  DEFB $D7,$83,$C0,$34,$1D,$10,$2A,$0F
  DEFB $03,$81,$01,$20,$55,$14,$60,$3A
  DEFB $12,$08,$83,$52,$45,$22,$61,$1C
  DEFB $4A,$13,$29,$00,$C3,$E0,$00,$D0
  DEFB $5C,$3C,$0B,$07,$27,$25,$69,$22
  DEFB $50,$90,$40,$0E,$06,$06,$41,$E8
  DEFB $30,$D0,$68,$12,$11,$07,$26,$A4
  DEFB $01,$21,$08,$58,$3C,$8D,$8D,$05
  DEFB $42,$81,$80,$CA,$28,$BE,$19,$2E
  DEFB $04,$03,$20,$32,$72,$5A,$1E,$1B
  DEFB $12,$A3,$8A,$E1,$80,$28,$4C,$12
  DEFB $A1,$22,$04,$04,$01,$51,$20,$3C
  DEFB $28,$A1,$0F,$04,$43,$20,$F0,$72
  DEFB $9A,$3C,$1B,$07,$05,$0B,$28,$F0
  DEFB $DA,$32,$2A,$16,$06,$84,$83,$21
  DEFB $A0,$BA,$7C,$90,$56,$06,$14,$C2
  DEFB $81,$52,$50,$50,$22,$64,$0D,$86
  DEFB $C2,$02,$30,$68,$40,$14,$06,$00
  DEFB $26,$82,$01,$70,$E0,$6D,$32,$4D
  DEFB $2E,$02,$42,$41,$34,$68,$40,$12
  DEFB $1B,$09,$80,$C1,$89,$30,$79,$60
  DEFB $AA,$10,$08,$26,$03,$01,$30,$62
  DEFB $08,$28,$0E,$4C,$97,$82,$85,$D0
  DEFB $70,$4D,$1C,$0E,$46,$97,$C1,$04
  DEFB $E0,$42,$20,$2A,$19,$46,$C4,$92
  DEFB $84,$A0,$60,$48,$12,$9C,$AA,$03
  DEFB $02,$E1,$40,$9A,$46,$1C,$8C,$21
  DEFB $15,$C0,$65,$60,$79,$5C,$0C,$0B
  DEFB $06,$80,$03,$C1,$A0,$E0,$6D,$41
  DEFB $0F,$08,$03,$92,$85,$40,$41,$54
  DEFB $14,$61,$09,$87,$42,$A1,$E0,$A0
  DEFB $54,$2E,$23,$0D,$A7,$83,$C1,$54
  DEFB $60,$4C,$06,$0D,$07,$84,$82,$29
  DEFB $70,$50,$14,$A6,$8B,$08,$22,$E1
  DEFB $40,$F0,$D2,$3C,$96,$17,$26,$15
  DEFB $81,$A1,$D2,$8A,$88,$20,$17,$04
  DEFB $A3,$81,$00,$50,$38,$1C,$30,$08
  DEFB $45,$00,$C1,$45,$60,$C8,$64,$20
  DEFB $0A,$50,$44,$03,$26,$04,$D8,$60
  DEFB $36,$14,$51,$10,$42,$C4,$D0,$98
  DEFB $51,$40,$0F,$0F,$03,$01,$C1,$A4
  DEFB $CD,$40,$2C,$00,$09,$84,$0C,$41
  DEFB $74,$E9,$68,$0C,$8C,$08,$04,$10
  DEFB $70,$A0,$B0,$28,$26,$1A,$2D,$02
  DEFB $11,$84,$A0,$40,$90,$00,$86,$31
  DEFB $02,$03,$04,$04,$F0,$6D,$3C,$4C
  DEFB $04,$22,$02,$00,$80,$F8,$00,$08
  DEFB $07,$53,$92,$C9,$75,$22,$89,$50
  DEFB $28,$0F,$07,$03,$41,$C0,$A0,$DA
  DEFB $8C,$98,$0D,$09,$06,$0B,$A1,$91
  DEFB $08,$48,$3A,$1C,$0E,$86,$03,$C9
  DEFB $A0,$C0,$2C,$38,$21,$07,$05,$80
  DEFB $08,$00,$78,$34,$1A,$59,$0E,$A3
  DEFB $C3,$01,$80,$58,$70,$42,$0E,$0B
  DEFB $00,$10,$04,$A2,$61,$38,$14,$10
  DEFB $0E,$A4,$02,$81,$70,$50,$0C,$22
  DEFB $19,$08,$81,$C0,$61,$30,$68,$2D
  DEFB $1C,$4F,$03,$90,$C0,$E1,$A0,$98
  DEFB $59,$1E,$58,$04,$04,$C1,$A0,$D0
  DEFB $B0,$61,$2C,$1A,$4D,$45,$00,$65
  DEFB $41,$38,$48,$34,$0C,$0C,$86,$04
  DEFB $A1,$75,$18,$3C,$4C,$58,$08,$00
  DEFB $40,$E0,$64,$D0,$34,$32,$5B,$0A
  DEFB $82,$D5,$E1,$A0,$E0,$59,$1A,$53
  DEFB $A7,$93,$43,$21,$B0,$60,$70,$00
  DEFB $17,$02,$24,$09,$E1,$A0,$48,$40
  DEFB $2E,$00,$4A,$C4,$82,$A1,$50,$D0
  DEFB $08,$2C,$17,$0D,$03,$D4,$24,$C0
  DEFB $B0,$60,$32,$14,$49,$55,$82,$E1
  DEFB $81,$0A,$46,$2A,$17,$07,$08,$04
  DEFB $29,$20,$A5,$30,$A4,$0A,$23,$87
  DEFB $80,$01,$D0,$50,$2C,$28,$11,$4D
  DEFB $83,$03,$C1,$51,$10,$6C,$28,$87
  DEFB $0C,$85,$C3,$61,$20,$A0,$78,$34
  DEFB $8D,$0A,$06,$C1,$81,$64,$49,$30
  DEFB $16,$17,$0B,$82,$03,$21,$E0,$72
  DEFB $58,$12,$0B,$03,$92,$4A,$81,$30
  DEFB $60,$48,$32,$1C,$05,$24,$08,$80
  DEFB $F1,$40,$40,$1C,$93,$0D,$83,$83
  DEFB $41,$21,$18,$50,$4A,$83,$23,$03
  DEFB $12,$E5,$50,$62,$4C,$B4,$8C,$0B
  DEFB $03,$13,$04,$22,$91,$42,$98,$46
  DEFB $2C,$15,$89,$C8,$60,$A9,$1D,$1E
  DEFB $06,$48,$90,$01,$C1,$80,$E8,$68
  DEFB $00,$5A,$06,$A3,$C1,$E1,$C0,$60
  DEFB $60,$36,$0F,$40,$96,$4A,$A1,$90
  DEFB $88,$38,$18,$19,$0F,$06,$42,$A1
  DEFB $10,$92,$00,$1C,$0D,$0E,$82,$C3
  DEFB $61,$A1,$02,$7C,$9C,$15,$0E,$84
  DEFB $52,$01,$B4,$C1,$4C,$0E,$10,$20
  DEFB $05,$52,$45,$20,$A8,$58,$22,$9D
  DEFB $07,$85,$41,$21,$44,$41,$28,$3C
  DEFB $0E,$0D,$A6,$08,$21,$90,$EA,$00
  DEFB $A4,$99,$21,$06,$42,$E8,$E0,$D0
  DEFB $6C,$26,$8F,$8A,$06,$02,$85,$10
  DEFB $52,$1C,$32,$14,$0C,$07,$0B,$A8
  DEFB $E3,$22,$38,$26,$8E,$07,$D4,$49
  DEFB $20,$30,$FA,$28,$38,$03,$06,$02
  DEFB $80,$08,$00,$30,$1C,$06,$19,$00
  DEFB $03,$11,$25,$22,$61,$04,$B4,$13
  DEFB $2D,$00,$01,$E1,$CA,$01,$38,$3C
  DEFB $10,$29,$A6,$8B,$81,$00,$F2,$40
  DEFB $28,$13,$0B,$05,$41,$08,$D0,$60
  DEFB $78,$10,$01,$4D,$98,$42,$C0,$F0
  DEFB $E0,$4D,$1F,$20,$0D,$83,$00,$40
  DEFB $A0,$10,$5C,$22,$1F,$4B,$14,$40
  DEFB $00,$B2,$C8,$88,$3A,$8C,$0E,$83
  DEFB $03,$A2,$14,$61,$88,$00,$0B,$2E
  DEFB $16,$93,$22,$24,$C9,$34,$34,$17
  DEFB $03,$A0,$C3,$09,$41,$18,$00,$30
  DEFB $19,$26,$86,$C3,$09,$00,$F0,$6C
  DEFB $1C,$18,$50,$44,$82,$61,$F0,$00
  DEFB $34,$16,$00,$0B,$88,$82,$62,$34
  DEFB $10,$44,$AE,$0F,$0C,$04,$03,$60
  DEFB $B0,$A8,$00,$3A,$59,$40,$14,$D0
  DEFB $00,$24,$01,$48,$12,$42,$0E,$01
  DEFB $40,$02,$64,$51,$75,$00,$0A,$40
  DEFB $12,$41,$22,$04,$00,$28,$1E,$0E
  DEFB $07,$04,$91,$34,$F4,$0C,$69,$02
  DEFB $4D,$0A,$94,$01,$A1,$40,$C8,$50
  DEFB $B0,$1C,$2E,$83,$92,$06,$40,$72
  DEFB $4C,$26,$0E,$4E,$06,$C3,$80,$D0
  DEFB $72,$5C,$1C,$12,$07,$83,$81,$E1
  DEFB $80,$3A,$8A,$22,$15,$26,$A4,$C1
  DEFB $81,$30,$62,$42,$92,$0F,$03,$82
  DEFB $4A,$81,$30,$60,$48,$32,$1C,$05
  DEFB $24,$0B,$60,$E0,$D0,$48,$46,$14
  DEFB $12,$A0,$C0,$80,$F1,$40,$40,$1C
  DEFB $93,$A6,$14,$10,$C4,$F4,$30,$35
  DEFB $33,$06,$02,$82,$03,$01,$30,$C0
  DEFB $44,$14,$12,$40,$D2,$42,$84,$C0
  DEFB $50,$61,$2A,$0E,$0B,$85,$13,$D0
  DEFB $F2,$90,$0C,$34,$11,$05,$81,$02
  DEFB $E0,$00,$00,$59,$20,$09,$01,$A1
  DEFB $C9,$24,$D0,$19,$34,$94,$49,$2C
  DEFB $01,$C1,$41,$D0,$80,$2C,$0A,$9E
  DEFB $0B,$01,$C0,$20,$00,$A2,$12,$2E
  DEFB $0D,$08,$85,$83,$09,$A0,$B1,$58
  DEFB $22,$14,$02,$26,$C8,$C0,$40,$00
  DEFB $48,$06,$00,$4D,$84,$D1,$81,$52
  DEFB $52,$70,$2C,$11,$42,$12,$48,$C0
  DEFB $50,$20,$14,$28,$13,$0B,$25,$40
  DEFB $60,$40,$A8,$54,$08,$04,$09,$04
  DEFB $80,$80,$44,$A0,$08,$06,$10,$09
  DEFB $95,$03,$20,$E0,$C8,$4C,$16,$0E
  DEFB $03,$86,$D4,$41,$60,$E0,$6C,$34
  DEFB $17,$08,$00,$C2,$81,$E0,$B8,$65
  DEFB $20,$43,$25,$83,$4A,$81,$10,$58
  DEFB $54,$1C,$0C,$02,$02,$C4,$61,$74
  DEFB $E9,$44,$1A,$0D,$01,$22,$62,$68
  DEFB $52,$10,$48,$24,$01,$00,$80,$00
  DEFB $01,$10,$90,$21,$39,$09,$29,$23
  DEFB $41,$48,$DA,$31,$34,$00,$8B,$05
  DEFB $80,$11,$70,$F0,$59,$10,$16,$11
  DEFB $43,$83,$41,$60,$F4,$38,$40,$00
  DEFB $48,$06,$00,$4D,$84,$D1,$81,$52
  DEFB $52,$70,$2C,$11,$42,$12,$48,$C0
  DEFB $50,$20,$14,$28,$13,$0B,$25,$40
  DEFB $60,$40,$A8,$54,$08,$04,$09,$04
  DEFB $80,$80,$44,$A0,$08,$06,$10,$09
  DEFB $95,$03,$20,$E0,$C8,$4C,$16,$0E
  DEFB $03,$EF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$EB,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$B3,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$D3,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$97,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$77,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$6F,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$05,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$DB,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FB,$FF,$01
  DEFB $01,$87,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$9F,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$8B,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$0F,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$B3,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$57,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$05,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$05,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FB,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$FF,$FF,$01,$01,$FF,$FF,$01
  DEFB $01,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$F3,$0D,$CE,$0B,$E3,$50,$CE
  DEFB $0B,$E4,$50,$1D,$17,$DC,$0A,$CE
  DEFB $0B,$E7,$50,$1A,$17,$DC,$0A,$D7
  DEFB $18,$38,$00,$38,$00,$0D,$19,$DB
  DEFB $02,$4D,$00,$34,$57,$CC,$00,$33
  DEFB $57,$8C,$08,$5C,$0E,$00,$47,$C0
  DEFB $57,$71,$0E,$F3,$0D,$21,$17,$C6
  DEFB $1E,$FF,$5E,$76,$1B,$03,$13,$00
  DEFB $3E,$00,$3C,$42,$42,$7E,$42,$42
  DEFB $00,$00,$7C,$42,$7C,$42,$42,$7C
  DEFB $00,$00,$3C,$42,$40,$40,$42,$3C
  DEFB $00,$00,$78,$44,$42,$42,$44,$78
  DEFB $00,$00,$7E,$40,$7C,$40,$40,$7E
  DEFB $00,$00,$7E,$40,$7C,$40,$40,$40
  DEFB $00,$00,$3C,$42,$40,$4E,$42,$3C
  DEFB $00,$00,$42,$42,$7E,$42,$42,$42
  DEFB $00,$00,$3E,$08,$08,$08,$08,$3E
  DEFB $00,$00,$02,$02,$02,$42,$42,$3C
  DEFB $00,$00,$44,$48,$70,$48,$44,$42
  DEFB $00,$00,$40,$40,$40,$40,$40,$7E
  DEFB $00,$00,$42,$66,$5A,$42,$42,$42
  DEFB $00,$00,$42,$62,$52,$4A,$46,$42
  DEFB $00,$00,$3C,$42,$42,$42,$42,$3C
  DEFB $00,$00,$7C,$42,$42,$7C,$40,$40
  DEFB $00,$00,$3C,$42,$42,$52,$4A,$3C
  DEFB $00,$00,$7C,$42,$42,$7C,$44,$42
  DEFB $00,$00,$3C,$40,$3C,$02,$42,$3C
  DEFB $00,$00,$FE,$10,$10,$10,$10,$10
  DEFB $00,$00,$42,$42,$42,$42,$42,$3C
  DEFB $00


C*******************************************************************************
C     MARK7C2.FOR
C     Last Modified 23-October-2009
C*******************************************************************************
C     Background:
C
C     MARK7C2.FOR was developed from MARK7C.FOR to increase the number of
C     obstacles supported from 20 to 30.  MARK7C2.FOR is required with SCAP
C     modules, BLAST (ver 1.12 and later) and BTOPS (ver 4.17 and later).  
C     MARK7C.FOR is retained for use with prior versions of the SCAP modules 
C     or older programs like MARK7J and MARK7L, that have not been updated.
C*******************************************************************************
      SUBROUTINE ACCUM(N1,N2,N3,N4,N5,N6,N7,NOMOR,ARG)
C
C---- THIS ROUTINE ACCUMULATES THE ANSWER FOR ARITHMETIC INSTRUCTIONS.
C
C---- LOCAL VARIABLE DECLARATIONS
C
      REAL ARG(999)
C
C---- COMMON STORAGE (MARK VII:  JULY 1, 1988)
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     $             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     $             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
C
      IWORK = -1
      IF (N5-1) 100,200,650
100   IF (KINDU-2) 150,150,200
150   IF (KINDV-2) 200,200,600
200   CALL ARITH(ANSWR,ARG(N1),ARG(N2),KINDU,NOMOR)
      IWORK = 1
      IF (NOMOR) 1200,250,250
250   IF (N6) 300,300,900
300   IF (KINDV) 1200,1200,350
350   IF (KINDV-2) 400,400,450
400   IF (KINDX-2) 450,450,900
450   CALL ARITH(SAVE,ANSWR,ARG(N3),KINDV,NOMOR)
      ANSWR = SAVE
      IF (NOMOR) 1200,500,500
500   IF (KINDX) 1200,1200,550
550   CALL ARITH(SAVE,ANSWR,ARG(N4),KINDX,NOMOR)
      ANSWR = SAVE
      GO TO 1200
600   IF (N6) 650,650,900
650   CALL ARITH(WORK,ARG(N2),ARG(N3),KINDV,NOMOR)
      IF (NOMOR) 1200,700,700
700   IF (KINDX-2) 750,750,800
750   CALL ARITH(ANSWR,ARG(N1),WORK,KINDU,NOMOR)
      IF (NOMOR) 1200,500,500
800   CALL ARITH(SAVE,WORK,ARG(N4),KINDX,NOMOR)
      WORK = SAVE
      IF (NOMOR) 1200,850,850
850   CALL ARITH(ANSWR,ARG(N1),WORK,KINDU,NOMOR)
      GO TO 1200
900   CALL ARITH(WORK,ARG(N3),ARG(N4),KINDX,NOMOR)
      IF (NOMOR) 1200,950,950
950   IF (N6) 1050,1050,1000
1000  IF (IWORK) 1100,1100,1050
1050  CALL ARITH(SAVE,ANSWR,WORK,KINDV,NOMOR)
      ANSWR = SAVE
      GO TO 1200
1100  CALL ARITH(SAVE,ARG(N2),WORK,KINDV,NOMOR)
      WORK = SAVE
      IF (NOMOR) 1200,1150,1150
1150  CALL ARITH(ANSWR,ARG(N1),WORK,KINDU,NOMOR)
1200  ARG(N7) = ANSWR
      RETURN
      END
      SUBROUTINE ARITH(A,B,C,K,NOMOR)
C
C---- THIS ROUTINE PERFORMS ONE ARITHMETIC OPERATION.
C
      IF(K.EQ.1)THEN
       A = B + C
      ELSEIF(K.EQ.2)THEN
       A = B - C
      ELSEIF(K.EQ.3)THEN
       A = B * C
      ELSEIF(C.NE.0.)THEN
       A = B / C
      ELSE
       NOMOR = -3
      ENDIF
C
      RETURN
      END
C*************************************************************************
      SUBROUTINE CMPUT(NOMOR,KARD3,TABLE,ARG,INSTB,TNOS,MAXTNO,
     &                 ILOC,IDOARY)
C
C---- LOCAL VARIABLE DECLARATIONS
C
      REAL             ARG(999),TABLE(*),TNOS(899)
C
      INTEGER          IDOARY(999),ILOC(899),INSTB(13,*),KEEP(4)
C
      DOUBLE PRECISION RN7,RGT,RLT

      LOGICAL TRCFIL,INMTRC
      COMMON/NMTRC/INMTRC
      INTEGER PRVINS

C
C---- COMMON STORAGE (MARK VII:  October 21, 2009)
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     $             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     &             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK5/IDUM(51),IDARG1(50),IDARG2(50),INSDUM
      COMMON/BLOKX/AVOID(2,30)

      SAVE TRCFIL
      DATA TRCFIL/.FALSE./
      DATA PRVINS/0/ 
C
C---- INITIALIZE DO POINTER ARRAY:
C
      IF(IDOARY(INSTB(1,1)/100).LE.3000)THEN
       ISAVE = INSTB(1,1) / 100
       IDOARY(ISAVE) = 1
C
       DO 5 I=2,KARD3 / 5
        ITEST = INSTB(1,I) / 100
C
        IF(ITEST.NE.ISAVE)THEN
         IDOARY(ISAVE) = IDOARY(ISAVE) * 10000 + I - 1
         ISAVE = ITEST
         IDOARY(ISAVE) = I
        ENDIF
5      CONTINUE
C
       IDOARY(ISAVE) = IDOARY(ISAVE) * 10000 + I - 1
      ENDIF
C
      KEEP2  = 0
      NINST  = NOMOR
C
10    INSDUM = INSTB(1,NINST)

C     Instruction trace code.  
C     Write instruction number trace, if requested
      IF (INMTRC) THEN
C        Instruction trace flag is on.
C        If trace file is not already openned, open it.
C        Make sure the file is new.
         LUNITR = 9
         IF (.NOT. TRCFIL) THEN
            OPEN (UNIT=LUNITR,FILE='InstructionTrace.txt',
     +            STATUS='UNKNOWN')
            CLOSE (UNIT=LUNITR,STATUS='DELETE')
            OPEN (UNIT=LUNITR,FILE='InstructionTrace.txt',
     +            STATUS='NEW')
            TRCFIL = .TRUE.
         ENDIF
C        This is before the instruction has executed.
C        So the ARG array still reflect what happened
C        after the previous instruction was executed.
         CALL ITRIT8(LUNITR,PRVINS,NOMOR,ARG)
         PRVINS = INSDUM
      ENDIF
C     End of instruction trace code

      INCOD  = INSDUM / 100
C
C---- BRANCH TO INSTRUCTION TYPE
C
      GOTO( 100, 200, 300, 400, 500, 600,
     &      700, 800, 900,1000,1100,1200)INSTB(2,NINST)
C
      IF(INSTB(2,NINST).LT.1)THEN
       IF(IDUM(51).GT.0)CALL DUMP
       NOMOR = -1
      ELSE
       NOMOR = -8
      ENDIF
C
      GOTO 9999
C
C---- PROCESS TABLE LOOKUP INSTRUCTION (TYPE 1)
C
100   KEXT = 0
C
      IF(INSTB(12,NINST).EQ.0)THEN
       ANSWR= AVOID(NINT(ARG(INSTB(4,NINST))),NINT(ARG(INSTB(5,NINST))))
      ELSE
       KINDU = INSTB( 8,NINST)
       KINDV = INSTB( 9,NINST)
       KINDX = INSTB(10,NINST)
       KINDY = INSTB(11,NINST)
       N5    = INSTB(12,NINST)
       N6    = INSTB(13,NINST)
       IF(N5.GT.899)N5 = ARG(N5) + .5
       IF(N6.GT.899)N6 = ARG(N6) + .5
C
       CALL FIND(KINDU,ARGM1,INSTB(4,NINST),ARGU,INSTB(6,NINST),ARGX,
     &           N5,I,NOU,NOV,ARG,TNOS,MAXTNO,ILOC)
       CALL FIND(KINDX,ARGM2,INSTB(5,NINST),ARGV,INSTB(7,NINST),ARGY,
     &           N6,J,NOX,NOY,ARG,TNOS,MAXTNO,ILOC)
C
       IF(N5.GT.0.AND.N5.LT.900)THEN
        IF(TNOS(N5).EQ.0.)KEXT = 1
       ENDIF
C
       IF(N6.GT.0.AND.N6.LT.900)THEN
        IF(TNOS(N6).EQ.0.)KEXT = 2
       ENDIF
C
       IF(KEXT.LT.1)CALL LOKUP(I,J,TABLE)
      ENDIF
C
      IF(KEXT.LT.1)THEN
       ARG(INSTB(3,NINST)) = ANSWR
       GOTO 2000
      ELSE
       NOMOR=-2
C
       IF(KEXT.EQ.1)THEN
        KEXT = N5
       ELSE
        KEXT = N6
       ENDIF
C
       GOTO 9999
      ENDIF
C
C---- PROCESS ARITHMETIC INSTRUCTION (TYPE 2)
C
200   KINDU = INSTB( 8,NINST)
      KINDV = INSTB( 9,NINST)
      KINDX = INSTB(10,NINST)
C
      CALL ACCUM(INSTB( 4,NINST),INSTB( 5,NINST),INSTB( 6,NINST),
     &           INSTB( 7,NINST),INSTB(12,NINST),INSTB(13,NINST),
     &           INSTB( 3,NINST),NOMOR,ARG)
C
      IF(NOMOR.GT.-1)THEN
       GOTO 2000
      ELSE
       GOTO 9999
      ENDIF
C
C---- PROCESS MAX INSTRUCTION (TYPE 3)
C
300   CALL PICKMX(INSTB(4,NINST),INSTB(5,NINST),INSTB(6,NINST),
     &            INSTB(7,NINST),INSTB(3,NINST),ARG)
      GOTO 2000
C
C---- PROCESS MIN INSTRUCTION (TYPE 4)
C
400   CALL PICKMN(INSTB(4,NINST),INSTB(5,NINST),INSTB(6,NINST),
     &            INSTB(7,NINST),INSTB(3,NINST),ARG)
      GOTO 2000
C
C---- PROCESS STORE CONSTANT INSTRUCTION (TYPE 5)
C
500   CALL CONST(INSTB(5,NINST),INSTB(8,NINST),ARG(INSTB(3,NINST)))
C
      IF(INSTB(6,NINST).EQ.0)THEN
       GOTO 2000
      ELSEIF(INSTB(6,NINST).EQ.2)THEN
       JUMP = INSTB(7,NINST)
       GOTO 905
      ELSEIF(INSTB(6,NINST).EQ.1)THEN
       GOTO 1000
      ELSE
       GOTO 1100
      ENDIF
C
C---- PROCESS STORE ARG IN ARG INSTRUCTION (TYPE 6)
C
600   IF(INSTB(8,NINST).NE.1)THEN
       ARG(INSTB(3,NINST)) =  ARG(INSTB(5,NINST))
      ELSE
       ARG(INSTB(3,NINST)) = -ARG(INSTB(5,NINST))
      ENDIF
C
      IF(INSTB(6,NINST).EQ.0)THEN
       GOTO 2000
      ELSEIF(INSTB(6,NINST).EQ.3)THEN
       GOTO 1100
      ELSEIF(INSTB(6,NINST).EQ.2)THEN
       JUMP = INSTB(7,NINST)
       GOTO 905
      ELSE
       GOTO 1000
      ENDIF
C
C---- PROCESS IF INSTRUCTION (TYPE 7)
C
700   RN7 = ARG(INSTB(3,NINST))
C
      IF(INSTB(4,NINST).GT.0)THEN
       RGT = ARG(INSTB(4,NINST))
      ELSE
       RGT = -1.D10
      ENDIF
C
      IF(INSTB(5,NINST).GT.0)THEN
       RLT = ARG(INSTB(5,NINST))
      ELSE
       RLT =  1.D10
      ENDIF
C
      IBRNCH = 0
C
      IF(INSTB(8,NINST).EQ.2)THEN
       IF(RN7.GT.RGT.AND.RN7.LT.RLT)IBRNCH = INSTB(6,NINST)
      ELSEIF(INSTB(8,NINST).EQ.1)THEN
       IF(RN7.GT.RGT.AND.RN7.LE.RLT+1.D-5)IBRNCH = INSTB(6,NINST)
      ELSEIF(INSTB(8,NINST).EQ.-1)THEN
       IF(RN7.GE.RGT-1.D-5.AND.RN7.LT.RLT)IBRNCH = INSTB(6,NINST)
      ELSEIF(INSTB(8,NINST).EQ.0)THEN
       IF(INSTB(4,NINST).EQ.0.OR.INSTB(5,NINST).EQ.0)THEN
        IF(RN7.EQ.ARG(INSTB(4,NINST)))IBRNCH = INSTB(6,NINST)
       ELSE
        IF(RN7.GE.RGT-1.D-5.AND.RN7.LE.RLT+1.D-5)IBRNCH = INSTB(6,NINST)
       ENDIF
      ELSE
       NOMOR = -9
       GOTO 9999
      ENDIF
C
      IF(IBRNCH.EQ.2)THEN
       JUMP = INSTB(7,NINST)
       GOTO 905
      ELSEIF(IBRNCH.EQ.0)THEN
       GOTO 2000
      ELSEIF(IBRNCH.EQ.1)THEN
       GOTO 1000
      ELSE
       GOTO 1100
      ENDIF
C
C---- PROCESS LIMIT INSTRUCTION (TYPE 8)
C
800   IF(INSTB(3,NINST).EQ.3)THEN
       N2 = INSTB(5,NINST)
       N3 = INSTB(6,NINST)
       IF(N3.GT.9)N3 = 10 - N3
       CALL CONST(N2,INSTB(7,NINST),ARG(51))
       CALL CONST(N3,INSTB(8,NINST),ARG(52))
      ELSEIF(INSTB(3,NINST).EQ.1)THEN
       N2 = INSTB(5,NINST)
       CALL CONST(N2,INSTB(7,NINST),ARG(51))
      ELSE
       N3 = INSTB(6,NINST)
       IF(N3.GT.9)N3 = 10 - N3
       CALL CONST(N3,INSTB(8,NINST),ARG(52))
      ENDIF
C
      GOTO 2000
C
C---- PROCESS SKIP INSTRUCTION (TYPE 9)
C
900   JUMP = INSTB(3,NINST)
C
905   NINST = NINST + JUMP
      IF(NINST.GT.KARD3/5)NINST = KARD3/5
      IF(INSTB(1,NINST)/100.GT.INCOD)
     &  NINST = IDOARY(INCOD) - IDOARY(INCOD) / 10000 * 10000
      GOTO 2000
C
C---- PROCESS GOTO INSTRUCTION (TYPE 10)
C
1000  LOOP = LOOP + 1
C
      IF(LOOP.LT.NOLOP)THEN
       IELEM = IDOARY(INSTB(7,NINST)/100)
       ILOW  = IELEM / 10000
       IHIGH = IELEM - ILOW * 10000
       IELEM = IHIGH
C
1010   IF(INSTB(1,IELEM).GT.INSTB(7,NINST))THEN
        IHIGH = IELEM
       ELSEIF(INSTB(1,IELEM).LT.INSTB(7,NINST))THEN
        ILOW = IELEM
       ELSE
        IF(IDUM(51).GT.0)CALL DUMP
        NINST=IELEM
        GOTO 10
       ENDIF
C
       IF(IHIGH.NE.ILOW)THEN
        IELEM = (ILOW + IHIGH) / 2
        GOTO 1010
       ELSE
        NOMOR = -5
        GOTO 9999
       ENDIF
      ELSE
       NOMOR = -4
       GOTO 9999
      ENDIF
C
C---- PROCESS DO INSTRUCTION (TYPE 11)
C
1100  KEEP2 = KEEP2 + 1
C
      IF(KEEP2.LT.5)THEN
       KEEP(KEEP2) = NINST + 1
       KEEP1 = INSTB(7,NINST)
      ELSE
       NOMOR = -7
       GOTO 9999
      ENDIF
C
C---- THE KEEP1 ELEMENT OF THE IDOARY ARRAY (IF NOT EQUAL TO ZERO)
C     STORES THE ELEMENT OF THE INSTB ARRAY IN WHICH THE FIRST OPTRAN
C     INSTRUCTION OF THE CODE DECADE BEING ACESSED BY A DO OCCURS:
 
      IF(IDOARY(KEEP1).NE.0)THEN
       NINST = IDOARY(KEEP1) / 10000
       GOTO 10
      ELSE
       NOMOR = -6
       GOTO 9999
      ENDIF
C
C---- PROCESS LOOP INSTRUCTION (TYPE 12)
C
1200  IF(INSTB(8,NINST).GE.0)THEN
       NOLOP = INSTB(8,NINST)
      ELSE
       LOOP = 0
      ENDIF
C
2000  CONTINUE



      IF(IDUM(51).GT.0)CALL DUMP
      NINST = NINST + 1
C
      IF(KEEP2.GT.0.AND.INSTB(1,NINST)/100.NE.INCOD)THEN
       NINST = KEEP(KEEP2)
C
       IF(IDUM(51).GT.0)THEN
        INSDUM = INSTB(1,NINST-1)
        CALL DUMP
       ENDIF
C
       KEEP2 = KEEP2 - 1
      ENDIF
      GOTO 10
C
9999  CONTINUE

C     Write instruction number trace, if requested
      IF (INMTRC .AND. TRCFIL) THEN
C        Instruction trace flag is on
         LUNITR = 9
         CALL ITRIT8(LUNITR,INSDUM,NOMOR,ARG)
      ENDIF
C     End of instruction trace code

      RETURN
      END
C*************************************************************************
      SUBROUTINE CONST(J,K,A)
C
C---- THIS ROUTINE CONSTRUCTS FLOATING POINT CONSTANTS
C
      DOUBLE PRECISION WORK
C
      IF(J.EQ.0)THEN
       A = K
      ELSE
       WORK = K
C
       IF(J.LT.0)THEN
        DO 100 I=1,-J
         WORK = WORK * 1.D-1
100     CONTINUE
       ELSE
        DO 200 I=1,J
         WORK = WORK * 1.D+1
200     CONTINUE
       ENDIF
C
       A = WORK
      ENDIF
C
      RETURN
      END
      SUBROUTINE FIND(K,AR,N1,A1,N3,A3,NT,ISUM,NN1,NN2,
     &                ARG,TNOS,MAXTNO,ILOC)
C
C---- THIS ROUTINE SETS ARGUMENTS,KINDS,AND FINDS TABLE.
C
C---- LOCAL VARIABLE DECLARATIONS
C
      REAL    ARG(999),TNOS(899)
C
      INTEGER ILOC(899)
C
      IF(K.GT.1)THEN
       IF(K.LT.4)THEN
        AR = ARG(51)
       ELSE
        AR = ARG(52)
C
        IF(K.EQ.4)THEN
         K = 2
        ELSE
         K = 3
        ENDIF
       ENDIF
      ENDIF
C
      IF(N1.GT.0)THEN
       A1 = ARG(N1)
      ELSE
       A1 = 0.
      ENDIF
C
      IF(N3.LT.1)THEN
       A3 = 0.
      ELSEIF(N3.LT.MAXTNO)THEN
       A3 = ARG(N3)
      ELSE
       A3 = -1.E7
      ENDIF
C
C---- LOCATE TABLE AND DETERMINE ITS DIMENSIONS.  THE NT ELEMENT OF THE
C     ILOC ARRAY CONTAINS THE ELEMENT NUMBER OF THE TABLE ARRAY WHERE
C     TABLE NUMBER NT BEGINS.
C
      IF(NT.GT.0)THEN
       ISUM  = ILOC(NT)
       ITAB  = TNOS(NT)
       IWORK = TNOS(NT) * 100. + .5
       NN1   = IWORK - ITAB * 100
       NN2   = (ITAB-NN1) / (NN1+1)
       IF(NN2.LT.1)NN2 = 1
      ELSE
       ISUM = 1
       NN2  = 0
      ENDIF
 
      RETURN
      END
      SUBROUTINE LOKUP(I,J,TABLE)
C
C---- THIS ROUTINE MANIPULATES ARGUMENTS AND TABLE LOOKUP RESULTS.
C
C---- LOCAL VARIABLE DECLARATIONS
C
      REAL TABLE(*)
C
C---- COMMON STORAGE (MARK VII:  JULY 1, 1988)
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     $             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     $             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
C
      NX = NOU
      NY = NOV
C
      CALL TABLU(TABLE(I),ARGM1,SAVE)
C
      IF(KEXT.LT.1)THEN
       IF(KINDY.LT.1)THEN
        ANSWR = SAVE
        GOTO 999
       ELSEIF(KINDV.EQ.4.OR.KINDV.EQ.5)THEN
        ANSWR = SAVE
       ELSEIF(KINDV.EQ.3)THEN
        IF(ARGY.GT.SAVE)ARGY = SAVE
       ELSEIF(ARGY.LE.-1.E6)THEN
        ARGY  = SAVE
       ELSE
        ARGX  = SAVE
       ENDIF
C
       NX    = NOX
       NY    = NOY
       ARGU  = ARGX
       ARGV  = ARGY
       KINDU = KINDX
       KINDV = KINDY
       CALL TABLU(TABLE(J),ARGM2,SAVE)
C
       IF(KEXT.LT.1)THEN
        IF(KINDY.EQ.4)THEN
         IF(ANSWR.GT.SAVE)ANSWR = SAVE
        ELSEIF(KINDY.EQ.5)THEN
         IF(ANSWR.LT.SAVE)ANSWR = SAVE
        ELSE
         ANSWR = SAVE
        ENDIF
       ELSE
        KEXT  = 2
       ENDIF
      ELSE
       KEXT = 1
      ENDIF
C
999   RETURN
      END
      SUBROUTINE PICKMN(N1,N2,N3,N4,N7,ARG)
C
C---- THIS ROUTINE PICKS OUT THE MIN OF ARG(N1) THROUGH ARG(N4).
C
C---- LOCAL VARIABLE DECLARATIONS
C
      REAL ARG(999)
C
C---- COMMON STORAGE (MARK VII:  JULY 1, 1988)
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     $             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     $             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
C
      ANSWR = ARG(N1)
C
      IF(ANSWR.GT.ARG(N2))ANSWR = ARG(N2)
C
      IF(N3.GT.0)THEN
       IF(ANSWR.GT.ARG(N3))ANSWR = ARG(N3)
       IF(N4.GT.0)THEN
          IF(ANSWR.GT.ARG(N4))ANSWR = ARG(N4)
       ENDIF
      ENDIF
C
      ARG(N7) = ANSWR
C
      RETURN
      END
      SUBROUTINE PICKMX(N1,N2,N3,N4,N7,ARG)
C
C---- THIS ROUTINE PICKS OUT THE MAX OF ARG(N1) THROUGH ARG(N4).
C
C---- LOCAL VARIABLE DECLARATIONS
C
      REAL ARG(999)
C
C---- COMMON STORAGE (MARK VII:  JULY 1, 1988)
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     $             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     $             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
C
      ANSWR = ARG(N1)
C
      IF(ANSWR.LT.ARG(N2))ANSWR = ARG(N2)
C
      IF(N3.GT.0)THEN
       IF(ANSWR.LT.ARG(N3))ANSWR = ARG(N3)
       IF(N4.GT.0)THEN
         IF(ANSWR.LT.ARG(N4))ANSWR = ARG(N4)
       ENDIF
      ENDIF
C
      ARG(N7) = ANSWR
C
      RETURN
      END
      SUBROUTINE REVSR(TABLE,Z,Y,X)
C
C---- REVERSE INTERPOLATION ROUTINE FOR TWO DIMENSIONAL TABLE.  GIVEN Y
C     AND Z, IT CALCULATES X, WHERE Z=F(X,Y).
C
C     INCRM = INDEX INCREMENT FOR CONSECUTIVE ENTRIES.
C     INIT  = INDEX OF FIRST ENTRY BEING SEARCHED.
C     KEXT  = ERROR RETURN. ZERO IF SUCCESS.  ONE IF Z OUTSIDE TABLE.
C     NTRY  = NUMBER OF ENTRIES OF VARIABLE
C     NX,NY = NUMBER OF ENTRIES FOR X AND Y AXIS.
C
      REAL TABLE(960)
C
C---- COMMON STORAGE (MARK VII:  JULY 1, 1988)
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,IDUM1(4),RDUM1(7),IDUM2(10),RDUM2(2)
C
      XFUN(TA,TB,G,G1,G2) = TA + ((G-G1) / (G2-G1)) * (TB-TA)
C
      KEXT = 0
C
      IF(NY.GT.1)THEN
       INIT  = NX + 1
       INCRM = INIT
       NTRY  = NY
       CALL SRCH(TABLE,Y,INIT,INCRM,Y1,Y2,NY1,IY)
C
       IF(IY.LT.1)THEN
        INIT = NY1 * INCRM + 1
C
        IF(IY.EQ.0)THEN
         ZA = XFUN(TABLE(INIT),TABLE(INIT+INCRM),Y,Y1,Y2)
C
         IF(Z.EQ.ZA)THEN
          X = TABLE(1)
          GOTO 999
         ELSE
          DO 100 I=2,NX
           INIT = INIT + 1
           ZB = XFUN(TABLE(INIT),TABLE(INIT+INCRM),Y,Y1,Y2)
C
           IF(Z.GT.ZB)THEN
            IF(Z.LT.ZA)THEN
             X = XFUN(TABLE(I-1),TABLE(I),Z,ZA,ZB)
             GOTO 999
            ENDIF
           ELSEIF(Z.LT.ZB)THEN
            IF(Z.GT.ZA)THEN
             X = XFUN(TABLE(I-1),TABLE(I),Z,ZA,ZB)
             GOTO 999
            ENDIF
           ELSE
            X = TABLE(I)
            GOTO 999
           ENDIF
C
           ZA = ZB
100       CONTINUE
C
          KEXT = 1
          GOTO 999
         ENDIF
        ENDIF
       ELSE
        KEXT = 1
        GOTO 999
       ENDIF
      ELSE
       INIT = NX + 1
      ENDIF
 
      INCRM = 1
      NTRY = NX
      CALL SRCH2(TABLE,Z,INIT,INCRM,ZA,ZB,NZ,IZ)
C
      IF(IZ.EQ.0)THEN
       X = XFUN(TABLE(NZ),TABLE(NZ+1),Z,ZA,ZB)
      ELSEIF(IZ.LT.0)THEN
       X = TABLE(NZ)
      ELSE
       KEXT = 1
      ENDIF
C
999   RETURN
      END
      SUBROUTINE RVRSY(TABLE,Z,X,Y)
C
C---- REVERSE INTERPOLATION ROUTINE FOR TWO DIMENSIONAL TABLE.  GIVEN Y
C     AND Z, IT CALCULATES X, WHERE Z=F(X,Y).
C
C     INCRM = INDEX INCREMENT FOR CONSECUTIVE ENTRIES.
C     INIT  = INDEX OF FIRST ENTRY BEING SEARCHED.
C     KEXT  = ERROR RETURN. ZERO IF SUCCESS.  ONE IF Z OUTSIDE TABLE.
C     NTRY  = NUMBER OF ENTRIES OF VARIABLE
C     NX,NY = NUMBER OF ENTRIES FOR X AND Y AXIS.
C
      REAL TABLE(960)
C
C---- COMMON STORAGE (MARK VII:  JULY 1, 1988)
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,IDUM1(4),RDUM1(7),IDUM2(10),RDUM2(2)
C
      XFUN(TA,TB,G,G1,G2) = TA + ((G-G1) / (G2-G1)) * (TB-TA)
C
      KEXT = 0
C
      IF(NY.GT.1)THEN
       INIT  = 1
       INCRM = 1
       NTRY  = NX
       CALL SRCH(TABLE,X,INIT,INCRM,X1,X2,NX1,IX)
C
       IF(IX.LT.1)THEN
        INCRM = NX + 1
        INIT  = INCRM + NX1
        NTRY  = NY
C
        IF(IX.EQ.0)THEN
         ZA = XFUN(TABLE(INIT),TABLE(INIT+1),X,X1,X2)
C
         IF(Z.EQ.ZA)THEN
          Y = TABLE(INCRM)
          GOTO 999
         ELSE
          DO 100 I=2,NY
           INIT = INIT + INCRM
           ZB = XFUN(TABLE(INIT),TABLE(INIT+1),X,X1,X2)
C
           IF(Z.GT.ZB)THEN
            IF(Z.LT.ZA)THEN
             ITI = I * INCRM
             Y = XFUN(TABLE(ITI-INCRM),TABLE(ITI),Z,ZA,ZB)
             GOTO 999
            ENDIF
           ELSEIF(Z.LT.ZB)THEN
            IF(Z.GT.ZA)THEN
             ITI = I * INCRM
             Y = XFUN(TABLE(ITI-INCRM),TABLE(ITI),Z,ZA,ZB)
             GOTO 999
            ENDIF
           ELSE
            Y = TABLE(I*INCRM)
            GOTO 999
           ENDIF
C
           ZA = ZB
100       CONTINUE
C
          KEXT = 1
          GOTO 999
         ENDIF
        ENDIF
       ELSE
        KEXT = 1
        GOTO 999
       ENDIF
      ELSE
       INCRM = 1
       INIT  = NX + 1
       NTRY  = NX
      ENDIF
 
      CALL SRCH2(TABLE,Z,INIT,INCRM,ZA,ZB,NZ,IZ)
C
      IF(IZ.EQ.0)THEN
       NTI = NZ * INCRM
       Y = XFUN(TABLE(NTI),TABLE(NTI+INCRM),Z,ZA,ZB)
      ELSEIF(IZ.LT.0)THEN
       Y = TABLE(NZ*INCRM)
      ELSE
       KEXT = 1
      ENDIF
C
999   RETURN
      END
      SUBROUTINE SRCH(TABLE,ARG,INIT,INCRM,TAB1,TAB2,NTAB1,IRROR)
C
C---- LOCATES INDEPENDENT VARIABLES CLOSEST TO ARG.
C
C---- LOCAL VARIABLE DECLARATIONS
C
C     INCRM  = DIFFERENCE BETWEEN INDICES OF CONSECUTIVE VALUES.
C     INIT   = INDEX OF FIRST ENTRY IN LIST BEING SEARCHED.
C     IRROR  = ERROR RETURN. MINUS ONE IF ARGUMENT IS A LATTICE POINT,
C              PLUS ONE IF ARGUMENT IS OUTSIDE OF TABLE.
C     NTAB1  = NUMBER OF ENTRIES LESS THAN ARGUMENT.
C     TAB1 &
C     TAB2   = VALUES OF CLOSEST ENTRIES.
C
      REAL TABLE(960)
C
C---- COMMON STORAGE (MARK VII:  JULY 1, 1988)
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,IDUM1(4),RDUM1(7),IDUM2(10),RDUM2(2)
C
C
      TOL(A,XC,XF) = DABS((DBLE(A) - DBLE(XC)) / (DBLE(XC) - DBLE(XF)))
C
      LAST  = INIT + (NTRY  - 1) * INCRM
C
      NTAB1 = NTRY / 2
      ISTRT = INIT + (NTAB1 - 1) * INCRM
      RTIMI = TABLE(ISTRT)
C
      IF(ARG.LE.RTIMI)THEN
       NTAB1 = 1
       ISTRT = INIT
       RTIMI = TABLE(ISTRT)
      ENDIF
C
      IF(ARG.GT.RTIMI)THEN
       DO 100 I=ISTRT + INCRM,LAST,INCRM
        RTI = TABLE(I)
C
        IF(ARG.GT.RTI)THEN
         NTAB1 = NTAB1 + 1
         RTIMI = RTI
        ELSEIF(ARG.LT.RTI)THEN
         IF(RTI-ARG.LT.ARG-RTIMI)THEN
          IF(TOL(ARG,RTI,RTIMI).GT.1.E-05)THEN
           IRROR = 0
           TAB1  = RTIMI
           TAB2  = RTI
           GOTO 999
          ELSE
           IRROR = -1
           NTAB1 = NTAB1 + 1
           TAB1  = RTI
           GOTO 999
          ENDIF
         ELSE
          IF(TOL(ARG,RTIMI,RTI).GT.1.E-05)THEN
           IRROR = 0
           TAB1  = RTIMI
           TAB2  = RTI
           GOTO 999
          ELSE
           IRROR = -1
           TAB1  = RTIMI
           GOTO 999
          ENDIF
         ENDIF
        ELSE
         IRROR = -1
         TAB1  = RTI
         NTAB1 = NTAB1 + 1
         GOTO 999
        ENDIF
100    CONTINUE
C
       RTIMI = TABLE(LAST-INCRM)
C
       IF(RTI.NE.RTIMI)THEN
        IF(TOL(ARG,RTI,RTIMI).LE.1.E-05)THEN
         IRROR = -1
         TAB1  = RTI
         GOTO 999
        ENDIF
       ENDIF
C
      ELSEIF(ARG.EQ.RTIMI)THEN
       IRROR = -1
       TAB1  = RTIMI
       GOTO 999
      ELSE
       RTI = TABLE(ISTRT + INCRM)
C
       IF(RTIMI.NE.RTI)THEN
        IF(TOL(ARG,RTIMI,RTI).LE.1.E-05)THEN
         IRROR = -1
         TAB1  = RTIMI
         GOTO 999
        ENDIF
       ENDIF
      ENDIF
C
      IRROR = 1
C
999   RETURN
      END
      SUBROUTINE SRCH2(TABLE,ARG,INIT,INCRM,TAB1,TAB2,NTAB1,IRROR)
C
C---- LOCATES INDEPENDENT VARIABLES CLOSEST TO ARG.
C
C---- LOCAL VARIABLE DECLARATIONS
C
C     INCRM  = DIFFERENCE BETWEEN INDICES OF CONSECUTIVE VALUES.
C     INIT   = INDEX OF FIRST ENTRY IN LIST BEING SEARCHED.
C     IRROR  = ERROR RETURN. MINUS ONE IF ARGUMENT IS A LATTICE POINT,
C              PLUS ONE IF ARGUMENT IS OUTSIDE OF TABLE.
C     NTAB1  = NUMBER OF ENTRIES LESS THAN ARGUMENT.
C     TAB1 &
C     TAB2   = VALUES OF CLOSEST ENTRIES.
C
      REAL TABLE(960)
C
C---- COMMON STORAGE (MARK VII:  JULY 1, 1988)
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,IDUM1(4),RDUM1(7),IDUM2(10),RDUM2(2)
C
C
      TOL(A,XC,XF) = DABS((DBLE(A) - DBLE(XC)) / (DBLE(XC) - DBLE(XF)))
C
      LAST  = INIT + (NTRY - 1) * INCRM
      NTAB1 = 1
      RTIMI = TABLE(INIT)
C
      IF(ARG.EQ.RTIMI)THEN
       IRROR = -1
       TAB1  = RTIMI
       GOTO 999
      ELSE
       ISINIT = INIT + INCRM
       RTI    = TABLE(ISINIT)
C
       IF(RTIMI.NE.RTI)THEN
        IF(TOL(ARG,RTIMI,RTI).LE.1.E-05)THEN
         IRROR = -1
         TAB1  = RTIMI
         GOTO 999
        ENDIF
       ENDIF
      ENDIF
C
      DO 100 I=ISINIT,LAST,INCRM
       RTI = TABLE(I)
C
       IF(ARG.GT.RTI)THEN
        IF(ARG.LT.RTIMI)THEN
         IF(ARG-RTI.LT.RTIMI-ARG)THEN
          IF(TOL(ARG,RTI,RTIMI).GT.1.E-05)THEN
           IRROR = 0
           TAB1  = RTIMI
           TAB2  = RTI
           GOTO 999
          ELSE
           IRROR = -1
           NTAB1 = NTAB1 + 1
           TAB1  = RTI
           GOTO 999
          ENDIF
         ELSE
          IF(TOL(ARG,RTIMI,RTI).GT.1.E-05)THEN
           IRROR = 0
           TAB1  = RTIMI
           TAB2  = RTI
           GOTO 999
          ELSE
           IRROR = -1
           TAB1  = RTIMI
           GOTO 999
          ENDIF
         ENDIF
        ENDIF
       ELSEIF(ARG.LT.RTI)THEN
        IF(ARG.GT.RTIMI)THEN
         IF(RTI-ARG.LT.ARG-RTIMI)THEN
          IF(TOL(ARG,RTI,RTIMI).GT.1.E-05)THEN
           IRROR = 0
           TAB1  = RTIMI
           TAB2  = RTI
           GOTO 999
          ELSE
           IRROR = -1
           NTAB1 = NTAB1 + 1
           TAB1  = RTI
           GOTO 999
          ENDIF
         ELSE
          IF(TOL(ARG,RTIMI,RTI).GT.1.E-05)THEN
           IRROR = 0
           TAB1  = RTIMI
           TAB2  = RTI
           GOTO 999
          ELSE
           IRROR = -1
           TAB1  = RTIMI
           GOTO 999
          ENDIF
         ENDIF
        ENDIF
       ELSE
        IRROR = -1
        TAB1  = RTI
        NTAB1 = NTAB1 + 1
        GOTO 999
       ENDIF
C
       NTAB1 = NTAB1 + 1
       RTIMI = RTI
100   CONTINUE
C
      RTIMI = TABLE(LAST-INCRM)
C
      IF(RTI.NE.RTIMI)THEN
       IF(TOL(ARG,RTI,RTIMI).LE.1.E-05)THEN
        IRROR = -1
        TAB1  = RTI
        GOTO 999
       ENDIF
      ENDIF
C
      IRROR = 1
C
999   RETURN
      END
      SUBROUTINE TABLU(TABLE,ARGM,SAVE)
C
C---- THIS ROUTINE CONTROLS EACH TABLE LOOKUP OPERATION.
C
C---- LOCAL VARIABLE DECLARATIONS
C
      REAL TABLE(960)
C
C---- COMMON STORAGE (MARK VII:  JULY 1, 1988)
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     &             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     &             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
C
      IF(KINDV.LT.6)THEN
       CALL TABSR(TABLE,ARGU,ARGV,SAVE)
      ELSEIF(KINDV.EQ.9)THEN
       CALL REVSR(TABLE,ARGU,ARGV,SAVE)
      ELSEIF(KINDV.EQ.6)THEN
       CALL RVRSY(TABLE,ARGU,ARGV,SAVE)
      ELSE
       CALL TABSR(TABLE,ARGU,ARGV,SAVE)
C
       IF(KEXT.LT.1)THEN
        IF(KINDV.EQ.7)THEN
         SAVE = SAVE + ARGU
        ELSEIF(KINDV.EQ.8)THEN
         SAVE = ARGU - SAVE
C
         IF(KINDU.EQ.2.OR.KINDU.EQ.4)THEN
          IF(SAVE.GT.ARGM)SAVE = ARGM
         ELSEIF(KINDU.GT.2)THEN
          IF(SAVE.LT.ARGM)SAVE = ARGM
         ENDIF
C
         CALL TABSR(TABLE,SAVE,ARGV,WORK)
C
         IF(KEXT.LT.1)THEN
          SAVE = ARGU - WORK
         ELSE
          GOTO 900
         ENDIF
        ENDIF
       ENDIF
      ENDIF
C
      IF(KEXT.LT.1)THEN
       IF(KINDU.EQ.2.OR.KINDU.EQ.4)THEN
        IF(SAVE.GT.ARGM)SAVE = ARGM
       ELSEIF(KINDU.GT.2)THEN
        IF(SAVE.LT.ARGM)SAVE = ARGM
       ENDIF
C
       GOTO 999
      ENDIF
C
900   ARGR1 = ARGU
      ARGR2 = ARGV
C
999   RETURN
      END
      SUBROUTINE TABSR (TABLE,X,Y,Z)
C
C     TWO DIMENSIONAL INTERPOLATION ROUTINE WITH SLIDE CAPABILITY.
C
C     INCRM = DIFFERENCE BETWEEN INDICES OF CONSECUTIVE VALUES.
C     INIT  = INDEX OF FIRST VALUE OF VARIABLE.
C     KEXT  = ERROR RETURN. ZERO IF SUCCESSFUL. ONE IF TABLE EXCEEDED.
C             TEN OR MORE IF AREA OF TABLE WAS BLANK (OLD MODEL TABLES).
C     NTRY  = NUMBER OF ENTRIES OF VARIABLE.
C     NX,NY = NUMBER OF ENTRIES ALONG EACH AXIS.
C
C---- LOCAL VARIABLE DECLARATIONS
C
      REAL TABLE(960)
C
C---- COMMON STORAGE (MARK VII:  JULY 1, 1988)
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,IDUM1(4),RDUM1(7),IDUM2(10),RDUM2(2)
C
      KEXT  = 0
C
      NTRY  = NX
      CALL SRCH(TABLE,X,1,1,X1,X2,NX1,IX)
C
      IF(IX.LT.1)THEN
       IF(NY.GT.1)THEN
        INCRM = NX + 1
        NTRY  = NY
        CALL SRCH(TABLE,Y,INCRM,INCRM,Y1,Y2,NY1,IY)
C
        IF(IY.LT.1)THEN
         M1 = NY1 * INCRM + NX1
         M2 = M1 + INCRM
        ELSE
         KEXT = 1
         GOTO 999
        ENDIF
       ELSE
        M1 = NX1 + NX
        M2 = M1 + 1
       ENDIF
      ELSE
       KEXT = 1
       GOTO 999
      ENDIF
C
      IF(IX.LT.0)THEN
       IF(IY.LT.0.OR.NY.LT.2)THEN
        Z = TABLE(M1)
        IF(TABLE(M1).EQ.0.)KEXT = 10
       ELSE
        Z = ((Y - Y1) * TABLE(M2) + (Y2 - Y) * TABLE(M1)) / (Y2 - Y1)
        IF(TABLE(M1).EQ.0..OR.TABLE(M2).EQ.0.)KEXT = 10
       ENDIF
      ELSEIF(IY.LT.0.OR.NY.LT.2)THEN
       M1P1 = M1 + 1
       Z = ((X - X1) * TABLE(M1P1) + (X2 - X) * TABLE(M1)) / (X2 - X1)
       IF(TABLE(M1).EQ.0..OR.TABLE(M1P1).EQ.0.)KEXT = 10
      ELSE
       M1P1 = M1 + 1
       M2P1 = M2 + 1
       YFAC = (Y-Y1) / (Y2-Y1)
       ZA   = TABLE(M1) + (TABLE(M2) - TABLE(M1)) * YFAC
       ZB   = TABLE(M1P1) + (TABLE(M2P1) - TABLE(M1P1)) * YFAC
       Z    = ZA + (ZB-ZA) * (X-X1) / (X2-X1)
       IF(TABLE(M1  ).EQ.0..OR.TABLE(M2  ).EQ.0..OR.
     &    TABLE(M1P1).EQ.0..OR.TABLE(M2P1).EQ.0.)KEXT = 10
      ENDIF
C
999   RETURN
      END
C***********************************************************************
      BLOCK DATA TRCINM

      LOGICAL INMTRC
      COMMON/NMTRC/INMTRC    
      DATA INMTRC /.FALSE./

      END
C***********************************************************************
      SUBROUTINE ITRIT8(LUNITR,INSNUM,NOMOR,ARG)

C     This routine writes instruction numbers and changed arguments.
C     The argument array has values just after instruction INSNUM
C     was executed.

      REAL PARG(999),ARG(999)
      LOGICAL FIRST,CHG

      SAVE FIRST,PARG
      DATA FIRST/.TRUE./

      IF (FIRST) THEN
C        First time through.  Store initial ARG array values.
         DO 100 I = 1,999
100      PARG(I) = ARG(I)
         FIRST = .FALSE.
      ENDIF

C     Check for table exceeds.  If one was encounted, say that.
      IF (NOMOR .EQ. -2) THEN
         WRITE(LUNITR,5000,ERR=401)INSNUM
401      CONTINUE
         WRITE(LUNITR,*,ERR=402)'***** Table Exceed *****'
402      CONTINUE
         RETURN
      ENDIF


C     Determine if there was a change in argument value.
      I = 0
      CHG = .FALSE.
      KARG = 1
200   CONTINUE
      I = I + 1
      IF (I.LE.999 .AND. .NOT.CHG) THEN
         IF (ARG(I) .NE. PARG(I)) THEN
C             Changed argument found.
              KARG = I
              CHG = .TRUE.
              PARG(I) = ARG(I)
              GO TO 300
           ELSE
              GO TO 200
         ENDIF
      ENDIF
300   CONTINUE

400   CONTINUE
C     Write out the instruction number and argument change, if any.
      IF (CHG) THEN
           WRITE(LUNITR,4000,ERR=4001)INSNUM,KARG,ARG(KARG)
4001       CONTINUE
        ELSEIF (INSNUM .NE. 0) THEN
           WRITE(LUNITR,5000,ERR=5001)INSNUM
5001       CONTINUE
      ENDIF

C     Draw some attention to 99999's to break things up.
      IF (INSNUM .EQ. 99999) THEN
        WRITE(LUNITR,*,ERR=5002)'-------------------'
5002    CONTINUE
      ENDIF
          
      RETURN

4000  FORMAT(1X,I5.5,3X,'A',I3.3,' = ',G14.7)
5000  FORMAT(1X,I5.5)

      END
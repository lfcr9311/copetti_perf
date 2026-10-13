      SUBROUTINE BTOPS

C-----EXPORT BTOPS() FOR DLL
C     Turn on preprocessor.
C
C     _USRDLL is a defined preprocessor macro for Win32 DLLs in C++
C     You will need to add this to your Fortran preprocessor defintions.
!ifndef _USRDLL
!define _USRDLL
!endif
!ifdef _USRDLL
	!DEC$ ATTRIBUTES DLLEXPORT,STDCALL,DECORATE,ALIAS:'BTOPS' :: BTOPS
	!DEC$ ATTRIBUTES DLLEXPORT :: TINPA
	!DEC$ ATTRIBUTES DLLEXPORT :: TINPN
	!DEC$ ATTRIBUTES DLLEXPORT :: TOUTA
	!DEC$ ATTRIBUTES DLLEXPORT :: TOUTN
	!DEC$ ATTRIBUTES DLLEXPORT :: BOGIND
	!DEC$ ATTRIBUTES DLLEXPORT :: BOGINI
	!DEC$ ATTRIBUTES DLLEXPORT :: BOGOUD
!endif
C*********************************************************
	!----------------------------
	! NON-SCAP INPUT COMMON BLOCKS
	!----------------------------
	! These common blocks are not used by BTOPS.  These common
	! blocks are needed for AFMDPI takeoff and landing.  They
	! have been added here because the call from java is the
	! same signature for AFMDPI, BTM/BLM and BTOPS/MTOPS
	real*8 FLTGEN,FLTOUT
	integer INTGEN, NDPIAP

      COMMON/BOGINI/ INTGEN(10), NDPIAP

      COMMON/BOGIND/ FLTGEN(10)

      COMMON /BOGOUD/ FLTOUT(25)

C***********************************************************
C     BOEING TAKEOFF PERFORMANCE SUBROUTINE (BTOPS)
C     VERSION NUM DEFINED IN WHATVB BELOW
C
C -------------------------------------------------------------------------
C     WRITTEN BY: THE BOEING COMPANY
C                 FLIGHT OPERATIONS ENGINEERING
C                 P.O. BOX 3707
C                 M/S 20-88
C                 SEATTLE, WA  98124-2207  USA
C
C     ***********************************************************
C     *       BOEING TAKEOFF ANALYSIS SUBROUTINE (BTOPS)        *
C     *                                                         *
C     *  BOEING PROPRIETARY, CONFIDENTIAL, AND/OR TRADE SECRET  *
C     *       COPYRIGHT (C) 1991 - 2016    THE BOEING COMPANY   *
C     *        UNPUBLISHED WORK      ALL RIGHTS RESERVED        *
C     ***********************************************************
C -------------------------------------------------------------------------
C
C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

C-------------------------------------------------------------------
C     File WhatStr.fi   10-April-2003
C     These variables hold "what" strings for the various products
C     WHATVA is for STAS
C     WHATVB is for BTOPS
C     WHATVC is for MTOPS
C     WHATVD is for BLAST
C     WHATVE is for MLAS
      CHARACTER*60 WHATVA,WHATVB,WHATVC,WHATVD,WHATVE,WHATVF
      COMMON /WHATUP/WHATVA,WHATVB,WHATVC,WHATVD,WHATVE,WHATVF
C-------------------------------------------------------------------
      COMMON /MFRORD/ORD(2,22),OMARK7(8)

      LOGICAL DRCCIP
      COMMON /DRCC/DRCCIP,DRCCGW,DRCCVB

      SAVE /BLOK1/,/BLOK2/,/BLOK3/,/BLOK4/,/BLOK5/,/INTFCA/,/INTFCN/,
     +     /TINPA/,/TINPN/,/TOUTA/,/TOUTN/,/MFRORD/,/WHATUP/

C     Setting the variable below facilitates use of the "what" command on
C     executables that use BTOPS.  The string is also used in TRNOUT
C     to define MMIDNT and MMDATE.
C                        1         2         3         4
C               12345678901234567890123456789012345678901
C                          [   ]       [         ]
      WHATVB = '@(#)BTOPS V4.23      dated 25-Oct-2016>'

C     INITIALIZE A GLOBAL FLAG THAT INDICATES THAT A DRY RUNWAY CROSS-CHECK
C     IS NOT CURRENTLY IN PROGRESS
      DRCCIP = .FALSE.

C     INITIALIZE STUFF IN COMMON BLOCKS
      CALL GETRDY

      IF (POPT(1) .EQ. 4.) THEN
C         MAX ASSUMED TEMPERATURE
          CALL BTOPSM
        ELSEIF (POPT(1) .EQ. 9.) THEN
C         JUST GET BREAK AND 25% REDUCED THRUST TEMPERATURE
          CALL BTOPS9
        ELSE
C         THE NORMAL BTOPS, ALMOST
          CALL BTOPS1
      ENDIF
      RETURN

      END
C**********************************************************
      SUBROUTINE BTOPS1

C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------


      IF (POPT(14) .EQ. 0.) THEN
C         Runway is dry.  No crosscheck is required.
          CALL BTOPS3
        ELSEIF (SPIB(90) .EQ. 1.) THEN
C         ???
C         No cross check is desired.
C         This ElseIf clause to be removed later.
          CALL BTOPS3
        ELSE
C         Appropriate logic for dealing with the dry runway
C         cross check for wet, slippery or contaminated runways
C         depends upon optimum or fixed flap settings.
C
C         BTOPS generated trace information, if generated,
C         will show the individual dry and non-dry calls.
C         This can a bit different from the composite returned
C         values that the calling program sees when dry
C         limited.
C
          IF(CONF(1) .EQ. 0.) THEN
             CALL BTOPZ3
            ELSE
             CALL BTOPZ2
          ENDIF
      ENDIF

      RETURN

      END
C****************************************************
      SUBROUTINE BTOPS2

C  THIS ROUTINE CALLS THESE SUBROUTINES AND FUNCTIONS:
C  SUBROUTINE    PURPOSE
C   /FUNCTION
C
C  RDTAB       LOCATES AND LOADS NEEDED MODEL TABLE
C  CHKMAP      CHECKS TO SEE IF SELECTED PROGRAM OPTION
C              IS SUPPORTED BY INFO SHEET ARGS
C  TRNIN       TRANSLATED IATA ARRAY INPUTS INTO OPTRAN
C              ARG INPUTS IN MODEL TABLES UNITS
C  RUNIT       CALLS OPTRAN INTERPRETER / CHART READER
C  TRNOUT      TRANSLATES OPTRAN ARG OUTPUTS INTO IATA
C              ARRAY OUTPUTS IN I/O UNITS
C  OPTFLP      SAVES OR RETRIEVES THE BEST FLAP OUTPUT DATA
C  TRACIT      WRITES IATA ARRAYS TO TRACE UNIT
C  WRTRWY      WRITES A MARK7E INPUT FILE TO TRACE UNIT
C  GETRDY      INITIALIZES VARIABLES

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

      COMMON /MFRORD/ORD(2,22),OMARK7(8)

      INTEGER RDTAB,CHKMAP,TRNIN,RUNIT,TRNOUT,FNDFLP,FLP(10)
      CHARACTER DOTHIS*8
      INTEGER ZSLPB2

      SAVE /BLOK1/,/BLOK2/,/BLOK3/,/BLOK4/,/BLOK5/,/INTFCA/,/INTFCN/,
     +     /TINPA/,/TINPN/,/TOUTA/,/TOUTN/,/MFRORD/

C     INITIALIZE STUFF IN COMMON BLOCKS
      CALL GETRDY

C  CHECK FOR INPUTS REQUIRED FOR MODEL TABLE SELECTION
      IF (ACTYPE .EQ. ' ')THEN
         ERFLAG = 'B'
         ERRMSG(NXTMSG) = 'INPUT REQUIRED TO ACTYPE - AIRCRAFT TYPE'
         NXTMSG = MIN (NXTMSG+1,20)
      ENDIF
      IF (ENGTYP .EQ. ' ')THEN
         ERFLAG = 'B'
         ERRMSG(NXTMSG) = 'INPUT REQUIRED TO ENGTYP - ENGINE TYPE'
         NXTMSG = MIN (NXTMSG+1,20)
      ENDIF
      IF (CERTIF .EQ. ' ')THEN
         ERFLAG = 'B'
         ERRMSG(NXTMSG) =
     +    'INPUT REQUIRED TO CERTIF - CERTIFICATION RULES'
         NXTMSG = MIN (NXTMSG+1,20)
      ENDIF
      IF (ACMDBI .EQ. ' ')THEN
         ERFLAG = 'B'
         ERRMSG(NXTMSG) =
     +    'INPUT REQUIRED TO ACMDBI - DATA BASE FILE NAME'
         NXTMSG = MIN (NXTMSG+1,20)
      ENDIF

C THE SUBROUTINE CALLING ALGORITHM DEPENDS ON SELECTED OR OPTIMUM FLAP
      IF(CONF(1).EQ.1.)THEN
C         **** SELECTED FLAP ****
          IF (CONF(3) .EQ. 9.E20) THEN
              ERFLAG = 'B'
              ERRMSG(NXTMSG) =
     +         'INPUT REQUIRED TO CONF(003) - FLAP POSITION'
              NXTMSG = MIN(NXTMSG+1,20)
              GOTO 200
            ELSE
              IFLAP = NINT(CONF(3))
          ENDIF
          IF (RDTAB() .NE. 0) THEN
             GOTO 200
          ENDIF
c         Call routine to potentially reinterpret inputs to account
c         for brakes deactivated on a slippery runway.
          IF (ZSLPB2(1) .NE. 0) THEN
              GOTO 200
          ENDIF
          IF (CHKMAP() .NE. 0) THEN
             GOTO 200
          ENDIF
          IF (TRNIN() .NE. 0) THEN
             GOTO 200
          ENDIF
C  WRITE RUNWAY FILE TRACE, IF REQUESTED.
          IF ( (POPT(20) .EQ. 2.) .OR. (POPT(20) .EQ. 3.) )THEN
             CALL WRTRWY(NINT(POPT(21)))
          ENDIF
          IF (RUNIT() .NE. 0) THEN
             GOTO 200
          ENDIF
          IF (TRNOUT() .NE. 0) THEN
             GOTO 200
          ENDIF
c         callroutine to restore user's original inputs in the case where
c         the inputs have been reinterpretted for brakes deactivated on
c         a slippery runway
          IF (ZSLPB2(2) .NE. 0) THEN
              GOTO 200
          ENDIF
        ELSEIF (CONF(1) .EQ. 0.)THEN
C         **** OPTIMUM FLAP ****
C         IF THERE IS A PROBLEM DO NOT CONTINUE
          IF (ERFLAG .NE. 'A') THEN
             GOTO 200
          ENDIF
C         FIND WHICH FLAPS THEY OWN FOR THIS CONFIGURATION
          IF (FNDFLP(NUMFLP,FLP).NE.0) THEN
             GOTO 200
          ENDIF
C         INITIALIZE THE SAVED DATA SET
          DOTHIS = 'SAVE    '
          CALL OPTFLP(DOTHIS,CLIMIT,RWYSEG,FIRSEG,SECSEG,ACCSEG,
     +                FINSEG,OBSLIM,TRNDAT,ERFLAG,ERRMSG,
     +                MMIDNT,MMDATE,ACMDBO,OUTMIS,OMARK7,SPOUTA)
          BESTWT = -20000.
C         RUN EACH FLAP AND SAVE IF THE MAX TO WT IS HIGHEST
          DO 100 I = 1,NUMFLP
C            REINITIALIZE
             CALL GETRDY
             IFLAP = FLP(I)
             IF (RDTAB() .NE. 0) THEN
                GOTO 300
             ENDIF
c            Call routine to potentially reinterpret inputs to account
c            for brakes deactivated on a slippery runway.
             IF (ZSLPB2(1) .NE. 0) THEN
               GOTO 300
             ENDIF
             IF (CHKMAP() .NE. 0) THEN
                GOTO 300
             ENDIF
             IF (TRNIN() .NE. 0) THEN
                GOTO 300
             ENDIF
C            WRITE RUNWAY FILE TRACE, IF REQUESTED.
             IF ( (POPT(20) .EQ. 2.) .OR. (POPT(20) .EQ. 3.) )THEN
                CALL WRTRWY(NINT(POPT(21)))
             ENDIF
             IF (RUNIT() .NE. 0) THEN
                GOTO 300
             ENDIF
             IF (TRNOUT() .NE. 0) THEN
C               IF PROBLEM TRANSLATING OUTPUT RESET MAX TOW
                CLIMIT(1) = 9.E20
             ENDIF
c           callroutine to restore user's original inputs in the case where
c           the inputs have been reinterpretted for brakes deactivated on
c           a slippery runway
             IF (ZSLPB2(2) .NE. 0) THEN
               GOTO 300
             ENDIF
C                !---------------------------------!
C                ! If runway surface is not dry:   !
C                !---------------------------------!
                 IF( POPT(14).NE.0.00 ) Then
                   CONF(1) = 1.00
                   CONF(3) = FLP(I)
C                  !--------------------------------------------------!
C                  ! Logic for call with dry runway cross check       !
C                  ! for fixed flap setting.                          !
C                  !--------------------------------------------------!
                   Call BTOPZ2
                   CONF(1) = 0.00
                   CONF(3) = 9.E20
                 End IF
!
300          CONTINUE
C            FOR THE FIRST FLAP, SAVE THE DATA NO MATTER WHAT.  IF A
C            VALID MAX BRAKE RELEASE WEIGHT WAS RETURNED, UPDATE
C            BESTWT.  FOR SUBSEQUENT FLAPS, ONLY UPDATE SAVED DATA AND
C            BESTWT IF A HIGHER MAX BRAKE RELEASE WEIGHT IS RETURNED.
             IF (I.EQ.1) THEN
C                 ** FIRST FLAP **
                  DOTHIS = 'SAVE    '
                  CALL OPTFLP(DOTHIS,CLIMIT,RWYSEG,FIRSEG,SECSEG,ACCSEG,
     +                        FINSEG,OBSLIM,TRNDAT,ERFLAG,ERRMSG,
     +                        MMIDNT,MMDATE,ACMDBO,OUTMIS,OMARK7,SPOUTA)
                  IF (CLIMIT(1).LT.7.E20)THEN
                         BESTWT = CLIMIT(1)
                  ENDIF
              ELSE
C              ** SUBSEQUENT FLAP **
               IF(CLIMIT(1) .GT. BESTWT .AND. CLIMIT(1) .LT. 7.E20)THEN
                  DOTHIS = 'SAVE    '
                  CALL OPTFLP(DOTHIS,CLIMIT,RWYSEG,FIRSEG,SECSEG,ACCSEG,
     +                        FINSEG,OBSLIM,TRNDAT,ERFLAG,ERRMSG,
     +                        MMIDNT,MMDATE,ACMDBO,OUTMIS,OMARK7,SPOUTA)
                  BESTWT = CLIMIT(1)
               ENDIF
              ENDIF
100       CONTINUE
C         RETRIEVE THE BEST WT AND FLAP DATA FROM SAVED SUBROUTINE VARIABLES
          DOTHIS = 'RETRIEVE'
                CALL OPTFLP(DOTHIS,CLIMIT,RWYSEG,FIRSEG,SECSEG,ACCSEG,
     +                      FINSEG,OBSLIM,TRNDAT,ERFLAG,ERRMSG,
     +                      MMIDNT,MMDATE,ACMDBO,OUTMIS,OMARK7,SPOUTA)
        ELSE
C         BAD INPUT TO CONF(1)
          ERFLAG = 'B'
          ERRMSG(NXTMSG) = 'INVALID INPUT TO  CONF(001) - FLAP CHOICE'
          NXTMSG = MIN(NXTMSG+1,20)
      ENDIF

C  WRITE TRACE OUTPUT, AS REQUIRED
200   CONTINUE
      IF ( (POPT(20).EQ. 1.) .OR.
     +     ((POPT(20) .GE. 3.) .AND. (POPT(20) .LE. 99999.)))THEN
            CALL TRACIT
      ENDIF

      RETURN
      END
C**********************************************************
      SUBROUTINE BTOPS3
C
C     This level uses the fixed improved climb feature
C     to support user specified range of speed increase
C     on optimum speed increase calcualtions
C
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------


      IF (POPT(27).EQ.0. .OR. POPT(27).EQ.9.E20) THEN
C           Not restricting range of speed increase, behave normally
            CALL BTOPS2
            RETURN
        ELSEIF (POPT(27) .NE. 1.) THEN
C           Invalid input to POPT(27)
            ERFLAG = 'B'
            ERRMSG(NXTMSG) = 'INVALID INPUT TO POPT(27)'
            NXTMSG = MIN (NXTMSG+1,20)
            RETURN
        ELSE
C           A reduced range of speed increase has been specified
C           Check inputs to POPT(28) and POPT(29)
            IF (POPT(28).LT.0. .OR. POPT(28).GT.150.) THEN
                 ERFLAG = 'B'
                 ERRMSG(NXTMSG) = 'INVALID INPUT TO POPT(28)'
                 NXTMSG = MIN (NXTMSG+1,20)
            ENDIF
            IF (POPT(29).LT.0. .OR. POPT(29).GT.150.) THEN
                 ERFLAG = 'B'
                 ERRMSG(NXTMSG) = 'INVALID INPUT TO POPT(29)'
                 NXTMSG = MIN (NXTMSG+1,20)
            ENDIF
            IF (POPT(28) .GT. POPT(29)) THEN
                 ERFLAG = 'B'
                 ERRMSG(NXTMSG)='THE VALUE YOU SPECIFIED FOR POPT(28)'
                 NXTMSG = MIN (NXTMSG+1,20)
                 ERRMSG(NXTMSG)=
     +            'IS GREATER THAN WHAT YOU SPECIFIED FOR POPT(29)'
                 NXTMSG = MIN (NXTMSG+1,20)
            ENDIF
            IF (ERFLAG(1:1) .EQ. 'B') RETURN
C           Done with checks, call BTOPS normally
            CALL BTOPS2
C           If there is a problem already, might as well return it
            IF (ERFLAG(1:1) .NE. 'A'  .AND.
     +          ERFLAG(1:1) .NE. 'D'  .AND.
     +          ERFLAG(1:1) .NE. 'F'      ) THEN
                RETURN
            ENDIF
C           Received a good return from BTOPS.  Check speed increase.
            IF (CLIMIT(4).LT.0. .OR. CLIMIT(4).GT.150.) THEN
                 ERFLAG = 'C'
                 ERRMSG(NXTMSG) =
     +            'RECEIVED INVALID SPEED INCREASE FROM MODEL TABLE'
                 NXTMSG = MIN (NXTMSG+1,20)
                 ERRMSG(NXTMSG) =
     +            'CANNOT CHECK RANGE OF SPEED INCREASE'
                 NXTMSG = MIN (NXTMSG+1,20)
                 RETURN
            ENDIF
            IF (CLIMIT(4).GE.POPT(28) .AND. CLIMIT(4).LE.POPT(29)) THEN
C               Speed increase is within user's range.  All is well.
                RETURN
              ELSEIF (CLIMIT(4) .LT. POPT(28)) THEN
C               Came out too low.
C               Fix at minimum and call BTOPS normally again.
                POPT07 = POPT(7)
                POPT08 = POPT(8)
                POPT(7) = 1.
                POPT(8) = POPT(28)
                CALL BTOPS2
                POPT(7) = POPT07
                POPT(8) = POPT08
                RETURN
              ELSEIF (CLIMIT(4) .GT. POPT(29)) THEN
C               Came out too high.
C               Fix at maximum and call BTOPS normally again.
                POPT07 = POPT(7)
                POPT08 = POPT(8)
                POPT(7) = 1.
                POPT(8) = POPT(29)
                CALL BTOPS2
                POPT(7) = POPT07
                POPT(8) = POPT08
                RETURN
            ENDIF
      ENDIF

      RETURN
      END
C**********************************************************
      SUBROUTINE BTOPS9

C     This uses model table in BTOPS database to find the break temp and assumed
C     temp for 25% thrust reduction.

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

      COMMON /MFRORD/ORD(2,22),OMARK7(8)

      INTEGER RDTAB,CHKMAP
      INTEGER TRNIN9,TRNOU9

      SAVE /BLOK1/,/BLOK2/,/BLOK3/,/BLOK4/,/BLOK5/,/INTFCA/,/INTFCN/,
     +     /TINPA/,/TINPN/,/TOUTA/,/TOUTN/,/MFRORD/


C INITIALIZE STUFF IN COMMON BLOCKS
      CALL GETRDY

C  CHECK FOR INPUTS REQUIRED FOR MODEL TABLE SELECTION
      IF (ACTYPE .EQ. ' ')THEN
         ERFLAG = 'B'
         ERRMSG(NXTMSG) = 'INPUT REQUIRED TO ACTYPE - AIRCRAFT TYPE'
         NXTMSG = MIN (NXTMSG+1,20)
      ENDIF
      IF (ENGTYP .EQ. ' ')THEN
         ERFLAG = 'B'
         ERRMSG(NXTMSG) = 'INPUT REQUIRED TO ENGTYP - ENGINE TYPE'
         NXTMSG = MIN (NXTMSG+1,20)
      ENDIF
      IF (CERTIF .EQ. ' ')THEN
         ERFLAG = 'B'
         ERRMSG(NXTMSG) =
     +    'INPUT REQUIRED TO CERTIF - CERTIFICATION RULES'
         NXTMSG = MIN (NXTMSG+1,20)
      ENDIF
      IF (ACMDBI .EQ. ' ')THEN
         ERFLAG = 'B'
         ERRMSG(NXTMSG) =
     +    'INPUT REQUIRED TO ACMDBI - DATA BASE FILE NAME'
         NXTMSG = MIN (NXTMSG+1,20)
      ENDIF

          IF (CONF(3) .EQ. 9.E20) THEN
              ERFLAG = 'B'
              ERRMSG(NXTMSG) =
     +         'INPUT REQUIRED TO CONF(003) - FLAP POSITION'
              NXTMSG = MIN(NXTMSG+1,20)
              GOTO 200
            ELSE
              IFLAP = NINT(CONF(3))
          ENDIF
          IF (RDTAB() .NE. 0) THEN
             GOTO 200
          ENDIF
          IF (CHKMAP() .NE. 0) THEN
             GOTO 200
          ENDIF
          IF (TRNIN9() .NE. 0) THEN
             GOTO 200
          ENDIF

          CALL SEERI

          IF (TRNOU9() .NE. 0) THEN
             GOTO 200
          ENDIF

C  WRITE TRACE OUTPUT, AS REQUIRED
200   CONTINUE
      IF ( (POPT(20).EQ. 1.) .OR.
     +     ((POPT(20) .GE. 3.) .AND. (POPT(20) .LE. 99999.)))THEN
            CALL TRACIT
      ENDIF

      RETURN
      END
C*********************************************************
      SUBROUTINE BTOPSM
C     MAXIMUM ASSUMED TEMPERATURE LOGIC

*=======================================================================
*= REVISIONS:
*= Defect Item 1103    VHN September 2016: At the check for zero or
*=                     negative value of output Maximum Takeoff Weight,
*=                     CLIMIT(1), set the executable statement to
*=                     "GO TO 200" instead of "RETURN" statement.  This
*=                     was done to allow POTP, CONF, and XMET to be
*=                     reset back to their original values in STAS
*=                     input file.
*=======================================================================

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

      COMMON /MFRORD/ORD(2,22),OMARK7(8)
      LOGICAL TFLAG
      LOGICAL doOptMAT

      REAL          LowMAT, SaveMAT, DispatchWT
      CHARACTER*10  InputWT

      SAVE TFLAG

      SAVE /BLOK1/,/BLOK2/,/BLOK3/,/BLOK4/,/BLOK5/,/INTFCA/,/INTFCN/,
     +     /TINPA/,/TINPN/,/TOUTA/,/TOUTN/,/MFRORD/

      doOptMAT    = .TRUE.
      InputWT     = ''
      LowMAT      = 0.0
      SaveMAT     = 0.0
      DispatchWT  = 0.0

C     DO MAX ASSUMED TEMPERATURE MODE
C     INITIALIZE STUFF IN COMMON BLOCKS
      CALL GETRDY
C     CHECK FOR INPUTS REQUIRED FOR MODEL TABLE SELECTION
      IF (ACTYPE .EQ. ' ')THEN
         ERFLAG = 'B'
         ERRMSG(NXTMSG) = 'INPUT REQUIRED TO ACTYPE - AIRCRAFT TYPE'
         NXTMSG = MIN (NXTMSG+1,20)
      ENDIF
      IF (ENGTYP .EQ. ' ')THEN
         ERFLAG = 'B'
         ERRMSG(NXTMSG) = 'INPUT REQUIRED TO ENGTYP - ENGINE TYPE'
         NXTMSG = MIN (NXTMSG+1,20)
      ENDIF
      IF (CERTIF .EQ. ' ')THEN
         ERFLAG = 'B'
         ERRMSG(NXTMSG) =
     +    'INPUT REQUIRED TO CERTIF - CERTIFICATION RULES'
         NXTMSG = MIN (NXTMSG+1,20)
      ENDIF
      IF (ACMDBI .EQ. ' ')THEN
         ERFLAG = 'B'
         ERRMSG(NXTMSG) =
     +    'INPUT REQUIRED TO ACMDBI - DATA BASE FILE NAME'
         NXTMSG = MIN (NXTMSG+1,20)
      ENDIF
C     CHECK FOR ACTUAL TEMPERATURE INPUT
      IF (XMET(6) .GT. 7.E20) THEN
         ERFLAG = 'B'
         ERRMSG(NXTMSG) =
     +    'INPUT REQUIRED TO XMET(6) - ACTUAL TEMPERATURE'
         NXTMSG = MIN (NXTMSG+1,20)
      ENDIF
C     Make sure the user did not specify differing temps
C     in XMET(1) and XMET(6).
      IF (XMET(1).NE.9.E20 .AND. XMET(1).NE.XMET(6)) THEN
         ERFLAG = 'B'
         ERRMSG(NXTMSG) =
     +    'INVALID INPUT TO XMET(1) - ASSUMED TEMPERATURE'
         NXTMSG = MIN (NXTMSG+1,20)
      ENDIF
C     Determine if trace was requested.
C     Check for logical unit number if trace was requested.
      TFLAG = (POPT(20).GT.0. .AND. POPT(20).LT.9999999.)
      IF (TFLAG) THEN
         IF (POPT(21).LT.1. .OR. POPT(21).GT.8.E20) THEN
             ERFLAG = 'B'
             ERRMSG(NXTMSG) =
     +       'INPUT REQUIRED TO POPT(21) - UNIT NUMBER FOR TRACE OUTPUT'
             NXTMSG = MIN (NXTMSG+1,20)
           ELSE
             LUNTRC = NINT(POPT(21))
         ENDIF
      ENDIF
C     MIGHT AS WELL QUIT HERE IF ALL IS NOT WELL
      IF (ERFLAG(1:1) .EQ. 'B')THEN
         RETURN
      ENDIF
C     SAVE CURRENT SETTINGS OF A FEW SCAP INPUT VARIABLES
C     SO WE CAN CHANGE THEM AS NEEDED
      POPT1 = POPT(1)
      POP20 = POPT(20)
      POP23 = POPT(23)
      CONF1 = CONF(1)
      XMET1 = XMET(1)
      XMET6 = XMET(6)
C     Turn off trace temporarily.
      POPT(20) = 0.
C     GET 25% REDUCED THRUST TEMP AND BREAK TEMP FROM MODEL TABLE
      POPT(1) = 9.
      CALL BTOPS9

      IF (CLIMIT(45) .LT. 9.E6) THEN
          T25  = FLOAT(INT(CLIMIT(45)))
      ELSE
          T25 = CLIMIT(45)
      ENDIF
      POPT(1) = POPT1
      TBRK    = CLIMIT(46)
C     !-------------------------------------------------------------!
C     ! Truncates the thrust break temperature to an integer number !
C     ! and increases the value by 1 degree.                        !
C     !-------------------------------------------------------------!
      IF (AINT(TBRK) .NE. TBRK) THEN
C        It wasn't a whole number already.
C        Make it the next higher whole number.
         TBRK    = AINT(TBRK) + 1.00
      ENDIF

C     CHECK TO MAKE SURE WE HAVE THE NEEDED INFORMATION TO CONTINUE
      IF (ERFLAG(1:1).EQ.'C'  .OR.
     +    ERFLAG(1:1).EQ.'B'  .OR.
     +    CLIMIT(45).GT.8.E20 .OR.
     +    CLIMIT(46).GT.8.E20      ) THEN
C         If the model tables don't support the assumed temperature
C         feature, the POPT(1) setting of 9 will not be recognized.
C         Indicating an input error due to POPT(1)=9 would be confusing
C         because that was not the user's input.
C         So, re-interpret the error message.
          IF (ERRMSG(1)(1:27).EQ.'INVALID INPUT TO  POPT(001)') THEN
             ERRMSG(1) = 'DATABASE DOES NOT SUPPORT MAXIMUM ALLOWED ASSU
     +          MED TEMPERATURE'
             ERRMSG(NXTMSG) = 'UNABLE TO BOUND TEMPERATURE ITERATION'
             NXTMSG = MIN (NXTMSG+1,20)
          ENDIF
C         TRACE AND BAIL OUT
          GOTO 200
      ENDIF
C     SET DISPATCH WEIGHT
      DWT        = POPT(24)
      DispatchWT = DWT
      POPT(23)   = 1.
      DWTT       = 0.99995

      Write (UNIT = InputWT, FMT = '(F9.1)') DispatchWT
C     Initialize final guess at the maximum allowed assumed temperature
      GFINAL = 9.E20
C     Write some trace information, if requested.
      IF (TFLAG) THEN
         WRITE(LUNTRC,2001,ERR=3001)DWT,XMET(6),TBRK,T25
         WRITE(LUNTRC,2002,ERR=3001)
3001     CONTINUE
      ENDIF
      POPT(1) = 1.0
C     TRY ACTUAL TEMP FIRST TO MAKE SURE WE CAN GO
      XMET(1) = XMET6
C     FIND LIMIT WEIGHT
      CALL BTOPS1
C     Write trace information, if requested.
      IF(TFLAG) THEN
        WRITE(LUNTRC,2003,ERR=3002)XMET(1),PLW()
3002    CONTINUE
      ENDIF
      IF (PLW().GT.DWT*DWTT .AND. PLW().LT.8.E20) THEN
C           CAN TRY TO FIND ASSUMED TEMP
            TOKAY = XMET(1)
            GLO   = XMET(1)
            GHI   = T25
C           If the actual OAT is less than the break temperature
C           check out the break temerature.
            IF (XMET(6) .LT. TBRK) THEN
C               TRY BREAK TEMP
                XMET(1) = TBRK
                CALL BTOPS1
C               Write trace information, if requested.
                IF(TFLAG) THEN
                   WRITE(LUNTRC,2003,ERR=3003)XMET(1),PLW()
3003               CONTINUE
                ENDIF
C               Check for no takeoff allowed at break temperature.
C               If takeoff is not allowed at the break, then assumed
C               temperature reduced thrust should not be used.
C               If the performance limited weight at the break is less than
C               the dispatch weight, then assumed temperature reduced thrust
C               should not be used.
                IF (PLW() .LT. 1.) THEN
                     ERFLAG = 'E'
                     ERRMSG(NXTMSG) =
     +               'No valid assumed temp found for these conditions.'
                     NXTMSG = NXTMSG +1
                       ERRMSG(NXTMSG) =
     +               'No assumed temp allowed at dispatch WT '//InputWT
                     NXTMSG = MIN (NXTMSG+1,20)
                     GOTO 200
                ELSE IF (PLW() .LT. DWT*DWTT) THEN
                     ERFLAG = 'E'
                     ERRMSG(NXTMSG) =
     +               'No valid assumed temp found for these conditions.'
                     NXTMSG = NXTMSG +1
                       ERRMSG(NXTMSG) =
     +                'No assumed temp allowed at dispatch WT '//InputWT
                      NXTMSG = MIN (NXTMSG+1,20)
                      GOTO 200
                END IF
C               Takeoff is allowed at the break, and the performance limit at
C               the break is higher than the dispatch weight, so set it to the
C               low guess.
                GLO = TBRK
            ENDIF
C           TRY MAX TEMP
            XMET(1) = T25
            CALL BTOPS1
C           Write trace information, if requested.
            IF(TFLAG) THEN
              WRITE(LUNTRC,2003,ERR=3004)XMET(1),PLW()
3004          CONTINUE
            ENDIF
!
            IF (PLW().GE.DWT*DWTT) THEN
                 GLO = XMET(1)
            ELSE
                 GHI = XMET(1)
            ENDIF
C           ITERATE
            JCNT = 0
            JMAX = 500
            EPSI = 0.1
100         CONTINUE
            GDELTA = GHI - GLO
            IF (GDELTA .LE. EPSI) THEN
               GFINAL = FLOAT(INT(GLO))
               LowMAT = GLO
               GOTO 300
            END IF
            IF (GHI .GE. GLO) THEN
                G = (GHI + GLO)/2.
            ELSE
C               SOMETHING WENT WRONG.
C               GFINAL will be returned as max allowed assumed
C               temperature in CLIMIT(44)
                GFINAL = TOKAY
                GOTO 300
            ENDIF
            XMET(1) = G
            CALL BTOPS1

            IF(TFLAG) THEN
              WRITE(LUNTRC,2003,ERR=3006)XMET(1),PLW()
3006          CONTINUE
            ENDIF

            IF (PLW().GE.DWT*DWTT) THEN
                 GLO = XMET(1)
            ELSE
                 GHI = XMET(1)
            ENDIF
            JCNT = JCNT + 1
            IF (JCNT .LT. JMAX) THEN
                GOTO 100
            ELSE
                ERFLAG = 'C'
                ERRMSG(NXTMSG) =
     +             'Max assumed temp iterations exceeded'
                NXTMSG = MIN (NXTMSG+1,20)
                GOTO 200
            ENDIF

300         CONTINUE

            CLIMIT(44) = GFINAL

            IF ( (doOptMAT) .AND. (GFINAL .LT. T25) ) Then
                SaveMAT     = CLIMIT(44)
                  POPT(1)     = 1.0
                  do 400 izz=1,100
                    XMET(1) = SaveMAT + 2.0
                    IF ( XMET(1) .GT. T25 ) Then
                      XMET(1) = T25
                    End IF
                    Call BTOPS1
                    IF( (ERFLAG(1:1) .ne. 'A') .or.
     +                  (CLIMIT(44) .le. SaveMAT) .or.
     +                  (CLIMIT(1) .lt. POPT(24))  ) Then

                      XMET(1) = SaveMAT + 1.0
                      IF ( XMET(1) .GT. T25 ) Then
                         XMET(1) = T25
                      End IF
                      Call BTOPS1
                      IF((ERFLAG(1:1).ne.'A') .or.
     +                   (CLIMIT(1).lt.POPT(24))) Then
                         goto 401
                      End IF
                      SaveMAT = SaveMAT + 1.0
                      goto 401

                    End IF
                    SaveMAT = SaveMAT + 2.0
400               continue
401               continue
                  IF ( SaveMAT .GT. T25 ) Then
                     SaveMAT = T25
                  End IF
              GFINAL = SaveMAT
              IF ( GFINAL .LT. TBRK ) Then
                    ERFLAG = 'E'
                    ERRMSG(NXTMSG) =
     +              'No valid assumed temp found for these conditions.'
                    NXTMSG = NXTMSG +1
                    ERRMSG(NXTMSG) =
     +              'No assumed temp allowed at dispatch WT '//InputWT
                      NXTMSG = MIN (NXTMSG+1,20)
                    GOTO 200
                End IF
                IF(TFLAG) THEN
                    WRITE(LUNTRC,2003,ERR=3007)XMET(1),PLW()
                    WRITE(LUNTRC,*,ERR=3007)' '
3007                CONTINUE
                ENDIF
              End IF
C           Do one more call at final guess honoring dwt to tidy up.
            XMET(1) = GFINAL

C            !this is the same as the oat
            IF (XMET(1) .eq. XMET(6)) Then
             ERFLAG = 'E'
             ERRMSG(NXTMSG) ='Max or requested assumed temp is same as O
     +          AT.'
             NXTMSG = NXTMSG +1
             ERRMSG(NXTMSG) =
     +          'No assumed temp allowed at dispatch WT '//InputWT
             NXTMSG = MIN (NXTMSG+1,20)
             GOTO 200
            End IF

            CALL BTOPS1

            IF ((CLIMIT(1).GE.DWT*DWTT).AND.(CLIMIT(1).LE.DWT/DWTT).AND.
     +          (GFINAL.GT.XMET6)) THEN
                CLIMIT(1) = DWT
            Else if ( ( GFINAL.LT.LowMAT ).AND.(GFINAL.GT.XMET6) ) Then
                GFINAL = GFINAL - 1.0
                GOTO 300
            Else
                ERFLAG = 'E'
                ERRMSG(NXTMSG) =
     +            'No valid assumed temp found for these conditions.'
                NXTMSG = NXTMSG +1
                  ERRMSG(NXTMSG) =
     +            'No assumed temp allowed at dispatch WT '//InputWT
                  NXTMSG = MIN (NXTMSG+1,20)
                GOTO 200
            END IF

C           Write trace information, if requested.
            IF(TFLAG) THEN
                 WRITE(LUNTRC,2003,ERR=3005)XMET(1),PLW()
                 WRITE(LUNTRC,*,ERR=3005)' '
3005             CONTINUE
            ENDIF
C           Maximum allowed assumed temperature is low guess
            CLIMIT(44) = GFINAL
         ELSEIF (CLIMIT(1).GE.DWT*DWTT.AND.CLIMIT(1).LE.DWT/DWTT) THEN
C           AT (OR VERY CLOSE TO) LIMIT WEIGHT
            CLIMIT(44) = XMET(1)
         ELSE IF ( (CLIMIT(1).LT.DWT*DWTT).AND.(CLIMIT(1).GT.0.0) ) THEN
            ERFLAG = 'E'
            ERRMSG(NXTMSG) =
     +        'DISPATCH WEIGHT PROVIDED IN POPT(24) IS TOO HIGH'
            NXTMSG = MIN (NXTMSG+1,20)
         ELSE IF ( CLIMIT(1).LE.0.0 ) THEN
            GO TO 200
         ELSE
            ERFLAG = 'C'
      END IF
C     RETRIEVE THE BREAK AND 25% TEMP FROM THE BTOPS9 CALL
      CLIMIT(45) = T25
      CLIMIT(46) = TBRK

200   CONTINUE
C     RESET USERS POPT(1) AND CONF(1) SETTINGS BACK THE WAY THEY WERE
      POPT(1)  = POPT1
      POPT(20) = POP20
      POPT(23) = POP23
      CONF(1)  = CONF1
      XMET(1)  = XMET1

C     WRITE TRACE OUTPUT, AS REQUIRED
      IF ( (POPT(20).EQ. 1.) .OR.
     +     ((POPT(20) .GE. 3.) .AND. (POPT(20) .LE. 99999.)))THEN
            CALL TRACIT
      END IF

      RETURN

2001  FORMAT(' Dispatch weight = ',G14.7/
     +       ' Actual outside air temperature = ',G14.7/
     +       ' Break Temperature = ',G14.7/
     +       ' Temperature for max thrust reduction = ',G14.7)
2002  FORMAT(3X,'Assumed Temp',7X,'Maximum Takeoff Weight')
2003  FORMAT(1X,G14.7,5X,G14.7)

      END
C*************************************************************************
      SUBROUTINE BTOPZ2

C     Logic for call with dry runway cross check for fixed flap setting

      PARAMETER (KTBLMX=90)
      PARAMETER (KAMPMX=100)
      PARAMETER (KERRMX=90)
      PARAMETER (KTMRMX=90)

C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2


      LOGICAL DRCCIP
      COMMON /DRCC/DRCCIP,DRCCGW,DRCCVB

C         CALL FOR SLIPPERY RUNWAY WITH DRY CROSSCHECK ON.
C
          DRCCIP = .TRUE.
C         SAVE USER'S STRUCTURAL LIMIT, RWY COND, AND THR REV SETTINGS
          P23 = POPT(23)
          P24 = POPT(24)
          P14 = POPT(14)
          P15 = POPT(15)
          P16 = POPT(16)
          P09 = POPT(9)
          P10 = POPT(10)
          CNF8 = CONF(8)
C         SET RUNWAY CONDITION TO DRY
          POPT(14) = 0.
          POPT(15) = 9.E20
          POPT(16) = 9.E20
          POPT(9)  = 9.E20
          POPT(10) = 9.E20
C         The thrust reverser configuration options for dry runways
C         are not consistent across all models and certifications.
C         Try input thrust reverser configuration first.
C         If that fails, try CONF(8) = 9.E20 (undefined)
C         If that fails, try Off / Inop / No credit
          CONF(8)  = CNF8
          CALL BTOPS3
C         If there was a bad return, try the another thrust reverser config
          IF ( CLIMIT(1).GT.7.E20 .OR.
     +         CLIMIT(1) .LT. 0.  .OR.
     +        (ERFLAG(1:1).NE.'A' .AND.
     +         ERFLAG(1:1).NE.'D' .AND.
     +         ERFLAG(1:1).NE.'F') ) THEN
                 CONF(8) = 9.E20
                 CALL BTOPS3
                 IF ( CLIMIT(1).GT.7.E20 .OR.
     +                CLIMIT(1) .LT. 0.  .OR.
     +               (ERFLAG(1:1).NE.'A' .AND.
     +                ERFLAG(1:1).NE.'D' .AND.
     +                ERFLAG(1:1).NE.'F') ) THEN
                        CONF(8) = 0.
                        CALL BTOPS3
                 ENDIF
          ENDIF
          DRCCIP = .FALSE.
          DRCCGW = 9.E20
          DRCCVB = 9.E20
C         If we got a good return, continue with comparison logic,
C         otherwise, write message and continue with wet/slippery/contaminated.
          IF ( CLIMIT(1).LT.7.E20 .AND. IGDRTN().EQ.0 ) THEN
C            GOT A GOOD RETURN, GO AHEAD WITH SLIPPERY RUNWAY CALC
C            STORE MAX TOW AND VMBE
             DRCCGW = CLIMIT(1)
             DRCCVB = CLIMIT(33)
C            STORE LIMIT CODES FROM DRY RUN FOR POSSIBLE USE LATER.
             C08 = CLIMIT(8)
             C09 = CLIMIT(9)
             C14 = CLIMIT(14)
             C15 = CLIMIT(15)
             C20 = CLIMIT(20)
             C21 = CLIMIT(21)
C            IN CASE OPTIMUM FLAP WAS USED, STORE CLIMIT(3) (BEST FLAP)
C            AND USER'S SETTINGS FOR CONF(1) AND (3)
             C03  = CLIMIT(3)
             CNF1 = CONF(1)
             CNF3 = CONF(3)
C            STORE ALL OF THE BASIC WEIGHTS FROM THE DRY RUN
             RY1 = RWYSEG(1)
             RY2 = RWYSEG(2)
             RY3 = RWYSEG(3)
             RY5 = RWYSEG(5)
             RY6 = RWYSEG(6)
             FR1 = FIRSEG(1)
             SC1 = SECSEG(1)
             FN1 = FINSEG(1)
             OS1 = OBSLIM(1)
             OS3 = OBSLIM(3)
             OS5 = OBSLIM(5)
C            USE DRY MAXIMUM TAKEOFF WEIGHT AS AN UPPER LIMIT IN SLIPPERY CALC
             POPT(24) = CLIMIT(1)
             POPT(23) = 1.
C            USE A FIXED FLAP SETTING = THE FLAP SETTING USED ON SLIPPERY RWY
             CONF(1) = 1.
             CONF(3) = C03
C            SET RUNWAY CONDITION TO WET/SLIPPERY
             POPT(14) = P14
             POPT(15) = P15
             POPT(16) = P16
             CONF(8) = CNF8
             CALL BTOPS3
             IF (IGDRTN().EQ.0) THEN
C               FOR THE BASIC WEIGHTS, USE THE LOWER OF THE SLIPPERY AND DRY
                RWYSEG(1) = AMIN1(RWYSEG(1),RY1)
                RWYSEG(2) = AMIN1(RWYSEG(2),RY2)
                RWYSEG(3) = AMIN1(RWYSEG(3),RY3)
                RWYSEG(5) = AMIN1(RWYSEG(5),RY5)
                RWYSEG(6) = AMIN1(RWYSEG(6),RY6)
                FIRSEG(1) = AMIN1(FIRSEG(1),FR1)
                SECSEG(1) = AMIN1(SECSEG(1),SC1)
                FINSEG(1) = AMIN1(FINSEG(1),FN1)
                OBSLIM(1) = AMIN1(OBSLIM(1),OS1)
                OBSLIM(3) = AMIN1(OBSLIM(3),OS3)
                OBSLIM(5) = AMIN1(OBSLIM(5),OS5)
C               IF LIMITED BY THE DRY WEIGHT, THE RETURN CODES WILL
C               INDICATE THAT WE ARE STRUCTURAL LIMITED, WHEN WE MAY
C               NOT BE.  CHECK FOR THIS CONDITION AND TWEAK RETURN
C               CODES IF NECESSARY.
                D1 = ABS(CLIMIT(1)-POPT(24))/POPT(24)
                D2 = ABS(CLIMIT(1)-P24)/P24
                IF ((D1.LT.0.001) .AND. D2 .GT. 0.001) THEN
C                 DRY LIMITED.
                  CLIMIT(52) = 2.
C                 USE LIMIT CODES FROM DRY RUN.
                  CLIMIT(8)  = C08
                  CLIMIT(9)  = C09
                  CLIMIT(14) = C14
                  CLIMIT(15) = C15
                  CLIMIT(20) = C20
                  CLIMIT(21) = C21
                 ELSE
C                 NOT DRY LIMITED
                  CLIMIT(52) = 1.
                ENDIF
             ENDIF
C            RESET USER'S FLAP SWITCHES
             CONF(1)  = CNF1
             CONF(3)  = CNF3
            ELSE
             IF ( ERFLAG .NE. 'B' ) Then
                ERFLAG = 'E'
                ERRMSG(NXTMSG) = 'IN DRY RUNWAY CROSS-CHECK:'
                NXTMSG = MIN(NXTMSG+1,20)
                ERRMSG(NXTMSG)(1:31) = 'PERFORMANCE RESTRICTIONS DO NOT'
                ERRMSG(NXTMSG)(32:59)= ' PERMIT COMPUTATION OF VALID'
                ERRMSG(NXTMSG)(60:80)= ' TAKEOFF WEIGHT '
                NXTMSG = MIN(NXTMSG+1,20)
             End IF

C            Dry runway cross check was not successful.
C            Do the wet or contaminated runway anyway and
C            indicate the condition.
C             POPT(14) = P14
C             POPT(15) = P15
C             POPT(16) = P16
C             POPT(23) = P23
C             POPT(24) = P24
C             POPT(9)  = P09
C             POPT(10) = P10
C             CONF(8) = CNF8
C             CALL BTOPS3
C             CLIMIT(52) = 0.
          ENDIF
C         RESET USER'S RUNWAY CONDITION SWITCH, STR LIM AND THRUST REV CONFIG
          POPT(14) = P14
          POPT(15) = P15
          POPT(16) = P16
          POPT(23) = P23
          POPT(24) = P24
          POPT(9)  = P09
          POPT(10) = P10
          CONF(8) = CNF8

C         Write trace of composite results.
          IF ( (POPT(20).EQ. 1.) .OR.
     +         ((POPT(20) .GE. 3.) .AND. (POPT(20) .LE. 99999.)))THEN
                IF (POPT(21).GE.1. .AND. POPT(21).LE.1000.)THEN
                WRITE(INT(POPT(21)),*,ERR=6543)
     +            '**** After Dry Runway Cross-Check: ****'
6543            CONTINUE
                CALL TRACIT
                ENDIF
          ENDIF

      RETURN
      END
C*************************************************************************
      SUBROUTINE BTOPZ3

C     Logic for call with dry runway cross check for optimum flap.

C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

      LOGICAL DRCCIP
      COMMON /DRCC/DRCCIP,DRCCGW,DRCCVB


C     First, do a normal call without any cross check to pick the best flap.
C     Then, do a dry runway cross checked call with the best flap fixed,
C           if a dry runway cross check is needed for these inputs.

C     The normal call without dry runway cross-check.
      DRCCIP = .FALSE.
      CALL BTOPS3

C     Decide if a dry runway cross-checked call is needed.
C     If one is NOT needed, we're done and can return.
      IF (POPT(14) .EQ. 0.) THEN
C         Runway is dry.
          RETURN
C       Could add an elseif here to test for ways to
C       optionally disable the dry check, if desired.
      ENDIF

C     Do a dry runway cross-checked call with the best flap fixed
      IF (IGDRTN().EQ.0) THEN
          CNF1 = CONF(1)
          CNF3 = CONF(3)
          CONF(1) = 1.
          CONF(3) = CLIMIT(3)
          CALL BTOPZ2
          CONF(1) = CNF1
          CONF(3) = CNF3
      ENDIF

      RETURN
      END
C******************************************************
      BLOCKDATA OVRRID

      COMMON /MFRORD/ORD(2,22),OMARK7(8)
      DATA ORD /44 * 0./

      END
C**********************************************************
      INTEGER FUNCTION CHKMAP()

C  CHECKS TO SEE IF INPUT CONFIGURATION IS COVERED BY INFORMATION
C  SHEET ARGUMENT MAPPING AND SETS OPTRAN ARGUMENTS IF IT IS.
C  EACH INFORMATION SHEET ARGUMENT MAPPING RECORD WILL HAVE A
C  SINGLE CHARACTER TO DESIGNATE WHICH SCAP INPUT ARRAY APPLIES.
C  THE LETTERS ARE:
C     P - POPT
C     C - CONF
C     X - XMET
C     R - RWYD
C     O - OBSD
C     F - FPTD
C     U - UNIT
C     S - SPIA
C     K - SPIB
C     V - SPIC

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

C     File:  Param4.fi   6 Nov 1996
C     THESE PARAMETERS DEFINE THE SIZE OF EACH OF THE SCAP ARRAYS
      PARAMETER (LLPOPT=200, LLCONF=200, LLXMET=200, LLRWYD=200,
     +           LLOBSD=200, LLFPTD=200, LLUNIT=200, LLSPIA=200,
     +           LLSPIB=200, LLSPIC=200)

      PARAMETER (LLCLIM=200, LLRWYS=200, LLFIRS=200, LLSECS=200,
     +           LLACCS=200, LLFINS=200, LLOBSL=200, LLTRND=200,
     +           LLSPOU=200)

      PARAMETER (LXPOPT=56, LXCONF=71, LXXMET=35, LXRWYD=40,
     +           LXOBSD=92, LXFPTD=41, LXUNIT=39, LXSPIA=100,
     +           LXSPIB=100, LXSPIC=100)

      PARAMETER (LXCLIM=60, LXRWYS=40, LXFIRS=14, LXSECS=20,
     +           LXACCS=20, LXFINS=21, LXOBSL=16, LXTRND=18,
     +           LXSPOU=100)

      CHARACTER LTR*1
      INTEGER MAPARG,CMAP2,CKTMR1

C  INITIALLY, ASSUME THAT THERE WILL BE A CORRESPONDING SETTING
C  FOR EACH USER SELECTION.  THIS WILL BE CHANGED TO 1 IF
C  A SELECTION IS INVALLID.
      CHKMAP = 0

C   DO PERMANENT INPUT ARG SETS, I.E.  C  TYPE MAPPING RECORDS
      DO 50 I = 1,NMMP(CNTLST)
         IF (MAPTYP(I) .EQ. 'C') ARG(ARGNUM(I)) = ARGVAL(I)
50    CONTINUE

C  CHECK DBOPTI INPUT AND TEXT MAPPING RECORDS
      IF (CKTMR1('DBOPTI') .NE. 0) THEN
         CHKMAP = 1
      ENDIF

      IF (FRAME(CNTLST) .EQ. '------') THEN
         IF (CKTMR1('ACTYPE') .NE. 0) THEN
            CHKMAP = 1
         ENDIF
      ENDIF

      IF (ENGINE(CNTLST) .EQ. '------') THEN
         IF (CKTMR1('ENGTYP') .NE. 0) THEN
            CHKMAP = 1
         ENDIF
      ENDIF

      IF (RULES(CNTLST) .EQ. '---') THEN
         IF (CKTMR1('CERTIF') .NE. 0) THEN
            CHKMAP = 1
         ENDIF
      ENDIF

      IF (BRTXT(CNTLST) .EQ. '------') THEN
         IF (CKTMR1('BRAKES') .NE. 0) THEN
            CHKMAP = 1
         ENDIF
      ENDIF

      IF (RLTXT(CNTLST) .EQ. '------') THEN
         IF (CKTMR1('RATING') .NE. 0) THEN
            CHKMAP = 1
         ENDIF
      ENDIF

C  CHECK FOR AND DO MAPPING ON INFO SHEET ARGS
      LTR = 'P'
      DO 100 I = 1,LXPOPT
      IF (CMAP2(POPT(I),I,YPOP(I),LTR) .NE. 0) THEN
         CHKMAP = 1
      ENDIF
100   CONTINUE

      LTR = 'C'
      DO 110 I = 1,LXCONF
      IF (CMAP2(CONF(I),I,YCON(I),LTR) .NE. 0) THEN
         CHKMAP = 1
      ENDIF
110   CONTINUE

      LTR = 'X'
      DO 120 I = 1,LXXMET
      IF (CMAP2(XMET(I),I,YXME(I),LTR) .NE. 0) THEN
         CHKMAP = 1
      ENDIF
120   CONTINUE

      LTR = 'R'
      DO 130 I = 1,7
      IF (CMAP2(RWYD(I),I,YRWY(I),LTR) .NE. 0) THEN
         CHKMAP = 1
      ENDIF
130   CONTINUE
C     Special treatment for RWYD(8) because standard error
C     trap options (-3,-4,-5) do not fit.
C     It will be set to zero if the RWYD(8) input matters.
C     Map if set to zero, otherwise ignore.
      I=8
!      IF (YRWY(8) .EQ. 0) THEN
      IF (CMAP2(RWYD(I),I,YRWY(I),LTR) .NE. 0) THEN
         CHKMAP = 1
      ENDIF
!      ENDIF
      DO 132 I = 9,LXRWYD
      IF (CMAP2(RWYD(I),I,YRWY(I),LTR) .NE. 0) THEN
         CHKMAP = 1
      ENDIF
132   CONTINUE

      LTR = 'O'
      DO 140 I = 1,LXOBSD
      IF (CMAP2(OBSD(I),I,YOBS(I),LTR) .NE. 0) THEN
         CHKMAP = 1
      ENDIF
140   CONTINUE

      LTR = 'F'
      DO 150 I = 1,LXFPTD
      IF (CMAP2(FPTD(I),I,YFPT(I),LTR) .NE. 0) THEN
         CHKMAP = 1
      ENDIF
150   CONTINUE

      LTR = 'U'
      DO 160 I = 1,LXUNIT
      IF (CMAP2(UNIT(I),I,YUNI(I),LTR) .NE. 0) THEN
         CHKMAP = 1
      ENDIF
160   CONTINUE

      LTR = 'S'
      DO 170 I = 1,LXSPIA
      IF (CMAP2(SPIA(I),I,YSPA(I),LTR) .NE. 0) THEN
         CHKMAP = 1
      ENDIF
170   CONTINUE

      LTR = 'K'
      DO 180 I = 1,LXSPIB
      IF (CMAP2(SPIB(I),I,YSPB(I),LTR) .NE. 0) THEN
         CHKMAP = 1
      ENDIF
180   CONTINUE

      LTR = 'V'
      DO 190 I = 1,LXSPIC
      IF (CMAP2(SPIC(I),I,YSPC(I),LTR) .NE. 0) THEN
         CHKMAP = 1
      ENDIF
190   CONTINUE

C  SPECIAL HANDLING IS REQUIRED FOR ANTI-SKID / BRAKES SINCE THESE
C  ARE A COMBINED INPUT ON MOST MODEL TABLES.
C  IF A/S ISN'T OPERATIVE, THE A/S CONFIGURATION IS USED, IF A/S IS
C  OPERATIVE, THE BRAKE CONFIGURATION IS USED.  IF A/S OUT AND BRAKE
C  DEACTIVATED AT SAME TIME, RETURN ERROR MESSAGE.
      IF (CONF(7) .EQ. 1. .OR. CONF(7) .EQ. 2.)THEN
         IF (YCON(7) .EQ. 0) THEN
            IF (MAPARG('C',7,CONF(7)) .NE. 0) THEN
               CHKMAP = 1
            ENDIF
         ENDIF
        ELSE
         IF (YCON(20) .EQ. 0) THEN
            IF (MAPARG('C',20,CONF(20)) .NE. 0) THEN
               CHKMAP = 1
            ENDIF
         ENDIF
      ENDIF
C     !---------------------------------------------------!
C     !     IF ANTI-SKID IS OUT, CHECK FOR BRAKES.        !
C     !---------------------------------------------------!
      IF ( (ABS(CONF(7)-1.).LT.1.E-5) .OR.
     +     (ABS(CONF(7)-2.).LT.1.E-5) ) THEN
           IF ( (CONF(20).GT.0.9) .AND. (CONF(20).LT.8.E20))THEN
                 ERFLAG = 'B'
                 ERRMSG(NXTMSG)=
     +           'INVALID INPUT TO  CONF(007) - ANTISKID'
                 NXTMSG = MIN(NXTMSG+1,20)
                 ERRMSG(NXTMSG)=
     +           'CANNOT HAVE ANTI-SKID AND BRAKES OUT AT THE SAME TIME'
                 NXTMSG = MIN(NXTMSG+1,20)
                 CHKMAP = 1
           END IF
      END IF
C     Model tables with JAR-OPS 1 or PEM based slippery and contaminated
C     runway adjustments do not allow full V1 optimization (maximization).
C     This section captures the situation where the user has selected
C     V1 optimization with slippery or contaminated runway adjustments.
C     In that situation, the user's selection will be remapped as a
C     V1 selection that allows increasing V1 to Vmcg, which is the
C     highest level of V1 optimization that is supported.
      IF (
     +     (CERTIF(1:3).EQ.'FAA' .OR. CERTIF(1:3).EQ.'OPS') .AND.
     +     (POPT(14).GE.2. .AND. POPT(14).LE.11.)           .AND.
     +     (POPT(5) .EQ. 0.)                                .AND.
     +     (YPOP(5) .EQ. 0)
     +    ) THEN
C           User has selected optimum V1 but it won't work for them.
C           Reselect the closest option that will work for them.
            IGNOR = CMAP2(5.,5,0,'P')
      ENDIF

      RETURN
      END
C*********************************************************************
      INTEGER FUNCTION CKTMR1(TV)

C     INPUT TO SCAP VARIABLE DBOPTI MAY CONTAIN MULTIPLE
C     SELECTIONS SEPARATED BY COMMAS.  EACH SELECTION IS USED TO
C     SET INFORMATION SHEET ARGUMENTS ACCORDING TO THE
C     TEXT MAPPING RECORDS (TMR) STORED IN THE INTFC COMMON BLOCKS.
C     THIS ROUTINE SETS THE INFORMATION SHEET ARGUMENTS ACCORDING TO
C     THE DBOPTI INPUT.  THIS FUNCTION RETURNS 0 IF IT WAS SUCCESSFUL
C     AND 1 IF A PROBLEM IS ENCOUNTERED.

C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------


      CHARACTER BLANK*16,REQST*16,TV*6,MS*20
      INTEGER CKTMR2

      BLANK = '                '
      MS = '                    '

C     ASSUME THE FUNCTION WILL BE SUCCESSFUL UNLESS THESE IS A PROBLEM
      CKTMR1 = 0

C     Define which variable we're trying to map via text mapping records.
      IF (TV .EQ. 'DBOPTI') THEN
           MS = DBOPTI
        ELSEIF (TV .EQ. 'ACTYPE') THEN
           MS = ACTYPE
        ELSEIF (TV .EQ. 'ENGTYP') THEN
           MS = ENGTYP
        ELSEIF (TV .EQ. 'BRAKES') THEN
           MS = BRAKES
        ELSEIF (TV .EQ. 'CERTIF') THEN
           MS = CERTIF
        ELSEIF (TV .EQ. 'RATING') THEN
           MS = RATING
        ELSE
           MS = '!@#$%^'
      ENDIF

      IF (MS.EQ.BLANK .AND. TV.EQ.'DBOPTI') THEN
C           NOTHING TO CHK.  THATS OKAY FOR DBOPTI SO GO AHEAD AND RETURN.
            CONTINUE
        ELSEIF (MS.EQ.BLANK .AND. TV.NE.'DBOPTI') THEN
C           NOTHING TO CHK AND HEADER INDICATED THAT THERE SHOULD BE.
C           Indicate and error.
            CKTMR1 = 1
            ERFLAG = 'B'
            ERRMSG(NXTMSG) = 'Input to        was blank.'
            ERRMSG(NXTMSG)(10:15) = TV(1:6)
            NXTMSG = MIN(NXTMSG+1,20)
        ELSEIF (NMTMR(CNTLST) .LE. 0) THEN
C           SOMETHING HAS BEEN INPUT BUT THERE ARE NO MAPPING RECORDS
C           TO USE TO SATISFY THE REQUEST.
            CKTMR1 = 1
            ERFLAG = 'B'
            IF (TV .EQ. 'DBOPTI') THEN
            ERRMSG(NXTMSG) =
     +       'INVALID INPUT TO  DBOPTI - MUST BE LEFT BLANK'
            NXTMSG = MIN(NXTMSG+1,20)
            ELSE
            ERRMSG(NXTMSG) =
     +       'INVALID INPUT TO A TEXT VARIABLE.'
            NXTMSG = MIN(NXTMSG+1,20)
            ERRMSG(NXTMSG) =
     +       'CHECK ACTYPE, ENGTYP, RATING, CERTIF AND BRAKES.'
            NXTMSG = MIN(NXTMSG+1,20)
            ENDIF
        ELSE
C           FOR EACH SEPARATE ENTRY (SEPARATED BY COMMAS)
C           TRY TO MEET THE REQUEST USING CKTMR2
            REQST = ' '
            IPOS = 0
            DO 100 I = 1,16
               IF (MS(I:I) .NE. ',') THEN
                     IF (MS(I:I) .NE. ' ') THEN
                        IPOS = IPOS + 1
                        REQST(IPOS:IPOS) = MS(I:I)
                     ENDIF
                  ELSE
                     IF (CKTMR2(REQST,TV) .NE. 0) THEN
                        CKTMR1 = 1
                     ENDIF
                     REQST = ' '
                     IPOS = 0
               ENDIF
100         CONTINUE
C           TRY THE LAST (OR ONLY) REQUEST
            IF (CKTMR2(REQST,TV) .NE. 0) THEN
                CKTMR1 = 1
            ENDIF
      ENDIF

      RETURN
      END
C************************************************************************
      INTEGER FUNCTION CKTMR2(REQST,TV)

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------


      CHARACTER REQST*16,TV*6

C     INITIALIZE TO SAY THERE IS A PROBLEM UNTIL A MATCH IS FOUND
      CKTMR2 = 1

      DO 100 J = 1,NMTMR(CNTLST)
         IF (TMRTXT(J) .EQ. REQST) THEN
            CKTMR2 = 0
            K = TMRARG(J)
            X = TMRSET(J)
            ARG(TMRARG(J)) = TMRSET(J)
         ENDIF
100   CONTINUE

      IF (CKTMR2 .NE. 0) THEN
         ERFLAG = 'B'
         ERRMSG(NXTMSG)(1:27) =
     +       'INVALID INPUT TO  DBOPTI - '
         ERRMSG(NXTMSG)(28:43) = REQST
         ERRMSG(NXTMSG)(19:24) = TV
         NXTMSG = MIN(NXTMSG+1,20)
      ENDIF
      RETURN
      END
C************************************************************************
      INTEGER FUNCTION CMAP2(SENTRY,IENTRY,RENTRY,LTR)

C     CHECKS MAPPING FOR AN INDIVIDUAL SCAP ARRAY ENTRY.
C     THIS INCLUDES VARIABLES WHICH DO NOT REQUIRE A UNIT CONVERSION.
C     IT ALSO INCLUDES TRAPS FOR VAIABLES WHICH CAN ONLY HAVE
C     INPUT VALUES SUCH AS 0, 1 OR 9.E20.

C     INPUT PARAMETERS:
C         SENTRY - THE SCAP ARRAY INPUT ITSELF (E.G. POPT(1)).
C         IENTRY - THE POSITION IN THE ARRAY (E.G. 1 FOR POPT(1))
C         RENTRY - THE REFERENCE ARRAY SETTING WHICH DESCRIBES
C                  HOW TO MAP THE PARAMETER.  (E.G. YPOP(1))
C                  0  - MAP IT USING FUNCTION MAPARG
C                  -3 = ONLY 9.E20 IS AN ACCEPTABLE INPUT
C                  -4 = ZERO AND 9.E20 ARE ACCEPTABLE INPUTS
C                  -5 = ONE AND 9.E20 ARE ACCEPTABLE INPUTS
C         LTR    - THE FIRST LETTER OF THE ARRAY NAME. (P FOR POPT).
C
C     OUTPUT IS THE RETURN VALUS OF THE FUNCTION.  0=SUCCESS  1=FAILURE

      REAL       SENTRY
      INTEGER    IENTRY,RENTRY
      CHARACTER  LTR*1


C     ASSUME SUCCESS UNTIL A PROBLEM
      CMAP2 = 0

      IF (RENTRY .EQ. 0) THEN
           IF( MAPARG(LTR,IENTRY,SENTRY) .NE. 0)THEN
             CMAP2 = 1
           ENDIF
         ELSEIF ((RENTRY.EQ.-3) .AND. (SENTRY.NE.9.E20)) THEN
           CALL MSGNOT(LTR,IENTRY,'     ')
           CMAP2 = 1
         ELSEIF ( (RENTRY .EQ. -4) .AND.
     +            (SENTRY .NE. 9.E20) .AND. (SENTRY .NE. 0.) )THEN
           CALL MSGNOT(LTR,IENTRY,'OR 0.')
           CMAP2 = 1
         ELSEIF ( (RENTRY .EQ. -5) .AND.
     +            (SENTRY .NE. 9.E20) .AND. (SENTRY .NE. 1.) )THEN
           CALL MSGNOT(LTR,IENTRY,'OR 1.')
           CMAP2 = 1
      ENDIF

      RETURN
      END
C**********************************************************
      SUBROUTINE DUMP


C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C
      DO 200 J = 1,IDUM(51)
       IF(IDUM(J).EQ.INSDUM)THEN
        IA1 = MAX0(  1,(((IDUMP1(J) + 4) / 5) * 5) -  4)
        IA2 = MIN0(999, ((IDUMP2(J) + 4) / 5) * 5)
        IDO = ((IA2 - IA1 + 1) / 5)
        IA3 = IA1 + 4
        WRITE(NT(6),5)IA1,IA2,IDUM(J)
C
        DO 100 I=1,IDO
         WRITE(NT(6),10)IA1,IA3,(ARG(K),K=IA1,IA3)
         IA1 = IA1 + 5
         IA3 = MIN0(IA3+5,999)
100     CONTINUE
C
        WRITE(NT(6),15)
       ENDIF
200   CONTINUE
C
5     FORMAT('0','DUMP OF ARGUMENTS ',I3,' THROUGH ',I3,' AFTER ',
     $       'INSTRUCTION ',I5,'.')
10    FORMAT(' ',8X,'A',I3,'-','A',I3,3X,5(F12.4))
15    FORMAT(' ')
C
      RETURN
      END
C********************************************************************
      INTEGER FUNCTION FNDCNT()

C  FIND INDEX NUM IN DATABASE FOR DESIRED MODEL TABLE
C  RETURNS -1 IF NONE FOUND

C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------


      Integer   iPOPT25, iDerate, ios
      Integer   iP25(2)
      LOGICAL   MATCH

      I       = 0
      iPOPT25 = 0
      iDerate = 0
      ios     = 0

      iP25(1) = 0
      iP25(2) = 0

      IF ( POPT(25) .GT. 99.0 ) THEN
        iPOPT25 = -1
      ELSE
        iPOPT25 = NINT(POPT(25))
      END IF

100   CONTINUE
      I = I + 1
      MATCH = .TRUE.

      MATCH = MATCH .AND. ( (ACTYPE(1:12).EQ.FRAME(I))
     +                 .OR. (FRAME(I)(1:6).EQ.'------') )
      MATCH = MATCH .AND. ( (ENGTYP(1:11) .EQ. ENGINE(I))
     +                 .OR. (ENGINE(I)(1:6).EQ.'------') )
      MATCH = MATCH .AND. ( (CERTIF(1:3) .EQ. RULES(I))
     +                 .OR. (RULES(I)(1:3).EQ.'---') )
      MATCH = MATCH .AND. ( (BRAKES(1:12) .EQ. BRTXT(I))
     +                 .OR. (BRTXT(I)(1:6).EQ.'------') )
!--------------------------------------------------------------------!
!                                                                    !
!     Check to determine whether POPT(25) is used for thrust rating: !
!     If RLTXT(1:4) = 'P25:', then use POPT(25) input for rating.    !
!                                                                    !
!--------------------------------------------------------------------!
      IF ( (RLTXT(I)(1:4).EQ.'P25:') .AND. (RATING.EQ.'') ) THEN
        iDerate = INDEX(RLTXT(I),',')
        IF ( iDerate .EQ. 0 ) THEN
          READ(UNIT=RLTXT(I)(5:5),FMT='(I1)',IOSTAT=ios) iP25(1)
          iP25(2) = iP25(1)
        ELSE
          READ(UNIT=RLTXT(I)(5:7),FMT='(I1,1X,I1)',IOSTAT=ios)
     +         iP25(1), iP25(2)
        END IF
        IF ( ios .EQ. 0 ) THEN
          MATCH = MATCH .AND. ( (iP25(1) .EQ. iPOPT25)
     +                   .OR.   (iP25(2) .EQ. iPOPT25) )
        ELSE
          MATCH = .FALSE.
        END IF
      ELSE

        MATCH = MATCH .AND. ( (RATING(1:8) .EQ. RLTXT(I))
     +                 .OR.   (RLTXT(I)(1:6).EQ.'------') )
      END IF

      MATCH = MATCH .AND. ((IFLAP .EQ. FLAPS(I)).OR.(FLAPS(I).EQ.99))
      MATCH = MATCH .AND. ((APACK .EQ. BLEED(I)).OR.
     +        (BLEED(I).EQ.'ALL').OR.(BLEED(I).EQ.'ON OR OFF') .OR.
     +        (BLEED(I).EQ.'AUTO/OFF'))
      MATCH = MATCH .AND. (
     +         (ARWY .EQ. RWYCON(I)) .OR.
     +         (RWYCON(I).EQ.'ALL' ) .OR.
     +         (ARWY.EQ.'DRY' .AND. RWYCON(I).EQ.'DRY OR WET') .OR.
     +         (ARWY.EQ.'WET' .AND. RWYCON(I).EQ.'DRY OR WET') )

C   IF TRACE OPTION IS 4, WRITE MODEL TABLES SELECTION TESTING
      IF (POPT(20) .EQ. 4.) THEN
            ITRC = NINT(POPT(21))
            WRITE (ITRC,1000)
            WRITE (ITRC,1070)ACTYPE(1:12),FRAME(I)
            WRITE (ITRC,1010)ENGTYP(1:11),ENGINE(I)
            WRITE (ITRC,1020)CERTIF(1:3),RULES(I)
            WRITE (ITRC,1070)BRAKES(1:12),BRTXT(I)
            WRITE (ITRC,1040)RATING(1:8),RLTXT(I)
            WRITE (ITRC,1080)IFLAP,FLAPS(I)
            WRITE (ITRC,1050)APACK,BLEED(I)
            WRITE (ITRC,1060)ARWY,RWYCON(I)
            IF (MATCH) THEN
                WRITE(ITRC,1090)'** Match found! **'
              ELSE
                WRITE(ITRC,1090)'** Not a match. **'
            ENDIF
      ENDIF

      IF (MATCH) THEN
         FNDCNT = I
      ELSEIF (I .LT. NUMOWN)THEN
         GOTO 100
      ELSE
         ERFLAG = 'B'
         ERRMSG(NXTMSG) =
     +    'Specified Airframe/Engine/Cert/Flap/Bleed/Runway Condition'
         NXTMSG = MIN(NXTMSG+1,20)
         ERRMSG(NXTMSG) = 'was not found.  Check inputs to:'
         NXTMSG = MIN(NXTMSG+1,20)
         ERRMSG(NXTMSG)= ' ACTYPE, ENGTYP, CERTIF, BRAKES, '
         ERRMSG(NXTMSG)(34:70)='RATING, CONF(3), CONF(4) and POPT(14)'
         NXTMSG = MIN(NXTMSG+1,20)
         IF (POPT(20).NE.4.) THEN
          ERRMSG(NXTMSG) = 'Set POPT(20)=4 to get additional '
          ERRMSG(NXTMSG)(34:80) = 'diagnostic information.'
          NXTMSG = MIN(NXTMSG+1,20)
         ENDIF
         FNDCNT = -1
      ENDIF

      RETURN

1000  FORMAT(' --------------------------'/' INPUT//DATABASE//')
1010  FORMAT(1X,2(A11,'//'))
1020  FORMAT(1X,2(A3,'//'))
1040  FORMAT(1X,2(A8,'//'))
1050  FORMAT(1X,2(A9,'//'))
1060  FORMAT(1X,2(A15,'//'))
1070  FORMAT(1X,2(A12,'//'))
1080  FORMAT(1X,2(I4,'//'))
1090  FORMAT(1X,A)

      END
C*****************************************************************
      INTEGER FUNCTION FNDFLP(NUMFLP,FLP)

C  FINDS FLAP NUMBERS FOR APPLICABLE MODEL TABLES IN THE DATABASE

*=======================================================================
*= REVISIONS:
*= Backlog Item 2626   VHN September 2016:
*=                     1. Increased the size of local variable LASTDB to
*=                        match with that of ACMBDI (255).
*=                     2. Implemented the same algorithm in checking for
*=                        the previous and current database as those of
*=                        function RDTAB().
*=                     3. Added processing for non-valid or non-existing
*=                        database.
*=
*= Defect Item 1095    VHN September 2016: Separated the processing of
*=                     runway condition, POPT(14), when the database is
*=                     either CAA or CAA-UK or JAA.
*=
*= Defect Item 1416    VHN October 2016: Removed the call to function
*=                     LNBCHR. Function LNBCHR only resides in code file
*=                     STAS.F. Therefore, if BTOPS.FOR is compiled
*=                     independently, the compilation will fail.
*=======================================================================

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

C     COMMON BLOCK FOR DATABASE SHARED BETWEEN THIS FUNCTION
C     AND FUNCTION RDTAB. THIS IS DONE TO ALLOW THE USER TO
C     SWITCH MULTIPLE DATABASES AND FLAP CHOICES (CONF(1))
C     WITHIN A SESSION.
      COMMON/DBNAME/LASTDB

      INTEGER   FLP(10)
      
      INTEGER MAX_LEN
      PARAMETER (MAX_LEN=LEN(ACMDBI))
      CHARACTER LASTDB*(MAX_LEN)
      CHARACTER TEMP_ACMDBI*(MAX_LEN)
      
      INTEGER LAST_DELIMITER_POS

      INTEGER   RDTOP
      LOGICAL   MATCH

      Integer   iPOPT25, iDerate, ios
      Integer   iP25(2)

      SAVE LASTLU
      DATA LASTDB / 'NONE' /
      DATA LASTLU / -1 /

      iPOPT25 = 0
      iDerate = 0
      ios     = 0

      iP25(1) = 0
      iP25(2) = 0

      IF ( POPT(25) .GT. 99.0 ) THEN
        iPOPT25 = -1
      ELSE
        iPOPT25 = NINT(POPT(25))
      END IF

C  DEFINE INTERNAL PACK VALUE FROM SPEC INPUTS
      IF (CONF(4) .EQ. 2.)THEN
          APACK = 'OFF'
        ELSEIF (CONF(4) .EQ. 0.)THEN
          APACK = 'AUTO'
        ELSEIF ((CONF(4) .EQ. 1.) .OR. (CONF(4) .EQ. 3.)) THEN
          APACK = 'ON'
        ELSE
          APACK = 'ERROR'
      ENDIF
C  DEFINE INTERNAL RWY CONDITION VALUE FROM SPEC INPUTS
      IF ((POPT(14) .EQ. 9.E20) .AND. (CERTIF(1:3) .EQ. 'FAA')) THEN
          ARWY = 'DRY'
        ELSEIF (POPT(14) .EQ. 0.)THEN
          ARWY = 'DRY'
        ELSEIF (POPT(14) .EQ. 1.)THEN
          ARWY = 'WET'
        ELSEIF (POPT(14) .EQ. 11.)THEN
          ARWY = 'WET'
          IF ((CERTIF(1:3) .EQ. 'CAA') .OR. (CERTIF(1:6) .EQ. 'CAA-UK')
     +    .OR. (CERTIF(1:3) .EQ. 'JAR')) THEN
             ARWY = 'ERROR'
             ERFLAG = 'B'
             ERRMSG(NXTMSG) =
     +       'SLIPPERY RUNWAY NOT SUPPORTED FOR CAA/CAA-UK/JAR CERTIF'
             NXTMSG = MIN (NXTMSG+1,20)
             FNDFLP = 1
             RETURN
          ENDIF
        ELSEIF ( (POPT(14) .EQ. 2.) .OR.
     +           (POPT(14) .EQ. 3.) .OR.
     +           (POPT(14) .EQ. 4.) .OR.
     +           (POPT(14) .EQ. 5.) .OR.
     +           (POPT(14) .EQ. 6.) .OR.
     +           (POPT(14) .EQ. 7.) .OR.
     +           (POPT(14) .EQ. 8.) .OR.
     +           (POPT(14) .EQ. 9.) ) THEN
          ARWY = 'CONTAMINATED'
        ELSE
          ARWY = 'ERROR'
      ENDIF

C  SET INTEGER VALUE OF DATA BASE LOGICAL UNIT NUMBER
      IF (POPT(22) .EQ. 9.E20) THEN
           ERFLAG = 'B'
           ERRMSG(NXTMSG) =
     +     'INPUT REQUIRED TO POPT(022) - DATABASE LOGICAL UNIT NUMBER'
           NXTMSG = MIN(NXTMSG+1,20)
           FNDFLP = 1
           RETURN
      ELSE
           LUNDB = NINT(POPT(22))
      ENDIF

C  IF SELECTED DATABASE HAS CHANGED, CLOSE OLD FILE
      IF (ACMDBI .NE. LASTDB .AND. LASTDB .NE. 'NONE')CLOSE(LASTLU)
C  IF NEW DATABASE OR FIRST DATABASE, THEN OPEN FILE
      IF (ACMDBI .NE. LASTDB) THEN
         OPEN(UNIT = LUNDB, FILE = ACMDBI, STATUS = 'OLD',
     +        ACCESS = 'SEQUENTIAL',FORM = 'UNFORMATTED',
     +        IOSTAT = IOS)
C     +        IOSTAT=IOS,READONLY)
C              One replacement line above.
C              If you keep your BTOPS databases in a protected file area
C              or share them with others on a server, you may want to
C              open the files in read only mode.  There is no ANSI standard
C              F77 way to do this, but the replacement line above is a commonly
C              used implementation.  It is supported by the Compaq Visual
C              Fortran compiler.  Look for the OPEN command's syntax
C              in your Fortran compiler's documentation to find out how to do
C              this in your environment.
C              There are two occurences in BTOPS, this is one.
         IF (IOS .NE. 0) THEN
C           ERRMSG is 80-character long while ACMDBI is 255-character long.
C           Therefore, the directory path of ACMDBI must be removed in order
C           to fit into ERRMSG.  This is done by iteratively truncating
C           the path directory '\' delimiter until the only remaining of the
C           string is the database name.
            TEMP_ACMDBI = ACMDBI
            DO WHILE (INDEX(TEMP_ACMDBI,'\') .NE. 0)
               LAST_DELIMITER_POS = INDEX(TEMP_ACMDBI,'\')
               TEMP_ACMDBI =
     +            TEMP_ACMDBI((LAST_DELIMITER_POS + 1):MAX_LEN)
            ENDDO
            
            ERFLAG = 'B'
            ERRMSG(NXTMSG) = 'ERROR OPENING DATABASE '
            NXTMSG = MIN (NXTMSG+1,20)
            ERRMSG(NXTMSG)(1:12) = 'File name = '
            ERRMSG(NXTMSG)(13:LEN(ERRMSG)) = TEMP_ACMDBI
            NXTMSG = MIN(NXTMSG+1,20)
            FNDFLP = IOS
            RETURN
         ENDIF
         IF (RDTOP() .NE. 0)THEN
            FNDFLP = 1
            RETURN
         ENDIF
         LASTDB = ACMDBI
         LASTLU = NINT(POPT(22))
         CNTLST = 0
      ENDIF

C  VALIDATE MIN / MAX FLAP SETTING INPUTS
      IF (CONF(28) .GT. CONF(29)) THEN
            ERFLAG = 'B'
            ERRMSG(NXTMSG) =
     +  'INVALID INPUT TO  CONF(028) - MIN FLAP GREATER THAN MAX FLAP'
            NXTMSG = MIN(NXTMSG+1,20)
            FNDFLP = 1
            RETURN
      ENDIF
C  CHECK FOR INPUT OF MIN AND MAX FLAP SETTINGS TO CONSIDER.
      IF (CONF(28) .NE. 9.E20) THEN
           MINFLP = NINT(CONF(28))
         ELSE
           MINFLP = -1000
      ENDIF
      IF (CONF(29) .NE. 9.E20) THEN
           MAXFLP = NINT(CONF(29))
         ELSE
           MAXFLP = 1000
      ENDIF

C  EXAMINE EACH MODEL TABLE IN THE DATABASE TO SEE IF IT MATCHES THE
C  REQUESTED CONFIGURATION.  IF IS DOES, INCREMENT THE NUMFLP COUNTER
C  AND ADD IT TO THE FLP ARRAY.
      NUMFLP   = 0
      DO 100 I = 1,NUMOWN

        MATCH = .TRUE.
        MATCH = MATCH .AND. ( (ACTYPE(1:12).EQ.FRAME(I))
     +                     .OR. (FRAME(I)(1:6).EQ.'------') )
        MATCH = MATCH .AND. ( (ENGTYP(1:11) .EQ. ENGINE(I))
     +                 .OR. (ENGINE(I)(1:6).EQ.'------') )
        MATCH = MATCH .AND. ( (CERTIF(1:3) .EQ. RULES(I))
     +                 .OR. (RULES(I)(1:3).EQ.'---') )
        MATCH = MATCH .AND. ( (BRAKES(1:12) .EQ. BRTXT(I))
     +                 .OR. (BRTXT(I)(1:6).EQ.'------') )
!--------------------------------------------------------------------!
!                                                                    !
!     Check to determine whether POPT(25) is used for thrust rating: !
!     If RLTXT(1:4) = 'P25:', then use POPT(25) input for rating.    !
!                                                                    !
!--------------------------------------------------------------------!
        IF ( (RLTXT(I)(1:4).EQ.'P25:') .AND. (RATING.EQ.'') ) THEN
            iDerate = INDEX(RLTXT(I),',')
            IF ( iDerate .EQ. 0 ) THEN
                READ(UNIT=RLTXT(I)(5:5),FMT='(I1)',IOSTAT=ios) iP25(1)
                iP25(2) = iP25(1)
            ELSE
                READ(UNIT=RLTXT(I)(5:7),FMT='(I1,1X,I1)',IOSTAT=ios)
     +               iP25(1), iP25(2)
            END IF
            IF ( ios .EQ. 0 ) THEN
                MATCH = MATCH .AND. ( (iP25(1) .EQ. iPOPT25)
     +                        .OR.    (iP25(2) .EQ. iPOPT25) )
            ELSE
                MATCH = .FALSE.
            END IF
        ELSE
            MATCH = MATCH .AND. ( (RATING(1:8) .EQ. RLTXT(I))
     +                    .OR.    (RLTXT(I)(1:6).EQ.'------') )
        END IF

        MATCH = MATCH .AND. ((APACK .EQ. BLEED(I)).OR.
     +        (BLEED(I).EQ.'ALL').OR.(BLEED(I).EQ.'ON OR OFF') .OR.
     +        (BLEED(I).EQ.'AUTO/OFF'))
        MATCH = MATCH .AND. (
     +         (ARWY .EQ. RWYCON(I)) .OR.
     +         (RWYCON(I).EQ.'ALL' ) .OR.
     +         (ARWY.EQ.'DRY' .AND. RWYCON(I).EQ.'DRY OR WET') .OR.
     +         (ARWY.EQ.'WET' .AND. RWYCON(I).EQ.'DRY OR WET') )

C   IF TRACE OPTION IS 4, WRITE MODEL TABLES SELECTION TESTING
        IF (POPT(20) .EQ. 4.) THEN
            ITRC = NINT(POPT(21))
            WRITE (ITRC,1000)
            WRITE (ITRC,1070)ACTYPE(1:12),FRAME(I)
            WRITE (ITRC,1010)ENGTYP(1:11),ENGINE(I)
            WRITE (ITRC,1020)CERTIF(1:3),RULES(I)
            WRITE (ITRC,1070)BRAKES(1:12),BRTXT(I)
            WRITE (ITRC,1040)RATING(1:8),RLTXT(I)
            WRITE (ITRC,1080)IFLAP,FLAPS(I)
            WRITE (ITRC,1050)APACK,BLEED(I)
            WRITE (ITRC,1060)ARWY,RWYCON(I)
            IF (MATCH) THEN
                WRITE(ITRC,1040)'TRUE    '
              ELSE
                WRITE(ITRC,1040)'FALSE   '
            ENDIF
        ENDIF

C        IF MATCH IS STILL TRUE AND THE FLAP SETTING IS WITHIN
C        THE DESIRED RANGE, THEN THIS MODEL TABLE SHOULD BE
C        CONSIDERED IN THE OPTIMUM FLAP ANALYSIS
        IF (MATCH
     +       .AND. FLAPS(I) .GE. MINFLP
     +       .AND. FLAPS(I) .LE. MAXFLP) THEN
            NUMFLP = NUMFLP + 1
            FLP(NUMFLP) = FLAPS(I)
        END IF

100   CONTINUE

C  CHECK FOR UNSUPPORTED CONFIGURATIONS
      IF (NUMFLP .EQ. 0) THEN
         ERFLAG = 'B'
         ERRMSG(NXTMSG) =
     +    'NO DATA FOUND FOR SPECIFIED CONFIGURATION.'
         NXTMSG = MIN(NXTMSG+1,20)
         ERRMSG(NXTMSG) = 'CHECK INPUTS TO:'
         NXTMSG = MIN(NXTMSG+1,20)
         ERRMSG(NXTMSG)(1:33)= ' ACTYPE, ENGTYP, CERTIF, BRAKES, '
         ERRMSG(NXTMSG)(34:61)='RATING, CONF(4) AND POPT(14)'
         NXTMSG = MIN(NXTMSG+1,20)
         FNDFLP = 1
         RETURN
      ENDIF

      FNDFLP = 0
      RETURN

1000  FORMAT(' --------------------------'/' INPUT//INTERNAL//')
1010  FORMAT(1X,2(A11,'//'))
1020  FORMAT(1X,2(A3,'//'))
1040  FORMAT(1X,2(A8,'//'))
1050  FORMAT(1X,2(A9,'//'))
1060  FORMAT(1X,2(A15,'//'))
1070  FORMAT(1X,2(A12,'//'))
1080  FORMAT(1X,2(I4,'//'))

      END
C*****************************************************************
      SUBROUTINE GETRDY

C  INITIALIZE VARIABLES

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2

C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

C     File:  Param4.fi   6 Nov 1996
C     THESE PARAMETERS DEFINE THE SIZE OF EACH OF THE SCAP ARRAYS
      PARAMETER (LLPOPT=200, LLCONF=200, LLXMET=200, LLRWYD=200,
     +           LLOBSD=200, LLFPTD=200, LLUNIT=200, LLSPIA=200,
     +           LLSPIB=200, LLSPIC=200)

      PARAMETER (LLCLIM=200, LLRWYS=200, LLFIRS=200, LLSECS=200,
     +           LLACCS=200, LLFINS=200, LLOBSL=200, LLTRND=200,
     +           LLSPOU=200)

      COMMON /MFRORD/ORD(2,22),OMARK7(8)

      NT(5) = 5
      NT(6) = 6
      NXTMSG = 1
      DO 100 I = 1,LLCLIM
         CLIMIT(I) = 9.E20
100   CONTINUE
      DO 110 I = 1,LLRWYS
         RWYSEG(I) = 9.E20
110   CONTINUE
      DO 120 I = 1,LLFIRS
         FIRSEG(I) = 9.E20
120   CONTINUE
      DO 130 I = 1,LLSECS
         SECSEG(I) = 9.E20
130   CONTINUE
      DO 140 I = 1,LLACCS
         ACCSEG(I) = 9.E20
140   CONTINUE
      DO 150 I = 1,LLFINS
         FINSEG(I) = 9.E20
150   CONTINUE
      DO 160 I = 1,LLOBSL
         OBSLIM(I) = 9.E20
160   CONTINUE
      DO 170 I = 1,LLTRND
         TRNDAT(I) = 9.E20
170   CONTINUE
      DO 175 I = 1,LLSPOU
         SPOUTA(I) = 9.E20
175   CONTINUE
      ERFLAG = 'A'
      DO 180 I = 1,20
         ERRMSG(I) = ' '
180   CONTINUE
      DO 190 I = 1,20
         OUTMIS(I) = ' '
190   CONTINUE
      MMIDNT = ' '
      MMDATE = ' '
      ACMDBO = ' '

C  INITIALIZE ALL OPTRAN ARGUMENTS TO 0
      DO 200 I = 1,999
         ARG(I) = 0.
200   CONTINUE

C  SET TAKEOFF PROGRAM FLAG  0.=MARK7  1.=BTOPS
      ARG(195) = 1.

C  INITIALIZE MFRORD OUTPUTS
      DO 210 I = 1,8
         OMARK7(I) = 9.E20
210   CONTINUE

      RETURN
      END
C****************************************************************************
      INTEGER FUNCTION IGDRTN()
C     This function looks at the ERFLAG SCAP output and determines
C     if there was a good return or not.  If we got a good return
C     IGDRTN will be set to zero.  For a bad return, it will be set to one.
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

C
      IF (ERFLAG(1:1) .EQ. 'A') THEN
           IGDRTN = 0
         ELSEIF (ERFLAG(1:1) .EQ. 'D') THEN
           IGDRTN = 0
         ELSEIF (ERFLAG(1:1) .EQ. 'F') THEN
           IGDRTN = 0
         ELSE
           IGDRTN = 1
      ENDIF
      RETURN
      END
C*************************************************************************
      SUBROUTINE LINUPV
C
C     Defines lineup distances based on angle of taxiway entry to runway
C     and ACTYPE inputs.

C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

C===== LINUPDIST.fi    07-June-2004 =======================================
C     NUMAP is the number of airplanes we have defined distances for.
      INTEGER NUMAP
      PARAMETER (NUMAP = 39)

      REAL G90(NUMAP),S90(NUMAP),G180(NUMAP),S180(NUMAP)
      CHARACTER*20 AP(NUMAP)

      SAVE G90,S90,G180,S180,AP

C     Most data from Airport Technology document dated 23 October 1997.
C
C     Updated 777-200 and 777-300 data from Airport Technology document
C     of 28 August 2003.

      DATA AP /
     +          '707-1               ',
     +          '707-3               ',
     +          '717-2               ',
     +          '720                 ',
     +          '727-1               ',
     +          '727-2               ',
     +          '737-1               ',
     +          '737-2               ',
     +          '737-3               ',
     +          '737-4               ',
     +          '737-5               ',
     +          '737-6               ',
     +          '737-7               ',
     +          '737-8               ',
     +          '737-9               ',
     +          '747-2               ',
     +          '747-4               ',
     +          '747SP               ',
     +          '757-2               ',
     +          '757-3               ',
     +          '767-2               ',
     +          '767-3               ',
     +          '767-4               ',
     +          '777-2               ',
     +          '777-3               ',
     +          'DC-10-10            ',
     +          'DC-10-30            ',
     +          'DC-10-40            ',
     +          'DC-8-43             ',
     +          'DC-8-62             ',
     +          'DC-8-63             ',
     +          'DC-9-15             ',
     +          'DC-9-32             ',
     +          'DC-9-51             ',
     +          'MD-11               ',
     +          'MD-87               ',
     +          'MD-90-30            ',
     +          'MD-90-82            ',
     +          'VC-25A              '
     +        /

C     TODA lineup distances for 90 degrees in feet
      DATA G90   /
     +           64.8,
     +           66.5,
     +           31.0,
     +           63.4,
     +           35.8,
     +           43.5,
     +           29.6,
     +           30.4,
     +           31.4,
     +           33.0,
     +           30.2,
     +           31.5,
     +           32.6,
     +           35.3,
     +           36.5,
     +           78.4,
     +           78.4,
     +           69.9,
     +           63.6,
     +           71.3,
     +           68.7,
     +           74.3,
     +           80.4,
     +           74.5,
     +           83.1,
     +           74.1,
     +           72.5,
     +           72.5,
     +           49.5,
     +           34.4,
     +           66.9,
     +           33.3,
     +           30.1,
     +           36.5,
     +           80.8,
     +           29.0,
     +           40.2,
     +           39.3,
     +           78.4
     +           /

C     ASDA lineup distances for 90 degrees in feet
      DATA S90   /
     +           117.1,
     +           125.5,
     +           88.7,
     +           114.1,
     +           89.1,
     +           106.8,
     +           63.9,
     +           67.7,
     +           72.2,
     +           79.8,
     +           66.5,
     +           68.6,
     +           73.9,
     +           86.7,
     +           92.4,
     +           162.4,
     +           162.4,
     +           137.2,
     +           123.6,
     +           144.6,
     +           133.3,
     +           149.0,
     +           166.1,
     +           159.4,
     +           185.5,
     +           146.5,
     +           144.9,
     +           144.9,
     +           107.0,
     +           95.2,
     +           144.4,
     +           77.0,
     +           83.3,
     +           97.4,
     +           161.6,
     +           91.9,
     +           117.4,
     +           111.8,
     +           162.4
     +           /

C     TODA lineup distances for 180 degrees in feet
      DATA G180   /
     +           80.3,
     +           86.8,
     +           69.7,
     +           78.2,
     +           66.7,
     +           82.0,
     +           46.5,
     +           49.6,
     +           53.2,
     +           59.4,
     +           48.5,
     +           49.4,
     +           53.7,
     +           64.2,
     +           68.8,
     +           111.9,
     +           111.9,
     +           92.7,
     +           85.8,
     +           101.2,
     +           90.5,
     +           102.1,
     +           114.6,
     +           167.6,
     +           221.8,
     +           98.6,
     +           98.0,
     +           97.9,
     +           77.8,
     +           77.4,
     +           103.2,
     +           55.4,
     +           65.0,
     +           77.9,
     +           109.3,
     +           74.4,
     +           94.5,
     +           89.7,
     +           111.9
     +           /

C     ASDA lineup distances for 180 degrees in feet
      DATA S180   /
     +           132.6,
     +           145.8,
     +           127.4,
     +           128.9,
     +           120.0,
     +           145.3,
     +           80.8,
     +           86.9,
     +           94.0,
     +           106.2,
     +           84.8,
     +           86.5,
     +           95.0,
     +           115.6,
     +           124.7,
     +           195.9,
     +           195.9,
     +           160.0,
     +           145.8,
     +           174.5,
     +           155.1,
     +           176.8,
     +           200.3,
     +           252.5,
     +           324.2,
     +           171.0,
     +           170.4,
     +           170.3,
     +           135.3,
     +           138.2,
     +           180.7,
     +           99.1,
     +           118.2,
     +           138.8,
     +           190.1,
     +           137.3,
     +           171.7,
     +           162.2,
     +           195.9
     +           /
C
C     This bit of code can be used to dump out the lineup distances
C     to check them. The following 9 lines should normally be commented out.
C      open(unit=55,file='LineupDistances.csv',status='UNKNOWN')
C      close(55,STATUS='DELETE')
C      open(unit=55,file='LineupDistances.csv',status='new')
C      write(55,*)'AP',',','G90',',','S90',',','G180',',','S180'
C      do 777 i=1,numap
C777   write(55,1777)ap(i),',',G90(i),',',S90(i),',',G180(i),',',S180(i)
C1777  format(A,A,G14.7,A,G14.7,A,G14.7,A,G14.7)
C      close(55)
C      stop 'have written LineupDistances.csv'
C
C==========================================================================

C     Initialize returned values to zero
      ADJ1 = 0.
      ADJ2 = 0.

C     Check for cases where lineup distances should be zero
      IF (RWYD(12) .EQ. 0.) THEN
C       We're already done.
        RETURN
      ENDIF

C     User specified default angle of taxiway entry of 90 or 180.
C     Hunt down the right numbers and use them.

      NNLUP = 180
      XRATE = ABS(RWYD(12))
      IF (XRATE .LE. 90.) THEN
           NNLUP = 90
         ELSE
           NNLUP = 180
      ENDIF

      N = 0
100   CONTINUE
      N = N + 1
      IF (N .LE. NUMAP) THEN
C        Have another entry to check.
C        Find out how many non blank characters there are to compare.
         L = LNBCHZ(AP(N))
         IF (L .GT. 0) THEN
C          Have something to compare.  Compare it.
           IF (ACTYPE(1:L) .EQ. AP(N)(1:L)) THEN
C              We have a match.
               IF (NNLUP .EQ. 90) THEN
                    ADJ1 = G90(N)
                    ADJ2 = S90(N)
                  ELSE
                    ADJ1 = G180(N)
                    ADJ2 = S180(N)
               ENDIF
C              Convert units, if needed
               IF (UNIT(3) .EQ. 0.) THEN
                    ADJ1 = ADJ1 / 3.2808399
                    ADJ2 = ADJ2 / 3.2808399
               ENDIF
C              Success!
               RETURN
            ELSE
C              Not a match.  Try again.
               GO TO 100
           ENDIF
          ELSE
C          Nothing to compare.  Keep trying.
           GO TO 100
         ENDIF
      ENDIF

C     Did not find a match.
      ERFLAG = 'C'
      ERRMSG(NXTMSG)(1:37) = 'Could not define lineup distance for '
      ERRMSG(NXTMSG)(38:57) = ACTYPE
      NXTMSG = MIN(NXTMSG+1,20)
      RETURN

      END
C*************************************************************************
      INTEGER FUNCTION LNBCHZ(LINE)

C     Find the last non-blank character on the input line

      CHARACTER NULL*1
      CHARACTER*(*) LINE

      NULL = CHAR(0)

      LNBCHZ = 0
      DO 100 I = 1,LEN(LINE)
         IF (LINE(I:I).NE.' ' .AND. LINE(1:1).NE.NULL) THEN
             LNBCHZ = I
         ENDIF
100   CONTINUE

      RETURN
      END
C**********************************************************
      INTEGER FUNCTION MAPARG(PORCIN,PNUM,PVAL)

C  CHECK A SINGLE INPUT CONFIG FOR COVERAGE IN INFO SHEET ARGS.
C  SETS ARG PRPERLY IF IT IS COVERED.

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------


      CHARACTER PORCIN*1
      INTEGER PNUM
      REAL PVAL

      NEXTRY = 0
      MAPARG = 1

100   CONTINUE
      NEXTRY = NEXTRY + 1
      IF ((PORCIN .EQ. PORC(NEXTRY)) .AND.
     +    (PNUM .EQ. POPNUM(NEXTRY))) THEN
          IF(MAPTYP(NEXTRY) .EQ. 'B')THEN
              ARG(ARGNUM(NEXTRY)) = PVAL
              MAPARG = 0
          ELSEIF((MAPTYP(NEXTRY) .EQ. 'A').OR.
     +             (MAPTYP(NEXTRY) .EQ. 'D'))THEN
              IF (PVAL .EQ. POPVAL(NEXTRY))THEN
                 MAPARG = 0
                 IF (MAPTYP(NEXTRY) .EQ. 'A')
     +              ARG(ARGNUM(NEXTRY)) = ARGVAL(NEXTRY)
              ELSE
                  IF (NEXTRY .EQ. NMMP(CNTLST)) THEN
                     ERFLAG = 'B'
                     ERRMSG(NXTMSG)(1:16) = 'INVALID INPUT TO'
                     CALL VARTXT(PORCIN,ERRMSG(NXTMSG)(19:22))
                     WRITE(ERRMSG(NXTMSG)(23:26),1000)PNUM
1000                 FORMAT('(',I3.3)
                     ERRMSG(NXTMSG)(27:30) = ') = '
                     WRITE(ERRMSG(NXTMSG)(31:44),1010)PVAL
1010                 FORMAT(1P,G14.6)
                     NXTMSG = MIN(NXTMSG+1,20)
                     MAPARG = -1
                   ELSE
                     GOTO 100
                  ENDIF
              ENDIF
          ENDIF
      ELSE
          IF (NEXTRY .EQ. NMMP(CNTLST)) THEN
                     ERFLAG = 'B'
                     ERRMSG(NXTMSG)(1:16) = 'INVALID INPUT TO'
                     CALL VARTXT(PORCIN,ERRMSG(NXTMSG)(19:22))
                     WRITE(ERRMSG(NXTMSG)(23:26),1000)PNUM
                     ERRMSG(NXTMSG)(27:30) = ') = '
                     WRITE(ERRMSG(NXTMSG)(31:44),1010)PVAL
                     NXTMSG = MIN(NXTMSG+1,20)
                     MAPARG = -1
           ELSE
             GOTO 100
          ENDIF
      ENDIF

      RETURN
      END
C****************************************************************
      SUBROUTINE MSGNOT(LTR,I,ALT)
C
      CHARACTER LTR*1,ALT*5

C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------


      ERFLAG = 'B'
      ERRMSG(NXTMSG)(1:16) = 'INVALID INPUT TO'
      CALL VARTXT(LTR,ERRMSG(NXTMSG)(19:22))
      WRITE(ERRMSG(NXTMSG)(23:26),1000)I
      ERRMSG(NXTMSG)(27:50) = ') - MUST BE SET TO 9.E20'
      ERRMSG(NXTMSG)(56:60) = ALT
      NXTMSG = MIN(NXTMSG+1,20)
      RETURN
1000  FORMAT('(',I3.3)
      END
C****************************************************************
      SUBROUTINE OBSCKI
C  SAME AS OBSCKE EXCEPT WRITES TO ERRMSG ARRAY VICE UNIT 6
C
C---- CHECK THAT NO OBSSTACLE IS IN THE SPECIFIED CLEARWAY OR STOPWAY

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------


C
      IF(XX(1,1).GT.0..AND.AMAX1(ARG(26),ARG(27)).GT.0.)THEN
       DO 100  I=1,NOBS(1)
        IF(REF(1).EQ.'BR')THEN
         COMP = XX(2*I,1) - ARG(20)*COS(ATAN(ARG(21)/100.))
        ELSE
         COMP = XX(2*I,1)
        ENDIF
C
        IF(COMP.LT.AMIN1(ARG(26),ARG(27)))THEN
           ERRMSG(NXTMSG)='OBSTACLE SPECIFIED IN CLEARWAY OR STOPWAY'
           NXTMSG = MIN(NXTMSG+1,20)
           GOTO 999
        ENDIF
100    CONTINUE
      ENDIF
C
999   RETURN
      END
C***********************************************************************
      SUBROUTINE OBSSTE(II)

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

      COMMON/BLOKX/AVOID(2,30)
C
      ARG(31) = XX(II+II  ,1)
      ARG(32) = XX(II+II-1,1)
C
      IF(REF(1).EQ.'BR'.AND.XX(II+II,1).GT.0.)THEN
       ARG(31) = AMAX1(0.,ARG(31)-ARG(20)*COS(ATAN(ARG(21)/100.)))
       ARG(32) = AMAX1(0.,ARG(32)-RWYD(3)*CF(3)*ARG(21)/100.)
      ELSE
       ARG(31) = AMAX1(0.,ARG(31))
       ARG(32) = AMAX1(0.,ARG(32))
      ENDIF
C
      ARG(198) = II
C
      IF(II.EQ.NOBS(1))THEN
       ARG(199) = 1
      ELSE
       ARG(199) = 0
      ENDIF
      AVOID(1,II) = ARG(31)
      AVOID(2,II) = ARG(32)
C
      RETURN
      END
C*****************************************************************
      SUBROUTINE OPTFLP(DOTHIS,Z1,Z2,Z3,Z4,Z5,Z6,Z7,Z8,Z9,Z10,
     +                  Z11,Z12,Z13,Z14,Z15,Z16)

C  OPTFLP      SAVES OR RETRIEVES THE BEST FLAP OUTPUT DATA
C
C  VARIABLES BEING TRANSFERED ON THE PARAMETER LIST START WITH Z.
C  SAVED VARIABLES START WITH S.
C  THE INDEX NUMBER FOLLOWING THE LETTER WILL BE THE SAME IN BOTH.
C  THEY ARE:
C     1 - CLIMIT
C     2 - RWYSEG
C     3 - FIRSEG
C     4 - SECSEG
C     5 - ACCSEG
C     6 - FINSEG
C     7 - OBSLIM
C     8 - TRNDAT
C     9 - ERFLAG
C     10 - ERRMSG
C     11 - MMIDNT
C     12 - MMDATE
C     13 - ACMDBO
C     14 - OUTMIS
C     15 - OMARK7
C     16 - SPOUTA

C     File:  Param4.fi   6 Nov 1996
C     THESE PARAMETERS DEFINE THE SIZE OF EACH OF THE SCAP ARRAYS
      PARAMETER (LLPOPT=200, LLCONF=200, LLXMET=200, LLRWYD=200,
     +           LLOBSD=200, LLFPTD=200, LLUNIT=200, LLSPIA=200,
     +           LLSPIB=200, LLSPIC=200)

      PARAMETER (LLCLIM=200, LLRWYS=200, LLFIRS=200, LLSECS=200,
     +           LLACCS=200, LLFINS=200, LLOBSL=200, LLTRND=200,
     +           LLSPOU=200)
      
      PARAMETER (LXCLIM=60, LXRWYS=40, LXFIRS=14, LXSECS=20,
     +           LXACCS=20, LXFINS=21, LXOBSL=16, LXTRND=18,
     +           LXSPOU=100)

C  INCOMING/OUTGOING SET OF VARIABLES
C      CHARACTER Z9*4,Z10*80,Z11*18,Z12*18,Z13*60,Z14*80,DOTHIS*8
      CHARACTER Z9*20,Z10*80,Z11*20,Z12*20,Z13*60,Z14*80,DOTHIS*8
      DIMENSION Z10(10),Z14(3)
      REAL Z1(LXCLIM),Z2(LXRWYS),Z3(LXFIRS),Z4(LXSECS),
     +     Z5(LXACCS),Z6(LXFINS),Z7(LXOBSL),Z8(LXTRND),
     +     Z15(8),Z16(LXSPOU)

C  SAVED SET OF VARIABLES
C      CHARACTER S9*4,S10*80,S11*18,S12*18,S13*60,S14*80
      CHARACTER S9*20,S10*80,S11*20,S12*20,S13*60,S14*80
      DIMENSION S10(10),S14(3)
      REAL S1(LXCLIM),S2(LXRWYS),S3(LXFIRS),S4(LXSECS),
     +     S5(LXACCS),S6(LXFINS),S7(LXOBSL),S8(LXTRND),
     +     S15(8),S16(LXSPOU)

      SAVE S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,S11,S12,S13,S14,S15,S16
      PARAMETER (LXSUM=LXCLIM+LXRWYS+LXFIRS+LXSECS+LXACCS+LXFINS+
     +                 LXOBSL+LXTRND+8+LXSPOU)
      DATA S1,S2,S3,S4,S5,S6,S7,S8,S15,S16 /LXSUM*9.E20/

      IF (DOTHIS .EQ. 'SAVE    ') THEN
C        MOVE ARGUMENTS OF SUBROUTINE TO SAVED VARIABLES
         DO 100 I = 1,LXCLIM
            S1(I) = Z1(I)
100      CONTINUE
         DO 110 I = 1,LXRWYS
            S2(I) = Z2(I)
110      CONTINUE
         DO 120 I = 1,LXFIRS
            S3(I) = Z3(I)
120      CONTINUE
         DO 130 I = 1,LXSECS
            S4(I) = Z4(I)
130      CONTINUE
         DO 140 I = 1,LXACCS
            S5(I) = Z5(I)
140      CONTINUE
         DO 150 I = 1,LXFINS
            S6(I) = Z6(I)
150      CONTINUE
         DO 160 I = 1,LXOBSL
            S7(I) = Z7(I)
160      CONTINUE
         DO 170 I = 1,LXTRND
            S8(I) = Z8(I)
170      CONTINUE
         S9 = Z9
         DO 180 I = 1,10
            S10(I) = Z10(I)
180      CONTINUE
         S11 = Z11
         S12 = Z12
         S13 = Z13
         DO 190 I =1,3
            S14(I) = Z14(I)
190      CONTINUE
         DO 195 I =1,8
            S15(I) = Z15(I)
195      CONTINUE
         DO 198 I =1,LXSPOU
            S16(I) = Z16(I)
198      CONTINUE
       ELSEIF (DOTHIS .EQ. 'RETRIEVE') THEN
C        MOVE SAVED VARIABLES TO ARGUMENTS OF SUBROUTINE
         DO 200 I = 1,LXCLIM
            Z1(I) = S1(I)
200      CONTINUE
         DO 210 I = 1,LXRWYS
            Z2(I) = S2(I)
210      CONTINUE
         DO 220 I = 1,LXFIRS
            Z3(I) = S3(I)
220      CONTINUE
         DO 230 I = 1,LXSECS
            Z4(I) = S4(I)
230      CONTINUE
         DO 240 I = 1,LXACCS
            Z5(I) = S5(I)
240      CONTINUE
         DO 250 I = 1,LXFINS
            Z6(I) = S6(I)
250      CONTINUE
         DO 260 I = 1,LXOBSL
            Z7(I) = S7(I)
260      CONTINUE
         DO 270 I = 1,LXTRND
            Z8(I) = S8(I)
270      CONTINUE
         Z9 = S9
         DO 280 I = 1,10
            Z10(I) = S10(I)
280      CONTINUE
         Z11 = S11
         Z12 = S12
         Z13 = S13
         DO 290 I = 1,3
            Z14(I) = S14(I)
290      CONTINUE
         DO 295 I = 1,8
            Z15(I) = S15(I)
295      CONTINUE
         DO 298 I = 1,LXSPOU
            Z16(I) = S16(I)
298      CONTINUE
      ENDIF

      RETURN
      END
C********************************************************************
      REAL FUNCTION PLW()
C     Returns the maximum takeoff weight (or zero if takeoff is not allowed)

C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------


C     Check for bad return
      IF (ERFLAG(1:1) .EQ. 'B' .OR.
     +    ERFLAG(1:1) .EQ. 'C' .OR.
     +    ERFLAG(1:1) .EQ. 'E' ) THEN
            PLW = 0.
            RETURN
      ENDIF
      IF (CLIMIT(1) .GT. 8.E20) THEN
            PLW = 0.
            RETURN
      ENDIF

      PLW = CLIMIT(1)

      RETURN

      END
C***************************************
      INTEGER FUNCTION RDECH(KEEPER)

C  READ ONE SET OF INTERFACE INFO AND ONE MODEL TABLE

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

C     File:  Param4.fi   6 Nov 1996
C     THESE PARAMETERS DEFINE THE SIZE OF EACH OF THE SCAP ARRAYS
      PARAMETER (LLPOPT=200, LLCONF=200, LLXMET=200, LLRWYD=200,
     +           LLOBSD=200, LLFPTD=200, LLUNIT=200, LLSPIA=200,
     +           LLSPIB=200, LLSPIC=200)

      PARAMETER (LLCLIM=200, LLRWYS=200, LLFIRS=200, LLSECS=200,
     +           LLACCS=200, LLFINS=200, LLOBSL=200, LLTRND=200,
     +           LLSPOU=200)

      PARAMETER (LXPOPT=56, LXCONF=71, LXXMET=35, LXRWYD=40,
     +           LXOBSD=92, LXFPTD=41, LXUNIT=39, LXSPIA=100,
     +           LXSPIB=100, LXSPIC=100)

      PARAMETER (LXCLIM=60, LXRWYS=40, LXFIRS=14, LXSECS=20,
     +           LXACCS=20, LXFINS=21, LXOBSL=16, LXTRND=18,
     +           LXSPOU=100)

      CHARACTER ALINE*80,KEEPER*1
      LOGICAL SAME

      LUNDB=NINT(POPT(22))

C   READ INFO SHEET ARG MAPPING
      READ(UNIT=LUNDB,END=2000,ERR=2010)(MAPTYP(I),ARGNUM(I),ARGVAL(I),
     +         PORC(I),POPNUM(I),POPVAL(I),I=1,NMMP(CNTLST))

C   READ THE INFO SHEET ERROR RETURNS
      READ(UNIT=LUNDB,END=2000,ERR=2010)ERRARG
      DO 100 K = 1,NMERR(CNTLST),10
       READ(UNIT=LUNDB,END=2000,ERR=2010)
     + (ERRTYP(I),RETCOD(I),RETTXT(I),I=K,MIN(K+9,NMERR(CNTLST)))
100   CONTINUE

C   READ THE TEXT MAPPING RECORDS
      DO 102 I = 1,NMTMR(CNTLST)
         READ(UNIT=LUNDB,END=2000,ERR=2010)TMRTXT(I),TMRARG(I),TMRSET(I)
102   CONTINUE

C   READ THE SCAP COMMON DATA HANDLING INSTRUCTIONS
      READ(UNIT=LUNDB,END=2000,ERR=2010)
     +    (YPOP(I),I=1,LXPOPT),
     +    (YCON(I),I=1,LXCONF),
     +    (YXME(I),I=1,LXXMET)
      READ(UNIT=LUNDB,END=2000,ERR=2010)
     +    (YRWY(I),I=1,LXRWYD),
     +    (YOBS(I),I=1,LXOBSD),
     +    (YFPT(I),I=1,LXFPTD),
     +    (YUNI(I),I=1,LXUNIT)
      READ(UNIT=LUNDB,END=2000,ERR=2010)
     +    (YSPA(I),I=1,LXSPIA),
     +    (YSPB(I),I=1,LXSPIB)
      READ(UNIT=LUNDB,END=2000,ERR=2010)
     +    (YSPC(I),I=1,LXSPIC)
      READ(UNIT=LUNDB,END=2000,ERR=2010)
     +    (ZCLI(I),I=1,LXCLIM),
     +    (ZRWY(I),I=1,LXRWYS),
     +    (ZFIR(I),I=1,LXFIRS),
     +    (ZSEC(I),I=1,LXSECS),
     +    (ZACC(I),I=1,LXACCS),
     +    (ZFIN(I),I=1,LXFINS),
     +    (ZOBS(I),I=1,LXOBSL),
     +    (ZTRN(I),I=1,LXTRND)
      READ(UNIT=LUNDB,END=2000,ERR=2010)
     +    (ZSPO(I),I=1,LXSPOU)

C   READ THE MODEL TABLE, DOING INITIALIZATION STUFF IF ITS A KEEPER
      IF (KEEPER .EQ. 'Y')THEN
         MAXTAB = 0
         MAXINS = 7500
         MAXTNO = 0
C
         DO 103 I=1,999
          ARG(I)    = 0.
          IDORA(I) = 0
103      CONTINUE
         DO 104 I=1,899
          ILOC(I)   = 0
          TNOS(I)   = 0.
104      CONTINUE
      ENDIF


      READ(UNIT=LUNDB,END=2000,ERR=2010)ALINE
      READ(ALINE,1000)TNAME,WGT(2),OAT(2),KARD(1),KARD(2),KARD(3),DECKD,
     +               MRKNO,ADRT,IDARG,HGT(2),DIS(2),PWR
1000  FORMAT(2A3,A2,A1,3I5,6X,2A4,17X,2A4,A3,I3,2A1,A3)
      DO 106 I=1,72,24
         READ(UNIT=LUNDB,END=2000,ERR=2010)ALINE
         READ(ALINE,1010)(DESC(L),L=I,I+23)
1010     FORMAT(24A3)
106   CONTINUE

      DO 110 K = 1,KARD(1),250
          READ(UNIT=LUNDB,END=2000,ERR=2010)
     +    (  TNOS(I  ),I=K,MIN(K+249,KARD(1)))
110   CONTINUE
      DO 120 K = 1,KARD(2),250
          READ(UNIT=LUNDB,END=2000,ERR=2010)
     +    ( TABLE(I  ),I=K,MIN(K+249,KARD(2)))
120   CONTINUE
      DO 130 K = 1,KARD(3)/5,10
          READ(UNIT=LUNDB,END=2000,ERR=2010)
     +    ((INSTB(I,J),I=1,13),J=K,MIN(K+9,KARD(3)/5))
130   CONTINUE

      RDECH = 0
C
      IF (KEEPER .EQ. 'Y')THEN
          IF(MRKNO(2)(1:2).EQ.'07')THEN
           MAXTAB = 90000
           MAXTNO = 999
          ELSE
           MAXTAB = 20000
           MAXTNO = 99
          ENDIF
C---- INITIALIZE TABLE LOCATION ARRAY:
         ISUM    = 1
         ILOC(1) = 1
C
         DO 200 I=2,KARD(1)
          ISUM    = ISUM + INT(TNOS(I-1))
          ILOC(I) = ISUM
200      CONTINUE
C---- INITIALIZE DO POINTER ARRAY:
         ISAVE = INSTB(1,1) / 100
         IDORA(ISAVE) = 1
C
         DO 600 I=2,KARD(3) / 5
          ITEST = INSTB(1,I) / 100
C
          IF(ITEST.NE.ISAVE)THEN
           ISAVE = ITEST
           IDORA(ISAVE) = I
          ENDIF
600      CONTINUE

C        DO A DOUBLE CHECK TO MAKE SURE THE LOADED MODEL TABLES
C        ID AND FLAP MATCHES THAT WHICH HAS BEEN REQUESTED
         SAME = .TRUE.
C        CHECK MODEL TABLE ID
         SAME = SAME .AND. (MTNAME(CNTLST)(1:3) .EQ. TNAME(1))
         SAME = SAME .AND. (MTNAME(CNTLST)(4:6) .EQ. TNAME(2))
C        CHECK FLAP
         READ(DESC(71)(1:2),1020)I
1020     FORMAT(I2)
         SAME = SAME .AND. (IFLAP .EQ. I)

         IF (SAME) THEN
             RDECH = 0
           ELSE
             ERFLAG = 'B'
             ERRMSG(NXTMSG) =
     +        'MTID AND FLAP IN COMPACT DECK DO NOT MATCH SIF'
             NXTMSG = MIN(NXTMSG+1,20)
             RDECH = 1
         ENDIF
      ENDIF

      RETURN

2000  ERFLAG = 'C'
      ERRMSG(NXTMSG) =
     +  'END OF FILE ENCOUNTERED WHILE READING FROM DATABASE - RDECH'
      NXTMSG = MIN(NXTMSG+1,20)
      RDECH = 1
      RETURN

2010  ERFLAG = 'C'
      ERRMSG(NXTMSG) = 'ERROR READING FROM DATABASE - RDECH'
      NXTMSG = MIN(NXTMSG+1,20)
      RDECH = 1
      RETURN

      END
C*****************************************************************
      INTEGER FUNCTION RDTAB()

C  CALLS ROUTINES TO SELECT AND READ IN DESIRED MODEL TABLE

*=======================================================================
*= REVISIONS:
*= Backlog Item 2626   VHN September 2016:
*=                     1. Increased the size of local variable LASTDB to
*                         match with that of ACMBDI (255).
*=                     2. Added processing for non-valid or non-existing
*=                        database.
*=
*= Defect Item 1095    VHN September 2016: Separated the processing of
*=                     runway condition, POPT(14), when the database is
*=                     either CAA or CAA-UK or JAA.
*=
*= Defect Item 1416    VHN October 2016: Removed the call to function
*=                     LNBCHR. Function LNBCHR only resides in code file
*=                     STAS.F. Therefore, if BTOPS.FOR is compiled
*=                     independently, the compilation will fail.
*=======================================================================

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

C     COMMON BLOCK FOR DATABASE SHARED BETWEEN THIS FUNCTION
C     AND FUNCTION FNDFLP. THIS IS DONE TO ALLOW THE USER TO
C     SWITCH MULTIPLE DATABASES AND FLAP CHOICES (CONF(1))
C     WITHIN A SESSION.
      COMMON/DBNAME/LASTDB

      INTEGER MAX_LEN
      PARAMETER (MAX_LEN=LEN(ACMDBI))
      CHARACTER LASTDB*(MAX_LEN)
      CHARACTER TEMP_ACMDBI*(MAX_LEN)
      
      CHARACTER KEEPER*1
      INTEGER CNTWNT,FNDCNT,RDTOP,RDECH
      
      INTEGER LAST_DELIMITER_POS    

      SAVE LASTLU
      DATA LASTDB / 'NONE' /
      DATA LASTLU / -1 /

C  DEFINE INTERNAL PACK VALUE FROM SPEC INPUTS
      IF (CONF(4) .EQ. 2.)THEN
          APACK = 'OFF'
        ELSEIF (CONF(4) .EQ. 0.)THEN
          APACK = 'AUTO'
        ELSEIF ((CONF(4) .EQ. 1.) .OR. (CONF(4) .EQ. 3.)) THEN
          APACK = 'ON'
        ELSE
          APACK = 'ERROR'
      ENDIF
C  DEFINE INTERNAL RWY CONDITION VALUE FROM SPEC INPUTS
      IF ((POPT(14) .EQ. 9.E20) .AND. (CERTIF(1:3) .EQ. 'FAA')) THEN
          ARWY = 'DRY'
        ELSEIF (POPT(14) .EQ. 0.)THEN
          ARWY = 'DRY'
        ELSEIF (POPT(14) .EQ. 1.)THEN
          ARWY = 'WET'
        ELSEIF (POPT(14) .EQ. 11.)THEN
          ARWY = 'WET'
          IF ((CERTIF(1:3) .EQ. 'CAA') .OR. (CERTIF(1:6) .EQ. 'CAA-UK')
     +    .OR. (CERTIF(1:3) .EQ. 'JAR')) THEN
             ARWY = 'ERROR'
             ERFLAG = 'B'
             ERRMSG(NXTMSG) =
     +       'SLIPPERY RUNWAY NOT SUPPORTED FOR CAA/CAA-UK/JAR CERTIF'
             NXTMSG = MIN (NXTMSG+1,20)
             RDTAB = 1
             RETURN
          ENDIF
        ELSEIF ( (POPT(14) .EQ. 2.) .OR.
     +           (POPT(14) .EQ. 3.) .OR.
     +           (POPT(14) .EQ. 4.) .OR.
     +           (POPT(14) .EQ. 5.) .OR.
     +           (POPT(14) .EQ. 6.) .OR.
     +           (POPT(14) .EQ. 7.) .OR.
     +           (POPT(14) .EQ. 8.) .OR.
     +           (POPT(14) .EQ. 9.) ) THEN
          ARWY = 'CONTAMINATED'
        ELSE
          ARWY = 'ERROR'
      ENDIF

C  SET INTEGER VALUE OF DATA BASE LOGICAL UNIT NUMBER
      IF (POPT(22) .EQ. 9.E20)THEN
          ERFLAG = 'B'
          ERRMSG(NXTMSG) =
     +     'INPUT REQUIRED TO POPT(022) - DATABASE LOGICAL UNIT NUMBER'
          NXTMSG = MIN (NXTMSG+1,20)
          RDTAB = 1
          RETURN
        ELSE
          LUNDB = NINT(POPT(22))
      ENDIF

C  IF SELECTED DATABASE HAS CHANGED, CLOSE OLD FILE
      IF (ACMDBI .NE. LASTDB .AND. LASTDB .NE. 'NONE')CLOSE(LASTLU)
C  IF NEW DATABASE OR FIRST DATABASE, THEN OPEN FILE
      IF (ACMDBI .NE. LASTDB) THEN
         OPEN(UNIT=LUNDB,FILE=ACMDBI,STATUS='OLD',
     +        ACCESS='SEQUENTIAL',FORM='UNFORMATTED',
     +        IOSTAT=IOS)
C     +        IOSTAT=IOS,READONLY)
C              One replacement line above.
C              If you keep your BTOPS databases in a protected file area
C              or share them with others on a server, you may want to
C              open the files in read only mode.  There is no ANSI standard
C              F77 way to do this, but the replacement line above is a commonly
C              used implementation.  It is supported by the Compaq Visual
C              Fortran compiler.  Look for the OPEN command's syntax
C              in your Fortran compiler's documentation to find out how to do
C              this in your environment.
C              There are two occurences in BTOPS, this is one.
         IF (IOS .NE. 0) THEN
C           ERRMSG is 80-character long while ACMDBI is 255-character long.
C           Therefore, the directory path of ACMDBI must be removed in order
C           to fit into ERRMSG.  This is done by iteratively truncating
C           the path directory '\' delimiter until the only remaining of the
C           string is the database name.
            TEMP_ACMDBI = ACMDBI
            DO WHILE (INDEX(TEMP_ACMDBI,'\') .NE. 0)
               LAST_DELIMITER_POS = INDEX(TEMP_ACMDBI,'\')
               TEMP_ACMDBI =
     +            TEMP_ACMDBI((LAST_DELIMITER_POS + 1):MAX_LEN)
            ENDDO
            
            ERFLAG = 'B'
            ERRMSG(NXTMSG) = 'ERROR OPENING DATABASE '
            NXTMSG = MIN (NXTMSG+1,20)
            ERRMSG(NXTMSG)(1:12) = 'File name = '
            ERRMSG(NXTMSG)(13:LEN(ERRMSG)) = TEMP_ACMDBI
            NXTMSG = MIN(NXTMSG+1,20)
            RDTAB = IOS
            RETURN
         ENDIF
         IF (RDTOP() .NE. 0)THEN
            RDTAB = 1
            RETURN
         ENDIF
         LASTDB = ACMDBI
         LASTLU = NINT(POPT(22))
         CNTLST = 0
      ENDIF

C  SET INDEX NUM IN DATABASE FOR DESIRED MODEL TABLE
      CNTWNT = FNDCNT()
      IF(CNTWNT .EQ. -1)THEN
           TNAME(1) = '-NO'
           TNAME(2) = 'NE-'
           MAXTAB = 0
           MAXINS = 7500
           MAXTNO = 0
           RDTAB=1
C          Did not find a model table to load.
C          Make sure s/w knows no model table is loaded.
           CNTLST = 9999
           RETURN
        ELSEIF (CNTLST .NE. CNTWNT)THEN
           TNAME(1) = '-NO'
           TNAME(2) = 'NE-'
           MAXTAB = 0
           MAXINS = 7500
           MAXTNO = 0
      ENDIF

100   CONTINUE
      IF(CNTLST .EQ. CNTWNT)THEN
C        DESIRED MODEL TABLE IS LOADED
         RDTAB = 0
         RETURN
       ELSEIF (CNTLST .GT. CNTWNT)THEN
C        NEED TO REWIND DATABASE TO READ IN DESIRED MODEL TABLE
         IF(RDTOP() .NE. 0)THEN
            RDTAB = 1
            RETURN
         ENDIF
         CNTLST = 0
         GOTO 100
       ELSEIF (CNTLST .EQ. CNTWNT-1)THEN
C        DESIRED MODEL TABLE IS NEXT IN DATABASE, SO DO A FULL READ
         KEEPER = 'Y'
         CNTLST = CNTLST + 1
         IF (RDECH(KEEPER) .NE. 0)THEN
            RDTAB = 1
          ELSE
            RDTAB = 0
         ENDIF
         RETURN
       ELSE
C        NEED TO SKIP A MODEL TABLE IN THE DATABASE, DO PARTIAL READ
         KEEPER = 'N'
         CNTLST = CNTLST + 1
         IF (RDECH(KEEPER) .NE. 0)THEN
            RDTAB = 1
            RETURN
         ENDIF
         GOTO 100
      ENDIF

      END
C**********************************************************************
      INTEGER FUNCTION RDTOP()

C  READS INFO AT TOP OF DATABASE WHICH IDENTIFIES APPLICABILITY
C  OF MODEL TABLES CONTAINED IN DATABASE

C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------


      CHARACTER LLINE*150,GENSIF*1
      LOGICAL What

      What  = .True.
      LUNDB = NINT(POPT(22))
      INQUIRE (UNIT=LUNDB,OPENED=What)
      IF (.NOT. What) THEN
        OPEN(UNIT = LUNDB,FILE=ACMDBI,STATUS='OLD',ACCESS='SEQUENTIAL',
     +       FORM ='UNFORMATTED',IOSTAT=IOS)
      END IF
      REWIND(LUNDB)

      READ (UNIT=LUNDB,END=2000,ERR=2010) LLINE
      READ(LLINE,1000) DBI
1000  FORMAT(1X,A60)
C
C      IF (ACMDBI .NE. DBI) THEN
C         ERRMSG(NXTMSG)(1:10) = 'ACMDBI NE '
C         ERRMSG(NXTMSG)(11:70) = DBI
C         ERRMSG(NXTMSG)(71:80) = ' '
C         NXTMSG = MIN(NXTMSG+1,20)
C      ENDIF
C
      READ(UNIT=LUNDB,END=2000,ERR=2010)LLINE
      READ(LLINE,1010)SERID,RNUM,MTDPU,RDAT,NUMOWN,GENSIF
1010  FORMAT(8X,A6,10X,I3,1X,A2,11X,A12,12X,I3,7X,A1)

C     MAKE SURE THE DATABASE IS COMPATIBLE, I.E THE CORRECT GENERATION
      IF (GENSIF .NE.'B') THEN
         ERFLAG = 'C'
         ERRMSG(NXTMSG) =
     +    'THIS DATABASE IS NOT COMPATIBLE WITH THIS VERSION OF BTOPS'
         NXTMSG = MIN(NXTMSG+1,20)
         RDTOP = 1
         RETURN
      ENDIF

C     MAKE SURE DEPTH UNITS ARE INCHES, MILLIMETERS OR BLANK IN SIF
      IF (MTDPU .NE. 'IN' .AND.
     +    MTDPU .NE. 'MM' .AND.
     +    MTDPU .NE. '  ') THEN
          ERFLAG = 'C'
          ERRMSG(NXTMSG) =
     +     'THE SIF HEADER CONTAINS AN ILLEGAL CONT. DEPTH UNIT'
          NXTMSG = MIN(NXTMSG+1,20)
          RDTOP = 1
          RETURN
      ENDIF

      DO 100 I=1,NUMOWN
        READ(UNIT=LUNDB,END=2000,ERR=2010)LLINE
        READ(LLINE,1020)FRAME(I),ENGINE(I),RULES(I),FLAPS(I),BLEED(I),
     +                  RWYCON(I),MTNAME(I),REVNUM(I),DECK(I),
     +                  NONLIM(I),MTLIM(I),BRTXT(I),COUNT(I),NMMP(I),
     +                  NMERR(I),NMTMR(I),RLTXT(I)
1020  FORMAT(1X,A12,1X,A11,1X,A3,1X,I2,1X,A9,1X,A15,1X,A6,1X,I2,1X,A8,
     +       F10.1,F9.1,1X,A12,5X,I2,1X,I3,1X,I3,1X,I3,1X,A8)
100   CONTINUE
      RDTOP = 0
      RETURN

2000  ERFLAG = 'C'
      ERRMSG(NXTMSG) =
     +  'End of file encountered while reading from database '
      ERRMSG(NXTMSG)(53:72) = ACMDBI(1:20)
      NXTMSG = MIN(NXTMSG+1,20)
      RDTOP=1
      RETURN

2010  ERFLAG = 'C'
      ERRMSG(NXTMSG) = 'Error reading from database '
      ERRMSG(NXTMSG)(29:80) = ACMDBI(1:52)
      NXTMSG = MIN(NXTMSG+1,20)
      ERRMSG(NXTMSG) = 'Make sure you have the latest database,'
      NXTMSG = MIN(NXTMSG+1,20)
      ERRMSG(NXTMSG) = 'prepared for use with this system.'
      NXTMSG = MIN(NXTMSG+1,20)

      RDTOP=1
      RETURN

      END
C*********************************************************************
      INTEGER FUNCTION RUNIT()

C  RUNIT       CALLS OPTRAN INTERPRETER / CHART READER
C
C     REPLACES ALLUP2
C
C---- ENGINEERING IMPROVED CLIMB OPTION                       (ENG,OVE)
C
C---- THIS PROGRAM USES THE OPEN CHART READER TO PERFORM TAKEOFF
C     ANALYSES.  MAX BRAKE RELEASE WEIGHTS AND THEIR CORRESPONDING
C     TAKEOFF SPEEDS ARE CALCULATED VERSUS WIND AND TEMPERATURE.
C

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C
        CALL SRTOBE
        CALL OBSCKI
C
          ICRIT(1)   = 0
          ICRIT(2)   = 0
          ARG(15) = 0.
          SAVE1   = 1.E7
          SAVE2   = SAVE1
          SAVE3   = SAVE1
C
          DO 400  II=1,NOBS(1)
           I = II + II
           ARG( 31) = XX(I  ,1)
           ARG( 32) = XX(I-1,1)
           ARG(198) = II
           IF(II .EQ. NOBS(1)) THEN
              ARG(199) = 1
           ELSE
              ARG(199) = 0
           ENDIF
           CALL OBSSTE(II)
           CALL SEERI
           IF(IRR.LE.0)THEN
            IF(ARG(15).GE.0.)THEN
             IF (ARG(14).LT.SAVE1)THEN
              SAVE1 = ARG(14)
              SAVE8 = ARG(16)
              SAVE9 = ARG(17)
              SAV10 = ARG(18)
C
C----         IF THE OBSTACLE WEIGHT IS GREATER THAN OR EQUAL TO THE
C             MAXIMUM OF ARG(9) (FIELD LENGTH GW OR ENG OUT GW) AND
C             ARG(10) (ALL ENG GW OR VMCG GW), THEN THAT OBSTACLE IS
C             NOT LIMITING
C
              WMAX = AMAX1(ARG(9),ARG(10))
              IF(ARG(14).LT.WMAX)ICRIT(1) = II
             ENDIF
C
             IF(ARG(38).LT.SAVE2)THEN
              SAVE2 = ARG(38)
C
C----         IF THE IMPROVED CLIMB OBSTACLE WEIGHT IS GREATER THAN OR
C             EQUAL TO THE MAXIMUM OF ARG(9) (FIELD LENGTH GW OR ENG
C             OUT GW) AND ARG(10) (ALL ENG GW OR VMCG GW), THEN THAT
C             OBSTACLE IS NOT LIMITING IN IMPROVED CLIMB
C
              WMAX = AMAX1(ARG(9),ARG(10))
              IF (ARG(38).LT.WMAX)ICRIT(2) = II
             ENDIF

             IF(ARG(41).LT.SAVE3)THEN
              SAVE3 = ARG(41)
              SAVE4 = ARG(42)
              SAVE5 = ARG(43)
              SAVE6 = ARG(44)
              SAVE7 = ARG(37)
             ENDIF
            ELSE
C             Error message number was assigned in Optran
              GOTO 600
            ENDIF
           ELSE
C           Calculation error
            CALL TROMPO
            RUNIT = 1
            RETURN
           ENDIF
400       CONTINUE
C
          ARG(14) = SAVE1
          ARG(38) = SAVE2
          ARG(41) = SAVE3
          ARG(37) = SAVE7
          IF (ARG(197) .NE. 1.) THEN
             ARG(42) = SAVE4
             ARG(43) = SAVE5
             ARG(44) = SAVE6
             ARG(16) = SAVE8
             ARG(17) = SAVE9
             ARG(18) = SAV10
          ENDIF
          IF(ARG(14).LT.ARG(15))ARG(15) = ARG(14)
          IF(ARG(38).LT.ARG(41))ARG(41) = ARG(38)
600     CONTINUE

      RUNIT = 0
      RETURN
      END
C***********************************************************************
      SUBROUTINE SEERI
C
C---- THIS ROUTINE CONTROLS CALLING OF THE CHART READER.

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------


C
      IRR   = 0
      LOOP  = 0
      NOLOP = 10
      NOMOR = 1
C
      DO 300 M=1,400
       CALL CMPUT(NOMOR,KARD(3),TABLE,ARG,INSTB,TNOS,MAXTNO,ILOC,IDORA)
       IF(NOMOR.LT.1)THEN
        IF (NOMOR.EQ.-1)THEN
!         DO 200 J=0,1
!          DO 100 I=J*30+8,J*26+15,J*2+1
!           ARG(I) = INT(ARG(I))
!100       CONTINUE
!200      CONTINUE
C
         GOTO 999
        ELSE
         IRR = -NOMOR
         GOTO 400
        ENDIF
       ENDIF
300   CONTINUE
      IRR = 1
C
400   WRITE(ERRMSG(NXTMSG),10)IRR,INSTB(1,NINST)
      NXTMSG = MIN(NXTMSG+1,20)
      IF(IRR.EQ.2)THEN
         WRITE(ERRMSG(NXTMSG),15)KEXT,ARGR1,ARGR2
         NXTMSG = MIN(NXTMSG+1,20)
      ENDIF
C     INDICATE A COMPUTATION ERROR
      ERFLAG = 'C'
C
10    FORMAT(' ERROR TYPE ',I3,' DOING INSTRUCTION ',I5)
15    FORMAT(' TABLE ',I3,' EXCEEDED USING',F12.3,' AND ',F12.3)
C
999   RETURN
      END
C *************************************************************
      INTEGER FUNCTION SETCF()

C   SETS UNIT CONVERSION FACTORS
C   INPUT*CF(NUM) = INPUT IN MODEL TABLE UNITS

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------


      SETCF = 0

C  CF(3) CORRESPONDS TO REF 7.3,  CF(9) CORRESPONDS TO REF 7.9 ETC
C  INITIALIZE
      DO 100 I = 1,39
         CF(I) = 1.E-25
100   CONTINUE
      CF(40) = 1.

C  *** SET CONVERSION FACTORS FOR I/O ***
C  TEMPERATURE
      IF (UNIT(1) .EQ. 0. .OR. UNIT(1) .EQ. 2.)THEN
         IF (OAT(2) .EQ. 'C') THEN
             CF(1) = 1.
           ELSEIF (OAT(2) .EQ. 'F') THEN
             CF(1) = 9. / 5.
           ELSE
              SETCF = 1
              ERFLAG = 'C'
              ERRMSG(NXTMSG) =
     +          'UNKNOWN MODEL TABLE TEMPERATURE UNITS'
              NXTMSG = MIN(NXTMSG+1,20)
          ENDIF
        ELSEIF (UNIT(1) .EQ. 1. .OR. UNIT(1) .EQ. 3.)THEN
         IF (OAT(2) .EQ. 'F') THEN
             CF(1) = 1.
           ELSEIF (OAT(2) .EQ. 'C') THEN
             CF(1) = 5. / 9.
           ELSE
              SETCF = 1
              ERFLAG = 'C'
              ERRMSG(NXTMSG) =
     +          'UNKNOWN MODEL TABLE TEMPERATURE UNITS'
              NXTMSG = MIN(NXTMSG+1,20)
          ENDIF
        ELSE
           SETCF = 1
           ERFLAG = 'B'
           ERRMSG(NXTMSG) =
     +        'INVALID INPUT TO  UNIT(001) - TEMPERATURE UNITS'
           NXTMSG = MIN(NXTMSG+1,20)
      ENDIF

C  TIME - MODEL TABLE UNITS ARE MINUTES
      IF (UNIT(2) .EQ. 9.E20) THEN
           CF(2) = 1.
        ELSEIF (UNIT(2) .EQ. 1.) THEN
           CF(2) = 1.
        ELSEIF (UNIT(2) .EQ. 0.) THEN
           CF(2) = 1./60.
        ELSEIF (UNIT(2) .EQ. 2.) THEN
           CF(2) = 60.
        ELSE
           SETCF = 1
           ERFLAG = 'B'
           ERRMSG(NXTMSG) =
     +        'INVALID INPUT TO  UNIT(002) - TIME UNITS'
           NXTMSG = MIN(NXTMSG+1,20)
      ENDIF

C  DISTANCE
      IF (UNIT(3) .EQ. 0. .AND. DIS(2) .EQ. 'M')THEN
           CF(3) = 1.
        ELSEIF (UNIT(3) .EQ. 1. .AND. DIS(2) .NE. 'M')THEN
           CF(3) = 1.
        ELSEIF (UNIT(3) .EQ. 0. .AND. DIS(2) .NE. 'M')THEN
           CF(3) = 3.2808399
        ELSEIF (UNIT(3) .EQ. 1. .AND. DIS(2) .EQ. 'M')THEN
           CF(3) = 0.3048
        ELSE
           SETCF = 1
           ERFLAG = 'B'
           ERRMSG(NXTMSG) =
     +        'INVALID INPUT TO  UNIT(003) - DISTANCE UNITS'
           NXTMSG = MIN(NXTMSG+1,20)
      ENDIF
C  HEIGHT
      IF (UNIT(4) .EQ. 0. .AND. HGT(2) .EQ. 'M')THEN
           CF(4) = 1.
        ELSEIF (UNIT(4) .EQ. 1. .AND. HGT(2) .NE. 'M')THEN
           CF(4) = 1.
        ELSEIF (UNIT(4) .EQ. 0. .AND. HGT(2) .NE. 'M')THEN
           CF(4) = 3.2808399
        ELSEIF (UNIT(4) .EQ. 1. .AND. HGT(2) .EQ. 'M')THEN
           CF(4) = 0.3048
        ELSE
           SETCF = 1
           ERFLAG = 'B'
           ERRMSG(NXTMSG) =
     +        'INVALID INPUT TO  UNIT(004) - HEIGHT UNITS'
           NXTMSG = MIN(NXTMSG+1,20)
      ENDIF

C  DEPTH - UNIT CONVERTED TO MODEL TABLE'S APPROPRIATE UNITS
      IF(MTDPU .EQ. 'IN' .AND. UNIT(5) .EQ. 1. .OR.
     +   MTDPU .EQ. 'MM' .AND. UNIT(5) .EQ. 0. .OR.
     +   MTDPU .EQ. '  ' .AND. UNIT(5) .EQ. 0. .OR.
     +   UNIT(5) .EQ. 9.E20) THEN
          CF(5) = 1.
         ELSEIF(MTDPU .EQ. 'IN' .AND. UNIT(5) .EQ. 0.) THEN
          CF(5) = 1./25.4
         ELSEIF(MTDPU .EQ. 'MM' .AND. UNIT(5) .EQ. 1. .OR.
     +          MTDPU .EQ. '  ' .AND. UNIT(5) .EQ. 1.) THEN
          CF(5) = 25.4
         ELSE
            SETCF = 1
            ERFLAG = 'B'
            ERRMSG(NXTMSG) =
     +        'INVALID INPUT TO  UNIT(005) - DEPTH UNITS'
            NXTMSG = MIN(NXTMSG+1,20)
      ENDIF

C  PRESSURE FOR QFE OR QNH - MODEL TABLE UNITS ARE INCHES OF MERCURY
      IF (UNIT(6) .EQ. 9.E20) THEN
           CF(6) = 1.
         ELSEIF (UNIT(6) .EQ. 1.) THEN
           CF(6) = 1.
         ELSEIF (UNIT(6) .EQ. 0.) THEN
           CF(6) = 29.92126/1013.25
         ELSE
            SETCF = 1
            ERFLAG = 'B'
            ERRMSG(NXTMSG) =
     +        'INVALID INPUT TO  UNIT(006) - QFE,QNH PRESSURE UNITS'
            NXTMSG = MIN(NXTMSG+1,20)
      ENDIF

C  TIRE PRESSURE - MODEL TABLE UNITS ARE PSI
      IF (UNIT(7) .EQ. 9.E20) THEN
           CF(7) = 1.
         ELSEIF (UNIT(7) .EQ. 1.) THEN
           CF(7) = 1.
         ELSEIF (UNIT(7) .EQ. 0.) THEN
           CF(7) = 14.695949/101.325
         ELSE
            SETCF = 1
            ERFLAG = 'B'
            ERRMSG(NXTMSG) =
     +        'INVALID INPUT TO  UNIT(007) - TIRE PRESSURE UNITS'
            NXTMSG = MIN(NXTMSG+1,20)
      ENDIF

C  WEIGHT / MASS
C     ASSUMES AIRPLANE OPERATION ON EARTH.
C     FOR OTHER PLANETS, CALCULATE G IN ACCORDANCE WITH
C     THE METHODS OF SIR ISAAC NEWTON.
      G = 9.8067
      IF (UNIT(8) .EQ. 0.) THEN
           IF (WGT(2) .EQ. 'KG') THEN
                 CF(8) = 1.
               ELSEIF (WGT(2) .EQ. 'LB') THEN
                 CF(8) = 2.2046226
             ELSE
                 SETCF = 1
                 ERFLAG = 'C'
                 ERRMSG(NXTMSG) =
     +             'UNKNOWN MODEL TABLE WEIGHT UNITS'
                 NXTMSG = MIN(NXTMSG+1,20)
           ENDIF
         ELSEIF (UNIT(8) .EQ. 1.) THEN
           IF (WGT(2) .EQ. 'KG') THEN
                 CF(8) = 1. / 2.2046226
               ELSEIF (WGT(2) .EQ. 'LB') THEN
                 CF(8) = 1.
             ELSE
                 SETCF = 1
                 ERFLAG = 'C'
                 ERRMSG(NXTMSG) =
     +             'UNKNOWN MODEL TABLE WEIGHT UNITS'
                 NXTMSG = MIN(NXTMSG+1,20)
           ENDIF
         ELSEIF (UNIT(8) .EQ. 2.) THEN
           IF (WGT(2) .EQ. 'KG') THEN
                 CF(8) = 1000. / G
               ELSEIF (WGT(2) .EQ. 'LB') THEN
                 CF(8) = 1000. / G * 2.2046226
             ELSE
                 SETCF = 1
                 ERFLAG = 'C'
                 ERRMSG(NXTMSG) =
     +             'UNKNOWN MODEL TABLE WEIGHT UNITS'
                 NXTMSG = MIN(NXTMSG+1,20)
           ENDIF
        ELSE
            SETCF = 1
            ERFLAG = 'B'
            ERRMSG(NXTMSG) =
     +        'INVALID INPUT TO  UNIT(008) - WEIGHT UNITS'
            NXTMSG = MIN(NXTMSG+1,20)
      ENDIF

C   SPEED
      IF (UNIT(9) .EQ. 0.)THEN
           CF(9) = 2.2369363 * 0.86897624
         ELSEIF (UNIT(9) .EQ. 1.)THEN
           CF(9) = 0.5924838 / 60.
         ELSEIF (UNIT(9) .EQ. 2.)THEN
           CF(9) = 1.
         ELSEIF (UNIT(9) .EQ. 3.)THEN
           CF(9) = 0.5399568
        ELSE
           SETCF = 1
           ERFLAG = 'B'
           ERRMSG(NXTMSG) =
     +        'INVALID INPUT TO  UNIT(009) - SPEED UNITS'
           NXTMSG = MIN(NXTMSG+1,20)
      ENDIF

C  ONE MORE CONVERSION FACTOR, CF(41) IS SET IN TRNIN
C  SINCE IT REQUIRES THE OAT
C  CF(41) = PRESSURE ALT INCREMENT / GROSS HEIGHT
C         = ABSOLUTE STANDARD DAY TEMP / ABSOLUTE OAT

      RETURN
      END
C***************************************************************
      SUBROUTINE SRTOBE
C
C---- SORTS OBSTACLES ACCORDING TO DISTANCE


C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C
      DO 200 I=2,NOBS(1)
       DO 100 J=I,NOBS(1)
        IF(XX((I-1)*2,1).GT.XX(J*2,1))THEN
         TMP               = XX(J*2,1)
         XX(J*2,1)         = XX((I-1)*2,1)
         XX((I-1)*2,1)     = TMP
         TMP               = XX((J*2)-1,1)
         XX((J*2)-1,1)     = XX(((I-1)*2)-1,1)
         XX(((I-1)*2)-1,1) = TMP
        ENDIF
100    CONTINUE
200   CONTINUE
C
      RETURN
      END
C********************************************************************
      REAL FUNCTION TISA(ALTFT)

C   RETURNS THE ISA TEMP FOR THIS PRESSURE ALTITUDE IN I/O UNITS
C   SLISA = SEA LEVEL ISA TEMP
C   LR = LAPSE RATE

C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------


      REAL LR

      IF ((UNIT(1) .EQ. 0.) .OR. (UNIT(1) .EQ. 2.))THEN
C          DEGEES C AND FEET
           SLISA = 15.
           LR = -0.00198
         ELSEIF ((UNIT(1) .EQ. 1.) .OR. (UNIT(1) .EQ. 3.))THEN
C          DEGEES F AND FEET
           SLISA = 59.
           LR = -0.00357
         ELSE
           TISA = 9.E20
           RETURN
      ENDIF

      TISA = SLISA + LR * ALTFT
      RETURN
      END
C********************************************************
      SUBROUTINE TRACIT

C  TRACIT      WRITES IATA ARRAYS TO TRACE UNIT

*=----------------------------------------------------------------------
*=   REVISIONS:
*=
*= IMPORTANT NOTE:
*=   In the current implementation, the first comment line, COMENT(1)
*=   is reserved for other use within STAS. As a resul, if the input
*=   file has one or more comment lines and TRACE FLAG LEVEL POPTL(20)
*=   is set, the first comment line will always be overwritten in the
*=   TRACE file.  However, all comment(s) is(are) correctly printed
*=   out in the STASOUT file.
*=
*= Backlog Item 1591,  DMG & VHN May2015: Output-Remove unnecessary
*=                     blank spaces and carriage returns/line feeds
*=                     (CRLF).
*=                     1. Only allowed print out of COMENT and MISCLA
*=                        when exist in the input file.
*=
*= Backlog Item 1332,  VHN August 2016: Removed legacy Form Feed,
*=                     "FF = CHAR(12)".
*=======================================================================

C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      
      integer   NCLBLM, NRWYLM, NFIRLM, NSECLM, NACCLM, NFINLM
     +,         NOBSLM, NTRNLM, NSPOUT, NERMST, NOUTMS, NCMNT
      parameter (NCLBLM=200, NRWYLM=200, NFIRLM=200, NSECLM=200
     +,          NACCLM=200, NFINLM=200, NOBSLM=200, NTRNLM=200
     +,          NSPOUT=200,NERMST=20, NOUTMS=20, NCMNT=20)

      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C     File:  Param4.fi   6 Nov 1996
C     THESE PARAMETERS DEFINE THE SIZE OF EACH OF THE SCAP ARRAYS
      PARAMETER (LLPOPT=200, LLCONF=200, LLXMET=200, LLRWYD=200,
     +           LLOBSD=200, LLFPTD=200, LLUNIT=200, LLSPIA=200,
     +           LLSPIB=200, LLSPIC=200)

      PARAMETER (LLCLIM=200, LLRWYS=200, LLFIRS=200, LLSECS=200,
     +           LLACCS=200, LLFINS=200, LLOBSL=200, LLTRND=200,
     +           LLSPOU=200)

      CHARACTER SHORT*4,LONG*6,FF*1

C     INITIALIZE FORM FEED.
      FF = ' '

C  SET LOGICAL UNIT NUMBER FOR TRACE OUTPUT
      IF (POPT(21) .EQ. 9.E20) THEN
            ERFLAG = 'B'
            ERRMSG(NXTMSG) =
     +     'INPUT REQUIRED TO POPT(021) - TRACE LOGICAL UNIT NUMBER'
            NXTMSG = MIN (NXTMSG+1,20)
            RETURN
         ELSEIF (POPT(21) .EQ. POPT(22)) THEN
            ERFLAG = 'B'
            ERRMSG(NXTMSG) =
     +       'INVALID INPUT TO  POPT(021) - CANNOT EQUAL POPT(022)'
            NXTMSG = MIN (NXTMSG+1,20)
            ERRMSG(NXTMSG) =
     +       'LOGICAL UNIT NUMBERS FOR DATABASE AND TRACE OUTPUT '
            NXTMSG = MIN (NXTMSG+1,20)
            ERRMSG(NXTMSG) = 'CANNOT BE THE SAME'
            NXTMSG = MIN (NXTMSG+1,20)
            RETURN
         ELSE
            LUNTR = NINT(POPT(21))
      ENDIF

C  INPUT DATA

      SHORT='POPT'
      WRITE(LUNTR,1005,ERR=200)FF,SHORT
      WRITE(LUNTR,1000,ERR=200)(POPT(I),I=1,LLPOPT)

      SHORT='CONF'
      WRITE(LUNTR,1010,ERR=200)SHORT
      WRITE(LUNTR,1000,ERR=200)(CONF(I),I=1,LLCONF)

      SHORT='XMET'
      WRITE(LUNTR,1010,ERR=200)SHORT
      WRITE(LUNTR,1000,ERR=200)(XMET(I),I=1,LLXMET)

      SHORT='RWYD'
      WRITE(LUNTR,1010,ERR=200)SHORT
      WRITE(LUNTR,1000,ERR=200)(RWYD(I),I=1,LLRWYD)

      SHORT='OBSD'
      WRITE(LUNTR,1005,ERR=200)FF,SHORT
      WRITE(LUNTR,1000,ERR=200)(OBSD(I),I=1,LLOBSD)

      SHORT='FPTD'
      WRITE(LUNTR,1010,ERR=200)SHORT
      WRITE(LUNTR,1000,ERR=200)(FPTD(I),I=1,LLFPTD)

      SHORT='UNIT'
      WRITE(LUNTR,1010,ERR=200)SHORT
      WRITE(LUNTR,1000,ERR=200)(UNIT(I),I=1,LLUNIT)

      SHORT='SPIA'
      WRITE(LUNTR,1005,ERR=200)FF,SHORT
      WRITE(LUNTR,1000,ERR=200)(SPIA(I),I=1,LLSPIA)

      SHORT='SPIB'
      WRITE(LUNTR,1010,ERR=200)SHORT
      WRITE(LUNTR,1000,ERR=200)(SPIB(I),I=1,LLSPIB)

      SHORT='SPIC'
      WRITE(LUNTR,1005,ERR=200)FF,SHORT
      WRITE(LUNTR,1000,ERR=200)(SPIC(I),I=1,LLSPIC)

      WRITE(LUNTR,*,ERR=200)' '
      WRITE(LUNTR,*,ERR=200)'ACTYPE = ',ACTYPE
      WRITE(LUNTR,*,ERR=200)'ENGTYP = ',ENGTYP
      WRITE(LUNTR,*,ERR=200)'RATING = ',RATING
      WRITE(LUNTR,*,ERR=200)'BRAKES = ',BRAKES
      WRITE(LUNTR,*,ERR=200)'CERTIF = ',CERTIF
      WRITE(LUNTR,*,ERR=200)'REVNBR = ',REVNBR
      WRITE(LUNTR,*,ERR=200)'DATE   = ',DATE
      WRITE(LUNTR,*,ERR=200)'DBOPTI = ',DBOPTI
      
      WRITE(LUNTR,985,ERR=200)ACMDBI(1:LEN_TRIM(ACMDBI))
985   FORMAT(1X,'ACMDBI = ',A)

      WRITE(LUNTR,*,ERR=200)'APTIDT = ',APTIDT
      WRITE(LUNTR,*,ERR=200)'RWYNBR = ',RWYNBR

C     Also check if the second comment line, COMENT(2)
C     has content. COMENT(1) is reserved for other use.
      ICMNTL1 = LEN_TRIM(COMENT(1))
      ICMNTL2 = LEN_TRIM(COMENT(2))
      IF ((ICMNTL1 .GT. 0) .OR. (ICMNTL2 .GT. 0)) THEN
         DO 10 I = 1,NCMNT
            ICMNTL=LEN_TRIM(COMENT(I))
            IF (ICMNTL .GT. 0) THEN
               WRITE(LUNTR,990,ERR=200) COMENT(I)(1:ICMNTL)
990            FORMAT(1X,'COMENT =',A)
            ENDIF
10       CONTINUE
      ELSE
         WRITE(LUNTR,*,ERR=200)'COMENT = '          
      ENDIF

      IMISCLA = LEN_TRIM(MISCLA)
      IF (IMISCLA .GT. 0) THEN
         WRITE(LUNTR,995,ERR=200) MISCLA(1:IMISCLA)
995      FORMAT(1X,'MISCLA = ',A)
      ELSE
         WRITE(LUNTR,*,ERR=200)'MISCLA = '
      ENDIF

C  OUTPUT DATA

      LONG='CLIMIT'
      WRITE(LUNTR,1015,ERR=200)FF,LONG
      WRITE(LUNTR,1000,ERR=200)(CLIMIT(I),I=1,LLCLIM)

      LONG='RWYSEG'
      WRITE(LUNTR,1020,ERR=200)LONG
      WRITE(LUNTR,1000,ERR=200)(RWYSEG(I),I=1,LLRWYS)

      LONG='FIRSEG'
      WRITE(LUNTR,1020,ERR=200)LONG
      WRITE(LUNTR,1000,ERR=200)(FIRSEG(I),I=1,LLFIRS)

      LONG='SECSEG'
      WRITE(LUNTR,1020,ERR=200)LONG
      WRITE(LUNTR,1000,ERR=200)(SECSEG(I),I=1,LLSECS)

      LONG='ACCSEG'
      WRITE(LUNTR,1020,ERR=200)LONG
      WRITE(LUNTR,1000,ERR=200)(ACCSEG(I),I=1,LLACCS)

      LONG='FINSEG'
      WRITE(LUNTR,1020,ERR=200)LONG
      WRITE(LUNTR,1000,ERR=200)(FINSEG(I),I=1,LLFINS)

      LONG='OBSLIM'
      WRITE(LUNTR,1020,ERR=200)LONG
      WRITE(LUNTR,1000,ERR=200)(OBSLIM(I),I=1,LLOBSL)

      LONG='TRNDAT'
      WRITE(LUNTR,1020,ERR=200)LONG
      WRITE(LUNTR,1000,ERR=200)(TRNDAT(I),I=1,LLTRND)

      LONG='SPOUTA'
      WRITE(LUNTR,1015,ERR=200)FF,LONG
      WRITE(LUNTR,1000,ERR=200)(SPOUTA(I),I=1,LLSPOU)

      WRITE(LUNTR,1050,ERR=200)ERFLAG

      WRITE(LUNTR,*,ERR=200)'ERRMSG = '
      DO 100 I=1,20
         WRITE(LUNTR,1040,ERR=200)ERRMSG(I)(1:79)
100   CONTINUE

      WRITE(LUNTR,*,ERR=200)'MMIDNT = ',MMIDNT
      WRITE(LUNTR,*,ERR=200)'MMDATE = ',MMDATE
      WRITE(LUNTR,*,ERR=200)'ACMDBO = ',ACMDBO

      WRITE(LUNTR,*,ERR=200)'OUTMIS = '
      DO 110 I=1,20
         WRITE(LUNTR,*,ERR=200)OUTMIS(I)
110   CONTINUE
      WRITE(LUNTR,1030,ERR=200)FF

200   CONTINUE
      RETURN

1000  FORMAT(5(1X,1P,G14.6))
1005  FORMAT(A1,A4,' ARRAY')
1010  FORMAT(/1X,A4,' ARRAY')
1015  FORMAT(A1,A6,' ARRAY')
1020  FORMAT(/1X,A6,' ARRAY')
1030  FORMAT(A1)
1040  FORMAT(1X,A79)
1050  FORMAT(/' ERFLAG = ',A)
      END
C*************************************************************************
      REAL FUNCTION TSTEQZ(X,Y)

C     USED FOR TESTING EQUIVALENCE.  RETURNS ABS( (X-Y)/X )

C     PROTECT AGAINST DIVIDE BY ZERO
      IF (X .NE. 0.) THEN
             Z = X
         ELSE
             Z = 1.E-7
      ENDIF

      TSTEQZ = ABS((Z-Y)/Z)
      RETURN
      END
C*********************************************************
      INTEGER FUNCTION TRNIN()

C  TRNIN       TRANSLATED IATA ARRAY INPUTS INTO OPTRAN
C              ARG INPUTS IN MODEL TABLES UNITS

*=========================================================================
*= REVISIONS:
*= Backlog Item B-02004,  VHN, August 2016:
*=                        Changed comment lines for QNH and QFE to reference
*=                        to either HectoPascal or Inches Hg units.
*=========================================================================

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------

      COMMON /MFRORD/ORD(2,22),OMARK7(8)

C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------


      INTEGER SETCF,ARGPOS(22),SPACF(16),SPACF2(8)
      LOGICAL BADOBS

      SAVE ARGPOS
      DATA ARGPOS /22,23,28,29,30,45,46,47,48,49,100,101,102,
     +             103,104,105,106,107,108,109,110,111/

C     CONVERSION FACTORS FOR EVEN NUMBERED SPIA ARRAY ELEMENTS FROM 2 TO 32
      DATA SPACF /3,3,3,3,3,3,3,3,3,8,40,40,40,9,9,9/
C     CONVERSION FACTORS FOR EVEN NUMBERED SPIA ARRAY ELEMENTS FROM 38 TO 52
      DATA SPACF2 /8,8,8,8,8,9,9,9/

C  ASSUME IT WILL RETURN WITHOUT ERROR UNTIL A PROBLEM IS ENCOUNTERED
      TRNIN = 0

C  SET THE I/O TO MODEL TABLE UNIT CONVERSION FACTORS FOR
C  DISTANCE, HEIGHT, WEIGHT AND SPEED
      IF (SETCF() .NE. 0)THEN
         TRNIN = 1
      ENDIF

C  CHECK FOR RANGE OF V1/VR INPUTS
      IF (POPT(2) .EQ. 1.) THEN
         IF (YPOP(3).LT.0 .OR. YPOP(4).LT.0) THEN
             ERFLAG = 'B'
             ERRMSG(NXTMSG)='INVALID INPUT TO  POPT(002) - V1/VR RANGE'
             NXTMSG = MIN(NXTMSG+1,20)
             ERRMSG(NXTMSG) = 'REDUCED RANGE OF V1/VR NOT SUPPORTED'
             NXTMSG = MIN(NXTMSG+1,20)
             TRNIN = 1
           ELSE
             ARG(YPOP(3)) = POPT(3)
             ARG(YPOP(4)) = POPT(4)
         ENDIF
       ELSEIF (POPT(5).EQ.1.) THEN
         IF (YPOP(3).LT.0 .OR. YPOP(4).LT.0) THEN
             ERFLAG = 'B'
             ERRMSG(NXTMSG)='INVALID INPUT TO  POPT(005) - V1/VR CHOICE'
             NXTMSG = MIN(NXTMSG+1,20)
             ERRMSG(NXTMSG) = 'FIXED V1/VR NOT SUPPORTED'
             NXTMSG = MIN(NXTMSG+1,20)
             TRNIN = 1
           ELSE
             ARG(YPOP(3)) = POPT(6)
             ARG(YPOP(4)) = POPT(6)
         ENDIF
      ENDIF

C  CHECK FOR FIXED I/C INPUT
      IF (YPOP(8) .GT. 0.) ARG(YPOP(8)) = POPT(8)
C  CHECK FOR SCREEN HT AND VERTICAL OBS CLEARANCE
      IF (YPOP(9) .GT. 0.) ARG(YPOP(9)) = POPT(9) * CF(4)
      IF (YPOP(10) .GT. 0.) ARG(YPOP(10)) = POPT(10) * CF(4)

C  DEPTH OF CONTAMINATION
      IF ( (POPT(14) .EQ. 2. .OR.
     +      POPT(14) .EQ. 3. .OR.
     +      POPT(14) .EQ. 5. .OR.
     +      POPT(14) .EQ. 6.) .AND.
     +      POPT(15) .LT. 7.E20) THEN
          IF (YPOP(15).GT.0) THEN
              IF (POPT(15) .NE. 9.E20) THEN
                 ARG(YPOP(15)) = POPT(15) * CF(5)
              ENDIF
            ELSE
              ERFLAG = 'C'
              ERRMSG(NXTMSG) = 'INTERFACE FILE ERROR ON POPT(15)'
              NXTMSG = MIN(NXTMSG+1,20)
              TRNIN = 1
          ENDIF
      ENDIF

C  Airplane braking coefficient
      IF (YPOP(16) .GT. 0) THEN
C        An Optran argument has been specified for mu-b
         IF (POPT(16) .NE. 9.E20) THEN
C           User has input a mu-b
            IF (POPT(16).GE.0.05 .AND. POPT(16).LE.0.2)THEN
C               Input looks valid.  Set it.
                ARG(YPOP(16)) = POPT(16)
               ELSE
C               Out of range.  Throw a message.
                ERFLAG = 'B'
                ERRMSG(NXTMSG) =
     +            'AIRPLANE BRAKING COEFFICIENT OUT OF RANGE'
                NXTMSG = MIN(NXTMSG+1,20)
                TRNIN = 1
            ENDIF
           ELSE
C           Argument was specified for mu-b, but user did not input
C           a value for mu-b.  Set optran argument to zero.
            ARG(YPOP(16)) = 0.
         ENDIF
      ENDIF

C  USER INPUT MAX WEIGHT
      IF (POPT(23) .EQ. 1.) THEN
         IF (YPOP(24) .GT. 0.) THEN
               ARG(YPOP(24)) = MIN(POPT(24)*CF(8),MTLIM(CNTLST))
            ELSE
              ERFLAG = 'C'
              ERRMSG(NXTMSG) = 'INTERFACE FILE ERROR ON POPT(24)'
              NXTMSG = MIN(NXTMSG+1,20)
              TRNIN = 1
          ENDIF
        ELSEIF (POPT(23) .EQ. 0.) THEN
         IF (YPOP(24) .GT. 0.) THEN
               ARG(YPOP(24)) = MTLIM(CNTLST)
            ELSE
              ERFLAG = 'C'
              ERRMSG(NXTMSG) = 'INTERFACE FILE ERROR ON POPT(24)'
              NXTMSG = MIN(NXTMSG+1,20)
              TRNIN = 1
          ENDIF
        ELSE
              ERFLAG = 'C'
              ERRMSG(NXTMSG) =
     +         'INVALID INPUT TO  POPT(23) - SELECTED MAX WEIGHT'
              NXTMSG = MIN(NXTMSG+1,20)
              TRNIN = 1
      ENDIF

C AIRPORT PRESSURE ALTITUDE
C       SET ELEVATION IN FEET
         IF (UNIT(4) .EQ. 0.)THEN
            ELEV = RWYD(1) * 3.2808399
          ELSEIF(UNIT(4) .EQ. 1.)THEN
            ELEV = RWYD(1)
         ENDIF
C        FIND THE PRESSURE ALTITUDE IN FEET
C        EITHER DIRECTLY OR USING DEFINITIONS OF QNH OR QFE.
         IF (XMET(4) .EQ. 0.)THEN
            IF(UNIT(4) .EQ. 1.)THEN
                ALTFT = XMET(5)
              ELSEIF (UNIT(4) .EQ. 0.)THEN
                ALTFT = XMET(5) * 3.2808399
              ELSE
                ERFLAG = 'B'
                ERRMSG(NXTMSG) =
     +          'INVALID INPUT TO  UNIT(004) - HEIGHT UNITS'
                NXTMSG = MIN(NXTMSG+1,20)
                TRNIN = 1
            ENDIF
          ELSEIF(XMET(4) .EQ. 1.)THEN
C            SET QNH EITHER TO HECTOPASCAL OR INCHES HG UNITS
             IF(UNIT(6) .EQ. 0.)THEN
               QNH = XMET(5)
               IF(QNH.LT.100.)THEN
                 ERFLAG = 'B'
                 ERRMSG(NXTMSG) = 'XMET(5) INCONSISTENT WITH UNIT(6)'
                 NXTMSG = MIN(NXTMSG+1,20)
                 TRNIN = 1
                ENDIF
              ELSEIF(UNIT(6) .EQ. 1.)THEN
               QNH = XMET(5) * 1013.25 / 29.92126
               IF(QNH.GT.2000.)THEN
                 ERFLAG = 'B'
                 ERRMSG(NXTMSG) = 'XMET(5) INCONSISTENT WITH UNIT(6)'
                 NXTMSG = MIN(NXTMSG+1,20)
                 TRNIN = 1
                ENDIF
             ENDIF
C           CALCULATE PRESSURE ALTITUDE IN FEET
             ALTFT = ELEV+145442.154*(1.-(QNH/1013.25)**.190263189)
           ELSEIF(XMET(4) .EQ. 2.)THEN
C            SET QFE TO EITHER HECTOPASCAL OR INCHES HG UNITS
             IF(UNIT(6) .EQ. 0.)THEN
                QFE = XMET(5)
               IF(QFE.LT.100.)THEN
                 ERFLAG = 'B'
                 ERRMSG(NXTMSG) = 'XMET(5) INCONSISTENT WITH UNIT(6)'
                 NXTMSG = MIN(NXTMSG+1,20)
                 TRNIN = 1
                ENDIF
              ELSEIF(UNIT(6) .EQ. 1.)THEN
                QFE = XMET(5) * 1013.25 / 29.92126
               IF(QFE.GT.2000.)THEN
                 ERFLAG = 'B'
                 ERRMSG(NXTMSG) = 'XMET(5) INCONSISTENT WITH UNIT(6)'
                 NXTMSG = MIN(NXTMSG+1,20)
                 TRNIN = 1
                ENDIF
             ENDIF
             ALTFT = -145442.154*(-1.+(QFE/1013.25)**.190263189)
           ELSE
             ERFLAG = 'B'
             ERRMSG(NXTMSG) = 'INVALID INPUT TO XMET(4)'
             NXTMSG = MIN(NXTMSG+1,20)
             TRNIN = 1
         ENDIF
C        THE PRESSURE ALTITUDE HAS BEEN CALCULATED, IN FEET.
C        NOW, SEND THE PRESSURE ALTITUDE, IN MODEL TABLE UNITS,
C        TO THE APPROPRIATE ARGUMENT NUMBER
         IF (YXME(5) .GT. 0.)THEN
            IF(HGT(2) .EQ. 'M')THEN
                ARG(YXME(5)) = ALTFT / 3.2808399
              ELSE
                ARG(YXME(5)) = ALTFT
            ENDIF
          ELSE
            ERFLAG = 'C'
            ERRMSG(NXTMSG) = 'INTERFACE FILE ERROR ON POPT(24)'
            NXTMSG = MIN(NXTMSG+1,20)
            TRNIN = 1
         ENDIF

C     CONVERT INPUT SCREEN HEIGHT AND VERT OBS CLR TO FEET FOR VALIDATION
      IF (UNIT(4).EQ.1.) THEN
          FTINP1 = POPT(9)
          FTINP2 = POPT(10)
        ELSE
          FTINP1 = POPT(9)  * 3.2808399
          FTINP2 = POPT(10) * 3.2808399
      ENDIF
C     IF THE IO REFERENCE ARRAYS SAY THE FORTRAN WILL TAKE CARE OF
C     SCREEN HEIGHT, VALIDATE IT.  9.E20 OR THE STANDARD VALUE
C     (WHICH DEPENDS ON RUNWAY CONDITION) WILL BE ACCEPTABLE.
      IF (YPOP(9).EQ.-2) THEN
         IF (POPT(9) .NE. 9.E20) THEN
            IF (POPT(14).EQ.9.E20 .OR. POPT(14).EQ.0.) THEN
C                DRY RUNWAY
                 IF (FTINP1 .LT. 34.5 .OR. FTINP1 .GT. 35.5) THEN
                    ERFLAG = 'B'
                    ERRMSG(NXTMSG) =
     +               'INVALID INPUT TO  POPT(009) - SCREEN HEIGHT'
                    NXTMSG = MIN(NXTMSG+1,20)
                    TRNIN = 1
                 ENDIF
               ELSE
C                WET OR CONTAMINATED RUNWAY
                 IF (FTINP1 .LT. 14.5 .OR. FTINP1 .GT. 15.5) THEN
                    ERFLAG = 'B'
                    ERRMSG(NXTMSG) =
     +               'INVALID INPUT TO  POPT(009) - SCREEN HEIGHT'
                    NXTMSG = MIN(NXTMSG+1,20)
                    TRNIN = 1
                 ENDIF
            ENDIF
         ENDIF
      ENDIF
C     SAME FOR VERTICAL OBSTACLE CLEARANCE
      IF (YPOP(10).EQ.-2) THEN
         IF (POPT(10) .NE. 9.E20) THEN
            IF (POPT(14).EQ.9.E20 .OR. POPT(14).EQ.0.) THEN
C                DRY RUNWAY
                 IF (FTINP2 .LT. 34.5 .OR. FTINP2 .GT. 35.5) THEN
                    ERFLAG = 'B'
                    ERRMSG(NXTMSG) =
     +               'INVALID INPUT TO  POPT(010) - VERT OBS CLR'
                    NXTMSG = MIN(NXTMSG+1,20)
                    TRNIN = 1
                 ENDIF
               ELSE
C                WET OR CONTAMINATED RUNWAY
                 IF (FTINP2 .LT. 14.5 .OR. FTINP2 .GT. 15.5) THEN
                    ERFLAG = 'B'
                    ERRMSG(NXTMSG) =
     +               'INVALID INPUT TO  POPT(010) - VERT OBS CLR'
                    NXTMSG = MIN(NXTMSG+1,20)
                    TRNIN = 1
                 ENDIF
            ENDIF
         ENDIF
      ENDIF

C  TEMPERATURE STUFF
      IF (UNIT(1) .EQ. 0. .OR. UNIT(1) .EQ. 1.) THEN
             AAT = XMET(1)
         ELSEIF (UNIT(1) .EQ. 2. .OR. UNIT(1) .EQ. 3.) THEN
             AAT = XMET(1) + TISA(ALTFT)
        ELSE
              ERFLAG = 'B'
              ERRMSG(NXTMSG) =
     +         'INVALID INPUT TO  UNIT(001) - TEMP UNITS'
              NXTMSG = MIN(NXTMSG+1,20)
              TRNIN = 1
      ENDIF
      IF (YXME(1) .GT. 0. )THEN
          ARG(YXME(1)) = CF(1)*(AAT+40.)-40.
        ELSE
           ERFLAG = 'C'
           ERRMSG(NXTMSG) = 'INTERFACE FILE ERROR ON XMET(1)'
           NXTMSG = MIN(NXTMSG+1,20)
           TRNIN = 1
      ENDIF

C  ACTUAL TEMPERATURE STUFF
      IF (XMET(6) .GT. 8.E20) THEN
C         ACTUAL TEMP NOT SUPPLIED
          ARG(153) = 0.
          ARG(156) = 0.
        ELSE
C         ACTUAL TEMP IS SUPPLED.
          ARG(156) = 1.
C         MAKE SURE MODULE SUPPORTS IT.
          IF (YXME(6) .LT. 0.) THEN
             ERFLAG = 'B'
             ERRMSG(NXTMSG)(1:31)  = 'MODULE DOES NOT SUPPORT ACTUAL '
             ERRMSG(NXTMSG)(32:60) = 'TEMPERATURE INPUT TO XMET(6)'
             NXTMSG = MIN(NXTMSG+1,20)
             TRNIN = 1
            ELSE
C            MAKE SURE THE ASSUMED TEMP >= THE ACTUAL
             IF (XMET(1) .LT. XMET(6)) THEN
                 ERFLAG = 'B'
                 ERRMSG(NXTMSG)(1:29)  = 'ASSUMED TEMPERATURE LESS THAN'
                 ERRMSG(NXTMSG)(30:48) = ' ACTUAL TEMPERATURE'
                 NXTMSG = MIN(NXTMSG+1,20)
                 TRNIN = 1
                ELSE
C                SET THE ACTUAL OAT
                 IF (UNIT(1) .EQ. 0. .OR. UNIT(1) .EQ. 1.) THEN
                   AOAT = XMET(6)
                  ELSEIF (UNIT(1) .EQ. 2. .OR. UNIT(1) .EQ. 3.) THEN
                   AOAT = XMET(6) + TISA(ALTFT)
                  ELSE
                   ERFLAG = 'B'
                   ERRMSG(NXTMSG) =
     +             'INVALID INPUT TO  UNIT(001) - TEMP UNITS'
                   NXTMSG = MIN(NXTMSG+1,20)
                   TRNIN = 1
                 ENDIF
                 IF (YXME(6) .GT. 0. )THEN
                   ARG(YXME(6)) = CF(1)*(AOAT+40.)-40.
                  ELSE
                   ERFLAG = 'C'
                   ERRMSG(NXTMSG) = 'INTERFACE FILE ERROR ON XMET(6)'
                   NXTMSG = MIN(NXTMSG+1,20)
                   TRNIN = 1
                 ENDIF
                 IF (XMET(1).GT.XMET(6))THEN
C                    Reduced thrust case
                     ARG(153) = 1.
                   ELSEIF (XMET(1).EQ.XMET(6)) THEN
C                    Full thrust case with two temps supplied.
C                    Flag as one temp case to ensure consistency.
                     ARG(153) = 0.
                   ELSE
C                    Error case.  Should have been previously trapped.
C                    So, this should be dead code.
                     ARG(153) = -999.
                 ENDIF
             ENDIF
          ENDIF
      ENDIF

C  ELEVATION IS NEEDED FOR STANDARD DAY CALC, MAKE SURE ONE WAS GIVEN
      IF (RWYD(1) .EQ. 9.E20) THEN
         ERFLAG = 'C'
         ERRMSG(NXTMSG)=
     +   'INPUT REQUIRED TO RWYD(001) - AIRPORT ELEVATION'
         NXTMSG = MIN(NXTMSG+1,20)
         TRNIN = 1
      ENDIF

C  NOW THAT WE HAVE THE OAT, WE CAN SET CF(41)
C  SET CF(41) = PRESSURE ALT INCREMENT / GROSS HEIGHT
C             = ABSOLUTE STANDARD DAY TEMP / ABSOLUTE OAT
C    SET ACTUAL TEMP IN MODEL TABLE UNITS
C     ATEMP = ARG(YXME(1))
      IF (YXME(6) .LT. 0) THEN
C        Two temperature input is not supported.  Use XMET(1) as OAT for this.
         ATEMP = ARG(YXME(1))
        ELSE
C        Two temperature input is supported.
C        Use XMET(6) if user has input this parameter.  Otherwise, use XMET(1).
         IF (ARG(153).EQ.1. .AND. ARG(YXME(6)).LT.7.E20) THEN
C             User has input an actual OAT.  Use it.
              ATEMP = ARG(YXME(6))
            ELSE
C             User has NOT input an actual OAT.  Use XMET(1).
              ATEMP = ARG(YXME(1))
         ENDIF
      ENDIF

C    SET STANDARD DAY TEMP IN I/O UNITS, THEN CONVERT TO MODEL TABLE UNITS
      STEMP = TISA(ALTFT)
      STEMP = CF(1) * (STEMP+40.) - 40.
C    CONVERT TEMPS TO ABSOLUTE TEMP SCALE
      IF(OAT(2) .EQ. 'C')THEN
          STEMP = STEMP + 273.15
          ATEMP = ATEMP + 273.15
        ELSEIF (OAT(2) .EQ. 'F') THEN
          STEMP = STEMP + 459.67
          ATEMP = ATEMP + 459.67
      ENDIF
      CF(41) = STEMP / ATEMP
C
C  WIND (component along runway ceterline)
      IF (YXME(2) .GT. 0)THEN
          ARG(YXME(2)) = XMET(2) * CF(9)
        ELSE
           ERFLAG = 'C'
           ERRMSG(NXTMSG) = 'INTERFACE FILE ERROR ON XMET(2)'
           NXTMSG = MIN(NXTMSG+1,20)
           TRNIN = 1
      ENDIF
C  CrossWIND (not generally supported by model tables)
      IF (YXME(3) .GT. 0)THEN
          ARG(YXME(3)) = XMET(3) * CF(9)
      ENDIF
C
C CHECK INTERFACE FILE FOR RUNWAY DISTANCES
      IF (YRWY(3) .LE. 0  .OR.
     +    YRWY(4) .LE. 0  .OR.
     +    YRWY(5) .LE. 0  .OR.
     +    YRWY(6) .LE. 0 )THEN
           ERFLAG = 'C'
           ERRMSG(NXTMSG) = 'INTERFACE FILE ERROR ON RUNWAY DATA'
           NXTMSG = MIN(NXTMSG+1,20)
           TRNIN = 1
       ENDIF

C      Define adjustments to TODA and ASDA for line-up
       IF (POPT(53).EQ.0. .OR. POPT(53).EQ.9.E20) THEN
C           Use POPT(12) and POPT(13) inputs.
C           SET ADJ1=TODA ADJUSTMENT
            IF (POPT(12).EQ.9.E20) THEN
                  ADJ1 = 0.
               ELSE
                  ADJ1 = POPT(12)
            ENDIF
C           SET ADJ2=ASDA ADJUSTMENT
            IF (POPT(13).EQ.9.E20) THEN
                  ADJ2 = 0.
               ELSE
                  ADJ2 = POPT(13)
            ENDIF
          ELSEIF (POPT(53) .EQ. 1.) THEN
C           Ignore POPT(12) and POPT(13).
C           Make assuption based on RWYD(12) and ACTYPE.
C           Check RWYD(12) input.
            IF (RWYD(12).LT.0. .OR. RWYD(12).GT.180.)THEN
                ERFLAG = 'B'
                ERRMSG(NXTMSG) = 'INVALID INPUT TO RWYD(12)'
                NXTMSG = MIN(NXTMSG+1,20)
                TRNIN = 1
              ELSE
C               RWYD(12) looks okay.  Use to define adjustments.
                CALL LINUPV
            ENDIF
          ELSE
            ERFLAG = 'B'
            ERRMSG(NXTMSG) = 'INVALID INPUT TO POPT(53)'
            NXTMSG = MIN(NXTMSG+1,20)
            ERRMSG(NXTMSG) = 'VALID VALUES ARE 0 AND 1'
            NXTMSG = MIN(NXTMSG+1,20)
            TRNIN = 1
       ENDIF

C      RUNWAY LENGTH
       ARG(YRWY(3)) = (RWYD(3)-ADJ1) * CF(3)
C  CLEARWAY
       IF (RWYD(2) .EQ. 0.) THEN
           ARG(YRWY(5)) = (RWYD(5)-RWYD(3))*CF(3)
         ELSE
           ARG(YRWY(5)) = RWYD(5) * CF(3)
       ENDIF
C  THE STOPWAY INPUT TO THE MODEL TABLE IS COMPLICATED
C  BY ALIGNMENT ALLOWANCES AND ASDA INCREMENT.
C  THE CALCULATION DIVIDES BY RWYD(9), MAKE SURE ITS NOT ZERO.
C  ALSO, TREAT AN INPUT TO RWYD(9) OF 9.E20 AS A ONE.
       IF (RWYD(9) .EQ. 9.E20) THEN
           XR9 = 1.
         ELSEIF(RWYD(9).EQ.0)THEN
           ERFLAG = 'B'
           ERRMSG(NXTMSG) =
     +      'INVALID INPUT TO RWYD(009) - ASDA FACTOR CANNOT = 0'
           NXTMSG = MIN(NXTMSG+1,20)
           TRNIN = 1
         ELSE
           XR9 = RWYD(9)
       ENDIF
C      SET THE ASDA INCREMENT VALUE TO ASDINC
C      IF THE USER HASN'T SPECIFIED ONE, ASSUME  THAT IT IS ZERO
       IF (RWYD(10).EQ.9.E20)THEN
             ASDINC = 0.
          ELSE
             ASDINC = RWYD(10)
       ENDIF
       IF (RWYD(2) .EQ. 0.) THEN
           ARG(YRWY(4)) =
     +      (RWYD(4)-RWYD(3)+ADJ1-ADJ2+(ASDINC/XR9))*CF(3)
         ELSE
           ARG(YRWY(4)) =
     +      (RWYD(4)+ADJ1-ADJ2+(ASDINC/XR9)) * CF(3)
       ENDIF
C  SLOPE
       IF(YRWY(7) .GT. 0.) THEN
C          IF THERE IS SUPPORT FOR TWO SLOPES BUT ONLY ONE IS GIVEN
C          IN RWYD(6), USE IT FOR BOTH.
           ARG(YRWY(6)) = RWYD(6)
           IF (RWYD(7).GT.8.E20) THEN
                 ARG(YRWY(7)) = RWYD(6)
              ELSE
                 ARG(YRWY(7)) = RWYD(7)
           ENDIF
         ELSE
           IF(RWYD(7) .NE. RWYD(6) .AND.
     +        RWYD(7) .NE. 9.E20) THEN
                ERRMSG(NXTMSG)='ONLY RWYD(6) IS USED FOR SLOPE'
                NXTMSG = MIN(NXTMSG+1,20)
           ENDIF
           ARG(YRWY(6)) = RWYD(6)
       ENDIF

C  OBSTACLE HEIGHTS AND DISTANCES
         IF (OBSD(1) .EQ. 9.E20) THEN
            ERRMSG(NXTMSG) =
     +      'INPUT REQUIRED TO OBSD(001) - NUMBER OF OBSTACLES'
            NXTMSG = MIN(NXTMSG+1,20)
            TRNIN = 1
            RETURN
         ENDIF
           IF ((OBSD(1).LT.0.00).OR.(OBSD(1).GT.30.00)) THEN
              ERRMSG(NXTMSG) = 'INVALID NUMBER OF OBSTACLES'
              NXTMSG = MIN(NXTMSG+1,20)
              TRNIN = 1
              RETURN
         END IF
         NOBS(1) = MAX(NINT(OBSD(1)),1)
         IF (OBSD(2) .EQ. 0.) THEN
             REF(1) = 'BR'
           ELSEIF (OBSD(2) .EQ. 1.) THEN
             REF(1) = 'LO'
           ELSE
             ERFLAG = 'B'
             ERRMSG(NXTMSG) =
     +         'INVALID INPUT TO  OBSD(2) - OBSTACLE DATUM'
             NXTMSG = MIN(NXTMSG+1,20)
             TRNIN = 1
         ENDIF

         DO 100 MTN = 1,60
             XX(MTN,1) = 0.
100      CONTINUE
         DO 101 MTN = 1,NINT(OBSD(1))
C            Obstacle height
C            See OBSSTE for translation to liftoff end.
             XX(2*MTN-1,1) = OBSD(3*MTN+1) * CF(4)
C            Obstacle distance
             IF (OBSD(2) .EQ. 1.) THEN
C                  Liftoff end referenced.
                   XX(2*MTN,1) = OBSD(3*MTN) * CF(3)
                ELSE
C                  Brake release end referenced.  Line-up has impact.
                   XX(2*MTN,1) = (OBSD(3*MTN)-ADJ1) * CF(3)
             ENDIF
101      CONTINUE

C        Sanity check the obstacle distances
         IF (NINT(OBSD(1)) .GE. 1)THEN
            BADOBS = .FALSE.
            DO 111 MTN = 1,NINT(OBSD(1))
               IF (REF(1).EQ.'BR')THEN
                   BADOBS = BADOBS .OR. (XX(2*MTN,1).LT.ARG(YRWY(3)))
                 ELSEIF (REF(1) .EQ. 'LO')THEN
                   BADOBS = BADOBS .OR. (XX(2*MTN,1).LT.0.)
               ENDIF
111         CONTINUE
            IF (BADOBS) THEN
              ERFLAG = 'B'
              ERRMSG(NXTMSG) =
     +         'INVALID OBSTACLE DISTANCE'
              NXTMSG = MIN(NXTMSG+1,20)
              TRNIN = 1
            ENDIF
         ENDIF

C  TRACE INPUT IS IN POPT(20)
C  0. = NO TRACE, 1.=STANDARD TRACE, OR +/-IIIII.
C  IIIII=INSTRUCTION NUMBER FOR DUMPING
C  IF +IIIII: W/ STD DUMP,  -IIIII: W/O STD DMP
      IF( (POPT(20).LT.0. .OR. POPT(20) .GT. 3.) .AND.
     +    (POPT(20) .NE. 9.E20) )THEN
         NT(6) = NINT(POPT(21))
         IDUM(51)=1
         IF(POPT(20) .LT. 0.)THEN
            DUMINP = ABS(POPT(20))
           ELSE
            DUMINP = POPT(20)
         ENDIF
C        DUMINP = IIIII.
         IDUM(1) = AINT(DUMINP)
         IDUMP1(1) = 1
         IDUMP2(1) = 999
       ELSEIF (POPT(20) .EQ. 1.)THEN
         NT(6)=NINT(POPT(21))
         IDUM(51) = 0
       ELSE
         NT(6) = 6
         IDUM(51)=0
      ENDIF

C  USER INPUT LEVEL-OFF HEIGHT.
C  CHECK FOR TWO SITUATIONS WHERE IT NEEDS A LITTLE HELP.
C  THESE ARE INPUT IN METERS AND/OR INPUT IN PRESSURE ALT INCREMENT.
      IF(YPOP(19).GE.0 .AND. (UNIT(4).EQ.0..OR.POPT(50).EQ.1.))THEN
C        FIND WHERE IT IS MAPPED
         DO 200 I = 1,NMMP(CNTLST)
            IF(  PORC(I).EQ.'P' .AND.
     +           POPNUM(I) .EQ. 19 .AND.
     +           MAPTYP(I) .EQ. 'B') THEN
                    IF (UNIT(4) .EQ. 0.) THEN
C                      MODEL TABLE ALWAYS EXPECTS FEET - CONVERT
                       ARG(ARGNUM(I)) = ARG(ARGNUM(I)) * 3.2808399
                    ENDIF
                    IF (POPT(50) .EQ. 1.) THEN
C                      USER LEVEL OFF IS A PRESS ALT INCREMENT - CONVERT
                       ARG(ARGNUM(I)) = ARG(ARGNUM(I)) / CF(41)
                    ENDIF
            ENDIF
200      CONTINUE
      ENDIF

C  CHECK FOR SUPPLEMENTAL PERFORMANCE DATA
C     SPIA(1) through SPIA(32)
      DO 250 I = 1,16,1
         IF (YSPA(I*2) .GT. 0) THEN
            ARG(YSPA(I*2)) = SPIA(I*2) * CF(SPACF(I))
         ENDIF
C        Associated odd numbers are all multiplcation factors (dimensionless)
         IF (YSPA(I*2-1) .GT. 0) THEN
            ARG(YSPA(I*2-1)) = SPIA(I*2-1)
         ENDIF
250   CONTINUE
C     SPIA(37) through SPIA(52)
      DO 251 I = 19,26,1
         IF (YSPA(I*2) .GT. 0) THEN
            ARG(YSPA(I*2)) = SPIA(I*2) * CF(SPACF2(I))
         ENDIF
C        Associated odd numbers are all multiplcation factors (dimensionless)
         IF (YSPA(I*2-1) .GT. 0) THEN
            ARG(YSPA(I*2-1)) = SPIA(I*2-1)
         ENDIF
251   CONTINUE


C  SPECIAL HANDLING FOR
C  MODEL TABLE IMPLEMENTATION OF ALTERNATE FORWARD CG LIMITS.
C  MODEL TABLES USUALLY IMPLEMENT THIS FUNCTION USING A SINGLE
C  INPUT OPTRAN ARGUMENT.
C  IF ZERO IS INPUT, THE FORWARD LIMIT IS USED.
C  IF NON-ZERO INPUT, THE INPUT IS INTERPRETTED AS
C  THE ALTERNATE FORWARD CG LIMIT.
C  SCAP INTERPRETATION USES TWO INPUT VARIABLES, POPT(30) AND POPT(32).
C  THIS SECTION DOES THE NEEDED TRANSLATION BETWEEN THE TWO IMPLEMENTATIONS.
      IF(YPOP(30).GT.0 .AND. YPOP(30).EQ.YPOP(32) )THEN
C        APPLY SPECIAL HANDLING
         IF (POPT(30).EQ.0. .OR. POPT(30).EQ.9.E20) THEN
C             USE FORWARD LIMIT
              ARG(YPOP(30)) = 0.
            ELSEIF (POPT(30).EQ.3. .OR. POPT(30).EQ.1.) THEN
C             ALTERNATE FORWARD LIMIT IS IN POPT(32)
              IF (POPT(32).GT.0. .AND. POPT(32).LT.50.) THEN
C                  ASSUME IT IS VALID AND USE IT
                   ARG(YPOP(30)) = POPT(32)
                 ELSE
C                  SOUNDS LIKE AN INVALID %MAC
                   ERFLAG = 'B'
                   ERRMSG(NXTMSG) =
     +             'INVALID %MAC INPUT TO POPT(32)'
                   NXTMSG = MIN(NXTMSG+1,20)
                   TRNIN = 1
                   RETURN
              ENDIF
            ELSE
C             DONT KNOW WHAT TO DO WITH POPT(30)
              ERFLAG = 'B'
              ERRMSG(NXTMSG) =
     +        'INVALID INPUT TO POPT(30)'
              NXTMSG = MIN(NXTMSG+1,20)
              ERRMSG(NXTMSG) =
     +        'SET TO 0 OR 3'
              NXTMSG = MIN(NXTMSG+1,20)
              TRNIN = 1
              RETURN
         ENDIF
      ENDIF

C  CHECK FOR SECOND TO CARD OVERIDES
      DO 300 I = 1,22
        IF(ORD(1,I).EQ.1.)THEN
            ARG(ARGPOS(I))=ORD(2,I)
            WRITE(ERRMSG(NXTMSG),1000)ARGPOS(I),ORD(2,I)
1000        FORMAT('ARG(',I3.3,') OVERRIDDEN WITH ',1P,G14.6)
            NXTMSG = MIN(NXTMSG+1,20)
        ENDIF
300   CONTINUE

C  CHECK FOR INVALID MIN AND MAX V1/VR INPUT
      IF (POPT(3) .GT. POPT(4)) THEN
             ERFLAG = 'B'
             ERRMSG(NXTMSG) =
     +        'INVALID INPUT TO  POPT(003) - IT IS GREATER THAN POPT(4)'
             NXTMSG = MIN(NXTMSG+1,20)
             TRNIN = 1
      ENDIF

      RETURN
      END
C**********************************************************************
      INTEGER FUNCTION TRNIN9()

C  TRNIN9      TRANSLATED IATA ARRAY INPUTS INTO OPTRAN
C              ARG INPUTS IN MODEL TABLES UNITS.
C              Special version for model table mode which
C              find 25% redeuced thrust temp and break temp

*=========================================================================
*= REVISIONS:
*= Backlog Item B-02004,  VHN, August 2016:
*=                        Changed comment lines for QNH and QFE to reference
*=                        to either HectoPascal or Inches Hg units.
*=========================================================================

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------

      COMMON /MFRORD/ORD(2,22),OMARK7(8)

C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------


      INTEGER SETCF,ARGPOS(22)

      SAVE ARGPOS
      DATA ARGPOS /22,23,28,29,30,45,46,47,48,49,100,101,102,
     +             103,104,105,106,107,108,109,110,111/

C  ASSUME IT WILL RETURN WITHOUT ERROR UNTIL A PROBLEM IS ENCOUNTERED
      TRNIN9 = 0

C  SET THE I/O TO MODEL TABLE UNIT CONVERSION FACTORS FOR
C  DISTANCE, HEIGHT, WEIGHT AND SPEED
      IF (SETCF() .NE. 0)THEN
         TRNIN9 = 1
      ENDIF

C AIRPORT PRESSURE ALTITUDE
C       SET ELEVATION IN FEET
         IF (UNIT(4) .EQ. 0.)THEN
            ELEV = RWYD(1) * 3.2808399
          ELSEIF(UNIT(4) .EQ. 1.)THEN
            ELEV = RWYD(1)
         ENDIF
C        FIND THE PRESSURE ALTITUDE IN FEET
C        EITHER DIRECTLY OR USING DEFINITIONS OF QNH OR QFE.
         IF (XMET(4) .EQ. 0.)THEN
            IF(UNIT(4) .EQ. 1.)THEN
                ALTFT = XMET(5)
              ELSEIF (UNIT(4) .EQ. 0.)THEN
                ALTFT = XMET(5) * 3.2808399
              ELSE
                ERFLAG = 'B'
                ERRMSG(NXTMSG) =
     +          'INVALID INPUT TO  UNIT(004) - HEIGHT UNITS'
                NXTMSG = MIN(NXTMSG+1,20)
                TRNIN9 = 1
            ENDIF
          ELSEIF(XMET(4) .EQ. 1.)THEN
C            SET QNH TO EITHER HECTOPASCAL OR INCHES HG UNITS
             IF(UNIT(6) .EQ. 0.)THEN
               QNH = XMET(5)
              ELSEIF(UNIT(6) .EQ. 1.)THEN
               QNH = XMET(5) * 1013.25 / 29.92126
             ENDIF
C           CALCULATE PRESSURE ALTITUDE IN FEET
             ALTFT = ELEV+145442.154*(1.-(QNH/1013.25)**.190263189)
           ELSEIF(XMET(4) .EQ. 2.)THEN
C            SET QFE TO EITHER HECTOPASCAL OR INCHES HG UNITS
             IF(UNIT(6) .EQ. 0.)THEN
                QFE = XMET(5)
              ELSEIF(UNIT(6) .EQ. 1.)THEN
                QFE = XMET(5) * 1013.25 / 29.92126
             ENDIF
             ALTFT = -145442.154*(-1.+(QFE/1013.25)**.190263189)
         ENDIF
C        THE PRESSURE ALTITUDE HAS BEEN CALCULATED, IN FEET.
C        NOW, SEND THE PRESSURE ALTITUDE, IN MODEL TABLE UNITS,
C        TO THE APPROPRIATE ARGUMENT NUMBER
         IF (YXME(5) .GT. 0.)THEN
            IF(HGT(2) .EQ. 'M')THEN
                ARG(YXME(5)) = ALTFT / 3.2808399
              ELSE
                ARG(YXME(5)) = ALTFT
            ENDIF
          ELSE
            ERFLAG = 'C'
            ERRMSG(NXTMSG) = 'INTERFACE FILE ERROR ON POPT(24)'
            NXTMSG = MIN(NXTMSG+1,20)
            TRNIN9 = 1
         ENDIF

C  TEMPERATURE STUFF
      IF (UNIT(1) .EQ. 0. .OR. UNIT(1) .EQ. 1.) THEN
             AAT = XMET(1)
         ELSEIF (UNIT(1) .EQ. 2. .OR. UNIT(1) .EQ. 3.) THEN
             AAT = XMET(1) + TISA(ALTFT)
        ELSE
              ERFLAG = 'B'
              ERRMSG(NXTMSG) =
     +         'INVALID INPUT TO  UNIT(001) - TEMP UNITS'
              NXTMSG = MIN(NXTMSG+1,20)
              TRNIN9 = 1
      ENDIF
      IF (YXME(1) .GT. 0. )THEN
          ARG(YXME(1)) = CF(1)*(AAT+40.)-40.
        ELSE
           ERFLAG = 'C'
           ERRMSG(NXTMSG) = 'INTERFACE FILE ERROR ON POPT(24)'
           NXTMSG = MIN(NXTMSG+1,20)
           TRNIN9 = 1
      ENDIF

C  ACTUAL TEMPERATURE STUFF
      IF (XMET(6) .GT. 8.E20) THEN
C         ACTUAL TEMP NOT SUPPLIED.  IT IS REQUIRED WHEN POPT(1)=9.
C         SINCE POPT(1)=9 IS USED WHEN POPT(1)=4, IT IS NEEDED THEN TOO.
          ARG(153) = 0.
          ERFLAG = 'B'
          ERRMSG(NXTMSG) =
     +    'INPUT REQUIRED TO XMET(6) - ACTUAL TEMPERATURE'
          NXTMSG = MIN(NXTMSG+1,20)
          TRNIN9 = 1
        ELSE
C         ACTUAL TEMP IS SUPPLED
          ARG(153) = 1.
C         MAKE SURE MODULE SUPPORTS IT
          IF (YXME(6) .LT. 0.) THEN
             ERFLAG = 'B'
             ERRMSG(NXTMSG)(1:31)  = 'MODULE DOES NOT SUPPORT ACTUAL '
             ERRMSG(NXTMSG)(32:60) = 'TEMPERATURE INPUT TO XMET(6)'
             NXTMSG = MIN(NXTMSG+1,20)
             TRNIN9 = 1
            ELSE
C                SET THE ACTUAL OAT
                 IF (UNIT(1) .EQ. 0. .OR. UNIT(1) .EQ. 1.) THEN
                   AOAT = XMET(6)
                  ELSEIF (UNIT(1) .EQ. 2. .OR. UNIT(1) .EQ. 3.) THEN
                   AOAT = XMET(6) + TISA(ALTFT)
                  ELSE
                   ERFLAG = 'B'
                   ERRMSG(NXTMSG) =
     +             'INVALID INPUT TO  UNIT(001) - TEMP UNITS'
                   NXTMSG = MIN(NXTMSG+1,20)
                   TRNIN9 = 1
                 ENDIF
                 IF (YXME(6) .GT. 0. )THEN
                   ARG(YXME(6)) = CF(1)*(AOAT+40.)-40.
                  ELSE
                   ERFLAG = 'C'
                   ERRMSG(NXTMSG) = 'INTERFACE FILE ERROR ON XMET(6)'
                   NXTMSG = MIN(NXTMSG+1,20)
                   TRNIN9 = 1
                 ENDIF
          ENDIF
      ENDIF

C  ELEVATION IS NEEDED FOR STANDARD DAY CALC, MAKE SURE ONE WAS GIVEN
      IF (RWYD(1) .EQ. 9.E20) THEN
         ERFLAG = 'C'
         ERRMSG(NXTMSG)=
     +   'INPUT REQUIRED TO RWYD(001) - AIRPORT ELEVATION'
         NXTMSG = MIN(NXTMSG+1,20)
         TRNIN9 = 1
      ENDIF

C  NOW THAT WE HAVE THE OAT, WE CAN SET CF(41)
C  SET CF(41) = PRESSURE ALT INCREMENT / GROSS HEIGHT
C             = ABSOLUTE STANDARD DAY TEMP / ABSOLUTE OAT
C    SET ACTUAL TEMP IN MODEL TABLE UNITS
      ATEMP = ARG(YXME(1))
C    SET STANDARD DAY TEMP IN I/O UNITS, THEN CONVERT TO MODEL TABLE UNITS
      STEMP = TISA(ALTFT)
      STEMP = CF(1) * (STEMP+40.) - 40.
C    CONVERT TEMPS TO ABSOLUTE TEMP SCALE
      IF(OAT(2) .EQ. 'C')THEN
          STEMP = STEMP + 273.15
          ATEMP = ATEMP + 273.15
        ELSEIF (OAT(2) .EQ. 'F') THEN
          STEMP = STEMP + 459.67
          ATEMP = ATEMP + 459.67
      ENDIF
      CF(41) = STEMP / ATEMP

C  CHECK FOR SECOND TO CARD OVERIDES
      DO 300 I = 1,22
        IF(ORD(1,I).EQ.1.)THEN
            ARG(ARGPOS(I))=ORD(2,I)
            WRITE(ERRMSG(NXTMSG),1000)ARGPOS(I),ORD(2,I)
1000        FORMAT('ARG(',I3.3,') OVERRIDDEN WITH ',1P,G14.6)
            NXTMSG = MIN(NXTMSG+1,20)
        ENDIF
300   CONTINUE

      RETURN
      END
C**********************************************************************
      INTEGER FUNCTION TRNOUT()

C  TRNOUT      TRANSLATES OPTRAN ARG OUTPUTS INTO IATA
C              ARRAY OUTPUTS IN I/O UNITS

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

C     File:  Param4.fi   6 Nov 1996
C     THESE PARAMETERS DEFINE THE SIZE OF EACH OF THE SCAP ARRAYS
      PARAMETER (LLPOPT=200, LLCONF=200, LLXMET=200, LLRWYD=200,
     +           LLOBSD=200, LLFPTD=200, LLUNIT=200, LLSPIA=200,
     +           LLSPIB=200, LLSPIC=200)

      PARAMETER (LLCLIM=200, LLRWYS=200, LLFIRS=200, LLSECS=200,
     +           LLACCS=200, LLFINS=200, LLOBSL=200, LLTRND=200,
     +           LLSPOU=200)

C-------------------------------------------------------------------
C     File WhatStr.fi   10-April-2003
C     These variables hold "what" strings for the various products
C     WHATVA is for STAS
C     WHATVB is for BTOPS
C     WHATVC is for MTOPS
C     WHATVD is for BLAST
C     WHATVE is for MLAS
      CHARACTER*60 WHATVA,WHATVB,WHATVC,WHATVD,WHATVE,WHATVF
      COMMON /WHATUP/WHATVA,WHATVB,WHATVC,WHATVD,WHATVE,WHATVF
C-------------------------------------------------------------------

      COMMON /MFRORD/ORD(2,22),OMARK7(8)

      INTEGER   XCLI(LLCLIM),XRWY(LLRWYS),XFIR(LLFIRS),
     +          XSEC(LLSECS),XACC(LLACCS),XFIN(LLFINS),
     +          XOBS(LLOBSL),XTRN(LLTRND),XSPO(LLSPOU)
      REAL      LITEST,LITCOD

C  THESE VARIABLES DEFINE WHICH CONVERSION FACTOR TO USE
C  WITH WHICH OUTPUT VARIABLE
      SAVE XCLI,XRWY,XFIR,XSEC,XACC,XFIN,XOBS,XTRN

      DATA XCLI / 8,40,40,40,9,9,9,40,40,3,3,3,9,40,40,3,3,3,9,
     +  40,40,3,3,3,3,3,40,40,40,40,9,9,9,40,
     +  40,40,40,40,40,40,40,40,40,40,1,1,40,153*40 /
      DATA XRWY / 8,8,8,9,8,8,40,40,40,40,40,40,40,40,40,40,40,183*40 /
      DATA XFIR / 8,3,4,4,40,40,40,40,40,40,40,40,40,40,186*40 /
      DATA XSEC / 8,40,40,3,3,4,4,4,3,40,40,40,40,40,40,40,40,40,40,
     + 40,180*40 /
      DATA XACC / 4,4,4,3,3,4,4,4,3,3,40,40,40,40,40,40,40,40,40,
     + 40,180*40 /
      DATA XFIN / 8,40,40,3,4,4,4,3,4,4,4,40,40,40,40,40,40,
     + 40,40,40,40,179*40/
      DATA XOBS / 8,40,8,40,8,40,40,40,40,40,40,40,40,40,40,40,184*40 /
      DATA XTRN / 40,4,3,3,40,4,3,3,40,40,40,40,40,40,40,40,40,
     + 40,182*40 /
      DATA XSPO /5*9,8,9,9,9,3,3,3,9,3,3,3,9,5*3,9,177*40 /

C     IDENTIFY BTOPS CODE
      MMIDNT = ' '
      I1 = INDEX(WHATVB,'BTOPS')
      I2 = INDEX(WHATVB,'dated') - 2
      IF (I1.GE.1  .AND.
     +    I1.LE.I2 .AND.
     +    I2-I1+1.LE.LEN(MMIDNT)) THEN
             MMIDNT = WHATVB(I1:I2)
      ENDIF
C     MMDATE = '03 February 2003'
      MMDATE = ' '
      I1 = INDEX(WHATVB,'dated') + 6
      I2 = INDEX(WHATVB,'>') - 1
      IF (I1.GE.1  .AND.
     +    I1.LE.I2 .AND.
     +    I2-I1+1.LE.LEN(MMDATE)) THEN
             MMDATE = WHATVB(I1:I2)
      ENDIF

C     IDENTIFY DATABASE
      ACMDBO(1:6) = SERID
      ACMDBO(7:11) = ' REV '
      WRITE(ACMDBO(12:14),1000)RNUM
1000  FORMAT(I3.3)
      ACMDBO(15:15) = ' '
      ACMDBO(16:26) = RDAT
      ACMDBO(27:28) = ' '
      ACMDBO(29:31) = TNAME(1)
      ACMDBO(32:34) = TNAME(2)
      ACMDBO(35:37) = DESC(68)
      ACMDBO(38:39) = ' '
      ACMDBO(40:42) = DESC(64)
      ACMDBO(43:45) = DESC(65)
      ACMDBO(46:48) = DESC(66)
      ACMDBO(49:51) = DESC(67)
      ACMDBO(52:52) = ' '
      ACMDBO(53:56) = DECKD(1)
      ACMDBO(57:60) = DECKD(2)

C  CHECK FOR ERROR MESSAGES RETURNED BY OPTRAN
      IF (ARG(ERRARG) .LT. 0.) THEN
         CLIMIT(1) = ARG(15) * 100.
         J = NINT(CLIMIT(1))
         DO 90 I = 1,NMERR(CNTLST)
            IF (RETCOD(I) .EQ. J) THEN
               ERFLAG = ERRTYP(I)
               ERRMSG(NXTMSG) = RETTXT(I)
               NXTMSG = MIN (NXTMSG+1,20)
            ENDIF
90       CONTINUE
         TRNOUT = 0
         RETURN
      ENDIF

C  IF FIXED GROSS LEVEL OFF HEIGHT HAS BEEN SELECTED, CHECK THE FIXED
C  GROSS LEVEL OFF HEIGHT AGAINST THE MFRH TO MAKE SURE IT IS OKAY
      IF (POPT(18) .EQ. 1.) THEN
         IF (ZACC(2) .GT. 0) THEN
C             DELTA = ABS(MFRH-FLOH) IN MODEL TABLE UNIT IE FEET
C             IF DELTA ISNT WITHIN 5 FEET ERROR OUT
              IF (POPT(50) .EQ. 1.) THEN
                 DELTA = ABS(ARG(ZACC(2)) - POPT(19)*CF(4)/CF(41))
               ELSE
                 DELTA = ABS(ARG(ZACC(2)) - POPT(19)*CF(4))
              ENDIF
              IF (DELTA .GT. 5.) THEN
                  ERFLAG = 'B'
                  ERRMSG(NXTMSG) =
     +            'FIXED LEVEL-OFF HEIGHT TOO LOW FOR THIS RUNWAY'
                  NXTMSG = MIN (NXTMSG+1,20)
                  TRNOUT = 0
                  RETURN
              ENDIF
            ELSE
              ERFLAG = 'C'
              ERRMSG(NXTMSG) = 'ERROR IN SIF - ACCSEG(2)'
              NXTMSG = MIN (NXTMSG+1,20)
              TRNOUT = 0
              RETURN
         ENDIF
      ENDIF

C  WHILE TRANSLATING OUTPUTS, CHECK FOR NON-LIMITING WEIGHTS
C  SETTING TO 9999999 AS NECESSARY

      DO 100 I = 1,LLCLIM
      IF (ZCLI(I) .GT. 0) THEN
C        OPTRAN DOES PROVIDE NUMBER
         IF (XCLI(I).EQ.8 .AND. ARG(ZCLI(I)).EQ.NONLIM(CNTLST))THEN
C             OUTPUT IS NON LIMITING WEIGHT
              CLIMIT(I) = 9999999.
            ELSE
C             OUTPUT IS EITHER A LIMITING WEIGHT OR
C             SOMETHING OTHER THAN A WEIGHT
              CLIMIT(I) = ARG(ZCLI(I)) / CF(XCLI(I))
         ENDIF
      ENDIF
100   CONTINUE

C     OUTPUT TEMPERATURES DO NOT USE STRAIGHT CONVERSION FACTORS.
      IF(ZCLI(45) .GT. 0)THEN
         CLIMIT(45) = (ARG(ZCLI(45))+40.)/CF(1)-40.
      ENDIF
      IF(ZCLI(46) .GT. 0)THEN
         CLIMIT(46) = (ARG(ZCLI(46))+40.)/CF(1)-40.
      ENDIF

C     Output temperature for 25% reduced thrust
C     and break temperatures use whole numbers.
C     The 25% reduced thrust point is truncated down.
C     The break temperature uses the next higher whole number.
      IF (CLIMIT(45) .LT. 9.E6) THEN
          CLIMIT(45)  = FLOAT(INT(CLIMIT(45)))
      ENDIF
      IF (AINT(CLIMIT(46)) .NE. CLIMIT(46)) THEN
C        It wasn't a whole number already.
C        Make it the next higher whole number.
         CLIMIT(46)    = AINT(CLIMIT(46)) + 1.00
      ENDIF

      DO 110 I = 1,LLRWYS
      IF (ZRWY(I) .GT. 0) THEN
C        OPTRAN DOES PROVIDE NUMBER
         IF (XRWY(I).EQ.8 .AND. ARG(ZRWY(I)).EQ.NONLIM(CNTLST))THEN
C             OUTPUT IS NON LIMITING WEIGHT
              RWYSEG(I) = 9999999.
            ELSE
C             OUTPUT IS EITHER A LIMITING WEIGHT OR
C             SOMETHING OTHER THAN A WEIGHT
              RWYSEG(I) = ARG(ZRWY(I)) / CF(XRWY(I))
         ENDIF
      ENDIF
110   CONTINUE


      DO 120 I = 1,LLFIRS
      IF (ZFIR(I) .GT. 0) THEN
C        OPTRAN DOES PROVIDE NUMBER
         IF (XFIR(I).EQ.8 .AND. ARG(ZFIR(I)).EQ.NONLIM(CNTLST))THEN
C             OUTPUT IS NON LIMITING WEIGHT
              FIRSEG(I) = 9999999.
            ELSE
C             OUTPUT IS EITHER A LIMITING WEIGHT OR
C             SOMETHING OTHER THAN A WEIGHT
              FIRSEG(I) = ARG(ZFIR(I)) / CF(XFIR(I))
         ENDIF
      ENDIF
120   CONTINUE


      DO 130 I = 1,LLSECS
      IF (ZSEC(I) .GT. 0) THEN
C        OPTRAN DOES PROVIDE NUMBER
         IF (XSEC(I).EQ.8 .AND. ARG(ZSEC(I)).EQ.NONLIM(CNTLST))THEN
C             OUTPUT IS NON LIMITING WEIGHT
              SECSEG(I) = 9999999.
            ELSE
C             OUTPUT IS EITHER A LIMITING WEIGHT OR
C             SOMETHING OTHER THAN A WEIGHT
              SECSEG(I) = ARG(ZSEC(I)) / CF(XSEC(I))
         ENDIF
      ENDIF
130   CONTINUE


      DO 140 I = 1,LLACCS
      IF (ZACC(I) .GT. 0) THEN
C        OPTRAN DOES PROVIDE NUMBER
         IF (XACC(I).EQ.8 .AND. ARG(ZACC(I)).EQ.NONLIM(CNTLST))THEN
C             OUTPUT IS NON LIMITING WEIGHT
              ACCSEG(I) = 9999999.
            ELSE
C             OUTPUT IS EITHER A LIMITING WEIGHT OR
C             SOMETHING OTHER THAN A WEIGHT
              ACCSEG(I) = ARG(ZACC(I)) / CF(XACC(I))
         ENDIF
      ENDIF
140   CONTINUE


      DO 150 I = 1,LLFINS
      IF (ZFIN(I) .GT. 0) THEN
C        OPTRAN DOES PROVIDE NUMBER
         IF (XFIN(I).EQ.8 .AND. ARG(ZFIN(I)).EQ.NONLIM(CNTLST))THEN
C             OUTPUT IS NON LIMITING WEIGHT
              FINSEG(I) = 9999999.
            ELSE
C             OUTPUT IS EITHER A LIMITING WEIGHT OR
C             SOMETHING OTHER THAN A WEIGHT
              FINSEG(I) = ARG(ZFIN(I)) / CF(XFIN(I))
         ENDIF
      ENDIF
150   CONTINUE


      DO 160 I = 1,LLOBSL
      IF (ZOBS(I) .GT. 0) THEN
C        OPTRAN DOES PROVIDE NUMBER
         IF (XOBS(I).EQ.8 .AND. ARG(ZOBS(I)).EQ.NONLIM(CNTLST))THEN
C             OUTPUT IS NON LIMITING WEIGHT
              OBSLIM(I) = 9999999.
            ELSE
C             OUTPUT IS EITHER A LIMITING WEIGHT OR
C             SOMETHING OTHER THAN A WEIGHT
              OBSLIM(I) = ARG(ZOBS(I)) / CF(XOBS(I))
         ENDIF
      ENDIF
160   CONTINUE


      DO 170 I = 1,LLTRND
      IF (ZTRN(I) .GT. 0) THEN
C        OPTRAN DOES PROVIDE NUMBER
         IF (XTRN(I).EQ.8 .AND. ARG(ZTRN(I)).EQ.NONLIM(CNTLST))THEN
C             OUTPUT IS NON LIMITING WEIGHT
              TRNDAT(I) = 9999999.
            ELSE
C             OUTPUT IS EITHER A LIMITING WEIGHT OR
C             SOMETHING OTHER THAN A WEIGHT
              TRNDAT(I) = ARG(ZTRN(I)) / CF(XTRN(I))
         ENDIF
      ENDIF
170   CONTINUE

      DO 175 I = 1,LLSPOU
       IF (ZSPO(I) .GT. 0) THEN
          SPOUTA(I) = ARG(ZSPO(I)) / CF(XSPO(I))
       ENDIF
175   CONTINUE

C  SPECIAL HANDLING IS REQUIRED FOR THE MAXIMUM RUNWAY LIMITED WEIGHT.
C  THREE USES FOR ARG(9) AND ARG(10) EXIST FOR OLD MODEL TABLES.
C  I) ARG(9) = FIELD LENGTH LIMIT,  ARG(10) = NOT USED
C  II) ARG(9) = ONE ENGINE OUT FIELD LIMIT,  ARG(10) = A/E FIELD LIMIT
C  III) ARG(9) = FIELD LIMIT,  ARG(10) = MIN CONTROL SPEED LIMIT
C  IN CASES II AND III, WE WANT RWYSEG(6) = MIN OF ARG(9) AND ARG(10)
C  IN CASE I WE WANT RWYSEG(6) = ARG(9)
C  IN FUTURE WE WANT FLEXIBILITY.  SO, THIS CODE DOES THE TRICK.
      IF (ZRWY(6) .EQ. 0) THEN
          FL = MIN(ARG(9),ARG(10))
        ELSEIF (ZRWY(6) .GT. 0) THEN
          FL = ARG(ZRWY(6))
        ELSE
          FL = 0.
      ENDIF
      IF (FL .EQ. NONLIM(CNTLST) .AND. ZRWY(6) .GE. 0) THEN
          RWYSEG(6) = 9999999.
        ELSEIF (ZRWY(6) .GE. 0) THEN
          RWYSEG(6) = FL / CF(XRWY(6))
      ENDIF

C  IF OPTRAN ARGUMENTS ARE PROVIDED FOR THE OBSTACLE WEIGHT
C  POSITIONS, THEY ARE ALREADY FILLED.  IF THE SIF HAS ZEROS
C  FOR THE OBS WT POSITIONS, FILL WITH EITHER ARG14 OR ARG38
C  DEPENDING ON CLIMIT(4).
      IF (ZOBS(1).EQ.0) THEN
C        USE DEFAULT ARGUMENTS FOR OBSTACLE WEIGHT
                    IF ((CLIMIT(4).GT.0. .AND. CLIMIT(4).LT.80.) .OR.
     +                (CLIMIT(4).GT.100. .AND. CLIMIT(4).LT.180.)) THEN
C                       IMPROVED CLIMB IS BEING USED
                        IF (ARG(38) .NE. NONLIM(CNTLST)) THEN
                           OBSLIM(1) = ARG(38)/CF(8)
                           OBSLIM(3) = ARG(38)/CF(8)
                           OBSLIM(5) = ARG(38)/CF(8)
                          ELSE
                           OBSLIM(1) = 9999999.
                           OBSLIM(3) = 9999999.
                           OBSLIM(5) = 9999999.
                        ENDIF
                      ELSE
C                       IMPROVED CLIMB IS NOT BEING USED
                        IF (ARG(14) .NE. NONLIM(CNTLST)) THEN
                           OBSLIM(1) = ARG(14)/CF(8)
                           OBSLIM(3) = ARG(14)/CF(8)
                           OBSLIM(5) = ARG(14)/CF(8)
                          ELSE
                           OBSLIM(1) = 9999999.
                           OBSLIM(3) = 9999999.
                           OBSLIM(5) = 9999999.
                        ENDIF
                    ENDIF
      ENDIF
C
C - Code to address OPT Obstacle Limit Weight = 9999999 issue
C - Un-commented - JNM 4/8/15
C
      IF (OBSLIM(1) .GE. 2222222. .AND. OBSLIM(2) .GE. 2222222.
     +                            .AND. OBSLIM(3) .GE. 2222222.) THEN
        IF (RWYSEG(6) .LT. 2222222.) THEN
            OBSLIM(1) = RWYSEG(6)
            OBSLIM(3) = RWYSEG(6)
            OBSLIM(5) = RWYSEG(6)
        ENDIF
      ENDIF

C  LIMITING OBSTACLE NUMBER
      IF (OBSD(1) .EQ. 0.) THEN
C          NO OBSTACLES
           OBSLIM(2) = 9.E20
           OBSLIM(4) = 9.E20
           OBSLIM(6) = 9.E20
        ELSE
               IF (ZOBS(6) .GT. 0) THEN
C                   OPTRAN ARG WAS SPECIFIED FOR LIMITING OBS NUMBER.
C                   USE IT FOR ALL THREE.
                    OBSLIM(2) = ARG(ZOBS(6))
                    OBSLIM(4) = ARG(ZOBS(6))
                    OBSLIM(6) = ARG(ZOBS(6))
                  ELSE
                    IF ((CLIMIT(4).GT.0. .AND. CLIMIT(4).LT.80.) .OR.
     +                (CLIMIT(4).GT.100. .AND. CLIMIT(4).LT.180.)) THEN
C                       IMPROVED CLIMB IS BEING USED
                        IF (ICRIT(2) .GT. 0) THEN
                           OBSLIM(2) = ICRIT(2)
                           OBSLIM(4) = ICRIT(2)
                           OBSLIM(6) = ICRIT(2)
                          ELSE
                           OBSLIM(2) = 9.E20
                           OBSLIM(4) = 9.E20
                           OBSLIM(6) = 9.E20
                        ENDIF
                      ELSE
C                       IMPROVED CLIMB IS NOT BEING USED
                        IF (ICRIT(1) .GT. 0) THEN
                           OBSLIM(2) = ICRIT(1)
                           OBSLIM(4) = ICRIT(1)
                           OBSLIM(6) = ICRIT(1)
                          ELSE
                           OBSLIM(2) = 9.E20
                           OBSLIM(4) = 9.E20
                           OBSLIM(6) = 9.E20
                        ENDIF
                    ENDIF
               ENDIF
C
C              SET ADJ1=TODA ADJUSTMENT.  IT IS NEEDED FOR SORTING
C              OUT THE LIMITING OBSTACLE NUMBER.
               IF (POPT(12).EQ.9.E20) THEN
                     ADJ1 = 0.
                  ELSE
                     ADJ1 = POPT(12)
               ENDIF
C
C              THEY HAVE BEEN SORTED IN XX.  FIND WHICH ONE WAS
C              LIMITING IN INPUT NUMBER.
               IF (OBSLIM(2) .GE. 0.  .AND. OBSLIM(2) .LE. 20. ) THEN
                    ICRTN = NINT(OBSLIM(2))
                  ELSE
                    ICRTN = 0
               ENDIF
               IF (ICRTN .NE. 0) THEN
                   DO 180 I = 1,NINT(OBSD(1)),1
                      IF(OBSD(2).EQ.1.)THEN
                        IF ( ABS( OBSD(I*3)*CF(3)-XX(ICRTN*2,1) )
     +                        .LT. 0.1) OBSLIM(2)=I
                       ELSE
                        IF ( ABS( (OBSD(I*3)-ADJ1)*CF(3)-XX(ICRTN*2,1) )
     +                        .LT. 0.1) OBSLIM(2)=I
                      ENDIF
180                CONTINUE
               ENDIF
      ENDIF
      OBSLIM(4) = OBSLIM(2)
      OBSLIM(6) = OBSLIM(2)


C  DO PRESSURE ALT CONVERSIONS WHERE GROSS HEIGHTS ARE AVAILABLE
      IF(ZSEC(7) .GT. 0)THEN
         SECSEG(8) = SECSEG(7) * CF(41)
      ENDIF
      IF(ZACC(2) .GT. 0)THEN
         ACCSEG(3) = ACCSEG(2) * CF(41)
      ENDIF
      IF(ZACC(7) .GT. 0)THEN
         ACCSEG(8) = ACCSEG(7) * CF(41)
      ENDIF
      IF(ZACC(16) .GT. 0)THEN
         ACCSEG(17) = ACCSEG(16) * CF(41)
      ENDIF
      IF(ZACC(19) .GT. 0)THEN
         ACCSEG(200) = ACCSEG(19) * CF(41)
      ENDIF
      IF(ZFIN(6) .GT. 0)THEN
         FINSEG(7) = FINSEG(6) * CF(41)
      ENDIF
      IF(ZFIN(10) .GT. 0)THEN
         FINSEG(11) = FINSEG(10) * CF(41)
      ENDIF

      CLIMIT(3) = REAL(FLAPS(CNTLST))

C     If model tables support range of V1 computations,
C     and that capability is being used,
C     check for some unusual V1/VR convergence situations.
      IF (
     +     (ZCLI(35).NE.ZCLI(36)) .AND.
     +     (ZCLI(35).GE.1 .AND. ZCLI(35).LE.999) .AND.
     +     (ZCLI(36).GE.1 .AND. ZCLI(36).LE.999) .AND.
     +     (ZCLI(37).GE.1 .AND. ZCLI(37).LE.999) .AND.
     +     (POPT(1).EQ.0. .OR. POPT(1).EQ.1. .OR. POPT(1).EQ.4.)
     +   ) THEN
C     Decisions are based on V1/VR ratios.
C     Make sure we have numbers that look like V1/VR ratios
C     before using them to make decisions.
      IF (
     +     (ARG(ZCLI(35)).GT.0.4 .AND. ARG(ZCLI(35)).LT.1.2) .AND.
     +     (ARG(ZCLI(36)).GT.0.4 .AND. ARG(ZCLI(36)).LT.1.2) .AND.
     +     (ARG(ZCLI(37)).GT.0.4 .AND. ARG(ZCLI(37)).LT.1.2)
     +   ) THEN
C        CHECK FOR MIN GT MAX.  IF VERY CLOSE, ADJUST.
C        OTHERWISE 9.E20 DISTANCES.
         IF (ARG(ZCLI(35)).GT.ARG(ZCLI(36)))THEN
            IF (ARG(ZCLI(35))-ARG(ZCLI(36)) .LE. 0.001) THEN
                  CLIMIT(7)  = CLIMIT(13)
                  CLIMIT(10) = CLIMIT(16)
                  CLIMIT(11) = CLIMIT(17)
                  CLIMIT(12) = CLIMIT(18)
                  CLIMIT(35) = CLIMIT(36)
                  RWYSEG(1)  = RWYSEG(2)
                ELSE
                  CLIMIT(10) = 9.E20
                  CLIMIT(11) = 9.E20
                  CLIMIT(12) = 9.E20
                  CLIMIT(16) = 9.E20
                  CLIMIT(17) = 9.E20
                  CLIMIT(18) = 9.E20
                  CLIMIT(22) = 9.E20
                  CLIMIT(23) = 9.E20
                  CLIMIT(24) = 9.E20
            ENDIF
         ENDIF
C        CHECK FOR BAL ABOVE MAX.  IF VERY CLOSE, ADJUST, OTHERWISE 9E20.
         IF (ARG(ZCLI(37)) .GT. ARG(ZCLI(36))) THEN
            IF (ARG(ZCLI(37))-ARG(ZCLI(36)) .LE. 0.001) THEN
                  CLIMIT(19) = CLIMIT(13)
                  CLIMIT(22) = CLIMIT(16)
                  CLIMIT(23) = CLIMIT(17)
                  CLIMIT(24) = CLIMIT(18)
                  CLIMIT(37) = CLIMIT(36)
                  RWYSEG(3)  = RWYSEG(2)
                ELSE
                  CLIMIT(19) = 9.E20
                  CLIMIT(22) = 9.E20
                  CLIMIT(23) = 9.E20
                  CLIMIT(24) = 9.E20
                  CLIMIT(37) = 9.E20
                  RWYSEG(3)  = 9.E20
            ENDIF
         ENDIF
C        CHECK FOR BAL BELOW MIN.  IF VERY CLOSE, ADJUST, OTHERWISE 9E20.
         IF (ARG(ZCLI(37)) .LT. ARG(ZCLI(35))) THEN
            IF (ARG(ZCLI(35))-ARG(ZCLI(37)) .LE. 0.001) THEN
                  CLIMIT(19) = CLIMIT(7)
                  CLIMIT(22) = CLIMIT(10)
                  CLIMIT(23) = CLIMIT(11)
                  CLIMIT(24) = CLIMIT(12)
                  CLIMIT(37) = CLIMIT(35)
                  RWYSEG(3)  = RWYSEG(1)
                ELSE
                  CLIMIT(19) = 9.E20
                  CLIMIT(22) = 9.E20
                  CLIMIT(23) = 9.E20
                  CLIMIT(24) = 9.E20
                  CLIMIT(37) = 9.E20
                  RWYSEG(3)  = 9.E20
            ENDIF
         ENDIF
      ENDIF
      ENDIF

C  FIGURE OUT THE MARK7T TYPE LIMIT CODE
      LITEST =
     +  MIN(ARG(8),ARG(9),ARG(10),ARG(11),ARG(12),ARG(13),ARG(14))
      IF (LITEST .EQ. ARG(10)) THEN
C          VMCG
           LITCOD = 9.
         ELSEIF (LITEST .EQ. ARG(12)) THEN
C          BRAKE ENERGY
           LITCOD = 12.
         ELSEIF (LITEST .EQ. ARG(8)) THEN
C          STRUCTURAL
           LITCOD = 1.
         ELSEIF (LITEST .EQ. ARG(9)) THEN
C          FIELD LENGTH
           LITCOD = 25.
         ELSEIF (LITEST .EQ. ARG(11)) THEN
C          TAKEOFF CLIMB
           LITCOD = 15.
         ELSEIF (LITEST .EQ. ARG(13)) THEN
C          TIRE SPEED
           LITCOD = 10.
         ELSEIF (LITEST .EQ. ARG(14)) THEN
C          OBSTACLE CLEARANCE WEIGHT IS LOWEST.  EITHER OBS OR LOH LIMITED.
C          IF MAX LOH AND MFRH ARE SUPPORTED FOR EXTENDED OUTPUT AND
C          EXTENDED OUTPUT IS SELECTED , WE CAN DISTINGUISH
C          BETWEEN THE TWO.  OTHERWISE, JUST CALL IT OBSTACLE LIMITED.
           IF (ZACC(2).GT.0 .AND. ZACC(7).GT.0 .AND.
     +         (POPT(1).EQ.0. .OR. POPT(1).EQ.1.)) THEN
                  IF (ACCSEG(2) .GE. 0.997*ACCSEG(7)) THEN
                       LITCOD = 17.
                     ELSE
                       LITCOD = 19.
                  ENDIF
              ELSE
                   LITCOD = 19.
           ENDIF
         ELSE
           LITCOD = 9.E20
      ENDIF
C  IF OTHER LIMIT CODES ARENT PROVIDED BY OPTRAN, USE THE MARK7T TYPE CODE
      IF (ZCLI(8).LE.0 .AND. ZCLI(14).LE.0 .AND.ZCLI(20).LE.0) THEN
         CLIMIT(8)  = LITCOD
         CLIMIT(14) = LITCOD
         CLIMIT(20) = LITCOD
      ENDIF

C  MARK7 MAX TAKEOFF WEIGHTS AND SPEEDS
      IF (ARG(15) .GT. 0.)THEN
          OMARK7(1) = ARG(15)/CF(8)
          OMARK7(2) = ARG(16)/CF(9)
          OMARK7(3) = ARG(17)/CF(9)
          OMARK7(4) = ARG(18)/CF(9)
          OMARK7(5) = ARG(41)/CF(8)
          OMARK7(6) = ARG(42)/CF(9)
          OMARK7(7) = ARG(43)/CF(9)
          OMARK7(8) = ARG(44)/CF(9)
      ENDIF

C---
C     If this case uses improved climb speed increase and
C     these model tables do not adjust the individual field,
C     climb, and tire speed limited gross weights,
C     throw away the field, climb, and tire speed limits
C     to avoid mis-interpretation.
      IF ((CLIMIT(4).GT.0. .AND. CLIMIT(4).LT.80.) .OR.
     +    (CLIMIT(4).GT.100. .AND. CLIMIT(4).LT.180.)) THEN
C       Improved climb speed increase is being used.
        IF (YPOP(8) .LE. 0) THEN
C          Fixed improved climb is not supported.
C          So, no updates were done to field, climb and
C          tire speed limits to adjust for the improved
C          climb speed increase.  Consequently, they
C          should be thrown out to avoid confusion.
              RWYSEG(5) = 9.E20
              RWYSEG(6) = 9.E20
              SECSEG(1) = 9.E20
        ENDIF
      ENDIF
C---

C  CHECK FOR OUTPUT NOT SET BY CHECKING FOR ZEROS.  SET TO 9.E20.
C  SKIP ARRAY POSITIONS WHICH HAVE ZERO AS A VALID OUTPUT VALUE.
      DO 195 I = 1,3
         IF (CLIMIT(I) .EQ. 0.) THEN
             CLIMIT(I) = 9.E20
         ENDIF
195   CONTINUE
      DO 200 I = 5,33
         IF (CLIMIT(I) .EQ. 0.) THEN
             CLIMIT(I) = 9.E20
         ENDIF
200   CONTINUE
      DO 205 I = 35,LLCLIM
         IF (CLIMIT(I) .EQ. 0.) THEN
             CLIMIT(I) = 9.E20
         ENDIF
205   CONTINUE
      DO 210 I = 1,LLRWYS
         IF (RWYSEG(I) .EQ. 0.) THEN
             RWYSEG(I) = 9.E20
         ENDIF
210   CONTINUE
      DO 215 I = 1,LLFIRS
         IF (FIRSEG(I) .EQ. 0.) THEN
             FIRSEG(I) = 9.E20
         ENDIF
215   CONTINUE
      DO 220 I = 1,LLSECS
         IF (SECSEG(I) .EQ. 0.) THEN
             SECSEG(I) = 9.E20
         ENDIF
220   CONTINUE
      DO 225 I = 1,LLACCS
         IF (ACCSEG(I) .EQ. 0.) THEN
             ACCSEG(I) = 9.E20
         ENDIF
225   CONTINUE
      DO 230 I = 1,LLFINS
         IF (FINSEG(I) .EQ. 0.) THEN
             FINSEG(I) = 9.E20
         ENDIF
230   CONTINUE
      DO 235 I = 1,LLOBSL
         IF (OBSLIM(I) .EQ. 0.) THEN
             OBSLIM(I) = 9.E20
         ENDIF
235   CONTINUE
      DO 240 I = 2,LLTRND
         IF (TRNDAT(I) .EQ. 0.) THEN
             TRNDAT(I) = 9.E20
         ENDIF
240   CONTINUE

C  TAKEOFF POWER SETTING FLAG
      IF ( CLIMIT(27) .GT. 10.00 ) THEN
        IF (PWR .EQ. 'EPR') THEN
            CLIMIT(27) = 0.
        ELSEIF (PWR .EQ. 'N1 ')THEN
            CLIMIT(27) = 1.
        ELSE
            CLIMIT(27) = 9.E20
        ENDIF
      END IF

C   CLIMIT(27) MAY NEED TO BE CHANGED IF ALTERNATE POWER SETTING IS CHOSEN.
C      IF ( CLIMIT(28) .GT. 20.00    .AND.
C     +     CLIMIT(27) .EQ. 0.00 ) THEN
C           CLIMIT(27) = 1.0
C      ELSE IF ( CLIMIT(28) .LT. 10.00  .AND.
C     +          CLIMIT(27) .EQ. 1.00 ) THEN
C           CLIMIT(27) = 0.0
C      END IF

C  Adjust takeoff distances and accelerate-stop distances for alignment.
      IF(POPT(38).EQ.1.) THEN
C          Adjust the distances.
           IF (POPT(12) .GT. 0.   .AND.
     +         POPT(12) .LT. 9.E20      )THEN
C              Alignment Allowance for TOD and TOR supplied.
               TTORA = RWYD(3)
               IF(RWYD(2) .EQ. 0.) THEN
                   TTORA = RWYD(3)
                   TTODA = RWYD(5)
                   TASDA = RWYD(4)
                 ELSE
                   TTORA = RWYD(3)
                   TTODA = RWYD(3) + RWYD(5)
                   TASDA = RWYD(3) + RWYD(4)
               ENDIF
               TOL = 3.E-4
               IF (CLIMIT(10) .GT. 0.    .AND.
     +             CLIMIT(10) .LT. 9.E20) THEN
                      CLIMIT(10) = CLIMIT(10) + POPT(12)
                      IF (TSTEQZ(CLIMIT(10),TTORA).LT.TOL) THEN
                         CLIMIT(10) = TTORA
                      ENDIF
               ENDIF
               IF (CLIMIT(16) .GT. 0.    .AND.
     +             CLIMIT(16) .LT. 9.E20) THEN
                      CLIMIT(16) = CLIMIT(16) + POPT(12)
                      IF (TSTEQZ(CLIMIT(16),TTORA).LT.TOL) THEN
                         CLIMIT(16) = TTORA
                      ENDIF
               ENDIF
               IF (CLIMIT(22) .GT. 0.    .AND.
     +             CLIMIT(22) .LT. 9.E20) THEN
                      CLIMIT(22) = CLIMIT(22) + POPT(12)
                      IF (TSTEQZ(CLIMIT(22),TTORA).LT.TOL) THEN
                         CLIMIT(22) = TTORA
                      ENDIF
               ENDIF
               IF (CLIMIT(25) .GT. 0.    .AND.
     +             CLIMIT(25) .LT. 9.E20) THEN
                      CLIMIT(25) = CLIMIT(25) + POPT(12)
                      IF (TSTEQZ(CLIMIT(25),TTORA).LT.TOL) THEN
                         CLIMIT(25) = TTORA
                      ENDIF
               ENDIF
               IF (CLIMIT(11) .GT. 0.    .AND.
     +             CLIMIT(11) .LT. 9.E20) THEN
                      CLIMIT(11) = CLIMIT(11) + POPT(12)
                      IF (TSTEQZ(CLIMIT(11),TTODA).LT.TOL) THEN
                         CLIMIT(11) = TTODA
                      ENDIF
               ENDIF
               IF (CLIMIT(17) .GT. 0.    .AND.
     +             CLIMIT(17) .LT. 9.E20) THEN
                      CLIMIT(17) = CLIMIT(17) + POPT(12)
                      IF (TSTEQZ(CLIMIT(17),TTODA).LT.TOL) THEN
                         CLIMIT(17) = TTODA
                      ENDIF
               ENDIF
               IF (CLIMIT(23) .GT. 0.    .AND.
     +             CLIMIT(23) .LT. 9.E20) THEN
                      CLIMIT(23) = CLIMIT(23) + POPT(12)
                      IF (TSTEQZ(CLIMIT(23),TTODA).LT.TOL) THEN
                         CLIMIT(23) = TTODA
                      ENDIF
               ENDIF
               IF (CLIMIT(26) .GT. 0.    .AND.
     +             CLIMIT(26) .LT. 9.E20) THEN
                      CLIMIT(26) = CLIMIT(26) + POPT(12)
                      IF (TSTEQZ(CLIMIT(26),TTODA).LT.TOL) THEN
                         CLIMIT(26) = TTODA
                      ENDIF
               ENDIF
           ENDIF
           IF (POPT(13) .GT. 0.   .AND.
     +         POPT(13) .LT. 9.E20      )THEN
C              Alignment Allowance for ASD supplied.
               IF (CLIMIT(12) .GT. 0.    .AND.
     +             CLIMIT(12) .LT. 9.E20) THEN
                      CLIMIT(12) = CLIMIT(12) + POPT(13)
                      IF (TSTEQZ(CLIMIT(12),TASDA).LT.TOL) THEN
                         CLIMIT(12) = TASDA
                      ENDIF
               ENDIF
               IF (CLIMIT(18) .GT. 0.    .AND.
     +             CLIMIT(18) .LT. 9.E20) THEN
                      CLIMIT(18) = CLIMIT(18) + POPT(13)
                      IF (TSTEQZ(CLIMIT(18),TASDA).LT.TOL) THEN
                         CLIMIT(18) = TASDA
                      ENDIF
               ENDIF
               IF (CLIMIT(24) .GT. 0.    .AND.
     +             CLIMIT(24) .LT. 9.E20) THEN
                      CLIMIT(24) = CLIMIT(24) + POPT(13)
                      IF (TSTEQZ(CLIMIT(24),TASDA).LT.TOL) THEN
                         CLIMIT(24) = TASDA
                      ENDIF
               ENDIF
           ENDIF
        ELSEIF (POPT(38).EQ.0. .OR. POPT(38).EQ.9.E20) THEN
C          Adjustment not desired.
           CONTINUE
        ELSE
C          Error
           ERFLAG = 'B'
           ERRMSG(NXTMSG) = 'INVALID INPUT TO POPT(38)'
           NXTMSG = MIN (NXTMSG+1,20)
      ENDIF

      RWYSEG(38) = ADJ1
      RWYSEG(39) = ADJ2

      TRNOUT = 0
      RETURN
      END
C*************************************************************
      INTEGER FUNCTION TRNOU9()

C  TRNOUT      TRANSLATES OPTRAN ARG OUTPUTS INTO IATA
C              ARRAY OUTPUTS IN I/O UNITS

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

C     File:  Param4.fi   6 Nov 1996
C     THESE PARAMETERS DEFINE THE SIZE OF EACH OF THE SCAP ARRAYS
      PARAMETER (LLPOPT=200, LLCONF=200, LLXMET=200, LLRWYD=200,
     +           LLOBSD=200, LLFPTD=200, LLUNIT=200, LLSPIA=200,
     +           LLSPIB=200, LLSPIC=200)

      PARAMETER (LLCLIM=200, LLRWYS=200, LLFIRS=200, LLSECS=200,
     +           LLACCS=200, LLFINS=200, LLOBSL=200, LLTRND=200,
     +           LLSPOU=200)

      COMMON /MFRORD/ORD(2,22),OMARK7(8)

      ACMDBO(1:6) = SERID
      ACMDBO(7:11) = ' REV '
      WRITE(ACMDBO(12:14),1000)RNUM
1000  FORMAT(I3.3)
      ACMDBO(15:15) = ' '
      ACMDBO(16:26) = RDAT
      ACMDBO(27:28) = ' '
      ACMDBO(29:31) = TNAME(1)
      ACMDBO(32:34) = TNAME(2)
      ACMDBO(35:37) = DESC(68)
      ACMDBO(38:39) = ' '
      ACMDBO(40:42) = DESC(64)
      ACMDBO(43:45) = DESC(65)
      ACMDBO(46:48) = DESC(66)
      ACMDBO(49:51) = DESC(67)
      ACMDBO(52:52) = ' '
      ACMDBO(53:56) = DECKD(1)
      ACMDBO(57:60) = DECKD(2)

C  CHECK FOR ERROR MESSAGES RETURNED BY OPTRAN
      IF (ARG(ERRARG) .LT. 0.) THEN
         CLIMIT(1) = ARG(15) * 100.
         J = NINT(CLIMIT(1))
         DO 90 I = 1,NMERR(CNTLST)
            IF (RETCOD(I) .EQ. J) THEN
               ERFLAG = ERRTYP(I)
               ERRMSG(NXTMSG) = RETTXT(I)
               NXTMSG = MIN (NXTMSG+1,20)
            ENDIF
90       CONTINUE
         TRNOU9 = 0
         RETURN
      ENDIF

C     Check for interface file support
         IF (ZCLI(45).LT.1 .OR. ZCLI(45).GT.999) THEN
               ERFLAG = 'C'
               ERRMSG(NXTMSG) =
     +          'SIF DOES NOT SUPPORT TEMP FOR 25% THRUST REDUCTION'
               NXTMSG = MIN (NXTMSG+1,20)
               TRNOU9 = 1
               RETURN
         ENDIF
         IF (ZCLI(46).LT.1 .OR. ZCLI(46).GT.999) THEN
               ERFLAG = 'C'
               ERRMSG(NXTMSG) =
     +          'SIF DOES NOT SUPPORT BREAK TEMP '
               NXTMSG = MIN (NXTMSG+1,20)
               TRNOU9 = 1
               RETURN
         ENDIF


C     OUTPUT TEMPERATURES DO NOT USE STRAIGHT CONVERSION FACTORS.
      IF(ZCLI(45) .GT. 0)THEN
         CLIMIT(45) = (ARG(ZCLI(45))+40.)/CF(1)-40.
      ENDIF
      IF(ZCLI(46) .GT. 0)THEN
         CLIMIT(46) = (ARG(ZCLI(46))+40.)/CF(1)-40.
      ENDIF

C     Output temperature for 25% reduced thrust
C     and break temperatures use whole numbers.
C     The 25% reduced thrust point is truncated down.
C     The break temperature uses the next higher whole number.
      IF (CLIMIT(45) .LT. 9.E6) THEN
          CLIMIT(45)  = FLOAT(INT(CLIMIT(45)))
      ENDIF
      IF (AINT(CLIMIT(46)) .NE. CLIMIT(46)) THEN
C        It wasn't a whole number already.
C        Make it the next higher whole number.
         CLIMIT(46)    = AINT(CLIMIT(46)) + 1.00
      ENDIF


      TRNOU9 = 0
      RETURN
      END
C*****************************************************************
      SUBROUTINE TROMPO

C  REINITIALIZE OUTPUT VARIABLES.
C  USE WHEN CALCULATION ERROR ENCOUNTERED.

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

C     File:  Param4.fi   6 Nov 1996
C     THESE PARAMETERS DEFINE THE SIZE OF EACH OF THE SCAP ARRAYS
      PARAMETER (LLPOPT=200, LLCONF=200, LLXMET=200, LLRWYD=200,
     +           LLOBSD=200, LLFPTD=200, LLUNIT=200, LLSPIA=200,
     +           LLSPIB=200, LLSPIC=200)

      PARAMETER (LLCLIM=200, LLRWYS=200, LLFIRS=200, LLSECS=200,
     +           LLACCS=200, LLFINS=200, LLOBSL=200, LLTRND=200,
     +           LLSPOU=200)

      COMMON /MFRORD/ORD(2,22),OMARK7(8)

      DO 100 I = 1,LLCLIM
         CLIMIT(I) = 9.E20
100   CONTINUE
      DO 110 I = 1,LLRWYS
         RWYSEG(I) = 9.E20
110   CONTINUE
      DO 120 I = 1,LLFIRS
         FIRSEG(I) = 9.E20
120   CONTINUE
      DO 130 I = 1,LLSECS
         SECSEG(I) = 9.E20
130   CONTINUE
      DO 140 I = 1,LLACCS
         ACCSEG(I) = 9.E20
140   CONTINUE
      DO 150 I = 1,LLFINS
         FINSEG(I) = 9.E20
150   CONTINUE
      DO 160 I = 1,LLOBSL
         OBSLIM(I) = 9.E20
160   CONTINUE
      DO 170 I = 1,LLTRND
         TRNDAT(I) = 9.E20
170   CONTINUE
      DO 175 I = 1,LLSPOU
         SPOUTA(I) = 9.E20
175   CONTINUE

C  INITIALIZE ALL OPTRAN ARGUMENTS TO 0
      DO 200 I = 1,999
         ARG(I) = 0.
200   CONTINUE

C  INITIALIZE MFRORD OUTPUTS
      DO 210 I = 1,8
         OMARK7(I) = 9.E20
210   CONTINUE

      RETURN
      END
C***************************************************************
      SUBROUTINE VARTXT(LTR,TXT)
C  GIVEN THE FIRST LETTER OF THE INPUT VARIABLE'S NAME
C  THIS ROUTINE WILL RETURN THE ENTIRE VAIRABLE NAME AS A TEXT STRING

      CHARACTER LTR*1,TXT*4

      IF (LTR .EQ. 'P')THEN
           TXT = 'POPT'
         ELSEIF (LTR .EQ. 'C')THEN
           TXT = 'CONF'
         ELSEIF (LTR .EQ. 'X')THEN
           TXT = 'XMET'
         ELSEIF (LTR .EQ. 'R')THEN
           TXT = 'RWYD'
         ELSEIF (LTR .EQ. 'O')THEN
           TXT = 'OBSD'
         ELSEIF (LTR .EQ. 'F')THEN
           TXT = 'FPTD'
         ELSEIF (LTR .EQ. 'U')THEN
           TXT = 'UNIT'
         ELSEIF (LTR .EQ. 'S')THEN
           TXT = 'SPIA'
         ELSEIF (LTR .EQ. 'K')THEN
           TXT = 'SPIB'
         ELSEIF (LTR .EQ. 'V')THEN
           TXT = 'SPIC'
       ELSE
         TXT = 'XXXX'
      ENDIF

      RETURN
      END
C*************************************************************
      SUBROUTINE WRTF(X,OUT)

C     THIS SUBROUTINE WRITES THE INPUT FLOATING POINT
C     NUMBER INTO THE OUTPUT CHARACTER STRING USING APPROPRIATE
C     FORMATING.  IT WORKS FOR NUMBERS IN THE RANGE
C     FROM -9999 TO +99999.  FOR NUMBERS OUTSIDE OF THAT
C     RANGE, THE TEXT FIELD WILL BE FILLED WITH *S

      REAL X,Y
      CHARACTER FMT*8,OUT*6

      Y = ABS(X)
      I = 1000000000
C     CHECK FOR NUMBERS TOO LARGE FOR THE UPCOMING WHOLE NUMBER CHECK
      IF (Y.GT.1.E9) THEN
         IF (X .EQ. 9.E20) THEN
            OUT = ' 9.E20'
            RETURN
           ELSE
            FMT = '(1PE6.0)'
            WRITE(OUT,FMT,ERR=100) X
            RETURN
         ENDIF
      ENDIF

      IF (FLOAT(NINT(X)).EQ.X) THEN
C          WHOLE NUMBER
           FMT = '(F6.0)'
         ELSEIF (X .GE. 0.) THEN
C          POSITIVE REAL NUMBER
           IF (Y .GE. 1.E4) THEN
                FMT = '(F6.0)'
              ELSEIF (Y .GE. 1.E3) THEN
                FMT = '(F6.1)'
              ELSEIF (Y .GE. 1.E2) THEN
                FMT = '(F6.2)'
              ELSEIF (Y .GE. 1.E1) THEN
                FMT = '(F6.3)'
              ELSEIF (Y .GE. 1.)   THEN
                FMT = '(F6.4)'
              ELSE
                FMT = '(F6.5)'
           ENDIF
         ELSE
C          NEGATIVE REAL NUMBER
           IF (Y .GE. 1.E3) THEN
                FMT = '(F6.0)'
              ELSEIF (Y .GE. 1.E2) THEN
                FMT = '(F6.1)'
              ELSEIF (Y .GE. 1.E1) THEN
                FMT = '(F6.2)'
              ELSEIF (Y .GE. 1.)   THEN
                FMT = '(F6.3)'
              ELSE
                FMT = '(F6.4)'
           ENDIF
      ENDIF

      WRITE(OUT,FMT,ERR=100) X
      RETURN

100   OUT = '******'
      RETURN

      END
C*************************************************************
      SUBROUTINE WRTRWY(LUNTR)

C  WRTRWY      WRITES A MARK7E INPUT FILE TO TRACE UNIT

C-----COMMON MARK7       15 may 1997---------------------------------
C
C---- BLOK4 CHARACTER DECLARATIONS
C
      CHARACTER*1  DIS,HGT,KAPR,OAT
      CHARACTER*2  REF,WGT
      CHARACTER*3  ADRT,AIDNO,CNTRY,DESC,PWR,TNAME
      CHARACTER*4  APNAM,CITY,CONFG,DATEME,DECKD,DESIG,MRKNO,RNWY
C
      COMMON/BLOK1/NX,NY,KEXT,NTRY,NOU,NOV,NOX,NOY,ARGU,ARGV,ARGX,ARGY,
     +             ANSWR,ARGM1,ARGM2,KINDU,KINDV,KINDX,KINDY,INCOD,
     +             INSTR,INTYP,NINST,LOOP,NOLOP,ARGR1,ARGR2
      COMMON/BLOK2/ARG(999),IDORA(999),ILOC(899),KARD(3),MAXINS,MAXTAB,
     +             MAXTNO,TNOS(899)
      COMMON/BLOK3/ADD(6),CWY(6),FLAP(6),ICRIT(2),IDARG,IRR,IRWTYP(6),
     +             JO(18),LINE,NOAT,NOBS(6),NRWY,NT(9),NWIND,OATD(99),
     +             RLUP(2,7),RWL(6),SLP(6),STOUTL,SWY(6),SUB(6),TEMP(7),
     +             UCF(3),VDATA(30),WDATA(10),WIND(9),XX(60,6),ZHT,ZSKP
      COMMON/BLOK4/ADRT,AIDNO(2),APNAM(5),CITY(5),CNTRY(4),CONFG(9),
     +             DATEME(3),DECKD(2),DESC(72),DESIG,DIS(2),HGT(2),KAPR,
     +             MRKNO(2),OAT(2),PWR,RNWY(2,6),TNAME(2),REF(2),WGT(2)
      COMMON/BLOK5/IDUM(51),IDUMP1(50),IDUMP2(50),INSDUM
      COMMON/BLOKI/INSTB(13,3000)
      COMMON/BLOKT/TABLE(90000)
C-----END OF COMMON MARK7 ----------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------

      CHARACTER LINEZ*80
      INTEGER DUMA(10)
      DATA DUMA/22,23,28,29,30,45,46,47,48,49/

C  TOP OF FILE THRU FIRST TAKEOFF CARD
      WRITE (LUNTR,1000,ERR=100)TNAME(1),TNAME(2),APTIDT(1:6),TNAME(1),
     +                          TNAME(2),COMENT(1)(1:24),ACTYPE(1:12),
     +                          WGT(2),OAT(2),HGT(2),DIS(2),REF(1)
1000  FORMAT('ENG',27X,'OVE'/'TAB'/2A3,'.DAT'/'NEW'/
     +       A6,2A3,12X,A24,A12,6X,A2,3A1,A2)

C  SECOND TAKEOFF CARD 1 OF 4
      LINEZ = ' '
      DO 200 I=1,10
         IANUM = DUMA(I)
         CALL WRTF(ARG(IANUM),LINEZ(6*(I-1)+1:6*(I-1)+6))
200   CONTINUE
      WRITE(LINEZ(66:72),1010,ERR=100)NINT(ARG(8))
1010  FORMAT(I6)
      LINEZ(80:80) = '+'
      WRITE(LUNTR,1070,ERR=100)LINEZ

C  SECOND TAKEOFF CARD 2 OF 4
      LINEZ = ' '
      DO 300 I = 1,12
         IANUM = I + 99
         CALL WRTF(ARG(IANUM),LINEZ(6*(I-1)+1:6*(I-1)+6))
300   CONTINUE
      LINEZ(80:80) = '+'
      WRITE(LUNTR,1070,ERR=100)LINEZ

C  SECOND TAKEOFF CARD 3 OF 4
      LINEZ = ' '
      DO 400 I = 1,12
         IANUM = I + 111
         CALL WRTF(ARG(IANUM),LINEZ(6*(I-1)+1:6*(I-1)+6))
400   CONTINUE
      LINEZ(80:80) = '+'
      WRITE(LUNTR,1070,ERR=100)LINEZ
C  SECOND TAKEOFF CARD 4 OF 4
      LINEZ = ' '
      DO 500 I = 1,12
         IANUM = I + 123
         CALL WRTF(ARG(IANUM),LINEZ(6*(I-1)+1:6*(I-1)+6))
500   CONTINUE
      WRITE(LUNTR,1070,ERR=100)LINEZ

C  WIND AND TEMP CARDS
      WRITE(LUNTR,1030,ERR=100)ARG(25),ARG(24),ARG(24),ARG(24),ARG(24)
1030  FORMAT(5X,'1',F6.2/2F6.1,5X,'0',F6.1,5X,'0',F6.1,5X,'1'/)

C  AIRPORT CARD
      WRITE(LUNTR,1040,ERR=100)NINT(ARG(19))
1040  FORMAT(4X,I5)

C  RUNWAY CARD
      WRITE(LUNTR,1050,ERR=100)NINT(ARG(20)),ARG(21),NINT(ARG(26)),
     +                 NINT(ARG(27)),(NINT(XX(I,1)),I=1,8),
     +                 RWYNBR(1:7),(NINT(XX(I,1)),I=9,40)
1050  FORMAT('RWY1',I5,5X,F5.2,2I4,4(I4,I6),5X,A7,'+'/
     +        27X,4(I4,I6),12X,'+'/27X,4(I4,I6),12X,'+'/
     +        27X,4(I4,I6),12X,'+'/27X,4(I4,I6))

C  FINISH UP
      WRITE(LUNTR,1060,ERR=100)
1060  FORMAT('QUIT'/30X,'END')

      RETURN

C  ERROR ENCOUNTERED WRITING MARK7 INPUT FILE
100   ERFLAG = 'B'
      ERRMSG(NXTMSG) = 'ERROR ENCOUNTERED WRITING MARK7 INPUT FILE'
      NXTMSG = MIN (NXTMSG+1,20)
      RETURN

1070  FORMAT(A80)

      END
C===================================================================
      INTEGER FUNCTION ZSLPB2(IMODE)

c        This routine conditionally reinterprets the user's inputs
c        to adjust mu-b to account for brakes deactivated.
c        If conditions for the reinterpretation are not met,
c        this routine will do nothing.
c
c        inputs:
c             imode integer  1=before MM call; 2=after mm call

c        variables related to local storage of user's inputs
c        which may be reinterpreted.
         real c20,p16
         logical trgr
         logical uic
         save uic,c20,p16

C---- COMMON INTFC -- (intfc4.fi)  27-July-2004 -----------------------
C     Used in both BTOPS and UNIFY
C
C     KTBLMX is the maximum number of sets allowed per database
      PARAMETER (KTBLMX=90)
C     KAMPMX is the maximum number of argument mapping recs per set
      PARAMETER (KAMPMX=100)
C     KERRMX is the maximum number of error messages allowed per set
      PARAMETER (KERRMX=90)
C     KTMRMX is the maximum number of text mapping records allowed per set
      PARAMETER (KTMRMX=90)
C  COMMON INTFC DECLARATIONS
      CHARACTER APACK*9,ARWY*15,BLEED*9,BRTXT*12,DBI*60,DECK*8,
     +          ENGINE*11,ERRTYP*1,FRAME*12,MAPTYP*1,MTDPU*2,MTNAME*6,
     +          MTOWN*6,PORC*1,RDAT*12,RETTXT*80,RLTXT*8,RULES*3,
     +          RWYCON*15,SERID*6,TMRTXT*16
      REAL ARGVAL,MTLIM,NONLIM,POPVAL
      INTEGER   ARGNUM,CNTLST,COUNT,ERRARG,FLAPS,NMERR,NMMP,NUMOWN,
     +          POPNUM,RETCOD,REVNUM,RNUM,TMRARG,YCON,YFPT,YOBS,YPOP,
     +          YRWY,YUNI,YXME,YSPA,YSPB,YSPC,ZACC,ZCLI,ZFIN,ZFIR,ZOBS,
     +          ZRWY,ZSEC,ZTRN,ZSPO

C  COMMON INTFC CHARACTER DATA BLOCK
      COMMON/INTFCA/APACK,ARWY,BLEED(KTBLMX),BRTXT(KTBLMX),DBI,
     +              DECK(KTBLMX),ENGINE(KTBLMX),ERRTYP(KERRMX),
     +              FRAME(KTBLMX),MAPTYP(KAMPMX),MTDPU,MTNAME(KTBLMX),
     +              MTOWN(KTBLMX),PORC(KAMPMX),RDAT,RETTXT(KERRMX),
     +              RLTXT(KTBLMX),RULES(KTBLMX),RWYCON(KTBLMX),SERID,
     +              TMRTXT(KTMRMX)

C  COMMON INTFC NUMERIC DATA BLOCK
      COMMON/INTFCN/ARGNUM(KAMPMX),ARGVAL(KAMPMX),CF(41),CNTLST,
     +              COUNT(KTBLMX),ERRARG,FLAPS(KTBLMX),IFLAP,
     +              MTLIM(KTBLMX),NMERR(KTBLMX),NMMP(KTBLMX),
     +              NMTMR(KTBLMX),NONLIM(KTBLMX),NUMOWN,NXTMSG,
     +              POPNUM(KAMPMX),POPVAL(KAMPMX),RETCOD(KERRMX),
     +              REVNUM(KTBLMX),RNUM,TMRARG(KTMRMX),TMRSET(KTMRMX),
     +              YCON(200),YFPT(200),YOBS(200),YPOP(200),YRWY(200),
     +              YUNI(200),YXME(200),YSPA(200),YSPB(200),YSPC(200),
     +              ZACC(200),ZCLI(200),ZFIN(200),ZFIR(200),ZOBS(200),
     +              ZRWY(200),ZSEC(200),ZTRN(200),ZSPO(200),ADJ1,ADJ2
C
C-----END OF COMMON INTFC---------------------------------------------
C ----File:  SCAP5.fi 10 Jan 2000-----------------------
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)
C SCAP OUTPUT:
      CHARACTER*20   ERFLAG
      CHARACTER*80   ERRMSG,OUTMIS
      CHARACTER*20   MMIDNT,MMDATE
      CHARACTER*255  ACMDBO
      COMMON/TOUTA/ERFLAG,ERRMSG(20),MMIDNT,MMDATE,
     +             ACMDBO,OUTMIS(20)
      COMMON/TOUTN/CLIMIT(200),RWYSEG(200),FIRSEG(200),
     +             SECSEG(200),ACCSEG(200),FINSEG(200),
     +             OBSLIM(200),TRNDAT(200),SPOUTA(200)
C ----END OF SCAP COMMON----------------------------------

      LOGICAL DRCCIP
      COMMON /DRCC/DRCCIP,DRCCGW,DRCCVB

         data uic/.false./

C     initialize return value
      ZSLPB2 = 0

      if (imode .eq. 2) then
c         If user's inputs were changed...
          if (uic) then
c             restore original inputs
              CONF(20) = c20
              POPT(16) = P16
              UIC = .FALSE.
c             look at Vmbe using information from the dry check
              if (DRCCVB .lt. CLIMIT(33)) then
                  CLIMIT(33) = DRCCVB
              endif
C             Compare output V1 values to Vmbe from the dry check
              if (
     +   (CLIMIT(7).LT.7.E20  .AND. CLIMIT(7).GT.CLIMIT(33))   .OR.
     +   (CLIMIT(13).LT.7.E20 .AND. CLIMIT(13).GT.CLIMIT(33))  .OR.
     +   (CLIMIT(19).LT.7.E20 .AND. CLIMIT(19).GT.CLIMIT(33)) ) then
                 ZSLPB2 = 1
                 CALL TROMPO
                 ERFLAG = 'E'
                 ERRMSG(NXTMSG) = 'Brake energy limits exceeded'
                 NXTMSG = NXTMSG +1
              endif
          endif
          return
      endif

c     Check for triggering conditions.  Conditions are:
c        Slippery with a defined fixed mu-b
c        Anti-skid operative
c        Brakes deactivated
c        The mu-b check is just intended to distinguish it from
c        a qualitative braking action value. Not a valid range check.
      trgr = (ABS(POPT(14)-11.).lt.1.e-5) .and.
     +       (POPT(16).GT.0.0001) .and.
     +       (POPT(16).LT.0.9999) .and.
     +       (CONF(20).GT.0.99 .AND. CONF(20).LT.5.1) .and.
     +       (  (ABS(CONF(7)).lt.1.e-5) .or.
     +          (CONF(7).GT.8.999e20 .and. CONF(7).LT.9.001e20) )

      if (.NOT. trgr) then
c         Not triggered. Do nothing.
          return
      endif

      c20 = conf(20)
      p16 = popt(16)
      factor = fmubb2()
      IF (popt(16)*factor .LT. 0.05) THEN
C          FACTORED MU-B WOULD BE BELOW MINIMUM
           ERFLAG = 'B'
           ERRMSG(NXTMSG) = 'Braking action too low'
           NXTMSG = NXTMSG +1
           ZSLPB2 = -1
           RETURN
      ENDIF
      if (factor .GE. 0.05 .and. factor.lt.1.) then
c         the function returned a usable factor
          uic = .true.
          popt(16) = popt(16) * factor
          if (.not. drccip) then
              conf(20) = 0.
          else
              conf(20) = c20
          endif
      else
          uic = .false.
      endif
      return
      end

c*********************************************************************
      Real Function fmubb2()

c        Computes a factored airplane braking coefficient which
c        accounts for a degraded braking configuration. The factor
c        applied will be the ratio of operative brakes to total brakes.

c        If zero is returned from this function, that means the ratio
c        was not successfully determined.
c        If a value greater than zero and less than one is returned,
c        that means the ratio was successfully computed.


c        Output:
c           the factor described above, as the return value of
c           the function


c        SCAP Takeoff input commons:
C SCAP INPUT:
      CHARACTER*20   RATING,CERTIF
      CHARACTER*20   FDCFGI
      CHARACTER*20   BRAKES,REVNBR,DATE,RWYNBR
      CHARACTER*20   DBOPTI
      CHARACTER*20   ACTYPE,ENGTYP,APTIDT
      CHARACTER*255  ACMDBI,MISCLA,CDLFIL
      CHARACTER*132  COMENT(20)
      COMMON/TINPA/ACTYPE,ENGTYP,RATING,BRAKES,CERTIF,
     +            REVNBR,DATE,DBOPTI,ACMDBI,APTIDT,RWYNBR,
     +            COMENT,MISCLA,FDCFGI,CDLFIL
      COMMON/TINPN/POPT(200),CONF(200),XMET(200),RWYD(200),
     +            OBSD(200),FPTD(200),UNIT(200),SPIA(200),
     +            SPIB(200),SPIC(200)




c        initialize returned value
         fmubb2 = 0.


c        set a value for the number of inoperative brakes,
c        based on the SCAP inputs
            if (conf(20).gt.8.99e20 .and. conf(20).lt.9.01e20) then
c              User's input is 9.e20. Interpret as all brakes operating
               niopb = 0
              elseif(abs(conf(20)) .lt. 1.e-4)then
               niopb = 0
              elseif(abs(conf(20)-1.) .lt. 1.e-4)then
               niopb = 1
              elseif(abs(conf(20)-3.) .lt. 1.e-4)then
               niopb = 2
              elseif(abs(conf(20)-4.) .lt. 1.e-4)then
               niopb = 2
              elseif(abs(conf(20)-5.) .lt. 1.e-4)then
               niopb = 2
              else
c               unknown brake configuration
                fmubb2 = 0.
                return
            endif


c        initialize the total number of brakes (operative or inoperative).
c        Logic may vary a bit by model to capture configuration differences
c        for minor models.
         ntotb = 0
         if (ACTYPE(1:3).eq.'747')then
               ntotb = 16
           elseif (ACTYPE(1:3).eq.'757' .or. ACTYPE(1:5).eq.'C-32A')then
               ntotb = 8
           elseif (ACTYPE(1:3).eq.'767')then
               ntotb = 8
           elseif (ACTYPE(1:3).eq.'777')then
               ntotb = 12
           elseif (ACTYPE(1:3).eq.'787')then
               ntotb = 8
           else
c              Other models not applicable.
                ntotb = 0
c               undefined airframe
                fmubb2 = 0.
                return
         endif


c       if we have what we need, compute the ratio.
         if (ntotb .gt.  0 .and. niopb .ge. 0 .and.
     +       ntotb .le. 50 .and. niopb .le. 5) then
                fmubb2 = float(ntotb-niopb)/float(ntotb)
            else
                fmubb2 = 0.
         endif

         return
         end

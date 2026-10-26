	SUBROUTINE ETME2_Loader()

c	Accessibility to the loadlibrary and getprocaddress functions 
	use kernel32

C INPUT PARAMETERS
	
	IMPLICIT NONE

	TYPE TINPN_T
		SEQUENCE
		REAL POPT(200),CONF(200),XMET(200),RWYD(200),OBSD(200),
     +    FPTD(200),UNIT(200),SPIA(200),SPIB(200),SPIC(200)
	END TYPE
      
	TYPE TINPA_T
		SEQUENCE
		CHARACTER*20  ACTYPE
		CHARACTER*20  ENGTYP
		CHARACTER*20  RATING
		CHARACTER*20  BRAKES
		CHARACTER*20  CERTIF
		CHARACTER*20  REVNBR
		CHARACTER*20  DATE
		CHARACTER*20  DBOPTI
		CHARACTER*255 ACMDBI
		CHARACTER*20  APTIDT
		CHARACTER*20  RWYNBR
		CHARACTER*132 COMENT(20)
		CHARACTER*255 MISCLA
		CHARACTER*20  FDCFGI
		CHARACTER*255 CDLFIL
	END TYPE      


C  OUTPUT PARAMETERS
	TYPE TOUTA_T
		SEQUENCE
		CHARACTER*20  ERFLAG
		CHARACTER*80  ERRMSG(20)
		CHARACTER*20  MMIDNT
		CHARACTER*20  MMDATE
		CHARACTER*255 ACMDBO
		CHARACTER*80  OUTMIS(20)
	ENDTYPE
      
      TYPE TOUTN_T
		SEQUENCE
		REAL CLIMIT(200),RWYSEG(200),FIRSEG(200),SECSEG(200),
     .  ACCSEG(200),FINSEG(200),OBSLIM(200),TRNDAT(200),
     .  SPOUTA(200)
	ENDTYPE
	
	TYPE(TINPN_T)  TINPN_T1
	TYPE(TINPA_T)  TINPA_T1
	TYPE(TOUTA_T)  TOUTA_T1
	TYPE(TOUTN_T)  TOUTN_T1

	TYPE(TINPN_T)  TINPN_T2
	TYPE(TINPA_T)  TINPA_T2
	TYPE(TOUTA_T)  TOUTA_T2
	TYPE(TOUTN_T)  TOUTN_T2

      COMMON/TINPN/TINPN_T1
      COMMON/TINPA/TINPA_T1
      COMMON/TOUTN/TOUTN_T1
      COMMON/TOUTA/TOUTA_T1

      COMMON/COMDLLTO/DLL_P

C	CREATE POINTERS TO EACH TYPE VARIABLE 
	pointer (TINPN_P, TINPN_T2)
	pointer (TINPA_P, TINPA_T2)
	pointer (TOUTN_P, TOUTN_T2)
	pointer (TOUTA_P, TOUTA_T2)

C	POINTER TO THE DLL
	REAL DLL
      REAL ETME2DLL
      pointer (DLL_P,DLL)
C	POINTER TO SUBROUTINE ETM170DLL
	pointer (ETME2DLL_P,ETME2DLL)


! First, locate the dll and load it into memory
	IF(DLL_P.EQ.0) THEN
		DLL_P = loadlibrary('ETME2_v301.dll') !File name
		if (DLL_P == 0) then
		type *, "Error occurred opening ETME2_v301.dll"
		type *, "Program aborting"
		goto 1000
		endif

	ENDIF

! Set up a pointer to the routine of interest
      ETME2DLL_P = getprocaddress(DLL_P, "ETME2")
	if (ETME2DLL_P == 0) then
		type *, "Error occurred finding ETME2 in ETME2_v301.dll"
		type *, "Program aborting"
		goto 1000
	endif

!	Set up the type pointers to the corresponded common variables
	TINPN_P = getprocaddress(DLL_P, "tinpn")
	TINPA_P = getprocaddress(DLL_P, "tinpa")
	TOUTN_P = getprocaddress(DLL_P, "toutn")
	TOUTA_P = getprocaddress(DLL_P, "touta")

	TINPN_T2 = TINPN_T1
	TINPA_T2 = TINPA_T1

	CALL ETME2DLL	! CALL DE MM

	TOUTA_T1 = TOUTA_T2
	TOUTN_T1 = TOUTN_T2

	RETURN

1000	TOUTA_T1%ERRMSG(1) =	'Error occurred opening dll 
     %or finding ETME2' 
	TOUTA_T1%ERFLAG = 'B'

	END
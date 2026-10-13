	SUBROUTINE OCTOPUS

	use kernel32

	IMPLICIT NONE

	INTEGER DLL, RUNSCAP
	pointer (RUNSCAP_P,RUNSCAP)
	pointer (DLL_P,DLL)

	INCLUDE 'DECLARA.FOR'
	INTEGER I
	CHARACTER AUX

C	****************************************************************
C	!ESCREVE O ARQUIVO DE INPUT
C	****************************************************************
	OPEN(UNIT=21,FILE='scap.in', STATUS='REPLACE')
	
	WRITE(21,'(A1)') '1'
	WRITE(21,'(A)') 'Common POPT -----------------------------------------'

	DO I=1,56
	  IF (POPT(I).LT.9E15) THEN
	    IF (I.LT.10) THEN
	      WRITE(21,'(A,I1,A,F)') 'POPT  ', I, '  = ', POPT(I)
	    ELSE
	      WRITE(21,'(A,I2,A,F)') 'POPT  ', I, ' = ', POPT(I)
		ENDIF
	  ENDIF
	ENDDO

	
	WRITE(21,*) 'Common CONF ---------------------------------------------'

	DO I=1,90
	  IF (CONF(I).LT.9E15) THEN
	    IF (I.LT.10) THEN
	      WRITE(21,'(A,I1,A,F)') 'CONF  ', I, '  = ', CONF(I)
	    ELSE
	      WRITE(21,'(A,I2,A,F)') 'CONF  ', I, ' = ', CONF(I)
		ENDIF
	  ENDIF
	ENDDO


	WRITE(21,*) 'Common XMET ---------------------------------------------'

	DO I=1,5
	  IF (XMET(I).LT.9E15) THEN
	    IF (I.LT.10) THEN
	      WRITE(21,'(A,I1,A,F)') 'XMET  ', I, '  = ', XMET(I)
	    ELSE
	      WRITE(21,'(A,I2,A,F)') 'XMET  ', I, ' = ', XMET(I)
		ENDIF
	  ENDIF
	ENDDO


	WRITE(21,*) 'Common RWYD ---------------------------------------------'

	DO I=1,13
	  IF (RWYD(I).LT.9E15) THEN
	    IF (I.LT.10) THEN
	      WRITE(21,'(A,I1,A,F)') 'RWYD  ', I, '  = ', RWYD(I)
	    ELSE
	      WRITE(21,'(A,I2,A,F)') 'RWYD  ', I, ' = ', RWYD(I)
		ENDIF
	  ENDIF
	ENDDO


	WRITE(21,*) 'Common OBSD ---------------------------------------------'

	DO I=1,92
	  IF (OBSD(I).LT.9E15) THEN
	    IF (I.LT.10) THEN
	      WRITE(21,'(A,I1,A,F)') 'OBSD  ', I, '  = ', OBSD(I)
	    ELSE
	      WRITE(21,'(A,I2,A,F)') 'OBSD  ', I, ' = ', OBSD(I)
		ENDIF
	  ENDIF
	ENDDO


	WRITE(21,*) 'Common FPTD ---------------------------------------------'

	DO I=1,16
	  IF (FPTD(I).LT.9E15) THEN
	    IF (I.LT.10) THEN
	      WRITE(21,'(A,I1,A,F)') 'FPTD  ', I, '  = ', FPTD(I)
	    ELSE
	      WRITE(21,'(A,I2,A,F)') 'FPTD  ', I, ' = ', FPTD(I)
		ENDIF
	  ENDIF
	ENDDO


	WRITE(21,*) 'Common UNIT ---------------------------------------------'

	DO I=1,10
	  IF (UNIT(I).LT.9E15) THEN
	    IF (I.LT.10) THEN
	      WRITE(21,'(A,I1,A,F)') 'UNIT  ', I, '  = ', UNIT(I)
	    ELSE
	      WRITE(21,'(A,I2,A,F)') 'UNIT  ', I, ' = ', UNIT(I)
		ENDIF
	  ENDIF
	ENDDO


	WRITE(21,*) 'Common SPIA ---------------------------------------------'

	DO I=1,32
	  IF (SPIA(I).LT.9E15) THEN
	    IF (I.LT.10) THEN
	      WRITE(21,'(A,I1,A,F)') 'SPIA  ', I, '  = ', SPIA(I)
	    ELSE
	      WRITE(21,'(A,I2,A,F)') 'SPIA  ', I, ' = ', SPIA(I)
		ENDIF
	  ENDIF
	ENDDO


	WRITE(21,'(A)') 'Common TINPA (Character values) ---------------------'
	WRITE(21,'(A,A)') 'ACMDBI   = ', ACMDBI
	WRITE(21,'(A,A)') 'MISCLA   = ', MISCLA
	WRITE(21,'(A,A)') 'CERTIF   = ', CERTIF
	WRITE(21,'(A,A)') 'FDCFGI   = ', FDCFGI
	WRITE(21,'(A)') 'DBOPTI   = '

	CLOSE(21)

C	****************************************************************
C	RODA O MÓDULO DE CÁLCULO
C	****************************************************************
	  DLL_P = loadlibrary("scap_octopus.dll")

	  RUNSCAP_P = getprocaddress(DLL_P, "_runscap@0")

	CALL RUNSCAP


C	****************************************************************
C	LÊ O ARQUIVO DE OUTPUT
C	****************************************************************
	OPEN(UNIT=22,FILE='SCAP.OUT',STATUS='OLD')

	DO I=1,34
		READ(22,*)
	ENDDO

	DO I=1,40
		READ(22,*) CLIMIT(I*5-4), CLIMIT(I*5-3), CLIMIT(I*5-2), 
     .				CLIMIT(I*5-1), CLIMIT(I*5)
	ENDDO

	READ(22,*)
	DO I=1,40
		READ(22,*) RWYSEG(I*5-4), RWYSEG(I*5-3), RWYSEG(I*5-2), 
     .				RWYSEG(I*5-1), RWYSEG(I*5)
	ENDDO

	READ(22,*)
	DO I=1,40
		READ(22,*) FIRSEG(I*5-4), FIRSEG(I*5-3), FIRSEG(I*5-2), 
     .				FIRSEG(I*5-1), FIRSEG(I*5)
	ENDDO
	

	READ(22,*)
	DO I=1,40
		READ(22,*) SECSEG(I*5-4), SECSEG(I*5-3), SECSEG(I*5-2), 
     .				SECSEG(I*5-1), SECSEG(I*5)
	ENDDO

	READ(22,*)
	DO I=1,40
		READ(22,*) ACCSEG(I*5-4), ACCSEG(I*5-3), ACCSEG(I*5-2), 
     .				ACCSEG(I*5-1), ACCSEG(I*5)
	ENDDO

	READ(22,*)
	DO I=1,40
		READ(22,*) FINSEG(I*5-4), FINSEG(I*5-3), FINSEG(I*5-2), 
     .				FINSEG(I*5-1), FINSEG(I*5)
	ENDDO
	

	READ(22,*)
	DO I=1,40
		READ(22,*) OBSLIM(I*5-4), OBSLIM(I*5-3), OBSLIM(I*5-2), 
     .				OBSLIM(I*5-1), OBSLIM(I*5)
	ENDDO
	
	
	READ(22,*)
	DO I=1,40
		READ(22,*) TRNDAT(I*5-4), TRNDAT(I*5-3), TRNDAT(I*5-2), 
     .				TRNDAT(I*5-1), TRNDAT(I*5)
	ENDDO
	

	READ(22,*)
	DO I=1,40
		READ(22,*) SPOUTA(I*5-4), SPOUTA(I*5-3), SPOUTA(I*5-2), 
     .				SPOUTA(I*5-1), SPOUTA(I*5)
	ENDDO

	READ(22,*)
	DO I=1,40
		READ(22,*) AECLMB(I*5-4), AECLMB(I*5-3), AECLMB(I*5-2), 
     .				AECLMB(I*5-1), AECLMB(I*5)
	ENDDO


	READ(22,*)
	DO I=1,40
		READ(22,*) AEFLPH(I*5-4), AEFLPH(I*5-3), AEFLPH(I*5-2), 
     .				AEFLPH(I*5-1), AEFLPH(I*5)
	ENDDO
	
		READ(22,*)
	

	READ(22,'(A12,A)') AUX, ERFLAG
	DO I=1,20
		READ(22,'(A12,A)') AUX, ERRMSG(I)
	ENDDO

	CLOSE(22)

C	**************************************************************
C	AJUSTE DO CÓDIGO DO LIMITANTE DE ACORDO COM A TABELA UTILIZADA
C	**************************************************************
	IF (CLIMIT(1).EQ.POPT(24)) THEN
		CLIMIT(8) = 1
	ELSEIF (CLIMIT(52).EQ.2) THEN
		CLIMIT(8) = 0
	ELSEIF (CLIMIT(8).EQ. 1.) THEN
		CLIMIT(8) = CLIMIT(9)
	ENDIF

	IF ((CLIMIT(8).EQ.5).OR.(CLIMIT(8).EQ.6))THEN
		CLIMIT(8) = 4
	ENDIF


	END SUBROUTINE
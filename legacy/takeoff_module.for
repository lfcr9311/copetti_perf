	PROGRAM TAKEOFF_MODULE
	IMPLICIT NONE

	INTEGER TS,TCASA,TCASB,I,J,K,FIRST_COMMA,SECOND_COMMA
	CHARACTER VAR
	CHARACTER*10 LINE,TAILNBR
	CHARACTER*8 ABFLAP
	CHARACTER B
	LOGICAL FOUND
	REAL PESO(4), LIMIT(4), V2VS(4), V1_AVERAGE, MTOW
	INTEGER ANALYSIS,FLAP(1),VENTO(3),TEMP(3)

	INCLUDE 'DECLARA.FOR'
	INCLUDE 'INICIALIZA.FOR'

	OPEN (UNIT=1,FILE='takeoff_data.dat',STATUS='UNKNOWN')
	OPEN (UNIT=2,FILE='takeoff_result.dat',STATUS='REPLACE')
	OPEN (UNIT=3,FILE='batch_result.dat',STATUS='REPLACE')
	OPEN (UNIT=16,FILE='trace.txt',STATUS='REPLACE')
	OPEN (UNIT=17,FILE='MUE6DB3D.PDF',ACCESS='DIRECT',
     .FORM='FORMATTED',RECL=80)
	OPEN (UNIT=17,FILE='MUE6DC3A.PDF',ACCESS='DIRECT',
     .FORM='FORMATTED',RECL=80)

	INCLUDE 'INPUT.FOR'


C	******************************************************************
C	               RODA ANÁLISE PONTUAL (ANALYSIS=0)
C	OBS: PARA O BATCH (ANALYSIS=1), ESSE PRIMEIRO PONTO SERVE PRA 
C	VERIFICAR SE TEM PERFORMANCE PRA VENTO ZERO E PRA SE DETERMINAR 
C	O FLAP ÓTIMO NO CASO DO EMBRAER (SE CONF(3)=5)
C	******************************************************************
	IF (INDEX(ACTYPE,'E2').GT.0) THEN
		IF (CONF(3).LT.5) THEN
			POPT(8) = V2VS(INT(CONF(3)))	
			CALL ETME2_Loader()
		ELSE
			DO I = 1, 4			!BUSCA FLAP ÓTIMO
				CONF(3) = I
				POPT(8) = V2VS(INT(CONF(3)))	
				CALL ETME2_Loader()

				PESO(I) = CLIMIT(1)
				LIMIT(I) = CLIMIT(20)
			ENDDO
			
			FLAP = MAXLOC(PESO(1:4))		!GUARDA FLAP ÓTIMO PRA RODAR BATCH
			CONF(3) = FLAP(1)
			POPT(8) = V2VS(FLAP(1))	
			CLIMIT(1) = PESO(FLAP(1))
			CLIMIT(20) = LIMIT(FLAP(1))
		ENDIF
	ELSEIF (INDEX(ACTYPE,'EMBRAER').GT.0) THEN
		IF (CONF(3).LT.5) THEN
			IF (POPT(7).EQ.1) THEN
				POPT(8) = V2VS(INT(CONF(3)))	
			ENDIF
			CALL ETM170
		ELSE
			DO I = 1, 4			!BUSCA FLAP ÓTIMO
				CONF(3) = I
				IF (POPT(7).EQ.1) THEN
					POPT(8) = V2VS(INT(CONF(3)))	
				ENDIF
				CALL ETM170
				PESO(I) = CLIMIT(1)
				LIMIT(I) = CLIMIT(8)
			ENDDO
			FLAP = MAXLOC(PESO(1:4))
			CONF(3) = FLAP(1)		!GUARDA FLAP ÓTIMO PRA RODAR BATCH
			IF (POPT(7).EQ.1) THEN
				POPT(8) = V2VS(FLAP(1))	
			ENDIF
			CLIMIT(1) = PESO(FLAP(1))
			CLIMIT(3) = FLAP(1)
			CLIMIT(8) = LIMIT(FLAP(1))
		ENDIF
	ELSEIF (INDEX(ACTYPE,'AIRBUS').GT.0) THEN
		CALL OCTOPUS
          
	ELSEIF (INDEX(ACTYPE,'737').GT.0) THEN
		CALL BTOPS
	ELSE
		CALL TTAM
		PESO(1) = CLIMIT(1)
		LIMIT(1) = CLIMIT(8)
		IF (POPT(14).EQ.1) THEN  !CHECA DRY
			POPT(14) = 0
			POPT(9) = 35
			CALL TTAM
			IF (CLIMIT(1).LT.PESO(1)) THEN
				CLIMIT(8) = 0 
			ELSE
				CLIMIT(1) = PESO(1)
				CLIMIT(8) = LIMIT(1)
			ENDIF
			!RETORNA AOS VALORES ORIGINAIS (NECESSÁRIO CASO RODE BATCH)
			POPT(14) = 1
			POPT(9) = 15
 		ENDIF
	ENDIF
C	******************************************************************



C	OUTPUT DA ANÁLISE PONTUAL

     !!ESCREVENDO OS LIMITANTES DE ACORDO COM O RUNWAY!!
	IF (INDEX(ACTYPE,'E2').GT.0) THEN
		IF (CLIMIT(1).GT.MTOW) THEN
			CLIMIT(20) = 1
		ENDIF
		IF ((CLIMIT(20).EQ.25).OR.(CLIMIT(20).EQ.26)) THEN
			CLIMIT(20) = 1
		ENDIF
	ENDIF
	
	IF (INDEX(ACTYPE,'EMBRAER').GT.0) THEN
		IF (CLIMIT(1).GT.MTOW) THEN
			CLIMIT(8) = 1
		ENDIF
		IF ((CLIMIT(8).EQ.25).OR.(CLIMIT(8).EQ.26)) THEN
			CLIMIT(8) = 1
		ENDIF
	ENDIF
	
	IF ((CLIMIT(8).EQ.22).OR.(CLIMIT(8).EQ.23)) THEN
		CLIMIT(8) = 3
	ENDIF
		
	IF ((CLIMIT(8).EQ.4).OR.(CLIMIT(8).EQ.9)) THEN
		CLIMIT(8) = 3
	ENDIF


	!!LIMITANDO O PESO DE ACORDO COM O AFM, MAS MANTENDO O MÁXIMO COMPUTACIONAL PARA RODAR O FLAP ÓTIMO!!
	IF (INDEX(ACTYPE,'EMBRAER').GT.0) THEN
		IF (CLIMIT(1).GT.MTOW) THEN
			CLIMIT(1) = MTOW
		ENDIF
	ENDIF
	IF (INDEX(ACTYPE,'E2').GT.0) THEN
		IF (CLIMIT(1).GT.MTOW) THEN
			CLIMIT(1) = MTOW
		ENDIF
	ENDIF
	
C	ESCREVENDO OS FLAPS DO AIRBUS
C	CLIMIT(2) REPRESENTA A DEFLEXÃO DO SLAT E FLAP
	IF (INDEX(ACTYPE,'AIRBUS320').GT.0) THEN
		SELECT CASE (INT(CLIMIT(2)))
		CASE (1810)
			ABFLAP = 'CONF 1+F'
		CASE (2215)
			ABFLAP = 'CONF 2'
		CASE (2220)
			ABFLAP = 'CONF 3'
		END SELECT
	ELSEIF (INDEX(ACTYPE,'AIRBUS321').GT.0) THEN
		SELECT CASE (INT(CLIMIT(2)))
		CASE (1810)
			ABFLAP = 'CONF 1+F'
		CASE (2214)
			ABFLAP = 'CONF 2'
		CASE (2221)
			ABFLAP = 'CONF 3'
          END SELECT
      ELSEIF (INDEX(ACTYPE,'AIRBUSF321').GT.0) THEN
		SELECT CASE (INT(CLIMIT(2)))
		CASE (1810)
			ABFLAP = 'CONF 1+F'
		CASE (2214)
			ABFLAP = 'CONF 2'
		CASE (2221)
			ABFLAP = 'CONF 3'
		END SELECT
	ELSEIF (INDEX(ACTYPE,'AIRBUS330NEO').GT.0) THEN
		SELECT CASE (INT(CLIMIT(2)))
		CASE (1608)
			ABFLAP = 'CONF 1+F'
		CASE (2015)
			ABFLAP = 'CONF 2'
		CASE (2323)
			ABFLAP = 'CONF 3'
		END SELECT	
	ELSEIF (INDEX(ACTYPE,'AIRBUS330').GT.0) THEN
		SELECT CASE (INT(CLIMIT(2)))
		CASE (1608)
			ABFLAP = 'CONF 1+F'
		CASE (2014)
			ABFLAP = 'CONF 2'
		CASE (2322)
			ABFLAP = 'CONF 3'
		END SELECT
	
	ENDIF
	B=TRIM(ERFLAG)
	IF (B.EQ.'A') THEN
		IF (INDEX(ACTYPE,'AIRBUS').GT.0) THEN
			WRITE(2,'(I6)') INT(CLIMIT(1))
			WRITE(2,'(A8)') ABFLAP
			WRITE(2,'(I2)') INT(CLIMIT(8))
		ELSEIF (INDEX(ACTYPE,'E2').GT.0) THEN
			WRITE(2,'(I5)') INT(CLIMIT(1))
			WRITE(2,'(I2)') INT(CONF(3))
			WRITE(2,'(I2)') INT(CLIMIT(20))
		ELSE
			WRITE(2,'(I5)') INT(CLIMIT(1))
			WRITE(2,'(I2)') INT(CLIMIT(3))
			WRITE(2,'(I2)') INT(CLIMIT(8))
		ENDIF
	ELSEIF (B.EQ.'D') THEN          ! ADICIONADO DEVIDO A LEITURA DO
		IF (INDEX(ACTYPE,'AIRBUS').GT.0) THEN !COM NARROW RWY NOS A320
			WRITE(2,'(I6)') INT(CLIMIT(1)) 
			WRITE(2,'(A8)') ABFLAP
			WRITE(2,'(I2)') INT(CLIMIT(8))
		ELSEIF (INDEX(ACTYPE,'E2').GT.0) THEN
			WRITE(2,'(I5)') INT(CLIMIT(1))
			WRITE(2,'(I2)') INT(CONF(3))
			WRITE(2,'(I2)') INT(CLIMIT(20))
		ELSE
			WRITE(2,'(I5)') INT(CLIMIT(1))
			WRITE(2,'(I2)') INT(CLIMIT(3))
			WRITE(2,'(I2)') INT(CLIMIT(8))
		ENDIF							! adicionado ate aqui
	ELSE 
		WRITE(2,'(A)') 'ERROR'
		WRITE(2,'(A)') ERRMSG(1)
		WRITE(2,'(A)') ERRMSG(2)
	ENDIF	
	


C	******************************************************************
C	                   RODA BATCH (ANALYSIS=1)
C	******************************************************************
	IF (ANALYSIS.EQ.1) THEN
	
		B=TRIM(ERFLAG)
		IF (B.EQ.'A') THEN
			IF (INDEX(ACTYPE,'E2').GT.0) THEN
			!DEFINE LOOP DE TEMPERATURA
				DO I = 1,3			
					TEMP(I) = XMET(6) -2*I +4
				ENDDO 			
			!DEFINE LOOP DE VENTO
				DO I = 1,3			
					VENTO(I) = XMET(2) +5*I -10
				!DEFINE LIMITES DE VENTO
					IF (VENTO(I).LT.-10) THEN
						VENTO(I) = -10
					ELSEIF (VENTO(I).GT.30) THEN
						VENTO(I) = 30
					ENDIF
				ENDDO

			ELSE
			!DEFINE LOOP DE TEMPERATURA
				DO I = 1,3			
					TEMP(I) = XMET(1) -2*I +4
				ENDDO 			
			!DEFINE LOOP DE VENTO
				DO I = 1,3			
					VENTO(I) = XMET(2) +5*I -10
				!DEFINE LIMITES DE VENTO
					IF (VENTO(I).LT.-10) THEN
						VENTO(I) = -10
					ELSEIF (VENTO(I).GT.30) THEN
						VENTO(I) = 30
					ENDIF
				ENDDO
			
			ENDIF
			!ESCREVE VALOR DO FLAP NA PRIMEIRA LINHA
			IF (INDEX(ACTYPE,'AIRBUS').GT.0) THEN
				WRITE(3,'(A)') ABFLAP
				CONF(1) = 4
				FDCFGI = ABFLAP
			ELSEIF (INDEX(ACTYPE,'E2').GT.0) THEN
				WRITE(3,'(I2)') INT(CONF(3))
			ELSE
				WRITE(3,'(I2)') INT(CLIMIT(3))
			ENDIF
			

		
			DO J = 1,3
				DO K = 1,3
					IF (INDEX(ACTYPE,'E2').GT.0) THEN
						XMET(6) = TEMP(J)						
						XMET(2) = VENTO(K)

						XMET(1) = 9E20
						XMET(3) = 9E20
					ELSE

						XMET(1) = TEMP(J)
						XMET(2) = VENTO(K)
					ENDIF

					IF (INDEX(ACTYPE,'E2').GT.0) THEN
						CALL ETME2_Loader()					
						
					ELSEIF (INDEX(ACTYPE,'EMBRAER').GT.0) THEN
						XMET(6) = XMET(1)
						CALL ETM170
					ELSEIF (INDEX(ACTYPE,'AIRBUS').GT.0) THEN
						CALL OCTOPUS
	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
					ELSEIF (INDEX(ACTYPE,'737').GT.0) THEN
						CALL BTOPS	
	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
					ELSE
						CALL TTAM
						PESO(1) = CLIMIT(1)
						LIMIT(1) = CLIMIT(8)
						IF (POPT(14).EQ.1) THEN  !CHECA DRY
							POPT(14) = 0
							POPT(9) = 35
							CONF(8) = 0
							CALL TTAM
							IF (CLIMIT(1).LT.PESO(1)) THEN
								CLIMIT(8) = 0 
							ELSE
								CLIMIT(1) = PESO(1)
								CLIMIT(8) = LIMIT(1)
							ENDIF
							POPT(14) = 1
							POPT(9) = 15
							CONF(8) = 1
 						ENDIF
					ENDIF


				!!ESCREVENDO OS LIMITANTES DE ACORDO COM O RUNWAY!!
						IF (INDEX(ACTYPE,'E2').GT.0) THEN
							IF (CLIMIT(1).GT.MTOW) THEN
								CLIMIT(20) = 1
							ENDIF
							IF ((CLIMIT(20).EQ.25).OR.(CLIMIT(20).EQ.26)) THEN
								CLIMIT(20) = 1
							ENDIF
							IF ((CLIMIT(20).EQ.22).OR.(CLIMIT(20).EQ.23)) THEN
								CLIMIT(20) = 3
							ENDIF
		
							IF ((CLIMIT(20).EQ.4).OR.(CLIMIT(20).EQ.9)) THEN
								CLIMIT(20) = 3
							ENDIF
						ENDIF
						IF (INDEX(ACTYPE,'EMBRAER').GT.0) THEN
							IF (CLIMIT(1).GT.MTOW) THEN
								CLIMIT(8) = 1
							ENDIF
							IF ((CLIMIT(8).EQ.25).OR.(CLIMIT(8).EQ.26)) THEN
								CLIMIT(8) = 1
							ENDIF
						ENDIF
	

						IF ((CLIMIT(8).EQ.22).OR.(CLIMIT(8).EQ.23)) THEN
							CLIMIT(8) = 3
						ENDIF
		
						IF ((CLIMIT(8).EQ.4).OR.(CLIMIT(8).EQ.9)) THEN
							CLIMIT(8) = 3
						ENDIF


	!!LIMITANDO O PESO DE ACORDO COM O AFM, MAS MANTENDO O MÁXIMO COMPUTACIONAL PARA RODAR O FLAP ÓTIMO!!
						IF (INDEX(ACTYPE,'E2').GT.0) THEN
							IF (CLIMIT(1).GT.MTOW) THEN
								CLIMIT(1) = MTOW
							ENDIF
						ENDIF
						IF (INDEX(ACTYPE,'EMBRAER').GT.0) THEN
							IF (CLIMIT(1).GT.MTOW) THEN
								CLIMIT(1) = MTOW
							ENDIF
						ENDIF
					IF (B.EQ.'A') THEN
						V1_AVERAGE = (CLIMIT(7)+CLIMIT(13))/2
						IF (INDEX(ACTYPE,'E2').GT.0) THEN
							WRITE(3,99) INT(XMET(6)),INT(XMET(2)),
     +									INT(CLIMIT(1)),INT(CLIMIT(20)),
     +									NINT(CLIMIT(5)),NINT(CLIMIT(6)),
     +									NINT(V1_AVERAGE),INT(ACCSEG(3)+RWYD(1)),
     +									INT(FINSEG(14))
						ELSEIF (INDEX(ACTYPE,'EMBRAER').GT.0) THEN
							WRITE(3,99) INT(XMET(1)),INT(XMET(2)),
     +									INT(CLIMIT(1)),INT(CLIMIT(8)),
     +									NINT(CLIMIT(5)),NINT(CLIMIT(6)),
     +									NINT(V1_AVERAGE),INT(ACCSEG(3)+RWYD(1)),
     +									INT(FINSEG(14))
						ELSE
							WRITE(3,99) INT(XMET(1)),INT(XMET(2)),
     +									INT(CLIMIT(1)),INT(CLIMIT(8)),
     +									NINT(CLIMIT(5)),NINT(CLIMIT(6)),
     +									NINT(V1_AVERAGE),INT(ACCSEG(3)+RWYD(1)),0
						ENDIF
					ELSE
						WRITE(3,99) INT(XMET(1)),INT(XMET(2)),0,0,0,0,0,0,0
					ENDIF
				ENDDO
			ENDDO
		ELSE
			WRITE(3,'(A)') 'ERROR'
			WRITE(3,'(A)') ERRMSG(1)
			WRITE(3,'(A)') ERRMSG(2)
		ENDIF		
	ENDIF				
C	******************************************************************


99	FORMAT(9(I6,','))

	
	END

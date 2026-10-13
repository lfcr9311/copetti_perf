C	LEITURA DO ARQUIVO DE INPUT

	READ(1,*) VAR, ANALYSIS !simple=0, batch=1
	READ(1,*) VAR, ACTYPE
	READ(1,*) VAR, ENGTYP
	READ(1,*) VAR, RATING
	READ(1,*) VAR, POPT(12) !TORA Takeoff Alignment (m)
	READ(1,*) VAR, POPT(13) !ASDA Takeoff Alignment (m)
	READ(1,*) VAR, POPT(14)	!Surface Condition (dry=0, wet=1)
	READ(1,*) VAR, POPT(24) !Maximum computational weight
	READ(1,*) VAR, POPT(30)	!CG envelope (std=0, alt=1)
	READ(1,*) VAR, CONF(3)	!flaps (1,2,3,4 or OPT=5)
	READ(1,*) VAR, XMET(1)	!temperature (°C)
	READ(1,*) VAR, XMET(2)	!wind (kt)
	READ(1,*) VAR, XMET(3)	!cross wind (kt)
	READ(1,*) VAR, XMET(5)	!QNH (mbar)
	READ(1,*) VAR, RWYD(1)	!airport elevation (ft)
	READ(1,*) VAR, RWYD(3)	!runway lenght (m)
	READ(1,*) VAR, RWYD(4)	!ASDA (m)
	READ(1,*) VAR, RWYD(5)	!TODA (m)
	READ(1,*) VAR, RWYD(6)	!slope (%)
	READ(1,*) VAR, RWYD(8)	!rwy surface (normal=0, grooved=1)
	READ(1,*) VAR, RWYD(11)	!rwy width (m)
	READ(1,*) VAR, OBSD(1)	!number of obstacles
	READ(1,*) VAR, OBSD(3)	!distance from end of TORA(m)
	READ(1,*) VAR, OBSD(4)	!height (ft)
	READ(1,*) VAR, OBSD(6)
	READ(1,*) VAR, OBSD(7)
	READ(1,*) VAR, OBSD(9)
	READ(1,*) VAR, OBSD(10)
	READ(1,*) VAR, OBSD(12)
	READ(1,*) VAR, OBSD(13)
	READ(1,*) VAR, OBSD(15)
	READ(1,*) VAR, OBSD(16)
	READ(1,*) VAR, OBSD(18)
	READ(1,*) VAR, OBSD(19)
	READ(1,*) VAR, OBSD(21)
	READ(1,*) VAR, OBSD(22)
	READ(1,*) VAR, OBSD(24)
	READ(1,*) VAR, OBSD(25)
	READ(1,*) VAR, OBSD(27)
	READ(1,*) VAR, OBSD(28)
	READ(1,*) VAR, OBSD(30)
	READ(1,*) VAR, OBSD(31)
	READ(1,*) VAR, OBSD(33)
	READ(1,*) VAR, OBSD(34)
	READ(1,*) VAR, OBSD(36)
	READ(1,*) VAR, OBSD(37)
	READ(1,*) VAR, OBSD(39)
	READ(1,*) VAR, OBSD(40)
	READ(1,*) VAR, OBSD(42)
	READ(1,*) VAR, OBSD(43)
	READ(1,*) VAR, OBSD(45)
	READ(1,*) VAR, OBSD(46)

	MTOW = POPT(24)
      THRUST = RATING
C	VARIÁVEIS COM VALORES FIXOS

C	************* POPT ***********************************************

	POPT(2) = 0
	POPT(5) = 0
	POPT(10) = 35
	POPT(11) = 0
	POPT(18) = 0
	POPT(19) = 400 	!MINIMUM LEVEL-OFF (foi mudado de acordo com o SOP Azul)
	POPT(20) = 1
	POPT(21) = 16
	POPT(22) = 17
	POPT(23) = 1 	!MAXIMUM COMPUTATIONAL WEIGHT (AFM=0, SELECTED=1)
	POPT(27) = 0
	POPT(33) = 0
	POPT(36) = 0
	POPT(39) = 0
	POPT(41) = 0

	IF (INDEX(ACTYPE,'E2').GT.0) THEN 
		POPT(1) = 1
		POPT(7) = 2

	POPT(2) = 9E20
	POPT(15) = 0
	POPT(16) = 6
	POPT(18) = 2

	POPT(21) = 9E20
	POPT(22) = 9E20
	POPT(23) = 1 	

	POPT(27) = 9E20
	POPT(33) = 0
	POPT(35) = 0
	POPT(36) = 9E20
	POPT(39) = 9E20
	POPT(41) = 9E20
	!!
		POPT(24) = 62300
		POPT(26) = 5
		POPT(38) = 1
		POPT(47) = 0
		POPT(49) = 0   ! DRY CHECK (0 - YES, 1 - NO)
		POPT(53) = 0
		POPT(57) = 0
		POPT(58) = 0
		
	ELSEIF (INDEX(ACTYPE,'EMBRAER').GT.0) THEN
		POPT(1) = 2
		POPT(24) = 54000
		POPT(26) = 5
		POPT(38) = 0
          POPT(53) = 0
		POPT(54) = 0
		POPT(56) = 0
C		RODA V2/VS FIXA PARA MOTOR 10E7 (TANTO PRO 190 E 195)		
		IF (INDEX(ENGTYP,'10E7').GT.0) THEN
			POPT(7) = 0 
		ELSE
			POPT(7) = 0
		ENDIF
	ELSEIF(INDEX(ACTYPE,'AIRBUS').GT.0) THEN
		POPT(1) = 0
		POPT(7) = 0
		POPT(19) = 1000
		POPT(25) = 0
		POPT(31) = 1
		POPT(35) = 0
		POPT(49) = 0
		POPT(50) = 0
		POPT(51) = 0
          
          IF(INDEX(ACTYPE,'AIRBUS330').GT.0) THEN
          IF (INDEX(ENGTYP,'CF6-80E1A4').GT.0) THEN
		    POPT(25) = 10 !BUMP
          ENDIF
          ENDIF

		IF(INDEX(ACTYPE,'AIRBUS321').GT.0) THEN
		POPT(19) = 400
          ENDIF
          
          IF(INDEX(ACTYPE,'AIRBUSF321').GT.0) THEN
		POPT(19) = 400
		ENDIF
		
		IF(INDEX(ACTYPE,'AIRBUS320').GT.0) THEN
		POPT(19) = 400
		ENDIF
		

		IF (POPT(14).EQ.0) THEN !DRY
			POPT(9) = 35
		ELSE					!WET
			POPT(9) = 15
		 	POPT(10) = 15	! OBSTACLE CLEARANCE AIRBUS
		ENDIF
		IF (RWYD(8).EQ.1) THEN
			POPT(16) = 8
		ENDIF
	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	ELSEIF (INDEX(ACTYPE,'737').GT.0) THEN
		POPT(1)=0					! EXTENDED OUTPUT
		POPT(7)=0					! IMPROVED CLIMB = OPTIMUM (0) NO(1)

		POPT(8)=9E20				! NOT SUPPORTED
		POPT(9)=9E20				! NOT SUPPORTED
		POPT(10)=9E20				! NOT SUPPORTED

		IF (POPT(14).EQ.1) THEN
			POPT(14)=11
			POPT(16)=0.2   
		ENDIF

		POPT(20)=4					! DETAILED TRACE OUTPUT
	!	POPT(24)=70000				! SELECTED VALUE OF MAXIMUM WEIGHT FLAG

		IF (INDEX(RATING,'TO').GT.0) THEN
		POPT(25)=0					! FULL THRUST
		ENDIF
		IF (INDEX(RATING,'TO-1').GT.0) THEN
		POPT(25)=1					! DERATE 22K
		ENDIF
		IF (INDEX(RATING,'TO-2').GT.0) THEN		
		POPT(25)=2					! DERATE 20K
		ENDIF

		POPT(26)=5					! THRUST TIME LIMIT
		POPT(27)=9E20				! NOT SUPPORTED
		POPT(30)=0					! NO ADJUSTMENTS ON FORWARD CG

		POPT(33)=9E20				! NOT SUPPORTED
		POPT(36)=9E20				! NOT SUPPORTED
		POPT(39)=9E20				! NOT SUPPORTED
		POPT(41)=9E20				! NOT SUPPORTED

		POPT(50)=0					! LOWEST LIMIT GROSS LEVEL-OFF HEIGHT
	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!	
	ELSE
		POPT(1) = 0
		POPT(7) = 0				!V2/VS ÓTIMA PRO ATR
		POPT(17) = 0
		POPT(30) = 0
		POPT(43) = 0
		IF (POPT(14).EQ.0) THEN !DRY
			POPT(9) = 35
		ELSE					!WET
			POPT(9) = 15
		ENDIF

		POPT(20) = 1
	ENDIF

c	IF (INDEX(ACTYPE,'EMBRAER').GT.0) THEN
c		POPT(23) = 1
c
c		IF (INDEX(ACTYPE,'190').GT.0) THEN
c			POPT(24) = 51800    !PESO MAX COMPUTACIONAL PARA O E190
c		ELSE
c			POPT(24) = 52290    !PESO MAX COMPUTACIONAL PARA O E195
c		ENDIF
c
c	ELSE
c		POPT(23) = 0
c	ENDIF			 


C	************* CONF ***********************************************

	CONF(1) = 1
	CONF(4) = 2 		! ECS OFF
	CONF(5) = 0			! A-ICING OFF	
	CONF(6) = 0			
	CONF(17) = 0
	CONF(20) = 0

	IF (INDEX(ACTYPE,'E2').GT.0) THEN
		CONF(6) = 9E20
		IF (POPT(14).EQ.0) THEN 
			CONF(8) = 0 ! NO REVERSE (DRY)
		ELSE
			CONF(8) = 1 ! ALL REVERSERS (WET)
		ENDIF
		CONF(13) = 1 	! AUTO BRAKES OFF 
		CONF(15) = 2 	! TIRE TYPE RADIAL 
		CONF(17) = 9E20
		CONF(20) = 9E20
		CONF(21) = 0 	! ATTCS ON
		CONF(58) = 5 	! LANDING FLAP POSITION
	ELSEIF (INDEX(ACTYPE,'EMBRAER').GT.0) THEN 
		IF (POPT(14).EQ.0) THEN 
			CONF(8) = 0 !NO REVERSE (DRY)
		ELSE
			CONF(8) = 1 !ALL REVERSERS (WET)
		ENDIF
		CONF(13) = 1
		
		IF (INDEX(ENGTYP,'10E5A1').GT.0) THEN
			IF (INDEX(RATING,'TO-1').GT.0) THEN
				CONF(21) = 1					! ATTCS OFF P/ T/O-1
			ENDIF
			IF (INDEX(RATING,'TO-2').GT.0) THEN
				CONF(21) = 0					! ATTCS ON
			ENDIF
			IF (INDEX(RATING,'TO-3').GT.0) THEN		
				CONF(21) = 0				    ! ATTCS ON	
			ENDIF
		ELSE
			CONF(21) = 0
		ENDIF
		
		CONF(36) = 2
		CONF(38) = 0
		CONF(69) = 1	!PNEU RADIAL
		CONF(70) = 0
		CONF(71) = 0
	ELSEIF (INDEX(ACTYPE,'AIRBUS').GT.0) THEN
		CONF(7) = 0
		IF(CONF(3).GT.4) THEN
			CONF(1) = 0
		ELSE
			CONF(1) = 4
		ENDIF
		IF (POPT(14).EQ.0) THEN 
			CONF(8) = 0 !NO REVERSE (DRY)
		ELSE
			CONF(8) = 1 !ALL REVERSERS (WET)
		ENDIF
		CONF(9) = 0
		CONF(10) = 0
		CONF(12) = 0
		CONF(13) = 0
		CONF(15) = 0
		CONF(24) = 0
		CONF(27) = 0
		CONF(44) = 0
		CONF(45) = 0
		CONF(63) = 0
		CONF(64) = 0
		CONF(65) = 0		
	ELSEIF (INDEX(ACTYPE,'737').GT.0) THEN
	!	CONF(1)=0						!FLAP CHOICE
	!	CONF(3)=15						!FLAP POSITION
	!
		IF (CONF(3).EQ.0) THEN			!LOGICA PARA FLAP OTIMO
			CONF(1)=0					!FLAP CHOICE = OPTIMUM
			CONF(3)=9E20
		ENDIF
	!
		CONF(7)=0						!ANTI SKID
		IF (POPT(14).EQ.0) THEN 
			CONF(8) = 0					!NO REVERSE (DRY)
		ELSE
			CONF(8) = 1					!ALL REVERSERS (WET)
		ENDIF
		CONF(12)=0						!PMC ON
	!	CONF(15)=0						!TIRE PROFILE: 40INCH NORMAL
		CONF(15)=1						!TIRE PROFILE: 42INCH
		CONF(16)=225					!TIRE SPEED: 225 MPH
	ELSE
		CONF(2) = 0
		CONF(3) = 15
		CONF(7) = 0
		CONF(8) = 0		!NO REVERSE (DRY AND WET)
		CONF(9) = 0
		CONF(12) = 0
		CONF(14) = 0
		CONF(15) = 0
		CONF(32) = 0
		CONF(54) = 0



		IF (INDEX(RATING,'BOOSTON+RTOON').GT.0) THEN
							!BOOST ON + RTO ON
			CONF(55) = 1 	!TAKEOFF THRUST POWER (NORMAL=0, RTO=1)
			CONF(56) = 2	!BOOST POWER (DEFAULT=0, BOOST OFF=1, BOOST ON=2 NOVO SCAP G8 0 FILE DEFAULT ANTIGO 2)
		ELSE IF (INDEX(RATING,'BOOSTOFF+RTOON').GT.0) THEN
							!BOOST OFF + RTO ON
			CONF(55) = 1	!TAKEOFF THRUST POWER (NORMAL=0, RTO=1)
			CONF(56) = 1 	!BOOST POWER (DEFAULT=0, BOOST OFF=1, BOOST ON=2 NOVO SCAP G8 0 FILE DEFAULT ANTIGO 1)


		ELSE IF (INDEX(RATING,'BOOSTON+RTOOFF').GT.0) THEN
							!INSERIDO DEVIDO AKI
							!BOOST ON + RTO OFF
			CONF(55) = 0	!TAKEOFF THRUST POWER (NORMAL=0, RTO=1)
			CONF(56) = 2 	!BOOST POWER (DEFAULT=0, BOOST OFF=1, BOOST ON=2 NOVO SCAP G8 0 FILE DEFAULT ANTIGO 1)
		
		ELSE
							!BOOST OFF + RTO OFF
			CONF(55) = 0	!TAKEOFF THRUST POWER (NORMAL=0, RTO=1)
			CONF(56) = 1	!BOOST POWER (DEFAULT=0, BOOST OFF=1, BOOST ON=2 NOVO SCAP G8 0 FILE DEFAULT ANTIGO 1)
		! ENDIF
		! ELSE
		!	CONF(55) = 0
		!	CONF(56) = 1


		END IF
	ENDIF


C	************* XMET ***********************************************

	XMET(4) = 1
	IF (INDEX(ACTYPE,'EMBRAER').GT.0) THEN
		XMET(6) = XMET(1)
	ENDIF
	IF (INDEX(ACTYPE,'E2').GT.0) THEN
		XMET(6) = XMET(1)
		XMET(1) = 9E20
		XMET(3) = 9E20
	ENDIF
	IF (INDEX(ACTYPE,'AIRBUS').EQ.0) THEN
		XMET(3) = 9E20
	ENDIF

C	************* RWYD ***********************************************

	RWYD(2) = 0
	RWYD(9) = 1
	RWYD(10) = 0
	IF (INDEX(ACTYPE,'EMBRAER').GT.0) THEN
		RWYD(7) = RWYD(6)
		!RWYD(11) = 9E20
	ELSEIF (INDEX(ACTYPE,'E2').GT.0) THEN
		RWYD(7) = RWYD(6)
		RWYD(9)=9E20
		RWYD(10)=9E20
		RWYD(11)=9E20
	ELSEIF (INDEX(ACTYPE,'AIRBUS320').GT.0) THEN !ADICIONADO NARROW
		RWYD(7) = 9E20							 !ADICIONADO RWYD=2
		IF (POPT(14).EQ.0) THEN !DRY
			RWYD(8) = 0
		ENDIF
	ELSEIF (INDEX(ACTYPE,'AIRBUS321').GT.0) THEN !ADICIONADO NARROW
		RWYD(7) = 9E20							 !ADICIONADO RWYD=2
		IF (POPT(14).EQ.0) THEN !DRY
			RWYD(8) = 0
		ENDIF
		IF (RWYD(8).EQ.1) THEN
			RWYD(8) = 2
          ENDIF	
	ELSEIF (INDEX(ACTYPE,'AIRBUSF321').GT.0) THEN !ADICIONADO NARROW
		RWYD(7) = 9E20							 !ADICIONADO RWYD=2
		IF (POPT(14).EQ.0) THEN !DRY
			RWYD(8) = 0
		ENDIF
		IF (RWYD(8).EQ.1) THEN
			RWYD(8) = 2
		ENDIF
	ELSE
		RWYD(7) = 9E20
		RWYD(8) = 0
	ENDIF

C	************* OBSD ***********************************************

	OBSD(2) = 1
	IF (INDEX(ACTYPE,'AIRBUS').GT.0) THEN
		DO I = 5,OBSD(1)*3+2,3
			OBSD(I) = 0
		ENDDO
	ENDIF

C	************* FPTD ***********************************************

	IF (INDEX(ACTYPE,'E2').GT.0) THEN
		FPTD(1) = 9E20
	ELSEIF (INDEX(ACTYPE,'EMBRAER').EQ.0) THEN
		FPTD(1) = 0
	ENDIF


C	************* UNIT ***********************************************

	UNIT(1) = 0
	UNIT(3) = 0
	UNIT(4) = 1
	UNIT(5) = 1
	UNIT(6) = 0
	UNIT(8) = 0
	UNIT(9) = 2
	IF (INDEX(ACTYPE,'E2').GT.0) THEN
		UNIT(2) = 0 
		UNIT(10) = 3 ! ENERGY [KGF.M]
		UNIT(7) = 9E20

	ELSEIF (INDEX(ACTYPE,'EMBRAER').GT.0) THEN
		UNIT(2) = 0 
		UNIT(7) = 1
		UNIT(10) = 0
	ELSEIF (INDEX(ACTYPE,'AIRBUS').GT.0) THEN
		UNIT(2) = 0
		UNIT(10) = 0
	ENDIF

C	************* SPIA ***********************************************

	IF (INDEX(ACTYPE,'E2').GT.0) THEN	
		DO I = 1, 200
			SPIA(I) = 9E20
		ENDDO

	ELSEIF (INDEX(ACTYPE,'EMBRAER').EQ.0) THEN
		DO I = 1, 31, 2
			SPIA(I) = 1
		ENDDO

		DO I = 2, 32, 2
			SPIA(I) = 0
		ENDDO

		SPIA(7) = 9E20
		SPIA(8) = 9E20
		SPIA(13) = 9E20
		SPIA(14) = 9E20
		SPIA(21) = 9E20
		SPIA(22) = 9E20
		SPIA(25) = 9E20
		SPIA(26) = 9E20
	ELSEIF (INDEX(ACTYPE,'AIRBUS').GT.0) THEN
		DO I = 1, 11, 2
			SPIA(I) = 1
		ENDDO
		DO I = 2, 12, 2
			SPIA(I) = 0
		ENDDO

		DO I = 21, 25, 2
			SPIA(I) = 1
		ENDDO
		DO I = 22, 26, 2
			SPIA(I) = 0
		ENDDO

		DO I = 29, 31, 2
			SPIA(I) = 1
		ENDDO

		DO I = 30, 32, 2
			SPIA(I) = 0
		ENDDO

		SPIA(33) = 0

	ENDIF
	
C	************* TINPA ***********************************************
	IF (INDEX(ACTYPE,'E2').GT.0) THEN
		ACTYPE = 'E195-E2'
	!	RATING = 'TO-1'
		BRAKES = '2-1768'
		CERTIF = 'ANAC'	
		REVNBR = 'ETME2_v3.0.1'
		ACMDBI = 'CAFM-ADB-069.pdm;CAFM-EDB-015.pdm'
		DATE = '19SEP2023;23AUG2021'
      ELSEIF (INDEX(ACTYPE,'EMBRAER').GT.0) THEN
 
          IF (INDEX(RATING,'TO-1').GT.0) THEN
          RATING = 'T/O-1'
          ELSEIF (INDEX(RATING,'TO-2').GT.0) THEN
          RATING = 'T/O-2'
          ELSEIF (INDEX(RATING,'TO-3').GT.0) THEN
          RATING = 'T/O-3'
          ENDIF
          
		BRAKES = 'ABSC 90002340PR'
		CERTIF = 'ANAC'
		IF (INDEX(ACTYPE,'EMBRAER190').GT.0) THEN
			ACTYPE = 'EMBRAER 190'
			IF ((RWYD(11).GT.20).AND.(RWYD(11).LT.30)) THEN		!Narrow Runway
				REVNBR = 'CAFM-40094_200'
				ACMDBI = 'CAFM-01334.DAT;191-05679-265.DAT'
				DATE = '14NOV2013;26AUG2009'
			ELSEIF (RWYD(11).GE.30) THEN						!"Wide" Runway
				IF ((INDEX(ENGTYP,'10E7').GT.0).OR.
     .				(INDEX(ENGTYP,'10E5A1').GT.0).OR.
     .                 (INDEX(ENGTYP,'10E5').GT.0)) THEN
					REVNBR = 'CAFM-40094_200'
					ACMDBI = '191-05677-300.DAT;191-05679-265.DAT'
					DATE = '19AUG2013;26AUG2009'
				ENDIF
			ENDIF
		ELSEIF (INDEX(ACTYPE,'EMBRAER195').GT.0) THEN
			ACTYPE = 'EMBRAER 195'
			IF ((RWYD(11).GT.20).AND.(RWYD(11).LT.30)) THEN		!Narrow Runway
				REVNBR = 'CAFM-40094_200'
				ACMDBI = 'CAFM-01335.DAT;191-05679-265.DAT'
				DATE = '14NOV2013;26AUG2009'
			ELSEIF (RWYD(11).GE.30) THEN						!"Wide" Runway
				IF (INDEX(ENGTYP,'10E7').GT.0) THEN
					REVNBR = 'CAFM-40094_200'
					ACMDBI = '191-05678-280.DAT;191-05679-257.DAT'
					DATE = '13JUN2019;03APR2008'
				ELSEIF (INDEX(ENGTYP,'10E6').GT.0) THEN
					REVNBR = 'CAFM-40094_200'
					ACMDBI = '191-05678-277.DAT;191-05679-256.DAT'
					DATE = '23AUG2013;03APR2008'
				ELSEIF (INDEX(ENGTYP,'10E5A1').GT.0) THEN
					REVNBR = 'CAFM-40094_200'
					ACMDBI = '191-05678-280.DAT;191-05679-256.DAT'
					DATE = '13JUN2019;03APR2008'
				ELSEIF (INDEX(ENGTYP,'10E5').GT.0) THEN
					REVNBR = 'CAFM-40094_200'
					ACMDBI = '191-05678-280.DAT;191-05679-256.DAT'
					DATE = '13JUN2019;03APR2008'	
				ENDIF
			ENDIF
		ENDIF
		RWYD(11) = 9E20


      ELSEIF (INDEX(ACTYPE,'AIRBUS330NEO').GT.0) THEN
          IF (INDEX(ENGTYP,'TRENT7000-STEP2').GT.0) THEN
			ACMDBI = 'AB941A09'
			MISCLA = 'XB941A09.pre'
			CERTIF = 'FAR'
          
          ELSEIF (INDEX(ENGTYP,'TRENT7000-STEP3').GT.0) THEN
			ACMDBI = 'AB941C02'
			MISCLA = 'XB941C02.pre'
			CERTIF = 'FAR'
          
          ENDIF
          
          SELECT CASE (INT(CONF(3)))
		CASE (1)
			FDCFGI = 'CONF 1+F'
		CASE (2)
			FDCFGI = 'CONF 2'
		CASE (3)
			FDCFGI = 'CONF 3'
		CASE DEFAULT
			FDCFGI = ''
        END SELECT
		CONF(3) = 9E20
          
          
      ELSEIF (INDEX(ACTYPE,'AIRBUS330').GT.0) THEN
          IF (INDEX(ENGTYP,'RR_TRENT_772B').GT.0) THEN
	        ACMDBI = 'AB243C02'
              MISCLA = 'XB243C02.pre'
	        CERTIF = 'FAR'
      
          ELSEIF (INDEX(ENGTYP,'CF6-80E1A4').GT.0) THEN
		    ACMDBI = 'AB202D03'
		    MISCLA = 'XB202D03.pre'
		    CERTIF = 'FAR'
      
          ENDIF
      
		SELECT CASE (INT(CONF(3)))
		CASE (1)
			FDCFGI = 'CONF 1+F'
		CASE (2)
			FDCFGI = 'CONF 2'
		CASE (3)
			FDCFGI = 'CONF 3'
		CASE DEFAULT
			FDCFGI = ''
		END SELECT
		CONF(3) = 9E20


	ELSEIF (INDEX(ACTYPE,'AIRBUS320').GT.0) THEN
	!	ACMDBI = 'AE251A02'
	!	MISCLA = 'XE251A02.PRE'
	!	CERTIF = 'EASA'


		IF (INDEX(ENGTYP,'SHARP').GT.0) THEN
			IF (INDEX(ENGTYP,'1A26SHARP').GT.0) THEN
				ACMDBI = 'AE251C01'
				MISCLA = 'XE251C01.PRE'
				CERTIF = 'EASA'
			ELSE
				ACMDBI = 'AE253B01'
				MISCLA = 'XE253B01.PRE'
				CERTIF = 'EASA'			
			ENDIF
		ELSEIF (INDEX(ENGTYP,'NORMAL').GT.0) THEN
			IF 	(INDEX(ENGTYP,'1A26NORMAL').GT.0) THEN
				ACMDBI = 'AE251A05'
				MISCLA = 'XE251A05.PRE'
				CERTIF = 'EASA'
			ELSE
				ACMDBI = 'AE253A01'
				MISCLA = 'XE253A01.PRE'
				CERTIF = 'EASA'			
			ENDIF
		ELSEIF (INDEX(ENGTYP,'214CEOSHARK').GT.0) THEN
				ACMDBI = 'AE214G02'
				MISCLA = 'XE214G02.PRE'
				CERTIF = 'EASA'
			ELSE
				ACMDBI = 'AE214E03'
				MISCLA = 'XE214E03.PRE'
				CERTIF = 'EASA'			
		ENDIF

		SELECT CASE (INT(CONF(3)))
		CASE (1)
			FDCFGI = 'CONF 1+F'
		CASE (2)
			FDCFGI = 'CONF 2'
		CASE (3)
			FDCFGI = 'CONF 3'
		CASE DEFAULT
			FDCFGI = ''
		END SELECT
		CONF(3) = 9E20
		
	ELSEIF (INDEX(ACTYPE,'AIRBUS321').GT.0) THEN
			ACMDBI = 'AC251B01'
			MISCLA = 'XC251B01.PRE'
			CERTIF = 'EASA'
		SELECT CASE (INT(CONF(3)))
		CASE (1)
			FDCFGI = 'CONF 1+F'
		CASE (2)
			FDCFGI = 'CONF 2'
		CASE (3)
			FDCFGI = 'CONF 3'
		CASE DEFAULT
			FDCFGI = ''
		END SELECT
		CONF(3) = 9E20
		
      ELSEIF (INDEX(ACTYPE,'AIRBUSF321').GT.0) THEN
          IF (INDEX(ENGTYP,'IAE_V2533_A5').GT.0) THEN
		ACMDBI = 'AC231M01'
		MISCLA = 'XC231M01.PRE'
		CERTIF = 'EASA'
      
          ELSEIF (INDEX(ENGTYP,'CFM_56_5B3_3').GT.0) THEN
		    ACMDBI = 'AC211K01'
		    MISCLA = 'XC211K01.pre'
		    CERTIF = 'EASA'
      
          ENDIF
      
		SELECT CASE (INT(CONF(3)))
		CASE (1)
			FDCFGI = 'CONF 1+F'
		CASE (2)
			FDCFGI = 'CONF 2'
		CASE (3)
			FDCFGI = 'CONF 3'
		CASE DEFAULT
			FDCFGI = ''
		END SELECT
		CONF(3) = 9E20
		
	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	ELSEIF (INDEX(ACTYPE,'737').GT.0) THEN
		IF (INDEX(ENGTYP,'CFM56-3C-1').GT.0) THEN
			ACTYPE='737-400'
			ACMDBI='B33C.BDB'
			RATING=''
			BRAKES='CAT_A'
			CERTIF='FAA'
		ELSEIF (INDEX(ENGTYP,'CFM56-3B-2').GT.0) THEN ! (DATABASE 22K)
			ACTYPE='737-400'
			ACMDBI='B342.BDB'
			RATING=''
			BRAKES='CAT_A'
			CERTIF='FAA'
		ENDIF
	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	
	ELSE
		CERTIF = 'FAR'
		IF (INDEX(ENGTYP,'PW127M_M').GT.0) THEN
			ACMDBI = 'MUE6DC3A.PDF'
	    ELSEIF (INDEX(ENGTYP,'PW127F_M').GT.0) THEN
			ACMDBI = 'MUE6DC3A.PDF'
		ELSE
			ACMDBI = 'MUE6DB3D.PDF'
		ENDIF
		ACTYPE = ''
	ENDIF

C	************* V2/VS FIXA ******************************************
	IF (INDEX(ACTYPE,'E2').GT.0) THEN
		V2VS(1) = 1.18
		V2VS(2) = 1.22
		V2VS(3) = 1.18
		V2VS(4)	= 1.18
	ELSEIF (INDEX(ACTYPE,'190').GT.0) THEN
		V2VS(1) = 1.18
		V2VS(2) = 1.17
		V2VS(3) = 1.17
		V2VS(4) = 1.19
	ELSE
		V2VS(1) = 1.18
		V2VS(2) = 1.17
		V2VS(3) = 1.17
		V2VS(4) = 1.21	
	ENDIF

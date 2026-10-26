"""Tabela de aeronaves: qual banco (TINPA) cada aeronave/motor usa.

Traduzido do bloco TINPA do INPUT.FOR. ACTYPE segue os mesmos nomes do
takeoff_data.dat (AIRBUS320, AIRBUS330, AIRBUS330NEO, EMBRAER195, E195-E2...).

Motores de calculo (Aircraft.engine):
  octopus         Airbus: scap_octopus.dll le scap.in / grava SCAP.OUT
  ttam            ATR: TTAM do DllWrapperATR.so (Linux), dados nos COMMON
  takeoff_module  Embraer E1/E2: takeoff_module.exe (Wine) com takeoff_data.dat
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class Variant:
    engtyp: str          # nome do motor como no takeoff_data.dat (ENGTYP)
    acmdbi: str
    miscla: str = ""
    certif: str = ""
    example: str = ""    # scap.in base deste motor (takeoff/templates/)
    rating: str = ""     # RATING do takeoff_data.dat (ATR/Embraer)
    mtow: float = 0      # POPT(24) (ATR/Embraer; no Airbus vem do exemplo)
    label: str = ""      # nome na tela, quando difere do ENGTYP

    @property
    def display(self):
        return self.label or self.engtyp


# POPT(30): limite dianteiro de CG. A base de cada aeronave so aceita alguns
# (testado no motor: as outras opcoes dao erro). No A320/A321 a opcao 1 e o
# Extended FWD (limite mais dianteiro: diminui o MTOW no A320). O A321neo da
# frota so tem o envelope Basic (a base aceita os dois).
CG_STANDARD = ((0, "Standard"),)
CG_EMBRAER = ((0, "Standard"), (1, "Alternate 1"))
CG_A320 = ((0, "Standard"), (1, "Extended FWD"))
CG_A330NEO = ((0, "Standard"), (1, "Alternate"), (2, "2nd Alternate"),
              (4, "3rd Alternate"))


@dataclass(frozen=True)
class Aircraft:
    name: str            # nome mostrado na tela
    actype: str          # ACTYPE do takeoff_data.dat
    engine: str          # motor de calculo: octopus, ttam (ATR), etm170 (E1)
    variants: tuple
    align: str = ""      # ACFT no toalign_list.csv (POPT 12/13)
    cg: tuple = CG_STANDARD   # limites dianteiros de CG aceitos (POPT 30)
    mtows: tuple = ()         # MTOW estruturais da frota (POPT 24, kg) para
                              # escolher na tela; vazio = so o da base
    mlw: float = 0            # MLW certificado (kg): teto de todo pouso
                              # (POPTL 9); 0 = sem cadastro (so o limite da base)

    @property
    def supported(self):
        return self.engine in ("octopus", "ttam", "takeoff_module")


AIRCRAFT = (
    Aircraft("A320", "AIRBUS320", "octopus", (
        Variant("1A26NORMAL", "AE251A05", "XE251A05.PRE", "EASA",
                "scap_A320-1A26NORMAL.in.example", label="LEAP-1A26 · Normal"),
        Variant("1A26SHARP", "AE251C01", "XE251C01.PRE", "EASA",
                "scap_A320-1A26SHARP.in.example", label="LEAP-1A26 · Sharp"),
        Variant("1A29SHARP", "AE253B01", "XE253B01.PRE", "EASA",
                "scap_A320-1A29SHARP.in.example", label="LEAP-1A29 · Sharp"),
    ), align="AIRBUS 320", cg=CG_A320, mtows=(77000, 79000), mlw=67400),
    Aircraft("A321neo", "AIRBUS321", "octopus", (
        Variant("1A32-NX", "AC251B01", "XC251B01.PRE", "EASA",
                "scap_A321-1A32-NX.in.example", label="LEAP-1A32"),
    ), align="AIRBUS 321", mlw=79200),  # so o envelope Basic (Standard) na frota
    Aircraft("A321F", "AIRBUSF321", "octopus", (
        Variant("CFM_56_5B3_3", "AC211K01", "XC211K01.pre", "EASA",
                "scap_A321F-CFM_56_5B3_3.in.example", label="CFM56-5B3"),
        Variant("IAE_V2533_A5", "AC231M01", "XC231M01.PRE", "EASA",
                "scap_A321F-IAE_V2533_A5.in.example", label="IAE V2533-A5"),
    ), align="AIRBUSF321", mlw=77800),
    Aircraft("A330", "AIRBUS330", "octopus", (
        Variant("RR_TRENT_772B", "AB243C02", "XB243C02.pre", "FAR",
                "scap_A330-RR_TRENT_772B.in.example", label="RR Trent 772B"),
    ), align="AIRBUS 330", mlw=182000),
    Aircraft("A330neo", "AIRBUS330NEO", "octopus", (
        Variant("TRENT7000-STEP3", "AB941C02", "XB941C02.pre", "FAR",
                "scap_A330NEO-TRENT7000-STEP3.in.example", label="RR Trent 7000 · Step 3"),
    ), align="AIRBUS 330 NEO", cg=CG_A330NEO, mlw=191000),
    # ACMDBI do ATR conforme o INPUT.FOR (PW127M_M/PW127F_M -> MUE6DC3A)
    Aircraft("ATR 72-600", "ATR72-600", "ttam", (
        Variant("PW127M_M", "MUE6DC3A.PDF", "", "FAR", rating="BOOSTON+RTOON",
                mtow=23000, label="PW127M · Boost ON"),
        Variant("PW127M_M", "MUE6DC3A.PDF", "", "FAR", rating="BOOSTOFF+RTOON",
                mtow=23000, label="PW127M · Boost OFF"),
        Variant("PW127F_M", "MUE6DC3A.PDF", "", "FAR", rating="BOOSTOFF+RTOON",
                mtow=22800, label="PW127F · Boost OFF"),
        Variant("PW127XT_M", "MUE6DB3D.PDF", "", "FAR", rating="BOOSTON+RTOON",
                mtow=23000, label="PW127XT · Boost ON"),
    ), align="ATR 72-600", mlw=22350),
    # E195 (E1): o takeoff_module escolhe a base pela largura da pista
    # (INPUT.FOR); aqui ficam a de pista larga (>= 30 m) e a de pista estreita.
    Aircraft("E195", "EMBRAER195", "takeoff_module", (
        Variant("CF34-10E5A1", "191-05678-280.DAT;191-05679-256.DAT;"
                "CAFM-01335.DAT;191-05679-265.DAT", "", "ANAC",
                rating="TO-1", mtow=50790),
    ), align="EMBRAER 195", cg=CG_EMBRAER, mlw=45000),
    Aircraft("E195-E2", "E195-E2", "takeoff_module", (
        Variant("PW1923G-A", "CAFM-ADB-069.pdm;CAFM-EDB-015.pdm", "", "ANAC",
                rating="TO-1", mtow=62000),
    ), align="E195-E2", cg=CG_EMBRAER, mlw=54000),
)


# CLIMIT(2) = deflexao slat/flap -> nome do flap (takeoff_module.for)
FLAP_NAMES = {
    "AIRBUS320": {1810: "CONF 1+F", 2215: "CONF 2", 2220: "CONF 3"},
    "AIRBUS321": {1810: "CONF 1+F", 2214: "CONF 2", 2221: "CONF 3"},
    "AIRBUSF321": {1810: "CONF 1+F", 2214: "CONF 2", 2221: "CONF 3"},
    "AIRBUS330": {1608: "CONF 1+F", 2014: "CONF 2", 2322: "CONF 3"},
    "AIRBUS330NEO": {1608: "CONF 1+F", 2015: "CONF 2", 2323: "CONF 3"},
}


def flap_options(aircraft):
    """[(codigo, nome)] dos flaps de decolagem que podem ser fixados no
    calculo (codigo = Conditions.flap). Vazio = so o otimo."""
    if aircraft.engine == "octopus":
        return sorted(FLAP_NAMES.get(aircraft.actype, {}).items(),
                      key=lambda item: item[1])
    if aircraft.engine == "ttam":
        return [(15, "FLAP 15")]        # a base do ATR so tem o FLAP 15
    return [(n, f"FLAP {n}") for n in (1, 2, 3, 4)]

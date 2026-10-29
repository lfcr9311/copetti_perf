#!/usr/bin/env python3
"""Pouso (despacho) do ATR 72-600 pelo TLAM da ATR (pacote SCAP APS 2.7.1) - em teste.

Usa o programa oficial da ATR: SCAPApp.exe + SCAPLibrary.dll (que confere a
licenca) + TLAM.dll, com entrada e saida em XML (IATA Alternate SCAP Interface
- XML Standard; ver engines/atr/SCAP_APS_2.7.1/docs). Roda pelo Wine (precisa do Mono do
Wine). O TLAM nunca e chamado direto: a licenca da ATR vale a cada calculo.

Campos: manual TLAM B2-O9 (OCT 2025). Base: MUE6DC3E.PDF (PW127F/M/N, freios
Meggitt 10.9 MJ), a que vem no pacote.

    python3 -m perf.landing.atr                            # SBRJ 20L, 25 C
    python3 -m perf.landing.atr --icao SBKG --rwy 15 --molhada
"""

import argparse
from dataclasses import dataclass
from typing import Optional

from ..catalog.airports import load_airports
from ..scapapp import BASE, ScapAppError, rodar
from ..scapapp import xml_entrada as xml_scap


# CLIMIL(6) do TLAM (codigos do FOS)
LIMITES = {
    0: "Desempenho em pista molhada (wet check)",
    1: "Peso máximo (MLW informado ou limite da base)",
    2: "Distância de pouso (LDA)",
    3: "Gradiente de arremetida (approach climb)",
    4: "Gradiente de subida de pouso (landing climb)",
    5: "Velocidade dos pneus",
    6: "Energia de freio",
}
# flap de pouso -> (CONFL(5) pouso, CONFL(3) arremetida), em graus
FLAPS = {"30": (30, 15)}



@dataclass
class PousoATR:
    """Entrada (m, ft, %, C, hPa, kt, kg)."""
    lda: float
    elev: float
    slope: float = 0.0
    temp: float = 15.0
    qnh: float = 1013.25
    vento: float = 0.0            # + proa, - cauda
    molhada: bool = False
    flap_pouso: int = 30          # CONFL(5), graus
    flap_arremetida: int = 15     # CONFL(3), graus
    reverso: int = 0              # CONFL(10): 0 sem credito, 1 todos
    icing: bool = False           # CONFL(7): 6 = condicao de gelo atmosferico
    boost: int = 2                # CONFL(45): 1 off, 2 on, 3 super (0 nao vale na MUE6DC3E)
    motor: str = "PW127M"         # ENGTYL
    mlw: Optional[float] = None   # POPTL(9)
    ga_grad: Optional[float] = None


class PousoError(Exception):
    pass


def blocos(p):
    # pista molhada (acerto com o engenheiro): modo operacional POPTL(36) = 1,
    # que exige a acao de frenagem POPTL(4) (5 = Good, pista molhada no RCAM),
    # credito de reverso CONFL(10) = 1 e LDA informada dividida por 1,15
    rev = 1 if p.molhada else p.reverso
    P = {1: 0, 2: 1 if p.molhada else 0, **({4: 5} if p.molhada else {}), 5: 0, 7: 11,
         8: 1 if p.mlw else 0, **({9: p.mlw} if p.mlw else {}),
         12: 0, 13: 0, 15: 0, 16: 0,
         17: 1 if p.ga_grad else 0, **({18: p.ga_grad} if p.ga_grad else {}),
         19: 0, 21: 0, 23: 0, 25: 0, 26: 0, 29: 0, 34: 0,
         36: 1 if p.molhada else 0,   # despacho / RLD
         38: 0}                       # wet check: sempre 0 (seca e molhada)
    C = {1: 1, 2: 0, 3: p.flap_arremetida, 4: 0, 5: p.flap_pouso,
         6: 2, 7: 6 if p.icing else 0, 9: 0, 10: rev,
         **({11: 0} if rev else {}),
         12: 0, 15: 0, 18: 0, 19: 0, 21: 0, 24: 0, 30: 1, 41: 0, 45: p.boost}
    X = {1: p.temp, 2: p.vento, 4: 1, 5: p.qnh}
    R = {1: p.elev, 2: p.lda / 1.15 if p.molhada else p.lda, 3: p.slope, 4: 0, 5: 1, 6: 0}
    U = {1: 0, 3: 0, 4: 1, 5: 1, 6: 0, 8: 0, 9: 2}
    return {"POPTL": P, "CONFL": C, "XMETL": X, "RWYDL": R, "UNITL": U}


def textos(p):
    return {"ACTYPL": "ATR72-600", "ENGTYL": p.motor, "BRAKEL": "MEGGITT 10.9 MJ",
            "AMDBIL": BASE, "CERTIL": "FAR", "APTIDL": "", "RWYNBL": "", "MISCLL": "",
            "FDCFGA": "", "FDCFGL": ""}


def xml_entrada(p):
    return xml_scap("LANDING", blocos(p), textos(p))


def calcular(p, timeout=180, slot=""):
    """slot: pasta de trabalho (work/atrpouso<slot>); slots diferentes rodam
    em paralelo."""
    try:
        arrays, elementos = rodar(f"atrpouso{slot}", xml_entrada(p), timeout)
    except ScapAppError as e:
        raise PousoError(str(e))
    c = arrays.get("CLIMIL", {})
    g = lambda i: c.get(i) if isinstance(c.get(i), float) else None
    codigo = g(6)
    msgs = [v for _, v in sorted(arrays.get("ERRMSL", {}).items()) if isinstance(v, str) and v.strip()]
    return {"mlw": g(1), "limitante": LIMITES.get(int(codigo), f"código {codigo:g}") if codigo is not None else "",
            "gradiente_arremetida": g(14), "gradiente_pouso": g(15),
            "vapp": g(22), "v_arremetida": g(23), "ld": g(12), "ld_exigida": g(13),
            "principal": {
                "MAXIMUM LANDING WEIGHT": g(1), "LIMITATION CODE": codigo,
                "WEIGHT LIMITED BY LDA": g(7), "WEIGHT LIMITED BY ACG": g(8),
                "WEIGHT LIMITED BY LCG": g(9), "WEIGHT LIMITED BY BRAKE ENERGY": g(11),
                "ACTUAL LD": g(12), "LD REQUIRED FOR MAX LD WEIGHT": g(13),
                "ACG FOR MAX LD WEIGHT (%)": g(14), "LCG FOR MAX LD WEIGHT (%)": g(15)},
            "erflag": elementos.get("ERFLAL", ""), "mensagens": msgs,
            "entrada": xml_entrada(p)}


def main():
    a = argparse.ArgumentParser(description="Pouso do ATR 72-600 (despacho), em teste")
    a.add_argument("--icao", default="SBRJ")
    a.add_argument("--rwy", default="20L")
    a.add_argument("--temp", type=float, default=25)
    a.add_argument("--qnh", type=float, default=1013.25)
    a.add_argument("--vento", type=float, default=0)
    a.add_argument("--molhada", action="store_true")
    a.add_argument("--lda", type=float)
    a.add_argument("--mlw", type=float)
    a.add_argument("--boost-off", action="store_true")
    a.add_argument("--mostrar-entrada", action="store_true")
    args = a.parse_args()
    rw = load_airports()[args.icao.upper()]["runways"][args.rwy]
    p = PousoATR(lda=args.lda or rw.tora, elev=rw.elev, slope=rw.slope, temp=args.temp,
                 qnh=args.qnh, vento=args.vento, molhada=args.molhada, mlw=args.mlw,
                 boost=1 if args.boost_off else 2)
    if args.mostrar_entrada:
        print(xml_entrada(p).replace("\r", ""))
    r = calcular(p)
    for k, v in r["principal"].items():
        print(f"  {k:34s} {'–' if v is None else f'{v:,.2f}'}")
    print(f"\nPeso máximo de pouso: {r['mlw'] and round(r['mlw'])} kg · {r['limitante']}")
    print(f"ERFLAG: {r['erflag']}  {r['mensagens'][:3]}")


if __name__ == "__main__":
    main()

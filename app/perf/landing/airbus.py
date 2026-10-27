#!/usr/bin/env python3
"""Pouso (despacho) do Airbus pelo scap_octopus.dll - em teste.

Monta um scap.in de pouso (primeira linha 2, blocos POPTL/CONFL/XMETL/RWYDL/
UNITL do manual PEP 5.15 - SCAP TO LDG), roda a DLL como a decolagem e le o
peso maximo de pouso (CLIMIL). Usado pela aba Pouso do app e pela linha de
comando:

    python3 -m perf.landing.airbus                          # A320, SBRJ 20L, 25 C
    python3 -m perf.landing.airbus --icao SBKP --rwy 15 --temp 30 --molhada
    python3 -m perf.landing.airbus --conf 3 --lda 1200 --vento -5 --mostrar-entrada

LDA: o airports_list.csv nao tem LDA; sem --lda usa a TORA da pista.
"""

import argparse
import re
from dataclasses import dataclass
from typing import Optional

from ..catalog.aircraft import AIRCRAFT, CG_A320, CG_A330NEO, CG_STANDARD
from ..catalog.airports import load_airports
from ..paths import folder_lock
from ..takeoff.airbus import prepare_workdir, run_dll

NA = 9e20

# configuracao de pouso -> (codigo slat/flap do pouso, codigo da arremetida)
# codigo = slat*100 + flap, como o CLIMIL(2)/(4) do SCAP.OUT; conferidos no
# status de cada base (CONF FULL / CONF 3 / CONF 2...). Arremetida: CONF 3
# no pouso FULL, CONF 2 no pouso CONF 3.
CONF_POUSO = {
    "AIRBUS320": {"FULL": (2740, 2220), "3": (2220, 2215)},
    "AIRBUS321": {"FULL": (2734, 2221), "3": (2221, 2214)},
    "AIRBUSF321": {"FULL": (2725, 2221), "3": (2221, 2214)},
    "AIRBUS330": {"FULL": (2332, 2322), "3": (2322, 2014)},
    "AIRBUS330NEO": {"FULL": (2332, 2323), "3": (2322, 2015)},
}

# POPTL(12): envelope de CG (limite dianteiro). A320: Standard ou Extended FWD
# (muda o pouso); A330neo: os mesmos da decolagem (a base aceita, o resultado
# nao muda). A321neo (frota so Basic), A321F e A330: so Standard (as outras
# opcoes dao erro na base).
CG_POUSO = {"AIRBUS320": CG_A320, "AIRBUS330NEO": CG_A330NEO}


# RWYDL(4) grooved/PFC: so estas bases aceitam no pouso (A321F e A330 dao
# "GROOVED/PFC NOT AVAILABLE WITH THIS AIRCRAFT"); nas outras, pista normal
GROOVED_POUSO = {"AIRBUS320", "AIRBUS321"}


def envelopes(actype):
    """[(POPTL 12, nome)] dos envelopes de CG de pouso da aeronave."""
    return CG_POUSO.get(actype, CG_STANDARD)

# CLIMIL(6): codigo do limitante
LIMITES = {
    1: "Peso máximo de pouso informado (MLW)",
    2: "Distância de pouso (LDA)",
    3: "Gradiente de arremetida (approach climb)",
    4: "Gradiente de subida de pouso (landing climb)",
    5: "Velocidade dos pneus",
    6: "Energia de freio",
    9: "Distância de pouso com motor inoperante",
}



@dataclass
class Pouso:
    """Entrada de um calculo de pouso (unidades: m, ft, %, C, hPa, kt, kg)."""
    lda: float
    elev: float
    slope: float = 0.0
    temp: float = 15.0
    qnh: float = 1013.25
    vento: float = 0.0            # + proa, - cauda
    molhada: bool = False
    conf_pouso: int = 2740
    conf_arremetida: int = 2220
    reverso: int = 0              # CONFL(10): 0 sem credito, 1 todos os reversos
    antigelo: int = 0             # CONFL(7): 0 OFF, 1 motor, 3 motor e asa
    ar: int = 2                   # CONFL(6): 1 ON, 2 OFF
    mlw: Optional[float] = None   # None = maximo computacional da base
    athr: bool = False            # MAN-A/THR on: VAPP = VREF + 5 kt; off = VREF (padrao)
    grooved: bool = False         # RWYDL(4): 0 normal, 2 grooved/PFC
    ga_grad: Optional[float] = None   # gradiente de arremetida exigido (%); None = STD
    peso: Optional[float] = None      # so no modo distancias: peso de pouso (LW)
    cg: int = 0                   # POPTL(12): envelope de CG (ver CG_POUSO)


class PousoError(Exception):
    pass


def numero(bloco, i, valor):
    # o Fortran le com G14.8: sem ponto decimal, 1 vira 0.00000001
    return f"{bloco:5s} {i:3d}= {float(valor):14.7f}\n"


def entrada(variant, p):
    linhas = ["2\n"]
    teto = p.peso or p.mlw
    blocos = {
        "POPTL": {1: 1 if p.peso else 0,   # 0 pesos limite; 1 distancias no peso (LW)
                  2: 1 if p.molhada else 0,
                  8: 1 if teto else 0,
                  **({9: teto} if teto else {}),
                  11: 0,            # arremetida sem bump
                  12: p.cg,         # envelope de CG: 0 Standard, 1 Extended FWD (A320)
                  # tecnica de pouso: A/THR on soma 5 kt a VREF (POPTL 13/14),
                  # como o despacho do EFB (MAN-A/THR on); off = VREF
                  13: 1 if p.athr else 0, **({14: 5} if p.athr else {}),
                  16: 0,
                  # gradiente de arremetida: STD (regulamento) ou exigido
                  17: 1 if p.ga_grad else 0, **({18: p.ga_grad} if p.ga_grad else {}), 19: 0, 21: 0, 23: 0, 25: 0, 26: 0,
                  32: 1,            # sem pre-calculo
                  34: 0},
        "CONFL": {1: 1, 2: p.conf_arremetida, 4: p.conf_pouso,
                  6: p.ar, 7: p.antigelo, 8: 0, 9: 0,
                  10: p.reverso,
                  11: 0, 12: 0, 13: 0, 15: 0,
                  16: 0,            # autobrake OFF
                  24: 0, 27: 0,
                  30: 1,            # pouso manual
                  34: 0,            # sem gelo residual
                  40: 0, 45: 0, 46: 0},
        "XMETL": {1: p.temp, 2: p.vento, 4: 1, 5: p.qnh},
        "RWYDL": {1: p.elev, 2: p.lda, 3: p.slope,
                  4: 2 if p.grooved else 0,     # superficie: grooved/PFC ou normal
                  5: 1, 6: 0, 7: 0},
        "UNITL": {1: 0, 2: 0, 3: 0, 4: 1, 5: 0, 6: 0, 8: 0, 9: 2},
    }
    for bloco, valores in blocos.items():
        linhas.append(f"Common {bloco} ------------------------------\n")
        linhas += [numero(bloco, i, v) for i, v in valores.items()]
    linhas.append("Common LINPA (texto) ------------------------------\n")
    linhas.append(f"AMDBIL   = {variant.acmdbi}\n")
    linhas.append(f"CERTIL   = {variant.certif}\n")
    return "".join(linhas)


def ler_saida(texto):
    """MAIN RESULTS (nome -> valor ou None), ERFLAG e mensagens (ERRMSL)."""
    principal = {}
    bloco = texto.split("**************** ALL RESULTS")[0]
    for nome, valor in re.findall(r"^(.+?)\s*->\s*(\S+)", bloco, re.M):
        try:
            v = float(valor)
        except ValueError:
            continue
        principal[nome.strip()] = None if v >= NA * 0.99 else v
    flag = re.search(r"ERFLA\w*\s*[=:]?\s*(\S+)", texto)
    msgs = [m.strip() for m in re.findall(r"ERRMSL[ \t]*\d+[ \t]*:[ \t]*(.*)", texto) if m.strip()]
    return principal, (flag.group(1) if flag else ""), msgs


def ler_climil(texto):
    """Array CLIMIL do 'ALL RESULTS' (posicao 1 = indice 0); None = sem valor."""
    m = re.search(r"---------- CLIMIL\n(.*?)\n----------", texto, re.S)
    if not m:
        return []
    return [None if float(x) >= NA * 0.99 else float(x) for x in m.group(1).split()]


def calcular(variant, p, slot=""):
    """Roda o pouso e devolve mlw, limitante, gradientes, resultados,
    mensagens e o scap.in. Com p.peso, calcula no peso informado (sem MLW).
    slot: pasta de trabalho (work/wpouso<slot>); calculos em slots
    diferentes rodam em paralelo."""
    texto = entrada(variant, p)
    with folder_lock(f"wpouso{slot}"):
        pasta = prepare_workdir(variant, f"pouso{slot}")
        (pasta / "scap.in").write_text(texto)
        saida = pasta / "SCAP.OUT"
        for _ in range(3):      # falha esporadica no Wine (OCTOCNF): repetir passa
            saida.unlink(missing_ok=True)
            proc = run_dll(pasta)
            if not saida.exists():
                raise PousoError("A DLL não gerou SCAP.OUT.\n" + (proc.stdout + proc.stderr)[-1500:])
            out = saida.read_text(errors="replace")
            if "OCTOCNF" not in out:
                break
    principal, flag, msgs = ler_saida(out)
    c = ler_climil(out)
    if flag not in ("A", "D") and not p.peso and not (c and c[0]):
        if any(m.startswith(("NOWELN", "EAC1LN")) for m in msgs):
            raise PousoError("Nenhum peso de pouso possível para esta LDA: o peso máximo fica abaixo do "
                             "peso mínimo da base do motor. Confira a LDA e as opções (ex. A/THR).\n"
                             + "\n".join(msgs[:2]))
        raise PousoError(f"ERFLAG = {flag or '?'}\n" + "\n".join(msgs[:6]))
    g = lambda i: c[i - 1] if len(c) >= i else None
    codigo = g(6)
    return {"mlw": g(1), "limitante": LIMITES.get(int(codigo), f"código {codigo:g}") if codigo else "",
            "gradiente_arremetida": g(14), "gradiente_pouso": g(15),
            "vapp": g(22), "v_arremetida": g(23), "ld": g(12), "ld_exigida": g(13),
            "principal": principal, "erflag": flag, "mensagens": msgs, "entrada": texto}


def main():
    a = argparse.ArgumentParser(description="Pouso do Airbus (despacho), em teste")
    a.add_argument("--aeronave", default="A320")
    a.add_argument("--motor", type=int, default=0, help="indice do motor (0 = primeiro)")
    a.add_argument("--icao", default="SBRJ")
    a.add_argument("--rwy", default="20L")
    a.add_argument("--temp", type=float, default=25)
    a.add_argument("--qnh", type=float, default=1013.25)
    a.add_argument("--vento", type=float, default=0, help="+ proa, - cauda (kt)")
    a.add_argument("--molhada", action="store_true")
    a.add_argument("--lda", type=float, help="LDA em metros (padrao: TORA)")
    a.add_argument("--conf", default="FULL", help="FULL ou 3")
    a.add_argument("--mlw", type=float, help="peso maximo de pouso (kg)")
    a.add_argument("--athr-on", action="store_true", help="MAN-A/THR on (VAPP = VREF + 5 kt); padrao off")
    a.add_argument("--grooved", action="store_true", help="pista grooved/PFC")
    a.add_argument("--cg", type=int, default=0, help="envelope de CG (POPTL 12): 0 Standard, 1 Extended FWD (A320)")
    a.add_argument("--ga", type=float, help="gradiente de arremetida exigido (%%); padrao STD")
    a.add_argument("--lw", type=float, help="peso de pouso: mostra gradiente/VAPP/LD nesse peso")
    a.add_argument("--mostrar-entrada", action="store_true")
    args = a.parse_args()

    ac = next(x for x in AIRCRAFT if x.name == args.aeronave)
    v = ac.variants[args.motor]
    rw = load_airports()[args.icao.upper()]["runways"][args.rwy]
    pouso, arremetida = CONF_POUSO[ac.actype][args.conf.upper()]
    p = Pouso(lda=args.lda or rw.tora, elev=rw.elev, slope=rw.slope, temp=args.temp,
              qnh=args.qnh, vento=args.vento, molhada=args.molhada,
              conf_pouso=pouso, conf_arremetida=arremetida, mlw=args.mlw,
              athr=args.athr_on, grooved=args.grooved, ga_grad=args.ga, cg=args.cg)
    r = calcular(v, p)
    if args.mostrar_entrada:
        print(r["entrada"])
    print(f"{ac.name} {v.display} · {args.icao.upper()} {args.rwy} · LDA {p.lda:g} m · "
          f"{p.temp:g} °C · vento {p.vento:+g} kt · QNH {p.qnh:g} · "
          f"{'molhada' if p.molhada else 'seca'} · CONF {args.conf.upper()}\n")
    for nome, valor in r["principal"].items():
        print(f"  {nome:38s} {'–' if valor is None else f'{valor:,.1f}'}")
    print(f"\nPeso máximo de pouso: {r['mlw'] and round(r['mlw'])} kg · {r['limitante'] or '–'}")
    print(f"Gradiente de arremetida (motor inop.) no MLW: {r['gradiente_arremetida']} % · VAPP {r['vapp']} kt")
    if args.lw:
        from dataclasses import replace
        w = calcular(v, replace(p, peso=args.lw))
        print(f"No peso {args.lw:g} kg: gradiente {w['gradiente_arremetida']} % · VAPP {w['vapp']} kt · LD {w['ld']} m")
    print(f"ERFLAG: {r['erflag']}")
    for m in r["mensagens"][:10]:
        print("  " + m)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Pouso (despacho) da Embraer pelas DLLs da Embraer - em teste.

    E195 (E1):          ELM170 (manual ELM170 rev 30), rotina ELM170DLL
    E195-E2 (PW1923G-A): ELME2 dentro do ETME2_v301.dll (manual ELME2 rev 17)


As duas trocam dados pelos mesmos blocos COMMON (Annex III / Annex II):
    /LINPN/ POPTL, CONFL, XMETL, RWYDL, UNITL, SPIAL, SPIBL, SPICL, IFCIN (200 REAL*4 cada)
    /LINPA/ ACTYPL ... IFCFIL (texto, tamanho fixo)
    /LOUTN/ CLIMIL(200), IFCNUM(200)        /LOUTA/ ERFLAL, ERRMSL(20) ...
O engines/loader/scaploader.exe (C, roda pelo Wine) copia os blocos montados aqui
para a DLL, chama a rotina e devolve os blocos de saida.

    python3 -m perf.landing.embraer                         # E195, SBRJ 20L, 25 C
    python3 -m perf.landing.embraer --icao SBKG --rwy 15 --molhada --flap 5
    python3 -m perf.landing.embraer --modelo E195-E2 --icao SBRJ --rwy 20L
"""

import argparse
import os
import platform
import shutil
import struct
import subprocess
import threading
from dataclasses import dataclass
from typing import Optional

from ..catalog.airports import load_airports
from ..paths import LOADER, WORK_DIR, drop_broken_link, find_file

NA = 9e20

BLOCOS = ("POPTL", "CONFL", "XMETL", "RWYDL", "UNITL", "SPIAL", "SPIBL", "SPICL", "IFCIN")
TEXTOS = (("ACTYPL", 20, 1), ("ENGTYL", 20, 1), ("RATINL", 20, 1), ("BRAKEL", 20, 1),
          ("CERTIL", 20, 1), ("REVNBL", 20, 1), ("DATEL", 20, 1), ("DBOPTL", 20, 1),
          ("AMDBIL", 255, 1), ("APTIDL", 20, 1), ("RWYNBL", 20, 1), ("COMENL", 132, 20),
          ("MISCLL", 255, 1), ("FDCFGA", 20, 1), ("FDCFGL", 20, 1), ("CDLFLL", 255, 1),
          ("IFCFIL", 255, 1))
LOUTN_BYTES = 400 * 4                       # CLIMIL(200), IFCNUM(200)
LOUTA_BYTES = 20 + 80 * 20 + 20 + 20 + 255 + 80 * 20 + 80 * 200

# modulo e base de cada modelo (manuais ELM170 Annex I e ELME2 sec. 5)
MODELOS = {
    "E195": {"tipo": "e1", "dll": "ELM170v100_CAFM-20050_200.dll", "rotina": "ELM170DLL",
             "simbolos": ("LINPN", "LINPA", "LOUTN", "LOUTA"),
             "copiar": ("DFORRT.DLL",),
             "texto": {"ACTYPL": "EMBRAER 195", "ENGTYL": "CF34-10E5A1", "RATINL": "GA",
                       "BRAKEL": "ABSC 90002340PR", "CERTIL": "ANAC",
                       "REVNBL": "CAFM-20050_200", "DATEL": "13JUN2019;03APR2008",
                       "AMDBIL": "191-05678-280.DAT;191-05679-256.DAT"}},
    # o ELME2 esta no mesmo ETME2_v301.dll da decolagem (simbolos minusculos)
    "E195-E2": {"tipo": "e2", "dll": "ETME2_v301.dll", "rotina": "ELME2",
                "simbolos": ("linpn", "linpa", "loutn", "louta"),
                "copiar": ("msvcr120.dll",),
                "texto": {"ACTYPL": "E195-E2", "ENGTYL": "PW1923G-A", "RATINL": "",
                          "BRAKEL": "2-1768", "CERTIL": "ANAC",
                          "REVNBL": "ELME2_v3.0.0", "DATEL": "19SEP2023;23AUG2021",
                          "AMDBIL": "CAFM-ADB-069.pdm;CAFM-EDB-015.pdm"}},
}
# flap de pouso -> (CONFL(5) pouso, CONFL(3) arremetida; o E2 nao usa o 2o)
FLAPS = {"5": (5, 2), "FULL": (6, 4)}
FLAPS_MODELO = {"E195": FLAPS, "E195-E2": {"5": (5, 0), "FULL": (6, 0)}}

LIMITES = {
    1: "Peso máximo de pouso informado (MLW)",
    2: "Distância de pouso (LDA)",
    3: "Gradiente de arremetida (approach climb)",
    4: "Gradiente de subida de pouso (landing climb)",
    5: "Velocidade dos pneus",
    6: "Energia de freio",
}

_LOCK = threading.Lock()


@dataclass
class PousoE:
    """Entrada (m, ft, %, C, hPa, kt, kg)."""
    lda: float
    elev: float
    slope: float = 0.0
    temp: float = 15.0
    qnh: float = 1013.25
    vento: float = 0.0            # + proa, - cauda
    molhada: bool = False
    grooved: bool = False
    flap_pouso: int = 6           # CONFL(5): 5 = flap 5, 6 = FULL
    flap_arremetida: int = 4      # CONFL(3): 2 ou 4
    reverso: int = 0              # CONFL(10): 0 sem credito, 1 todos
    antigelo: int = 0             # CONFL(7): 0 OFF, 3 motor e asa
    autobrake: int = 0            # CONFL(16): 0 OFF; 1..3 = setting 0..2 (CONFL 16=1, 17=n-1)
    vref_inc: float = 0.0         # POPTL(14): incremento na VREF (kt)
    mlw: Optional[float] = None   # POPTL(9); None = limite do CAFM
    ga_grad: Optional[float] = None
    peso: Optional[float] = None  # so E2: distancias no peso informado (POPTL(1)=1)


class PousoError(Exception):
    pass


def blocos(p, tipo="e1"):
    if tipo == "e2":
        return blocos_e2(p)
    P = {1: 1, 2: 1 if p.molhada else 0, 4: 6, 5: 0, 7: 16,
         8: 1 if p.mlw else 0, **({9: p.mlw} if p.mlw else {}),
         12: 0, 13: 1, 14: p.vref_inc,
         17: 1 if p.ga_grad else 0, **({18: p.ga_grad} if p.ga_grad else {}),
         19: 0, 21: 0, 23: 0, 26: 0, 27: 0, 28: 0, 29: 0,
         32: 1, 53: 1, 55: 1, 56: 0}
    C = {1: 1, 3: p.flap_arremetida, 5: p.flap_pouso, 7: p.antigelo, 8: 0,
         10: p.reverso, 15: 0, 16: min(p.autobrake, 1), 21: 0, 24: 0,
         30: 1, 34: 0, 80: 1}
    if p.autobrake:
        C[17] = p.autobrake - 1
    X = {1: p.temp, 2: p.vento, 4: 1, 5: p.qnh}
    R = {1: p.elev, 2: p.lda, 3: p.slope, 4: 2 if p.grooved else 0, 5: 1, 6: 0, 7: 0}
    U = {1: 0, 2: 0, 3: 0, 4: 1, 5: 0, 6: 0, 7: 0, 8: 0, 9: 2, 10: 1}
    return {"POPTL": P, "CONFL": C, "XMETL": X, "RWYDL": R, "UNITL": U}


def blocos_e2(p):
    """ELME2 (manual sec. 5); o que nao aparece fica 9E20."""
    teto = p.peso or p.mlw
    P = {1: 1 if p.peso else 0,       # 0 pesos limite (airport analysis), 1 no peso
         2: 1 if p.molhada else 0, 4: 6, 5: 0,
         8: 1 if teto else 0, **({9: teto} if teto else {}),
         12: 0, 13: 1, 14: p.vref_inc,
         17: 1 if p.ga_grad else 0, **({18: p.ga_grad} if p.ga_grad else {}),
         19: 0, 21: 0, 23: 0, 26: 0,
         28: 0,                       # drag index (configuracao normal)
         36: 0,                       # despacho / RLD
         37: 0 if p.peso else 1}      # wet check: obrigatorio no airport analysis
    C = {1: 1, 5: p.flap_pouso, 7: p.antigelo, 10: p.reverso,
         16: min(p.autobrake, 1), 19: 2, 30: 1, 34: 0}
    if p.autobrake:
        C[17] = p.autobrake - 1
    X = {1: p.temp, 2: p.vento, 4: 1, 5: p.qnh}
    R = {1: p.elev, 2: p.lda, 3: p.slope, 4: 2 if p.grooved else 0, 7: 0}
    U = {1: 0, 2: 0, 3: 0, 4: 1, 5: 0, 6: 0, 8: 0, 9: 2, 10: 0}
    return {"POPTL": P, "CONFL": C, "XMETL": X, "RWYDL": R, "UNITL": U}


def linpn(valores):
    num = [NA] * (200 * len(BLOCOS))
    for bloco, campos in valores.items():
        for i, v in campos.items():
            num[BLOCOS.index(bloco) * 200 + i - 1] = float(v)
    return struct.pack(f"<{len(num)}f", *num)


def linpa(texto):
    return b"".join(texto.get(nome, "").encode("latin-1")[:largura].ljust(largura) * vezes
                    for nome, largura, vezes in TEXTOS)


def entrada_legivel(valores, texto):
    linhas = [f"{k:6s} = {v}" for k, v in texto.items()]
    for bloco, campos in valores.items():
        linhas += [f"{bloco}({i:3d}) = {float(v):g}" for i, v in campos.items()]
    return "\n".join(linhas)


def pasta_trabalho(modelo):
    """work/epouso com o carregador, a DLL, o runtime e as bases (links)."""
    m = MODELOS[modelo]
    pasta = WORK_DIR / "epouso"
    pasta.mkdir(parents=True, exist_ok=True)
    for nome in (m["dll"], *m["copiar"]):
        origem = find_file(nome)
        if origem is None:
            raise PousoError(f"Arquivo não encontrado: {nome}")
        if not (pasta / nome).exists():
            shutil.copy2(origem, pasta / nome)
    if not LOADER.exists():
        raise PousoError("Falta o engines/loader/scaploader.exe (rode engines/loader/build.sh)")
    shutil.copy2(LOADER, pasta / "scaploader.exe")
    for nome in m["texto"]["AMDBIL"].split(";"):
        origem = find_file(nome)
        if origem is None:
            raise PousoError(f"Base não encontrada: {nome}")
        alvo = pasta / nome
        drop_broken_link(alvo)
        if not (alvo.exists() or alvo.is_symlink()):
            try:
                alvo.symlink_to(origem)
            except OSError:
                shutil.copy2(origem, alvo)
    return pasta


def calcular(modelo, p, timeout=120):
    m = MODELOS[modelo]
    valores, texto = blocos(p, m["tipo"]), m["texto"]
    nin, ain, nout, aout = m["simbolos"]
    with _LOCK:
        pasta = pasta_trabalho(modelo)
        (pasta / "linpn.bin").write_bytes(linpn(valores))
        (pasta / "linpa.bin").write_bytes(linpa(texto))
        for f in ("loutn.bin", "louta.bin"):
            (pasta / f).unlink(missing_ok=True)
        cmd = ["scaploader.exe", m["dll"], m["rotina"],
               "--in", f"{nin}=linpn.bin", "--in", f"{ain}=linpa.bin",
               "--out", f"{nout}={LOUTN_BYTES}:loutn.bin", "--out", f"{aout}={LOUTA_BYTES}:louta.bin"]
        if platform.system() == "Windows":
            cmd[0] = str(pasta / cmd[0])
        else:
            cmd.insert(0, os.environ.get("SCAP_WINE", "wine"))
        try:
            proc = subprocess.run(cmd, cwd=pasta, env=dict(os.environ, WINEDEBUG="-all"),
                                  capture_output=True, text=True, errors="replace", timeout=timeout)
        except subprocess.TimeoutExpired:
            raise PousoError(f"O módulo de pouso não terminou em {timeout} s")
        if not (pasta / "loutn.bin").exists():
            raise PousoError("O módulo de pouso não devolveu resultado.\n"
                             + (proc.stdout + proc.stderr).strip()[-1500:])
        n = struct.unpack("<400f", (pasta / "loutn.bin").read_bytes())
        a = (pasta / "louta.bin").read_bytes().decode("latin-1")
    # 9E20 = sem valor; 9999999 = calculo sem resultado valido (ERFLAG E)
    climil = [None if v >= NA * 0.99 or abs(v - 9999999) < 1 else v for v in n[:200]]
    g = lambda i: climil[i - 1]
    flag = a[:20].replace("\x00", " ").strip()
    msgs = [a[20 + 80 * i:100 + 80 * i].replace("\x00", " ").strip() for i in range(20)]
    codigo = g(6)
    limitante = LIMITES.get(int(codigo), f"código {codigo:g}") if codigo else ""
    if g(1) is None and limitante:      # ex.: autobrake numa pista curta
        limitante += ": nenhum peso cabe nessa condição"
    return {"mlw": g(1), "limitante": limitante,
            "gradiente_arremetida": g(14), "gradiente_pouso": g(15),
            "vapp": g(22), "v_arremetida": g(23), "ld": g(12), "ld_exigida": g(13),
            "principal": {
                "MAXIMUM LANDING WEIGHT": g(1), "LIMITATION CODE": codigo,
                "WEIGHT LIMITED BY LDA": g(7), "WEIGHT LIMITED BY ACG": g(8),
                "WEIGHT LIMITED BY LCG": g(9), "WEIGHT LIMITED BY TIRE SPEED": g(10),
                "WEIGHT LIMITED BY BRAKE ENERGY": g(11), "ACTUAL LD": g(12),
                "LD REQUIRED FOR MAX LD WEIGHT": g(13), "ACG FOR MAX LD WEIGHT (%)": g(14),
                "LCG FOR MAX LD WEIGHT (%)": g(15), "VREF (KT)": g(22)},
            "erflag": flag, "mensagens": [x for x in msgs if x],
            "entrada": entrada_legivel(valores, texto)}


def main():
    a = argparse.ArgumentParser(description="Pouso da Embraer E1 (despacho), em teste")
    a.add_argument("--modelo", default="E195", choices=sorted(MODELOS))
    a.add_argument("--icao", default="SBRJ")
    a.add_argument("--rwy", default="20L")
    a.add_argument("--temp", type=float, default=25)
    a.add_argument("--qnh", type=float, default=1013.25)
    a.add_argument("--vento", type=float, default=0)
    a.add_argument("--molhada", action="store_true")
    a.add_argument("--grooved", action="store_true")
    a.add_argument("--lda", type=float)
    a.add_argument("--flap", default="FULL", help="5 ou FULL")
    a.add_argument("--mlw", type=float)
    args = a.parse_args()
    rw = load_airports()[args.icao.upper()]["runways"][args.rwy]
    pouso, arremetida = FLAPS_MODELO[args.modelo][args.flap.upper()]
    p = PousoE(lda=args.lda or rw.tora, elev=rw.elev, slope=rw.slope, temp=args.temp, qnh=args.qnh,
               vento=args.vento, molhada=args.molhada, grooved=args.grooved,
               flap_pouso=pouso, flap_arremetida=arremetida, mlw=args.mlw)
    r = calcular(args.modelo, p)
    for k, v in r["principal"].items():
        print(f"  {k:34s} {'–' if v is None else f'{v:,.2f}'}")
    print(f"\nPeso máximo de pouso: {r['mlw'] and round(r['mlw'])} kg · {r['limitante']}")
    print(f"ERFLAG: {r['erflag']}  {r['mensagens'][:3]}")


if __name__ == "__main__":
    main()

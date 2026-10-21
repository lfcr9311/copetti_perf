#!/usr/bin/env python3
"""Pouso (despacho) do ATR 72-600 pelo TLAM da ATR (pacote SCAP APS 2.7.1) - em teste.

Usa o programa oficial da ATR: SCAPApp.exe + SCAPLibrary.dll (que confere a
licenca) + TLAM.dll, com entrada e saida em XML (IATA Alternate SCAP Interface
- XML Standard; ver SCAP_APS_2.7.1/docs). Roda pelo Wine (precisa do Mono do
Wine). O TLAM nunca e chamado direto: a licenca da ATR vale a cada calculo.

Campos: manual TLAM B2-O9 (OCT 2025). Base: MUE6DC3E.PDF (PW127F/M/N, freios
Meggitt 10.9 MJ), a que vem no pacote.

    python3 pouso_atr.py                                   # SBRJ 20L, 25 C
    python3 pouso_atr.py --icao SBKG --rwy 15 --molhada
"""

import argparse
import os
import platform
import shutil
import subprocess
import threading
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import scap_engine
from airports import load_airports

NA = 9e20
PACOTE = Path(__file__).resolve().parent.parent / "SCAP_APS_2.7.1"
ARQUIVOS = ("SCAPApp.exe", "SCAPLibrary.dll", "TLAM.dll", "TTAM.dll", "License", "LicenseKey")
BASE = "MUE6DC3E.PDF"

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

_LOCK = threading.Lock()


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
    P = {1: 0, 2: 1 if p.molhada else 0, 5: 0, 7: 11,
         8: 1 if p.mlw else 0, **({9: p.mlw} if p.mlw else {}),
         12: 0, 13: 0, 15: 0, 16: 0,
         17: 1 if p.ga_grad else 0, **({18: p.ga_grad} if p.ga_grad else {}),
         19: 0, 21: 0, 23: 0, 25: 0, 26: 0, 29: 0, 34: 0,
         36: 0,          # despacho / RLD
         38: 0}          # wet check
    C = {1: 1, 2: 0, 3: p.flap_arremetida, 4: 0, 5: p.flap_pouso,
         6: 2, 7: 6 if p.icing else 0, 9: 0, 10: p.reverso,
         **({11: 0} if p.reverso else {}),
         12: 0, 15: 0, 18: 0, 19: 0, 21: 0, 24: 0, 30: 1, 41: 0, 45: p.boost}
    X = {1: p.temp, 2: p.vento, 4: 1, 5: p.qnh}
    R = {1: p.elev, 2: p.lda, 3: p.slope, 4: 0, 5: 1, 6: 0}
    U = {1: 0, 3: 0, 4: 1, 5: 1, 6: 0, 8: 0, 9: 2}
    return {"POPTL": P, "CONFL": C, "XMETL": X, "RWYDL": R, "UNITL": U}


def textos(p):
    return {"ACTYPL": "ATR72-600", "ENGTYL": p.motor, "BRAKEL": "MEGGITT 10.9 MJ",
            "AMDBIL": BASE, "CERTIL": "FAR", "APTIDL": "", "RWYNBL": "", "MISCLL": "",
            "FDCFGA": "", "FDCFGL": ""}


def xml_entrada(p):
    """INPUT_FILE no formato do SCAP.in de referencia da ATR: uma tag por linha
    e CRLF (o leitor do TLAM le linha a linha; tudo numa linha nao funciona).
    Sem output_file/trace_file: a saida vai para entrada.out / entrada.log."""
    linhas = ['<?xml version="1.0"?>', "<INPUT_FILE>",
              "\t<interface_version>X.X</interface_version>",
              "\t<security_code>123456789012345678901234567890</security_code>",
              "\t<landing_spec_version>X.X</landing_spec_version>",
              "\t<config>", "\t\t<data_files>data\\</data_files>", "\t</config>",
              '\t<block type="LANDING" id="1">', '\t\t<case id="1">']
    for nome, itens in blocos(p).items():
        linhas.append(f'\t\t\t<array name="{nome}">')
        linhas += [f'\t\t\t\t<item index="{i}"> <value>{float(v):g}</value> </item>'
                   for i, v in itens.items()]
        linhas.append("\t\t\t</array>")
    linhas += [f'\t\t\t<element name="{nome}"> <value>{escape(v)}</value> </element>'
               for nome, v in textos(p).items()]
    linhas += ["\t\t</case>", "\t</block>", "</INPUT_FILE>", ""]
    return "\r\n".join(linhas)


def ler_saida(texto):
    """OUTPUT_FILE -> (arrays {nome: {indice: valor}}, elements {nome: texto})."""
    raiz = ET.fromstring(texto)
    arrays, elementos = {}, {}
    for caso in raiz.iter("case"):
        for arr in caso.findall("array"):
            dados = {}
            for item in arr.findall("item"):
                v = (item.findtext("value") or "").strip()
                try:
                    x = float(v)
                    dados[int(item.get("index"))] = None if x >= NA * 0.99 else x
                except ValueError:
                    dados[int(item.get("index"))] = v
            arrays[arr.get("name")] = dados
        for el in caso.findall("element"):
            elementos[el.get("name")] = (el.findtext("value") or "").strip()
    return arrays, elementos


def pasta_trabalho():
    if not PACOTE.is_dir():
        raise PousoError(f"Pacote da ATR não encontrado em {PACOTE}")
    pasta = scap_engine.WORK_DIR / "atrpouso"
    (pasta / "data").mkdir(parents=True, exist_ok=True)
    for nome in ARQUIVOS:
        origem = PACOTE / nome
        if not origem.exists():
            raise PousoError(f"Falta {nome} no pacote da ATR ({PACOTE})")
        shutil.copy2(origem, pasta / nome)          # copia sempre: licenca nova vale
    base = PACOTE / "data" / BASE
    alvo = pasta / "data" / BASE
    scap_engine.drop_broken_link(alvo)
    if not (alvo.exists() or alvo.is_symlink()):
        try:
            alvo.symlink_to(base)
        except OSError:
            shutil.copy2(base, alvo)
    return pasta


def calcular(p, timeout=180):
    with _LOCK:
        pasta = pasta_trabalho()
        for f in ("entrada.out", "entrada.log", "Error.log"):
            (pasta / f).unlink(missing_ok=True)
        (pasta / "entrada.xml").write_bytes(xml_entrada(p).encode("latin-1"))
        cmd = ["SCAPApp.exe", "entrada.xml"]
        if platform.system() == "Windows":
            cmd[0] = str(pasta / cmd[0])
        else:
            cmd.insert(0, os.environ.get("SCAP_WINE", "wine"))
        try:
            proc = subprocess.run(cmd, cwd=pasta, env=dict(os.environ, WINEDEBUG="-all"),
                                  stdin=subprocess.DEVNULL, capture_output=True, text=True,
                                  errors="replace", timeout=timeout)
        except subprocess.TimeoutExpired:
            raise PousoError(f"O SCAPApp da ATR não terminou em {timeout} s")
        erro = (pasta / "Error.log").read_text(errors="replace").strip() if (pasta / "Error.log").exists() else ""
        if erro:
            if "expired" in erro.lower():
                erro += " — peça à ATR o arquivo License renovado (SCAP_APS_2.7.1/License)"
            raise PousoError(f"ATR: {erro}")
        saida = pasta / "entrada.out"
        if not saida.exists() or not saida.stat().st_size:
            log = (pasta / "entrada.log").read_text(errors="replace")[-1500:] if (pasta / "entrada.log").exists() else ""
            raise PousoError("O SCAPApp da ATR não gerou a saída.\n" + (log or (proc.stdout + proc.stderr)[-1500:]))
        arrays, elementos = ler_saida(saida.read_text(errors="replace"))
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

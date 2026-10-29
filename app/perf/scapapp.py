"""SCAPApp.exe da ATR (pacote SCAP APS 2.7.1): roda o TTAM (decolagem) e o
TLAM (pouso) com a licenca da ATR, entrada e saida em XML (IATA Alternate
SCAP Interface - XML Standard; ver engines/atr/SCAP_APS_2.7.1/docs).

Roda pelo Wine (precisa do Mono do Wine). TTAM.dll e TLAM.dll nunca sao
chamados direto: a licenca vale a cada calculo. Base: MUE6DC3E.PDF, a que
vem no pacote (data/).
"""

import os
import platform
import shutil
import subprocess
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

from .paths import ATR_PACKAGE as PACOTE
from .paths import WORK_DIR, drop_broken_link, folder_lock

NA = 9e20
ARQUIVOS = ("SCAPApp.exe", "SCAPLibrary.dll", "TLAM.dll", "TTAM.dll", "License", "LicenseKey")
BASE = "MUE6DC3E.PDF"


class ScapAppError(Exception):
    pass


def pasta_trabalho(nome):
    """work/<nome> com o SCAPApp, as DLLs, a licenca e a base em data/."""
    if not PACOTE.is_dir():
        raise ScapAppError(f"Pacote da ATR não encontrado em {PACOTE}")
    pasta = WORK_DIR / nome
    (pasta / "data").mkdir(parents=True, exist_ok=True)
    for arq in ARQUIVOS:
        origem = PACOTE / arq
        if not origem.exists():
            raise ScapAppError(f"Falta {arq} no pacote da ATR ({PACOTE})")
        shutil.copy2(origem, pasta / arq)          # copia sempre: licenca nova vale
    base = PACOTE / "data" / BASE
    alvo = pasta / "data" / BASE
    drop_broken_link(alvo)
    if not (alvo.exists() or alvo.is_symlink()):
        try:
            alvo.symlink_to(base)
        except OSError:
            shutil.copy2(base, alvo)
    return pasta


def xml_entrada(tipo, arrays, elementos):
    """INPUT_FILE no formato do SCAP.in de referencia da ATR: uma tag por linha
    e CRLF (o leitor le linha a linha; tudo numa linha nao funciona). tipo:
    TAKEOFF ou LANDING. Sem output_file/trace_file: a saida vai para
    entrada.out / entrada.log."""
    spec = "takeoff" if tipo == "TAKEOFF" else "landing"
    linhas = ['<?xml version="1.0"?>', "<INPUT_FILE>",
              "\t<interface_version>X.X</interface_version>",
              "\t<security_code>123456789012345678901234567890</security_code>",
              f"\t<{spec}_spec_version>X.X</{spec}_spec_version>",
              "\t<config>", "\t\t<data_files>data\\</data_files>", "\t</config>",
              f'\t<block type="{tipo}" id="1">', '\t\t<case id="1">']
    for nome, itens in arrays.items():
        linhas.append(f'\t\t\t<array name="{nome}">')
        linhas += [f'\t\t\t\t<item index="{i}"> <value>{float(v):g}</value> </item>'
                   for i, v in sorted(itens.items())]
        linhas.append("\t\t\t</array>")
    linhas += [f'\t\t\t<element name="{nome}"> <value>{escape(v)}</value> </element>'
               for nome, v in elementos.items()]
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


def rodar(nome, entrada, timeout=180):
    """Roda o SCAPApp em work/<nome> (um calculo por vez em cada pasta) e
    devolve ler_saida() da saida."""
    with folder_lock(nome):
        pasta = pasta_trabalho(nome)
        for f in ("entrada.out", "entrada.log", "Error.log"):
            (pasta / f).unlink(missing_ok=True)
        (pasta / "entrada.xml").write_bytes(entrada.encode("latin-1"))
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
            raise ScapAppError(f"O SCAPApp da ATR não terminou em {timeout} s")
        erro = (pasta / "Error.log").read_text(errors="replace").strip() if (pasta / "Error.log").exists() else ""
        if erro:
            if "expired" in erro.lower():
                erro += " — peça à ATR o arquivo License renovado (engines/atr/SCAP_APS_2.7.1/License)"
            raise ScapAppError(f"ATR: {erro}")
        saida = pasta / "entrada.out"
        if not saida.exists() or not saida.stat().st_size:
            log = (pasta / "entrada.log").read_text(errors="replace")[-1500:] if (pasta / "entrada.log").exists() else ""
            raise ScapAppError("O SCAPApp da ATR não gerou a saída.\n" + (log or (proc.stdout + proc.stderr)[-1500:]))
        return ler_saida(saida.read_text(errors="replace"))

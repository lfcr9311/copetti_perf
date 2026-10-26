"""Airbus: monta o scap.in, roda o motor Octopus (scap_octopus.dll) e le o
SCAP.OUT.

Equivale ao OCTOPUS.FOR: a DLL le o scap.in da pasta atual e grava o
SCAP.OUT ali mesmo. No Linux a DLL e chamada pelo rundll32 do Wine.

Cada calculo roda numa pasta de trabalho propria (app/work/wN) com links
para a DLL, os .cnf e as bases; assim varios calculos rodam em paralelo.
"""

import os
import platform
import shutil
import subprocess

from ..catalog.aircraft import FLAP_NAMES
from ..catalog.airports import obsd_values, rwyd_values
from ..paths import TEMPLATES_DIR, WORK_DIR, drop_broken_link, find_file
from .common import CALM, ScapError, database_files

DLL_NAME = "scap_octopus.dll"
DLL_ENTRY = "_runscap@0"
ENGINE_FILES = (DLL_NAME, "msvcr120.dll", "DFORRT.DLL", "octocnf",
                "errors.cnf", "limits.cnf", "config")

# Larguras dos campos CHARACTER do bloco TINPA (DECLARA.FOR)
TINPA_WIDTH = {"ACMDBI": 255, "MISCLA": 255, "CERTIF": 20, "FDCFGI": 20}


def find_example(variant=None):
    """scap.in base do motor (templates/<variant.example>, com POPT/CONF e
    MTOW proprios do modelo). Sem exemplo proprio, usa o scap.in.example
    generico."""
    name = variant.example if variant is not None and variant.example else "scap.in.example"
    path = TEMPLATES_DIR / name
    if path.exists():
        return path
    raise ScapError(f"Exemplo nao encontrado: {path}")


# ---------------------------------------------------------------- scap.in

def _ending(line):
    return line[len(line.rstrip("\r\n")):] or "\n"


def _block_start(lines, name):
    for i, line in enumerate(lines):
        if line.strip().startswith(f"Common {name}"):
            return i
    raise ScapError(f"scap.in.example nao tem o bloco 'Common {name}'")


def _block_end(lines, start):
    for i in range(start + 1, len(lines)):
        if lines[i].strip().startswith("Common"):
            return i
    return len(lines)


def _value_line(block, index, value, ending):
    # Mesmo formato do OCTOPUS.FOR: 'POPT  1  = ' / 'POPT  24 = ' + F16.7
    return f"{block}  {index:<2} ={float(value):16.7f}{ending}"


def set_values(lines, block, values):
    """Troca/insere 'BLOCO i = valor' dentro do bloco, mantendo a ordem."""
    start = _block_start(lines, block)
    end = _block_end(lines, start)
    ending = _ending(lines[start])
    current = {}
    for line in lines[start + 1:end]:
        parts = line.replace("=", " ").split()
        if len(parts) == 3 and parts[0] == block:
            current[int(parts[1])] = line
    for index, value in values.items():
        current[index] = _value_line(block, index, value, ending)
    lines[start + 1:end] = [current[i] for i in sorted(current)]


def replace_block(lines, block, values):
    """Reescreve o bloco inteiro so com os valores dados."""
    start = _block_start(lines, block)
    end = _block_end(lines, start)
    ending = _ending(lines[start])
    lines[start + 1:end] = [_value_line(block, i, v, ending)
                            for i, v in sorted(values.items())]


def set_tinpa(lines, values):
    start = _block_start(lines, "TINPA")
    values = dict(values)
    for i in range(start + 1, len(lines)):
        key = lines[i].split("=", 1)[0].strip()
        if key in values:
            lines[i] = (f"{key:<8} = {values.pop(key):<{TINPA_WIDTH[key]}}"
                        f"{_ending(lines[i])}")
    if values:
        raise ScapError("Faltam no TINPA do scap.in.example: "
                        + ", ".join(values))


def read_value(text, block, index):
    """Le 'BLOCO  i = valor' de um scap.in (ex.: POPT 24)."""
    for line in text.splitlines():
        parts = line.replace("=", " ").split()
        if len(parts) == 3 and parts[0] == block and parts[1] == str(index):
            return float(parts[2])
    return None


def build_input(example_text, aircraft, variant, runway=None,
                temperature=None, align=None, cond=None):
    """Copia o scap.in.example trocando o TINPA (ACMDBI, MISCLA, CERTIF) e,
    se informados, a temperatura (XMET 1), o vento e o QNH (XMET 2, 3, 5),
    o flap (CONF 1/2), o limite de CG (POPT 30), o MTOW estrutural (POPT 24),
    a pista (RWYD), os obstaculos (OBSD) e o alinhamento (POPT 12/13). O
    resto fica como no exemplo."""
    lines = example_text.splitlines(keepends=True)
    set_tinpa(lines, {"ACMDBI": variant.acmdbi, "MISCLA": variant.miscla,
                      "CERTIF": variant.certif})
    if temperature is not None:
        set_values(lines, "XMET", {1: temperature})
    if cond is not None:
        set_values(lines, "XMET", {2: cond.wind, 3: cond.crosswind,
                                   4: 1, 5: cond.qnh})
        if cond.flap is not None:       # configuracao escolhida
            set_values(lines, "CONF", {1: 1, 2: cond.flap})
        if cond.cg:                     # limite dianteiro de CG
            set_values(lines, "POPT", {30: cond.cg})
        if cond.mtow:                   # peso estrutural (MTOW) escolhido
            set_values(lines, "POPT", {24: cond.mtow})
    if runway is not None:
        wet = read_value(example_text, "POPT", 14) == 1
        replace_block(lines, "RWYD", rwyd_values(runway, aircraft.actype, wet))
        replace_block(lines, "OBSD", obsd_values(runway))
    if align is not None:
        set_values(lines, "POPT", align)
    return "".join(lines)


# ------------------------------------------------------------- execucao

def prepare_workdir(variant, slot):
    """Pasta work/w<slot> com links para os arquivos que a DLL le."""
    folder = WORK_DIR / f"w{slot}"
    folder.mkdir(parents=True, exist_ok=True)
    for name in ENGINE_FILES + tuple(database_files(variant)):
        source = find_file(name)
        target = folder / source.name
        drop_broken_link(target)
        if target.exists() or target.is_symlink():
            continue
        try:
            target.symlink_to(source, target_is_directory=source.is_dir())
        except OSError:          # Windows sem permissao para links
            if source.is_dir():
                shutil.copytree(source, target)
            else:
                shutil.copy2(source, target)
    return folder


def run_dll(folder, timeout=180):
    if platform.system() == "Windows":
        # A DLL e de 32 bits: um Python de 64 bits nao consegue carrega-la.
        # O rundll32 de 32 bits do proprio Windows (SysWOW64) carrega a DLL
        # da pasta de trabalho (cwd) e chama _runscap@0, como o Wine faz no
        # Linux. SCAP_PYTHON32 (caminho de um python.exe de 32 bits) e uma
        # alternativa opcional.
        python32 = os.environ.get("SCAP_PYTHON32")
        if python32:
            code = ("import ctypes, os; os.add_dll_directory(os.getcwd()); "
                    f"getattr(ctypes.WinDLL(os.path.abspath('{DLL_NAME}')), "
                    f"'{DLL_ENTRY}')()")
            cmd = [python32, "-c", code]
        else:
            windir = os.environ.get("SystemRoot", r"C:\Windows")
            rundll = os.path.join(windir, "SysWOW64", "rundll32.exe")
            if not os.path.exists(rundll):         # Windows de 32 bits
                rundll = os.path.join(windir, "System32", "rundll32.exe")
            cmd = [rundll, f"{DLL_NAME},{DLL_ENTRY}"]
    else:
        cmd = [os.environ.get("SCAP_WINE", "wine"), "rundll32",
               f"{DLL_NAME},{DLL_ENTRY}"]
    env = dict(os.environ, WINEDEBUG="-all")
    try:
        return subprocess.run(cmd, cwd=folder, env=env, timeout=timeout,
                              capture_output=True, text=True,
                              errors="replace")
    except FileNotFoundError:
        raise ScapError(f"Nao achei o programa '{cmd[0]}'")
    except subprocess.TimeoutExpired:
        raise ScapError(f"O motor nao terminou em {timeout} s")


# ------------------------------------------------------------- SCAP.OUT

def _numbers(lines):
    values = []
    for line in lines:
        values.extend(float(v) for v in line.split())
    return values


def parse_output(text):
    """Le o SCAP.OUT: MAIN RESULTS, arrays (CLIMIT...) e ERFLAG/ERRMSG."""
    main, arrays, errmsg = {}, {}, []
    erflag = ""
    section = None
    block = []

    for line in text.splitlines():
        if line.startswith("**************** INPUT RECAP"):
            break
        if line.startswith("----------"):
            if section and block:
                arrays[section] = _numbers(block)
            section, block = line[10:].strip(), []
            continue
        if section is None:
            if "->" in line:
                label, value = line.split("->", 1)
                main[label.strip()] = float(value)
        elif section in ("ERROR", "MISC"):
            if line.startswith("ERFLAG"):
                erflag = line.split(":", 1)[1].strip()
            elif line.startswith("ERRMSG") and line.split(":", 1)[1].strip():
                errmsg.append(line.split(":", 1)[1].strip())
        elif line.strip():
            block.append(line)
    if section and block and section not in ("ERROR", "MISC"):
        arrays[section] = _numbers(block)

    return {"main": main, "arrays": arrays, "erflag": erflag,
            "errmsg": errmsg}


def limitation_code(climit, max_weight):
    """Codigo do limitante, com os mesmos ajustes do OCTOPUS.FOR e do
    takeoff_module.for. climit e indexado a partir de 1 como no Fortran."""
    c = lambda i: climit[i - 1]
    if c(1) == max_weight:
        code = 1
    elif c(52) == 2:
        code = 0
    elif c(8) == 1:
        code = c(9)
    else:
        code = c(8)
    code = int(code)
    if code in (5, 6):
        code = 4
    if code in (22, 23, 4, 9):
        code = 3
    return code


def _transient(out):
    """Falha esporadica do motor no Wine: o mesmo scap.in passa se repetir."""
    return out is None or any("OCTOCNF" in m for m in out["errmsg"])


def compute(aircraft, variant, runway=None, temperature=None, slot=0,
            align=None, retries=2, cond=CALM):
    """Airbus: scap.in -> scap_octopus.dll -> SCAP.OUT. Devolve mtow, flap,
    limit_code, v1_min, v1_max, vr, v2 (None se o motor nao da)."""
    input_text = build_input(find_example(variant).read_text(errors="replace"),
                             aircraft, variant, runway, temperature, align,
                             cond)
    folder = prepare_workdir(variant, slot)
    (folder / "scap.in").write_text(input_text)

    out_path = folder / "SCAP.OUT"
    for _ in range(retries + 1):
        out_path.unlink(missing_ok=True)
        proc = run_dll(folder)
        out = (parse_output(out_path.read_text(errors="replace"))
               if out_path.exists() else None)
        if not _transient(out):
            break
    if out is None:
        raise ScapError("O motor nao gerou SCAP.OUT.\n"
                        + (proc.stdout + proc.stderr).strip())
    if out["erflag"] not in ("A", "D"):
        raise ScapError(f"ERFLAG = {out['erflag'] or '?'}\n"
                        + "\n".join(out["errmsg"]))

    climit = out["arrays"]["CLIMIT"]
    max_weight = read_value(input_text, "POPT", 24)
    flap = FLAP_NAMES.get(aircraft.actype, {}).get(int(climit[1]),
                                                  f"{climit[1]:.0f}")
    main = out["main"]
    return {
        "temperature": read_value(input_text, "XMET", 1),
        "mtow": int(climit[0]),           # INT() como no Fortran
        "flap": flap,
        "limit_code": limitation_code(climit, max_weight),
        "v1_min": main.get("MINIMUM V1 (IAS)"),
        "v1_max": main.get("MAXIMUM V1 (IAS)"),
        "vr": main.get("VR (IAS)"),
        "v2": main.get("V2 (IAS)"),
        "main": main,
        "erflag": out["erflag"],
        "errmsg": out["errmsg"],
    }

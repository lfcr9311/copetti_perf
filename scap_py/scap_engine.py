"""Monta o scap.in, roda o motor Octopus (scap_octopus.dll) e le o SCAP.OUT.

Equivale ao OCTOPUS.FOR: a DLL le o scap.in da pasta atual e grava o
SCAP.OUT ali mesmo. No Linux a DLL e chamada pelo rundll32 do Wine.

Cada calculo roda numa pasta de trabalho propria (scap_py/work/wN) com links
para a DLL, os .cnf e os bancos; assim varios calculos rodam em paralelo e
o scap.in/SCAP.OUT da pasta do Fortran nao sao tocados.
"""

import gzip
import os
import platform
import shutil
import subprocess
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from queue import Queue

from aircraft import FLAP_NAMES
from airports import obsd_values, rwyd_values

HERE = Path(__file__).resolve().parent
# Pasta do projeto Fortran: DLL, bancos (.pre etc.), octocnf, errors.cnf...
SCAP_DIR = HERE.parent
WORK_DIR = HERE / "work"
EXAMPLES_DIR = HERE / "examples"
DLL_NAME = "scap_octopus.dll"
DLL_ENTRY = "_runscap@0"
ENGINE_FILES = (DLL_NAME, "msvcr120.dll", "DFORRT.DLL", "octocnf",
                "errors.cnf", "limits.cnf", "config")

# Larguras dos campos CHARACTER do bloco TINPA (DECLARA.FOR)
TINPA_WIDTH = {"ACMDBI": 255, "MISCLA": 255, "CERTIF": 20, "FDCFGI": 20}


class ScapError(Exception):
    pass


@dataclass(frozen=True)
class Conditions:
    """Vento e pressao, sempre relativos a pista (convencao do SCAP):
    wind > 0 = proa, wind < 0 = cauda (XMET 2); crosswind > 0 = vindo da
    direita (XMET 3, so o Airbus usa); qnh em hPa (XMET 5, XMET 4 = 1).
    flap: None = otimo (o motor escolhe o que da maior MTOW); senao o flap
    fixo no codigo de cada motor: Airbus o codigo de FLAP_NAMES, ex. 1810 =
    CONF 1+F (CONF 1 = 1, CONF 2); Embraer 1 a 4 (CONF 3); ATR 15 (CONF 3;
    a base do ATR so tem o FLAP 15)."""
    wind: float = 0.0
    crosswind: float = 0.0
    qnh: float = 1013.25
    flap: "int | None" = None

    def describe(self):
        parts = []
        if self.wind > 0:
            parts.append(f"proa {self.wind:g} kt")
        elif self.wind < 0:
            parts.append(f"cauda {-self.wind:g} kt")
        if self.crosswind:
            side = "direita" if self.crosswind > 0 else "esquerda"
            parts.append(f"través {abs(self.crosswind):g} kt ({side})")
        wind = ", ".join(parts) or "sem vento"
        return f"{wind} · QNH {self.qnh:g}"


CALM = Conditions()


def find_example(variant=None):
    """scap.in base do motor (examples/<variant.example>, com POPT/CONF e
    MTOW proprios do modelo). Sem exemplo proprio, usa o scap.in.example
    generico de scap_py/ ou da pasta do projeto Fortran."""
    if variant is not None and variant.example:
        path = EXAMPLES_DIR / variant.example
        if path.exists():
            return path
        raise ScapError(f"Exemplo nao encontrado: {path}")
    for folder in (HERE, SCAP_DIR):
        path = folder / "scap.in.example"
        if path.exists():
            return path
    raise ScapError(f"scap.in.example nao encontrado em {HERE} nem em "
                    f"{SCAP_DIR}")


def find_file(name, folder=None):
    """Procura o arquivo sem diferenciar maiusculas (o Wine faz o mesmo).
    Na pasta do projeto, se so existir <nome>.gz (as bases grandes vao
    comprimidas para o GitHub), descomprime na primeira vez."""
    wanted = name.lower()
    gz = None
    for path in (folder or SCAP_DIR).iterdir():
        if path.name.lower() == wanted:
            return path
        if path.name.lower() == wanted + ".gz":
            gz = path
    if gz is not None and folder is None:
        return _gunzip(gz)
    return None


_GUNZIP_LOCK = threading.Lock()


def _gunzip(gz):
    target = gz.with_name(gz.name[:-3])
    with _GUNZIP_LOCK:
        if not target.exists():
            part = target.with_name(target.name + ".part")
            with gzip.open(gz, "rb") as src, open(part, "wb") as dst:
                shutil.copyfileobj(src, dst, 1 << 20)
            part.replace(target)
    return target


def drop_broken_link(path):
    """Apaga um link quebrado (ex. pasta work/ copiada de outra maquina,
    com links para /home/<outro usuario>/...) para ele ser refeito."""
    if path.is_symlink() and not path.exists():
        path.unlink()


def database_files(variant):
    return [n for n in variant.acmdbi.split(";") + [variant.miscla] if n]


def missing_databases(variant):
    return [n for n in database_files(variant) if find_file(n) is None]


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


# ---------------------------------------------------------------- calculo

def check(aircraft, variant):
    if not aircraft.supported:
        raise ScapError(f"{aircraft.name} ainda nao esta ligado "
                        f"(motor {aircraft.engine})")
    if aircraft.engine == "octopus":
        engine_files = ENGINE_FILES
        find_example(variant)
    elif aircraft.engine == "takeoff_module":
        from tm_engine import COPY_FILES as engine_files
    else:
        from atr_engine import SO_PATH
        if platform.system() != "Linux":
            raise ScapError("O ATR so roda no Linux (DllWrapperATR.so)")
        if not SO_PATH.exists():
            raise ScapError(f"Nao achei {SO_PATH}")
        engine_files = ()
    missing = missing_databases(variant) + [
        n for n in engine_files if find_file(n) is None]
    if missing:
        raise ScapError(f"Arquivo nao encontrado em {SCAP_DIR}: "
                        + ", ".join(missing))


def _transient(out):
    """Falha esporadica do motor no Wine: o mesmo scap.in passa se repetir."""
    return out is None or any("OCTOCNF" in m for m in out["errmsg"])


def compute(aircraft, variant, runway=None, temperature=None, slot=0,
            align=None, retries=2, cond=CALM):
    """Roda o motor da aeronave e devolve o resultado resumido:
    mtow, flap, limit_code, v1_min, v1_max, vr, v2 (None se o motor nao da).
    cond: vento/QNH (Conditions); o traves so entra no Airbus, como no
    INPUT.FOR."""
    check(aircraft, variant)
    if aircraft.engine != "octopus":
        if runway is None or temperature is None:
            raise ScapError(f"{aircraft.name}: escolha a pista e a temperatura")
        align = align or {12: 0, 13: 0}
        if aircraft.engine == "ttam":
            import atr_engine
            return atr_engine.compute(variant, runway, temperature, align,
                                      slot, cond=cond)
        import tm_engine
        return tm_engine.compute(aircraft, variant, runway, temperature,
                                 align, slot, cond=cond)

    # Airbus: scap.in -> scap_octopus.dll -> SCAP.OUT
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


def default_workers():
    """Calculos em paralelo: PERF_WORKERS ou metade dos nucleos (max. 6)."""
    if os.environ.get("PERF_WORKERS", "").isdigit():
        return max(1, int(os.environ["PERF_WORKERS"]))
    return max(1, min(6, (os.cpu_count() or 2) // 2))


def compute_cases(aircraft, variant, runway, cases, workers=None,
                  on_progress=None, align=None):
    """Calcula varias combinacoes (temperatura, Conditions) em paralelo.
    Devolve uma lista na ordem de cases com o resultado ou {'error'}."""
    check(aircraft, variant)
    workers = workers or default_workers()
    slots = Queue()
    for i in range(workers):
        slots.put(i + 1)          # w0 fica para o calculo unico
    done = [0]
    lock = threading.Lock()

    def one(case):
        temp, cond = case
        slot = slots.get()
        try:
            res = compute(aircraft, variant, runway, temp, slot, align,
                          cond=cond)
        except ScapError as e:
            res = {"temperature": temp, "error": str(e)}
        finally:
            slots.put(slot)
        with lock:
            done[0] += 1
            count = done[0]
        if on_progress:
            on_progress(count, len(cases))
        return res

    with ThreadPoolExecutor(workers) as pool:
        return list(pool.map(one, cases))


def compute_tasks(tasks, workers=None, on_progress=None):
    """Calcula varias tarefas misturando aeronaves e pistas, num pool so de
    pastas de trabalho (nunca duas tarefas no mesmo slot ao mesmo tempo).
    tasks: lista de (aircraft, variant, runway, temperatura, Conditions,
    align). Devolve os resultados na mesma ordem (ou {'error'})."""
    for aircraft, variant in {(t[0], t[1]) for t in tasks}:
        check(aircraft, variant)
    workers = workers or default_workers()
    slots = Queue()
    for i in range(workers):
        slots.put(i + 1)
    done = [0]
    lock = threading.Lock()

    def one(task):
        aircraft, variant, runway, temp, cond, align = task
        slot = slots.get()
        try:
            res = compute(aircraft, variant, runway, temp, slot, align,
                          cond=cond)
        except ScapError as e:
            res = {"temperature": temp, "error": str(e)}
        finally:
            slots.put(slot)
        with lock:
            done[0] += 1
            count = done[0]
        if on_progress:
            on_progress(count, len(tasks))
        return res

    with ThreadPoolExecutor(workers) as pool:
        return list(pool.map(one, tasks))


def compute_range(aircraft, variant, runway, temperatures, workers=None,
                  on_progress=None, align=None, cond=CALM):
    """Varias temperaturas com o mesmo vento/QNH (ver compute_cases)."""
    return compute_cases(aircraft, variant, runway,
                         [(t, cond) for t in temperatures], workers,
                         on_progress, align)

"""Embraer E1 (E190/E195) e E2: roda o takeoff_module.exe (Wine no Linux).

Escreve o takeoff_data.dat na ordem dos READ do INPUT.FOR, roda o
takeoff_module.exe e le o takeoff_result.dat (MTOW, flap, limitante). O
proprio takeoff_module escolhe a base pela largura da pista, busca o flap
otimo (CONF(3) = 5) e chama a DLL do Embraer (ETM170 ou ETME2).

Cada calculo roda em work/tm<slot>: o .exe e as DLLs sao copiados (o Wine
procura as DLLs na pasta do .exe) e as bases entram como links. Os arquivos
que o programa grava (takeoff_result.dat, trace.txt, TRACE_TO.DAT...) ficam
so na pasta de trabalho.

No modo de um ponto (ANALYSIS = 0) o takeoff_module nao devolve V1/VR/V2.
"""

import os
import platform
import shutil
import subprocess

EXE = "takeoff_module.exe"
# Copiados (pequenos; o .exe carrega as DLLs da propria pasta)
COPY_FILES = (EXE, "DFORRT.DLL", "msvcr120.dll",
              "ETM170v140_CAFM-40094_200.dll", "ETME2_v301.dll",
              "TRACE_TO.AFM")
NA = "9E20"
LINK_ABOVE = 100 * 1024 * 1024   # bases maiores que isso entram como link
MAX_OBSTACLES = 15


def data_file(aircraft, variant, runway, temperature, align,
              wind=0.0, qnh=1013.25, flap=None, cg=0):
    """takeoff_data.dat: 'CHAVE: valor' na ordem exata dos READ do INPUT.FOR.
    Sem espacos nos valores (o READ e list-directed)."""
    fmt = lambda v: f"{v:g}"
    rows = [
        ("ANALYSIS", "0"),
        ("ACTYPE", aircraft.actype),
        ("ENGTYP", variant.engtyp),
        ("RATING", variant.rating),
        ("POPT(12)", fmt(align[12])), ("POPT(13)", fmt(align[13])),
        ("POPT(14)", "0"),                      # pista seca
        ("POPT(24)", fmt(variant.mtow)),
        ("POPT(30)", str(cg)),                  # limite dianteiro de CG
        ("CONF(3)", str(flap or 5)),            # 1 a 4; 5 = flap otimo
        ("XMET(1)", fmt(temperature)), ("XMET(2)", fmt(wind)),
        ("XMET(3)", "0"), ("XMET(5)", fmt(qnh)),
        ("RWYD(1)", fmt(runway.elev)), ("RWYD(3)", fmt(runway.tora)),
        ("RWYD(4)", fmt(runway.asda)), ("RWYD(5)", fmt(runway.toda)),
        ("RWYD(6)", fmt(runway.slope)),
        # RWYD(8): no Embraer 0 = normal, 2 = grooved (1 e invalido); em pista
        # seca nao muda o resultado
        ("RWYD(8)", "2" if runway.grooved else "0"),
        ("RWYD(11)", fmt(runway.width)),
        ("OBSD(1)", str(len(runway.obstacles[:MAX_OBSTACLES]))),
    ]
    obstacles = runway.obstacles[:MAX_OBSTACLES]
    for k in range(MAX_OBSTACLES):
        dist, height = (fmt(obstacles[k][0]), fmt(obstacles[k][1])) \
            if k < len(obstacles) else (NA, NA)
        rows += [(f"OBSD({3 * k + 3})", dist), (f"OBSD({3 * k + 4})", height)]
    return "".join(f"{key}: {value}\r\n" for key, value in rows)


def prepare_workdir(variant, slot):
    from scap_engine import (WORK_DIR, ScapError, database_files,
                             drop_broken_link, find_file)

    folder = WORK_DIR / f"tm{slot}"
    folder.mkdir(parents=True, exist_ok=True)
    for name in COPY_FILES:
        source = find_file(name)
        if source is None:
            raise ScapError(f"Arquivo nao encontrado: {name}")
        target = folder / source.name
        if not target.exists():
            shutil.copy2(source, target)
    for name in database_files(variant):
        source = find_file(name)
        if source is None:
            raise ScapError(f"Base nao encontrada: {name}")
        target = folder / source.name
        drop_broken_link(target)
        # O runtime Fortran do Windows abre a base em modo exclusivo: dois
        # calculos em paralelo no mesmo arquivo (mesmo via link) dao "Open
        # error - Error code 30". Bases pequenas sao copiadas por pasta.
        if source.stat().st_size <= LINK_ABOVE:
            if target.is_symlink():
                target.unlink()
            if not target.exists():
                shutil.copy2(source, target)
        elif not (target.exists() or target.is_symlink()):
            try:
                target.symlink_to(source)
            except OSError:
                shutil.copy2(source, target)
    return folder


def parse_result(text):
    """takeoff_result.dat: MTOW / flap / limitante, ou ERROR + 2 mensagens."""
    lines = [l.strip() for l in text.splitlines()]
    if not lines or not lines[0]:
        return None, "takeoff_result.dat vazio"
    if lines[0].upper() == "ERROR":
        return None, "\n".join(l for l in lines[1:] if l) or "ERROR"
    try:
        mtow, flap, limit = (int(float(v)) for v in lines[:3])
    except ValueError:
        return None, "Nao entendi o takeoff_result.dat:\n" + text[:300]
    return (mtow, flap, limit), None


def compute(aircraft, variant, runway, temperature, align, slot=0,
            timeout=180, retries=1, cond=None):
    from scap_engine import ScapError

    folder = prepare_workdir(variant, slot)
    (folder / "takeoff_data.dat").write_text(
        data_file(aircraft, variant, runway, temperature, align,
                  *((cond.wind, cond.qnh, cond.flap, cond.cg) if cond else ())))
    result = folder / "takeoff_result.dat"

    if platform.system() == "Windows":
        cmd = [str(folder / EXE)]
    else:
        cmd = [os.environ.get("SCAP_WINE", "wine"), EXE]
    env = dict(os.environ, WINEDEBUG="-all")
    for _ in range(retries + 1):
        result.unlink(missing_ok=True)
        try:
            proc = subprocess.run(cmd, cwd=folder, env=env, timeout=timeout,
                                  stdin=subprocess.DEVNULL,
                                  capture_output=True, text=True,
                                  errors="replace")
        except FileNotFoundError:
            raise ScapError(f"Nao achei o programa '{cmd[0]}'")
        except subprocess.TimeoutExpired:
            raise ScapError(f"O takeoff_module nao terminou em {timeout} s")
        if result.exists() and result.stat().st_size:
            break
    if not result.exists():
        raise ScapError("O takeoff_module nao gerou takeoff_result.dat.\n"
                        + (proc.stdout + proc.stderr).strip()[-1500:])
    values, error = parse_result(result.read_text(errors="replace"))
    if error:
        raise ScapError(error)
    mtow, flap, limit = values
    return {
        "temperature": temperature, "mtow": mtow, "flap": f"FLAP {flap}",
        "limit_code": limit, "v1_min": None, "v1_max": None, "vr": None,
        "v2": None, "main": {}, "erflag": "A", "errmsg": [],
    }

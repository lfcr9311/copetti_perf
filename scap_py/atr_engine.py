"""ATR 72-600: chama o TTAM do DllWrapperATR.so (Linux, gfortran).

Faz o mesmo que o takeoff_module.exe faz para o ATR: monta os COMMON
/TINPN/ e /TINPA/ como o INICIALIZA.FOR + INPUT.FOR, chama TTAM e le
/TOUTN/ e /TOUTA/. O layout dos COMMON e o do DECLARA.FOR (os tamanhos dos
simbolos tinpa_/tinpn_/touta_/toutn_ do .so batem campo a campo).

Cada calculo roda num processo Python separado (este arquivo com --run), na
pasta work/atr<slot>: a biblioteca guarda estado global, abre a base pelo
nome na pasta atual e um STOP do Fortran mataria o processo que a carregou.
"""

import ctypes
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SO_PATH = HERE / "engines" / "DllWrapperATR.so"
NA = 9e20
RESULT_FILE = "ttam_result.json"

BLOCKS = ("POPT", "CONF", "XMET", "RWYD", "OBSD", "FPTD", "UNIT", "SPIA",
          "SPIB", "SPIC")
# /TINPA/ do DECLARA.FOR: (campo, largura, repeticoes)
TINPA_FIELDS = (("ACTYPE", 20, 1), ("ENGTYP", 20, 1), ("RATING", 20, 1),
                ("BRAKES", 20, 1), ("CERTIF", 20, 1), ("REVNBR", 20, 1),
                ("DATE", 20, 1), ("DBOPTI", 20, 1), ("ACMDBI", 255, 1),
                ("APTIDT", 20, 1), ("RWYNBR", 20, 1), ("COMENT", 132, 20),
                ("MISCLA", 255, 1), ("FDCFGI", 20, 1), ("CDLFIL", 255, 1))
TINPA_SIZE = 3625
TOUTA_SIZE = 3515          # ERFLAG*20, ERRMSG(20)*80, MMIDNT, MMDATE, ACMDBO, OUTMIS


def tinpa_offsets():
    offsets, pos = {}, 0
    for name, width, count in TINPA_FIELDS:
        offsets[name] = (pos, width)
        pos += width * count
    assert pos == TINPA_SIZE
    return offsets


# ------------------------------------------------------------- entrada

def build_inputs(variant, runway, temperature, align, wind=0.0, qnh=1013.25,
                 flap=None):
    """COMMON de entrada como o INPUT.FOR monta para o ATR (ramo ELSE),
    pista seca. Devolve {'num': {bloco: {i: valor}}, 'chr': {campo: texto}}."""
    num = {b: {} for b in BLOCKS}
    P, C, X, R, O, F, U, S = (num[b] for b in BLOCKS[:8])

    # lidos do takeoff_data.dat
    P.update({12: align[12], 13: align[13], 14: 0, 24: variant.mtow, 30: 0})
    X.update({1: temperature, 2: wind, 5: qnh})
    R.update({1: runway.elev, 3: runway.tora, 4: runway.asda,
              5: runway.toda, 6: runway.slope, 8: 0, 11: runway.width})
    O[1] = len(runway.obstacles)
    for k, (dist, height) in enumerate(runway.obstacles):
        O[3 * k + 3] = dist
        O[3 * k + 4] = height

    # valores fixos + ramo ELSE (ATR) do INPUT.FOR
    P.update({2: 0, 5: 0, 10: 35, 11: 0, 18: 0, 19: 400, 20: 1, 21: 16,
              22: 17, 23: 1, 27: 0, 33: 0, 36: 0, 39: 0, 41: 0})
    P.update({1: 0, 7: 0, 17: 0, 30: 0, 43: 0, 9: 35})
    C.update({1: 1, 4: 2, 5: 0, 6: 0, 17: 0, 20: 0})
    C.update({2: 0, 3: 15 if flap is None else flap, 7: 0, 8: 0, 9: 0,
              12: 0, 14: 0, 15: 0, 32: 0, 54: 0})
    rating = variant.rating
    if "BOOSTON+RTOON" in rating:
        C.update({55: 1, 56: 2})
    elif "BOOSTOFF+RTOON" in rating:
        C.update({55: 1, 56: 1})
    elif "BOOSTON+RTOOFF" in rating:
        C.update({55: 0, 56: 2})
    else:
        C.update({55: 0, 56: 1})
    X[4] = 1
    R.update({2: 0, 9: 1, 10: 0})
    O[2] = 1
    F[1] = 0
    U.update({1: 0, 3: 0, 4: 1, 5: 1, 6: 0, 8: 0, 9: 2})
    for i in range(1, 32, 2):
        S[i] = 1
    for i in range(2, 33, 2):
        S[i] = 0
    for i in (7, 8, 13, 14, 21, 22, 25, 26):
        S.pop(i, None)

    chars = {"ACTYPE": "", "ENGTYP": variant.engtyp, "RATING": rating,
             "CERTIF": "FAR", "ACMDBI": variant.acmdbi}
    return {"num": num, "chr": chars}


# ------------------------------------------------------------- execucao

def compute(variant, runway, temperature, align, slot=0, timeout=120,
            cond=None):
    from scap_engine import WORK_DIR, ScapError, drop_broken_link, find_file

    if not SO_PATH.exists():
        raise ScapError(f"Nao achei {SO_PATH}")
    folder = WORK_DIR / f"atr{slot}"
    folder.mkdir(parents=True, exist_ok=True)
    # O TTAM abre ACMDBI pelo nome exato (Linux diferencia maiusculas)
    source = find_file(variant.acmdbi)
    if source is None:
        raise ScapError(f"Base do ATR nao encontrada: {variant.acmdbi}")
    link = folder / variant.acmdbi
    drop_broken_link(link)
    if not (link.exists() or link.is_symlink()):
        link.symlink_to(source)

    data = build_inputs(variant, runway, temperature, align,
                        *((cond.wind, cond.qnh, cond.flap) if cond else ()))
    result_path = folder / RESULT_FILE
    result_path.unlink(missing_ok=True)
    try:
        proc = subprocess.run(
            [sys.executable, str(Path(__file__)), "--run"], cwd=folder,
            input=json.dumps(data), capture_output=True, text=True,
            timeout=timeout, errors="replace")
    except subprocess.TimeoutExpired:
        raise ScapError(f"O TTAM nao terminou em {timeout} s")
    if not result_path.exists():
        raise ScapError("O TTAM terminou sem resultado.\n"
                        + (proc.stdout + proc.stderr).strip()[-1500:])
    out = json.loads(result_path.read_text())
    climit = out["climit"]
    errmsg = [m for m in out["errmsg"] if m]
    if out["erflag"] not in ("A", "D"):
        raise ScapError(f"ERFLAG = {out['erflag'] or '?'}\n"
                        + "\n".join(errmsg))

    c = lambda i: climit[i - 1]
    code = int(c(8))
    if code in (22, 23, 4, 9):          # mesmos ajustes do takeoff_module.for
        code = 3
    return {
        "temperature": temperature,
        "mtow": int(c(1)),
        "flap": f"FLAP {c(3):.0f}",
        "limit_code": code,
        "v1_min": c(7), "v1_max": c(13), "vr": c(6), "v2": c(5),
        "main": {}, "erflag": out["erflag"], "errmsg": errmsg,
    }


def _run_in_process():
    """Roda dentro da pasta de trabalho: preenche os COMMON e chama TTAM."""
    data = json.loads(sys.stdin.read())
    lib = ctypes.CDLL(str(SO_PATH))

    tinpn = (ctypes.c_float * 2000).in_dll(lib, "tinpn_")
    for k in range(2000):                 # INICIALIZA.FOR: tudo 9E20
        tinpn[k] = NA
    for b, values in data["num"].items():
        base = BLOCKS.index(b) * 200
        for i, v in values.items():
            tinpn[base + int(i) - 1] = float(v)

    tinpa = (ctypes.c_char * TINPA_SIZE).in_dll(lib, "tinpa_")
    ctypes.memset(tinpa, ord(" "), TINPA_SIZE)
    offsets = tinpa_offsets()
    for name, text in data["chr"].items():
        pos, width = offsets[name]
        raw = text.encode("latin-1")[:width].ljust(width)
        ctypes.memmove(ctypes.addressof(tinpa) + pos, raw, width)

    touta = (ctypes.c_char * TOUTA_SIZE).in_dll(lib, "touta_")
    ctypes.memset(touta, ord(" "), TOUTA_SIZE)
    toutn = (ctypes.c_float * 1800).in_dll(lib, "toutn_")
    for k in range(1800):
        toutn[k] = NA

    lib.ttam_()

    raw = bytes(touta)
    result = {
        "climit": [toutn[k] for k in range(200)],
        "erflag": raw[:20].decode("latin-1").strip(),
        "errmsg": [raw[20 + 80 * i:100 + 80 * i].decode("latin-1").strip()
                   for i in range(20)],
    }
    Path(RESULT_FILE).write_text(json.dumps(result))


if __name__ == "__main__" and sys.argv[1:] == ["--run"]:
    _run_in_process()

"""ATR 72-600: decolagem pelo TTAM da ATR (TTAM.dll do pacote SCAP APS
2.7.1), rodado pelo SCAPApp.exe oficial (perf/scapapp.py), com a licenca da
ATR e a base MUE6DC3E.PDF.

A entrada e a mesma que o takeoff_module.exe monta para o ATR (INICIALIZA.FOR
+ INPUT.FOR, ramo ELSE), em XML como o SCAP.in de referencia do pacote.
Campos: manual TTAM H2-O9 (OCT 2025).
"""

from ..scapapp import ScapAppError, rodar, xml_entrada
from .common import ScapError

BLOCKS = ("POPT", "CONF", "XMET", "RWYD", "OBSD", "FPTD", "UNIT", "SPIA",
          "SPIB", "SPIC")


# ------------------------------------------------------------- entrada

def build_inputs(variant, runway, temperature, align, wind=0.0, qnh=1013.25,
                 flap=None, mtow=None, aircond=False):
    """COMMON de entrada como o INPUT.FOR monta para o ATR (ramo ELSE),
    pista seca. Devolve {'num': {bloco: {i: valor}}, 'chr': {campo: texto}}."""
    num = {b: {} for b in BLOCKS}
    P, C, X, R, O, F, U, S = (num[b] for b in BLOCKS[:8])

    # lidos do takeoff_data.dat
    P.update({12: align[12], 13: align[13], 14: 0, 24: mtow or variant.mtow, 30: 0})
    X.update({1: temperature, 2: wind, 5: qnh})
    R.update({1: runway.elev, 3: runway.tora, 4: runway.asda,
              5: runway.toda, 6: runway.slope, 8: 0, 11: runway.width})
    # obstaculos a partir do inicio da TORA (OBSD 2 = 0), como o SPS: o
    # cadastro mede do fim da TORA; a altura soma o desnivel da pista
    # (slope % x TORA, em ft como UNIT 4), arredondada para pe inteiro como
    # o SPS. Com slope acentuado o TTAM da resultados um pouco diferentes
    # conforme a referencia (ex. SBSR 25).
    rise = runway.slope / 100 * runway.tora / 0.3048
    O[1] = len(runway.obstacles)
    for k, (dist, height) in enumerate(runway.obstacles):
        O[3 * k + 3] = runway.tora + dist
        O[3 * k + 4] = round(height + rise)

    # valores fixos + ramo ELSE (ATR) do INPUT.FOR
    P.update({2: 0, 5: 0, 10: 35, 11: 0, 18: 0, 19: 400, 20: 1, 21: 16,
              22: 17, 23: 1, 27: 0, 33: 0, 36: 0, 39: 0, 41: 0})
    P.update({1: 0, 7: 0, 17: 0, 30: 0, 43: 0, 9: 35})
    P[49] = 0                            # perform dry check (pedido do engenheiro)
    C.update({1: 1, 4: 1 if aircond else 2, 5: 0, 6: 0, 17: 0, 20: 0})   # CONF 4: ar 1 ON, 2 OFF
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
    O[2] = 0
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

def compute(variant, runway, temperature, align, slot=0, timeout=180,
            cond=None):
    data = build_inputs(variant, runway, temperature, align,
                        *((cond.wind, cond.qnh, cond.flap, cond.mtow, cond.aircond) if cond else ()))
    arrays = {b: v for b, v in data["num"].items() if v}
    elementos = {"ACTYPE": "ATR72-600", "ENGTYP": data["chr"]["ENGTYP"].replace("_M", ""),
                 "BRAKES": "N/A", "ACMDBI": data["chr"]["ACMDBI"], "CERTIF": data["chr"]["CERTIF"],
                 "APTIDT": runway.icao, "RWYNBR": runway.rwy, "MISCLA": "", "FDCFGI": ""}
    entrada = xml_entrada("TAKEOFF", arrays, elementos)
    try:
        return _ler(entrada, slot, timeout, temperature)
    except ScapError as e:
        e.entrada = entrada
        raise


def _ler(entrada, slot, timeout, temperature):
    try:
        out, el = rodar(f"atrdecol{slot}", entrada, timeout)
    except ScapAppError as e:
        raise ScapError(str(e))
    climit = out.get("CLIMIT", {})
    erflag = el.get("ERFLAG", "")
    errmsg = [v for _, v in sorted(out.get("ERRMSG", {}).items()) if isinstance(v, str) and v.strip()]
    if erflag[:1] not in ("A", "D", "F") or climit.get(1) is None:
        raise ScapError(f"ERFLAG = {erflag or '?'}\n" + "\n".join(errmsg))

    c = climit.get
    code = int(c(8))
    if code in (22, 23, 4, 9):          # mesmos ajustes do takeoff_module.for
        code = 3
    return {
        "temperature": temperature,
        "mtow": int(c(1)),
        "flap": f"FLAP {c(3):.0f}",
        "limit_code": code,
        "v1_min": c(7), "v1_max": c(13), "vr": c(6), "v2": c(5),
        "main": {}, "erflag": erflag, "errmsg": errmsg, "entrada": entrada,
    }

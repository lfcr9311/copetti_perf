#!/usr/bin/env python3
"""Performance de Decolagem - app web local.

    python3 server.py            # abre http://127.0.0.1:8765 no navegador

So biblioteca padrao: um servidor HTTP local (127.0.0.1) entrega a pagina
(web/) e uma API JSON que usa o pacote perf/ (perf.takeoff, perf.landing,
perf.schedule). Os calculos rodam em segundo plano; a pagina acompanha o
progresso pela API. Varias pessoas podem calcular ao mesmo tempo (cada
calculo usa a sua pasta de trabalho).
"""

import argparse
import csv
import dataclasses
import hmac
import json
import mimetypes
import os
import platform
import re
import shutil
import subprocess
import threading
import time
import traceback
import uuid
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

from perf import blocked, schedule
from perf.batch import COLUMNS, condition_columns, result_row, temperatures
from perf.catalog.aircraft import AIRCRAFT, flap_options
from perf.catalog.airports import MAX_OBSTACLES, align_values, load_airports, load_toalign
from perf.landing import airbus as landing_airbus
from perf.landing import atr as landing_atr
from perf.landing import embraer as landing_embraer
from perf.paths import ASSETS_DIR, RESULTS_DIR, WEB_DIR
from perf.takeoff import engine as takeoff
MAX_CASES = 3000          # combinacoes de condicoes
MAX_TOTAL = 20000         # aeronaves x pistas x combinacoes
MAX_BODY = 30 * 1024 * 1024   # malha enviada pelo navegador

# Servidor (AWS, Oracle...): variaveis de ambiente
#   PERF_HOST          endereco (padrao 127.0.0.1; no servidor 0.0.0.0)
#   PERF_PORT          porta (padrao 8765)
#   PERF_PASSWORD      senha pedida na tela (sem ela, qualquer um calcula)
#   PERF_CORS_ORIGIN   site que pode chamar a API (ex. https://perf.vercel.app)
#   PERF_SERVER=1      modo servidor: a malha vem do navegador (upload) e
#                      volta para download; nada e aberto na maquina
PASSWORD = os.environ.get("PERF_PASSWORD", "")
CORS_ORIGINS = {o.strip().rstrip("/") for o in
                os.environ.get("PERF_CORS_ORIGIN", "").split(",") if o.strip()}
SERVER_MODE = os.environ.get("PERF_SERVER", "") == "1"

# limitation.lis
LIMITS = {
    0: "Verificação de pista seca", 1: "Peso estrutural",
    2: "Distância – todos os motores", 3: "Distância – motor inoperante",
    9: "VMCG", 10: "Velocidade dos pneus", 12: "Energia dos freios",
    13: "V2 mínimo (VMCA)", 14: "Subida – 1º segmento",
    15: "Subida – 2º segmento", 17: "Aceleração (3º segmento)",
    18: "Subida – segmento final", 19: "Obstáculo",
    20: "Corrida – motor inoperante", 21: "Corrida – todos os motores",
    24: "Inclinação da pista", 25: "Pista – motor inoperante",
    26: "Pista – todos os motores", 30: "V2 mínimo (VMU)", 51: "Arremetida",
}


def limit_text(code):
    if code in (None, ""):
        return ""
    return LIMITS.get(int(code), f"Código {code}")


class BadRequest(Exception):
    pass


# ------------------------------------------------------------------ dados

AIRPORTS = load_airports()
TOALIGN = load_toalign()
try:
    IATA_BY_ICAO = {icao: iata for iata, icao in schedule.load_iata().items()}
except OSError:
    IATA_BY_ICAO = {}


def meta():
    aircraft = []
    for i, ac in enumerate(AIRCRAFT):
        variants = []
        for j, v in enumerate(ac.variants):
            try:
                takeoff.check(ac, v)
                ready, reason = True, ""
            except takeoff.ScapError as e:
                ready, reason = False, str(e).splitlines()[0]
            try:                # MTOW estrutural da base (POPT 24)
                mtow = schedule.structural_mtow(ac, v)
            except (OSError, takeoff.ScapError):
                mtow = None
            variants.append({"id": j, "label": v.display, "ready": ready,
                             "reason": reason, "database": v.acmdbi,
                             "structural": mtow})
        try:                    # peso estrutural do motor usado na malha
            structural = schedule.structural_mtow(ac, ac.variants[0])
        except (OSError, takeoff.ScapError):
            structural = None
        aircraft.append({"id": i, "name": ac.name, "engine": ac.engine,
                         "structural": structural,
                         "flaps": [{"code": c, "label": n}
                                   for c, n in flap_options(ac)],
                         "cg": [{"code": c, "label": n} for c, n in ac.cg],
                         "mtows": list(ac.mtows),
                         "speeds": ac.engine != "takeoff_module",
                         "crosswind": ac.engine == "octopus",
                         "variants": variants})
    airports = [{"icao": icao, "name": a["name"].title(),
                 "iata": IATA_BY_ICAO.get(icao, ""),
                 "runways": len(a["runways"])}
                for icao, a in sorted(AIRPORTS.items())]
    return {"aircraft": aircraft, "airports": airports,
            "malha": "" if SERVER_MODE else str(schedule.DEFAULT_MALHA),
            "server": SERVER_MODE}


def airport(icao):
    a = AIRPORTS.get(icao.upper())
    if not a:
        raise BadRequest(f"Aeroporto {icao} não está no airports_list.csv")
    return {"icao": icao.upper(), "name": a["name"].title(),
            "iata": IATA_BY_ICAO.get(icao.upper(), ""),
            "runways": [{"rwy": r.rwy, "elev": r.elev, "tora": r.tora,
                         "toda": r.toda, "asda": r.asda, "width": r.width,
                         "slope": r.slope, "surface": r.surface,
                         "to_align": r.to_align or "0",
                         "obstacles": r.obstacles}
                        for r in a["runways"].values()]}


# ----------------------------------------------------------- condicoes

def number(value, name):
    try:
        return float(str(value).replace(",", "."))
    except (TypeError, ValueError):
        raise BadRequest(f"{name}: valor inválido “{value}”")


def spec_values(spec, name):
    """{'mode': 'single', 'value': x} ou {'mode': 'range', min, max, step}."""
    if (spec or {}).get("mode") == "range":
        lo, hi, step = (number(spec.get(k), name) for k in ("min", "max", "step"))
        if step <= 0:
            raise BadRequest(f"{name}: o intervalo tem que ser maior que zero")
        values = temperatures(lo, hi, step)
        if not values:
            raise BadRequest(f"{name}: o valor inicial é maior que o final")
        return values
    return [number((spec or {}).get("value"), name)]


def build_cases(body):
    temps = [int(t) if float(t).is_integer() else t
             for t in spec_values(body.get("temp"), "Temperatura")]
    qnhs = spec_values(body.get("qnh"), "QNH")
    for q in qnhs:
        if not 900 <= q <= 1100:
            raise BadRequest(f"QNH fora da faixa (900 a 1100 hPa): {q:g}")
    wind = body.get("wind") or {}
    if wind.get("mode") == "range":
        winds = [(w, 0.0) for w in spec_values(wind, "Vento")]
    else:
        kind = wind.get("kind", "calm")
        speed = 0.0 if kind == "calm" else number(wind.get("speed"), "Vento")
        if speed < 0:
            raise BadRequest("Vento: informe a velocidade sem sinal e escolha "
                             "proa, cauda ou través")
        side = 1 if wind.get("side", "right") == "right" else -1
        winds = [{"calm": (0.0, 0.0), "head": (speed, 0.0),
                  "tail": (-speed, 0.0), "cross": (0.0, side * speed)}
                 .get(kind, (0.0, 0.0))]
    aircond = body.get("ar") == "on"        # ar-condicionado na decolagem (CONF 4)
    cases = [(t, takeoff.Conditions(w, x, q, aircond=aircond))
             for t in temps for w, x in winds for q in qnhs]
    if len(cases) > MAX_CASES:
        raise BadRequest(f"São {len(cases)} combinações; o limite é "
                         f"{MAX_CASES}. Aumente os intervalos.")
    return cases


def pick_flaps(body, multi=False):
    """body['flaps'] = {nome da aeronave: codigo | [codigos]}; None/"opt" =
    flap otimo. multi=False: {nome: codigo} (so um, otimo fica de fora).
    multi=True: {nome: [None (otimo) e/ou codigos]}, na ordem das opcoes."""
    out = {}
    for name, value in (body.get("flaps") or {}).items():
        ac = next((a for a in AIRCRAFT if a.name == name), None)
        options = [c for c, _ in flap_options(ac)] if ac else []
        chosen = set()
        for code in value if isinstance(value, list) else [value]:
            if code in (None, "", "opt"):
                chosen.add(None)
                continue
            try:
                code = int(code)
            except (TypeError, ValueError):
                code = None
            if code not in options:
                raise BadRequest(f"Flap inválido para {name}: {code}")
            chosen.add(code)
        ordered = ([None] if None in chosen else []) + \
            [c for c in options if c in chosen]
        if multi:
            if ordered and ordered != [None]:
                out[name] = ordered
        elif ordered and ordered[-1] is not None:
            out[name] = ordered[-1]
    return out


def pick_cg(body, multi=False):
    """body['cg'] = {nome da aeronave: codigo | [codigos]} do POPT 30 (limite
    dianteiro de CG), aceitos pela base da aeronave; ausente = Standard (0).
    multi=False: {nome: codigo} (so um; Standard fica de fora).
    multi=True: {nome: [codigos]} na ordem das opcoes (so Standard fica de
    fora)."""
    out = {}
    for name, value in (body.get("cg") or {}).items():
        ac = next((a for a in AIRCRAFT if a.name == name), None)
        if ac is None:
            continue
        chosen = set()
        for item in value if isinstance(value, list) else [value]:
            if item in (None, ""):
                continue
            try:
                code = int(item)
            except (TypeError, ValueError):
                code = None
            if code not in dict(ac.cg):
                raise BadRequest(f"Limite de CG inválido para {name}: {item}")
            chosen.add(code)
        ordered = [c for c, _ in ac.cg if c in chosen]
        if multi:
            if ordered and ordered != [0]:
                out[name] = ordered
        elif ordered and ordered[-1]:
            out[name] = ordered[-1]
    return out


def pick_mtow(body):
    """body['mtow'] = {nome da aeronave: kg}: peso estrutural maximo de
    decolagem (POPT 24) no lugar do da base; vazio = o da base."""
    out = {}
    for name, value in (body.get("mtow") or {}).items():
        ac = next((a for a in AIRCRAFT if a.name == name), None)
        if value in (None, "") or ac is None:
            continue
        kg = number(value, f"MTOW estrutural do {name}")
        if kg not in ac.mtows:
            raise BadRequest(f"MTOW estrutural inválido para {name}: {kg:g} "
                             f"(opções: {', '.join(f'{m:g}' for m in ac.mtows) or 'só o da base'})")
        out[name] = kg
    return out


def flap_units(planes, flaps, cgs=None, mtows=None):
    """[(aircraft, variant, flap, nome do flap, cg, nome do cg, mtow)] para
    cada aeronave, flap e limite de CG escolhidos. Nome vazio = so o otimo /
    so o Standard (sem sufixo na chave); mtow None = o da base."""
    cgs, mtows = cgs or {}, mtows or {}
    units = []
    for ac, v in planes:
        names, cg_names = dict(flap_options(ac)), dict(ac.cg)
        mtow = mtows.get(ac.name)
        for code in flaps.get(ac.name, [None]):
            label = "" if ac.name not in flaps else \
                "Flap ótimo" if code is None else names[code]
            for cg in cgs.get(ac.name, [0]):
                cg_text = f"CG {cg_names[cg]}" if ac.name in cgs else ""
                units.append((ac, v, code, label, cg, cg_text, mtow))
    return units


def pick_aircraft(body):
    """[(aircraft, variant)] de body['selection'] = [{aircraft, variant}]
    (ou o formato antigo, body['aircraft'] / body['variant'])."""
    items = body.get("selection")
    if items is None and "aircraft" in body:
        items = [{"aircraft": body["aircraft"], "variant": body.get("variant")}]
    chosen = []
    for item in items or []:
        try:
            ac = AIRCRAFT[int(item["aircraft"])]
            v = ac.variants[int(item["variant"])]
        except (KeyError, IndexError, ValueError, TypeError):
            raise BadRequest("Seleção de aeronave inválida")
        if (ac, v) not in chosen:
            chosen.append((ac, v))
    if not chosen:
        raise BadRequest("Escolha pelo menos uma aeronave")
    return chosen


# Campos da pista que o usuario pode alterar (ex.: NOTAM com parte da pista
# fechada). Os obstaculos vem a parte (override['obstacles']).
#   campo -> (atributo do Runway, nome, minimo, maximo)
RUNWAY_EDIT = {
    "elev": ("elev", "RUNWAY ELEVATION (RWYD1)", -2000, 16000),
    "tora": ("tora", "TORA (RWYD3)", 100, 6000),
    "asda": ("asda", "ASDA (RWYD4)", 100, 6000),
    "toda": ("toda", "TODA (RWYD5)", 100, 8000),
    "slope": ("slope", "SLOPE TODA (RWYD6)", -5, 5),
    "width": ("width", "RUNWAY WIDTH (RWYD11)", 10, 100),
}
# obstaculo: distancia do fim da TORA (m) e altura (ft), como no cadastro
OBSTACLE_DIST = (0, 20000)
OBSTACLE_HEIGHT = (0, 5000)


def edited_obstacles(rw, items):
    """Lista de obstaculos que vai para o calculo: [{dist, height, on}]
    (on=False fica de fora) ou [dist, height]. Ordenada pela distancia."""
    if not isinstance(items, list):
        raise BadRequest(f"{rw.icao} {rw.rwy}: lista de obstáculos inválida")
    out = []
    for n, item in enumerate(items, 1):
        if isinstance(item, dict):
            if item.get("on") is False:
                continue
            dist, height = item.get("dist"), item.get("height")
        elif isinstance(item, (list, tuple)) and len(item) == 2:
            dist, height = item
        else:
            raise BadRequest(f"{rw.icao} {rw.rwy}: obstáculo {n} inválido")
        dist = number(dist, f"{rw.icao} {rw.rwy} obstáculo {n}: distância")
        height = number(height, f"{rw.icao} {rw.rwy} obstáculo {n}: altura")
        for value, (lo, hi), what, unit in (
                (dist, OBSTACLE_DIST, "distância", "m"),
                (height, OBSTACLE_HEIGHT, "altura", "ft")):
            if not lo <= value <= hi:
                raise BadRequest(f"{rw.icao} {rw.rwy}: obstáculo {n} com {what} "
                                 f"fora da faixa ({lo} a {hi} {unit}): {value:g}")
        out.append((dist, height))
    if len(out) > MAX_OBSTACLES:
        raise BadRequest(f"{rw.icao} {rw.rwy}: {len(out)} obstáculos marcados; "
                         f"o limite dos motores é {MAX_OBSTACLES}")
    return sorted(out)


def edited_runway(rw, override):
    """Copia da pista com os valores alterados (RWYD 1, 3, 4, 5, 6, 8, 11 e
    os obstaculos)."""
    changes = {}
    for key, (attr, label, lo, hi) in RUNWAY_EDIT.items():
        if override.get(key) in (None, ""):
            continue
        value = number(override[key], label)
        if not lo <= value <= hi:
            raise BadRequest(f"{rw.icao} {rw.rwy}: {label} fora da faixa "
                             f"({lo} a {hi}): {value:g}")
        changes[attr] = value
    if "surface" in override:                    # RWYD8: normal ou grooved
        changes["surface"] = ("GROOVED" if str(override["surface"]).lower()
                              in ("grooved", "2", "1") else "NORMAL")
    if override.get("obstacles") is not None:    # OBSD
        obstacles = edited_obstacles(rw, override["obstacles"])
        if obstacles != sorted(tuple(o) for o in rw.obstacles):
            changes["obstacles"] = obstacles
    new = dataclasses.replace(rw, **changes)
    if new == rw:
        return rw
    new.edited = True
    return new


def pick_runways(body):
    """[runway] de body['runways'] = [{icao, rwy, override?}] (ou icao/rwy
    antigos). override altera os dados da pista so neste calculo."""
    items = body.get("runways")
    if items is None and "icao" in body:
        items = [{"icao": body["icao"], "rwy": body.get("rwy")}]
    chosen, keys = [], set()
    for item in items or []:
        a = AIRPORTS.get(str(item.get("icao", "")).upper())
        name = str(item.get("rwy", ""))
        if not a or name not in a["runways"]:
            raise BadRequest(f"Pista inválida: {item.get('icao')} {name}")
        rw = a["runways"][name]
        if item.get("override"):
            rw = edited_runway(rw, item["override"])
        if runway_key(rw) not in keys:
            keys.add(runway_key(rw))
            chosen.append(rw)
    if not chosen:
        raise BadRequest("Escolha pelo menos uma pista")
    return chosen


# ---------------------------------------------------------------- jobs

JOBS = {}
JOBS_LOCK = threading.Lock()
MAX_JOBS = 8                    # jobs rodando ao mesmo tempo


def start_job(kind, work):
    """Roda work(job) numa thread. Varios jobs podem rodar juntos (varias
    pessoas): cada calculo pega a sua pasta de trabalho (takeoff.work_slot)
    e os motores dividem os mesmos PERF_WORKERS."""
    with JOBS_LOCK:
        if sum(j["state"] == "running" for j in JOBS.values()) >= MAX_JOBS:
            raise BadRequest(f"Já há {MAX_JOBS} cálculos em andamento no servidor; "
                             "tente de novo em instantes")
        job = {"id": uuid.uuid4().hex[:12], "kind": kind, "state": "running",
               "done": 0, "total": 0, "label": "", "result": None,
               "error": None}
        JOBS[job["id"]] = job

    def run():
        try:
            job["result"] = work(job)
            job["state"] = "done"
        except (BadRequest, takeoff.ScapError, schedule.MalhaError,
                OSError, ValueError) as e:
            job["error"], job["state"] = str(e), "error"
        except Exception as e:                      # erro inesperado: mostra
            traceback.print_exc()
            job["error"], job["state"] = f"Erro inesperado: {e}", "error"

    threading.Thread(target=run, daemon=True).start()
    return job


def calc_job(body):
    """Todas as combinacoes aeronave x pista x (temperatura, vento, QNH)."""
    planes = pick_aircraft(body)
    runways = pick_runways(body)
    cases = build_cases(body)
    units = flap_units(planes, pick_flaps(body, multi=True),
                       pick_cg(body, multi=True), pick_mtow(body))
    total = len(units) * len(runways) * len(cases)
    if total > MAX_TOTAL:
        raise BadRequest(f"São {total} cálculos (aeronaves/flaps/CG × pistas × "
                         f"combinações); o limite é {MAX_TOTAL}.")
    for ac, v in planes:
        try:
            takeoff.check(ac, v)
        except takeoff.ScapError as e:
            raise BadRequest(f"{ac.name} {v.display}: {e}")
    tasks, labels = [], []
    for ac, v, flap, label, cg, cg_text, mtow in units:
        for rw in runways:
            align = align_values(rw, ac.align, TOALIGN)
            for t, cond in cases:
                tasks.append((ac, v, rw, t,
                              dataclasses.replace(cond, flap=flap, cg=cg, mtow=mtow),
                              align))
                labels.append((label, cg_text))

    def work(job):
        job["total"] = len(tasks)

        def progress(done, total):
            job["done"], job["total"] = done, total

        results = takeoff.compute_tasks(tasks, on_progress=progress)
        rows, csv_rows = [], []
        for (ac, v, rw, t, cond, _), (label, cg_text), res in zip(
                tasks, labels, results):
            row = {"plane": plane_key(ac, v, label, cg_text, cond.mtow),
                   "runway": runway_key(rw),
                   "temp": t, "wind": cond.wind, "crosswind": cond.crosswind,
                   "qnh": cond.qnh}
            base = {"aircraft": ac.name, "engine": v.display, "icao": rw.icao,
                    "airport": rw.name,
                    "rwy": rw.rwy + (" (editada)" if getattr(rw, "edited", False) else ""),
                    "to_align": rw.to_align, "n_obst": len(rw.obstacles),
                    "temp_c": t, **condition_columns(cond),
                    "flap_sel": label or "ótimo",
                    "cg_sel": dict(ac.cg)[cond.cg],
                    "mtow_sel": cond.mtow or "base"}
            if "error" in res:
                row["error"] = " | ".join(res["error"].splitlines())
                base["error"] = row["error"]
            else:
                row.update(mtow=res["mtow"], flap=res["flap"],
                           limit=res["limit_code"],
                           limit_text=limit_text(res["limit_code"]),
                           v1_min=res["v1_min"], v1_max=res["v1_max"],
                           vr=res["vr"], v2=res["v2"], error="")
                base.update(result_row(res))
            if len(tasks) == 1:            # entrada do motor so no calculo unico
                row["entrada"] = res.get("entrada")
            rows.append(row)
            csv_rows.append(base)
        name = save_csv(csv_rows, planes, runways, cases)
        return {
            "planes": [{"key": plane_key(ac, v, label, cg_text, mtow),
                        "aircraft": ac.name, "engine": v.display, "flap": label,
                        "cg": cg_text, "mtow": mtow,
                        "speeds": ac.engine != "takeoff_module"}
                       for ac, v, _, label, _, cg_text, mtow in units],
            "runways": [{"key": runway_key(rw), "icao": rw.icao,
                         "rwy": rw.rwy, "airport": rw.name.title(),
                         "edited": getattr(rw, "edited", False),
                         "data": {"elev": rw.elev, "tora": rw.tora, "asda": rw.asda,
                                  "toda": rw.toda, "slope": rw.slope,
                                  "surface": rw.surface, "width": rw.width,
                                  "obstacles": rw.obstacles}}
                        for rw in runways],
            "rows": rows, "csv": name}

    return start_job("calc", work)


def mtow_text(mtow):
    return f"MTOW {mtow:,.0f} kg".replace(",", ".") if mtow else ""


def plane_key(ac, v, flap="", cg="", mtow=None):
    return f"{ac.name} {v.display}" + "".join(f" · {x}" for x in (flap, cg, mtow_text(mtow)) if x)


def runway_key(rw):
    return f"{rw.icao} {rw.rwy}{' (editada)' if getattr(rw, 'edited', False) else ''}"


# colunas do batch + o flap pedido (flap_sel: "ótimo" ou o flap fixo), o
# limite dianteiro de CG (cg_sel) e o MTOW estrutural (mtow_sel: kg ou "base")
CALC_COLUMNS = COLUMNS[:COLUMNS.index("mtow_kg")] + ["flap_sel", "cg_sel", "mtow_sel"] + \
    COLUMNS[COLUMNS.index("mtow_kg"):]


def save_csv(rows, planes, runways, cases):
    RESULTS_DIR.mkdir(exist_ok=True)
    temps = sorted({t for t, _ in cases})
    winds = sorted({(c.wind, c.crosswind) for _, c in cases})
    qnhs = sorted({c.qnh for _, c in cases})
    slug = f"{temps[0]}C" if len(temps) == 1 else f"{temps[0]}a{temps[-1]}C"
    if len(winds) > 1:
        slug += f"_vento{winds[0][0]:g}a{winds[-1][0]:g}kt"
    elif winds[0] != (0, 0):
        w, x = winds[0]
        slug += (f"_traves{x:+g}kt" if x else
                 f"_{'proa' if w > 0 else 'cauda'}{abs(w):g}kt")
    if len(qnhs) > 1:
        slug += f"_QNH{qnhs[0]:g}a{qnhs[-1]:g}"
    elif qnhs[0] != takeoff.CALM.qnh:
        slug += f"_QNH{qnhs[0]:g}"
    if len(planes) == 1:
        ac, v = planes[0]
        who = f"{ac.name}_{v.display}"
    else:
        who = f"{len(planes)}aeronaves"
    where = (f"{runways[0].icao}_{runways[0].rwy}" if len(runways) == 1 else
             f"{runways[0].icao}_{len(runways)}pistas"
             if len({r.icao for r in runways}) == 1 else f"{len(runways)}pistas")
    name = f"{where}_{who}_{slug}"
    name = re.sub(r"[^\w.+-]+", "_", name.replace("/", "-")).strip("_") + ".csv"
    with open(RESULTS_DIR / name, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, CALC_COLUMNS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    return name


def uploaded_malha(body):
    """Modo servidor: grava a malha enviada pelo navegador numa pasta
    propria e devolve o caminho. Nunca le caminhos da maquina."""
    text = body.get("csv")
    if not isinstance(text, str) or not text.strip():
        raise BadRequest("Escolha o arquivo da malha (.csv)")
    stem = re.sub(r"[^\w.-]+", "_", Path(str(body.get("filename") or
                                            "Malha.csv")).stem)[:60] or "Malha"
    folder = RESULTS_DIR / "malhas" / time.strftime("%Y%m%d-%H%M%S")
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / f"{stem}.csv"
    path.write_text(text, encoding="utf-8")
    return path


def malha_job(body):
    if SERVER_MODE:
        path = uploaded_malha(body)
    else:
        path = Path(str(body.get("path") or schedule.DEFAULT_MALHA)).expanduser()
    if not path.is_file():
        raise BadRequest(f"Arquivo não encontrado: {path}")
    cases = build_cases(body)
    flaps = pick_flaps(body)            # malha: um flap por aeronave
    cgs = pick_cg(body)
    refs = {}
    for name, value in (body.get("refs") or {}).items():
        if value in (None, ""):
            continue
        kg = number(value, f"Peso de referência do {name}")
        if not 1000 <= kg <= 400000:
            raise BadRequest(f"Peso de referência do {name} fora da faixa: {kg:g}")
        refs[str(name)] = kg

    def work(job):
        def progress(n, total, done, jobs):
            job["done"], job["total"] = n - 1 + done / max(jobs, 1), total
            job["label"] = f"Aeroporto {n} de {total}"

        summary = schedule.process(path, cases, None, progress,
                                log=lambda _msg: None, refs=refs,
                                flaps=flaps, cgs=cgs)
        rows = []
        for info in summary:
            cond, wc = info["cond"], info["worst_cond"]
            rows.append({
                "iata": info["iata"], "icao": info["icao"],
                "aircraft": info["aircraft"] or info["eqp"],
                "mtow": info["mtow"], "rwy": info["rwy"], "temp": info["temp"],
                "wind": cond.wind if cond else None,
                "crosswind": cond.crosswind if cond else None,
                "qnh": cond.qnh if cond else None, "flap": info["flap"],
                "limit": info["limit"],
                "limit_text": limit_text(info["limit"]),
                "worst_mtow": info["worst_mtow"], "worst_rwy": info["worst_rwy"],
                "worst_temp": info["worst_temp"],
                "worst_wind": wc.wind if wc else None,
                "worst_crosswind": wc.crosswind if wc else None,
                "worst_qnh": wc.qnh if wc else None,
                "worst_limit_text": limit_text(info["worst_limit"]),
                "ref": info["ref"], "margin": info["margin"],
                "limit_temp": info["limit_temp"], "alert": info["alert"],
                "obs": info["obs"]})
        job["path"] = str(path)
        download = None
        if SERVER_MODE:                 # copia para results/ (download)
            download = f"{path.stem}_calculada_{path.parent.name}.csv"
            shutil.copy2(path, RESULTS_DIR / download)
        return {"path": path.name if SERVER_MODE else str(path),
                "download": download, "rows": rows, "cases": len(cases),
                "temps": sorted({t for t, _ in cases}),
                "winds": sorted({c.wind for _, c in cases}),
                "crosswind": cases[0][1].crosswind,
                "qnhs": sorted({c.qnh for _, c in cases})}

    return start_job("malha", work)


# ---------------------------------------------------------------- pouso (teste)

def pouso_meta():
    """Aeronaves com pouso (Airbus pelo scap_octopus, E195 pela ELM170) e as
    configuracoes de pouso conhecidas."""
    out = []
    for i, ac in enumerate(AIRCRAFT):
        if ac.engine == "octopus":
            fab, confs = "airbus", landing_airbus.CONF_POUSO.get(ac.actype, {})
        elif ac.name in landing_embraer.MODELOS:
            fab, confs = "embraer", landing_embraer.FLAPS_MODELO[ac.name]
        elif ac.engine == "ttam":
            fab, confs = "atr", landing_atr.FLAPS
        else:
            continue
        envelopes = landing_airbus.envelopes(ac.actype) if fab == "airbus" else ()
        out.append({"id": i, "name": ac.name, "fabricante": fab, "mlw_cert": ac.mlw or None,
                    "envelopes": [{"code": c, "label": n} for c, n in envelopes],
                    "grooved": fab != "airbus" or ac.actype in landing_airbus.GROOVED_POUSO,
                    "variants": [{"id": j, "label": v.display} for j, v in enumerate(ac.variants)],
                    "confs": [{"name": n, "pouso": c[0], "arremetida": c[1]} for n, c in confs.items()]})
    return {"aircraft": out}


def pouso_calc(body):
    """Um calculo de pouso (despacho) do Airbus, sincrono."""
    try:
        ac = AIRCRAFT[int(body["aircraft"])]
        v = ac.variants[int(body["variant"])]
    except (KeyError, IndexError, ValueError, TypeError):
        raise BadRequest("Escolha a aeronave e o motor")
    embraer = ac.name in landing_embraer.MODELOS
    atr = ac.engine == "ttam"
    if ac.engine != "octopus" and not embraer and not atr:
        raise BadRequest(f"Pouso ainda não disponível para {ac.name}")
    campos = {  # campo -> (nome, minimo, maximo)
        "lda": ("LDA", 300, 6000), "elev": ("Elevação", -2000, 16000),
        "slope": ("Slope", -5, 5), "temp": ("Temperatura", -60, 60),
        "qnh": ("QNH", 900, 1100), "vento": ("Vento", -30, 60),
        "conf_pouso": ("Código do pouso", 0, 9999),
        "conf_arremetida": ("Código da arremetida", 0, 9999)}
    valores = {}
    for chave, (nome, lo, hi) in campos.items():
        x = number(body.get(chave), nome)
        if not lo <= x <= hi:
            raise BadRequest(f"{nome} fora da faixa ({lo} a {hi}): {x:g}")
        valores[chave] = x
    def opcional(chave, nome, lo, hi):
        if body.get(chave) in (None, ""):
            return None
        x = number(body[chave], nome)
        if not lo <= x <= hi:
            raise BadRequest(f"{nome} fora da faixa ({lo} a {hi}): {x:g}")
        return x
    # superficie: a do cadastro da pista (grooved/PFC so onde existe); sem
    # pista do cadastro, a escolhida na tela
    rw = AIRPORTS.get(str(body.get("icao") or "").upper(), {}).get("runways", {}).get(str(body.get("rwy") or ""))
    grooved = rw.grooved if rw is not None else bool(body.get("grooved"))
    if ac.engine == "octopus" and ac.actype not in landing_airbus.GROOVED_POUSO:
        grooved = False                 # base sem grooved/PFC no pouso
    # MLW: teto de todo pouso = o certificado da aeronave; na tela so da para
    # pedir um valor menor (restricao operacional)
    mlw = opcional("mlw", "MLW", 10000, 400000)
    lw = opcional("lw", "Peso de pouso (LW)", 10000, 400000)
    cert = ac.mlw or None
    if cert and mlw and mlw > cert:
        raise BadRequest(f"MLW {mlw:,.0f} kg acima do certificado do {ac.name} ({cert:,.0f} kg)".replace(",", "."))
    if cert and lw and lw > cert:
        raise BadRequest(f"Peso de pouso {lw:,.0f} kg acima do MLW certificado do {ac.name} ({cert:,.0f} kg)".replace(",", "."))
    mlw = mlw or cert
    ga = opcional("ga_grad", "Gradiente de arremetida", 0.1, 20)
    opcoes = {"reverso": (0, 1), "ar": (1, 2),
              "antigelo": (0, 6) if atr else (0, 3) if embraer else (0, 1, 3)}
    for chave, validos in opcoes.items():
        x = int(number(body.get(chave, validos[0]), chave))
        if x not in validos:
            raise BadRequest(f"Valor inválido para {chave}: {x}")
        valores[chave] = x
    if atr:
        rating = v.rating.upper()
        p = landing_atr.PousoATR(
            lda=valores["lda"], elev=valores["elev"], slope=valores["slope"],
            temp=valores["temp"], qnh=valores["qnh"], vento=valores["vento"],
            molhada=bool(body.get("molhada")),
            flap_pouso=int(valores["conf_pouso"]), flap_arremetida=int(valores["conf_arremetida"]),
            reverso=valores["reverso"], icing=valores["antigelo"] == 6,
            boost=2 if "BOOSTON" in rating else 1 if "BOOSTOFF" in rating else 0,
            motor=v.engtyp.replace("_M", ""), mlw=mlw, ga_grad=ga)
        try:
            r = landing_atr.calcular(p)
            no_lw = landing_atr.calcular(dataclasses.replace(p, mlw=lw)) if lw else None
        except (landing_atr.PousoError, takeoff.ScapError) as e:
            raise BadRequest(str(e))
    elif embraer:
        autobrake = int(number(body.get("autobrake", 0), "Autobrake"))
        inc = number(body.get("vref_inc") or 0, "Incremento na VREF")
        if autobrake not in (0, 1, 2, 3) or not 0 <= inc <= 20:
            raise BadRequest("Autobrake ou incremento na VREF inválido")
        p = landing_embraer.PousoE(
            lda=valores["lda"], elev=valores["elev"], slope=valores["slope"],
            temp=valores["temp"], qnh=valores["qnh"], vento=valores["vento"],
            molhada=bool(body.get("molhada")), grooved=grooved,
            flap_pouso=int(valores["conf_pouso"]), flap_arremetida=int(valores["conf_arremetida"]),
            reverso=valores["reverso"], antigelo=valores["antigelo"], autobrake=autobrake,
            vref_inc=inc, mlw=mlw, ga_grad=ga)
        try:
            r = landing_embraer.calcular(ac.name, p)
            # no LW: o E2 tem o modo "distancias no peso" (POPTL(1)=1); o E1
            # sempre calcula os limites, entao o LW entra como peso maximo
            e2 = landing_embraer.MODELOS[ac.name]["tipo"] == "e2"
            no_lw = landing_embraer.calcular(ac.name, dataclasses.replace(p, **({"peso": lw} if e2 else {"mlw": lw}))) if lw else None
        except (landing_embraer.PousoError, takeoff.ScapError) as e:
            raise BadRequest(str(e))
    else:
        cg = int(number(body.get("cg") or 0, "Envelope de CG"))
        if cg not in dict(landing_airbus.envelopes(ac.actype)):
            raise BadRequest(f"Envelope de CG inválido para {ac.name}: {cg}")
        p = landing_airbus.Pouso(**valores, molhada=bool(body.get("molhada")), mlw=mlw,
                               athr=body.get("athr", False) not in (False, 0, "0", "off", None),
                               grooved=grooved, ga_grad=ga, cg=cg)
        try:
            r = landing_airbus.calcular(v, p)
            no_lw = landing_airbus.calcular(v, dataclasses.replace(p, peso=lw)) if lw else None
        except (landing_airbus.PousoError, takeoff.ScapError) as e:
            raise BadRequest(str(e))
    if no_lw:
        no_lw = {k: no_lw[k] for k in ("gradiente_arremetida", "gradiente_pouso", "vapp",
                                       "v_arremetida", "ld", "ld_exigida", "erflag", "mensagens")}
    if cert and mlw == cert and r.get("mlw") is not None and abs(r["mlw"] - cert) < 0.5:
        r["limitante"] = "Peso máximo de pouso certificado (MLW)"
    return {**r, "lw": lw, "no_lw": no_lw, "aircraft": ac.name, "engine": v.display,
            "grooved": grooved, "mlw_usado": mlw, "mlw_cert": cert}


# ---------------------------------------------------------------- pista bloqueada

BLOQUEIO_COLUMNS = ["aircraft", "engine", "icao", "rwy", "position_m", "distance_m", "available_m",
                    "temp_c", "wind_kt", "crosswind_kt", "qnh_hpa", "air_cond", "tora_m", "asda_m", "toda_m",
                    "lda_m", "n_obst", "mtow_kg", "flap", "to_limit", "to_error",
                    "mlw_kg", "ld_limit", "ld_error"]


def bloqueio_job(body):
    """Varre a posicao de um bloqueio na pista (De/Ate/Passo, m a partir da
    primeira cabeceira) e calcula MTOW e peso de pouso das duas cabeceiras
    usando so o trecho antes do bloqueio (perf.blocked)."""
    planes = pick_aircraft(body)
    if not planes:
        raise BadRequest("Marque pelo menos uma aeronave")
    icao = str(body.get("icao") or "").upper()
    if icao not in AIRPORTS:
        raise BadRequest(f"Aeroporto {icao or '?'} não está no airports_list.csv")
    runways = AIRPORTS[icao]["runways"]
    vals = {k: number(body.get(k), nome) for k, nome in (
        ("de", "De"), ("ate", "Até"), ("passo", "Passo"), ("margem", "Margem"),
        ("altura", "Altura do bloqueio"))}
    if vals["margem"] < 0 or not 0 <= vals["altura"] <= 300:
        raise BadRequest("Margem não pode ser negativa e a altura vai de 0 a 300 ft")
    cases = build_cases(body)
    try:
        phys = blocked.physical_runway(runways, str(body.get("rwy") or ""))
        pos = blocked.positions(vals["de"], vals["ate"], vals["passo"])
    except blocked.BlockedError as e:
        raise BadRequest(str(e))
    total = len(planes) * len(phys["ends"]) * len(pos) * len(cases) * 2
    if total > MAX_TOTAL * 2:
        raise BadRequest(f"São {total} cálculos (decolagem + pouso); o limite é {MAX_TOTAL * 2}. "
                         "Aumente o passo ou diminua as faixas.")
    for ac, v in planes:
        try:
            takeoff.check(ac, v)
        except takeoff.ScapError as e:
            raise BadRequest(f"{ac.name} {v.display}: {e}")
    wet = bool(body.get("molhada"))

    def work(job):
        def progress(done, total):
            job["done"], job["total"] = done, total

        try:
            out = blocked.run(planes, runways, body.get("rwy"), vals["de"], vals["ate"],
                              vals["passo"], vals["margem"], vals["altura"], cases, TOALIGN,
                              wet=wet, on_progress=progress)
        except blocked.BlockedError as e:
            raise BadRequest(str(e))
        for row in out["rows"]:
            if row.get("to_limit") is not None:
                row["to_limit_text"] = limit_text(row["to_limit"])
        RESULTS_DIR.mkdir(exist_ok=True)
        name = (f"bloqueio_{icao}_{out['phys']['a']}-{out['phys']['b']}_"
                f"{vals['de']:g}a{vals['ate']:g}m_passo{vals['passo']:g}_{time.strftime('%Y%m%d-%H%M%S')}.csv")
        with open(RESULTS_DIR / name, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, BLOQUEIO_COLUMNS)
            w.writeheader()
            for r in out["rows"]:
                w.writerow({"aircraft": r["aircraft"], "engine": r["engine"], "icao": icao,
                            "rwy": r["end"], "position_m": r["position"], "distance_m": r["distance"],
                            "available_m": r["available"], "temp_c": r["temp"], "wind_kt": r["wind"],
                            "crosswind_kt": r["crosswind"], "qnh_hpa": r["qnh"],
                            "air_cond": "ON" if cases[0][1].aircond else "OFF",
                            "tora_m": r.get("tora"), "asda_m": r.get("asda"), "toda_m": r.get("toda"),
                            "lda_m": r.get("lda"), "n_obst": r.get("n_obst"),
                            "mtow_kg": r.get("mtow"), "flap": r.get("flap"),
                            "to_limit": r.get("to_limit_text"), "to_error": r.get("to_error") or r.get("error"),
                            "mlw_kg": round(r["mlw"]) if r.get("mlw") is not None else None,
                            "ld_limit": r.get("ld_limit"), "ld_error": r.get("ld_error") or r.get("error")})
        return {**out, "icao": icao, "airport": AIRPORTS[icao]["name"].title(), "csv": name,
                "margem": vals["margem"], "altura": vals["altura"], "molhada": wet,
                "ar": cases[0][1].aircond}

    return start_job("bloqueio", work)


def open_local(path):
    if platform.system() == "Windows":
        os.startfile(path)
    else:
        opener = "open" if platform.system() == "Darwin" else "xdg-open"
        subprocess.Popen([opener, str(path)], stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL)


# ---------------------------------------------------------------- HTTP

class Handler(BaseHTTPRequestHandler):
    server_version = "PerformanceDecolagem"

    def log_message(self, fmt, *args):            # silencioso
        pass

    def end_headers(self):
        origin = (self.headers.get("Origin") or "").rstrip("/")
        if origin and (origin in CORS_ORIGINS or "*" in CORS_ORIGINS):
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
            self.send_header("Access-Control-Allow-Headers",
                             "Content-Type, X-Perf-Key")
            self.send_header("Access-Control-Allow-Methods",
                             "GET, POST, OPTIONS")
        super().end_headers()

    def do_OPTIONS(self):                          # preflight do CORS
        self.send_response(204)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def authorized(self):
        """Com PERF_PASSWORD, a API e os downloads pedem a senha (cabecalho
        X-Perf-Key ou ?key= nos links de download)."""
        if not PASSWORD:
            return True
        key = self.headers.get("X-Perf-Key") or \
            (parse_qs(urlparse(self.path).query).get("key") or [""])[0]
        return hmac.compare_digest(key.encode(), PASSWORD.encode())

    def deny(self):
        self.send_json({"error": "Senha incorreta ou ausente", "auth": True},
                       401)

    def send_json(self, data, status=200):
        raw = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def send_file(self, path, download=False):
        if not path.is_file():
            return self.send_json({"error": "Arquivo não encontrado"}, 404)
        data = path.read_bytes()
        ctype = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        if ctype.startswith("text/") or ctype.endswith("javascript"):
            ctype += "; charset=utf-8"
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        if download:
            self.send_header("Content-Disposition",
                             f'attachment; filename="{path.name}"')
        self.end_headers()
        self.wfile.write(data)

    def body(self):
        size = int(self.headers.get("Content-Length") or 0)
        if size > MAX_BODY:
            raise BadRequest("Arquivo grande demais")
        try:
            return json.loads(self.rfile.read(size) or b"{}")
        except json.JSONDecodeError:
            raise BadRequest("JSON inválido")

    @staticmethod
    def inside(base, name):
        path = (base / name).resolve()
        return path if base.resolve() in path.parents else None

    def do_GET(self):
        url = urlparse(self.path)
        parts = [unquote(p) for p in url.path.split("/") if p]
        try:
            if not parts:
                return self.send_file(WEB_DIR / "index.html")
            if parts[0] in ("api", "files") and not self.authorized():
                return self.deny()
            if parts[0] == "api":
                if parts[1:] == ["meta"]:
                    return self.send_json(meta())
                if parts[1:] == ["pouso", "meta"]:
                    return self.send_json(pouso_meta())
                if len(parts) == 3 and parts[1] == "airport":
                    return self.send_json(airport(parts[2]))
                if len(parts) == 3 and parts[1] == "job":
                    job = JOBS.get(parts[2])
                    if not job:
                        return self.send_json({"error": "Job não encontrado"}, 404)
                    return self.send_json(job)
                return self.send_json({"error": "Rota desconhecida"}, 404)
            if parts[0] == "files" and len(parts) == 2:
                path = self.inside(RESULTS_DIR, parts[1])
                return self.send_file(path, download=True) if path else \
                    self.send_json({"error": "Arquivo inválido"}, 400)
            base = ASSETS_DIR if parts[0] == "assets" else WEB_DIR
            rel = "/".join(parts[1:] if parts[0] == "assets" else parts)
            path = self.inside(base, rel)
            return self.send_file(path) if path else \
                self.send_json({"error": "Arquivo inválido"}, 400)
        except BadRequest as e:
            self.send_json({"error": str(e)}, 400)

    def do_POST(self):
        parts = [p for p in urlparse(self.path).path.split("/") if p]
        try:
            if not self.authorized():
                return self.deny()
            body = self.body()
            if parts == ["api", "calc"]:
                return self.send_json(calc_job(body))
            if parts == ["api", "malha"]:
                return self.send_json(malha_job(body))
            if parts == ["api", "pouso"]:
                return self.send_json(pouso_calc(body))
            if parts == ["api", "bloqueio"]:
                return self.send_json(bloqueio_job(body))
            if parts == ["api", "open"]:
                if SERVER_MODE:
                    raise BadRequest("No servidor, use o botão de download")
                job = JOBS.get(str(body.get("job", "")))
                if not job or "path" not in job:
                    raise BadRequest("Nada para abrir")
                open_local(job["path"])
                return self.send_json({"ok": True})
            return self.send_json({"error": "Rota desconhecida"}, 404)
        except BadRequest as e:
            self.send_json({"error": str(e)}, 400)
        except takeoff.ScapError as e:
            self.send_json({"error": str(e)}, 400)


def main():
    p = argparse.ArgumentParser(description="Performance de Decolagem (web local)")
    p.add_argument("--port", type=int,
                   default=int(os.environ.get("PERF_PORT", 8765)))
    p.add_argument("--host", default=os.environ.get("PERF_HOST", "127.0.0.1"),
                   help="0.0.0.0 para aceitar conexoes de fora (servidor)")
    p.add_argument("--no-browser", action="store_true",
                   help="nao abre o navegador automaticamente")
    args = p.parse_args()
    local = args.host in ("127.0.0.1", "localhost")
    if not local and not PASSWORD:
        print("ATENCAO: aberto para a rede sem senha (defina PERF_PASSWORD)")
    ports = range(args.port, args.port + 20) if local else [args.port]
    for port in ports:
        try:
            server = ThreadingHTTPServer((args.host, port), Handler)
            break
        except OSError:
            continue
    else:
        raise SystemExit(f"Nenhuma porta livre entre {ports[0]} e {ports[-1]}")
    url = f"http://{'127.0.0.1' if local else args.host}:{server.server_port}/"
    print(f"Performance de Decolagem em {url}  (Ctrl+C para sair)", flush=True)
    if SERVER_MODE:
        print("Modo servidor: malha por upload/download", flush=True)
    if local and not args.no_browser:
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nEncerrado.")


if __name__ == "__main__":
    main()

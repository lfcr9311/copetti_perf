"""Pista bloqueada: varre a posicao de um bloqueio (buraco, aeronave parada)
ao longo da pista e calcula, para as duas cabeceiras, o MTOW e o peso maximo
de pouso usando so o trecho antes do bloqueio.

Geometria igual a reducao de pista da tela de decolagem: a pista fisica vai
da cabeceira a (x = 0) a cabeceira b (x = L, L = maior TORA entre os
sentidos), cada TORA comeca na ponta do pavimento (sem cabeceira deslocada).
Bloqueio em x = p (metros a partir da cabeceira a):

  cabeceira a: distancia ate o bloqueio d = p;  cabeceira b: d = L - p
  disponivel = d - margem
  decolagem: TORA = min(TORA, disponivel); ASDA e TODA nao passam da nova
             TORA; obstaculos do cadastro se afastam do fim da TORA pelo
             trecho cortado; o bloqueio entra como obstaculo (altura > 0)
             a (d - nova TORA) do fim da TORA
  pouso:     LDA = min(TORA, disponivel) (o cadastro nao tem LDA)
"""

import dataclasses
import re
import threading
from concurrent.futures import ThreadPoolExecutor

from .catalog.airports import MAX_OBSTACLES, align_values
from .landing.dispatch import max_landing
from .takeoff import engine as takeoff

RWY_RE = re.compile(r"^(\d{2})([LRC]?)(?:/(.+))?$")
MIN_AVAILABLE = 300.0      # m: abaixo disso a posicao nao e calculada


class BlockedError(Exception):
    pass


def opposite_end(base):
    m = re.fullmatch(r"(\d{2})([LRC]?)", base)
    return f"{(int(m.group(1)) + 17) % 36 + 1:02d}" + {"L": "R", "R": "L"}.get(m.group(2), m.group(2))


def physical_runway(runways, rwy):
    """{'a', 'b', 'L', 'ends': {cabeceira: Runway}} da pista fisica de rwy
    (so as cabeceiras principais; intersecoes ficam de fora)."""
    m = RWY_RE.match(rwy)
    if not m:
        raise BlockedError(f"Pista {rwy}: nome fora do padrão (ex. 15, 09L)")
    a, b = sorted([m.group(1) + m.group(2), opposite_end(m.group(1) + m.group(2))])
    members = [r for name, r in runways.items()
               if (k := RWY_RE.match(name)) and k.group(1) + k.group(2) in (a, b)]
    ends = {e: runways[e] for e in (a, b) if e in runways}
    if not ends:
        raise BlockedError(f"Pista {rwy}: cabeceiras {a}/{b} não estão no cadastro")
    return {"a": a, "b": b, "L": max(r.tora for r in members), "ends": ends}


def positions(start, stop, step):
    if step <= 0:
        raise BlockedError("O passo precisa ser maior que zero")
    if stop < start:
        raise BlockedError("'Até' precisa ser maior ou igual a 'De'")
    count = int((stop - start) // step) + 1
    if count > 200:
        raise BlockedError(f"São {count} posições; o limite é 200 (aumente o passo)")
    return [start + i * step for i in range(count)]


def blocked_runway(phys, end, p, margin, height):
    """Pista do cadastro da cabeceira 'end' reduzida pelo bloqueio em x = p.
    Devolve (Runway reduzida, distancia ate o bloqueio, disponivel) ou
    (None, d, disponivel) se sobra menos que MIN_AVAILABLE."""
    rw = phys["ends"][end]
    d = p if end == phys["a"] else phys["L"] - p
    available = d - margin
    if available < MIN_AVAILABLE:
        return None, d, available
    tora = min(rw.tora, available)
    cut = rw.tora - tora
    obstacles = [(dist + cut, h) for dist, h in rw.obstacles]
    if height > 0:
        obstacles.append((d - tora, height))
    obstacles = sorted(obstacles)[:MAX_OBSTACLES]
    reduced = dataclasses.replace(
        rw, tora=tora, asda=min(rw.asda, tora) if cut > 0 else rw.asda,
        toda=min(rw.toda, tora) if cut > 0 else rw.toda, obstacles=obstacles)
    return reduced, d, available


def run(planes, runways, rwy, start, stop, step, margin, height, cases,
        toalign, wet=False, on_progress=None):
    """Varredura completa. planes: [(aircraft, variant)]; cases: [(temp,
    Conditions)]. Devolve {'phys', 'rows'}; cada linha: cabeceira, posicao
    (m a partir da cabeceira a), distancia ate o bloqueio, TORA/ASDA/TODA/LDA
    usadas, aeronave, condicoes, MTOW/limitante e peso de pouso/limitante."""
    phys = physical_runway(runways, rwy)
    pos = positions(start, stop, step)
    if pos[-1] > phys["L"] or pos[0] < 0:
        raise BlockedError(f"As posições vão de 0 a {phys['L']:g} m (comprimento da pista)")
    for ac, v in planes:
        takeoff.check(ac, v)

    rows, to_tasks, to_rows, ld_tasks = [], [], [], []
    for ac, v in planes:
        for end in phys["ends"]:
            for p in pos:
                reduced, d, available = blocked_runway(phys, end, p, margin, height)
                for t, cond in cases:
                    row = {"aircraft": ac.name, "engine": v.display, "end": end, "position": p,
                           "distance": d, "available": available, "temp": t, "wind": cond.wind,
                           "crosswind": cond.crosswind, "qnh": cond.qnh}
                    rows.append(row)
                    if reduced is None:
                        row["error"] = f"sobram {max(available, 0):.0f} m (mínimo {MIN_AVAILABLE:.0f} m)"
                        continue
                    row.update(tora=reduced.tora, asda=reduced.asda, toda=reduced.toda,
                               lda=reduced.tora, n_obst=len(reduced.obstacles))
                    to_tasks.append((ac, v, reduced, t, cond, align_values(reduced, ac.align, toalign)))
                    to_rows.append(row)
                    ld_tasks.append((ac, v, reduced, t, cond, row))

    total = len(to_tasks) + len(ld_tasks)
    done = {"to": 0, "ld": 0}
    lock = threading.Lock()

    def progress():
        if on_progress:
            on_progress(done["to"] + done["ld"], total)

    def to_progress(n, _total):
        with lock:
            done["to"] = n
        progress()

    results = takeoff.compute_tasks(to_tasks, on_progress=to_progress) if to_tasks else []
    for row, res in zip(to_rows, results):
        if "error" in res:
            row["to_error"] = " | ".join(res["error"].splitlines())
        else:
            row.update(mtow=res["mtow"], flap=res["flap"], to_limit=res["limit_code"])

    def landing(task):
        ac, v, rw, t, cond, row = task
        with takeoff.work_slot() as slot:
            r = max_landing(ac, v, rw, rw.tora, t, cond.qnh, cond.wind, wet, slot=f"b{slot}")
        row.update(mlw=r["mlw"], ld_limit=r["limitante"], ld_error=r["erro"])
        with lock:
            done["ld"] += 1
        progress()

    with ThreadPoolExecutor(takeoff.default_workers()) as pool:
        list(pool.map(landing, ld_tasks))
    return {"phys": {"a": phys["a"], "b": phys["b"], "L": phys["L"],
                     "ends": {e: {"tora": r.tora, "asda": r.asda, "toda": r.toda}
                              for e, r in phys["ends"].items()}},
            "positions": pos, "rows": rows}

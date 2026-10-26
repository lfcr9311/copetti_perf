#!/usr/bin/env python3
"""Calculo em massa: aeronaves x aeroportos/pistas (com obstaculos) x temperaturas.

Cada linha do CSV de saida e um calculo (aeronave, motor, pista, temperatura).
O arquivo e gravado linha a linha: se o processo parar, rodar de novo com o
mesmo --out continua de onde parou (pula o que ja foi calculado).

Exemplos:
    python -m perf.batch                                   # tudo, -10 a 45 C
    python -m perf.batch --aircraft A320 --airports SBKP,SBGR
    python -m perf.batch --aircraft A320 --engine 1A26NORMAL --airports SBKP --runways 15
    python -m perf.batch --aircraft A330neo --engine TRENT7000-STEP3 --tmin 0 --tmax 40 --step 5
    python -m perf.batch --dry-run                         # so monta os scap.in e conta
"""

import argparse
import csv
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from .catalog.aircraft import AIRCRAFT
from .catalog.airports import align_values, load_airports, load_toalign
from .paths import RESULTS_DIR
from .takeoff import atr as takeoff_atr
from .takeoff import embraer as takeoff_embraer
from .takeoff import engine as takeoff

COLUMNS = ["aircraft", "engine", "icao", "airport", "rwy", "to_align",
           "n_obst", "temp_c", "wind_kt", "crosswind_kt", "qnh_hpa",
           "mtow_kg", "flap", "limit_code",
           "v1_min_kt", "v1_max_kt", "vr_kt", "v2_kt", "error"]


def condition_columns(cond):
    """wind_kt: + proa / - cauda; crosswind_kt: + da direita (so Airbus)."""
    return {"wind_kt": f"{cond.wind:g}", "crosswind_kt": f"{cond.crosswind:g}",
            "qnh_hpa": f"{cond.qnh:g}"}


def result_row(res):
    """Colunas de resultado do CSV a partir do dict de takeoff.compute."""
    return {"mtow_kg": res["mtow"], "flap": res["flap"],
            "limit_code": res["limit_code"], "v1_min_kt": res["v1_min"],
            "v1_max_kt": res["v1_max"], "vr_kt": res["vr"], "v2_kt": res["v2"],
            "error": ""}


def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--aircraft", help="nomes separados por virgula (ex.: A320,A330neo). "
                                      "Padrao: todas")
    p.add_argument("--engine", help="motores separados por virgula (ex.: 1A26NORMAL)")
    p.add_argument("--airports", help="ICAO separados por virgula. Padrao: todos")
    p.add_argument("--runways", help="cabeceiras separadas por virgula, como no "
                                     "airports_list.csv (ex.: 15,33/B). Padrao: todas")
    p.add_argument("--tmin", type=float, default=-10)
    p.add_argument("--tmax", type=float, default=45)
    p.add_argument("--step", type=float, default=1)
    p.add_argument("--wind", default="0",
                   help="vento ao longo da pista em kt (+ proa, - cauda): valor, "
                        "lista (-5,0,5) ou faixa inicio:fim:passo (-10:20:5). Padrao 0")
    p.add_argument("--crosswind", type=float, default=0,
                   help="vento de traves em kt, + da direita (so Airbus; padrao 0)")
    p.add_argument("--qnh", default="1013.25",
                   help="QNH em hPa: valor, lista ou faixa (990:1030:10). Padrao 1013.25")
    p.add_argument("--workers", type=int, default=takeoff.default_workers())
    p.add_argument("--out", default=str(RESULTS_DIR / "performance_em_massa.csv"))
    p.add_argument("--retry-errors", action="store_true",
                   help="recalcula as linhas que deram erro no --out existente")
    p.add_argument("--dry-run", action="store_true",
                   help="so monta os scap.in (sem rodar o motor) e mostra a contagem")
    return p.parse_args()


def split(text):
    return {s.strip().upper() for s in text.split(",") if s.strip()} if text else None


def temperatures(tmin, tmax, step):
    if step <= 0:
        raise ValueError("O passo de temperatura tem que ser maior que zero")
    temps, t = [], tmin
    while t <= tmax + 1e-9:
        temps.append(int(t) if float(t).is_integer() else round(t, 2))
        t += step
    return temps


def parse_values(text, name="valor"):
    """'10' -> [10]; '-5,0,5' -> lista; '-10:20:5' -> faixa (inicio:fim:passo)."""
    text = str(text).replace(" ", "")
    try:
        if ":" in text:
            lo, hi, step = (float(v) for v in text.split(":"))
            values = temperatures(lo, hi, step)
        else:
            values = [float(v) for v in text.split(",") if v]
    except ValueError:
        raise ValueError(f"{name}: use um valor (10), uma lista (-5,0,5) ou "
                         f"uma faixa inicio:fim:passo (-10:20:5), nao '{text}'")
    if not values:
        raise ValueError(f"{name}: nenhum valor em '{text}'")
    return values


def build_cases(temps, winds=(0.0,), qnhs=(1013.25,), crosswind=0.0):
    """Combinacoes (temperatura, Conditions) na ordem temperatura > vento > QNH."""
    return [(t, takeoff.Conditions(float(w), float(crosswind), float(q)))
            for t in temps for w in winds for q in qnhs]


def select_variants(args):
    names, engines = split(args.aircraft), split(args.engine)
    chosen = []
    for ac in AIRCRAFT:
        if names and ac.name.upper() not in names:
            continue
        if not ac.supported:
            if names:
                print(f"AVISO: {ac.name} ainda nao e suportado pelo motor ({ac.engine}); pulando")
            continue
        for v in ac.variants:
            if engines and not engines & {v.engtyp.upper(), v.display.upper()}:
                continue
            try:
                takeoff.check(ac, v)
            except takeoff.ScapError as e:
                print(f"AVISO: pulando {ac.name} {v.display}: {e}")
                continue
            chosen.append((ac, v))
    return chosen


def select_runways(args):
    wanted, rwys = split(args.airports), split(args.runways)
    airports = load_airports()
    if wanted:
        missing = wanted - set(airports)
        if missing:
            print("AVISO: aeroportos fora do airports_list.csv: " + ", ".join(sorted(missing)))
    runways = []
    for icao in sorted(airports):
        if wanted and icao not in wanted:
            continue
        runways.extend(r for r in airports[icao]["runways"].values()
                       if not rwys or r.rwy.upper() in rwys)
    if rwys and not runways:
        print("AVISO: nenhuma pista encontrada. Cabeceiras de "
              + ", ".join(f"{i}: {' '.join(airports[i]['runways'])}"
                          for i in sorted(wanted or ()) if i in airports))
    return runways


def key(ac_name, engine, icao, rwy, temp, conds):
    return (ac_name, engine, icao, rwy, f"{float(temp):g}", conds["wind_kt"],
            conds["crosswind_kt"], conds["qnh_hpa"])


def load_done(out, retry_errors):
    """Chaves ja calculadas. Com --retry-errors reescreve o CSV sem os erros."""
    if not out.exists():
        return set()
    with open(out, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    if reader.fieldnames != COLUMNS:
        sys.exit(f"{out} tem outras colunas (versao antiga do batch). "
                 f"Use outro --out.")
    if retry_errors:
        rows = [r for r in rows if not r["error"]]
        with open(out, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, COLUMNS)
            w.writeheader()
            w.writerows(rows)
    return {key(r["aircraft"], r["engine"], r["icao"], r["rwy"], r["temp_c"], r)
            for r in rows}


def main():
    args = parse_args()
    variants = select_variants(args)
    runways = select_runways(args)
    try:
        temps = temperatures(args.tmin, args.tmax, args.step)
        winds = parse_values(args.wind, "--wind")
        qnhs = parse_values(args.qnh, "--qnh")
    except ValueError as e:
        sys.exit(str(e))
    toalign = load_toalign()
    cases = build_cases(temps, winds, qnhs, args.crosswind)
    if not variants or not runways or not temps:
        sys.exit("Nada a calcular (confira --aircraft/--engine/--airports/--tmin/--tmax).")

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    done = set() if args.dry_run else load_done(out, args.retry_errors)

    jobs = []
    for ac, v in variants:
        for rw in runways:
            for t, cond in cases:
                if key(ac.name, v.display, rw.icao, rw.rwy, t,
                       condition_columns(cond)) not in done:
                    jobs.append((ac, v, rw, t, cond))
    total_all = len(variants) * len(runways) * len(cases)
    print(f"{len(variants)} motor(es) x {len(runways)} pista(s) x {len(cases)} combinacao(oes) "
          f"[{len(temps)} temperatura(s) {temps[0]} a {temps[-1]} C x {len(winds)} vento(s) "
          f"x {len(qnhs)} QNH] = {total_all} calculos; "
          f"{total_all - len(jobs)} ja feitos, {len(jobs)} a fazer.")

    if args.dry_run:
        errors = 0
        for ac, v, rw, t, cond in jobs:
            try:
                align = align_values(rw, ac.align, toalign)
                if ac.engine == "octopus":
                    takeoff.build_input(
                        takeoff.find_example(v).read_text(errors="replace"),
                        ac, v, rw, t, align, cond)
                elif ac.engine == "ttam":
                    takeoff_atr.build_inputs(v, rw, t, align, cond.wind, cond.qnh)
                else:
                    takeoff_embraer.data_file(ac, v, rw, t, align, cond.wind, cond.qnh)
            except (takeoff.ScapError, ValueError) as e:
                errors += 1
                if errors <= 10:
                    print(f"  {ac.name} {v.display} {rw.icao} {rw.rwy} {t}: {e}")
        print(f"dry-run: {len(jobs) - errors} entradas montadas, {errors} com erro.")
        return
    if not jobs:
        print(f"Tudo ja calculado em {out}")
        return

    lock = threading.Lock()
    new_file = not out.exists()
    f = open(out, "a", newline="", encoding="utf-8")
    writer = csv.DictWriter(f, COLUMNS)
    if new_file:
        writer.writeheader()
    counter = {"done": 0, "errors": 0}
    start = time.time()

    def one(job):
        ac, v, rw, t, cond = job
        row = {"aircraft": ac.name, "engine": v.display, "icao": rw.icao,
               "airport": rw.name, "rwy": rw.rwy, "to_align": rw.to_align,
               "n_obst": len(rw.obstacles), "temp_c": t,
               **condition_columns(cond)}
        try:
            with takeoff.work_slot() as slot:
                res = takeoff.compute(ac, v, rw, t, slot,
                                      align_values(rw, ac.align, toalign),
                                      cond=cond)
            row.update(result_row(res))
        except (takeoff.ScapError, ValueError) as e:
            row["error"] = " | ".join(str(e).split("\n"))
        with lock:
            writer.writerow(row)
            f.flush()
            counter["done"] += 1
            counter["errors"] += bool(row["error"])
            n = counter["done"]
            if n == 1 or n % 25 == 0 or n == len(jobs):
                rate = n / (time.time() - start)
                eta = (len(jobs) - n) / rate if rate else 0
                print(f"  {n}/{len(jobs)}  erros={counter['errors']}  "
                      f"{rate:.2f}/s  faltam ~{eta / 60:.0f} min", flush=True)

    pool = ThreadPoolExecutor(args.workers)
    try:
        list(pool.map(one, jobs))
    except KeyboardInterrupt:
        print("\nInterrompido. Rode o mesmo comando de novo para continuar.")
        pool.shutdown(wait=True, cancel_futures=True)
    finally:
        pool.shutdown(wait=True)
        f.close()
    print(f"Fim: {counter['done']} calculados, {counter['errors']} com erro -> {out}")


if __name__ == "__main__":
    main()

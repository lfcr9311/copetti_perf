#!/usr/bin/env python3
"""Malha: maior MTOW de decolagem para cada voo de uma malha (Malha.csv).

Para cada linha da malha pega o aeroporto de partida (coluna C, IATA) e o
equipamento (coluna Eqp), calcula a performance em todas as pistas do
aeroporto (airports_list.csv) para as temperaturas pedidas e grava na
propria Malha.csv o maior MTOW, com a pista, a temperatura, o flap e o
limitante que deram esse valor. Antes de gravar, guarda uma copia em
Malha.csv.bak.

O calculo e feito uma vez por par (aeroporto, aeronave): as linhas repetidas
reaproveitam o resultado. O MTOW nunca passa do peso estrutural (POPT 24),
entao, quando alguma pista chega nele, as temperaturas mais quentes daquele
aeroporto sao dispensadas (o maximo ja foi achado). Empate no MTOW: fica a
pista com maior TORA.

Alerta: alem do melhor caso, acha o pior caso das condicoes pedidas (a
combinacao em que a melhor pista da o menor MTOW) e compara com um peso de
referencia por aeronave (padrao: o estrutural). OK = o pior caso ja atende;
ATENCAO = atende so em parte das condicoes (com a temperatura limite);
RESTRITO = nem o melhor caso atende. Margem = pior caso - referencia.

Uso:
    python malha.py                      # ../Malha.csv, -10 a 45 C
    python malha.py caminho/Malha.csv --tmin 0 --tmax 40 --step 5
"""

import argparse
import dataclasses
import csv
import shutil
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from queue import Queue

import scap_engine
from aircraft import AIRCRAFT
from airports import align_values, load_airports, load_toalign

HERE = Path(__file__).resolve().parent
DEFAULT_MALHA = HERE.parent / "Malha.csv"
IATA_CSV = HERE / "iata_icao.csv"

DEP_COLUMN = 2                       # coluna C
# Codigo do equipamento na malha -> (aeronave, motor). Motor None = o primeiro
# da lista em aircraft.py. Edite aqui para novos codigos.
EQP_AIRCRAFT = {
    # codigos IATA (SSIM)
    "295": ("E195-E2", None),
    "E95": ("E195", None), "195": ("E195", None),
    "AT7": ("ATR 72-600", None), "AT76": ("ATR 72-600", None),
    "ATR": ("ATR 72-600", None),
    "320": ("A320", None), "32N": ("A320", None),
    "321": ("A321neo", None), "32Q": ("A321neo", None),
    "332": ("A330", None), "330": ("A330", None),
    "339": ("A330neo", None),
    # designadores ICAO (e variantes usadas na malha, como A32N)
    "E295": ("E195-E2", None), "E195": ("E195", None),
    "AT75": ("ATR 72-600", None), "AT72": ("ATR 72-600", None),
    "A320": ("A320", None), "A20N": ("A320", None), "A32N": ("A320", None),
    "A321": ("A321neo", None), "A21N": ("A321neo", None),
    "A332": ("A330", None), "A339": ("A330neo", None),
}
NEW_COLUMNS = ["MTOW Max (kg)", "Pista", "Temp (C)", "Flap", "Limitante",
               "Vento", "QNH (hPa)",
               # alerta: pior caso das condicoes x peso de referencia
               "MTOW Pior Caso (kg)", "Pior Caso", "Peso Ref (kg)",
               "Margem (kg)", "Temp Limite (C)", "Alerta", "Obs"]
ALERT_TEXT = {"OK": "OK", "ATENCAO": "ATENCAO", "RESTRITO": "RESTRITO"}


class MalhaError(Exception):
    pass


def load_iata(path=IATA_CSV):
    with open(path, encoding="utf-8", newline="") as f:
        return {r["IATA"].strip().upper(): r["ICAO"].strip().upper()
                for r in csv.DictReader(f)}


def resolve_aircraft(eqp):
    entry = EQP_AIRCRAFT.get(eqp.strip().upper())
    if entry is None:
        raise MalhaError(f"Equipamento '{eqp}' sem aeronave em EQP_AIRCRAFT")
    name, engine = entry
    aircraft = next(a for a in AIRCRAFT if a.name == name)
    variants = [v for v in aircraft.variants
                if engine is None or v.display == engine]
    return aircraft, variants[0]


# ------------------------------------------------------------- arquivo

def read_malha(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        rows = list(csv.reader(f))
    for i, row in enumerate(rows):
        if "Eqp" in row and len(row) > DEP_COLUMN and \
                row[DEP_COLUMN].strip() == "Dep":
            return rows, i
    raise MalhaError("Nao achei o cabecalho da malha (linha com 'Dep' na "
                     "coluna C e 'Eqp')")


def base_width(header):
    """Colunas originais do cabecalho (sem as colunas vazias do fim e sem
    as colunas que este programa ja tenha acrescentado)."""
    names = header[:header.index(NEW_COLUMNS[0])] \
        if NEW_COLUMNS[0] in header else header
    while names and not names[-1].strip():
        names = names[:-1]
    return len(names)


def is_flight(row, eqp_col):
    dep = row[DEP_COLUMN].strip() if len(row) > DEP_COLUMN else ""
    return len(dep) == 3 and dep.isalpha() and len(row) > eqp_col \
        and row[eqp_col].strip() != ""


def write_malha(path, rows, header_index, width, results):
    """Reescreve a malha com as colunas novas (copia em .bak antes)."""
    shutil.copy2(path, path.with_name(path.name + ".bak"))
    eqp_col = rows[header_index].index("Eqp")
    out = []
    for i, row in enumerate(rows):
        if i == header_index:
            out.append(row[:width] + NEW_COLUMNS)
        elif i > header_index and is_flight(row, eqp_col):
            key = (row[DEP_COLUMN].strip().upper(), row[eqp_col].strip())
            out.append((row + [""] * width)[:width] + results[key])
        else:
            out.append(row)
    with open(path, "w", encoding="utf-8", newline="") as f:
        csv.writer(f, lineterminator="\n").writerows(out)


# ------------------------------------------------------------- calculo

def structural_mtow(aircraft, variant):
    """Peso estrutural maximo de decolagem do motor (kg) ou None."""
    if aircraft.engine == "octopus":    # Airbus: POPT 24 do scap.in exemplo
        return scap_engine.read_value(
            scap_engine.find_example(variant).read_text(errors="replace"),
            "POPT", 24)
    return variant.mtow or None


class Analysis:
    """Calculos de um par (aeroporto, aeronave), com cache: cada
    (pista, combinacao) roda no maximo uma vez."""

    def __init__(self, aircraft, variant, runways, cases, toalign, workers,
                 on_progress=None):
        self.aircraft, self.variant, self.runways = aircraft, variant, runways
        self.cases, self.toalign, self.workers = cases, toalign, workers
        self.on_progress = on_progress
        self.structural = structural_mtow(aircraft, variant)
        self.cache, self.errors = {}, []
        self.done = self.planned = 0
        self.slots = Queue()
        for i in range(workers):
            self.slots.put(i + 1)
        self.lock = threading.Lock()

    def compute(self, rw, k):
        if (rw.rwy, k) in self.cache:
            return self.cache[(rw.rwy, k)]
        t, cond = self.cases[k]
        slot = self.slots.get()
        try:
            res = scap_engine.compute(
                self.aircraft, self.variant, rw, t, slot,
                align_values(rw, self.aircraft.align, self.toalign), cond=cond)
        except (scap_engine.ScapError, ValueError) as e:
            res = None
            with self.lock:
                self.errors.append(f"{rw.rwy} {t}C {cond.describe()}: "
                                   f"{str(e).splitlines()[0]}")
        finally:
            self.slots.put(slot)
        with self.lock:
            self.cache[(rw.rwy, k)] = res
        return res

    def tick(self):
        with self.lock:
            self.done += 1
            if self.on_progress:
                self.on_progress(self.done, max(self.planned, self.done))

    def run(self, jobs, fn):
        """fn(rw, k) para cada job, em paralelo."""
        jobs = list(jobs)
        with self.lock:
            self.planned += len(jobs)

        def one(job):
            fn(*job)
            self.tick()

        with ThreadPoolExecutor(self.workers) as pool:
            list(pool.map(one, jobs))

    def best_on_case(self, k):
        """Maior MTOW entre as pistas na combinacao k: (res, pista) ou
        (None, None). Roda o que faltar."""
        self.run([(rw, k) for rw in self.runways], self.compute)
        best = (None, None)
        for rw in self.runways:
            res = self.cache.get((rw.rwy, k))
            if res is not None and (best[0] is None or
                                    (res["mtow"], rw.tora)
                                    > (best[0]["mtow"], best[1].tora)):
                best = (res, rw)
        return best

    # ------------------------------------------------------------ melhor
    def best(self):
        """Maior MTOW entre todas as pistas e combinacoes: (res, pista, k)
        ou (None, None, None)."""
        cases, runways = self.cases, self.runways
        order = sorted(range(len(cases)), key=lambda k: cases[k][0])
        # stop_above: temperatura em que alguma pista chegou no estrutural; as
        # outras pistas dessa temperatura ainda rodam (desempate), as mais
        # quentes sao dispensadas.
        state = {"best": None, "stop_above": None}

        def better(res, rw, k, best):
            if best is None:
                return True
            b_res, b_rw, b_k = best
            # empate: maior TORA; depois a pista que vem antes no
            # airports_list.csv; depois a combinacao que vem antes na lista
            return ((res["mtow"], rw.tora, -runways.index(rw), -k)
                    > (b_res["mtow"], b_rw.tora, -runways.index(b_rw), -b_k))

        def one(rw, k):
            t = cases[k][0]
            if state["stop_above"] is not None and t > state["stop_above"]:
                return
            res = self.compute(rw, k)
            with self.lock:
                if res is not None and better(res, rw, k, state["best"]):
                    state["best"] = (res, rw, k)
                if res is not None and self.structural \
                        and res["mtow"] >= self.structural:
                    state["stop_above"] = min(
                        t, t if state["stop_above"] is None
                        else state["stop_above"])

        self.run([(rw, k) for k in order for rw in runways], one)
        return state["best"] or (None, None, None)

    # ------------------------------------------------------------ pior
    def groups(self):
        """Combinacoes agrupadas por (vento, traves, QNH), cada grupo em
        ordem crescente de temperatura."""
        out = {}
        for k, (t, c) in enumerate(self.cases):
            out.setdefault((c.wind, c.crosswind, c.qnh), []).append(k)
        return [sorted(ks, key=lambda k: self.cases[k][0])
                for ks in out.values()]

    def worst(self):
        """Pior caso: a combinacao em que a melhor pista da o menor MTOW.
        O MTOW cai com a temperatura, entao so a mais quente de cada grupo
        (vento, QNH) precisa ser olhada. Devolve (res, pista, k) ou
        (None, None, None)."""
        hottest = [ks[-1] for ks in self.groups()]
        self.run([(rw, k) for k in hottest for rw in self.runways],
                 self.compute)
        worst = (None, None, None)
        for k in hottest:
            res, rw = self.best_on_case(k)
            if res is not None and (worst[0] is None
                                    or res["mtow"] < worst[0]["mtow"]):
                worst = (res, rw, k)
        return worst

    def limit_temperature(self, weight, k_worst):
        """Maior temperatura (nas condicoes de vento/QNH do pior caso) em
        que alguma pista ainda decola com weight. None se nem a mais fria
        decola. Busca binaria: o MTOW cai com a temperatura."""
        ks = next(g for g in self.groups() if k_worst in g)
        ok = lambda k: (self.best_on_case(k)[0] or {}).get("mtow", 0) >= weight
        lo, hi = 0, len(ks) - 1
        if not ok(ks[lo]):
            return None
        while lo < hi:                  # ks[lo] decola; procura o ultimo
            mid = (lo + hi + 1) // 2
            if ok(ks[mid]):
                lo = mid
            else:
                hi = mid - 1
        return self.cases[ks[lo]][0]


def alert_level(best, worst, ref):
    """OK / ATENCAO / RESTRITO comparando com o peso de referencia."""
    if best is None or not ref:
        return ""
    if worst is not None and worst >= ref:
        return "OK"
    return "ATENCAO" if best >= ref else "RESTRITO"


def process(path=DEFAULT_MALHA, cases=None, workers=None, on_progress=None,
            log=print, refs=None, flaps=None, cgs=None):
    """Calcula e grava a malha. cases: combinacoes (temperatura,
    Conditions); padrao -10 a 45 C sem vento, QNH 1013.25. Devolve a lista de
    resumos por par (IATA, Eqp): dict com icao, aircraft, mtow, rwy, temp,
    cond, flap, limit, obs e o alerta (worst_*, ref, margin, limit_temp,
    alert). refs: {nome da aeronave: peso de referencia em kg}; sem valor,
    a referencia e o peso estrutural. flaps: {nome da aeronave: codigo do
    flap fixo} (ver Conditions.flap); sem valor, flap otimo. cgs: {nome da
    aeronave: limite dianteiro de CG (POPT 30)}; sem valor, Standard."""
    path = Path(path)
    cases = cases or [(t, scap_engine.CALM) for t in range(-10, 46)]
    workers = workers or scap_engine.default_workers()
    rows, header_index = read_malha(path)
    log(f"{len(cases)} combinacao(oes) de temperatura/vento/QNH por pista")
    header = rows[header_index]
    eqp_col = header.index("Eqp")
    width = base_width(header)

    keys = []
    for row in rows[header_index + 1:]:
        if is_flight(row, eqp_col):
            key = (row[DEP_COLUMN].strip().upper(), row[eqp_col].strip())
            if key not in keys:
                keys.append(key)
    if not keys:
        raise MalhaError("Nenhum voo encontrado na malha")

    iata = load_iata()
    airports = load_airports()
    toalign = load_toalign()
    results, summary = {}, []
    for n, (dep, eqp) in enumerate(keys, 1):
        info = {"iata": dep, "eqp": eqp, "icao": iata.get(dep, ""),
                "aircraft": "", "model": "", "mtow": None, "rwy": "",
                "temp": "", "cond": None, "flap": "", "limit": "", "obs": "",
                "worst_mtow": None, "worst_rwy": "", "worst_temp": "",
                "worst_cond": None, "worst_limit": "", "ref": None,
                "margin": None, "limit_temp": None, "alert": ""}
        try:
            if not info["icao"]:
                raise MalhaError(f"IATA {dep} sem ICAO em {IATA_CSV.name}")
            if info["icao"] not in airports:
                raise MalhaError(f"{info['icao']} nao esta no "
                                 f"airports_list.csv")
            aircraft, variant = resolve_aircraft(eqp)
            info["aircraft"] = f"{aircraft.name} {variant.display}"
            scap_engine.check(aircraft, variant)
            runways = list(airports[info["icao"]]["runways"].values())
            log(f"[{n}/{len(keys)}] {dep} ({info['icao']}) - "
                f"{info['aircraft']}: {len(runways)} pista(s) x "
                f"{len(cases)} combinacao(oes)")
            progress = (lambda d, t, n=n: on_progress(n, len(keys), d, t)) \
                if on_progress else None
            flap = (flaps or {}).get(aircraft.name)
            cg = (cgs or {}).get(aircraft.name, 0)
            ac_cases = [(t, dataclasses.replace(c, flap=flap, cg=cg))
                        for t, c in cases] if flap is not None or cg else cases
            an = Analysis(aircraft, variant, runways, ac_cases, toalign,
                          workers, progress)
            info["model"] = aircraft.name
            res, rw, k = an.best()
            if res is None:
                raise MalhaError("nenhum calculo deu certo: "
                                 + "; ".join(an.errors[:3]))
            t, cond = cases[k]
            info.update(mtow=res["mtow"], rwy=rw.rwy, temp=t, cond=cond,
                        flap=res["flap"], limit=res["limit_code"])
            log(f"    maior MTOW {res['mtow']} kg - pista {rw.rwy}, {t} C, "
                f"{cond.describe()}, {res['flap']}, limitante "
                f"{res['limit_code']}")
            w_res, w_rw, w_k = an.worst()
            ref = (refs or {}).get(aircraft.name) or an.structural
            info["ref"] = ref
            if w_res is not None:
                w_t, w_cond = cases[w_k]
                info.update(worst_mtow=w_res["mtow"], worst_rwy=w_rw.rwy,
                            worst_temp=w_t, worst_cond=w_cond,
                            worst_limit=w_res["limit_code"])
                if ref:
                    info["margin"] = w_res["mtow"] - ref
            info["alert"] = alert_level(res["mtow"], info["worst_mtow"], ref)
            if info["alert"] in ("ATENCAO",) and w_res is not None:
                info["limit_temp"] = an.limit_temperature(ref, w_k)
            if an.errors:
                info["obs"] = f"{len(an.errors)} calculo(s) com erro"
            log(f"    pior caso {info['worst_mtow']} kg - pista "
                f"{info['worst_rwy']}, {info['worst_temp']} C; referencia "
                f"{ref} kg: {info['alert'] or '-'}"
                + (f", decola ate {info['limit_temp']} C"
                   if info["limit_temp"] is not None else ""))
        except (MalhaError, scap_engine.ScapError) as e:
            info["obs"] = str(e).splitlines()[0]
            log(f"    ERRO: {info['obs']}")
        cond, w_cond = info["cond"], info["worst_cond"]
        blank = lambda v: "" if v is None else f"{v:g}" \
            if isinstance(v, float) else str(v)
        results[(dep, eqp)] = [
            blank(info["mtow"]), info["rwy"], str(info["temp"]), info["flap"],
            str(info["limit"]),
            cond.describe().split(" · ")[0] if cond else "",
            f"{cond.qnh:g}" if cond else "",
            blank(info["worst_mtow"]),
            f"pista {info['worst_rwy']} / {info['worst_temp']} C / "
            f"{w_cond.describe().split(' · ')[0]} / QNH {w_cond.qnh:g}"
            if w_cond else "",
            blank(info["ref"]), blank(info["margin"]),
            blank(info["limit_temp"]), ALERT_TEXT.get(info["alert"], ""),
            info["obs"]]
        summary.append(info)

    write_malha(path, rows, header_index, width, results)
    log(f"Gravado em {path} (copia do original em {path.name}.bak)")
    return summary


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("malha", nargs="?", default=str(DEFAULT_MALHA))
    p.add_argument("--tmin", type=float, default=-10)
    p.add_argument("--tmax", type=float, default=45)
    p.add_argument("--step", type=float, default=1)
    p.add_argument("--wind", default="0",
                   help="vento ao longo da pista em kt (+ proa, - cauda): "
                        "valor, lista (-5,0,5) ou faixa (-10:20:5)")
    p.add_argument("--crosswind", type=float, default=0,
                   help="traves em kt, + da direita (so Airbus)")
    p.add_argument("--qnh", default="1013.25",
                   help="QNH em hPa: valor, lista ou faixa (990:1030:10)")
    p.add_argument("--workers", type=int, default=scap_engine.default_workers())
    p.add_argument("--ref", action="append", default=[], metavar="AERONAVE=KG",
                   help="peso de referencia do alerta (ex.: --ref E195-E2="
                        "60000); sem isso, o peso estrutural")
    args = p.parse_args()
    from batch import build_cases, parse_values, temperatures
    try:
        cases = build_cases(temperatures(args.tmin, args.tmax, args.step),
                            parse_values(args.wind, "--wind"),
                            parse_values(args.qnh, "--qnh"), args.crosswind)
        refs = {}
        for item in args.ref:
            name, _, kg = item.partition("=")
            refs[name.strip()] = float(kg)
        process(args.malha, cases, args.workers, refs=refs)
    except (MalhaError, ValueError, OSError) as e:
        raise SystemExit(f"Erro: {e}")


if __name__ == "__main__":
    main()

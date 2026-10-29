"""Decolagem: escolhe o motor de cada aeronave e roda varios calculos em
paralelo (pastas de trabalho separadas).

Motores (Aircraft.engine):
  octopus         Airbus (airbus.py)
  takeoff_module  Embraer E1/E2 (embraer.py)
  ttam            ATR (atr.py: TTAM.dll pelo SCAPApp.exe)
"""

import os
import threading
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager

from .. import scapapp
from ..paths import ATR_PACKAGE, find_file
from . import airbus, atr, embraer
from .common import CALM, Conditions, ScapError, missing_databases  # noqa: F401
from .airbus import build_input, find_example, read_value  # noqa: F401


def check(aircraft, variant):
    if not aircraft.supported:
        raise ScapError(f"{aircraft.name} ainda nao esta ligado "
                        f"(motor {aircraft.engine})")
    if aircraft.engine == "ttam":        # base e licenca ficam no pacote da ATR
        missing = [n for n in scapapp.ARQUIVOS + ("data/" + scapapp.BASE,)
                   if not (ATR_PACKAGE / n).exists()]
        if missing:
            raise ScapError(f"Falta no pacote da ATR ({ATR_PACKAGE}): " + ", ".join(missing))
        return
    if aircraft.engine == "octopus":
        engine_files = airbus.ENGINE_FILES
        airbus.find_example(variant)
    else:
        engine_files = embraer.COPY_FILES
    missing = missing_databases(variant) + [
        n for n in engine_files if find_file(n) is None]
    if missing:
        raise ScapError("Arquivo nao encontrado em engines/ ou databases/: "
                        + ", ".join(missing))


def compute(aircraft, variant, runway=None, temperature=None, slot=0,
            align=None, retries=2, cond=CALM):
    """Roda o motor da aeronave e devolve o resultado resumido:
    mtow, flap, limit_code, v1_min, v1_max, vr, v2 (None se o motor nao da).
    cond: vento/QNH (Conditions); o traves so entra no Airbus, como no
    INPUT.FOR."""
    check(aircraft, variant)
    if aircraft.engine == "octopus":
        return airbus.compute(aircraft, variant, runway, temperature, slot,
                              align, retries, cond)
    if runway is None or temperature is None:
        raise ScapError(f"{aircraft.name}: escolha a pista e a temperatura")
    align = align or {12: 0, 13: 0}
    if aircraft.engine == "ttam":
        return atr.compute(variant, runway, temperature, align, slot,
                           cond=cond)
    return embraer.compute(aircraft, variant, runway, temperature, align,
                           slot, cond=cond)


def default_workers():
    """Calculos em paralelo: PERF_WORKERS ou metade dos nucleos (max. 6)."""
    if os.environ.get("PERF_WORKERS", "").isdigit():
        return max(1, int(os.environ["PERF_WORKERS"]))
    return max(1, min(6, (os.cpu_count() or 2) // 2))


_SLOT_LOCK = threading.Lock()
_FREE_SLOTS = []
_SLOT_COUNT = [0]
_RUNNING = None


@contextmanager
def work_slot():
    """Numero de pasta de trabalho (w<n>, tm<n>, atr<n>) so deste calculo
    enquanto ele roda. O pool e global: varios calculos ao mesmo tempo (por
    exemplo duas pessoas no servidor) nunca dividem a mesma pasta, e no
    total rodam no maximo default_workers() motores de uma vez. A pasta 0
    fica para o calculo unico do desktop."""
    global _RUNNING
    with _SLOT_LOCK:
        if _RUNNING is None:
            _RUNNING = threading.BoundedSemaphore(default_workers())
    with _RUNNING:
        with _SLOT_LOCK:
            if _FREE_SLOTS:
                slot = _FREE_SLOTS.pop()
            else:
                _SLOT_COUNT[0] += 1
                slot = _SLOT_COUNT[0]
        try:
            yield slot
        finally:
            with _SLOT_LOCK:
                _FREE_SLOTS.append(slot)


def compute_cases(aircraft, variant, runway, cases, workers=None,
                  on_progress=None, align=None):
    """Calcula varias combinacoes (temperatura, Conditions) em paralelo.
    Devolve uma lista na ordem de cases com o resultado ou {'error'}."""
    check(aircraft, variant)
    workers = workers or default_workers()
    done = [0]
    lock = threading.Lock()

    def one(case):
        temp, cond = case
        try:
            with work_slot() as slot:
                res = compute(aircraft, variant, runway, temp, slot, align,
                              cond=cond)
        except ScapError as e:
            res = {"temperature": temp, "error": str(e)}
        with lock:
            done[0] += 1
            count = done[0]
        if on_progress:
            on_progress(count, len(cases))
        return res

    with ThreadPoolExecutor(workers) as pool:
        return list(pool.map(one, cases))


def compute_tasks(tasks, workers=None, on_progress=None):
    """Calcula varias tarefas misturando aeronaves e pistas em paralelo
    (nunca duas tarefas na mesma pasta de trabalho ao mesmo tempo).
    tasks: lista de (aircraft, variant, runway, temperatura, Conditions,
    align). Pode rodar junto com outros compute_tasks (ver work_slot). Devolve os resultados na mesma ordem (ou {'error'})."""
    for aircraft, variant in {(t[0], t[1]) for t in tasks}:
        check(aircraft, variant)
    workers = workers or default_workers()
    done = [0]
    lock = threading.Lock()

    def one(task):
        aircraft, variant, runway, temp, cond, align = task
        try:
            with work_slot() as slot:
                res = compute(aircraft, variant, runway, temp, slot, align,
                              cond=cond)
        except ScapError as e:
            res = {"temperature": temp, "error": str(e), "entrada": e.entrada}
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

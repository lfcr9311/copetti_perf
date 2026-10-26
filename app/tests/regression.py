#!/usr/bin/env python3
"""Regressao pela API HTTP: roda casos fixos e compara com golden.json.

    python3 tests/regression.py            # compara (sai 1 se algum mudar)
    python3 tests/regression.py --record   # grava a referencia de novo

Sobe o server.py numa porta livre, chama /api/calc (decolagem) e /api/pouso
(pouso) e compara peso, limitante, flap e gradiente. A referencia inclui os
casos conferidos no EFB/iPad (ex. A320 pouso SDU 20L 57.287 / 61.468 kg,
E195 decolagem 42.244 / 42.382 kg, E2 53.034 / 53.208 kg). So grave de novo
quando a mudanca de resultado for intencional.
"""
import json
import os
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent.parent
GOLDEN = Path(__file__).resolve().parent / "golden.json"

CASOS_TO = [  # (aeronave, motor, icao, pista, oat, vento, qnh, extra)
    ("A320", 0, "SBRJ", "20L", 30, 0, 1013.25, {}), ("A320", 1, "SBRJ", "20L", 30, 0, 1013.25, {}),
    ("A320", 2, "SBKG", "15", 30, 0, 1013.25, {}), ("A320", 0, "SBRJ", "20L", 30, 0, 1013.25, {"cg": {"A320": [1]}}),
    ("A320", 0, "SBRJ", "20L", 25, 10, 1013.25, {}), ("A320", 0, "SBRJ", "20L", 25, -5, 990, {}),
    ("A320", 0, "SBRJ", "20L", 30, 0, 1013.25, {"flaps": {"A320": [2215]}}),
    ("A321neo", 0, "SBRJ", "20L", 30, 0, 1013.25, {}), ("A320", 0, "SBKP", "15", 0, 0, 1013.25, {"mtow": {"A320": 77000}}),
    ("A321F", 0, "SBRJ", "20L", 30, 0, 1013.25, {}), ("A321F", 1, "SBKG", "15", 30, 0, 1013.25, {}),
    ("A330", 0, "SBKP", "15", 35, 0, 1013.25, {}), ("A330neo", 0, "SBKP", "15", 35, 0, 1013.25, {}),
    ("A330neo", 0, "SBKP", "15", 35, 0, 1013.25, {"cg": {"A330neo": [4]}}),
    ("ATR 72-600", 0, "SBRJ", "20L", 30, 0, 1013.25, {}), ("ATR 72-600", 1, "SBKG", "33", 30, 0, 1013.25, {}),
    ("ATR 72-600", 2, "SBFN", "30", 30, 0, 1013.25, {}), ("ATR 72-600", 3, "SBKG", "15", 30, 0, 1013.25, {}),
    ("E195", 0, "SBRJ", "20L", 30, 0, 1013, {}), ("E195", 0, "SBRJ", "20L", 30, 0, 1013, {"cg": {"E195": [1]}}),
    ("E195", 0, "SBKG", "15", 35, 0, 1013.25, {}), ("E195", 0, "SBRJ", "20L", 30, 0, 1013, {"flaps": {"E195": [3]}}),
    ("E195-E2", 0, "SBRJ", "20L", 30, 0, 1013, {}), ("E195-E2", 0, "SBRJ", "20L", 30, 0, 1013, {"cg": {"E195-E2": [1]}}),
    ("E195-E2", 0, "SBFN", "30", 35, 5, 1013.25, {}),
]
CASOS_LD = [  # (aeronave, icao, pista, lda, oat, qnh, molhada, grooved, conf_pouso, conf_arremetida, extra)
    ("A320", "SBRJ", "20L", 1323, 25, 1013.25, False, True, 2740, 2220, {"athr": True, "mlw": 67400}),
    ("A320", "SBRJ", "20L", 1323, 25, 1013.25, False, True, 2740, 2220, {"athr": False, "mlw": 67400}),
    ("A320", "SBRJ", "20L", 1323, 25, 1013.25, True, True, 2740, 2220, {"athr": True, "mlw": 67400}),
    ("A320", "SBKG", "15", 1565, 25, 1013.25, True, False, 2740, 2220, {"athr": True, "mlw": 67400, "lw": 60000}),
    ("A320", "SBRJ", "20L", 1323, 25, 1013.25, False, True, 2220, 2215, {"athr": True, "mlw": 67400}),
    ("E195", "SBRJ", "20L", 1323, 25, 1013.25, False, True, 6, 4, {"mlw": 45000}),
    ("E195", "SBRJ", "20L", 1260, 30, 1013, False, True, 5, 2, {}),
    ("E195", "SBKG", "15", 1565, 40, 1013.25, True, False, 6, 4, {}),
    ("E195-E2", "SBRJ", "20L", 1323, 25, 1013.25, False, True, 6, 0, {}),
    ("E195-E2", "SBRJ", "20L", 1323, 25, 1013.25, True, False, 6, 0, {"lw": 50000}),
    ("E195-E2", "SBRJ", "20L", 1323, 25, 1013.25, False, True, 5, 0, {"mlw": 54000}),
    ("ATR 72-600", "SBJR", "03", 900, 25, 1013.25, False, False, 30, 15, {}),
    ("ATR 72-600", "SBJR", "03", 900, 25, 1013.25, False, False, 30, 15, {"antigelo": 6}),
    ("ATR 72-600", "SBRJ", "20L", 1323, 25, 1013.25, False, False, 30, 15, {"mlw": 22350, "lw": 21000}),
    # conferidos no FlySmart (A/THR off): A320 NSHP26K SBRJ 61,4 / molhada 58,2 t; A321neo SBRJ 58 t
    ("A320", "SBRJ", "20L", 1323, 25, 1013.25, False, True, 2740, 2220, {"athr": False, "icao": "SBRJ", "rwy": "20L"}),
    ("A320", "SBRJ", "20L", 1323, 25, 1013.25, True, True, 2740, 2220, {"athr": False, "icao": "SBRJ", "rwy": "20L"}),
    ("A320", "SBRJ", "20L", 1323, 25, 1013.25, False, True, 2740, 2220, {"athr": False, "cg": 1, "icao": "SBRJ", "rwy": "20L"}),
    ("A320", "SBKG", "33", 1475, 25, 1013.25, True, True, 2740, 2220, {"athr": False, "icao": "SBKG", "rwy": "33"}),
    ("A321neo", "SBRJ", "20L", 1323, 25, 1013.25, False, True, 2734, 2221, {"athr": False, "icao": "SBRJ", "rwy": "20L"}),
    ("A321neo", "SBKP", "15", 3150, 25, 1013.25, True, False, 2734, 2221, {"athr": False}),
    ("A321F", "SBRJ", "20L", 1323, 25, 1013.25, False, True, 2725, 2221, {"athr": False, "icao": "SBRJ", "rwy": "20L"}),
    ("A330", "SBKP", "15", 3150, 25, 1013.25, False, False, 2332, 2322, {"athr": False}),
    ("A330neo", "SBKP", "15", 3150, 25, 1013.25, True, False, 2332, 2323, {"athr": False}),
]


def porta_livre():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def chamar(base, rota, body=None):
    req = urllib.request.Request(base + rota, json.dumps(body).encode() if body is not None else None,
                                 {"Content-Type": "application/json"})
    try:
        return json.load(urllib.request.urlopen(req, timeout=600))
    except urllib.error.HTTPError as e:
        return {"erro_http": json.load(e).get("error", "")[:200]}


def rodar():
    porta = porta_livre()
    srv = subprocess.Popen([sys.executable, "server.py", "--no-browser"], cwd=APP_DIR,
                           env=dict(os.environ, PERF_PORT=str(porta), PERF_PASSWORD=""),
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    base = f"http://127.0.0.1:{porta}"
    try:
        for _ in range(60):
            try:
                meta = chamar(base, "/api/meta")
                break
            except Exception:
                time.sleep(0.5)
        ids = {a["name"]: a["id"] for a in meta["aircraft"]}
        out = {}
        for i, (ac, var, icao, rwy, t, w, q, extra) in enumerate(CASOS_TO, 1):
            body = {"selection": [{"aircraft": ids[ac], "variant": var}], "runways": [{"icao": icao, "rwy": rwy}],
                    "temp": {"mode": "single", "value": t}, "qnh": {"mode": "single", "value": q},
                    "wind": {"kind": "calm"} if not w else {"kind": "head" if w > 0 else "tail", "speed": abs(w)}, **extra}
            job = chamar(base, "/api/calc", body)
            while job.get("state") == "running":
                time.sleep(0.5)
                job = chamar(base, f"/api/job/{job['id']}")
            r = (job.get("result") or {}).get("rows", [{}])[0]
            chave = f"TO{i:02d} {ac} v{var} {icao} {rwy} {t}C w{w} q{q} {json.dumps(extra, sort_keys=True)}"
            out[chave] = {"peso": r.get("mtow"), "flap": r.get("flap"), "limitante": r.get("limit_text"),
                          "erro": r.get("error") or job.get("error") or job.get("erro_http")}
            print(chave, "->", out[chave]["peso"], out[chave]["limitante"], flush=True)
        pmeta = {a["name"]: a["id"] for a in chamar(base, "/api/pouso/meta")["aircraft"]}
        for i, (ac, icao, rwy, lda, t, q, molh, groo, cp, ca, extra) in enumerate(CASOS_LD, 1):
            body = {"aircraft": pmeta[ac], "variant": 0, "lda": lda, "elev": 10 if icao == "SBRJ" else None,
                    "slope": 0, "temp": t, "qnh": q, "vento": 0, "molhada": molh, "grooved": groo,
                    "conf_pouso": cp, "conf_arremetida": ca, "reverso": 0, "antigelo": 0, "ar": 2,
                    "autobrake": 0, "vref_inc": 0, "mlw": "", "lw": "", "ga_grad": "", **extra}
            body["elev"] = {"SBRJ": 10, "SBKG": 1647, "SBJR": 10, "SBKP": 2170}.get(icao, 0)
            r = chamar(base, "/api/pouso", body)
            chave = f"LD{i:02d} {ac} {icao} {rwy} lda{lda} {t}C q{q} {'molh' if molh else 'seca'}{' groo' if groo else ''} {cp}/{ca} {json.dumps(extra, sort_keys=True)}"
            out[chave] = {"peso": round(r["mlw"]) if r.get("mlw") else None, "limitante": r.get("limitante"),
                          "grad": round(r["gradiente_arremetida"], 2) if r.get("gradiente_arremetida") else None,
                          "erro": (r.get("erro_http") or "")[:80] or None}
            print(chave, "->", out[chave]["peso"], out[chave]["limitante"], flush=True)
        return out
    finally:
        srv.terminate()


def main():
    atual = rodar()
    if sys.argv[1:] == ["--record"]:
        GOLDEN.write_text(json.dumps(atual, ensure_ascii=False, indent=1))
        print(f"\n{len(atual)} casos gravados em {GOLDEN}")
        return
    ref = json.loads(GOLDEN.read_text())
    dif = [(k, ref.get(k), atual.get(k)) for k in sorted(set(ref) | set(atual)) if ref.get(k) != atual.get(k)]
    for k, a, b in dif:
        print(f"MUDOU {k}\n   antes: {a}\n   agora: {b}")
    print(f"\n{len(ref)} casos, {len(dif)} diferentes")
    sys.exit(1 if dif else 0)


if __name__ == "__main__":
    main()

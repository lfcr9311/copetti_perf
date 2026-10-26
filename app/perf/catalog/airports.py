"""Base de aeroportos/pistas (airports_list.csv) e blocos RWYD/OBSD."""

import csv
from dataclasses import dataclass, field

from ..paths import DATA_DIR

AIRPORTS_CSV = DATA_DIR / "airports_list.csv"
TOALIGN_CSV = DATA_DIR / "toalign_list.csv"

MAX_OBSTACLES = 15   # takeoff_data.dat traz OBSD(3) ate OBSD(46)


def load_toalign(path=TOALIGN_CSV):
    """ACFT -> {'0': (TORA, ASDA), '90': ..., '180': ..., '180PAD': ...}
    (perda de distancia no alinhamento, em metros)."""
    table = {}
    with open(path, encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            table[row["ACFT"].strip()] = {
                k: (_float(row[f"T{k}"]), _float(row[f"A{k}"]))
                for k in ("0", "90", "180", "180PAD")}
    return table


def align_values(runway, align_name, table):
    """POPT 12/13 (alinhamento TORA/ASDA) pela coluna TO ALIGN da pista."""
    key = runway.to_align.upper() or "0"
    try:
        tora, asda = table[align_name][key]
    except KeyError:
        raise ValueError(f"Sem alinhamento '{key}' para '{align_name}' "
                         f"no {TOALIGN_CSV.name}")
    return {12: tora, 13: asda}


@dataclass
class Runway:
    icao: str
    name: str
    rwy: str
    elev: float          # ft
    tora: float          # m
    toda: float          # m
    asda: float          # m
    width: float         # m
    slope: float         # %
    surface: str         # NORMAL ou GROOVED...
    to_align: str        # 0, 90, 180, 180PAD
    obstacles: list = field(default_factory=list)  # (dist. fim TORA m, altura ft)

    @property
    def grooved(self):
        return "GROOVED" in self.surface.upper()


def _float(text, default=0.0):
    try:
        return float(text)
    except ValueError:
        return default


def load_airports(path=AIRPORTS_CSV):
    """Colunas: 0 ICAO, 1 NOME, 2 ELEV, 3 CABECEIRA, 4 TORA, 5 TODA, 6 ASDA,
    7 LARGURA, 8 SLOPE, 9 SUPERFICIE, 10 TO ALIGN, 11-17 peso por aeronave,
    18 HEADING, 19 N OBST, 20.. pares distancia/altura."""
    airports = {}
    with open(path, encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f)
        next(reader, None)
        for row in reader:
            if len(row) < 20 or not row[0].strip() or not row[3].strip():
                continue
            n_obst = int(_float(row[19]))
            pairs = row[20:]
            obstacles = []
            for i in range(min(n_obst, MAX_OBSTACLES)):
                dist, height = (pairs[2 * i:2 * i + 2] + ["", ""])[:2]
                if dist.strip() and height.strip():
                    obstacles.append((_float(dist), _float(height)))
            rwy = Runway(
                icao=row[0].strip(), name=row[1].strip(), rwy=row[3].strip(),
                elev=_float(row[2]), tora=_float(row[4]), toda=_float(row[5]),
                asda=_float(row[6]), width=_float(row[7], 45.0),
                slope=_float(row[8]), surface=row[9].strip(),
                to_align=row[10].strip(), obstacles=obstacles)
            airports.setdefault(rwy.icao, {"name": rwy.name, "runways": {}})
            airports[rwy.icao]["runways"][rwy.rwy] = rwy
    return airports


def rwyd_values(runway, actype, wet):
    """RWYD como o INPUT.FOR monta para Airbus (RWYD 7 fica sem valor)."""
    surface = 0
    if actype in ("AIRBUS320", "AIRBUS321", "AIRBUSF321") and wet:
        if runway.grooved:
            surface = 2 if "321" in actype else 1
    return {1: runway.elev, 2: 0, 3: runway.tora, 4: runway.asda,
            5: runway.toda, 6: runway.slope, 8: surface, 9: 1, 10: 0,
            11: runway.width}


def obsd_values(runway):
    """OBSD 1 = n, OBSD 2 = 1, depois (distancia, altura, lateral=0)."""
    values = {1: len(runway.obstacles), 2: 1}
    for i, (dist, height) in enumerate(runway.obstacles):
        values[3 * i + 3] = dist
        values[3 * i + 4] = height
        values[3 * i + 5] = 0
    return values

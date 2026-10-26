"""Onde fica cada coisa do projeto (unico lugar com caminhos fixos).

    engines/    motores dos fabricantes (DLL, .exe, .so, .cnf)
    databases/  bases de desempenho (.pre, .DAT, .pdm, .pdf)
    data/       cadastros (aeroportos, alinhamento, malha, IATA)
    app/work/   pastas de trabalho dos calculos (temporario)
    app/results CSVs gerados pelo app
"""

import gzip
import shutil
import threading
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent.parent
ROOT = APP_DIR.parent
ENGINES_DIR = ROOT / "engines"
DATABASES_DIR = ROOT / "databases"
DATA_DIR = ROOT / "data"
WORK_DIR = APP_DIR / "work"
RESULTS_DIR = APP_DIR / "results"
WEB_DIR = APP_DIR / "web"
ASSETS_DIR = APP_DIR / "assets"
TEMPLATES_DIR = Path(__file__).resolve().parent / "takeoff" / "templates"

ATR_SO = ENGINES_DIR / "atr" / "DllWrapperATR.so"
ATR_PACKAGE = ENGINES_DIR / "atr" / "SCAP_APS_2.7.1"
LOADER = ENGINES_DIR / "loader" / "scaploader.exe"

# onde find_file procura motores e bases, nesta ordem
SEARCH_DIRS = tuple(d for base in (ENGINES_DIR, DATABASES_DIR)
                    for d in sorted(p for p in base.iterdir() if p.is_dir())
                    if d.name != "loader") if ENGINES_DIR.is_dir() else ()


def find_file(name, folder=None):
    """Procura o arquivo sem diferenciar maiusculas (o Wine faz o mesmo) nas
    pastas de engines/ e databases/ (ou so em folder). Se so existir
    <nome>.gz (as bases grandes vao comprimidas para o GitHub), descomprime
    na primeira vez."""
    wanted = name.lower()
    gz = None
    for d in (folder,) if folder else SEARCH_DIRS:
        for path in d.iterdir():
            if path.name.lower() == wanted:
                return path
            if path.name.lower() == wanted + ".gz" and gz is None:
                gz = path
    if gz is not None and folder is None:
        return _gunzip(gz)
    return None


_GUNZIP_LOCK = threading.Lock()


def _gunzip(gz):
    target = gz.with_name(gz.name[:-3])
    with _GUNZIP_LOCK:
        if not target.exists():
            part = target.with_name(target.name + ".part")
            with gzip.open(gz, "rb") as src, open(part, "wb") as dst:
                shutil.copyfileobj(src, dst, 1 << 20)
            part.replace(target)
    return target


def drop_broken_link(path):
    """Apaga um link quebrado (ex. pasta work/ copiada de outra maquina,
    com links para /home/<outro usuario>/...) para ele ser refeito."""
    if path.is_symlink() and not path.exists():
        path.unlink()

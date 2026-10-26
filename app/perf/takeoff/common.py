"""Comum aos motores de decolagem: erro, condicoes (vento/QNH/flap/CG) e
bases de cada variante."""

from dataclasses import dataclass

from ..paths import find_file


class ScapError(Exception):
    pass


@dataclass(frozen=True)
class Conditions:
    """Vento e pressao, sempre relativos a pista (convencao do SCAP):
    wind > 0 = proa, wind < 0 = cauda (XMET 2); crosswind > 0 = vindo da
    direita (XMET 3, so o Airbus usa); qnh em hPa (XMET 5, XMET 4 = 1).
    flap: None = otimo (o motor escolhe o que da maior MTOW); senao o flap
    fixo no codigo de cada motor: Airbus o codigo de FLAP_NAMES, ex. 1810 =
    CONF 1+F (CONF 1 = 1, CONF 2); Embraer 1 a 4 (CONF 3); ATR 15 (CONF 3;
    a base do ATR so tem o FLAP 15).
    cg: limite dianteiro de CG (POPT 30): 0 = Standard, 1 = Alternate...
    (opcoes de cada aeronave em Aircraft.cg).
    mtow: peso estrutural maximo de decolagem (POPT 24, kg); None = o da
    base (scap.in exemplo no Airbus, Variant.mtow no ATR/Embraer)."""
    wind: float = 0.0
    crosswind: float = 0.0
    qnh: float = 1013.25
    flap: "int | None" = None
    cg: int = 0
    mtow: "float | None" = None

    def describe(self):
        parts = []
        if self.wind > 0:
            parts.append(f"proa {self.wind:g} kt")
        elif self.wind < 0:
            parts.append(f"cauda {-self.wind:g} kt")
        if self.crosswind:
            side = "direita" if self.crosswind > 0 else "esquerda"
            parts.append(f"través {abs(self.crosswind):g} kt ({side})")
        wind = ", ".join(parts) or "sem vento"
        return f"{wind} · QNH {self.qnh:g}"


CALM = Conditions()


def database_files(variant):
    return [n for n in variant.acmdbi.split(";") + [variant.miscla] if n]


def missing_databases(variant):
    return [n for n in database_files(variant) if find_file(n) is None]

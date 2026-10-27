"""Peso maximo de pouso (despacho) de qualquer aeronave com as opcoes padrao
da aba Pouso: flap FULL, A/THR off, sem reverso, anti-ice e ar-condicionado
OFF, autobrake OFF, MLW certificado da aeronave e grooved/PFC do cadastro
(so nas bases que aceitam). Usado na varredura de pista bloqueada.
"""

from ..takeoff.common import ScapError
from . import airbus, atr, embraer


def max_landing(aircraft, variant, runway, lda, temp, qnh=1013.25, wind=0.0,
                wet=False, slot=""):
    """Devolve {'mlw', 'limitante', 'erro'} para a LDA dada (m) na pista
    (elevacao, slope e superficie do cadastro). Erro do motor vira 'erro'."""
    mlw = aircraft.mlw or None
    try:
        if aircraft.engine == "octopus":
            cp, ca = airbus.CONF_POUSO[aircraft.actype]["FULL"]
            p = airbus.Pouso(lda=lda, elev=runway.elev, slope=runway.slope, temp=temp,
                             qnh=qnh, vento=wind, molhada=wet, conf_pouso=cp,
                             conf_arremetida=ca, mlw=mlw,
                             grooved=runway.grooved and aircraft.actype in airbus.GROOVED_POUSO)
            r = airbus.calcular(variant, p, slot=slot)
        elif aircraft.name in embraer.MODELOS:
            fp, fa = embraer.FLAPS_MODELO[aircraft.name]["FULL"]
            p = embraer.PousoE(lda=lda, elev=runway.elev, slope=runway.slope, temp=temp,
                               qnh=qnh, vento=wind, molhada=wet, grooved=runway.grooved,
                               flap_pouso=fp, flap_arremetida=fa, mlw=mlw)
            r = embraer.calcular(aircraft.name, p, slot=slot)
        elif aircraft.engine == "ttam":
            fp, fa = atr.FLAPS["30"]
            rating = variant.rating.upper()
            p = atr.PousoATR(lda=lda, elev=runway.elev, slope=runway.slope, temp=temp,
                             qnh=qnh, vento=wind, molhada=wet, flap_pouso=fp,
                             flap_arremetida=fa,
                             boost=2 if "BOOSTON" in rating else 1 if "BOOSTOFF" in rating else 0,
                             motor=variant.engtyp.replace("_M", ""), mlw=mlw)
            r = atr.calcular(p, slot=slot)
        else:
            return {"mlw": None, "limitante": "", "erro": f"Pouso não disponível para {aircraft.name}"}
    except (airbus.PousoError, embraer.PousoError, atr.PousoError, ScapError) as e:
        return {"mlw": None, "limitante": "", "erro": str(e).splitlines()[0]}
    limitante = r["limitante"]
    if mlw and r.get("mlw") is not None and abs(r["mlw"] - mlw) < 0.5:
        limitante = "Peso máximo de pouso certificado (MLW)"
    erro = "" if r.get("mlw") is not None else "sem resultado: " + " · ".join(r.get("mensagens", [])[:2])
    return {"mlw": r.get("mlw"), "limitante": limitante, "erro": erro}

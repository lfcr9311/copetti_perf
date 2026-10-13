# Performance de Decolagem: tela + calculo (Airbus e Embraer pelo Wine, ATR
# pelo .so) num container so. Construir a partir da pasta fortran/:
#   docker compose up -d --build        (ver scap_py/DOCKER.md)
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
# Wine de 32 bits (scap_octopus.dll e takeoff_module.exe sao Windows 32 bits),
# Python e a libgfortran do DllWrapperATR.so
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        wine wine32 wine64 python3 libgfortran5 ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 1000 perf
USER perf
ENV WINEPREFIX=/home/perf/.wine WINEDEBUG=-all
# cria o prefixo do Wine uma vez, na construcao da imagem
# (sem tela: avisos de display sao normais e nao atrapalham)
RUN (wineboot --init || true) && (wineserver --wait || true)

WORKDIR /app
COPY --chown=perf:perf . /app
# bases grandes que vieram comprimidas do GitHub (.pdm.gz): descomprime ja
RUN cd /app && for f in *.gz; do [ -e "$f" ] || continue; \
      [ -e "${f%.gz}" ] || gunzip -k "$f"; done \
 && mkdir -p scap_py/work scap_py/resultados

ENV PERF_HOST=0.0.0.0 PERF_PORT=8765 PERF_SERVER=1 PYTHONUNBUFFERED=1
EXPOSE 8765
CMD ["python3", "scap_py/app.py", "--no-browser"]

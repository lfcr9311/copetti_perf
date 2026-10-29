# Performance de Decolagem: tela + calculo (Airbus, Embraer e ATR pelo Wine)
# num container so. Construir a partir da pasta fortran/:
#   docker compose up -d --build        (ver docs/DOCKER.md)
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
# Wine de 32 bits (scap_octopus.dll e takeoff_module.exe sao Windows 32 bits),
# Python; o ATR roda pelo SCAPApp.exe (.NET) no Wine com o Wine Mono
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        wine wine32 wine64 python3 ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 1000 perf
USER perf
ENV WINEPREFIX=/home/perf/.wine WINEDEBUG=-all
# Wine Mono (.NET do Wine): o SCAPApp.exe do ATR (decolagem e pouso) e .NET. O Debian nao
# empacota; o wineboot instala sozinho o .msi que estiver em ~/.cache/wine
# (versao casada com o Wine 8.0 do bookworm)
ADD --chown=perf:perf https://dl.winehq.org/wine/wine-mono/7.4.0/wine-mono-7.4.0-x86.msi /home/perf/.cache/wine/
# cria o prefixo do Wine uma vez, na construcao da imagem
# (sem tela: avisos de display sao normais e nao atrapalham)
RUN (wineboot --init || true) && (wineserver --wait || true) \
 && test -d "$WINEPREFIX/drive_c/windows/mono" && rm -rf /home/perf/.cache/wine

WORKDIR /app
COPY --chown=perf:perf . /app
# bases grandes que vieram comprimidas do GitHub (.pdm.gz): descomprime ja
RUN cd /app && for f in databases/*/*.gz; do [ -e "$f" ] || continue; \
      [ -e "${f%.gz}" ] || gunzip -k "$f"; done \
 && mkdir -p app/work app/results

ENV PERF_HOST=0.0.0.0 PERF_PORT=8765 PERF_SERVER=1 PYTHONUNBUFFERED=1
EXPOSE 8765
CMD ["python3", "app/server.py", "--no-browser"]

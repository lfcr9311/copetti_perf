#!/usr/bin/env bash
# =============================================================================
# Dependencias do Performance de Decolagem numa maquina nova (Ubuntu/Debian
# x86_64), para rodar e desenvolver sem Docker:
#
#   - Wine 32 bits     scap_octopus.dll (Airbus), takeoff_module.exe e as DLLs
#                      da Embraer sao programas Windows de 32 bits
#   - Python 3         o app (so biblioteca padrao)
#   - libgfortran5     o motor do ATR (scap_py/engines/DllWrapperATR.so)
#   - MinGW i686       compila o scap_py/engines/scaploader.exe (carregador
#                      em C das DLLs da Embraer; o .exe ja vem pronto no Git,
#                      o compilador so e preciso para recompilar)
#
# Uso, de dentro da pasta fortran:
#     sudo bash deploy/instalar_dependencias.sh
# Pode rodar de novo sem problema. Servidor: use o Docker (deploy/migrar_docker.sh)
# ou o deploy/instalar_ec2.sh.
# =============================================================================
set -euo pipefail

passo() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()    { printf '    \033[32mOK\033[0m %s\n' "$*"; }
falha() { printf '\n\033[1;31mERRO:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || falha "Rode com sudo:  sudo bash deploy/instalar_dependencias.sh"
[ "$(uname -m)" = x86_64 ] || falha "A maquina precisa ser x86_64 (Wine 32 bits nao roda em ARM)."
DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN_USER="${SUDO_USER:-$(stat -c %U "$DIR")}"
RUN_HOME="$(getent passwd "$RUN_USER" | cut -d: -f6)"

passo "Pacotes do sistema"
export DEBIAN_FRONTEND=noninteractive
dpkg --add-architecture i386
apt-get update -q
apt-get install -y -q \
    ca-certificates curl gzip git \
    python3 libgfortran5 \
    wine wine32:i386 wine64 \
    gcc-mingw-w64-i686
ok "$(python3 --version)"
ok "$(wine --version 2>/dev/null || echo wine)"
ok "$(i686-w64-mingw32-gcc --version | head -1)"

passo "Wine do usuario $RUN_USER"
sudo -u "$RUN_USER" env HOME="$RUN_HOME" WINEDEBUG=-all \
    WINEDLLOVERRIDES="mscoree,mshtml=" timeout 300 wineboot --init >/dev/null 2>&1 || true
sudo -u "$RUN_USER" env HOME="$RUN_HOME" timeout 120 wineserver --wait >/dev/null 2>&1 || true
ok "prefixo em $RUN_HOME/.wine"

passo "Carregador das DLLs da Embraer (scaploader.exe)"
sudo -u "$RUN_USER" bash "$DIR/scap_py/engines/compilar.sh"

passo "Bases grandes (.pdm.gz)"
shopt -s nullglob
for gz in "$DIR"/*.gz; do
    [ -e "${gz%.gz}" ] || { sudo -u "$RUN_USER" gunzip -k "$gz"; ok "descomprimido $(basename "${gz%.gz}")"; }
done

cat <<EOF

Pronto. Para abrir o app:   cd $DIR/scap_py && python3 app.py
EOF

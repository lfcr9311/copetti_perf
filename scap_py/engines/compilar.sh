#!/usr/bin/env bash
# Compila o scaploader.exe (carregador em C das DLLs da Embraer) com o MinGW.
# Precisa do pacote gcc-mingw-w64-i686. O .exe gerado fica nesta pasta.
set -euo pipefail
cd "$(dirname "$0")"
i686-w64-mingw32-gcc -O2 -s -static -Wall -o scaploader.exe scaploader.c
echo "scaploader.exe compilado ($(stat -c %s scaploader.exe) bytes)"

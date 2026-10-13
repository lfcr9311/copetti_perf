#!/usr/bin/env bash
# =============================================================================
# Performance de Decolagem - instalacao completa num servidor novo
# (EC2 da AWS, Oracle Cloud ou qualquer maquina Ubuntu/Debian x86_64).
#
# Instala TUDO: bibliotecas do sistema, Wine 32 bits (Airbus e Embraer),
# Python 3, libgfortran (ATR), nginx, swap (maquinas pequenas), o servico
# "perf" (app.py sempre ligado) e testa os tres motores de calculo no fim.
#
# Uso, de dentro da pasta fortran no servidor:
#     sudo bash deploy/instalar_ec2.sh
# (pede a senha da tela; ou passe direto: sudo PERF_PASSWORD='...' bash ...)
#
# Pode rodar de novo quantas vezes quiser: para trocar a senha, depois de
# atualizar os arquivos do projeto ou para consertar a instalacao.
# =============================================================================
set -euo pipefail

passo() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()    { printf '    \033[32mOK\033[0m %s\n' "$*"; }
falha() { printf '\n\033[1;31mERRO:\033[0m %s\n' "$*" >&2; exit 1; }

# ----------------------------------------------------------------- conferencias
[ "$(id -u)" = 0 ] || falha "Rode com sudo:  sudo bash deploy/instalar_ec2.sh"

ARCH="$(uname -m)"
[ "$ARCH" = x86_64 ] || falha "Esta maquina e $ARCH. Precisa ser x86_64 (Intel/AMD).
    Os motores do Airbus e do Embraer sao programas Windows de 32 bits (Wine),
    que nao rodam em ARM (AWS Graviton t4g/m7g/c7g, Oracle Ampere A1)."

. /etc/os-release
case "${ID:-}" in
    ubuntu|debian) ;;
    *) falha "Sistema '${PRETTY_NAME:-desconhecido}' nao suportado. Use Ubuntu 22.04/24.04 ou Debian 12
    (no EC2: escolha a imagem 'Ubuntu Server'; o Amazon Linux nao tem o Wine 32 bits)." ;;
esac

DIR="$(cd "$(dirname "$0")/.." && pwd)"                 # pasta fortran
APP="$DIR/scap_py/app.py"
[ -f "$APP" ] || falha "Nao achei $APP. Rode o script de dentro da pasta fortran."
RUN_USER="${SUDO_USER:-}"
if [ -z "$RUN_USER" ] || [ "$RUN_USER" = root ]; then
    RUN_USER="$(stat -c %U "$DIR")"                     # dono da pasta do projeto
fi
[ "$RUN_USER" != root ] || falha "Nao rode o programa como root. Copie o projeto para a pasta de um usuario (ex. /home/ubuntu)."
RUN_HOME="$(getent passwd "$RUN_USER" | cut -d: -f6)"

if [ -z "${PERF_PASSWORD:-}" ] && [ -f /etc/perf.env ]; then
    read -r -p "Manter a senha atual? [S/n] " manter || true
    case "${manter:-s}" in [nN]*) ;; *) PERF_PASSWORD="$(sed -n 's/^PERF_PASSWORD=//p' /etc/perf.env)";; esac
fi
while [ -z "${PERF_PASSWORD:-}" ]; do
    read -r -s -p "Senha que a tela vai pedir: " PERF_PASSWORD; echo
    read -r -s -p "Repita a senha: " confirma; echo
    [ "$PERF_PASSWORD" = "$confirma" ] || { echo "As senhas nao conferem."; PERF_PASSWORD=""; }
done

echo "Projeto: $DIR"
echo "Usuario: $RUN_USER"
echo "Sistema: $PRETTY_NAME ($ARCH)"

# ----------------------------------------------------------------- swap
# Maquinas pequenas (t3.micro/small, 1-2 GB) travam ao instalar o Wine ou ao
# calcular em paralelo sem swap.
passo "Memoria"
MEM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
if [ "$MEM_MB" -lt 3500 ] && ! swapon --show | grep -q .; then
    if [ ! -f /swapfile ]; then
        fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
        chmod 600 /swapfile
        mkswap /swapfile >/dev/null
    fi
    swapon /swapfile
    grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    ok "${MEM_MB} MB de RAM: swap de 2 GB criado"
else
    ok "${MEM_MB} MB de RAM"
fi

# ----------------------------------------------------------------- pacotes
passo "Instalando pacotes do sistema (pode levar alguns minutos)"
export DEBIAN_FRONTEND=noninteractive
dpkg --add-architecture i386
apt-get update -q
apt-get install -y -q \
    ca-certificates curl gzip rsync tmux procps psmisc \
    python3 libgfortran5 \
    wine wine32:i386 wine64 \
    nginx
ok "python3 $(python3 -c 'import platform; print(platform.python_version())')"
ok "$(wine --version 2>/dev/null || echo 'wine instalado')"
ok "nginx $(nginx -v 2>&1 | sed 's/.*\///')"

PY_OK=$(python3 -c 'import sys; print(int(sys.version_info >= (3, 8)))')
[ "$PY_OK" = 1 ] || falha "O Python precisa ser 3.8 ou mais novo."

# ----------------------------------------------------------------- projeto
passo "Preparando os arquivos do projeto"
shopt -s nullglob
for gz in "$DIR"/*.gz; do                 # bases que vieram comprimidas do GitHub
    alvo="${gz%.gz}"
    if [ ! -e "$alvo" ]; then
        gunzip -k "$gz"
        ok "descomprimido $(basename "$alvo")"
    fi
done
shopt -u nullglob
mkdir -p "$DIR/scap_py/work" "$DIR/scap_py/resultados"
chown -R "$RUN_USER": "$DIR"
ok "pastas work/ e resultados/ prontas"

# ----------------------------------------------------------------- wine
passo "Preparando o Wine para o usuario $RUN_USER"
# sem tela e sem baixar Mono/Gecko (os motores nao usam)
sudo -u "$RUN_USER" env HOME="$RUN_HOME" WINEDEBUG=-all \
    WINEDLLOVERRIDES="mscoree,mshtml=" timeout 300 wineboot --init >/dev/null 2>&1 || true
sudo -u "$RUN_USER" env HOME="$RUN_HOME" timeout 120 wineserver --wait >/dev/null 2>&1 || true
[ -d "$RUN_HOME/.wine" ] && ok "prefixo em $RUN_HOME/.wine" || falha "O Wine nao criou $RUN_HOME/.wine"

# ----------------------------------------------------------------- teste dos motores
passo "Testando os motores de calculo (SBKP 15, 25 C)"
systemctl stop perf 2>/dev/null || true            # libera as pastas de trabalho
if ! sudo -u "$RUN_USER" env HOME="$RUN_HOME" WINEDEBUG=-all \
        bash -c "cd '$DIR/scap_py' && timeout 600 python3 -" <<'EOF'
import scap_engine as se
from aircraft import AIRCRAFT
from airports import load_airports, load_toalign, align_values
ap, ta = load_airports(), load_toalign()
rw = ap["SBKP"]["runways"]["15"]
ok = True
for name in ("A320", "E195-E2", "ATR 72-600"):
    ac = next(a for a in AIRCRAFT if a.name == name); v = ac.variants[0]
    try:
        r = se.compute(ac, v, rw, 25, 1, align_values(rw, ac.align, ta))
        print(f"    OK  {name:<11} {r['mtow']} kg ({r['flap']})")
    except Exception as e:
        ok = False
        print(f"    ERRO {name}: {str(e).splitlines()[0]}")
raise SystemExit(0 if ok else 1)
EOF
then
    falha "Algum motor nao calculou (veja acima). Confira se a pasta fortran foi copiada inteira, com as bases (.pdm, .DAT, .BDB)."
fi

# ----------------------------------------------------------------- senha
passo "Guardando a senha em /etc/perf.env (so o root le)"
install -m 600 /dev/null /etc/perf.env
printf 'PERF_PASSWORD=%s\n' "$PERF_PASSWORD" > /etc/perf.env
ok "senha guardada"

# ----------------------------------------------------------------- servico
passo "Criando o servico perf (app.py sempre ligado)"
cat > /etc/systemd/system/perf.service <<EOF
[Unit]
Description=Performance de Decolagem
After=network.target

[Service]
User=$RUN_USER
WorkingDirectory=$DIR/scap_py
Environment=HOME=$RUN_HOME
Environment=PERF_HOST=127.0.0.1
Environment=PERF_PORT=8765
Environment=PERF_SERVER=1
Environment=WINEDEBUG=-all
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/etc/perf.env
ExecStart=/usr/bin/python3 $APP --no-browser
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable perf >/dev/null 2>&1
systemctl restart perf
ok "servico perf ativo"

# ----------------------------------------------------------------- nginx
passo "Configurando o nginx (porta 80 -> app.py)"
cat > /etc/nginx/sites-available/perf <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    client_max_body_size 30m;          # malha enviada pelo navegador

    location / {
        proxy_pass http://127.0.0.1:8765;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 300s;
    }
}
EOF
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/perf /etc/nginx/sites-enabled/perf
nginx -t >/dev/null 2>&1 || { nginx -t; falha "Configuracao do nginx invalida"; }
systemctl enable nginx >/dev/null 2>&1
systemctl restart nginx
ok "nginx na porta 80"

# firewall da propria maquina (se estiver ligado)
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
    ufw allow 80/tcp >/dev/null && ok "porta 80 liberada no ufw"
fi

# ----------------------------------------------------------------- conferencia final
passo "Conferindo"
for _ in $(seq 1 20); do
    curl -fs -o /dev/null http://127.0.0.1/ && break
    sleep 1
done
curl -fs -o /dev/null http://127.0.0.1/ || falha "O programa nao respondeu. Veja: sudo journalctl -u perf -n 50"
CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/api/meta)
[ "$CODE" = 401 ] && ok "a tela abre e a API pede senha" || falha "A API respondeu $CODE (esperado 401 sem senha)"

TOKEN=$(curl -fs -m 2 -X PUT http://169.254.169.254/latest/api/token \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || true)
HOST=$(curl -fs -m 2 -H "X-aws-ec2-metadata-token: $TOKEN" \
       http://169.254.169.254/latest/meta-data/public-hostname 2>/dev/null || true)
[ -n "$HOST" ] || HOST=$(curl -fs -m 3 https://checkip.amazonaws.com 2>/dev/null || echo "<endereco-do-servidor>")

cat <<EOF

=============================================================================
 Pronto! Abra no navegador:   http://$HOST/
=============================================================================
 - Libere a porta 80 (HTTP) no Security Group do EC2, se ainda nao liberou.
 - Ver se esta rodando:        sudo systemctl status perf
 - Ver erros:                  sudo journalctl -u perf -n 50
 - Depois de atualizar:        sudo systemctl restart perf
 - Trocar a senha:             sudo bash deploy/instalar_ec2.sh
EOF

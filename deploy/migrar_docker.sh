#!/usr/bin/env bash
# =============================================================================
# Passa o servidor para Docker (uma vez so). Depois disso, cada push na master
# atualiza o servidor sozinho pelo GitHub Actions (deploy/atualizar.sh).
#
# Uso, no EC2, com o repositorio ja clonado em ~/fortran:
#     sudo bash deploy/migrar_docker.sh
#
# O que faz:
#   - swap de 2 GB em maquinas pequenas (o build da imagem usa memoria)
#   - instala o Docker (se faltar) e poe o usuario no grupo docker
#   - desliga a instalacao antiga sem Docker (servico perf e nginx), que
#     ocupava a porta 80
#   - cria o .env com a senha (reaproveita a de /etc/perf.env, se existir)
#   - sobe o programa (docker compose up -d --build)
#   - copia os CSVs antigos de ~/fortran_antigo/scap_py/resultados, se houver
# Pode rodar de novo sem problema.
# =============================================================================
set -euo pipefail

passo() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()    { printf '    \033[32mOK\033[0m %s\n' "$*"; }
falha() { printf '\n\033[1;31mERRO:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || falha "Rode com sudo:  sudo bash deploy/migrar_docker.sh"
[ "$(uname -m)" = x86_64 ] || falha "A maquina precisa ser x86_64 (Wine 32 bits nao roda em ARM)."

DIR="$(cd "$(dirname "$0")/.." && pwd)"
[ -d "$DIR/.git" ] || falha "$DIR nao e um clone do Git. Clone antes:
    git clone https://github.com/lfcr9311/copetti_perf.git ~/fortran"
RUN_USER="${SUDO_USER:-$(stat -c %U "$DIR")}"
[ "$RUN_USER" != root ] || falha "Clone o projeto na pasta de um usuario (ex. /home/ubuntu), nao do root."
RUN_HOME="$(getent passwd "$RUN_USER" | cut -d: -f6)"
echo "Projeto: $DIR"
echo "Usuario: $RUN_USER"

# ----------------------------------------------------------------- swap
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

# ----------------------------------------------------------------- docker
passo "Docker"
if ! command -v docker >/dev/null || ! docker compose version >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker >/dev/null 2>&1
usermod -aG docker "$RUN_USER"
ok "$(docker --version)"
ok "$RUN_USER no grupo docker (vale a partir do proximo login SSH)"

# ----------------------------------------------------------------- instalacao antiga
passo "Desligando a instalacao antiga (sem Docker)"
for svc in perf nginx; do
    if systemctl cat "$svc" >/dev/null 2>&1; then
        systemctl disable --now "$svc" >/dev/null 2>&1 || true
        ok "servico $svc parado e desligado"
    fi
done

# ----------------------------------------------------------------- .env
passo "Configuracao (.env)"
if [ -f "$DIR/.env" ]; then
    ok ".env ja existe (mantido)"
else
    PERF_PASSWORD="${PERF_PASSWORD:-}"
    if [ -z "$PERF_PASSWORD" ] && [ -f /etc/perf.env ]; then
        PERF_PASSWORD="$(sed -n 's/^PERF_PASSWORD=//p' /etc/perf.env)"
        [ -n "$PERF_PASSWORD" ] && ok "senha reaproveitada de /etc/perf.env"
    fi
    while [ -z "$PERF_PASSWORD" ]; do
        read -r -s -p "Senha que a tela vai pedir: " PERF_PASSWORD; echo
        read -r -s -p "Repita a senha: " confirma; echo
        [ "$PERF_PASSWORD" = "$confirma" ] || { echo "As senhas nao conferem."; PERF_PASSWORD=""; }
    done
    install -m 600 -o "$RUN_USER" -g "$RUN_USER" /dev/null "$DIR/.env"
    printf 'PERF_PASSWORD=%s\nPERF_DOMAIN=\nPERF_WORKERS=\n' "$PERF_PASSWORD" > "$DIR/.env"
    ok ".env criado (para HTTPS com dominio, preencha PERF_DOMAIN depois)"
fi

# ----------------------------------------------------------------- subir
passo "Construindo a imagem e subindo (a primeira vez leva alguns minutos)"
cd "$DIR"
docker compose up -d --build --remove-orphans
chown -R "$RUN_USER": "$DIR"
ok "containers no ar"

# ----------------------------------------------------------------- resultados antigos
ANTIGOS="$RUN_HOME/fortran_antigo/scap_py/resultados"
if [ -d "$ANTIGOS" ] && [ -n "$(ls -A "$ANTIGOS" 2>/dev/null)" ]; then
    passo "Copiando os resultados antigos para o volume do Docker"
    docker compose cp "$ANTIGOS/." perf:/app/scap_py/resultados/
    docker compose exec -T -u root perf chown -R perf:perf /app/scap_py/resultados
    ok "$(ls "$ANTIGOS" | wc -l) arquivo(s) de $ANTIGOS"
fi

# ----------------------------------------------------------------- conferencia
passo "Conferindo"
for _ in $(seq 1 60); do
    code=$(docker compose exec -T perf python3 -c '
import urllib.request, urllib.error
try:
    print(urllib.request.urlopen("http://127.0.0.1:8765/api/meta", timeout=5).status)
except urllib.error.HTTPError as e:
    print(e.code)
except Exception:
    print(0)' 2>/dev/null || echo 0)
    case "$code" in 200|401) break ;; esac
    sleep 2
done
case "$code" in
    200|401) ok "o programa respondeu (HTTP $code)" ;;
    *) docker compose logs --tail 40 perf; falha "O programa nao respondeu" ;;
esac

cat <<EOF

=============================================================================
 Pronto! O programa esta no Docker, na porta 80.
=============================================================================
 - Ver os containers:     docker compose ps        (na pasta $DIR)
 - Ver o log:             docker compose logs -f perf
 - Atualizar a mao:       bash deploy/atualizar.sh
 - Deploy automatico:     configure os secrets no GitHub (scap_py/DOCKER.md)
EOF

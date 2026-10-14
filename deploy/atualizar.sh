#!/usr/bin/env bash
# =============================================================================
# Atualiza o servidor com o que esta no GitHub e reinicia o container.
#
# Chamado pelo GitHub Actions (.github/workflows/deploy.yml) a cada push na
# master. Tambem pode rodar a mao, no servidor:
#     bash ~/fortran/deploy/atualizar.sh
#
# O .env (senha) nao esta no Git e nao e mexido. Os CSVs gerados ficam no
# volume "resultados" do Docker e continuam la.
# =============================================================================
# Tudo dentro de { }: o bash le o script inteiro antes de rodar, porque o
# git reset abaixo pode trocar este proprio arquivo no meio da execucao.
{
set -euo pipefail

passo() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
falha() { printf '\n\033[1;31mERRO:\033[0m %s\n' "$*" >&2; exit 1; }

DIR="$(cd "$(dirname "$0")/.." && pwd)"
BRANCH="${DEPLOY_BRANCH:-master}"
cd "$DIR"
[ -f .env ] || falha "Falta o $DIR/.env (senha). Rode antes: sudo bash deploy/migrar_docker.sh"

passo "Baixando a $BRANCH do GitHub"
git fetch --quiet origin "$BRANCH"
git reset --quiet --hard "origin/$BRANCH"
git log -1 --format='    commit %h: %s (%an, %ar)'

passo "Reconstruindo e reiniciando o container"
docker compose up -d --build --remove-orphans
docker image prune -f >/dev/null

passo "Conferindo se o programa responde"
for _ in $(seq 1 60); do
    # dentro do container: com senha a API responde 401, sem senha 200
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
    200|401) printf '    \033[32mOK\033[0m o programa respondeu (HTTP %s)\n' "$code" ;;
    *) docker compose logs --tail 40 perf; falha "O programa nao respondeu depois do deploy" ;;
esac
exit 0
}

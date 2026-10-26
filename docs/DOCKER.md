# Colocar no servidor

## Sem Docker: EC2 com nginx (o jeito mais simples)

No EC2 (Ubuntu, x86), de dentro da pasta `fortran`:

```bash
sudo PERF_PASSWORD='sua-senha' bash deploy/instalar_ec2.sh
```

O script instala Wine, Python e nginx, cria o serviço `perf` (o `server.py` fica sempre
ligado e sobe junto com a máquina) e coloca o nginx na porta 80. Libere a porta 80
no Security Group e abra `http://<endereço do EC2>/`.

| Para… | Comando |
|---|---|
| Ver se está rodando | `sudo systemctl status perf` |
| Ver erros | `sudo journalctl -u perf -n 50` |
| Reiniciar depois de atualizar os arquivos | `sudo systemctl restart perf` |
| Trocar a senha | rode o script de novo com a senha nova |

## Com Docker

O programa inteiro (tela + cálculo) roda num container Docker numa máquina Linux
(AWS, Oracle Cloud ou servidor da empresa). Na frente dele vai o **Caddy**, que
cuida do HTTPS sozinho quando você tem um domínio.

Os arquivos ficam na pasta `fortran/`:

| Arquivo | O que é |
|---|---|
| `Dockerfile` | A imagem: Debian + Wine 32 bits + Python + o programa e as bases |
| `docker-compose.yml` | Sobe o programa e o Caddy juntos |
| `.env.example` | Modelo das configurações (senha, domínio) |
| `.dockerignore` | O que fica fora da imagem (Git, Visual Studio, temporários) |

---

## 1. A máquina

- **Processador x86 (Intel ou AMD). ARM não serve.** O Airbus e o Embraer são
  programas Windows de 32 bits rodando pelo Wine, que só funciona em x86, e o
  motor do ATR também é x86.
  - **Oracle Cloud:** escolha um shape **AMD** (`VM.Standard.E4.Flex` ou
    `E5.Flex`). O **Ampere A1** (ARM, o do plano grátis) **não funciona**.
  - **AWS:** use `t3`, `m6i`, `c6i`… **Não** use `t4g`, `m7g`, `c7g` (Graviton, ARM).
- **Tamanho:** pelo menos **2 vCPU, 4 GB de RAM e 30 GB de disco**. Mais vCPU =
  mais cálculos ao mesmo tempo (o programa usa metade dos núcleos; dá para mudar
  com `PERF_WORKERS`).
- **Sistema:** Ubuntu 22.04/24.04 ou Debian 12.
- **Portas abertas na nuvem:** 80 e 443 (TCP), além da 22 (SSH).
  - **AWS:** *Security Group* da instância → *Inbound rules*.
  - **Oracle:** *Security List* da VCN → *Ingress rules*. A imagem Ubuntu da Oracle
    também bloqueia no firewall da própria máquina; libere com:
    ```bash
    sudo iptables -I INPUT 6 -p tcp --dport 80 -j ACCEPT
    sudo iptables -I INPUT 6 -p tcp --dport 443 -j ACCEPT
    sudo netfilter-persistent save
    ```

## 2. Instalar o Docker na máquina

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER     # depois saia e entre de novo no SSH
```

## 3. Levar o programa para a máquina

Pelo Git (com as bases grandes comprimidas em `.pdm.gz`, que o Docker
descomprime sozinho):

```bash
git clone https://github.com/lfcr9311/copetti_perf.git fortran
cd fortran
```

Ou copiando a pasta `fortran` inteira do seu computador:

```bash
scp -r ~/Documents/Azul/fortran usuario@IP-DO-SERVIDOR:~/
```

## 4. Configurar

```bash
cp .env.example .env
nano .env
```

- `PERF_PASSWORD`: a senha que a tela vai pedir. **Obrigatória.**
- `PERF_DOMAIN`: o domínio que aponta para o IP do servidor (por exemplo,
  `perf.suaempresa.com`). Com ele, o Caddy ativa o **HTTPS** sozinho. Sem domínio,
  deixe vazio e o acesso fica em `http://IP-DO-SERVIDOR`.
  Um domínio grátis serve: crie um em duckdns.org apontando para o IP.

O `.env` tem a senha: **não coloque no Git** (ponha `.env` no `.gitignore`).

## 5. Subir

```bash
docker compose up -d --build
```

Na primeira vez demora alguns minutos (baixa o Wine). Depois abra no navegador:

- com domínio: `https://perf.suaempresa.com`
- sem domínio: `http://IP-DO-SERVIDOR`

A tela pede a senha uma vez e lembra dela naquele navegador.

## O que muda em relação ao computador

- **Malha:** em vez de digitar o caminho, você **escolhe o arquivo** `.csv` do seu
  computador. No fim aparece o botão **Baixar malha calculada**. A sua malha
  original não é alterada.
- **Um cálculo por vez:** se duas pessoas calcularem ao mesmo tempo, a segunda
  recebe "Já existe um cálculo em andamento" e tenta de novo depois.
- Os CSVs gerados ficam no volume `resultados` do Docker e continuam lá mesmo
  depois de atualizar o programa.

## Dia a dia

| Para… | Comando (na pasta `fortran`) |
|---|---|
| Ver se está rodando | `docker compose ps` |
| Ver o que o programa escreveu | `docker compose logs -f perf` |
| Atualizar depois de um `git pull` | `docker compose up -d --build` |
| Parar | `docker compose down` |
| Trocar a senha | edite o `.env` e rode `docker compose up -d` |

## Deploy automático pelo GitHub

A cada `git push` na `master`, o GitHub Actions (`.github/workflows/deploy.yml`)
entra no EC2 por SSH e roda `deploy/atualizar.sh`: baixa o commit novo, reconstrói
a imagem e reinicia o container. O resultado aparece na aba **Actions** do GitHub.

### Uma vez no EC2: passar para Docker

```bash
mv ~/fortran ~/fortran_antigo          # se existir a instalação antiga
git clone https://github.com/lfcr9311/copetti_perf.git ~/fortran
cd ~/fortran
sudo bash deploy/migrar_docker.sh
```

O script instala o Docker, desliga o serviço `perf` e o nginx antigos (liberam a
porta 80), cria o `.env` (reaproveita a senha de `/etc/perf.env`), sobe o programa
e copia os CSVs de `~/fortran_antigo/scap_py/resultados` para o volume do Docker.

### Uma vez no seu computador: chave do GitHub

Uma chave só para o deploy (não use a `.pem` da AWS):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/gh_deploy_perf -N "" -C github-actions-deploy
```

Coloque a chave pública no EC2. A linha abaixo já **limita a chave a rodar só o
deploy** (ela não abre um terminal no servidor):

```bash
echo "command=\"bash ~/fortran/deploy/atualizar.sh\",no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty $(cat ~/.ssh/gh_deploy_perf.pub)" \
  | ssh -i ~/CHAVE.pem ubuntu@IP-DO-EC2 'cat >> ~/.ssh/authorized_keys'
```

### Uma vez no GitHub: secrets

Em **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Valor |
|---|---|
| `EC2_HOST` | IP ou endereço público do EC2 |
| `EC2_USER` | `ubuntu` |
| `EC2_SSH_KEY` | conteúdo de `~/.ssh/gh_deploy_perf` (a chave **privada**, inteira) |
| `EC2_KNOWN_HOSTS` | saída de `ssh-keyscan -t ed25519 IP-DO-EC2` |

Com o `gh` instalado, dá para fazer pelo terminal:

```bash
R=lfcr9311/copetti_perf
gh secret set EC2_HOST -R $R -b "IP-DO-EC2"
gh secret set EC2_USER -R $R -b "ubuntu"
gh secret set EC2_SSH_KEY -R $R < ~/.ssh/gh_deploy_perf
ssh-keyscan -t ed25519 IP-DO-EC2 | gh secret set EC2_KNOWN_HOSTS -R $R
```

### Na AWS

- O **Security Group** precisa aceitar a porta **22** de qualquer IP (os IPs do
  GitHub mudam). A chave acima só consegue rodar o deploy.
- Use um **Elastic IP**: sem ele, o IP muda quando a instância é parada e o
  `EC2_HOST` / `EC2_KNOWN_HOSTS` deixam de valer.

### Testar

Aba **Actions → Deploy no EC2 → Run workflow**, ou faça um push na `master`.
No servidor, o mesmo deploy roda à mão com `bash ~/fortran/deploy/atualizar.sh`.

## Sem Docker / outras opções

- **Tela em outro lugar (ex. Vercel):** publique só a pasta `app/web`. No
  arquivo `web/config.js`, coloque o endereço do servidor
  (`window.PERF_API = "https://perf.suaempresa.com"`). No `.env` do servidor, defina
  `PERF_CORS_ORIGIN=https://seu-site.vercel.app`. O servidor **precisa de HTTPS**
  (domínio no Caddy); senão o navegador bloqueia a chamada.
- **Variáveis do `server.py`** (para rodar fora do Docker): `PERF_HOST`, `PERF_PORT`,
  `PERF_PASSWORD`, `PERF_SERVER=1` (Malha por upload), `PERF_CORS_ORIGIN`,
  `PERF_WORKERS`.

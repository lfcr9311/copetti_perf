# Colocar no servidor

## Sem Docker: EC2 com nginx (o jeito mais simples)

No EC2 (Ubuntu, x86), de dentro da pasta `fortran`:

```bash
sudo PERF_PASSWORD='sua-senha' bash deploy/instalar_ec2.sh
```

O script instala Wine, Python e nginx, cria o serviço `perf` (o `app.py` fica sempre
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

## Sem Docker / outras opções

- **Tela em outro lugar (ex. Vercel):** publique só a pasta `scap_py/web`. No
  arquivo `web/config.js`, coloque o endereço do servidor
  (`window.PERF_API = "https://perf.suaempresa.com"`). No `.env` do servidor, defina
  `PERF_CORS_ORIGIN=https://seu-site.vercel.app`. O servidor **precisa de HTTPS**
  (domínio no Caddy); senão o navegador bloqueia a chamada.
- **Variáveis do `app.py`** (para rodar fora do Docker): `PERF_HOST`, `PERF_PORT`,
  `PERF_PASSWORD`, `PERF_SERVER=1` (Malha por upload), `PERF_CORS_ORIGIN`,
  `PERF_WORKERS`.

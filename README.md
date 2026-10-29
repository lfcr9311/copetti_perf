# Performance de Decolagem e Pouso

> **Só quer usar o programa?** Veja o [LEIA-ME.md](docs/LEIA-ME.md), um guia passo a passo sem termos técnicos.
> **Servidor (AWS, Oracle…):** veja o [DOCKER.md](docs/DOCKER.md).

Calcula o peso máximo de decolagem (MTOW) por pista para a frota e o peso
máximo de pouso de despacho, usando os motores de cálculo originais dos fabricantes:

| Aeronave | Motor | Como roda |
|---|---|---|
| A320, A321neo, A321F, A330 (RR Trent 772B), A330neo (Trent 7000 Step 3) | `scap_octopus.dll` (Airbus SCAP) | Wine (Linux) / Python 32 bits (Windows) |
| ATR 72-600 (PW127M) | TTAM (`TTAM.dll`) pelo `SCAPApp.exe` oficial da ATR | Wine + Mono; precisa de `License`/`LicenseKey` |
| E190, E195, E195-E2 | `takeoff_module.exe` (ETM170 / ETME2) | Wine; não informa V1/VR/V2 |

Pouso (despacho): Airbus pelo `scap_octopus.dll`, E195 e E195-E2 pelas DLLs ELM170/ELME2
(carregador `engines/loader/scaploader.exe`, Wine) e ATR pelo `SCAPApp.exe` oficial da ATR
(`engines/atr/SCAP_APS_2.7.1`, Wine + Mono; precisa dos arquivos `License`/`LicenseKey`,
que **não** vão para o Git).

## Dependências (máquina nova)

Ubuntu/Debian x86_64. Tudo de uma vez, de dentro da pasta `fortran`:

```bash
sudo bash deploy/instalar_dependencias.sh
```

| Pacote | Para quê |
|---|---|
| `wine`, `wine32:i386`, `wine64` | `scap_octopus.dll` (Airbus), `takeoff_module.exe` e as DLLs da Embraer (Windows 32 bits) |
| `python3` | o app (só biblioteca padrão) |
| `gcc-mingw-w64-i686` | compila `engines/loader/scaploader.exe`, o carregador em C das DLLs da Embraer (`engines/loader/build.sh`). O `.exe` já vem no Git; o compilador só é preciso para recompilar |

## Abrir o app

```bash
cd app
python3 server.py
```

Abre `http://127.0.0.1:8765` no navegador. Só usa a biblioteca padrão do
Python; tudo roda na própria máquina (o servidor só aceita conexões locais).
`Ctrl+C` encerra.

### Cálculo
1. **Aeronaves:** clique em um ou mais motores (pode misturar modelos: A320 + ATR + E2...).
2. **Pistas:** busque o aeroporto (ICAO, IATA ou nome) e clique nas pistas, ou em
   **Todas**. Dá para trocar de aeroporto e continuar somando pistas; as escolhidas
   ficam em **Selecionadas** (× tira uma).
   O **✎** de cada pista abre a edição de RWYD 1, 3, 4, 5, 6, 8 e 11 (elevação,
   TORA, ASDA, TODA, slope, superfície, largura) para aquele cálculo; os obstáculos
   ficam os do cadastro. O front manda `override` em `/api/calc` (`runways:
   [{icao, rwy, override}]`) e a pista sai como "ICAO RWY (editada)".
3. **Condições:** temperatura, vento (relativo à pista: proa, cauda ou través) e QNH
   podem ser **um valor** ou uma **faixa**; embaixo de cada faixa aparecem os valores
   que serão calculados.

**Flap:** ótimo por padrão (o motor escolhe o de maior MTOW) ou fixo por modelo.
No cálculo dá para pedir vários (`flaps: {nome: [null, código, …]}` em `/api/calc`;
`null` = ótimo): cada flap vira uma "aeronave" própria nos resultados
(`"A320 LEAP-1A26 · Normal · CONF 2"`) e o CSV ganha `flap_sel`. Na Malha é um só
(`flaps: {nome: código}` em `/api/malha`). Airbus: `CONF 1 = 1` e
`CONF 2` = código da configuração (1810 = CONF 1+F etc., ver `FLAP_NAMES`); Embraer:
`CONF(3)` = 1 a 4 (5 = ótimo); ATR: só FLAP 15 na base (`flap_options` em `perf/catalog/aircraft.py`).

**Limite de CG** (POPT 30): Standard e as alternativas que a base aceita (A320:
Extended FWD; A330neo: Alternate…; A321neo só o Standard, como a frota). **MTOW
estrutural** (POPT 24): botões **Base** (o de cada motor: A320 LEAP-1A26 Normal 79.000,
Sharp 77.000 kg…) ou os pesos da frota em `Aircraft.mtows` (A320: 77.000 / 79.000),
valendo para os motores marcados daquele modelo (`mtow: {nome: kg}` em `/api/calc`;
o CSV ganha `mtow_sel`).

Várias pessoas podem calcular ao mesmo tempo no servidor: cada cálculo pega a sua
pasta de trabalho (`perf.takeoff.engine.work_slot`) e todos dividem os mesmos
`PERF_WORKERS` motores em paralelo.

São calculadas todas as combinações aeronave × pista × temperatura × vento × QNH
(o botão mostra o total antes de calcular). Com um cálculo só, o resultado mostra
MTOW, flap, limitante e V1/VR/V2. Com vários:

- **Cartões** – um por aeronave (maior e menor MTOW, com as condições do menor).
- **Resumo** – matriz aeronave × pista: maior MTOW de cada uma e o menor da faixa;
  a cor é a % do maior MTOW da própria aeronave e o contorno marca a melhor pista.
- **Gráfico** – MTOW no eixo Y; você escolhe o eixo X (temperatura, vento ou QNH),
  o que vira linhas (pista, aeronave, vento ou QNH) e o valor fixo do resto.
- **Tabela RTOW** – temperatura × vento para a aeronave, pista e QNH escolhidos;
  cada célula traz MTOW / limitante e V1/VR/V2, com a cor indicando o peso.
- **Lista** – todos os cálculos, ordenável.

Tudo vai para um CSV só em `app/results/` (botão **Baixar CSV**). Erros do motor (por
exemplo "No optimal weight is found" numa interseção curta com vento de cauda)
aparecem como "erro", com a mensagem no tooltip e na lista.

### Pouso
Aba **Pouso** (despacho, um cálculo por vez): peso máximo de pouso, limitante,
distância sobre a LDA e o peso por critério.

- **LDA:** o cadastro de pistas não tem LDA; o campo vem com a TORA e é editável.
- **Superfície:** a do `airports_list.csv` (grooved/PFC só onde está cadastrado);
  não dá para escolher. Nas bases Airbus sem grooved no pouso (A321F, A330, A330neo)
  vai como normal.
- **Airbus:** CONF FULL ou 3 (códigos de cada base em `CONF_POUSO`), A/THR off
  (padrão, VREF) ou on (VREF + 5 kt), envelope de CG (POPTL 12): A320 Standard ou
  Extended FWD; A330neo Standard/Alternate/2nd/3rd (mesmo resultado na base).
  Quando a LDA é curta demais para a base ("No possible weight"), a tela explica.

### Pista bloqueada
Aba **Pista bloqueada**: simula um bloqueio (buraco, aeronave parada) em um ponto da
pista e varre a posição dele de **De** até **Até**, a cada **Passo** (metros a partir
da primeira cabeceira da pista física, ex. 15 em 15/33). Para cada posição, as **duas
cabeceiras** usam só o trecho **antes** do bloqueio, menos a **Margem**:
TORA/ASDA/TODA e LDA = distância até o bloqueio − margem. Com **Altura** > 0 o bloqueio
entra como obstáculo na decolagem. Condições (temperatura, vento, QNH) em valor ou
faixa, como na decolagem. Resultado: por cabeceira, gráfico e tabela de MTOW e peso
máximo de pouso por posição, e o CSV em `app/results/` (`perf/blocked.py`).
Decolagem com flap ótimo, CG Standard e MTOW da base; pouso com FULL, A/THR off e
MLW certificado (`perf/landing/dispatch.py`).

### Malha
Aba **Malha**: lê a `data/Malha.csv` (aeroporto de partida na coluna C,
equipamento na coluna Eqp), calcula todas as pistas de cada aeroporto em todas
as combinações de condições e grava o maior MTOW em colunas novas no fim da
própria malha (cópia do original em `Malha.csv.bak`).

Alerta: também acha o **pior caso** (a combinação em que a melhor pista dá o menor
MTOW; olha só a temperatura mais quente de cada vento/QNH, já que o MTOW cai com a
temperatura) e compara com um peso de referência por aeronave (padrão: estrutural):
OK = o pior caso atende; ATENCAO = só parte das condições, com a temperatura limite
(busca binária nas temperaturas); RESTRITO = nem o melhor caso atende. Colunas novas:
`MTOW Pior Caso (kg)`, `Pior Caso`, `Peso Ref (kg)`, `Margem (kg)`,
`Temp Limite (C)`, `Alerta`.

## Linha de comando

De dentro de `app/`:

```bash
python3 -m perf.batch --aircraft A320 --airports SBKP --wind=-10:20:5 --qnh 990:1030:10
python3 -m perf.schedule --wind=-5,0,5
python3 -m perf.schedule --tmin 15 --tmax 40 --step 5 --ref E195-E2=61000 --ref A320=77000
python3 -m perf.landing.airbus --icao SBKP --rwy 15 --molhada      # pouso (também .embraer, .atr)
```

`--wind` e `--qnh` aceitam um valor, uma lista (`-5,0,5`) ou uma faixa
`início:fim:passo`. Com valor negativo, use `=` (`--wind=-10:20:5`).

## Arquivos

```
app/                      o programa
  server.py               servidor web + API (python3 server.py)
  desktop.py              interface antiga em Tk (mantida, não recebe novidades)
  web/, assets/           página (HTML/JS/CSS) e imagens
  perf/                   cálculo
    paths.py              único lugar com os caminhos (engines/, databases/, data/...)
    catalog/              aircraft.py (aeronaves, motores, bases) e airports.py (pistas, obstáculos, alinhamento)
    takeoff/              engine.py (escolhe o motor, cálculo em paralelo), airbus.py, embraer.py, atr.py
      templates/          scap.in base de cada motor Airbus
    landing/              pouso de despacho: airbus.py, embraer.py, atr.py
    batch.py, schedule.py cálculo em massa e malha (também pela linha de comando)
  tests/                  regression.py + golden.json (casos conferidos com o EFB)
  work/, results/         pastas de trabalho e CSVs gerados (fora do Git)
engines/                  motores dos fabricantes
  airbus/                 scap_octopus.dll, octocnf, errors.cnf, limits.cnf, config/
  embraer/                takeoff_module.exe, ETM170, ETME2, ELM170 (pouso), TRACE_TO.AFM
  atr/                    SCAP_APS_2.7.1/ (SCAPApp, TTAM/TLAM e base MUE6DC3E; licença fora do Git)
  common/                 DFORRT.DLL, msvcr120.dll (runtime das DLLs Windows)
  loader/                 scaploader.c/.exe (carregador das DLLs de pouso da Embraer) e build.sh
databases/                bases de desempenho: airbus/ (.pre e sem extensão), embraer/ (.DAT, .pdm), atr/ (.pdf)
data/                     airports_list.csv, toalign_list.csv, iata_icao.csv, airplanes_*.csv, Malha.csv
legacy/                   fonte Fortran original (takeoff_module, INPUT.FOR, OCTOPUS.FOR, ttam.f...) e projeto do Visual Studio
docs/                     LEIA-ME.md, DOCKER.md, limitation.lis (códigos de limitação)
  manuals/                manuais dos fabricantes (scap.in/IATA, ETM170, ELM170, ELME2, TLAM/TTAM); só local, fora do Git
deploy/                   scripts de instalação/atualização do servidor
```

Motores e bases são achados pelo nome (sem diferenciar maiúsculas) em qualquer
subpasta de `engines/` e `databases/` (`perf/paths.py`, `find_file`). Base nova:
coloque na pasta do fabricante e cadastre em `perf/catalog/aircraft.py`. As bases
grandes vão comprimidas (`.pdm.gz`) e são descomprimidas no primeiro uso.

**Regressão:** antes de subir mudança de cálculo, rode `python3 tests/regression.py`
(de dentro de `app/`, ~10 min). Ele sobe o servidor e compara os casos de decolagem e
pouso com `tests/golden.json`; só grave de novo (`--record`) se a mudança de resultado
for intencional.

Vento e QNH seguem a convenção do SCAP: `XMET(2)` positivo = proa, negativo =
cauda; `XMET(3)` positivo = través da direita (só o Airbus usa); `XMET(5)` = QNH.

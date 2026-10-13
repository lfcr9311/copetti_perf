# Performance de Decolagem (scap_py)

> **Só quer usar o programa?** Veja o [LEIA-ME.md](LEIA-ME.md), um guia passo a passo sem termos técnicos.
> **Servidor (AWS, Oracle…):** veja o [DOCKER.md](DOCKER.md).

Calcula o peso máximo de decolagem (MTOW) por pista para a frota, usando os
motores de cálculo originais:

| Aeronave | Motor | Como roda |
|---|---|---|
| A320, A321neo, A321F, A330 (RR Trent 772B), A330neo (Trent 7000 Step 3) | `scap_octopus.dll` (Airbus SCAP) | Wine (Linux) / Python 32 bits (Windows) |
| ATR 72-600 | TTAM (`engines/DllWrapperATR.so`) | direto no Linux, sem Wine |
| E190, E195, E195-E2 | `takeoff_module.exe` (ETM170 / ETME2) | Wine; não informa V1/VR/V2 |

## Abrir o app

```bash
cd scap_py
python3 app.py
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
`CONF(3)` = 1 a 4 (5 = ótimo); ATR: só FLAP 15 na base (`flap_options` em `aircraft.py`).

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

Tudo vai para um CSV só em `resultados/` (botão **Baixar CSV**). Erros do motor (por
exemplo "No optimal weight is found" numa interseção curta com vento de cauda)
aparecem como "erro", com a mensagem no tooltip e na lista.

### Malha
Aba **Malha**: lê a `Malha.csv` (aeroporto de partida na coluna C,
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

```bash
python3 batch.py --aircraft A320 --airports SBKP --wind=-10:20:5 --qnh 990:1030:10
python3 malha.py --wind=-5,0,5
python3 malha.py --tmin 15 --tmax 40 --step 5 --ref E195-E2=61000 --ref A320=77000
```

`--wind` e `--qnh` aceitam um valor, uma lista (`-5,0,5`) ou uma faixa
`início:fim:passo`. Com valor negativo, use `=` (`--wind=-10:20:5`).

## Arquivos

| Arquivo | O que é |
|---|---|
| `app.py`, `web/` | app web (servidor local + página) |
| `scap_engine.py` | cálculo: Airbus (scap.in/SCAP.OUT) e despacho para ATR/Embraer |
| `atr_engine.py`, `tm_engine.py` | ATR (TTAM .so) e Embraer (takeoff_module.exe) |
| `aircraft.py` | aeronaves, motores e bases de dados |
| `airports.py` | pistas e obstáculos (`../airports_list.csv`), alinhamento (`../toalign_list.csv`) |
| `batch.py`, `malha.py` | cálculo em massa e malha pela linha de comando |
| `examples/` | `scap.in` base de cada motor Airbus |
| `iata_icao.csv` | IATA → ICAO (gerado a partir do OurAirports; pode ser editado) |
| `frontend.py` | interface antiga em Tk (mantida, não recebe mais novidades) |

Vento e QNH seguem a convenção do SCAP: `XMET(2)` positivo = proa, negativo =
cauda; `XMET(3)` positivo = través da direita (só o Airbus usa); `XMET(5)` = QNH.

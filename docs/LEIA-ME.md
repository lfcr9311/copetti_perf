# Performance de Decolagem — guia de uso

Este programa calcula o **peso máximo de decolagem (MTOW)** de uma aeronave numa pista,
para a temperatura, o vento e o QNH que você escolher. Ele mostra também o **flap**, o que
**limitou** o peso (pista, obstáculo, subida…) e, quando o motor informa, as velocidades
**V1, VR e V2**.

Você **não precisa saber programar**. Basta seguir os passos abaixo.

---

## 1. Abrir o programa

O programa funciona dentro do navegador (Firefox), mas roda **no seu próprio computador**.
Para abri-lo, você digita um comando curto numa janela chamada **Terminal**.

1. Abra o Terminal: aperte as teclas **Ctrl + Alt + T** ao mesmo tempo.
   Vai abrir uma janela com fundo escuro, onde dá para digitar.

2. Copie a linha abaixo, cole no Terminal (botão direito do mouse → **Colar**, ou
   **Ctrl + Shift + V**) e aperte **Enter**:

   ```
   cd ~/Documents/Azul/fortran/app && python3 server.py
   ```

3. Em um ou dois segundos o **Firefox abre sozinho** com o programa.
   No Terminal aparece uma frase parecida com esta:

   ```
   Performance de Decolagem em http://127.0.0.1:8765/  (Ctrl+C para sair)
   ```

   Se o navegador **não** abrir, abra o Firefox você mesmo e digite na barra de endereço:
   **127.0.0.1:8765** e aperte Enter.

> **Importante:** deixe a janela do Terminal **aberta** enquanto estiver usando o programa.
> Pode minimizá-la, mas não feche. Se fechar, o programa para de funcionar.

### No Windows

O programa precisa da pasta **`fortran` inteira** (com os arquivos de dados das
aeronaves e a subpasta `app`). Copie a pasta toda, não só o `app`.

1. Instale o **Python** (python.org → Downloads). Na instalação, marque a opção
   **"Add python.exe to PATH"**.
2. Abra a pasta `fortran\app` no Explorador de Arquivos, clique na **barra de
   endereço** lá em cima, apague o que estiver escrito, digite **cmd** e aperte **Enter**.
   Abre uma janela preta (o "Prompt de Comando") já nessa pasta.
3. Digite o comando abaixo e aperte **Enter**:

   ```
   python server.py
   ```

O resto funciona igual. No Windows, o **ATR 72-600 não está disponível** (o motor de
cálculo dele só existe para Linux); Airbus, E195 e E195-E2 funcionam.

---

## 2. Fazer um cálculo

A tela tem duas partes: à **esquerda** você escolhe o que quer calcular; à **direita**
aparece o resultado.

### Passo 1 — Escolha a aeronave

Na seção **Aeronaves**, cada linha é um modelo (A320, ATR 72-600, E195-E2…) e os
botões ao lado são os motores.

- **Clique em um motor** para marcar (ele fica azul). Clique de novo para desmarcar.
- **Clique no nome do modelo** (por exemplo, "A320") para marcar todos os motores dele
  de uma vez. Clicando de novo, desmarca todos.
- Pode marcar **várias aeronaves**, inclusive de modelos diferentes.
- **Limpar** desmarca tudo.

### Passo 2 — Escolha as pistas

Na seção **Pistas**:

1. Na caixa de busca, digite o aeroporto: pode ser o código de 4 letras (**SBKP**), o de
   3 letras (**VCP**) ou parte do nome (**Viracopos**). Escolha o aeroporto na lista que
   aparecer (ou aperte Enter para pegar o primeiro).
2. Aparecem os botões das pistas desse aeroporto. O número pequeno ao lado é o
   comprimento disponível para decolagem, em metros. **Clique** para marcar.
   - **Cabeceiras**: marca só as pistas inteiras (sem as interseções, como "15/A").
   - **Todas**: marca todas as pistas e interseções.
   - **Nenhuma**: desmarca as pistas desse aeroporto.
3. Pode **trocar de aeroporto** e continuar marcando: as pistas escolhidas vão se
   juntando. Elas aparecem listadas logo abaixo; o **×** tira uma pista da lista.
4. Os aeroportos que você usou por último ficam como botões abaixo da busca, para abrir
   com um clique.

#### Alterar os dados de uma pista (pista parcialmente fechada, NOTAM…)

Na lista de pistas escolhidas, clique no **✎** ao lado da pista. Abre um quadro onde
dá para mudar:

| Campo | O que é |
|---|---|
| RUNWAY ELEVATION (RWYD1) | Elevação da pista, em pés |
| TORA (RWYD3) | Distância disponível para a corrida de decolagem, em metros |
| ASDA (RWYD4) | Distância disponível para acelerar e parar, em metros |
| TODA (RWYD5) | Distância disponível para decolagem, em metros |
| SLOPE TODA (RWYD6) | Inclinação da pista, em % |
| RUNWAY SURFACE (RWYD8) | Superfície: Normal ou Grooved |
| RUNWAY WIDTH (RWYD11) | Largura da pista, em metros |

- Embaixo de cada campo aparece o **valor do cadastro**, para comparar. O que você mudou
  fica destacado em amarelo.
- **Último terço fechado** tira 1/3 da TORA, e a ASDA e a TODA ficam iguais à nova TORA.
  Para tirar outra medida, digite os metros ao lado e clique em **Descontar**.
  Depois dá para ajustar qualquer número à mão.
- **Os obstáculos não mudam**: continuam os do cadastro.
- Clique em **Aplicar**. A pista passa a aparecer como **editada** (em amarelo) e o
  resultado sai como "SBKP 15 (editada)", com os dados usados escritos no topo.
- **Restaurar original** volta aos valores do cadastro. A alteração vale só para as suas
  consultas; o cadastro de pistas (`airports_list.csv`) não muda.

### Passo 3 — Ajuste as condições

Na seção **Condições** há três quadros: **Temperatura**, **Vento** e **QNH**.
Cada um pode ser:

- **Um valor** — um número só (por exemplo, 30 °C).
- **Faixa** — vários valores de uma vez. Você diz **de** quanto, **até** quanto e **a cada**
  quanto. Exemplo: de 25 até 45 a cada 10 → calcula 25, 35 e 45 °C.
  Logo abaixo aparecem os valores que serão calculados, para você conferir.

Sobre o **vento**:
- **Um valor**: escolha **Sem vento**, **Proa** (de frente), **Cauda** (por trás) ou
  **Través** (de lado) e digite a velocidade em nós (kt).
- **Faixa**: números **negativos são vento de cauda** e positivos são de proa.
  Exemplo: de −10 até 10 a cada 10 → cauda 10, sem vento e proa 10.
- O vento de través só faz diferença nos Airbus.

Sobre o **flap** (quadro **Flap**, que aparece embaixo do QNH com as aeronaves marcadas):
- **Ótimo** (o padrão): o programa testa os flaps e mostra o que dá o **maior peso**.
- Clicando num número (por exemplo, **2** no A320 ou **1** no E195-E2), o cálculo é feito
  **com esse flap**, mesmo que outro desse mais peso. Serve para comparar com o que a
  operação usa.
- Dá para marcar **vários** ao mesmo tempo (por exemplo, **Ótimo**, **1+F**, **2** e **3**).
  Cada flap vira uma linha separada no resultado ("A320 … · CONF 2"), com seu cartão,
  sua Tabela RTOW e sua linha no Gráfico — fácil de comparar. O número de cálculos
  multiplica pelo número de flaps marcados.
- Clicar de novo num flap marcado desmarca. Se nenhum ficar marcado, volta ao **Ótimo**.
- O ATR só tem o **FLAP 15** na base de dados, então ele não tem escolha.
- O resultado mostra os flaps escolhidos no topo, e o CSV ganha a coluna `flap_sel`.

### Passo 4 — Calcule

Embaixo, à esquerda, o programa mostra quantos cálculos vai fazer
(por exemplo, "3 aeronaves × 2 pistas × 3 combinações = 18 cálculos").

Clique em **Calcular** (ou aperte **Ctrl + Enter**).

Uma barra mostra o andamento. Quanto tempo leva:
- ATR: praticamente instantâneo.
- Airbus: cerca de 1 a 2 segundos por cálculo.
- E195 e E195-E2: cerca de 2 a 4 segundos por cálculo.

Vários cálculos rodam ao mesmo tempo. Se forem mais de 300, o programa pede para você
confirmar antes.

---

## 3. Ler o resultado

### Um cálculo só

Aparece o **peso máximo** em destaque, o **flap**, o que **limitou** o peso e as
velocidades **V1 / VR / V2** (em nós).

### Vários cálculos

No topo aparece um resumo por aeronave: o **maior** MTOW e o **menor**, com as condições
em que o menor acontece. Embaixo há três abas:

- **Tabela RTOW** (a principal): uma tabela para cada aeronave e pista. As linhas são as
  temperaturas (a mais quente em cima) e as colunas são os ventos. Cada quadrinho mostra:
  - em cima: **peso máximo (kg) / código do que limitou** (veja a tabela abaixo);
  - embaixo: **V1 / VR / V2**, ou o flap, quando o motor não informa velocidades;
  - a **cor**: quanto mais escuro, mais pesado dá para decolar.

  **Passe o mouse** sobre um quadrinho para ver tudo por extenso.
  Os botões no alto da aba filtram por aeronave, pista ou QNH.
- **Gráfico**: o peso máximo conforme a temperatura (ou o vento, ou o QNH). Você escolhe
  nos botões acima do gráfico o que vai em cada eixo. Passe o mouse para ver os valores.
- **Lista**: todos os cálculos numa tabela. Clique no título de uma coluna para ordenar.

### Códigos do limitante (o número depois da "/")

| Código | Significado |
|---|---|
| 1 | Peso estrutural (máximo da aeronave — a pista não limita) |
| 2 | Distância com todos os motores |
| 3 | Distância com um motor inoperante |
| 9 | VMCG |
| 10 | Velocidade dos pneus |
| 12 | Energia dos freios |
| 13 | V2 mínimo (VMCA) |
| 14 | Subida – 1º segmento |
| 15 | Subida – 2º segmento |
| 17 | Aceleração (3º segmento) |
| 18 | Subida – segmento final |
| 19 | Obstáculo |
| 20 | Corrida com um motor inoperante |
| 21 | Corrida com todos os motores |
| 24 | Inclinação da pista |

### Guardar o resultado

O botão **CSV** (no canto de cima, à direita) baixa uma planilha com todos os números,
que abre no Excel ou no LibreOffice. Uma cópia também fica guardada na pasta
`Documents/Azul/fortran/app/results`.

### "erro" em algum quadrinho

Às vezes o próprio programa de performance não encontra um peso possível — por exemplo,
numa interseção curta com vento de cauda. O quadrinho mostra **erro**; passando o mouse,
aparece a explicação. Isso é uma resposta do cálculo, não um defeito do programa.

---

## 4. Atalhos para o dia a dia

- **O programa lembra a última consulta.** Na próxima vez que abrir, as aeronaves, as
  pistas e as condições já estarão marcadas como você deixou.
- **Recentes**: as últimas consultas ficam no topo da coluna da esquerda. Um clique
  carrega tudo de novo; depois é só apertar **Calcular**.
- **Ctrl + Enter** calcula de qualquer lugar da tela.
- O botão com a **lua**, no canto de cima, alterna entre tema claro e escuro.

---

## 5. Aba "Malha"

Serve para a planilha de voos (**Malha.csv**). O programa lê, para cada voo, o
aeroporto de partida e o tipo de aeronave, testa **todas as pistas** desse aeroporto e
escreve na própria planilha o **maior peso possível**, com a pista e as condições.

1. Clique na aba **Malha**, no alto da tela.
2. Confira o caminho do arquivo (já vem preenchido com a Malha.csv da pasta `fortran/data`).
3. Ajuste as condições (temperatura, vento, QNH), do mesmo jeito do cálculo normal.
4. Em **Peso de referência para o alerta**, digite o peso que cada aeronave precisa
   decolar (por exemplo, 61000 no E195-E2). Deixando em branco, o programa usa o peso
   estrutural máximo. Logo abaixo dá para escolher o **flap** de cada aeronave
   (**Flap ótimo** é o padrão). O programa lembra esses valores na próxima vez.
5. Clique em **Calcular malha** e espere.
6. No fim aparece uma tabela com o resultado de cada aeroporto. O botão **Abrir malha**
   abre a planilha atualizada.

### Alertas

Para cada aeroporto e aeronave, o programa calcula dois pesos:

- **Maior MTOW**: o melhor caso entre todas as condições (normalmente a temperatura mais
  fria).
- **Pior caso**: a condição mais desfavorável (normalmente a mais quente), usando a
  melhor pista nessa condição.

Depois compara com o peso de referência:

| Alerta | Significado |
|---|---|
| **OK** (verde) | Até no pior caso dá para decolar com o peso de referência. |
| **Atenção** (amarelo) | Só dá em parte das condições. A coluna **Decola com a ref. até** mostra a temperatura máxima em que ainda dá. |
| **Restrito** (vermelho) | Nem no melhor caso dá para decolar com o peso de referência. |

- **Margem**: pior caso menos referência. Negativa (vermelha) = quantos kg faltam.
- A tabela já vem com os casos mais graves em cima. Os botões acima dela filtram:
  **Só alertas**, **Restrito**, **Atenção** ou **OK**.
- A planilha ganha as colunas **MTOW Pior Caso (kg)**, **Pior Caso**, **Peso Ref (kg)**,
  **Margem (kg)**, **Temp Limite (C)** e **Alerta** (OK / ATENCAO / RESTRITO).

O programa **guarda uma cópia** da planilha original antes de escrever, com o nome
**Malha.csv.bak**, na mesma pasta.

---

## 6. Fechar o programa

1. Feche a aba do Firefox.
2. Volte para a janela do Terminal e aperte **Ctrl + C**. Aparece a palavra
   "Encerrado." Depois pode fechar o Terminal.

---

## 7. Se algo der errado

| O que aparece | O que fazer |
|---|---|
| "Não consegui falar com o servidor" na tela | O Terminal foi fechado ou o programa parou. Abra de novo (parte 1). |
| O Firefox não abriu sozinho | Abra o Firefox e digite **127.0.0.1:8765** na barra de endereço. |
| No Terminal: "Nenhuma porta livre" | Já existe outro programa aberto. Feche os Terminais abertos e tente de novo. |
| O endereço é diferente de 8765 | Normal se essa porta estava ocupada: use o endereço que aparece no Terminal. |
| "Já existe um cálculo em andamento" | Espere o cálculo atual terminar. Só dá para fazer um cálculo por vez. |
| Um motor aparece apagado e não deixa clicar | Faltam os arquivos de dados desse motor no computador. Avise o responsável. |
| "Wine" ou "Nao achei o programa" numa mensagem de erro | Falta um programa de apoio no computador (o Wine). Avise o responsável. |
| A tela parece velha depois de uma atualização | No Firefox, aperte **Ctrl + Shift + R** para recarregar. |

Se nada disso resolver, tire um **print da tela** e do **Terminal** e envie para quem cuida
do programa.

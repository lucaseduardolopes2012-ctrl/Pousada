---
name: Painel e site da pousada
description: Painel de balcão e site de reservas para a pousada pequena brasileira, desenhados como uma tábua de marés numa carta náutica.
colors:
  mar: "#0c3452"
  mar-2: "#164a6e"
  mar-3: "#23618c"
  mar-suave: "#a9c4d6"
  agua: "#e9f2f3"
  agua-2: "#dcebee"
  raso: "#c7e0e6"
  agua-funda: "#9fcad6"
  papel: "#ffffff"
  campo: "#f3f8f9"
  terra: "#ead6a0"
  terra-clara: "#f6eccd"
  terra-tinta: "#5e4a14"
  livre-borda: "#e2cd8f"
  magenta: "#a8135f"
  magenta-esc: "#8a0d4d"
  magenta-clara: "#f7e1ec"
  tinta: "#0b2233"
  suave: "#48616f"
  fraco: "#6f8692"
  fio: "#c3d6dc"
  fio-forte: "#9fbac3"
  linha: "#dbe7ea"
  ok: "#0f5f8a"
  ok-bg: "#deedf5"
  ok-borda: "#b5d3e4"
  sai: "#845300"
  sai-bg: "#fbefd3"
  sai-borda: "#ecd29a"
  atraso: "#b0261a"
  atraso-bg: "#fde9e6"
  atraso-borda: "#f3bdb5"
  chega: "#0e6a55"
  chega-bg: "#dcf0e8"
  chega-borda: "#acd9c7"
typography:
  display:
    fontFamily: "Barlow Condensed, Arial Narrow, sans-serif"
    fontSize: "clamp(56px, 10vw, 136px)"
    fontWeight: 700
    lineHeight: 0.88
    letterSpacing: "-0.01em"
  headline:
    fontFamily: "Barlow Condensed, Arial Narrow, sans-serif"
    fontSize: "clamp(30px, 4vw, 42px)"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "-0.005em"
  title:
    fontFamily: "Barlow Condensed, Arial Narrow, sans-serif"
    fontSize: "23px"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "0.005em"
  numeral:
    fontFamily: "Barlow Condensed, Arial Narrow, sans-serif"
    fontSize: "26px"
    fontWeight: 600
    lineHeight: 1
    fontFeature: "\"tnum\" 1, \"lnum\" 1"
  numeral-table:
    fontFamily: "Barlow Condensed, Arial Narrow, sans-serif"
    fontSize: "17px"
    fontWeight: 500
    lineHeight: 1.3
    fontFeature: "\"tnum\" 1, \"lnum\" 1"
  body:
    fontFamily: "Digitos, Atkinson Hyperlegible, Segoe UI, system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.5
  body-leitura:
    fontFamily: "Digitos, Atkinson Hyperlegible, Segoe UI, system-ui, sans-serif"
    fontSize: "16.5px"
    fontWeight: 400
    lineHeight: 1.7
  button:
    fontFamily: "Digitos, Atkinson Hyperlegible, Segoe UI, system-ui, sans-serif"
    fontSize: "14px"
    fontWeight: 700
    lineHeight: 1
  label:
    fontFamily: "Digitos, Atkinson Hyperlegible, Segoe UI, system-ui, sans-serif"
    fontSize: "12.5px"
    fontWeight: 700
    lineHeight: 1.3
rounded:
  none: "0px"
  etiqueta: "3px"
  r-p: "5px"
  r: "6px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  2xl: "28px"
  3xl: "36px"
components:
  button-primary:
    backgroundColor: "{colors.magenta}"
    textColor: "{colors.papel}"
    typography: "{typography.button}"
    rounded: "{rounded.r-p}"
    padding: "0 16px"
    height: "40px"
  button-primary-hover:
    backgroundColor: "{colors.magenta-esc}"
  button-primary-large:
    backgroundColor: "{colors.magenta}"
    textColor: "{colors.papel}"
    rounded: "{rounded.r-p}"
    padding: "0 20px"
    height: "48px"
  button-navy:
    backgroundColor: "{colors.mar}"
    textColor: "{colors.papel}"
    typography: "{typography.button}"
    rounded: "{rounded.r-p}"
    padding: "0 16px"
    height: "40px"
  button-navy-hover:
    backgroundColor: "{colors.mar-2}"
  button-outline:
    backgroundColor: "{colors.papel}"
    textColor: "{colors.tinta}"
    typography: "{typography.button}"
    rounded: "{rounded.r-p}"
    padding: "0 16px"
    height: "40px"
  button-danger:
    backgroundColor: "{colors.papel}"
    textColor: "{colors.atraso}"
    typography: "{typography.button}"
    rounded: "{rounded.r-p}"
    padding: "0 16px"
    height: "40px"
  button-danger-hover:
    backgroundColor: "{colors.atraso-bg}"
  input:
    backgroundColor: "{colors.papel}"
    textColor: "{colors.tinta}"
    typography: "{typography.body}"
    rounded: "{rounded.r-p}"
    padding: "0 12px"
    height: "44px"
  tag-ocupado:
    backgroundColor: "{colors.ok-bg}"
    textColor: "{colors.ok}"
    typography: "{typography.label}"
    rounded: "{rounded.etiqueta}"
    padding: "0 8px"
    height: "24px"
  tag-sai:
    backgroundColor: "{colors.sai-bg}"
    textColor: "{colors.sai}"
    rounded: "{rounded.etiqueta}"
    padding: "0 8px"
    height: "24px"
  tag-atrasado:
    backgroundColor: "{colors.atraso-bg}"
    textColor: "{colors.atraso}"
    rounded: "{rounded.etiqueta}"
    padding: "0 8px"
    height: "24px"
  tag-chega:
    backgroundColor: "{colors.chega-bg}"
    textColor: "{colors.chega}"
    rounded: "{rounded.etiqueta}"
    padding: "0 8px"
    height: "24px"
  tag-livre:
    backgroundColor: "{colors.terra-clara}"
    textColor: "{colors.terra-tinta}"
    rounded: "{rounded.etiqueta}"
    padding: "0 8px"
    height: "24px"
  tag-pedido:
    backgroundColor: "{colors.magenta}"
    textColor: "{colors.papel}"
    rounded: "{rounded.etiqueta}"
    padding: "0 8px"
    height: "24px"
  rail:
    backgroundColor: "{colors.mar}"
    textColor: "{colors.papel}"
    padding: "20px 14px 18px"
    width: "248px"
  nav-item:
    backgroundColor: "{colors.mar}"
    textColor: "{colors.mar-suave}"
    typography: "{typography.body}"
    rounded: "{rounded.r-p}"
    padding: "0 12px"
    height: "42px"
  nav-item-active:
    backgroundColor: "{colors.mar-2}"
    textColor: "{colors.papel}"
  module-paper:
    backgroundColor: "{colors.papel}"
    textColor: "{colors.tinta}"
    rounded: "{rounded.r}"
    padding: "18px 20px 20px"
  ticket-head:
    backgroundColor: "{colors.mar}"
    textColor: "{colors.papel}"
    typography: "{typography.title}"
    padding: "20px 22px"
  toast:
    backgroundColor: "{colors.mar}"
    textColor: "{colors.papel}"
    rounded: "{rounded.r}"
    padding: "12px 18px"
---

# Design System: Painel e site da pousada

## Overview

**Creative North Star: "A Tábua de Marés"**

O dia da pousada se lê como uma tábua de marés publicada numa carta náutica: movimentos listados por horário em colunas, números condensados alinhados como num almanaque, e a ocupação das próximas semanas desenhada como uma curva de maré, com preamar ("Mais cheia") e baixa-mar ("Mais vazia"). O sistema serve a quem está no balcão ou no celular com pressa: a primeira linha da tábua é a próxima coisa a fazer.

O mundo é o da carta impressa: um menu em azul de mar fundo, o chão em água rasa clara, a terra em ocre claro para o que está livre ou quieto, e o magenta das cartas náuticas reservado ao que exige ação. Os módulos não são cartões estufados; são seções abertas por um fio grosso de mar e divididas por linhas finas, densas como uma página de almanaque. Palavras em Atkinson Hyperlegible, feita para ler fácil por gente de todas as idades; horários, datas, preços e números de quarto em Barlow Condensed, sempre tabulares.

O mesmo mundo veste o site público de cada pousada, onde a pousada é a protagonista: o nome dela em letras condensadas enormes, a escolha de datas como um bilhete de travessia (entrada e saída em colunas), e uma faixa de maré em dois tons de água separando a abertura dos quartos. O que este sistema recusa é o painel SaaS genérico de quatro blocos de KPI sobre um gráfico de barras.

**Key Characteristics:**
- Chão em água de carta (`agua`), nunca creme nem branco puro; papel branco só para o que se destaca do chão.
- Magenta de carta só para ação: pedido novo, botão principal, linha "agora", marcador de hoje, foco.
- Fios em vez de caixas: módulo abre com fio de 2px em azul de mar e se divide com linhas de 1px.
- Duas vozes tipográficas com papéis fixos: Atkinson para palavras, Barlow Condensed para tudo que é número ou título.
- Cada estadia e cada quarto é identificado pelo número primeiro.
- Situação sempre como etiqueta com quadradinho de cor e palavra, nunca só cor.

## Colors

Uma carta náutica impressa: azul de mar fundo para a moldura, água clara para o chão, ocre de terra para o que está quieto, e um único magenta para o que pede ação; os tons de situação são funcionais e sempre acompanham uma palavra.

### Primary
- **Magenta de Carta** (`magenta`): a cor da ação. Botão principal ("Registrar estadia", "Confirmar", "Pedir reserva"), etiqueta de pedido novo, borda do bloco de pedidos do site, linha "agora" na tábua, marcador de hoje na curva de maré, contador de pedidos no menu, anel de foco (`:focus-visible`, 2px). **Magenta Funda** (`magenta-esc`) é o hover do botão principal; **Magenta Clara** (`magenta-clara`) é o fundo raro de destaque suave.

### Secondary
- **Azul de Mar Fundo** (`mar`): a moldura. Menu lateral do painel, topo e rodapé do site, cabeça do bilhete de datas, faixa da ficha do hóspede, cabeça da gaveta, recado (toast), dica da curva e o fio de 2px que abre cada módulo. Também a linha da curva de maré e o texto dos títulos grandes do site.
- **Mar Médio** (`mar-2`): item ativo do menu, hover de botão azul, campos de data dentro do bilhete escuro, links de texto e códigos de estadia.
- **Mar Claro** (`mar-3`): a barra de progresso da estadia e o "404" grande.
- **Bruma** (`mar-suave`): texto secundário e ícones sobre o azul de mar.

### Tertiary
- **Terra de Carta** (`terra`): a marca da pousada (quadrado com iniciais), o ícone do item ativo do menu, o passo concluído da ficha e o código do pedido confirmado. É a "terra firme" sobre o azul.
- **Terra Clara** (`terra-clara`) com **Tinta de Terra** (`terra-tinta`) e **Borda de Terra** (`livre-borda`): o que está livre ou quieto. Etiqueta "Livre", observações do hóspede, aviso de sinal no resumo, campo "a preencher" nos documentos legais.

### Neutral
- **Água de Carta** (`agua`): o chão de todas as páginas.
- **Água Funda** (`agua-2`): hover discreto sobre o chão e fundo dos botões de contador.
- **Água Rasa** (`raso`): fundo de foto ausente, seleção de texto, anel de foco dos campos (3px), item marcado em menus.
- **Água de Maré** (`agua-funda`): a água sob a curva de maré e a faixa ondulada do site; nunca texto.
- **Papel** (`papel`): módulos que se destacam do chão (pedidos, bilhete, cartões de quarto do site, gaveta), campos e botões de borda.
- **Campo** (`campo`): cabeçalho de tabela, estado vazio e bandejas de formulário.
- **Tinta** (`tinta`): todo texto principal.
- **Suave** (`suave`): texto de apoio, rótulos e cabeçalhos de coluna. **Fraco** (`fraco`): placeholder e contagens apagadas.
- **Fio** (`fio`), **Fio Forte** (`fio-forte`), **Linha** (`linha`): as três espessuras visuais de divisória. `linha` entre linhas de tabela; `fio` entre colunas e módulos; `fio-forte` sob cabeçalhos de coluna e em bordas de campo.

### Situações
Cada situação tem um trio texto/fundo/borda e só aparece dentro de uma etiqueta com palavra:
- **Ocupado / Hospedado** (`ok`, `ok-bg`, `ok-borda`).
- **Sai hoje** (`sai`, `sai-bg`, `sai-borda`): âmbar de maré vazante.
- **Saída atrasada / Cancelada** (`atraso`, `atraso-bg`, `atraso-borda`): também usado em erros e no botão de perigo.
- **Chega hoje** (`chega`, `chega-bg`, `chega-borda`).
- **Livre** (terra, acima). **Pedido novo** (magenta cheio).

### Named Rules
**A Regra do Magenta de Carta.** Magenta só marca o que exige ação agora ou onde você está agora. Se nada na tela pede ação, o único magenta é o botão principal.

**A Regra do Chão de Água.** O chão é sempre `agua`. Não é creme, não é branco. Papel branco é um módulo levantado do chão, não o fundo da página.

**A Regra da Palavra ao Lado da Cor.** Nenhuma situação é comunicada só por cor: etiqueta com quadradinho de 7px e a palavra ("Sai hoje", "Chega hoje"), ou a hora em vermelho acompanhada de "há 1 dia".

## Typography

**Display Font:** Barlow Condensed (com Arial Narrow, sans-serif)
**Body Font:** Atkinson Hyperlegible (com Segoe UI, system-ui, sans-serif)
**Label/Mono Font:** Barlow Condensed tabular para números; não há fonte mono.

**Character:** A Barlow Condensed é a voz do almanaque: títulos, horas, datas, preços e números de quarto, estreitos e alinhados em coluna. A Atkinson Hyperlegible é a voz que conversa com o dono e o hóspede, larga e sem ambiguidade. Os algarismos dentro do texto corrido vêm de um subconjunto da Barlow ("Digitos", só U+0030–0039) para evitar o zero cortado da Atkinson.

### Hierarchy
- **Display** (700, clamp(56px, 10vw, 136px), 0.88): nome da pousada na abertura do site. Variantes do mesmo papel: tela de entrar (clamp(40px, 5.4vw, 76px)/0.95), código do pedido confirmado (clamp(56px, 10vw, 112px)/0.9), "404" (120px/0.8).
- **Headline** (700, clamp(30px, 4vw, 42px), 1): data do dia no painel, pergunta de cada passo do cadastro. No site, títulos de seção sobem para clamp(38px, 5vw, 60px)/0.95; nos documentos legais, clamp(40px, 6vw, 60px).
- **Title** (700, 23px, 1.1): cabeçalho de módulo ("Tábua de hoje", "Maré de ocupação"). Nomes de quarto e títulos de gaveta usam 24–28px/1 no mesmo peso.
- **Numeral** (600, 26px, 1, tabular): hora na tábua, leituras da régua do dia (28px), preço (22–30px), total do resumo (34px). Número de quarto como placa sem foto: 700, 72–140px.
- **Numeral de tabela** (500, 17px, 1.3, tabular): datas, valores e códigos nas tabelas de estadias e em ficha de dados.
- **Body** (400, 15px, 1.5): painel. Site sobe para 16px/1.55; documentos legais 16.5px/1.7 com 68ch de medida. Parágrafos de apoio limitados a 62ch.
- **Label** (700, 12.5px): cabeçalhos de coluna, etiquetas de situação, rótulos de dado. Rótulos de campo de formulário: 700, 13.5px. Nunca em caixa alta.

### Named Rules
**A Regra da Coluna de Números.** Toda hora, data, preço, contagem e número de quarto sai em Barlow Condensed com algarismos tabulares, inclusive dentro de campos `date`, `time` e `number` (600, 18px). Palavras nunca saem em Barlow em corpo de texto.

**A Regra do Número Primeiro.** Quarto e estadia são identificados pelo número antes do nome: "Quarto 2", "#00101", e o quarto sem foto mostra o próprio número como placa de chaveiro.

## Layout

O painel é uma casca de duas colunas: menu lateral fixo de 248px em azul de mar e área de conteúdo com topo pegajoso translúcido (água a 94% com desfoque de 8px). O conteúdo tem respiro de 28px nas laterais e no topo, 56px embaixo, largura máxima de 1360px. A visão geral empilha: cabeçalho (data + resumo em uma linha + ações à direita), faixa de pedidos quando houver, régua do dia com quatro leituras, e duas colunas (1.1fr / 1fr, 36px de vão) com a tábua de hoje e a curva de maré.

O site usa uma coluna central de até 1180px (`width: min(1180px, 100% - 48px)`), com seções de clamp(44px, 6vw, 80px) de respiro vertical; a abertura é uma grade de texto + bilhete de 420px alinhada pela base. Documentos legais usam coluna de 760px.

O ritmo é denso, de almanaque: 8px entre ícone e rótulo, 12px de respiro interno de linha de tabela, 16px entre campos, 20px de padding de módulo, 28px de margem de página, 36px entre colunas. Grades de quartos usam `auto-fill` com mínimo de 260–280px e 16–18px de vão.

**Responsivo.** Abaixo de 1150px as duas colunas da visão geral empilham. Abaixo de 900px o menu lateral vira gaveta de 280px que desliza da esquerda e a margem cai para 16px. Abaixo de 760px a régua passa a 2×2. Abaixo de 640px as tabelas viram fichas em grade de duas colunas com o rótulo acima do valor; abaixo de 560px a tábua de hoje vira hora à esquerda e quem/movimento à direita, com o botão de ação em largura total, e os formulários passam a uma coluna. No site, abaixo de 960px o bilhete desce sob o nome e, abaixo de 700px, o mosaico de fotos vira carrossel com encaixe. Todos os topos e rodapés fixos respeitam `env(safe-area-inset-*)`.

### Named Rules
**A Regra do Fio, Não do Cartão.** Um módulo abre com um fio de 2px em `mar` e se divide com linhas de 1px; não ganha caixa, sombra nem padding de cartão. Só ganha papel e borda o que precisa se destacar: o bloco de pedidos, o aviso de termos, o bilhete de datas e os cartões de quarto do site.

## Elevation & Depth

O sistema é plano, como uma carta impressa. A profundidade vem do contraste de superfície (moldura em azul de mar, chão em água, módulo em papel) e da hierarquia de fios. Sombras aparecem só em três casos: o que flutua sobre a página (menu de filtro, gaveta, menu móvel, recado, dica da curva), o que precisa chamar o olho de forma deliberada (bloco de pedidos e o botão principal, ambos com brilho magenta difuso), e o bilhete de datas do site. Todas as sombras são tingidas de azul de mar ou de magenta, nunca preto neutro (a exceção é o botão "Ver todas" sobre fotos).

### Shadow Vocabulary
- **Sombra de papel** (`box-shadow: 0 1px 2px rgba(12, 52, 82, .06), 0 8px 24px -16px rgba(12, 52, 82, .25)`): menus suspensos, bilhete de datas, quarto escolhido.
- **Brilho de ação** (`box-shadow: 0 1px 0 rgba(0, 0, 0, .12), 0 6px 14px -10px rgba(168, 19, 95, .9)`): botão principal.
- **Anel de pedido** (`box-shadow: 0 0 0 1px var(--magenta), 0 10px 24px -18px rgba(168, 19, 95, .7)`): bloco de pedidos do site; o aviso de termos usa só o anel de 1px.
- **Gaveta** (`box-shadow: -24px 0 56px -24px rgba(8, 38, 60, .5)`): gaveta lateral e, espelhada, o menu móvel.
- **Recado** (`box-shadow: 0 14px 32px -14px rgba(8, 38, 60, .6)`): toast no rodapé.
- **Foco de campo** (`box-shadow: 0 0 0 3px var(--raso)`): campo em foco, com a borda virando `mar`.

### Named Rules
**A Regra da Carta Plana.** Superfície parada não tem sombra. Sombra significa "isto está flutuando" ou "isto pede ação", e é sempre tingida de mar ou de magenta.

## Shapes

Cantos quase retos, como etiquetas e placas de uma carta: 3px para etiquetas, marcas e contadores, 5px para botões, campos e itens de menu, 6px para módulos de papel, gaveta e recado. Módulos de fio (tábua, maré, quartos do painel, régua, "bom saber") têm canto zero. Fotos de quarto em 16:10 no painel e 4:3 no site; o quarto sem foto mostra uma grade de 32px de carta em `raso` com o número grande. A marca da pousada é um quadrado de 34px em terra com as iniciais em Barlow. A única curva livre do sistema é a maré: a curva de ocupação e a faixa ondulada do site. Ícones são traço de 1.6px, cantos arredondados, 18px.

### Named Rules
**A Regra da Etiqueta Reta.** Nenhum canto passa de 6px e nada vira pílula. Curva só na água.

## Components

### Buttons
Etiquetas firmes, de palavra inteira, nunca pílula.
- **Shape:** cantos levemente arredondados (`r-p`, 5px), altura mínima 40px, padding horizontal 16px, Atkinson 700 a 14px, ícone de 17px a 8px do rótulo.
- **Primary:** magenta cheio com texto branco e brilho de ação; um por região. Versão grande: 48px de altura, 20px de padding, 15px; no bilhete e na ficha do site, 52px.
- **Hover / Focus:** hover escurece para `magenta-esc`; transição de 150ms em cor de fundo, borda e sombra. Foco visível é contorno de 2px em magenta com 2px de afastamento.
- **Azul (`btn--sec`):** azul de mar cheio, hover `mar-2`. Para ação forte que não é a principal.
- **Borda:** papel com borda `fio-forte`, texto tinta; hover troca a borda para `mar`. É o botão de ação por linha da tábua ("Registrar saída", "Registrar entrada").
- **Perigo:** papel com borda e texto `atraso`; hover com fundo `atraso-bg` ("Recusar").
- **Desabilitado:** opacidade 0.55, cursor de progresso.
- **Ícone (`.ic`):** 36×36, sem fundo, `mar-2`; hover com fundo `agua-2`.

### Chips
- **Style:** etiqueta de situação com 24px de altura, cantos de 3px, borda de 1px, Atkinson 700 a 12.5px, quadradinho de 7px na cor do texto antes da palavra.
- **State:** uma variante por situação (ocupado, sai hoje, atrasado/cancelado, chega hoje, próxima, livre, pedido novo, fora/encerrada). "Pedido" é a única cheia (magenta). "Fora/encerrada" troca o quadradinho por um contorno vazio.
- **Filtro ativo:** etiqueta azul de mar com 32px de altura e botão de remover; abas são texto com sublinhado de 3px em `mar` e a contagem em magenta quando ativa.

### Cards / Containers
- **Corner Style:** 6px (`r`) para módulos de papel; 0 para módulos de fio.
- **Background:** papel sobre o chão de água; cabeça em azul de mar no bilhete de datas e na gaveta.
- **Shadow Strategy:** plano por padrão (ver Elevation & Depth); só bilhete, pedidos e flutuantes têm sombra.
- **Border:** 1px `fio`; pedidos e aviso de termos em magenta; quarto escolhido no site com anel de 2px magenta.
- **Internal Padding:** 18–20px (bloco 18px 20px 20px; bilhete 20px 22px; resumo 20px).

### Inputs / Fields
- **Style:** papel, borda 1px `fio-forte`, 5px de canto, 44px de altura, 12px de padding, 15px; cursor de texto magenta. Campos de data, hora e número usam Barlow Condensed 600 a 18px tabular. Rótulo acima, Atkinson 700 a 13.5px, com dica em 400 `suave`.
- **Focus:** borda vira `mar` e ganha anel de 3px em `raso`. Sobre azul de mar (bilhete), o campo é `mar-2` com anel branco translúcido; na ficha do site, anel em `terra`.
- **Error / Disabled:** caixa de erro com fundo `atraso-bg`, borda `atraso-borda`, texto `atraso` 700 a 14px. Contador do site desabilitado em opacidade 0.35.

### Navigation
- **Painel:** menu lateral de 248px em azul de mar, marca da pousada no topo separada por fio branco a 12%. Item com 42px, ícone de 19px em `mar-suave`, texto Atkinson 15px. Hover com branco a 7%; ativo em `mar-2`, texto branco 700 e ícone em terra. Contador à direita em quadrado de 3px: vermelho para atraso, magenta para pedido. Grupos rotulados em 12.5px 700 `mar-suave`. Abaixo de 900px vira gaveta deslizante (280ms, curva de saída).
- **Site:** barra de 64px em azul de mar com a marca e links em `#dbe8f0`, sublinhados no hover; o botão "Pedir reserva" é o único magenta da barra. Links somem abaixo de 640px.

### Tábua de hoje (assinatura)
A tabela de movimentos do dia, ordenada por hora. Colunas: Hora (Barlow 600 26px, com "saída"/"entrada"/"há 1 dia" em 12px abaixo), Movimento (etiqueta), Quarto e hóspede (número do quarto em negrito, nome e pessoas em `suave`), Ação (botão de borda ou principal). Linhas separadas por `linha`; linha atrasada com a hora em `atraso`. A linha "agora HH:MM" em magenta corta a tábua no horário atual com um fio de 1px.

### Régua do dia (assinatura)
Quatro leituras em linha (hospedados, saem hoje, atrasadas, livres) entre um fio de 2px em `mar` em cima e 1px `fio-forte` embaixo, separadas por fios verticais. Rótulo em 13.5px `suave`, número em Barlow 600 28px com complemento em 500 17px. A leitura de alerta fica em `atraso`. No site, o mesmo desenho vira "fatos" da pousada (entrada, saída, quartos, diária).

### Maré de ocupação (assinatura)
Curva suave de quartos ocupados por noite (7, 14 ou 30 dias), traço `mar` de 2.2px sobre água em gradiente (`agua-funda` a `raso`), pontos brancos com contorno azul, linha de hoje em magenta de 1.5px e rótulo do dia em magenta. Legenda com "Mais cheia" e "Mais vazia" e uma tabela alternativa acessível em `details`.

### Bilhete de datas (assinatura do site)
Formulário de datas como bilhete de travessia: cabeça em azul de mar com "Quando você vem?", entrada e saída em duas colunas separadas por fio branco translúcido, campos de data em Barlow 21px; parte de baixo em papel com contadores de adultos e crianças (botões de 38px em `agua-2`) e o botão principal em largura total.

## Do's and Don'ts

### Do:
- **Do** manter o chão de toda página em `agua` (#e9f2f3) e usar papel branco só para módulos que se destacam.
- **Do** abrir cada módulo com fio de 2px em `mar` e separar linhas com 1px `linha`; use `fio-forte` sob cabeçalhos de coluna.
- **Do** escrever toda hora, data, preço e número de quarto em Barlow Condensed tabular, e toda palavra em Atkinson Hyperlegible.
- **Do** identificar quarto e estadia pelo número primeiro ("Quarto 2", "#00101").
- **Do** mostrar situação com etiqueta de quadradinho + palavra, usando o trio texto/fundo/borda da situação.
- **Do** reservar o magenta para ação e para o "agora": botão principal, pedido novo, linha do horário atual, marcador de hoje, foco.
- **Do** dar a cada botão um rótulo em palavras ("Registrar saída", "Pedir reserva"); ícone sozinho só em ações repetidas por linha, com `aria-label`.
- **Do** respeitar `prefers-reduced-motion`: animações de entrada usam `cubic-bezier(.16, 1, .3, 1)` entre 280 e 450ms e somem com a preferência reduzida.

### Don't:
- **Don't** resumir o dia em blocos de KPI com número grande, caixa e sombra sobre um gráfico de barras; as leituras vão numa régua de fios e a ocupação vai como curva de maré.
- **Don't** pintar o chão de creme ou de branco puro.
- **Don't** usar magenta como decoração, cor de marca ou fundo de seção.
- **Don't** passar de 6px de canto nem fazer botões, etiquetas ou abas em pílula.
- **Don't** pôr sombra em módulo parado; sombra é para o que flutua ou pede ação, sempre tingida de mar ou magenta.
- **Don't** comunicar situação só por cor.
- **Don't** usar caixa alta em rótulos nem títulos.

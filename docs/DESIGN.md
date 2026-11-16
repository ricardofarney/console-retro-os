# Design do Arcádia

Visual aprovado pelo usuário em 14/11/2026 (horário de Brasília). Este documento é a referência do tema [temas/arcadia](../temas/arcadia), da arte de abertura e das funções novas do EmulationStation ([FUNCOES-ARCADIA.md](FUNCOES-ARCADIA.md)).

## Identidade

| Item | Definição |
|---|---|
| Nome | **Arcádia** |
| Slogan (abertura) | **"seus clássicos, de onde você parou"** |
| Estilo | **colorido por console**: fundo claro, cada console com a sua cor |
| Marcas | **sem logotipos oficiais** — só o nome do console em texto |
| Formas | cantos arredondados em cards, painéis e barra de seleção |
| Jogadores | **até 4** (decisão de 16/11/2026): o padrão é 2; 3 ou 4 só nos jogos que permitem, com o multitap ligado automaticamente — [MULTIJOGADOR.md](MULTIJOGADOR.md) |

## Cores base

| Uso | Cor |
|---|---|
| Fundo geral | `#F4F1EA` |
| Texto principal | `#2C2C2A` |
| Texto secundário | `#5F5E5A` |
| Fundo das telas internas de um console | tom **bem claro** da cor do console (cor do console misturada ~88% com branco) |

## Paleta por console

| Console | Cor | | Console | Cor |
|---|---|---|---|---|
| Atari 2600 | `#D85A30` | | Master System | `#378ADD` |
| Atari 7800 | `#993C1D` | | Mega Drive | `#185FA5` |
| NES | `#A32D2D` | | Sega CD / 32X | `#0C447C` |
| Super Nintendo | `#534AB7` | | Game Gear | `#1D9E75` |
| Nintendo 64 | `#0F6E56` | | PlayStation | `#5F5E5A` |
| Game Boy | `#3B6D11` | | PC Engine | `#BA7517` |
| Game Boy Color | `#639922` | | Neo Geo | `#854F0B` |
| Game Boy Advance | `#3C3489` | | Arcade | `#993556` |
| Neo Geo Pocket | `#D4537E` | | WonderSwan | `#444441` |
| MSX | `#E24B4A` | | **demais consoles** | `#888780` |

Variantes do mesmo console usam a mesma cor (ex.: Famicom = NES; Super Famicom = Super Nintendo; Genesis = Mega Drive; Neo Geo CD = Neo Geo; Neo Geo Pocket Color = Neo Geo Pocket; WonderSwan Color = WonderSwan; MSX2 = MSX; MAME/FBNeo/CPS = Arcade; PC Engine CD/SuperGrafx = PC Engine).

As coleções da tela inicial usam cores próprias, fora da paleta dos consoles: **Continuar jogando** `#2C2C2A` (texto principal) e **Favoritos** `#C9A227` (dourado, cor da estrela).

## Telas

### (a) Abertura

- Fundo `#F4F1EA`.
- Ao centro, **"Arcádia"** em letras grandes (`#2C2C2A`).
- Acima do nome, uma **fileira de quadradinhos** de cantos arredondados com as cores dos consoles (na ordem da paleta).
- Abaixo do nome, o slogan **"seus clássicos, de onde você parou"** (`#5F5E5A`).
- Embaixo, **barra de carregamento** fina (trilho `#E2DED3`, preenchimento `#2C2C2A`).
- Resoluções: 1920×1080 (padrão), 1280×720 e 3840×2160 (ver [temas/arcadia/LEIA-ME.md](../temas/arcadia/LEIA-ME.md)).

### (b) Início

- Abre **direto nos consoles** (não em "Continuar jogando").
- Ordem: **consoles favoritados** primeiro (cards maiores, com ★), depois **"Continuar jogando"** e **"Favoritos"** (coleções de jogos), depois **todos os consoles**.
- Cada card: retângulo arredondado na cor do console, com o **nome** do console em texto e a **quantidade de jogos**.
- Botão **Y** na tela inicial marca/desmarca o console como favorito (função nova — [FUNCOES-ARCADIA.md](FUNCOES-ARCADIA.md)).
- Limite técnico: o EmulationStation do EmuELEC desenha a tela inicial como **carrossel**, não como grade livre. O layout adotado é o mais próximo possível: carrossel horizontal com vários cards visíveis ao mesmo tempo, o selecionado ampliado.

### (c) Lista de jogos

- Fundo no **tom claro da cor do console**; faixa superior na cor do console com o nome em branco.
- **"★ Favoritos"** no topo, depois **todos de A a Z**, cada um com o **gênero**.
- Painel ao lado: **capa**, **nome**, **ano**, **gênero**, **jogadores** e **resumo em português**.
- Jogo sem capa: mostra o card do console no lugar da capa.

### (d) Abrir jogo que tem save

- Janela com **"Continuar de onde parei"** e **"Começar do início"**.
- Cada save mostra **data/hora** e **miniatura** da tela no momento em que foi salvo.
- Funciona com o salvamento automático, ligado de fábrica.

### (e) Configurações simplificadas

Menu com **6 itens**:

1. **Wi-Fi**
2. **Parear controle Bluetooth**
3. **Configurar botões** — submenu com **Mapear um controle** e **Ordem dos jogadores** (jogadores 1 a 4; "automático" = ordem de conexão)
4. **Atualizações**
5. **Som e tela**
6. **Desligar com segurança**

As opções técnicas do EmuELEC ficam **escondidas**, acessíveis por **"Modo avançado"**, no fim do menu.

## Regras de texto

- Tudo em português do Brasil; nomes de consoles como são conhecidos no Brasil (Mega Drive, Master System, Super Nintendo).
- Datas no formato `dd/mm/aaaa hh:mm`, horário de Brasília.

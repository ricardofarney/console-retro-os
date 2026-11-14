# Tema Arcádia (versão 0.2)

Tema do EmulationStation do projeto Arcádia, em português do Brasil, no estilo **"colorido por console"** aprovado em [docs/DESIGN.md](../../docs/DESIGN.md). Funciona no EmulationStation do EmuELEC (imagem) e no do RetroBat (prévia no Windows — [docs/PREVIA-WINDOWS.md](../../docs/PREVIA-WINDOWS.md)).

## Telas

| Tela | Como ficou |
|---|---|
| Abertura (`splash.xml`) | fundo `#F4F1EA`, quadradinhos com as cores dos consoles, "Arcádia", slogan "seus clássicos, de onde você parou" e a barra de carregamento real do EmulationStation |
| Início (`view system`) | **grade** de cards arredondados (`imagegrid` + `itemTemplate`), 4 por linha; cada card na cor do console com nome, fabricante e quantidade de jogos ("1 jogo" / "N jogos"); card selecionado amplia; ★ em consoles favoritos (função do `arcadia-emulationstation`) |
| Lista de jogos (`basic/detailed/video`) | fundo no tom claro da cor do console, faixa superior na cor do console; cada linha com ★ (favorito), nome e gênero; barra de seleção escura arredondada |
| Painel do jogo (`detailed`) | painel branco arredondado com capa, nome, ano, gênero, jogadores e resumo; sem capa → card do console |

Telas de abertura do EmuELEC (antes do EmulationStation abrir), geradas pelo mesmo script: `packages/sx05re/emuelec/config/splash/splash-1080.png` (1920×1080), `splash-std.png` (1280×1024), `loading-game.png` e `loading-game-std.png` ("carregando o jogo…").

## Estrutura

| Pasta/arquivo | Conteúdo |
|---|---|
| `theme.xml` | layout de todas as telas |
| `splash.xml` | tela de carregamento do EmulationStation |
| `arte/branco.png`, `arte/sombra.png`, `arte/abertura.png` | fundo tingível, sombra dos cards e abertura (gerados) |
| `logos/<sistema>.png` | **cards** dos consoles 640×400 (gerados) — usados pela grade via `{system:logo}` |
| `logos/claro/<sistema>.png` | nome em branco para a faixa das listas (gerados) |
| `cores/<sistema>.xml` | cor do console e tom claro do fundo das listas (gerados) |
| `arte/fundo.png`, `arte/brilho.png`, `arte/faixa.png` | sobras da v0.1 (não usadas; candidatas a remoção) |

## Como alterar

Nomes, fabricantes e cores ficam na tabela do script [ferramentas/tema/gerar-arte.ps1](../../ferramentas/tema/gerar-arte.ps1) (paleta do DESIGN.md; consoles sem cor usam `#888780`). Depois de editar:

```powershell
powershell -ExecutionPolicy Bypass -File ferramentas\tema\gerar-arte.ps1
powershell -ExecutionPolicy Bypass -File ferramentas\tema\gerar-arte.ps1 -Previa
powershell -ExecutionPolicy Bypass -File ferramentas\previa\instalar-previa.ps1
```

## Na imagem do EmuELEC

Pacote [packages/sx05re/emuelec-emulationstation/themes/es-theme-arcadia](../../packages/sx05re/emuelec-emulationstation/themes/es-theme-arcadia/package.mk): instala esta pasta em `/usr/config/emulationstation/themes/arcadia` e é dependência do EmulationStation; `ThemeSet=arcadia` é o padrão em `config/es_settings.cfg`.

## Cuidados (aprendidos na prévia)

- **Não usar `!=` em expressões** (`<visible>`): derruba o leitor de expressões do EmulationStation, que passa a dizer que o arquivo de sistemas é inválido. Use `!(a == b)`.
- Somar texto com número (`{system:total} + " jogos"`) não funciona; use dois textos com `<visible>` diferentes.
- Com `itemTemplate` na lista de jogos, a barra de seleção padrão some: ela é desenhada no próprio modelo (cor animada de transparente para `#2C2C2A`).
- O EmulationStation do EmuELEC é mais antigo que o do RetroBat; os recursos usados existem no código dele (`imagegrid`, `itemTemplate`, `rectangle`, `storyboard`, `{system:total}`), mas a confirmação final só no aparelho.

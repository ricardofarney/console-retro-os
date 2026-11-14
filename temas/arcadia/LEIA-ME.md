# Tema Arcádia (versão 0.1)

Tema do EmulationStation do projeto Arcádia, em português do Brasil, para o EmuELEC (e para a prévia no Windows com RetroBat — ver [docs/PREVIA-WINDOWS.md](../../docs/PREVIA-WINDOWS.md)).

## O que tem

- **Tela inicial:** fundo escuro, brilho na cor do console selecionado, carrossel horizontal com logotipos em texto (nome do console + fabricante).
- **Coleções em destaque:** "Continuar jogando" (`auto-lastplayed`), "Favoritos" (`auto-favorites`) e "Todos os jogos" (`auto-allgames`).
- **Listas de jogos:** faixa superior e seleção na cor do console; imagem, descrição, "última vez jogado", "vezes jogado" e gênero.
- **86 consoles** com nome e cor próprios; consoles sem arquivo usam o dourado padrão e o nome do sistema em texto.

## Estrutura

| Pasta/arquivo | Conteúdo |
|---|---|
| `theme.xml` | layout de todas as telas |
| `arte/` | fundo, brilho, faixa e painel (gerados) |
| `logos/<sistema>.png` | logotipos em texto (gerados) |
| `cores/<sistema>.xml` | cor de cada console (gerados) |

## Como alterar

Nomes, linhas de baixo e cores ficam na tabela do script [ferramentas/tema/gerar-arte.ps1](../../ferramentas/tema/gerar-arte.ps1). Depois de editar:

```powershell
powershell -ExecutionPolicy Bypass -File ferramentas\tema\gerar-arte.ps1
```

O layout (posições, tamanhos, textos fixos) fica no `theme.xml`.

## Ainda não feito

- Instalação automática na imagem do EmuELEC (pacote em `packages/sx05re/emuelec-emulationstation/themes/`) — próxima etapa da Fase 1.
- Logotipos desenhados (hoje são texto), fonte própria e vista em grade.

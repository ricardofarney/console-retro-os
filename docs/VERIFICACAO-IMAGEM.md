# Verificação automática da imagem

Script: [ferramentas/verificar-imagem.sh](../ferramentas/verificar-imagem.sh) — roda no Ubuntu do WSL e abre a imagem **sem gravar cartão**: descompacta o `.img.gz`, monta as partições (somente leitura) e o `SYSTEM` (squashfs), confere cada item e gera um relatório em `imagens-compiladas\logs\verificacao-<imagem>-<data>.md`.

```powershell
wsl -d Ubuntu-22.04 -- bash -c "tr -d '\r' < '/mnt/d/Adube Sistemas/Console de Jogo/console-retro-os/ferramentas/verificar-imagem.sh' > ~/verificar-imagem.sh; bash ~/verificar-imagem.sh"
```

Sem argumento, confere `Arcadia-Amlogic-ng.aarch64-<EE_VERSION>-Generic.img.gz`; aceita outro caminho como argumento. Sai com código 0 só se tudo estiver OK.

## Itens conferidos

| Item | Como |
|---|---|
| EmulationStation do fork (≥ `6ad7cae`) | binário aarch64 contém `ArcadiaMenuSimples`, `ArcadiaFavoriteSystems`, `FavoriteSystems` e os textos-fonte novos; mostra o `PKG_VERSION` do repositório |
| Textos novos em pt-BR | `emulationstation2.mo` contém CONTINUAR DE ONDE PAREI, COMEÇAR DO INÍCIO, FAVORITAR CONSOLE, MODO AVANÇADO, DESLIGAR COM SEGURANÇA, ONDE VOCÊ QUER COMEÇAR? |
| Tema arcadia padrão | `ThemeSet=arcadia` no `es_settings.cfg`; `theme.xml`, `splash.xml` e cards presentes |
| Idioma e fuso | `system.language=pt_BR`, `system.timezone=America/Sao_Paulo` no `emuelec.conf` |
| Salvamento automático | `global.autosave=1`, padrão `true` no `setsettings.sh`, `ShowSaveStates=true`, `autosave_interval = "10"` no RetroArch |
| "ONDE VOCÊ QUER COMEÇAR?" | `global.savestates=2` no `emuelec.conf`; `setsettings.sh` mantém o salvar ao sair em "COMEÇAR DO INÍCIO" |
| Coleções e ordem (DESIGN.md) | `CollectionSystemsAuto=recent,favorites,all` + função de ordem no binário |
| Consoles vazios escondidos | `LoadEmptySystems` não ligado (padrão `false` do ES esconde consoles sem jogos; Continuar jogando/Favoritos aparecem mesmo vazios — comprovado em [TESTE-WSLG.md](TESTE-WSLG.md)) |
| Desempenho S905X2 | `global.shaderset=none`; `retroarch-core-options.cfg` com N64 em 320×240 e PS1 em resolução nativa ([DESEMPENHO-S905X2.md](DESEMPENHO-S905X2.md)) |
| Ficha do jogo | tema usa `{game:releaseyear}` e esconde `md_releasedate` (sem "Lançamento: Desconhecido") |
| Senha do root | hash em `/usr/cache/shadow` (permissão 000, lido com `sudo`) não confere com `emuelec` |
| Atualização | `updatecheck.sh` com `versoes.txt` e Releases de `ricardofarney/console-retro-os`, arquivo `Arcadia-*`, comparação X.Y.Z |
| Proteção de dados | sem `clearconfig EMUS`; `emuelec-upgrade` (em `/usr/bin/batocera/`) chama `arcadia-dados.sh backup`; `emuelec_autostart.sh` migra gamelists |
| DTBs do S905X2 | `device_trees/g12a_s905x2_2g.dtb` e `g12a_s905x2_2g_1gbit.dtb` na partição de boot |

## Resultados

### 15/11/2026 01:18 — imagem 1.0.0 do build de 14/11 (commit `ae97c2b`)

**10 OK, 1 FALHOU**

- ❌ Consoles/coleções vazios escondidos: o script procurava uma configuração que não existe. Na Etapa 2 (teste no WSLg) ficou provado que o ES já esconde consoles sem jogos por padrão (`LoadEmptySystems=false`), e o item passou a conferir isso. A Etapa 2 também acrescentou 2 itens: escolha de save e ficha sem "Desconhecido".
- Primeira rodada (01:17) acusou também a senha do root e a proteção de dados por erro **do script** (arquivo de senhas com permissão 000 lido sem `sudo`; `emuelec-upgrade` procurado em `/usr/bin` em vez de `/usr/bin/batocera`). Corrigido no script; na imagem estava tudo certo.
- DTBs do S905X2 presentes: `g12a_s905x2_2g.dtb`, `g12a_s905x2_2g_1gbit.dtb`, `g12a_s905x2_4g.dtb`, `g12a_s905x2_4g_1gbit.dtb` (+ Beelink); 75 DTBs ao todo.

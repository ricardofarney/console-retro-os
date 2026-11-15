# Verificação automática da imagem

Script: [ferramentas/verificar-imagem.sh](../ferramentas/verificar-imagem.sh) — roda no Ubuntu do WSL e abre a imagem **sem gravar cartão**: descompacta o `.img.gz`, monta as partições (somente leitura) e o `SYSTEM` (squashfs), confere cada item e gera um relatório em `imagens-compiladas\logs\verificacao-<imagem>-<data>.md`.

```powershell
wsl -d Ubuntu-22.04 -- bash -c "tr -d '\r' < '/mnt/d/Adube Sistemas/Console de Jogo/console-retro-os/ferramentas/verificar-imagem.sh' > ~/verificar-imagem.sh; bash ~/verificar-imagem.sh"
```

Sem argumento, confere `Arcadia-Amlogic-ng.aarch64-<EE_VERSION>-Generic.img.gz`; aceita outro caminho como argumento. Sai com código 0 só se tudo estiver OK.

## Itens conferidos

| Item | Como |
|---|---|
| EmulationStation do fork (≥ `0c64beb`) | binário aarch64 contém `ArcadiaMenuSimples`, `ArcadiaFavoriteSystems`, `FavoriteSystems` e os textos-fonte novos; mostra o `PKG_VERSION` do repositório |
| Textos novos em pt-BR | `emulationstation2.mo` contém CONTINUAR DE ONDE PAREI, COMEÇAR DO INÍCIO, FAVORITAR CONSOLE, MODO AVANÇADO, DESLIGAR COM SEGURANÇA, ONDE VOCÊ QUER COMEÇAR? |
| Tema arcadia padrão | `ThemeSet=arcadia` no `es_settings.cfg`; `theme.xml`, `splash.xml` e cards presentes |
| Idioma e fuso | `system.language=pt_BR`, `system.timezone=America/Sao_Paulo` no `emuelec.conf` |
| Salvamento automático | `global.autosave=1`, padrão `true` no `setsettings.sh`, `ShowSaveStates=true`, `autosave_interval = "10"` no RetroArch |
| Coleções e ordem (DESIGN.md) | `CollectionSystemsAuto=recent,favorites,all` + função de ordem no binário |
| Consoles/coleções vazios escondidos | configuração/função de esconder sistemas sem jogos (exceto Continuar jogando/Favoritos) |
| Senha do root | hash em `/usr/cache/shadow` (permissão 000, lido com `sudo`) não confere com `emuelec` |
| Atualização | `updatecheck.sh` com `versoes.txt` e Releases de `ricardofarney/console-retro-os`, arquivo `Arcadia-*`, comparação X.Y.Z |
| Proteção de dados | sem `clearconfig EMUS`; `emuelec-upgrade` (em `/usr/bin/batocera/`) chama `arcadia-dados.sh backup`; `emuelec_autostart.sh` migra gamelists |
| DTBs do S905X2 | `device_trees/g12a_s905x2_2g.dtb` e `g12a_s905x2_2g_1gbit.dtb` na partição de boot |

## Resultados

### 15/11/2026 01:18 — imagem 1.0.0 do build de 14/11 (commit `ae97c2b`)

**10 OK, 1 FALHOU**

- ❌ Consoles/coleções vazios escondidos: função ainda não existia nesta imagem (implementada na Etapa 2, item 8).
- Primeira rodada (01:17) acusou também a senha do root e a proteção de dados por erro **do script** (arquivo de senhas com permissão 000 lido sem `sudo`; `emuelec-upgrade` procurado em `/usr/bin` em vez de `/usr/bin/batocera`). Corrigido no script; na imagem estava tudo certo.
- DTBs do S905X2 presentes: `g12a_s905x2_2g.dtb`, `g12a_s905x2_2g_1gbit.dtb`, `g12a_s905x2_4g.dtb`, `g12a_s905x2_4g_1gbit.dtb` (+ Beelink); 75 DTBs ao todo.

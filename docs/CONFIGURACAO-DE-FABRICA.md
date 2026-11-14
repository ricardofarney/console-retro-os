# Configuração de fábrica da imagem Arcádia

Aplicada em 14/11/2026 (horário de Brasília) — Etapa 4 (itens 3, 4 e 6 do plano da Fase 1 em [ANALISE-INICIAL.md](ANALISE-INICIAL.md#6-plano-da-fase-1)).

Lembrete: os padrões abaixo valem para **cartões novos** (no primeiro boot o EmuELEC copia `/usr/config/...` para `/storage/...`). Num cartão já em uso valem os arquivos em `/storage`.

## Idioma, fuso e nome na rede

| Item | Arquivo | Valor |
|---|---|---|
| Idioma | [emuelec.conf](../packages/sx05re/emuelec/config/emuelec/configs/emuelec.conf) | `system.language=pt_BR` (EmulationStation e RetroArch) |
| Fuso horário | `emuelec.conf` | `system.timezone=America/Sao_Paulo` |
| Nome na rede | `emuelec.conf` | `system.hostname=ARCADIA` (`\\ARCADIA`, `ssh root@ARCADIA`) |

## Tela inicial e coleções

| Item | Arquivo | Valor |
|---|---|---|
| Tema | [es_settings.cfg](../packages/sx05re/emuelec-emulationstation/config/es_settings.cfg) | `ThemeSet=arcadia` (pacote `es-theme-arcadia`) |
| Coleções | `es_settings.cfg` | `CollectionSystemsAuto=recent,favorites,all` (Continuar jogando, Favoritos, Todos os jogos) |
| Escolha de save ao abrir jogo | `es_settings.cfg` | `ShowSaveStates=true` (janela "Continuar de onde parei / Começar do início" — textos no `arcadia-emulationstation`) |
| Favoritos no topo das listas | `es_settings.cfg` | `FavoritesFirst=true` (já era padrão) |

## Salvamento automático em todos os sistemas

| Camada | Arquivo | Mudança |
|---|---|---|
| Opção geral | `emuelec.conf` | `global.autosave=1` (antes comentado) |
| Padrão aplicado a cada jogo | [setsettings.sh](../packages/sx05re/emuelec/bin/setsettings.sh) (`default_settings`) | `savestate_auto_save` e `savestate_auto_load` = `"true"` (antes `"false"`) |
| Save da bateria (.srm) | [retroarch/package.mk](../packages/sx05re/libretro_base/retroarch/package.mk) | `autosave_interval = "10"` (grava a cada 10 s; protege contra desligar na tomada) |

Emuladores standalone (PPSSPP, Flycast SA, DuckStation SA, Mupen64Plus SA, Dolphin…) não usam essas opções do RetroArch.

## Proteção de saves e favoritos nas atualizações

| Risco | Correção |
|---|---|
| "Atualização forçada" apagava quase todo o `/storage` (`emuelec-utils clearconfig EMUS`) | removido de [updatecheck.sh](../packages/sx05re/emuelec/bin/updatecheck.sh); no lugar, cópia de segurança |
| Atualização normal sem backup | [emuelec-upgrade](../packages/sx05re/emuelec/bin/batocera/emuelec-upgrade) chama `arcadia-dados.sh backup` antes de baixar |
| `gamelist.xml` (favoritos, últimos jogados) podia ficar em `~/.emulationstation/gamelists` | a cada boot, [emuelec_autostart.sh](../packages/sx05re/emuelec/bin/emuelec_autostart.sh) chama `arcadia-dados.sh migrar-gamelists`, que copia para `/storage/roms/<sistema>/gamelist.xml` (o original vira `gamelist.xml.migrado`) |

Script novo: [packages/sx05re/emuelec/bin/arcadia-dados.sh](../packages/sx05re/emuelec/bin/arcadia-dados.sh)

- `backup`: grava `/storage/roms/backup/arcadia/antes-da-atualizacao-AAAA-MM-DD_HHMM.tar.gz` com `emuelec.conf`, `es_settings.cfg`, `es_input.cfg`, coleções, gamelists antigos, configurações do RetroArch e do PPSSPP, Bluetooth, fuso e nome; mantém os **3** mais recentes. Não usa o nome `ee_backup_config.tar.gz` de propósito: esse arquivo é **restaurado automaticamente no boot** pelo EmuELEC.
- Saves (`.srm` ao lado das roms) e save states (`/storage/roms/savestates/`) já ficam em `/storage/roms`, que nenhuma atualização apaga.
- Para restaurar manualmente: `tar -xzf /storage/roms/backup/arcadia/<arquivo>.tar.gz -C /` e reiniciar.

## Segurança

| Acesso | Antes | Agora |
|---|---|---|
| SSH (`root`) | senha conhecida `emuelec` | senha gerada, guardada em `docs/SENHAS-LOCAIS.md` (**fora do Git**) |
| Pastas de rede (Samba) | sem senha (convidado = root) | usuário `arcadia` com senha gerada (mesmo arquivo); `SAMBA_SECURE="true"` |

Como funciona: [distributions/EmuELEC/options](../distributions/EmuELEC/options) usa `ROOT_PASSWORD="${ARCADIA_ROOT_PASSWORD:-emuelec}"` e o [pacote samba](../packages/network/samba/package.mk) troca `@ARCADIA_SAMBA_PASSWORD@` na instalação. O [compilar.ps1](../ferramentas/wsl/compilar.ps1) lê as senhas de `docs/SENHAS-LOCAIS.md` e passa ao build pelo `WSLENV`; o [compilar.sh](../ferramentas/wsl/compilar.sh) recompila `busybox` e `samba` quando elas mudam. Sem o arquivo, a imagem sai com as senhas padrão e o log avisa.

Avaliação do Samba: numa rede doméstica o risco é baixo, mas sem senha qualquer aparelho da rede pode apagar roms e saves (o convidado tinha permissão de root). A senha custa só digitá-la uma vez no Windows (que pode lembrar), por isso ficou **ligada**. Para desligar: `SAMBA_SECURE="false"` em `/storage/.cache/services/samba.conf` no aparelho.

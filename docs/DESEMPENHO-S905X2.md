# Desempenho no S905X2 (2 GB): padrões de fábrica

**Aparelho:** KINHANK Super Console X2 Pro. Processador Amlogic S905X2 (4× Cortex-A53, até 1,8 GHz), GPU Mali-G31 MP2, 2 GB de RAM. É a mesma família (g12a) usada pelos desenvolvedores do EmuELEC, então os padrões do EmuELEC já foram pensados para ele.

**Data:** 15/11/2026. Nada aqui foi medido no aparelho: o PC não reproduz o desempenho do S905X2. Os itens marcados **CONFIRMAR** precisam de teste quando o aparelho chegar.

## Fontes consultadas

**Relatos da comunidade**, todos de usuários, não de testes oficiais:
- [EmuELEC — Nintendo 64 is slow](https://emuelec.discourse.group/t/nintendo-64-is-slow/1987): N64 lento num S905X2 depois de atualizar o EmuELEC. A sugestão é baixar a resolução e usar "Fullspeed" ou o núcleo ParaLLEl.
- [EmuELEC — Ways to improve performance and graphics for N64 and Dreamcast](https://emuelec.discourse.group/t/ways-to-improve-performance-and-graphics-for-n64-and-dreamcast/2040): no N64, a resolução é o que mais pesa; emulação de framebuffer pode ajudar ou causar falhas gráficas.
- [EmuELEC — Help with a new s905 box](https://emuelec.discourse.group/t/help-with-a-new-s905-box/1348).
- [Bytes N Bits — Android TV box with EmuELEC](https://bytesnbits.co.uk/android-tv-box-emuelec/): S905X2/X3; ParaLLEl N64 "um pouco menos preciso, mas em velocidade cheia".

**Desenvolvedores do libretro:**
- [libretro — Mupen64Plus-Next 2.0](https://www.libretro.com/index.php/mupen64plus-next-2-0-64dd-support-angrylion-and-gliden64-in-one-build-parallel-rsp-support-and-android/): Mupen64Plus-Next é, em média, um pouco mais rápido que o ParaLLEl N64 e mais compatível.
- [libretro forums — Parallel core vs Mupen64Plus-Next](https://forums.libretro.com/t/parallel-core-vs-mupen64plus-next/50916).

**Código dos próprios núcleos** que vão na imagem: nomes e valores exatos das opções (`libretro_core_options.h` do mupen64plus_next `222acbd` e do pcsx_rearmed `228c14e`).

Não achei uma tabela "oficial" de ajustes para o S905X2. Os relatos às vezes se contradizem (o mesmo jogo "lento" para um e "em velocidade cheia" para outro), por isso tudo que é desempenho fica para conferir no aparelho.

## O que ficou de fábrica no Arcádia

### Núcleo padrão por console

O EmuELEC já usa, para o S905X2, os núcleos leves que a comunidade recomenda. **Mantive todos**, com estes motivos:

| Console | Núcleo padrão | Por quê | Alternativa (se ficar lento) |
|---|---|---|---|
| PS1 | `pcsx_rearmed_32b` | O mais leve para ARM: recompilador dinâmico e GPU NEON. Os outros (SwanStation, DuckStation) são mais pesados. | — |
| N64 | `mupen64plus_next` (GLideN64) | Mais rápido em média e mais compatível que o ParaLLEl, segundo o libretro. O que pesa é a resolução, que foi reduzida (abaixo). | `parallel_n64_32b` (já configurado com Rice e 320×240), escolhido por jogo em Opções do jogo → Emulador. **CONFIRMAR** qual vai melhor em cada jogo. |
| Arcade (`arcade`) | `mame2003_plus` | O MAME leve; o `mame` (atual) é pesado demais para o S905X2 | `fbneo` para jogos Capcom/SNK |
| MAME (`mame`) | AdvanceMame (standalone) | Feito para hardware fraco | `mame2003_plus` |
| Neo Geo | `fbneo` | Velocidade cheia em ARM | — |
| SNES | `snes9x` | Velocidade cheia em A53 de 1,8 GHz para quase tudo | `snes9x2010` para jogos com chip Super FX/SA-1 (Star Fox, Yoshi's Island…), se engasgarem. **CONFIRMAR** |
| Mega Drive / Mega CD | `genesis_plus_gx` | Leve e preciso | `picodrive` (o mais leve; obrigatório no 32X) |
| Master System | `gearsystem` | Leve | `genesis_plus_gx` |
| NES / GB / GBC / GBA | `nestopia`, `gambatte`, `mgba` | Leves; testados no PC (NES, GBC) | `fceumm` no NES, `gpsp` no GBA |
| PSP | PPSSPP standalone | Resolução 1× e frameskip automático já definidos por jogo pelo EmuELEC | — |
| Dreamcast | `flycast` (renderização em thread já ligada) | É o limite do S905X2. **CONFIRMAR** | `flycast_32b` |
| Saturn | `yabasanshiroSA1_5` | O único com chance no S905X2. **CONFIRMAR** (muitos jogos lentos) | — |

### Resolução interna e quadros

Arquivo: [packages/sx05re/emuelec/config/retroarch/retroarch-core-options.cfg](../packages/sx05re/emuelec/config/retroarch/retroarch-core-options.cfg). É copiado para `/storage/.config/retroarch/` no primeiro boot e não sobrescreve ajustes do usuário em atualizações.

| Opção | Valor de fábrica | Antes (padrão do núcleo) | Efeito |
|---|---|---|---|
| `mupen64plus-43screensize` | `320x240` | `640x480` | N64 na resolução original: 4× menos pixels para a Mali-G31 |
| `mupen64plus-169screensize` | `640x360` | `640x360` | Só vale com tela 16:9 forçada. Fica explícito. |
| `mupen64plus-FrameDuping` | `True` | `False` | Se o jogo não alcança 60 fps, repete o quadro em vez de engasgar o som |
| `pcsx_rearmed_neon_enhancement_enable` | `disabled` | `disabled` | PS1 em resolução nativa. Fica explícito. |
| `pcsx_rearmed_frameskip_type` | `disabled` | `disabled` | PS1 não pula quadros (roda cheio no S905X2). Fica explícito. |
| `pcsx_rearmed_gpu_thread_rendering` | `sync` | `disabled` | GPU do PS1 numa thread separada, com o ritmo dos quadros preservado. **CONFIRMAR**: a opção só existe se o núcleo for compilado com `THREAD_RENDERING`; se não existir, é ignorada. |
| `parallel-n64-screensize` / `gfxplugin` | `320x240` / `rice` | (EmuELEC) | Já vinha do EmuELEC. Mantido. |
| `reicast_threaded_rendering` | `enabled` | (EmuELEC) | Já vinha do EmuELEC. Mantido. |

**Frameskip:** fica **desligado** em todos os consoles, porque pular quadros deixa o jogo "picotado". O N64 usa a repetição de quadro acima. No PSP, o frameskip automático vem dos arquivos por jogo do EmuELEC. Para ligar num console específico: Opções do jogo → Opções do núcleo.

### Shaders

`global.shaderset=none` no `emuelec.conf`, agora explícito (antes vinha comentado, com o mesmo efeito). Nenhum console tem shader próprio de fábrica. Shaders de CRT custam caro na Mali-G31.

### Saída de vídeo

`ee_videomode=1080p60hz`, mantido. A tela inicial e os consoles 2D ficam nítidos em TV Full HD. Os 3D (PS1 e N64) renderizam na resolução nativa acima, e só a ampliação final é em 1080p, o que custa pouco.

Se algum console 3D ficar lento ou a TV não aceitar 1080p: Modo avançado → EmuELEC Settings → Video Mode → `720p60hz`. **CONFIRMAR** na TV que vai ser usada.

## Para conferir quando o aparelho chegar

Abrir com o FPS ligado (Modo avançado → Ajustes de jogo → Mostrar FPS) e anotar aqui:

| Console | Jogo de teste sugerido | O que olhar | Resultado |
|---|---|---|---|
| PS1 | Crash Bandicoot, Gran Turismo 2 | 60/50 fps estáveis; som sem estalos | |
| N64 | Super Mario 64, Mario Kart 64, GoldenEye | fps; falhas gráficas com 320×240; comparar com `parallel_n64_32b` | |
| SNES | Star Fox, Yoshi's Island | engasgos no Super FX → trocar para `snes9x2010` | |
| Arcade | Metal Slug (fbneo), jogos CPS2 | fps e som | |
| Dreamcast | Sonic Adventure, Crazy Taxi | jogável ou não | |
| PSP | Jogos 2D e 3D leves | fps com frameskip automático | |
| Geral | — | `pcsx_rearmed_gpu_thread_rendering` aparece nas Opções do núcleo? Temperatura depois de 30 min | |

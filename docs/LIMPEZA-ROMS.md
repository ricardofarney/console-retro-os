# Limpeza de ROMs (`limpar-roms.py`)

Criada em 14/11/2026 (horário de Brasília). Ferramenta de linha de comando para organizar a pasta `roms` do Arcádia (padrão EmuELEC/RetroBat, uma subpasta por console) antes de copiá-la para o aparelho.

- Script: `ferramentas\roms\limpar-roms.py` (Python 3, só biblioteca padrão — não precisa instalar nada)
- Atalho PowerShell: `ferramentas\roms\limpar-roms.ps1` (repassa os argumentos para o .py)
- Cache (DATs baixadas, temporários, pasta de teste): `ferramentas\roms\.cache\` — fica fora do git (`.gitignore`)

## O que ela faz

Para cada subpasta de console reconhecida (`nes`, `snes`, `megadrive`/`genesis`, `mastersystem`, `gamegear`, `gb`, `gbc`, `gba`, `n64`, `psx`, `ps2`, `pcengine`, `neogeo`, `atari2600`, `segacd`, `saturn`, `dreamcast` e outras — a tabela completa está em `SISTEMAS` no começo do script):

1. **Duplicados e versões do mesmo jogo**
   - **Duplicado exato**: arquivos com conteúdo idêntico (mesmo SHA1), mesmo com nomes diferentes. Também vale para a ROM dentro de um `.zip` (um `Jogo.nes` e um `Jogo.zip` com a mesma ROM dentro são duplicados).
   - **Versões do mesmo jogo**: pelo nome normalizado, sem as tags entre parênteses/colchetes (regiões, `Rev 1`, `v1.1`, `[!]`, `(Beta)`...). Ex.: `Sonic (USA)`, `Sonic (Europe) (Rev 1)` e `Sonic (Japan) [!]` são o mesmo jogo. O número do disco conta (`(Disc 1)` e `(Disc 2)` **não** são duplicados).
   - **DATs No-Intro (cartuchos) / Redump (discos)**: o CRC32 de cada ROM (inclusive dentro de `.zip`, e também sem o cabeçalho de 16 bytes do `.nes`) é comparado com as DATs públicas do [libretro-database](https://github.com/libretro/libretro-database) (`metadat/no-intro` e `metadat/redump`). Quando a ROM é reconhecida, o nome oficial também entra no agrupamento (um `smb.nes` é reconhecido como "Super Mario Bros. (World)") e é usado para achar a capa. As DATs são baixadas para `.cache\dats\` e reaproveitadas por 30 dias.
2. **Mantém UMA versão por jogo**, nesta ordem de prioridade:
   1. Tradução em **português (PT-BR)** — tags como `(PT-BR)`, `[T-Por]`, `[T+Bra]`, `(Traduzido)`, `PTBR`, `Português`, e lançamentos oficiais `(Brazil)`/`(Brasil)`;
   2. **EUA** (`USA`, `U`) — `World`/`Mundo` conta como EUA;
   3. **Europa** (`Europe`, `E`, e países europeus);
   4. arquivo **sem tag de região** (ex.: `Miniplanets.bin`) — se a DAT reconhecer a ROM, vale a região do nome oficial;
   5. **Japão** (`Japan`, `J`);
   6. outras regiões (Coreia, China, Ásia...);
   7. **hacks** (`(Hack)`, `[h]`, traduções para outras línguas `[T+Eng]`, trainers `[t]`) ficam por último em qualquer região.

   Desempates, nesta ordem: versão final ganha de `Beta`/`Proto`/`Demo`/`Sample`/`Pirate` (mesmo de outra região); revisão mais nova (`Rev 2` > `Rev 1`, `v1.1` > `v1.0`); dump verificado `[!]`; versão principal ganha de alternativa `[a]`; dumps marcados como ruins `[b]`/`[o]` sempre perdem; por fim, o nome mais curto.
3. **Move** (nunca apaga) os descartados para `<roms>\_removidos\<console>\`, mantendo o nome. Se já existir um arquivo com o mesmo nome lá, recebe sufixo numérico (`Jogo (USA)__2.nes`). Jogos de disco andam juntos: `.m3u` + `.cue` + `.bin` (ou `.gdi` + faixas, `.ccd` + `.img`/`.sub`, `.mds` + `.mdf`) são movidos como um conjunto, mantendo a estrutura de subpastas; se colidir, o conjunto inteiro vai para uma subpasta numerada (`_removidos\psx\_2\...`). A pasta `_removidos` (e qualquer pasta que comece com `_` ou `.`) nunca é tratada como console.
4. **Corrompidos / não abrem** — só **listados** no relatório (não são movidos, a não ser com `--mover-corrompidos`, que os leva para `_removidos\<console>\corrompidos\`). Verificações:
   - arquivo com tamanho zero;
   - `.zip` inválido, vazio ou com CRC errado (`zipfile.testzip`); `.7z` só pela assinatura (a biblioteca padrão não abre 7z);
   - cabeçalho: NES (`NES\x1a`), FDS, Game Boy/Color (logo da Nintendo + checksum do cabeçalho), GBA (logo + checksum), Mega Drive (`SEGA` em 0x100, ou formato `.smd` intercalado), Nintendo 64, Atari 7800 (`.a78`), Lynx (`.lnx`), `.chd` e `.pbp` (assinatura);
   - `.cue`/`.gdi`/`.m3u` apontando para arquivo inexistente.

   Arquivos corrompidos ficam fora da escolha de versões (nunca "ganham" de um arquivo bom, e nunca são movidos como duplicado).
5. **Capas** do [libretro-thumbnails](https://thumbnails.libretro.com) (gratuito, sem conta): `https://thumbnails.libretro.com/<sistema libretro>/Named_Boxarts/<nome>.png`, com os caracteres `&*/:`<>?\|"` trocados por `_`. Tenta, nesta ordem: nome do jogo na DAT, nome da ROM na DAT, nome do arquivo e outras versões do mesmo jogo na DAT. Salva em `<roms>\<console>\images\<nome do arquivo sem extensão>.png`. Jogo que já tem capa (no gamelist ou em `images\`) não é baixado de novo. Não achar capa não é erro.
6. **gamelist.xml** (formato EmulationStation) de cada console:
   - **preserva tudo o que já existe** (`favorite`, `lastplayed`, `playcount`, `desc`, `genre`, `rating`, comentários etc.) e só acrescenta o que falta: entrada para jogos sem entrada (`<path>` + `<name>`), `<image>` quando baixou/achou capa;
   - remove as entradas dos jogos que foram para `_removidos` e as guarda (intactas, com um comentário de data e motivo) em `_removidos\<console>\gamelist-removidos.xml`;
   - antes de alterar, faz backup do original como `gamelist.xml.bak-AAAAMMDD-HHMM` (só quando há alteração); mantém o fim de linha do original.
7. **Relatório** em `<roms>\_relatorios\limpeza-AAAA-MM-DD_HHMM.md` (e `.txt` com `--txt`): resumo geral, e por console: antes/depois (quantidade e tamanho), movidos com o motivo e qual versão ficou, corrompidos, capas baixadas/não encontradas, alterações no gamelist. Na simulação o nome termina em `-simulacao.md`.

Pastas sem mapeamento (ex.: `ports`, `halflife`, `sonic-mania`) e arquivos que não são jogos (`_info.txt`, `.ini`, `.xml`...) são ignorados e não são tocados; as pastas ignoradas com arquivos aparecem no fim do relatório.

## Como usar no Windows

Abra o PowerShell (não precisa ser administrador) e vá até a pasta da ferramenta:

```powershell
cd "D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\roms"
```

**Sempre rode primeiro em simulação** e leia o relatório:

```powershell
python limpar-roms.py "D:\Adube Sistemas\Console de Jogo\arcadia-preview\roms" --simular
```

Se estiver tudo certo, rode de verdade:

```powershell
python limpar-roms.py "D:\Adube Sistemas\Console de Jogo\arcadia-preview\roms"
```

Outros exemplos:

```powershell
# Pelo atalho PowerShell (mesmos argumentos)
.\limpar-roms.ps1 "E:\roms" --simular

# Só alguns consoles, sem capas, relatório também em .txt
python limpar-roms.py "E:\roms" --consoles nes,snes,megadrive --sem-capas --txt

# Sem internet / sem DATs (só nomes e hashes locais)
python limpar-roms.py "E:\roms" --sem-dat --sem-capas

# Também tirar da pasta os arquivos corrompidos
python limpar-roms.py "E:\roms" --mover-corrompidos
```

| Opção | Efeito |
|---|---|
| `--simular` | Não move, não baixa capas e não altera nenhum arquivo da pasta `roms`; só gera o relatório (em `_relatorios`). As DATs ainda podem ser baixadas para o cache da ferramenta (para a simulação dar o mesmo resultado da execução real) e as capas são só consultadas (HEAD), sem baixar. |
| `--sem-capas` | Não procura/baixa capas (o gamelist continua sendo atualizado para os jogos movidos). |
| `--sem-dat` | Não usa DATs No-Intro/Redump. Duplicados exatos continuam sendo achados pelo SHA1. |
| `--mover-corrompidos` | Move os corrompidos para `_removidos\<console>\corrompidos\`. |
| `--txt` | Gera também o relatório em `.txt`. |
| `--consoles a,b,c` | Processa só essas subpastas. |
| `--limite-hash-mb N` | Não calcula hash de arquivos maiores que N MB (padrão 1024). Esses arquivos não entram na detecção de duplicado exato nem na DAT, mas continuam na comparação por nome. |
| `--atualizar-dats` | Baixa as DATs de novo mesmo com cache recente. |

Se o PowerShell bloquear o `.ps1`, rode antes `Set-ExecutionPolicy -Scope Process Bypass` (vale só para aquela janela, não exige administrador) ou use o `python limpar-roms.py ...` direto.

## Onde ficam as coisas

| O quê | Onde |
|---|---|
| Jogos descartados (duplicados/versões) | `<roms>\_removidos\<console>\` |
| Corrompidos (só com `--mover-corrompidos`) | `<roms>\_removidos\<console>\corrompidos\` |
| Entradas de gamelist dos jogos removidos | `<roms>\_removidos\<console>\gamelist-removidos.xml` |
| Backup do gamelist antes da alteração | `<roms>\<console>\gamelist.xml.bak-AAAAMMDD-HHMM` |
| Capas baixadas | `<roms>\<console>\images\<jogo>.png` |
| Relatórios | `<roms>\_relatorios\limpeza-AAAA-MM-DD_HHMM.md` |
| DATs baixadas | `console-retro-os\ferramentas\roms\.cache\dats\` |

Ao copiar a pasta `roms` para o aparelho, **não copie** `_removidos` nem `_relatorios` (não atrapalham o EmulationStation, mas ocupam espaço).

## Como desfazer

Nada é apagado, então dá para voltar tudo:

1. **Jogos**: mova os arquivos de `<roms>\_removidos\<console>\` de volta para `<roms>\<console>\` (se houver subpastas, mantenha a mesma estrutura; arquivos com sufixo `__2` precisam ter o sufixo retirado; conjuntos em `_2\` voltam sem o `_2`). Exemplo no PowerShell, para o NES:

   ```powershell
   $roms = "D:\Adube Sistemas\Console de Jogo\arcadia-preview\roms"
   Get-ChildItem "$roms\_removidos\nes" -File -Exclude gamelist-removidos.xml |
       Move-Item -Destination "$roms\nes"
   ```

   (o `Move-Item` avisa e não sobrescreve se já existir um arquivo com o mesmo nome.)
2. **gamelist.xml**: volte o backup — renomeie `gamelist.xml.bak-AAAAMMDD-HHMM` para `gamelist.xml` (guarde antes o atual, se quiser). Ou copie as entradas `<game>` de `_removidos\<console>\gamelist-removidos.xml` de volta para dentro do `<gameList>` do console.
3. **Capas**: são só arquivos novos em `images\`; podem ficar ou ser movidos para outro lugar.

## Limitações conhecidas

- **Agrupamento por nome**: jogos diferentes com o mesmo título normalizado seriam tratados como versões do mesmo jogo (raro em No-Intro; mais comum com nomes "livres"). Por outro lado, nomes muito diferentes da mesma ROM só são juntados se a DAT reconhecer o arquivo ou se forem idênticos byte a byte. Por isso: **sempre simule e leia o relatório antes**.
- **Arquivo sem região × região explícita**: sem DAT, `Jogo.bin` (sem tag) perde para `Jogo (Europe).bin` e ganha de `Jogo (Japan).bin`. Com DAT, vale a região do nome oficial.
- **Traduções e hacks** quase nunca estão nas DATs; para eles vale só o que está escrito no nome do arquivo. Uma tradução PT-BR precisa ter a marca no nome (`PT-BR`, `T-Por`, `T+Bra`, `Traduzido`, `Português`...).
- **`.7z`**: a biblioteca padrão do Python não abre 7z; só a assinatura é conferida e não há hash/DAT para eles (entram só na comparação por nome). `.rar` não é suportado.
- **Arcade** (`neogeo`): romsets não são agrupados por versão (clones dependem dos pais); só a integridade do zip é verificada. Capas de arcade usam o nome descritivo do jogo, que o nome curto do zip (`mslug.zip`) não fornece — normalmente não são encontradas.
- **Discos**: o hash é do `.bin`/`.iso`/`.chd` inteiro (limite padrão de 1 GB por arquivo); `.chd`, `.pbp`, `.cso` e `.rvz` não casam com a Redump (que lista as faixas originais). Jogos de disco em CHD contam só pela comparação por nome e pelo duplicado exato.
- **Cabeçalhos**: não há checagem para SNES, Master System, Game Gear, PC Engine etc. (só zero bytes / zip). A checagem do Mega Drive pode acusar alguns cartuchos não licenciados sem a palavra `SEGA`; a do Game Boy acusa traduções/hacks que não corrigiram o checksum do cabeçalho — por isso corrompidos só são listados.
- **Capas**: o libretro-thumbnails cobre bem os jogos comerciais com nomes No-Intro/Redump; homebrews e arquivos com nomes fora do padrão costumam ficar sem capa. A capa de um jogo movido continua em `images\` (não é movida).
- **gamelist.xml**: é regravado com indentação por tabulação e declaração `encoding="UTF-8"` (o conteúdo é preservado; só a formatação pode mudar). Se o gamelist estiver com XML inválido, ele não é alterado (aparece como erro no relatório).
- Subpastas que ficarem vazias depois da limpeza não são apagadas.

## Registro do teste (14/11/2026, horário de Brasília)

Ambiente: Windows 11, Python 3.12.10. DATs usadas: `no-intro/Nintendo - Nintendo Entertainment System.dat`, `Sega - Mega Drive - Genesis.dat`, `Nintendo - Game Boy Color.dat` e `redump/Sony - PlayStation.dat` (versões de 07/10/2026 do libretro-database).

### 1. Pasta de teste com versões fictícias

Pasta `console-retro-os\ferramentas\roms\.cache\teste\roms` (fora do git), montada por `.cache\montar-teste.py` só com cópias dos homebrews livres da prévia (sem jogos comerciais). Cada "versão regional" é uma cópia do Nova the Squirrel com o último byte alterado (para não serem duplicados exatos entre si):

- `nes`: `Nova the Squirrel` em `(USA)`, `(Europe)`, `(Japan)`, `(PT-BR)`, `(USA) (Hack)`, `(USA) (Beta)` e `(World).zip`; `Quebrado (USA).nes` (0 bytes); `Arquivo Invalido (USA).zip` (lixo); `Cabecalho Ruim (USA).nes` (sem `NES\x1a`); `Thwaite (USA).nes`, `Thwaite Copia (USA).nes` (cópia idêntica) e `Thwaite (World).zip` (mesma ROM dentro de zip); `_info.txt`; `gamelist.xml` com entradas favoritas para a versão USA e para a PT-BR;
- `megadrive`: `Miniplanets.bin` original + `Miniplanets (Europe).bin` alterado, com o gamelist da prévia;
- `gbc`: `uCity.gbc` original + `uCity Checksum Ruim (USA).gbc` (cabeçalho alterado), com o gamelist da prévia;
- `psx`: `Jogo de Disco (USA)` e `(Japan)` (`.cue` + `.bin` cada), `Faltando (USA).cue` (aponta para `.bin` inexistente) e `Aventura (USA).m3u` com dois discos (`.cue` + `.bin`) numa subpasta;
- `ports` (pasta sem mapeamento) e `snes` só com `_info.txt`.

**Simulação (`--simular`)**: 4 consoles, 21 jogos antes → 11 depois, 10 seriam movidos (1,9 MB), 5 corrompidos, 1 capa disponível. Conferido depois: nenhum arquivo movido, nenhum gamelist alterado, só o relatório `-simulacao.md` criado.

**Execução real**: mesmo resultado, agora aplicado:

| Console | Antes | Depois | Movidos | Corrompidos | Capas novas | Sem capa | Reconhecidos pela DAT |
|---|---|---|---|---|---|---|---|
| gbc | 2 (256,0 KB) | 2 (256,0 KB) | 0 | 1 | 0 | 1 | 1/2 |
| megadrive | 2 (1,0 MB) | 1 (512,0 KB) | 1 | 0 | 1 | 0 | 1/2 |
| nes | 13 (1,9 MB) | 5 (536,2 KB) | 8 | 3 | 0 | 2 | 3/13 |
| psx | 4 (12,4 KB) | 3 (8,4 KB) | 1 | 1 | 0 | 2 | 0/4 |
| **Total** | **21 (3,2 MB)** | **11 (1,3 MB)** | **10** | **5** | **1** | **5** | |

Conferências:

- **NES**: ficou `Nova the Squirrel (PT-BR).nes`; foram para `_removidos\nes\` as versões USA, Europe, Japan, Hack, Beta e World.zip (motivo: "tradução PT-BR tem prioridade"). `Thwaite Copia (USA).nes` e `Thwaite (World).zip` foram movidos como **duplicado exato** de `Thwaite (USA).nes` (o do zip pelo SHA1 da ROM interna). Os 3 Thwaite foram reconhecidos pela DAT ("Thwaite (World) (Proto 4)", CRC sem cabeçalho). Corrompidos listados e **não movidos**: tamanho zero, zip inválido, cabeçalho NES inválido. `_info.txt` ignorado.
- **gamelist NES**: a entrada da versão USA (favorita, `playcount` 3) saiu do `gamelist.xml` e foi guardada intacta em `_removidos\nes\gamelist-removidos.xml` com comentário do motivo; a entrada PT-BR manteve nome, descrição em português, `favorite` e `lastplayed`; `Thwaite` ganhou entrada nova; backup `gamelist.xml.bak-20261114-1553` criado.
- **Mega Drive**: `Miniplanets.bin` (sem tag) foi reconhecido pela DAT como "Miniplanets Remix (World)" e ficou (Mundo = EUA) contra `Miniplanets (Europe).bin` (movido). Capa baixada do libretro-thumbnails (nome da ROM na DAT: "Miniplanets Remix (World) (Aftermarket) (Unl)", PNG 512×722) e `<image>` acrescentado ao gamelist, preservando a descrição.
- **GBC**: `uCity Checksum Ruim (USA).gbc` listado como corrompido ("checksum do cabeçalho Game Boy inválido (esperado 6D, achado D2)").
- **PSX**: `Jogo de Disco (Japan).cue` + `.bin` movidos juntos; `Aventura (USA)` (m3u + 2 discos em subpasta) tratado como um jogo só e nada movido; `Faltando (USA).cue` listado como corrompido. (Os `.bin` fictícios não casam com a Redump, como esperado.)
- **Colisão e `--mover-corrompidos`** (rodada extra, devolvendo cópias para a pasta): a segunda cópia de `Nova the Squirrel (USA).nes` foi para `_removidos\nes\Nova the Squirrel (USA)__2.nes`, o conjunto `.cue`/`.bin` repetido foi para `_removidos\psx\_2\`, e os 5 corrompidos foram para `_removidos\<console>\corrompidos\`.
- **`--sem-dat`**: mesmo resultado no NES/PSX/GBC; no Mega Drive, sem a DAT, `Miniplanets.bin` (sem região) perde para `Miniplanets (Europe).bin` — comportamento documentado nas limitações.
- Fins de linha preservados: o gamelist de teste em CRLF continuou CRLF; os da prévia (LF) continuaram LF.

### 2. Pasta real da prévia (`arcadia-preview\roms`)

Rodado primeiro com `--simular` e depois de verdade (`--txt`). Resultado da execução real (relatório `arcadia-preview\roms\_relatorios\limpeza-2026-11-14_1551.md`):

| Console | Antes | Depois | Movidos | Corrompidos | Capas novas | Sem capa | Reconhecidos pela DAT |
|---|---|---|---|---|---|---|---|
| gbc | 1 (128,0 KB) | 1 (128,0 KB) | 0 | 0 | 0 | 1 | 1/1 (uCity (World) (v1.3)) |
| megadrive | 1 (512,0 KB) | 1 (512,0 KB) | 0 | 0 | 1 | 0 | 1/1 (Miniplanets Remix (World)) |
| nes | 2 (280,0 KB) | 2 (280,0 KB) | 0 | 0 | 0 | 2 | 2/2 (Nova the Squirrel (World) (v1.0.6-2385); Thwaite (World) (Proto 4)) |

- **Nada foi movido** (não há duplicados) e nenhum corrompido; a pasta `_removidos` nem foi criada.
- **Capas**: 1 baixada (Miniplanets → `megadrive\images\Miniplanets.png`); Nova the Squirrel, Thwaite e uCity não existem no libretro-thumbnails (testados nome da DAT, nome da ROM, nome do arquivo e outras versões da DAT) — registrado no relatório como "não encontradas", sem erro.
- **gamelist.xml**: `nes` e `gbc` **não foram alterados** (byte a byte; sem backup porque não houve mudança) — o `<favorite>true</favorite>` do Nova the Squirrel e todas as descrições em português continuam lá. `megadrive` ganhou só `<image>./images/Miniplanets.png</image>` (e a declaração `encoding="UTF-8"`), com backup `gamelist.xml.bak-20261114-1551`; descrição, gênero, jogadores e desenvolvedora preservados.
- Pastas ignoradas (sem mapeamento): `halflife`, `ports`, `sonic-mania`; as ~240 subpastas vazias e os `_info.txt` do RetroBat não foram tocados.

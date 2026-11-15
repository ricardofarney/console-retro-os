# Roteiro para quando o aparelho chegar

KINHANK Super Console X2 Pro (Amlogic S905X2) + Arcádia. Preparado em 14/11/2026 (horário de Brasília). Scripts em [ferramentas/aparelho/](../ferramentas/aparelho).

**Regra de ouro:** o cartão microSD **original** do aparelho nunca é gravado. Tudo é feito em cópias e num **cartão novo**.

## Material

- Cartão microSD **novo**, de preferência do mesmo tamanho ou maior que o original (classe A1/U3).
- Leitor de cartão USB.
- Espaço livre em `D:` de pelo menos 2× o tamanho do cartão original.
- Imagem do Arcádia: `D:\Adube Sistemas\Console de Jogo\imagens-compiladas\Arcadia-Amlogic-ng.aarch64-1.0.0-Generic.img.gz` (+ `.sha256`).
- [balenaEtcher](https://etcher.balena.io) ou [Rufus](https://rufus.ie) para gravar o cartão novo.
- Senhas do Arcádia: `docs/SENHAS-LOCAIS.md` (arquivo local, fora do Git).

## 1. Testar o aparelho como veio (antes de mexer em qualquer coisa)

Ligue o X2 Pro com o cartão original e anote ([checklist](#checklist-do-aparelho-original)):

| Teste | Como | Anotar |
|---|---|---|
| Vídeo | liga na TV pelo HDMI | resolução, se a imagem cobre a tela |
| Controles | controles que vieram na caixa (2.4 GHz/USB) | todos os botões respondem? |
| Wi-Fi | conectar na rede de casa | conecta? sinal? |
| Bluetooth | parear um controle Bluetooth, se tiver | pareia? |
| Jogos | abrir 2 ou 3 jogos de consoles diferentes | rodam? som? |
| Versão | Menu → Informações | versão do EmuELEC e da placa |

## 2. Backup do cartão original

Desligue o aparelho, tire o cartão e coloque no leitor. ⚠️ Se o Windows oferecer **"Formatar o disco"**, clique em **Cancelar**.

**2a. Boot (dtb.img) e roms** — PowerShell normal:

```powershell
powershell -ExecutionPolicy Bypass -File "D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\aparelho\1-copiar-boot-e-roms.ps1"
```

Copia a partição de boot para `backups\cartao-original\boot-<data>\` (com `INFO.txt` e o SHA-256 do `dtb.img`) e, se a partição `EEROMS` aparecer no Windows (FAT32/exFAT/NTFS), todas as roms, saves e gamelists para `backups\roms-original\`. Guarda também o identificador do volume do cartão original, usado para os passos seguintes recusarem esse cartão.

Se a `EEROMS` for ext4 (não aparece no Windows): ligue o aparelho com o cartão original e copie pela rede em `\\EMUELEC\ROMS` para `backups\roms-original\`, ou use um leitor de ext4 somente leitura.

**2b. Imagem inteira do cartão** — PowerShell **como administrador** (exige administrador porque lê o disco diretamente; o cartão é aberto **somente para leitura**):

```powershell
powershell -ExecutionPolicy Bypass -File "D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\aparelho\2-imagem-do-cartao.ps1"
```

Lista os discos removíveis, pede o número do cartão, grava `backups\cartao-original\x2pro-original-<data>.img`, lê o cartão uma segunda vez para conferir e salva `.sha256` e `.txt`. Depois, compacte com 7-Zip e guarde uma segunda cópia fora do PC.

Guarde o cartão original numa caixinha identificada.

## 3. Descobrir o DTB certo

O `dtb.img` copiado no passo 2a é o que funciona no X2 Pro. Para saber qual DTB genérico ele é, compare o SHA-256 (em `INFO.txt`) com os arquivos da pasta `device_trees` da partição de boot do cartão novo (passo 4) — esperado: `g12a_s905x2_2g.dtb` ou `g12a_s905x2_2g_1gbit.dtb` ([ANALISE-INICIAL.md](ANALISE-INICIAL.md#24-dtb-do-super-console-x2-pro)). Usar o `dtb.img` original diretamente é o caminho mais seguro, e é o que o passo 4 faz.

## 4. Gravar o Arcádia num cartão NOVO

1. Confira o SHA-256 da imagem: `Get-FileHash "D:\Adube Sistemas\Console de Jogo\imagens-compiladas\Arcadia-Amlogic-ng.aarch64-1.0.0-Generic.img.gz"` e compare com o `.sha256`.
2. Coloque o **cartão novo** no leitor (só ele).
3. balenaEtcher → *Flash from file* → o `.img.gz` → *Select target* → o cartão novo (confira o tamanho!) → *Flash*.
4. Coloque o DTB do original no cartão novo:

   ```powershell
   powershell -ExecutionPolicy Bypass -File "D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\aparelho\3-preparar-cartao-arcadia.ps1"
   ```

   O script recusa o cartão original e guarda o `dtb.img` padrão da imagem como `dtb.img.padrao-arcadia`.
5. Ejete com segurança, coloque o cartão novo no aparelho e ligue. O **primeiro boot** redimensiona o cartão e cria a partição `EEROMS` (alguns minutos — não desligue).

Se não houver imagem na TV: desligue, volte o cartão ao PC e troque o `dtb.img` por `device_trees\g12a_s905x2_2g.dtb` (ou `_1gbit`) renomeado para `dtb.img`.

## 5. Testar o Arcádia

| Teste | Esperado |
|---|---|
| Abertura | tela clara com quadradinhos coloridos, "Arcádia", "seus clássicos, de onde você parou" e barra de carregamento |
| Idioma e hora | menus em português; hora certa (Brasília) |
| Tela inicial | grade de cards coloridos com "N jogos" |
| Y na tela inicial | console vai para o início com ★; aviso "ADICIONADO AOS CONSOLES FAVORITOS" |
| Lista de jogos | fundo no tom claro do console, ★ favoritos no topo, gênero ao lado |
| Salvamento automático | jogar, sair (Select+Start), abrir de novo → janela "Continuar de onde parei" (com miniatura) / "Começar do início" |
| Continuar jogando | o jogo aparece na coleção da tela inicial |
| Menu (Start) | 6 itens + Modo avançado; testar Wi-Fi, parear controle Bluetooth, configurar botões, Som e tela |
| Rede | `\\ARCADIA` no Windows pede usuário `arcadia` e a senha de `docs/SENHAS-LOCAIS.md` |
| SSH | `ssh root@ARCADIA` com a senha de `docs/SENHAS-LOCAIS.md` |
| Desligar com segurança | desliga sem erros |

Anote o que falhar em [FUNCOES-ARCADIA.md](FUNCOES-ARCADIA.md) (seção "o que só pode ser testado no aparelho").

## 6. Limpar e migrar as roms

Com o cartão novo de volta no leitor do PC (depois do primeiro boot):

```powershell
# 1º: só o relatório (nada é movido nem copiado)
powershell -ExecutionPolicy Bypass -File "D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\aparelho\4-migrar-roms.ps1" -Simular
# 2º: limpa a cópia e grava no cartão novo
powershell -ExecutionPolicy Bypass -File "D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\aparelho\4-migrar-roms.ps1"
```

- Trabalha numa **cópia** (`backups\roms-para-arcadia`); `backups\roms-original` nunca é alterado.
- A limpeza ([LIMPEZA-ROMS.md](LIMPEZA-ROMS.md)) mantém uma versão por jogo (PT-BR > EUA > Europa > Japão > hacks), **move** os descartes para `_removidos\<console>\`, lista corrompidos, baixa capas e completa os `gamelist.xml` sem perder favoritos.
- Revise `backups\roms-para-arcadia\_relatorios\` e `_removidos\` antes de dar como encerrado.
- Pastas de console com nome diferente entre o EmuELEC original e o Arcádia aparecem no relatório como consoles sem jogos; renomeie a pasta na cópia e rode de novo.

No aparelho: *Menu → Atualizar listas de jogos* se algum console não aparecer.

## Checklist do aparelho original

```
Data: ____/____/______   Versão do EmuELEC original: __________
[ ] Vídeo: resolução ________  ocupa a tela toda? ____
[ ] Controles da caixa: tipo ________  todos os botões? ____
[ ] Wi-Fi: conectou? ____  Bluetooth: pareou? ____
[ ] Jogos testados: ____________________________________
[ ] Backup boot + roms (passo 2a)   [ ] Imagem inteira + SHA-256 (passo 2b)
[ ] Cartão original guardado
[ ] Arcádia gravado no cartão novo + dtb.img   [ ] Testes do passo 5
[ ] Roms migradas e relatório revisado
```

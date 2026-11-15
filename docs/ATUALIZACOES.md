# Atualizações do Arcádia (Releases do GitHub)

Montado em 14/11/2026 (horário de Brasília). **Nenhuma versão foi publicada ainda** — tudo está pronto para a primeira, **Arcádia 1.0.0**.

## Como o aparelho procura atualização

```
aparelho (updatecheck.sh)
   │ 1. lê https://raw.githubusercontent.com/ricardofarney/console-retro-os/dev/atualizacao/versoes.txt
   │    → linha do canal configurado: "1.0.0;stable" ou "1.1.0;beta"
   │ 2. compara com /usr/config/EE_VERSION (versão instalada) — formato X.Y.Z
   │ 3. se for mais nova, baixa
   │    https://github.com/ricardofarney/console-retro-os/releases/download/v<versão>/Arcadia-Amlogic-ng.aarch64-<versão>.tar
   │    e confere com o .sha256 ao lado
   ▼
próximo boot: o initramfs aplica o .tar (KERNEL + SYSTEM); /storage não é tocado
```

| Peça | Arquivo |
|---|---|
| Endereços e comparação de versão | [packages/sx05re/emuelec/bin/updatecheck.sh](../packages/sx05re/emuelec/bin/updatecheck.sh) |
| Download e conferência | [packages/sx05re/emuelec/bin/batocera/emuelec-upgrade](../packages/sx05re/emuelec/bin/batocera/emuelec-upgrade) (faz backup antes com `arcadia-dados.sh backup`) |
| Versão da imagem | [packages/sx05re/emuelec/config/EE_VERSION](../packages/sx05re/emuelec/config/EE_VERSION) = `1.0.0` |
| Versões publicadas (lido pelos aparelhos) | [atualizacao/versoes.txt](../atualizacao/versoes.txt) — vazio até a primeira publicação |
| Canal do aparelho | `updates.type=stable` (ou `beta`) no `emuelec.conf`; `updates.enabled=1` verifica no boot |
| Nome dos arquivos | o build gera `Arcadia-Amlogic-ng.aarch64-<versão>-Generic.img.gz` (TV boxes, como o X2 Pro), imagens de placas (`-Odroid_N2`, `-Radxa_Zero`… — não usadas) e o `.tar` de atualização (`CUSTOM_IMAGE_NAME` no [compilar.sh](../ferramentas/wsl/compilar.sh)) |

O que mudou em relação ao EmuELEC:

- servidor: Releases do fork em vez de `EmuELEC/EmuELEC` e `EmuELEC-tests` (beta e estável no mesmo repositório; beta = pré-lançamento);
- comparação de versão reescrita para X.Y.Z (`sort -V`): a do EmuELEC só funcionava com versões de dois dígitos, como 4.8;
- mensagens em português;
- a "atualização forçada" não apaga mais as configurações (ver [CONFIGURACAO-DE-FABRICA.md](CONFIGURACAO-DE-FABRICA.md)).

## Como publicar uma versão

1. Ajuste a versão em `packages/sx05re/emuelec/config/EE_VERSION` (ex.: `1.0.1`), faça commit.
2. Compile: `ferramentas\wsl\compilar.ps1` (ver [AMBIENTE-BUILD.md](AMBIENTE-BUILD.md)). Saem `Arcadia-Amlogic-ng.aarch64-<versão>-Generic.img.gz` e `.tar` em `imagens-compiladas\` (mais as imagens de placas, que não são publicadas).
3. Teste a imagem no aparelho.
4. Simule (não envia nada):

   ```powershell
   powershell -ExecutionPolicy Bypass -File "D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\publicar-versao.ps1" -Versao 1.0.1
   ```

   Prepara `imagens-compiladas\publicar\v1.0.1\` com os dois arquivos, um `.sha256` para cada e `NOTAS.md` (notas em português geradas a partir dos commits desde a última versão).
5. Publique:

   ```powershell
   powershell -ExecutionPolicy Bypass -File "D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\publicar-versao.ps1" -Versao 1.0.1 -Publicar
   ```

   Cria a Release `v1.0.1` em <https://github.com/ricardofarney/console-retro-os/releases> e grava `1.0.1;stable` em `atualizacao/versoes.txt` (commit + push). A partir daí os aparelhos no canal estável encontram a atualização.

Opções: `-Canal beta` (pré-lançamento, só para aparelhos com `updates.type=beta`), `-Notas arquivo.md` (notas próprias).

Proteções do script: recusa versão fora do formato X.Y.Z ou diferente do `EE_VERSION`; recusa arquivo acima de 2 GB (limite do GitHub); recusa Release já existente ou repositório com alterações não commitadas.

## Voltar para uma versão anterior

- Num aparelho: grave o `.img.gz` da versão anterior (o cartão é apagado; antes, copie a pasta de roms/saves) **ou** copie o `.tar` da versão anterior para `\\ARCADIA\Update` e reinicie.
- Para todos: edite `atualizacao/versoes.txt` voltando a linha do canal (aparelhos já atualizados não "voltam" sozinhos — só oferecem versões mais novas).

## Testado

| Teste | Resultado |
|---|---|
| `bash -n updatecheck.sh` (sintaxe) | ok |
| comparação X.Y.Z (1.0.1>1.0.0, 1.0.10>1.0.9, 2.0.0>1.9.9; 1.0.0=1.0.0 não atualiza) | ok |
| `publicar-versao.ps1` em simulação com arquivos fictícios (cópia, `.sha256` no formato do aparelho, notas com acentos) | ok |
| recusa de versão diferente do `EE_VERSION` | ok |
| download real no aparelho | **só no aparelho**, depois da primeira publicação |

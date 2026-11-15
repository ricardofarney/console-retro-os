# Arcádia — publica uma imagem compilada como Release do GitHub (fork ricardofarney/console-retro-os).
#
# Por padrão só SIMULA (prepara os arquivos e mostra o que faria). Para publicar de verdade, use -Publicar.
#
# Exemplos:
#   powershell -ExecutionPolicy Bypass -File ferramentas\publicar-versao.ps1 -Versao 1.0.0
#   powershell -ExecutionPolicy Bypass -File ferramentas\publicar-versao.ps1 -Versao 1.0.0 -Publicar
#   powershell -ExecutionPolicy Bypass -File ferramentas\publicar-versao.ps1 -Versao 1.1.0 -Canal beta -Notas notas.md -Publicar
#
# O que faz:
#   1. procura em imagens-compiladas\ os arquivos Arcadia-Amlogic-ng.aarch64-<versão>-Generic.img.gz (TV boxes) e .tar;
#   2. copia para imagens-compiladas\publicar\v<versão>\ e gera um .sha256 para cada um;
#   3. gera as notas da versão em português (ou usa -Notas);
#   4. (-Publicar) cria a Release v<versão> com os arquivos, e atualiza atualizacao\versoes.txt
#      (é o arquivo que os aparelhos consultam) com commit e push.
#   -Rascunho (com -Publicar): cria a Release como RASCUNHO (draft), invisível ao público e aos aparelhos,
#      e NÃO mexe no versoes.txt. Serve para ensaiar a publicação (ex.: -Versao 1.0.1-teste).
param(
    [Parameter(Mandatory = $true)][string]$Versao,
    [ValidateSet('stable', 'beta')][string]$Canal = 'stable',
    [string]$Notas,
    [switch]$Publicar,
    [switch]$Rascunho,
    [string]$PastaImagens = 'D:\Adube Sistemas\Console de Jogo\imagens-compiladas'   # para testes
)
$ErrorActionPreference = 'Stop'
# saída do git/gh em UTF-8 (acentos nas notas)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $OutputEncoding = [System.Text.Encoding]::UTF8
$repo      = 'D:\Adube Sistemas\Console de Jogo\console-retro-os'
$imagens   = $PastaImagens
$github    = 'ricardofarney/console-retro-os'
$device    = 'Amlogic-ng.aarch64'
$base      = "Arcadia-$device-$Versao"
$tag       = "v$Versao"
$saida     = Join-Path $imagens "publicar\$tag"
$utf8      = New-Object System.Text.UTF8Encoding $false
$agora     = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date), 'E. South America Standard Time').ToString('dd/MM/yyyy HH:mm')

function Aviso($t) { Write-Host "AVISO: $t" -ForegroundColor Yellow }
function Passo($t) { Write-Host "==> $t" -ForegroundColor Cyan }

# ---------- 1. conferências ----------
if ($Versao -notmatch '^\d+\.\d+\.\d+(-[0-9A-Za-z]+)?$') { throw "Versão inválida '$Versao' (use X.Y.Z, ex.: 1.0.0; versões de teste: X.Y.Z-teste)." }
if ($Versao -match '-' -and -not $Rascunho) { throw "Versão de teste ($Versao) só pode ser publicada como rascunho (-Rascunho)." }
$versaoRepo = (Get-Content (Join-Path $repo 'packages\sx05re\emuelec\config\EE_VERSION') -Raw).Trim()
if ($versaoRepo -ne $Versao) {
    $msg = "A versão pedida ($Versao) é diferente da versão da branch atual ($versaoRepo em packages\sx05re\emuelec\config\EE_VERSION)."
    if ($Rascunho) { Aviso "$msg Aceito porque é rascunho (versão de teste compilada de outra branch)." }
    else { throw "$msg Compile a versão certa antes." }
}

$img = Join-Path $imagens "$base-Generic.img.gz"   # imagem para TV boxes (as de placas Odroid/Radxa etc. não são publicadas)
$tar = Join-Path $imagens "$base.tar"
foreach ($f in $img, $tar) { if (-not (Test-Path $f)) { throw "Arquivo não encontrado: $f (compile com ferramentas\wsl\compilar.ps1)." } }
foreach ($f in $img, $tar) {
    $gb = (Get-Item $f).Length / 1GB
    if ($gb -ge 2) { throw "$(Split-Path $f -Leaf) tem $([math]::Round($gb,2)) GB; o GitHub aceita no máximo 2 GB por arquivo." }
}

# ---------- 2. arquivos + sha256 ----------
Passo "Preparando $saida"
New-Item -ItemType Directory -Force $saida | Out-Null
$arquivos = @()
foreach ($f in $img, $tar) {
    $nome = Split-Path $f -Leaf
    $destino = Join-Path $saida $nome
    Copy-Item $f $destino -Force
    $hash = (Get-FileHash $destino -Algorithm SHA256).Hash.ToLower()
    # formato "hash  nome" (o updatecheck.sh do aparelho lê o primeiro campo)
    [System.IO.File]::WriteAllText("$destino.sha256", "$hash  $nome`n", $utf8)
    $arquivos += $destino, "$destino.sha256"
    Write-Host ("   {0}  {1:N0} MB  sha256 {2}" -f $nome, ((Get-Item $destino).Length / 1MB), $hash)
}

# ---------- 3. notas da versão ----------
$notasArq = Join-Path $saida 'NOTAS.md'
if ($Notas) {
    Copy-Item $Notas $notasArq -Force
} else {
    $anterior = (git -C $repo tag --list 'v*' --sort=-v:refname 2>$null | Select-Object -First 1)
    $faixa = if ($anterior) { "$anterior..HEAD" } else { 'HEAD~30..HEAD' }
    $mudancas = (git -C $repo log --pretty='- %s' $faixa 2>$null | Select-Object -First 40) -join "`n"
    $hashImg = (Get-Content "$saida\$base-Generic.img.gz.sha256").Split(' ')[0]
    $hashTar = (Get-Content "$saida\$base.tar.sha256").Split(' ')[0]
    $tipo = if ($Canal -eq 'beta') { 'versão de testes (beta)' } else { 'versão estável' }
    $texto = @"
# Arcádia $Versao

Sistema de jogos retrô do projeto Arcádia para o KINHANK Super Console X2 Pro (Amlogic S905X2), baseado no EmuELEC — $tipo, publicada em $agora (horário de Brasília).

## Instalação nova (cartão microSD novo)

1. Baixe **$base-Generic.img.gz** e confira o SHA-256.
2. Grave no cartão com o balenaEtcher (ou Rufus) — não é preciso descompactar.
3. Coloque o DTB do aparelho como ``dtb.img`` na partição de boot (ver docs/CHEGADA-DO-APARELHO.md).

## Atualização de um Arcádia já instalado

Menu **Atualizações** no próprio console: ele baixa **$base.tar**, confere o SHA-256 e aplica no próximo boot. Saves, favoritos e configurações são preservados (cópia de segurança em ``/storage/roms/backup/arcadia``).

## Arquivos

| Arquivo | SHA-256 |
|---|---|
| $base-Generic.img.gz | ``$hashImg`` |
| $base.tar | ``$hashTar`` |

## Mudanças

$mudancas
"@
    [System.IO.File]::WriteAllText($notasArq, $texto, $utf8)
}
Write-Host "   notas: $notasArq"

if (-not $Publicar) {
    Passo 'SIMULAÇÃO concluída (nada foi enviado ao GitHub).'
    if ($Rascunho) {
        Write-Host "Para publicar: acrescente -Publicar. Seria criada a Release $tag em $github como RASCUNHO (versoes.txt não muda)."
    } else {
        Write-Host "Para publicar: acrescente -Publicar. Seria criada a Release $tag em $github$(if ($Canal -eq 'beta') { ' (pré-lançamento)' }) e a linha '$Versao;$Canal' em atualizacao\versoes.txt."
    }
    exit 0
}

# ---------- 4. publicação ----------
# No PowerShell 5.1, com 'Stop', qualquer texto do gh/git na saída de erro (ex.: "release not found",
# barra de progresso do upload) vira erro fatal. Daqui em diante, vale o código de saída ($LASTEXITCODE).
$ErrorActionPreference = 'Continue'
Passo 'Conferindo o gh e a tag'
gh auth status 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw 'gh não está autenticado (gh auth login).' }
gh release view $tag --repo $github 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { throw "A Release $tag já existe em $github." }
if (-not $Rascunho -and (git -C $repo status --porcelain)) { throw 'Há alterações não commitadas no repositório; faça commit antes de publicar.' }

Passo "Criando a Release $tag$(if ($Rascunho) { ' (RASCUNHO)' })"
$extra = @(); if ($Canal -eq 'beta') { $extra += '--prerelease' }; if ($Rascunho) { $extra += '--draft' }
gh release create $tag @arquivos --repo $github --target dev --title "Arcádia $Versao" --notes-file $notasArq @extra
if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar a Release.' }

if ($Rascunho) {
    Passo "Rascunho criado (não aparece para o público nem para os aparelhos; versoes.txt não foi alterado)."
    Write-Host "Ver:    gh release view $tag --repo $github"
    Write-Host "Apagar: gh release delete $tag --repo $github --yes"
    exit 0
}

Passo 'Atualizando atualizacao\versoes.txt'
$vers = Join-Path $repo 'atualizacao\versoes.txt'
$linhas = @(Get-Content $vers | Where-Object { $_ -notmatch ";$Canal\s*$" })
$linhas += "$Versao;$Canal"
[System.IO.File]::WriteAllText($vers, (($linhas -join "`n") + "`n"), $utf8)
git -C $repo add atualizacao/versoes.txt
git -C $repo commit -q -m "atualizacao: publica Arcádia $Versao no canal $Canal`n`nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git -C $repo push -q origin dev
Passo "Publicado: https://github.com/$github/releases/tag/$tag"

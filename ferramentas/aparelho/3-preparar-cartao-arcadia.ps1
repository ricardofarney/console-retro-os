# Arcádia — passo 3 da chegada do aparelho: depois de gravar a imagem do Arcádia num cartão NOVO
# (balenaEtcher/Rufus), coloca nele o dtb.img copiado do cartão original. Não precisa de administrador.
# Recusa o cartão original (compara o identificador do volume salvo no passo 1).
# Uso: powershell -ExecutionPolicy Bypass -File "D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\aparelho\3-preparar-cartao-arcadia.ps1"
param([string]$Dtb)
$ErrorActionPreference = 'Stop'
$backups = 'D:\Adube Sistemas\Console de Jogo\backups\cartao-original'

if (-not $Dtb) {
    $ultimo = Get-ChildItem $backups -Directory -Filter 'boot-*' -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $ultimo -or -not (Test-Path "$($ultimo.FullName)\dtb.img")) { throw 'dtb.img do cartão original não encontrado em backups\cartao-original\boot-*. Rode antes o passo 1 (ou use -Dtb <arquivo>).' }
    $Dtb = "$($ultimo.FullName)\dtb.img"
}
$original = Get-Content "$backups\volume-boot-original.txt" -ErrorAction SilentlyContinue

$boots = @(Get-Volume | Where-Object { $_.FileSystemLabel -eq 'EMUELEC' -and $_.DriveLetter })
if ($boots.Count -eq 0) { throw 'Partição de boot do cartão novo não encontrada (rótulo EMUELEC). Grave a imagem do Arcádia antes.' }
if ($boots.Count -gt 1) { throw 'Há mais de um cartão com o Arcádia/EmuELEC conectado. Deixe só o cartão NOVO.' }
$b = $boots[0]
if ($original -and $b.UniqueId -eq $original) { throw 'Este é o CARTÃO ORIGINAL do aparelho. Operação cancelada (nunca alteramos o cartão original).' }
$raiz = "$($b.DriveLetter):\"
if (-not (Test-Path "$raiz\KERNEL") -or -not (Test-Path "$raiz\SYSTEM")) { throw "$raiz não parece a partição de boot do Arcádia (faltam KERNEL/SYSTEM)." }

if (Test-Path "$raiz\dtb.img") { Copy-Item "$raiz\dtb.img" "$raiz\dtb.img.padrao-arcadia" -Force; Write-Host '   dtb.img padrão guardado como dtb.img.padrao-arcadia' }
Copy-Item $Dtb "$raiz\dtb.img" -Force
$h = (Get-FileHash "$raiz\dtb.img" -Algorithm SHA256).Hash.ToLower()
Write-Host "Pronto: dtb.img do cartão original copiado para $raiz (SHA-256 $h)."
Write-Host 'Ejete o cartão com segurança, coloque no aparelho e ligue (o primeiro boot cria a partição EEROMS e demora alguns minutos).'

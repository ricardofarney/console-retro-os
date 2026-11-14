# Arcádia — passo 1 da chegada do aparelho: copia a partição de boot (dtb.img etc.) e as roms
# do CARTÃO ORIGINAL para D:\Adube Sistemas\Console de Jogo\backups\. Não grava nada no cartão.
# Não precisa de administrador.
# Uso: powershell -ExecutionPolicy Bypass -File "D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\aparelho\1-copiar-boot-e-roms.ps1"
$ErrorActionPreference = 'Stop'
$backups = 'D:\Adube Sistemas\Console de Jogo\backups'
$data    = Get-Date -Format 'yyyy-MM-dd_HHmm'
$destBoot = Join-Path $backups "cartao-original\boot-$data"
$destRoms = Join-Path $backups 'roms-original'

$boot = Get-Volume | Where-Object { $_.FileSystemLabel -eq 'EMUELEC' -and $_.DriveLetter }
$roms = Get-Volume | Where-Object { $_.FileSystemLabel -eq 'EEROMS' -and $_.DriveLetter }
if (-not $boot) { throw 'Partição de boot "EMUELEC" do cartão original não encontrada. Coloque o cartão no leitor (se o Windows oferecer FORMATAR, clique em CANCELAR).' }
if (@($boot).Count -gt 1) { throw 'Há mais de um cartão "EMUELEC" conectado. Deixe só o cartão ORIGINAL no leitor.' }

New-Item -ItemType Directory -Force $destBoot, $destRoms | Out-Null

# 1) boot
Write-Host "==> Copiando a partição de boot ($($boot.DriveLetter):) para $destBoot"
robocopy "$($boot.DriveLetter):\" $destBoot /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NP | Out-Null
$dtb = Join-Path $destBoot 'dtb.img'
$info = @("Cartão original — boot copiado em $(Get-Date -Format 'dd/MM/yyyy HH:mm') (horário de Brasília)",
          "Letra: $($boot.DriveLetter):  Rótulo: $($boot.FileSystemLabel)  Sistema de arquivos: $($boot.FileSystem)",
          "Identificador do volume (usado para não confundir com o cartão novo): $($boot.UniqueId)")
if (Test-Path $dtb) {
    $h = (Get-FileHash $dtb -Algorithm SHA256).Hash.ToLower()
    $info += "dtb.img SHA-256: $h  ($((Get-Item $dtb).Length) bytes)"
    Write-Host "   dtb.img copiado (SHA-256 $h)"
} else { Write-Host '   AVISO: não há dtb.img na partição de boot.' -ForegroundColor Yellow }
if (Test-Path "$($boot.DriveLetter):\ee_fstype") { $info += "ee_fstype: $(Get-Content "$($boot.DriveLetter):\ee_fstype")" }
$info | Set-Content -Encoding UTF8 (Join-Path $destBoot 'INFO.txt')
$boot.UniqueId | Set-Content -Encoding ASCII (Join-Path $backups 'cartao-original\volume-boot-original.txt')

# 2) roms
if ($roms) {
    Write-Host "==> Copiando as roms ($($roms.DriveLetter):, $($roms.FileSystem)) para $destRoms (pode demorar)"
    robocopy "$($roms.DriveLetter):\" $destRoms /E /COPY:DAT /R:1 /W:1 /XD '$RECYCLE.BIN' 'System Volume Information' /NFL /NDL /NJH /NP
    $n = (Get-ChildItem $destRoms -Recurse -File | Measure-Object Length -Sum)
    Write-Host ("   {0:N0} arquivos, {1:N1} GB copiados" -f $n.Count, ($n.Sum / 1GB))
} else {
    Write-Host 'AVISO: a partição de roms "EEROMS" não apareceu no Windows (provavelmente ext4).' -ForegroundColor Yellow
    Write-Host '       Copie pela rede com o aparelho ligado (\\EMUELEC\ROMS) ou leia o cartão com um leitor de ext4 (ver docs\CHEGADA-DO-APARELHO.md).'
}
Write-Host "Pronto. Resumo em $destBoot\INFO.txt"

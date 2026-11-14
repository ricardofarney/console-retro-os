# Arcádia — passo 2 da chegada do aparelho: imagem INTEIRA do cartão original (somente leitura) + SHA-256.
# PRECISA DE ADMINISTRADOR (leitura direta do disco). O cartão NUNCA é gravado: o arquivo é aberto só para leitura.
# Uso (PowerShell como administrador):
#   powershell -ExecutionPolicy Bypass -File "D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\aparelho\2-imagem-do-cartao.ps1"
param([int]$Disco = -1)
$ErrorActionPreference = 'Stop'
$destino = 'D:\Adube Sistemas\Console de Jogo\backups\cartao-original'
New-Item -ItemType Directory -Force $destino | Out-Null

$adm = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $adm) { throw 'Abra o PowerShell como ADMINISTRADOR para ler o cartão inteiro.' }

$removiveis = Get-Disk | Where-Object { $_.BusType -in 'USB', 'SD', 'MMC' -and -not $_.IsSystem -and -not $_.IsBoot }
if (-not $removiveis) { throw 'Nenhum cartão/leitor USB encontrado.' }
$removiveis | Select-Object Number, FriendlyName, BusType, @{n='GB';e={[math]::Round($_.Size/1GB,1)}}, PartitionStyle | Format-Table -AutoSize | Out-Host
if ($Disco -lt 0) { $Disco = [int](Read-Host 'Digite o NÚMERO do disco do cartão ORIGINAL') }
$d = $removiveis | Where-Object Number -eq $Disco
if (-not $d) { throw "Disco $Disco não está na lista de removíveis." }
if ($d.Size -gt 1TB) { throw 'Disco grande demais para ser um cartão microSD; cancelado por segurança.' }
$livre = (Get-PSDrive D).Free
if ($livre -lt $d.Size * 1.05) { throw ("Espaço insuficiente em D: (precisa de {0:N1} GB)." -f ($d.Size / 1GB)) }

$nome = "x2pro-original-$(Get-Date -Format 'yyyy-MM-dd').img"
$arquivo = Join-Path $destino $nome
Write-Host ("==> Lendo {0} ({1:N1} GB) para {2}" -f $d.FriendlyName, ($d.Size / 1GB), $arquivo)

function Ler-Disco([int]$n, [long]$tamanho, [string]$saida) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $ent = [System.IO.File]::Open("\\.\PhysicalDrive$n", [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $sai = if ($saida) { [System.IO.File]::Create($saida) } else { $null }
    $buf = New-Object byte[] (8MB); $lido = [long]0; $ultimo = -1
    try {
        while ($lido -lt $tamanho) {
            $pedir = [int][Math]::Min($buf.Length, $tamanho - $lido)
            $pedir = $pedir - ($pedir % 512); if ($pedir -le 0) { break }
            $r = $ent.Read($buf, 0, $pedir); if ($r -le 0) { break }
            [void]$sha.TransformBlock($buf, 0, $r, $null, 0)
            if ($sai) { $sai.Write($buf, 0, $r) }
            $lido += $r
            $pct = [int](100 * $lido / $tamanho); if ($pct -ne $ultimo) { Write-Progress -Activity 'Lendo o cartão' -Status "$pct%" -PercentComplete $pct; $ultimo = $pct }
        }
        [void]$sha.TransformFinalBlock($buf, 0, 0)
        return (($sha.Hash | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally { $ent.Close(); if ($sai) { $sai.Close() } }
}

$h1 = Ler-Disco $Disco $d.Size $arquivo
Write-Host "   SHA-256 da imagem: $h1"
Write-Host '==> Conferindo (segunda leitura do cartão)...'
$h2 = Ler-Disco $Disco $d.Size $null
if ($h1 -ne $h2) { throw "A segunda leitura deu outro SHA-256 ($h2). Repita com outro leitor de cartão." }
"$h1  $nome" | Set-Content -Encoding ASCII "$arquivo.sha256"
@("Imagem do cartão original do KINHANK Super Console X2 Pro",
  "Data: $(Get-Date -Format 'dd/MM/yyyy HH:mm') (horário de Brasília)",
  "Leitor: $($d.FriendlyName)  Barramento: $($d.BusType)  Tamanho: $($d.Size) bytes",
  "SHA-256: $h1 (conferido em duas leituras)",
  "Para restaurar: balenaEtcher/Rufus/Win32 Disk Imager -> gravar este .img num cartão do mesmo tamanho ou maior.") |
  Set-Content -Encoding UTF8 "$arquivo.txt"
Write-Host "Pronto: $arquivo (+ .sha256 e .txt). Dica: compacte com 7-Zip e guarde uma segunda cópia em outro disco."

# Arcádia — passo 4 da chegada do aparelho: limpa uma CÓPIA das roms do cartão original e copia
# para a partição EEROMS do cartão NOVO (já com o Arcádia e depois do primeiro boot).
# Não precisa de administrador. O backup original (backups\roms-original) nunca é alterado.
# Uso:
#   powershell -ExecutionPolicy Bypass -File "...\4-migrar-roms.ps1" -Simular      # só relatório da limpeza
#   powershell -ExecutionPolicy Bypass -File "...\4-migrar-roms.ps1"                # limpa a cópia e grava no cartão novo
#   powershell -ExecutionPolicy Bypass -File "...\4-migrar-roms.ps1" -SemLimpeza    # copia sem limpar
param([switch]$Simular, [switch]$SemLimpeza, [switch]$SemCapas)
$ErrorActionPreference = 'Stop'
$base     = 'D:\Adube Sistemas\Console de Jogo'
$original = "$base\backups\roms-original"
$copia    = "$base\backups\roms-para-arcadia"
$limpar   = "$base\console-retro-os\ferramentas\roms\limpar-roms.py"
if (-not (Test-Path $original)) { throw "Não encontrei $original. Rode antes o passo 1." }

# 1) cópia de trabalho (o original fica intacto)
Write-Host "==> Atualizando a cópia de trabalho em $copia"
robocopy $original $copia /E /COPY:DAT /XO /R:1 /W:1 /NFL /NDL /NJH /NP | Out-Null

# 2) limpeza (duplicados, versões, corrompidos, capas, gamelist)
if (-not $SemLimpeza) {
    $args = @($limpar, $copia)
    if ($Simular) { $args += '--simular' }
    if ($SemCapas) { $args += '--sem-capas' }
    Write-Host "==> Limpando a cópia: python $($args -join ' ')"
    & python @args
    if ($LASTEXITCODE -ne 0) { throw 'A limpeza terminou com erro (veja a mensagem acima).' }
    if ($Simular) { Write-Host "Simulação concluída. Relatório em $copia\_relatorios\. Nada foi copiado para o cartão."; exit 0 }
}

# 3) cartão novo: partição EEROMS no MESMO disco de um boot que NÃO seja o original
$idOriginal = Get-Content "$base\backups\cartao-original\volume-boot-original.txt" -ErrorAction SilentlyContinue
$eeroms = @(Get-Volume | Where-Object { $_.FileSystemLabel -eq 'EEROMS' -and $_.DriveLetter })
if ($eeroms.Count -ne 1) { throw 'Deixe conectado só o cartão NOVO (com a partição EEROMS visível, criada no primeiro boot do Arcádia).' }
$disco = (Get-Partition -DriveLetter $eeroms[0].DriveLetter).DiskNumber
$bootMesmoDisco = Get-Partition -DiskNumber $disco | Get-Volume | Where-Object FileSystemLabel -eq 'EMUELEC'
if ($idOriginal -and $bootMesmoDisco -and $bootMesmoDisco.UniqueId -eq $idOriginal) { throw 'Este é o CARTÃO ORIGINAL. Operação cancelada.' }
$destino = "$($eeroms[0].DriveLetter):\"

Write-Host "==> Copiando as roms para $destino (sem apagar nada que já esteja lá)"
robocopy $copia $destino /E /COPY:DAT /R:1 /W:1 /XD '_removidos' '_relatorios' /NFL /NDL /NJH /NP
Write-Host 'Pronto. No aparelho: Menu > Atualizar listas de jogos (se algum console não aparecer).'
Write-Host "Revise os descartes em $copia\_removidos e o relatório em $copia\_relatorios."

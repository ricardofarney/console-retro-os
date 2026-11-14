# limpar-roms.ps1 — atalho para limpar-roms.py (Arcádia)
# Repassa todos os argumentos para o script Python que está na mesma pasta.
#
# Exemplos:
#   .\limpar-roms.ps1 "D:\Adube Sistemas\Console de Jogo\arcadia-preview\roms" --simular
#   .\limpar-roms.ps1 "E:\roms" --sem-capas --txt
#
# Se o PowerShell bloquear scripts, rode uma vez nesta janela (não exige administrador):
#   Set-ExecutionPolicy -Scope Process Bypass

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'limpar-roms.py'

# Acentos corretos no console
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$env:PYTHONIOENCODING = 'utf-8'

$py = $null
foreach ($cand in @('py', 'python')) {
    if (Get-Command $cand -ErrorAction SilentlyContinue) { $py = $cand; break }
}
if (-not $py) {
    Write-Host 'ERRO: Python 3 não encontrado (comando "py" ou "python").'
    exit 2
}

if ($py -eq 'py') {
    & py -3 $script @args
} else {
    & python $script @args
}
exit $LASTEXITCODE

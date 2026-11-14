# Arcádia — inicia o build no WSL e impede o Windows de suspender enquanto ele roda.
# O build continua mesmo fechando o terminal ou o Claude.
# Uso (PowerShell normal, sem administrador):
#   Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','"D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\wsl\compilar.ps1"'

Add-Type -Namespace Win32 -Name Energia -MemberDefinition @'
[DllImport("kernel32.dll")]
public static extern uint SetThreadExecutionState(uint esFlags);
'@
# ES_CONTINUOUS | ES_SYSTEM_REQUIRED: mantém o PC acordado (a tela pode apagar normalmente)
[Win32.Energia]::SetThreadExecutionState(0x80000001) | Out-Null

# Avisa o build (via WSLENV) se houver alterações não commitadas, que não entram na imagem
$pendentes = git -C 'D:\Adube Sistemas\Console de Jogo\console-retro-os' status --porcelain 2>$null
$env:ARCADIA_NAO_COMMITADO = if ($pendentes) { '1' } else { '0' }
# Senhas locais (docs/SENHAS-LOCAIS.md, fora do Git): root (SSH) e compartilhamento de rede
$senhas = 'D:\Adube Sistemas\Console de Jogo\console-retro-os\docs\SENHAS-LOCAIS.md'
$env:ARCADIA_ROOT_PASSWORD = ''; $env:ARCADIA_SAMBA_PASSWORD = ''
if (Test-Path $senhas) {
    foreach ($linha in Get-Content $senhas -Encoding UTF8) {
        if ($linha -match '^(ARCADIA_(ROOT|SAMBA)_PASSWORD)=(\S+)$') { Set-Item -Path "Env:$($Matches[1])" -Value $Matches[3] }
    }
}
$env:WSLENV = 'ARCADIA_NAO_COMMITADO:ARCADIA_ROOT_PASSWORD:ARCADIA_SAMBA_PASSWORD'

try {
    wsl.exe -d Ubuntu-22.04 -u console -- bash -lc "tr -d '\r' < '/mnt/d/Adube Sistemas/Console de Jogo/console-retro-os/ferramentas/wsl/compilar.sh' > ~/compilar.sh && bash ~/compilar.sh"
}
finally {
    [Win32.Energia]::SetThreadExecutionState(0x80000000) | Out-Null
}

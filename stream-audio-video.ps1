<#
.SINOPSE
Sistema automático de transmissão de Áudio/Vídeo para Windows
Repositório: https://github.com/l0ckz3r0/StreamAudioWin
#>

# ===================== CONFIGURAÇÕES =====================
$portaUsada = 8080
$ffmpegPath = "C:\ffmpeg\bin\ffmpeg.exe"
$ffmpegUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"

# ===================== FUNÇÃO: PERMISSÕES =====================
function Setar-Permissoes {
    Write-Host "`n🔐 Ajustando permissões..."
    $chaves = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"
    )
    foreach ($caminho in $chaves) {
        if (-not (Test-Path $caminho)) { New-Item -Path $caminho -Force | Out-Null }
        Set-ItemProperty -Path $caminho -Name Value -Value Allow -Type String -Force
    }

    # Regra de Firewall
    Remove-NetFirewallRule -Name "StreamAudioVideo" -ErrorAction SilentlyContinue | Out-Null
    New-NetFirewallRule -Name "StreamAudioVideo" -DisplayName "Transmissao Audio Video" `
        -Direction Inbound -Protocol TCP -LocalPort $portaUsada -Action Allow -Enabled True | Out-Null
}

# ===================== FUNÇÃO: INSTALAR FFMPEG =====================
function Instalar-Ffmpeg {
    if (Test-Path $ffmpegPath) {
        Write-Host "`n✅ FFmpeg já instalado"
        return
    }
    Write-Host "`n📥 Baixando e instalando FFmpeg..."
    $tmpZip = "$env:TEMP\ffmpeg.zip"
    $tmpDir = "$env:TEMP\ffmpeg_inst"

    Invoke-WebRequest -Uri $ffmpegUrl -OutFile $tmpZip -UseBasicParsing
    Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force
    $pastaExtraida = Get-ChildItem -Path $tmpDir -Directory -Filter "ffmpeg-*" | Select-Object -First 1

    New-Item -ItemType Directory -Path "C:\ffmpeg\bin" -Force | Out-Null
    Copy-Item -Path "$($pastaExtraida.FullName)\bin\*" -Destination "C:\ffmpeg\bin\" -Recurse -Force

    $env:PATH += ";C:\ffmpeg\bin"
    [Environment]::SetEnvironmentVariable("PATH", $env:PATH, "Machine")

    Remove-Item $tmpZip, $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✅ FFmpeg instalado com sucesso"
}

# ===================== FUNÇÃO: DETECTAR DISPOSITIVOS =====================
function Obter-Dispositivos {
    Write-Host "`n🔍 Procurando câmera e microfone..."
    $saida = & $ffmpegPath -list_devices true -f dshow -i dummy 2>&1

    $temCamera = ($saida -match "DirectShow video devices") -and ($saida -match '".+"')
    $temMicrofone = ($saida -match "DirectShow audio devices") -and ($saida -match '".+"')

    $nomeMic = if ($saida -match '"Microfone[^"]+"') { $matches[0] -replace '"','' } else { $null }
    $nomeCam = if ($saida -match '"Camera[^"]+"') { $matches[0] -replace '"','' } else { $null }

    return @{
        TemCamera = $temCamera
        TemMicrofone = $temMicrofone
        NomeCamera = $nomeCam
        NomeMicrofone = $nomeMic
    }
}

# ===================== EXECUÇÃO PRINCIPAL =====================
Clear-Host
Write-Host "============================================="
Write-Host "   STREAM AUDIO/VIDEO AUTOMÁTICO"
Write-Host "============================================="

Setar-Permissoes
Instalar-Ffmpeg
$dev = Obter-Dispositivos

# Pegar IP válido
$ipValido = (Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.InterfaceAlias -notmatch 'Loopback|VMware|Virtual' -and $_.IPAddress -notlike '169.254.*' } |
            Select-Object -First 1).IPAddress
if (-not $ipValido) { $ipValido = "10.0.0.92" }

# Montar comando conforme dispositivo
if ($dev.TemCamera) {
    Write-Host "`n📹 Usando CÂMERA: $($dev.NomeCamera)"
    $cmd = "`"$ffmpegPath`" -y -f dshow -framerate 15 -video_size 1280x720 -i `"video=$($dev.NomeCamera)`" -vcodec mjpeg -q:v 5 -f mpjpeg -listen 1 `"http://0.0.0.0:$portaUsada/stream`""
}
elseif ($dev.TemMicrofone) {
    Write-Host "`n🎤 Usando MICROFONE: $($dev.NomeMicrofone)"
    $cmd = "`"$ffmpegPath`" -y -f dshow -rtbufsize 2M -i `"audio=$($dev.NomeMicrofone)`" -acodec mp3 -b:a 64k -ar 22050 -ac 1 -f mp3 -listen 1 `"http://0.0.0.0:$portaUsada/stream`""
}
else {
    Write-Host "`n❌ Nenhum dispositivo encontrado."
    exit 1
}

# Mostrar acesso
Write-Host "`n============================================="
Write-Host "✅ TRANSMISSÃO INICIADA!"
Write-Host "============================================="
Write-Host "📡 Acesso via VLC:"
Write-Host "http://$ipValido`:$portaUsada/stream"
Write-Host "`n💡 No VLC: Mídia > Abrir Fluxo de Rede > Colar o link acima"
Write-Host "============================================="

# Iniciar transmissão
Invoke-Expression $cmd

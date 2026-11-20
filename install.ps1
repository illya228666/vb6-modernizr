$ErrorActionPreference = 'Stop'

$dll = Join-Path $PSScriptRoot 'VB6Modernizr.dll'
if (!(Test-Path -LiteralPath $dll -PathType Leaf)) {
    throw 'VB6Modernizr.dll is missing. Run build.ps1 first.'
}
if (Get-Process -Name vb6 -ErrorAction SilentlyContinue) {
    throw 'Close Visual Basic 6 before installing VB6 Modernizr.'
}

# VB6 is a 32-bit application and uses the 32-bit COM registry.
$systemDir = 'System32'
if ([Environment]::Is64BitOperatingSystem) { $systemDir = 'SysWOW64' }
$regsvr32 = Join-Path $env:windir "$systemDir\regsvr32.exe"
Write-Host 'Registering VB6Modernizr.dll. Approve the Windows elevation prompt if shown.'
$registration = Start-Process -FilePath $regsvr32 -ArgumentList "/s `"$dll`"" `
    -Verb RunAs -WindowStyle Hidden -Wait -PassThru
if ($registration.ExitCode -ne 0) {
    throw "VB6Modernizr.dll registration failed (regsvr32 exit code $($registration.ExitCode))."
}

# Write startup settings for the user who launched the script.
$key = 'HKCU:\Software\Microsoft\Visual Basic\6.0\Addins\VB6Modernizr.Connect'
if (!(Test-Path -LiteralPath $key)) { New-Item -Path $key -Force | Out-Null }
New-ItemProperty -LiteralPath $key -Name FriendlyName -Value 'VB6 Modernizr' -PropertyType String -Force | Out-Null
New-ItemProperty -LiteralPath $key -Name CommandLineSafe -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -LiteralPath $key -Name LoadBehavior -Value 3 -PropertyType DWord -Force | Out-Null

Write-Host 'VB6 Modernizr is installed and will load the next time you start Visual Basic 6.'

$ErrorActionPreference = 'Stop'

$setupKey = 'Microsoft\VisualStudio\6.0\Setup\Microsoft Visual Basic'
$vb6Dirs = Get-ItemProperty -LiteralPath "HKLM:\SOFTWARE\WOW6432Node\$setupKey", "HKLM:\SOFTWARE\$setupKey" `
    -Name ProductDir -ErrorAction SilentlyContinue
$vb6 = $vb6Dirs | ForEach-Object { Join-Path $_.ProductDir 'VB6.EXE' } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1

if (!$vb6) {
    $programFiles = ${env:ProgramFiles(x86)}
    if (!$programFiles) { $programFiles = $env:ProgramFiles }
    $vb6 = Join-Path $programFiles 'Microsoft Visual Studio\VB98\VB6.EXE'
}
if (!(Test-Path -LiteralPath $vb6 -PathType Leaf)) {
    throw 'VB6.EXE was not found. Install the Visual Basic 6 IDE first.'
}
if (!(Test-Path -LiteralPath "$PSScriptRoot\compat\VB6Modernizr.dll" -PathType Leaf)) {
    throw 'The binary compatibility DLL is missing from compat\VB6Modernizr.dll.'
}
if (Get-Process -Name vb6 -ErrorAction SilentlyContinue) {
    throw 'Close Visual Basic 6 before building so it releases VB6Modernizr.dll.'
}

$log = Join-Path $PSScriptRoot 'build.log'
$dll = Join-Path $PSScriptRoot 'VB6Modernizr.dll'
if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log }

# An unelevated VB6 build can delete the existing Add-In Manager entry.
$addinKey = 'Software\Microsoft\Visual Basic\6.0\Addins\VB6Modernizr.Connect'
$backup = $null
$restoreRegistration = $false
$compatLayer = $env:__COMPAT_LAYER
try {
    if (Test-Path -LiteralPath "HKCU:\$addinKey") {
        $backup = [IO.Path]::GetTempFileName()
        reg.exe export "HKCU\$addinKey" $backup /y | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not back up the existing VB6 add-in registration.' }
        $restoreRegistration = $true
    }

    $env:__COMPAT_LAYER = 'RunAsInvoker'
    $build = Start-Process -FilePath $vb6 -ArgumentList '/make VB6Modernizr.vbp /out build.log' `
        -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -Wait -PassThru
    if ($build.ExitCode -ne 0 -or !(Test-Path -LiteralPath $dll -PathType Leaf)) {
        if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log | Write-Host }
        throw "Build failed (VB6 exit code $($build.ExitCode)). See $log."
    }
} finally {
    $env:__COMPAT_LAYER = $compatLayer
    if ($restoreRegistration) {
        reg.exe import $backup | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not restore the add-in registration. Backup: $backup" }
    }
    if ($backup) { Remove-Item -LiteralPath $backup }
}

Write-Host "Built $dll"

#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Arm64VisualStudio {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
        throw 'Visual Studio Installer was not found. Install Visual Studio or Build Tools with the ARM64 C++ tools and a Windows SDK.'
    }

    $instancesJson = & $vswhere -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.ARM64 -sort -format json -utf8
    if ($LASTEXITCODE -ne 0) {
        throw "Visual Studio discovery failed with exit code $LASTEXITCODE."
    }
    $instances = @($instancesJson | ConvertFrom-Json)
    if ($instances.Count -eq 0) {
        throw 'No Visual Studio installation with ARM64 C++ tools was found. Add the MSVC ARM64/ARM64EC build tools and a Windows SDK using Visual Studio Installer.'
    }

    $capabilitiesJson = & cmake -E capabilities
    if ($LASTEXITCODE -ne 0) {
        throw "CMake capability detection failed with exit code $LASTEXITCODE."
    }
    $capabilities = $capabilitiesJson | ConvertFrom-Json
    $cmakeVersion = [version]::new($capabilities.version.major, $capabilities.version.minor, $capabilities.version.patch)
    if ($cmakeVersion -lt [version]'3.24') {
        throw "CMake 3.24 or newer is required; found $cmakeVersion."
    }

    foreach ($instance in ($instances | Sort-Object { [version]$_.installationVersion } -Descending)) {
        $major = ([version]$instance.installationVersion).Major
        $generator = @($capabilities.generators | Where-Object { $_.name -match "^Visual Studio $major " })
        if ($major -ge 17 -and $generator.Count -gt 0) {
            return [pscustomobject]@{
                Generator = $generator[0].name
                Instance = $instance.installationPath
                Version = $instance.installationVersion
            }
        }
    }

    throw 'CMake has no matching generator for the installed ARM64 Visual Studio tools (2022 or newer required). Upgrade CMake to support your Visual Studio version.'
}

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw 'Run this script on Windows with Visual Studio ARM64 C++ build tools and a Windows SDK installed.'
}
if (-not (Get-Command cmake -CommandType Application -ErrorAction SilentlyContinue)) {
    throw 'CMake was not found. Install CMake 3.24 or newer and add it to PATH.'
}

$visualStudio = Get-Arm64VisualStudio
$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repoRoot 'utils/arm64'
$build = Join-Path $repoRoot 'bin/arm64-deps'
Write-Host "Using $($visualStudio.Generator) ($($visualStudio.Version)) at $($visualStudio.Instance)"

# Discard cached generator/instance settings if the installed toolchain changed.
& cmake --fresh -S $source -B $build -G $visualStudio.Generator -A ARM64 "-DCMAKE_GENERATOR_INSTANCE=$($visualStudio.Instance)"
if ($LASTEXITCODE -ne 0) {
    throw "ARM64 dependency configuration failed with exit code $LASTEXITCODE."
}

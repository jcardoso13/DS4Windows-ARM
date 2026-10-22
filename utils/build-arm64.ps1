#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$SelfContained
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-BuildCommand {
    param(
        [string]$Command,
        [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed with exit code $LASTEXITCODE."
    }
}

function Test-Arm64Binary {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 64 -or [System.BitConverter]::ToUInt16($bytes, 0) -ne 0x5a4d) {
        throw "Not a Windows executable: $Path"
    }

    $peOffset = [System.BitConverter]::ToInt32($bytes, 0x3c)
    if ($peOffset -lt 0 -or $peOffset -gt ($bytes.Length - 6) -or
        [System.BitConverter]::ToUInt32($bytes, $peOffset) -ne 0x4550 -or
        [System.BitConverter]::ToUInt16($bytes, $peOffset + 4) -ne 0xaa64) {
        throw "Not an ARM64 Windows binary: $Path"
    }
}

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw 'Run this script on Windows with Visual Studio ARM64 C++ build tools and a Windows SDK installed.'
}

foreach ($tool in @('cmake', 'dotnet')) {
    if (-not (Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue)) {
        throw "Required tool '$tool' was not found. Install CMake 3.24 or newer and the .NET 8 SDK, and add them to PATH."
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$dependencyBuild = Join-Path $repoRoot 'bin/arm64-deps'
$project = Join-Path $repoRoot 'DS4Windows/DS4WinWPF.csproj'
$output = Join-Path $repoRoot 'bin/arm64/Release/output'
$selfContainedValue = $SelfContained.IsPresent.ToString().ToLowerInvariant()

Push-Location $repoRoot
try {
    Write-Host 'Configuring ARM64 dependencies (the first build downloads pinned upstream sources)...'
    & (Join-Path $PSScriptRoot 'configure-arm64.ps1')

    Write-Host 'Building ARM64 dependencies...'
    Invoke-BuildCommand -Command 'cmake' -Arguments @(
        '--build', $dependencyBuild, '--config', 'Release'
    )

    Write-Host 'Publishing DS4Windows for Windows ARM64...'
    Invoke-BuildCommand -Command 'dotnet' -Arguments @(
        'publish', $project, '-c', 'Release', '-r', 'win-arm64',
        '--self-contained', $selfContainedValue, '/p:Platform=ARM64', '-o', $output
    )

    foreach ($name in @('DS4Windows.exe', 'ViGEmClient.dll', 'FakerInputDll.dll')) {
        Test-Arm64Binary -Path (Join-Path $output $name)
    }

    Write-Host ''
    Write-Host "Build complete: $(Join-Path $output 'DS4Windows.exe')"
    Write-Host 'Keep the entire output folder together; the EXE requires its DLLs and other files.'
    if (-not $SelfContained) {
        Write-Host 'Install the .NET 8 ARM64 Desktop Runtime on the Windows ARM device before running.'
    }
}
finally {
    Pop-Location
}

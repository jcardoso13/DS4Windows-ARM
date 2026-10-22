#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$configure = Join-Path (Split-Path -Parent $PSScriptRoot) 'configure-arm64.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($configure, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) {
    throw "PowerShell syntax errors: $parseErrors"
}
$discovery = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-Arm64VisualStudio'
}, $true)
# Replace only the native command boundary to test discovery without Windows.
$mockedDiscovery = $discovery.Extent.Text.Replace('& $vswhere ', '& Invoke-TestVswhere ')
if ($mockedDiscovery -eq $discovery.Extent.Text) {
    throw 'Could not mock the vswhere command boundary.'
}
. ([scriptblock]::Create($mockedDiscovery))

$originalProgramFiles = ${env:ProgramFiles(x86)}
${env:ProgramFiles(x86)} = [System.IO.Path]::GetTempPath()
$script:installerExists = $true
$script:discoveryExitCode = 0
$script:capabilitiesExitCode = 0
$script:instances = @(
    @{ installationVersion = '17.14.1'; installationPath = 'C:/VS 2022' },
    @{ installationVersion = '18.10.1'; installationPath = 'C:/VS 2026' }
)
$script:capabilities = @{
    version = @{ major = 4; minor = 4; patch = 4 }
    generators = @(@{ name = 'Visual Studio 17 2022' }, @{ name = 'Visual Studio 18 2026' })
}

function Test-Path {
    param($LiteralPath, $PathType)
    return $script:installerExists
}
function Invoke-TestVswhere {
    if ($args -notcontains 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' -or $args -notcontains '*') {
        throw 'Discovery must include Build Tools installations and require ARM64 tools.'
    }
    $global:LASTEXITCODE = $script:discoveryExitCode
    ConvertTo-Json -InputObject @($script:instances) -Depth 4
}
function cmake {
    if (($args -join ' ') -ne '-E capabilities') {
        throw 'Expected CMake capabilities query.'
    }
    $global:LASTEXITCODE = $script:capabilitiesExitCode
    ConvertTo-Json -InputObject $script:capabilities -Depth 4
}
function Assert-DiscoveryFailure {
    param([string]$Expected)
    try {
        Get-Arm64VisualStudio > $null
    }
    catch {
        if ($_.Exception.Message -notlike $Expected) {
            throw
        }
        return
    }
    throw "Expected discovery failure: $Expected"
}

try {
    $selected = Get-Arm64VisualStudio
    if ($selected.Generator -ne 'Visual Studio 18 2026' -or $selected.Instance -ne 'C:/VS 2026') {
        throw 'Did not select newest installed Visual Studio with its exact instance path.'
    }

    $script:capabilities.generators = @(@{ name = 'Visual Studio 17 2022' })
    if ((Get-Arm64VisualStudio).Generator -ne 'Visual Studio 17 2022') {
        throw 'Did not select an older installed version supported by CMake.'
    }
    $script:instances = @($script:instances[0])
    if ((Get-Arm64VisualStudio).Instance -ne 'C:/VS 2022') {
        throw 'Single-installation discovery failed.'
    }

    $script:capabilities.generators = @(@{ name = 'Visual Studio 18 2026' })
    Assert-DiscoveryFailure '*no matching generator*'
    $script:capabilities.version = @{ major = 3; minor = 23; patch = 0 }
    Assert-DiscoveryFailure '*3.24 or newer*'
    $script:capabilitiesExitCode = 7
    Assert-DiscoveryFailure '*capability detection failed with exit code 7*'
    $script:capabilitiesExitCode = 0
    $script:discoveryExitCode = 9
    Assert-DiscoveryFailure '*discovery failed with exit code 9*'
    $script:discoveryExitCode = 0
    $script:instances = @()
    Assert-DiscoveryFailure '*No Visual Studio installation with ARM64*'
    $script:installerExists = $false
    Assert-DiscoveryFailure '*Visual Studio Installer was not found*'
    Write-Host 'Passed 9 ARM64 Visual Studio discovery tests.'
}
finally {
    ${env:ProgramFiles(x86)} = $originalProgramFiles
}

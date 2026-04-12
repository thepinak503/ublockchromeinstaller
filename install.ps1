$ErrorActionPreference = "Stop"

$ExtensionEntry = "blockddmmcjpfkbhanlgegpmjpfpfjka;https://ublock.r58playz.dev/update.xml"
$RegistryPath = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"

if (-not (Test-Path -LiteralPath $RegistryPath)) {
    $null = New-Item -Path $RegistryPath -Force
}

$existingValues = Get-ItemProperty -LiteralPath $RegistryPath -ErrorAction SilentlyContinue
$alreadyInstalled = $false

if ($null -ne $existingValues) {
    foreach ($prop in $existingValues.PSObject.Properties) {
        if ($prop.Name -match "^\d+$" -and $prop.Value -eq $ExtensionEntry) {
            $alreadyInstalled = $true
            break
        }
    }
}

if ($alreadyInstalled) {
    Write-Output "Already installed -- skipping"
    exit
}

$maxIndex = 0
if ($null -ne $existingValues) {
    foreach ($prop in $existingValues.PSObject.Properties) {
        if ($prop.Name -match "^\d+$") {
            $index = [int]$prop.Name
            if ($index -gt $maxIndex) {
                $maxIndex = $index
            }
        }
    }
}

$nextIndex = $maxIndex + 1

Set-ItemProperty -LiteralPath $RegistryPath -Name $nextIndex.ToString() -Value $ExtensionEntry

Write-Output "Added entry $nextIndex to registry"
Write-Output "Done."
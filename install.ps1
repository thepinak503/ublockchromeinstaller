param(
    [switch]$Uninstall
)

if ($env:OS -ne "Windows_NT") {
    return
}

$ExtensionId = "blockddmmcjpfkbhanlgegpmjpfpfjka"
$UpdateUrl   = "https://ublock.r58playz.dev/update.xml"
$ExtensionEntry = "$ExtensionId;$UpdateUrl"
$RegistryPath = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"

$ChromePaths = @(
    "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    "${env:LOCALAPPDATA}\Google\Chrome\Application\chrome.exe"
)
$ChromeExe = $ChromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $ChromeExe) {
    Write-Output "Chrome not found. Install Chrome first."
    return
}

# Fake MDM enrollment keys — needed so Chrome honors ExtensionInstallForcelist
# for extensions NOT on the Chrome Web Store.
$FakeMdmEnrollments = @(
    @{
        Path  = "HKLM:\SOFTWARE\Microsoft\Enrollments\FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"
        Values = @{
            "EnrollmentState" = 1
            "EnrollmentType"  = 0
            "IsFederated"     = 0
            "UPN"             = "user@Fake-MDM-Provider.local"
        }
    }
    @{
        Path  = "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"
        Values = @{
            "Flags"                   = 0x00d6fb7f
            "AcctUId"                 = "0x000000000000000000000000000000000000000000000000000000000000000000000000"
            "RoamingCount"            = 0
            "SslClientCertReference"  = "MY;User;0000000000000000000000000000000000000000"
            "ProtoVer"                = "1.2"
        }
    }
)

if ($Uninstall) {
    Write-Output "Uninstalling..."

    $shortcutPath = "$env:USERPROFILE\Desktop\Chrome (uBlock).lnk"
    if (Test-Path -LiteralPath $shortcutPath) {
        Remove-Item -LiteralPath $shortcutPath -Force -ErrorAction SilentlyContinue
        Write-Output "Removed desktop shortcut"
    }

    if (Test-Path -LiteralPath $RegistryPath) {
        Remove-Item -LiteralPath $RegistryPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Output "Removed ExtensionInstallForcelist policy"
    }

    foreach ($entry in $FakeMdmEnrollments) {
        if (Test-Path -LiteralPath $entry.Path) {
            Remove-Item -LiteralPath $entry.Path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Output "Removed fake MDM key: $($entry.Path)"
        }
    }

    Write-Output "Done."
    return
}

# ---- Method 1: Fake MDM enrollment + ExtensionInstallForcelist ----
Write-Output "--- Method 1: Registry policy (fake MDM + ExtensionInstallForcelist) ---"

Write-Output "Applying fake MDM enrollment..."
foreach ($entry in $FakeMdmEnrollments) {
    $parent = Split-Path -Path $entry.Path -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        $null = New-Item -Path $parent -Force
    }
    if (-not (Test-Path -LiteralPath $entry.Path)) {
        $null = New-Item -Path $entry.Path -Force
    }
    foreach ($kv in $entry.Values.GetEnumerator()) {
        $name = $kv.Key
        $value = $kv.Value
        if ($value -is [int]) {
            Set-ItemProperty -LiteralPath $entry.Path -Name $name -Value $value -Type DWord -ErrorAction SilentlyContinue
        } else {
            Set-ItemProperty -LiteralPath $entry.Path -Name $name -Value $value -Type String -ErrorAction SilentlyContinue
        }
    }
}

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

if (-not $alreadyInstalled) {
    $maxIndex = 0
    if ($null -ne $existingValues) {
        foreach ($prop in $existingValues.PSObject.Properties) {
            if ($prop.Name -match "^\d+$") {
                $index = [int]$prop.Name
                if ($index -gt $maxIndex) { $maxIndex = $index }
            }
        }
    }
    $nextIndex = $maxIndex + 1
    Set-ItemProperty -LiteralPath $RegistryPath -Name $nextIndex.ToString() -Value $ExtensionEntry -ErrorAction SilentlyContinue
    Write-Output "Added extension to registry policy (entry $nextIndex)"
} else {
    Write-Output "Extension already in registry policy -- skipped"
}

Write-Output ""

# ---- Method 2: Chrome shortcut with --allowlisted-extension-id ----
Write-Output "--- Method 2: Desktop shortcut with --allowlisted-extension-id ---"

$chromeDir = Split-Path -Path $ChromeExe -Parent
$shortcutPath = "$env:USERPROFILE\Desktop\Chrome (uBlock).lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $ChromeExe
$shortcut.Arguments = "--allowlisted-extension-id=$ExtensionId"
$shortcut.WorkingDirectory = $chromeDir
$shortcut.Description = "Chrome with uBlock Origin MV3 support"
$shortcut.Save()

Write-Output "Created desktop shortcut: $shortcutPath"
Write-Output "Use this shortcut to launch Chrome - the flag lets uBlock MV3 use webRequestBlocking."
Write-Output ""

# ---- Final instructions ----
Write-Output "========= Setup complete ========="
Write-Output ""
Write-Output "1. Close all Chrome windows."
Write-Output "2. Launch Chrome from the new desktop shortcut: Chrome (uBlock)"
Write-Output "3. Go to chrome://policy - ExtensionInstallForcelist should show as OK"
Write-Output "4. Go to chrome://extensions - uBlock Origin MV3 should be installed"
Write-Output "5. IMPORTANT: Click Details on uBlock Origin and enable Allow User Scripts"
Write-Output ""
Write-Output "If you normally pin Chrome to taskbar, replace it with this shortcut."
Write-Output "========= Setup complete ========="

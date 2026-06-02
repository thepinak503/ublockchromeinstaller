# ublockchromeinstaller

Force-installs **uBlock Origin MV3** (unofficial port) on Chrome/Chromium via system policies.

The official uBlock Origin (MV2) was removed from the Chrome Web Store. This installs the [MV3 port by r58playz](https://github.com/r58Playz/uBlock-mv3), which keeps `webRequestBlocking` support via policy installation or the `--allowlisted-extension-id` flag.

## Usage

### Linux/macOS

```bash
curl -fsSL https://is.gd/installublockforce | sudo sh
```

Or locally:

```bash
git clone https://github.com/thepinak503/ublockchromeinstaller.git
cd ublockchromeinstaller
sudo sh install.sh
```

### Windows

Run as Administrator in PowerShell:

```powershell
irm https://py.md/ublockwin | iex
```

Or with the full URL:

```powershell
irm https://raw.githubusercontent.com/thepinak503/ublockchromeinstaller/main/install.ps1 | iex
```

Or locally:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

## What it does

### Linux/macOS

Writes to Chrome's managed policy directory:

- `/etc/opt/chrome/policies/managed/policy.json` — Chrome
- `/etc/chromium/policies/managed/policy.json` — Chromium

### Windows

1. **Fake MDM enrollment** — adds registry keys to make Chrome think the device is enterprise-managed (required for non-Web Store extensions)
2. **ExtensionInstallForcelist** — writes `blockddmmcjpfkbhanlgegpmjpfpfjka;https://ublock.r58playz.dev/update.xml` to `HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist`
3. **Desktop shortcut** — creates `Chrome (uBlock).lnk` on your desktop with `--allowlisted-extension-id=blockddmmcjpfkbhanlgegpmjpfpfjka` as a reliable fallback

The installer handles three cases:
- Extension already in policy → skips
- `ExtensionInstallForcelist` key exists → appends to it
- No policy yet → creates one

### Uninstall

Locally:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

Or as a one-liner:

```powershell
iex "& { $(irm https://py.md/ublockwin) } -Uninstall"
```

This removes the fake MDM keys, the ExtensionInstallForcelist policy, and the desktop shortcut.

## Requirements

- Linux, macOS, or Windows
- Chrome or Chromium installed
- Root/Administrator access

## Notes

- After installing, **enable "Allow User Scripts"** in the extension details on `chrome://extensions`
- Use the desktop shortcut `Chrome (uBlock)` to launch with `--allowlisted-extension-id` if the policy method doesn't work on your Chrome version
- Restart Chrome after running for the extension to appear
- Works on stable, beta, dev, and canary variants

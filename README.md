# ublockchromeinstaller

Force-installs uBlock Origin on Chrome/Chromium via system policies. Works on machines where you can't install extensions normally (school/work/enterprise).

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

The extension ID is `cjpalhdlnbpafiamejdnhcphjbkeiagm` (uBlock Origin official).

### Windows

Writes to the Windows Registry:

- `HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist`

The extension ID is `cjpalhdlnbpafiamejdnhcphjbkeiagm` (uBlock Origin official).

The installer handles three cases:

- Extension already in policy → skips
- `ExtensionInstallForcelist` key exists → appends to it
- No policy yet → creates one

Auto-detects which browser is installed. If none is found it writes anyway.

## Requirements

- Linux, macOS, or Windows
- Chrome or Chromium installed
- Root/Administrator access

## Notes

- Does not touch any existing policies, only appends
- Works on stable, beta, dev, and canary variants
- Restart Chrome/Chromium after running for the extension to appear
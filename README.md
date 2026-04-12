# ublockchromeinstaller

Force-installs uBlock Origin on Chrome/Chromium via system policies. Works on machines where you can't install extensions normally (school/work/enterprise).

## Usage

```bash
curl -fsSL https://is.gd/installublockforce | sudo sh
```
Enter sudo password and done!

Or locally:

```bash
git clone https://github.com/thepinak503/ublockchromeinstaller.git
cd ublockchromeinstaller
sudo sh install.sh
```

## What it does

Writes to Chrome's managed policy directory:

- `/etc/opt/chrome/policies/managed/policy.json` — Chrome
- `/etc/chromium/policies/managed/policy.json` — Chromium

The script handles three cases:

- Extension already in policy → skips
- `ExtensionInstallForcelist` key exists → appends to it
- No policy file yet → creates one

Auto-detects which browser you have installed. If neither is found it writes both locations anyway.

## Requirements

- Linux
- Chrome or Chromium installed
- Root access

## Notes

- Does not touch any existing policies, only appends
- Works on stable, beta, dev, and canary variants
- Restart Chrome/Chromium after running for the extension to appear

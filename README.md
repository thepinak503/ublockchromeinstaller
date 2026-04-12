# ublockchromeinstaller

Force-installs uBlock Origin to Chrome/Chromium using system policies. Useful for enterprise/school machines where you can't install extensions normally.

## Usage

```bash
curl -fsSL is.gd/installublockforce | sh
```

Or run locally:

```bash
sudo sh install.sh
```

## How it works

The script writes to Chrome's managed policies directory:
- `/etc/opt/chrome/policies/managed/policy.json` (Chrome)
- `/etc/chromium/policies/managed/policy.json` (Chromium)

This forces the extension to be installed on all browsers using those policies.

## Requirements

- Chrome or Chromium installed
- Root access to write to the policy directory
#!/bin/sh
# POSIX-compliant installer to force-install uBlock Origin via Chrome/Chromium policies.
# Run as root: curl -fsSL is.gd/installublockforce | sh

set -eu

EXTENSION_ENTRY='blockddmmcjpfkbhanlgegpmjpfpfjka;https://ublock.r58playz.dev/update.xml'

CHROME_POLICY="/etc/opt/chrome/policies/managed/policy.json"
CHROMIUM_POLICY="/etc/chromium/policies/managed/policy.json"

CANDIDATES='
google-chrome
google-chrome-stable
google-chrome-beta
google-chrome-unstable
google-chrome-canary
chrome
chrome-stable
chrome-beta
chrome-unstable
chromium
chromium-browser
chromium-beta
chromium-unstable
chromium-canary
'

write_policy() {
  policy_path=$1
  dir=$(dirname -- "$policy_path")

  # Already has our entry somewhere in the file — nothing to do
  if [ -f "$policy_path" ] && grep -q "$EXTENSION_ENTRY" "$policy_path" 2>/dev/null; then
    printf 'Already installed in %s — skipping\n' "$policy_path"
    return 0
  fi

  mkdir -p -- "$dir" 2>/dev/null || {
    printf 'Error: cannot create %s\n' "$dir" >&2
    return 1
  }

  tmp="$(mktemp "$dir/policy.json.XXXX")" || {
    printf 'Error: mktemp failed\n' >&2
    return 1
  }

  # If policy.json exists, try to append into existing ExtensionInstallForcelist
  # otherwise create fresh
  if [ -f "$policy_path" ]; then
    if grep -q '"ExtensionInstallForcelist"' "$policy_path" 2>/dev/null; then
      # Append our entry into the existing array
      sed 's|"ExtensionInstallForcelist"\s*:\s*\[|"ExtensionInstallForcelist": [\n    "'"$EXTENSION_ENTRY"'",|' \
        "$policy_path" > "$tmp" || {
        printf 'Error: sed failed\n' >&2
        rm -f -- "$tmp"
        return 1
      }
      printf 'Appended to existing ExtensionInstallForcelist in %s\n' "$policy_path"
    else
      # Has other policies but no forcelist key — inject it before closing brace
      sed 's|}$|,\n  "ExtensionInstallForcelist": [\n    "'"$EXTENSION_ENTRY"'"\n  ]\n}|' \
        "$policy_path" > "$tmp" || {
        printf 'Error: sed failed\n' >&2
        rm -f -- "$tmp"
        return 1
      }
      printf 'Injected ExtensionInstallForcelist into %s\n' "$policy_path"
    fi
  else
    # No file yet — create fresh
    cat > "$tmp" <<EOF
{
  "ExtensionInstallForcelist": [
    "$EXTENSION_ENTRY"
  ]
}
EOF
    printf 'Created %s\n' "$policy_path"
  fi

  chmod 644 -- "$tmp" 2>/dev/null || true
  chown root:root -- "$tmp" 2>/dev/null || true

  mv -f -- "$tmp" "$policy_path" || {
    printf 'Error: mv failed\n' >&2
    rm -f -- "$tmp"
    return 1
  }
}

# Detect browsers (subshell workaround via marker files)
printf '%s\n' "$CANDIDATES" | while IFS= read -r bin; do
  [ -z "$bin" ] && continue
  if command -v "$bin" >/dev/null 2>&1 || [ -x "/usr/bin/$bin" ] || [ -x "/usr/local/bin/$bin" ]; then
    case "$bin" in
      chromium*) : > /tmp/.ublock_need_chromium ;;
      *)         : > /tmp/.ublock_need_chrome   ;;
    esac
  fi
done

need_chrome=0
need_chromium=0
if [ -f /tmp/.ublock_need_chrome ];   then need_chrome=1;   rm -f /tmp/.ublock_need_chrome;   fi
if [ -f /tmp/.ublock_need_chromium ]; then need_chromium=1; rm -f /tmp/.ublock_need_chromium; fi

if [ "$need_chrome" -eq 0 ] && [ "$need_chromium" -eq 0 ]; then
  printf 'No Chrome/Chromium detected — writing both default locations\n'
  need_chrome=1
  need_chromium=1
fi

[ "$need_chrome" -eq 1 ]   && write_policy "$CHROME_POLICY"
[ "$need_chromium" -eq 1 ] && write_policy "$CHROMIUM_POLICY"

printf 'Done.\n'

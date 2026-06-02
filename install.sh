#!/bin/sh
# POSIX-compliant installer to force-install uBlock Origin via Chrome/Chromium policies.
# Linux:  curl -fsSL https://is.gd/installublockforce | sudo sh
# macOS:  curl -fsSL https://is.gd/installublockforce | sudo sh
# Uninstall (both): curl -fsSL https://is.gd/installublockforce | sudo sh -s -- -Uninstall

set -eu

EXTENSION_ID='blockddmmcjpfkbhanlgegpmjpfpfjka'
UPDATE_URL='https://ublock.r58playz.dev/update.xml'
EXTENSION_ENTRY="${EXTENSION_ID};${UPDATE_URL}"

CHROME_POLICY="/etc/opt/chrome/policies/managed/policy.json"
CHROMIUM_POLICY="/etc/chromium/policies/managed/policy.json"

OS=$(uname -s)

# ---- Parse flags ----
UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    -Uninstall|-uninstall|--uninstall) UNINSTALL=1 ;;
  esac
done

# ======================================================================
#  macOS helpers — managed preferences plists
# ======================================================================
mac_plist="/Library/Managed Preferences"

install_mac() {
  domain=$1  # e.g. com.google.Chrome
  label=$2

  mkdir -p "$mac_plist" 2>/dev/null || true

  # Check if already installed
  if defaults read "$mac_plist/$domain" ExtensionInstallForcelist 2>/dev/null | grep -qF "$EXTENSION_ENTRY"; then
    printf '%s already installed — skipping\n' "$label"
    return 0
  fi

  # Key exists → append; else → create
  if defaults read "$mac_plist/$domain" ExtensionInstallForcelist >/dev/null 2>&1; then
    defaults write "$mac_plist/$domain" ExtensionInstallForcelist -array-add "$EXTENSION_ENTRY"
  else
    defaults write "$mac_plist/$domain" ExtensionInstallForcelist -array "$EXTENSION_ENTRY"
  fi

  printf 'Added %s to %s policy\n' "$EXTENSION_ID" "$label"
  chown root:wheel "$mac_plist/$domain.plist" 2>/dev/null || true
  chmod 644 "$mac_plist/$domain.plist" 2>/dev/null || true
}

uninstall_mac() {
  domain=$1
  label=$2

  plist="$mac_plist/$domain.plist"
  if [ ! -f "$plist" ]; then
    printf 'No %s policy found\n' "$label"
    return 0
  fi

  # Read current array, rebuild without our entry
  entries=$(defaults read "$mac_plist/$domain" ExtensionInstallForcelist 2>/dev/null || printf '')
  if [ -z "$entries" ]; then
    defaults delete "$mac_plist/$domain" ExtensionInstallForcelist 2>/dev/null || true
    printf 'Removed %s from %s policy\n' "$EXTENSION_ID" "$label"
    return 0
  fi

  # Rebuild filtered list using newline-delimited values
  filtered=''
  count=0
  while IFS= read -r entry; do
    entry=$(printf '%s' "$entry" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')
    [ -z "$entry" ] && continue
    if [ "$entry" != "$EXTENSION_ENTRY" ]; then
      filtered="$filtered $entry"
      count=$((count + 1))
    fi
  done <<EOF
$(printf '%s' "$entries" | tr ',' '\n' | tr -d '()\n')
EOF

  if [ "$count" -eq 0 ]; then
    defaults delete "$mac_plist/$domain" ExtensionInstallForcelist 2>/dev/null || true
  else
    # shellcheck disable=SC2086
    defaults write "$mac_plist/$domain" ExtensionInstallForcelist -array $filtered
  fi
  printf 'Removed %s from %s policy\n' "$EXTENSION_ID" "$label"
}

# ======================================================================
#  Linux helpers — JSON policy files
# ======================================================================
write_policy() {
  policy_path=$1
  dir=$(dirname -- "$policy_path")

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

  if [ -f "$policy_path" ]; then
    if grep -q '"ExtensionInstallForcelist"' "$policy_path" 2>/dev/null; then
      sed 's|"ExtensionInstallForcelist"\s*:\s*\[|"ExtensionInstallForcelist": [\n    "'"$EXTENSION_ENTRY"'",|' \
        "$policy_path" > "$tmp" || {
        printf 'Error: sed failed\n' >&2
        rm -f -- "$tmp"
        return 1
      }
      printf 'Appended to existing ExtensionInstallForcelist in %s\n' "$policy_path"
    else
      sed 's|}$|,\n  "ExtensionInstallForcelist": [\n    "'"$EXTENSION_ENTRY"'"\n  ]\n}|' \
        "$policy_path" > "$tmp" || {
        printf 'Error: sed failed\n' >&2
        rm -f -- "$tmp"
        return 1
      }
      printf 'Injected ExtensionInstallForcelist into %s\n' "$policy_path"
    fi
  else
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

remove_policy() {
  policy_path=$1

  if [ ! -f "$policy_path" ]; then
    return 0
  fi

  if grep -q "$EXTENSION_ENTRY" "$policy_path" 2>/dev/null; then
    # Remove only our entry from the ExtensionInstallForcelist array
    tmp="$(mktemp "$(dirname -- "$policy_path")/policy.json.XXXX")" || return 1
    sed 's|    "'"$EXTENSION_ENTRY"'",||;s|    "'"$EXTENSION_ENTRY"'"||;s|,\s*\]|]|;s|\[\s*,|[|;s|,\s*}|}|;s|{\s*,|{|' \
      "$policy_path" > "$tmp" && mv -f -- "$tmp" "$policy_path"
    printf 'Removed %s from %s\n' "$EXTENSION_ID" "$policy_path"
  fi
}

# ======================================================================
#  Browser detection
# ======================================================================
need_chrome=0
need_chromium=0

case "$OS" in
  Darwin)
    chromium_detected=0
    for _ in /Applications/Chromium.app /Applications/Brave\ Browser.app; do
      [ -d "$_" ] && chromium_detected=1
    done

    if [ -d "/Applications/Google Chrome.app" ]; then
      need_chrome=1
      printf 'Detected: Google Chrome (macOS)\n'
    fi
    if [ "$chromium_detected" -eq 1 ] || command -v chromium >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1; then
      need_chromium=1
      printf 'Detected: Chromium-based browser (macOS)\n'
    fi
    ;;

  Linux)
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

    # Flatpak Chrome/Chromium
    for fp in com.google.Chrome org.chromium.Chromium; do
      if command -v flatpak >/dev/null 2>&1 && flatpak info "$fp" >/dev/null 2>&1; then
        printf 'Detected: %s (Flatpak)\n' "$fp"
        case "$fp" in
          org.chromium.*) : > /tmp/.ublock_need_chromium ;;
          *)              : > /tmp/.ublock_need_chrome   ;;
        esac
      fi
    done

    # AppImage — scan common locations
    for ai in ~/Applications/*chrome*.AppImage ~/Applications/*chromium*.AppImage \
              /opt/*chrome*.AppImage /opt/*chromium*.AppImage; do
      if [ -x "$ai" ]; then
        printf 'Detected: %s (AppImage)\n' "$(basename "$ai")"
        case "$(basename "$ai")" in
          *chromium*) : > /tmp/.ublock_need_chromium ;;
          *)          : > /tmp/.ublock_need_chrome   ;;
        esac
      fi
    done

    printf '%s\n' "$CANDIDATES" | while IFS= read -r bin; do
      [ -z "$bin" ] && continue
      if command -v "$bin" >/dev/null 2>&1 || [ -x "/usr/bin/$bin" ] || [ -x "/usr/local/bin/$bin" ]; then
        case "$bin" in
          chromium*) : > /tmp/.ublock_need_chromium ;;
          *)         : > /tmp/.ublock_need_chrome   ;;
        esac
      fi
    done

    if [ -f /tmp/.ublock_need_chrome ];   then need_chrome=1;   rm -f /tmp/.ublock_need_chrome;   fi
    if [ -f /tmp/.ublock_need_chromium ]; then need_chromium=1; rm -f /tmp/.ublock_need_chromium; fi
    ;;

  *)
    printf 'Unsupported OS: %s\n' "$OS" >&2
    exit 1
    ;;
esac

# Fallback — if nothing detected, write both
if [ "$need_chrome" -eq 0 ] && [ "$need_chromium" -eq 0 ]; then
  printf 'No browser detected — writing default policies for both\n'
  need_chrome=1
  need_chromium=1
fi

# ======================================================================
#  Install / Uninstall
# ======================================================================
if [ "$UNINSTALL" -eq 1 ]; then
  case "$OS" in
    Darwin)
      [ "$need_chrome" -eq 1 ]   && uninstall_mac com.google.Chrome Chrome
      [ "$need_chromium" -eq 1 ] && uninstall_mac org.chromium.Chromium Chromium
      ;;
    Linux)
      [ "$need_chrome" -eq 1 ]   && remove_policy "$CHROME_POLICY"
      [ "$need_chromium" -eq 1 ] && remove_policy "$CHROMIUM_POLICY"
      ;;
  esac
else
  case "$OS" in
    Darwin)
      [ "$need_chrome" -eq 1 ]   && install_mac com.google.Chrome Chrome
      [ "$need_chromium" -eq 1 ] && install_mac org.chromium.Chromium Chromium
      ;;
    Linux)
      [ "$need_chrome" -eq 1 ]   && write_policy "$CHROME_POLICY"
      [ "$need_chromium" -eq 1 ] && write_policy "$CHROMIUM_POLICY"
      ;;
  esac
fi

printf 'Done.\n'

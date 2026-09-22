#!/bin/bash
set -euo pipefail

# Restrict characters so the password is safe in INI and the game's chat command.
if [[ ! ${ADMIN_PASSWORD:-} =~ ^[A-Za-z0-9_-]{16,128}$ ]]; then
    echo 'ADMIN_PASSWORD must contain 16-128 letters, digits, underscores or hyphens.' >&2
    exit 1
fi
export ADMIN_PASSWORD

settings_dir="${LGSM_SERVERFILES:-/data/serverfiles}/HumanitZServer"
settings="${settings_dir}/GameServerSettings.ini"
if [[ ! -d "$settings_dir" ]]; then
    echo 'HumanitZ files are missing; installation must finish before configuration.' >&2
    exit 1
fi
if [[ ! -f "$settings" ]]; then
    if [[ -f "${settings_dir}/REF_GameServerSettings.ini" ]]; then
        cp "${settings_dir}/REF_GameServerSettings.ini" "$settings"
    else
        printf '[Host Settings]\n' > "$settings"
    fi
fi

umask 077
temporary=$(mktemp "${settings}.XXXXXX")
trap 'rm -f -- "$temporary"' EXIT
awk '
    { sub(/\r$/, "") }
    /^[[:space:]]*\[/ {
        host = ($0 ~ /^[[:space:]]*\[Host Settings\][[:space:]]*$/)
        print
        if (host) {
            print "AdminPass=\"" ENVIRON["ADMIN_PASSWORD"] "\""
            found = 1
        }
        next
    }
    host && /^[[:space:]]*AdminPass[[:space:]]*=/ { next }
    { print }
    END {
        if (!found) {
            print "\n[Host Settings]"
            print "AdminPass=\"" ENVIRON["ADMIN_PASSWORD"] "\""
        }
    }
' "$settings" > "$temporary"
mv -- "$temporary" "$settings"
echo 'HumanitZ admin password configured from ADMIN_PASSWORD (value hidden).'

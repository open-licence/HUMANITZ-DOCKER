#!/bin/bash
set -euo pipefail

# Restrict characters so the password is safe in INI and the game's chat command.
if [[ -z ${ADMIN_PASSWORD:-} ]]; then
    echo 'ADMIN_PASSWORD is missing or empty. Run the interactive installer.' >&2
    exit 1
fi
if (( ${#ADMIN_PASSWORD} < 16 || ${#ADMIN_PASSWORD} > 128 )); then
    echo 'ADMIN_PASSWORD has invalid length; use 16-128 characters. Value hidden.' >&2
    exit 1
fi
if [[ ! $ADMIN_PASSWORD =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo 'ADMIN_PASSWORD has unsupported characters. Use only A-Z, a-z, 0-9, underscore or hyphen; no spaces, quotes or KEY= prefix. Value hidden.' >&2
    exit 1
fi
export ADMIN_PASSWORD
export SERVER_NAME="${SERVER_NAME:-HumanitZ Community}"
export SERVER_PASSWORD="${SERVER_PASSWORD:-}"
if [[ ! $SERVER_NAME =~ ^[[:alnum:]\ ._-]{1,64}$ || ${SERVER_NAME,,} == *official* ]]; then
    echo 'Invalid SERVER_NAME: use 1-64 letters, digits, spaces, dots, underscores or hyphens; no Official.' >&2
    exit 1
fi
if [[ -n $SERVER_PASSWORD && ! $SERVER_PASSWORD =~ ^[A-Za-z0-9_-]{8,128}$ ]]; then
    echo 'Invalid SERVER_PASSWORD: use 8-128 letters, digits, underscores or hyphens, or leave empty.' >&2
    exit 1
fi
if [[ ${1:-} == --check-only ]]; then
    exit 0
fi

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
    function write_settings() {
        print "AdminPass=\"" ENVIRON["ADMIN_PASSWORD"] "\""
        print "ServerName=\"" ENVIRON["SERVER_NAME"] "\""
        print "Password=\"" ENVIRON["SERVER_PASSWORD"] "\""
    }
    { sub(/\r$/, "") }
    /^[[:space:]]*\[/ {
        host = ($0 ~ /^[[:space:]]*\[Host Settings\][[:space:]]*$/)
        print
        if (host) {
            write_settings()
            found = 1
        }
        next
    }
    host && /^[[:space:]]*(AdminPass|ServerName|Password)[[:space:]]*=/ { next }
    { print }
    END {
        if (!found) {
            print "\n[Host Settings]"
            write_settings()
        }
    }
' "$settings" > "$temporary"
mv -- "$temporary" "$settings"
echo 'HumanitZ admin password configured from ADMIN_PASSWORD (value hidden).'

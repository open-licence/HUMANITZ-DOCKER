#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
script="$PWD/humanitz/configure-humanitz.sh"
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
export LGSM_SERVERFILES="$scratch/serverfiles"
mkdir -p "$LGSM_SERVERFILES/HumanitZServer"
settings="$LGSM_SERVERFILES/HumanitZServer/GameServerSettings.ini"
export ADMIN_PASSWORD=TestOnlyPassword_123456 SERVER_NAME='My Test Server' SERVER_PASSWORD=Players_12345
printf '[Host Settings]\r\nServerName="Old"\r\nAdminPass="old"\r\nAdminPass="duplicate"\r\nPassword="old"\r\nSaveName="KeepWorld"\r\n[Other]\r\nValue=42\r\n' > "$settings"
bash "$script"
bash "$script"
test "$(grep -c '^AdminPass=' "$settings")" = 1
grep -Fxq 'AdminPass="TestOnlyPassword_123456"' "$settings"
grep -Fxq 'ServerName="My Test Server"' "$settings"
grep -Fxq 'Password="Players_12345"' "$settings"
grep -Fxq 'SaveName="KeepWorld"' "$settings"
grep -Fxq 'Value=42' "$settings"
SERVER_PASSWORD='' bash "$script"
grep -Fxq 'Password=""' "$settings"
cp "$settings" "$scratch/before.ini"
for value in '' short 'Invalid password with spaces'; do
    if output=$(ADMIN_PASSWORD="$value" bash "$script" 2>&1); then exit 1; fi
    [[ -z $value || $output != *"$value"* ]]
    cmp "$settings" "$scratch/before.ini"
done
if SERVER_NAME='Bad"Name' bash "$script" --check-only 2>/dev/null; then exit 1; fi
if SERVER_PASSWORD='bad password' bash "$script" --check-only 2>/dev/null; then exit 1; fi
LGSM_SERVERFILES="$scratch/absent" bash "$script" --check-only
printf '[Other]\nValue=42\n' > "$settings"
bash "$script"
grep -Fxq '[Host Settings]' "$settings"
export LGSM_SERVERFILES="$scratch/fresh"
mkdir -p "$LGSM_SERVERFILES/HumanitZServer"
printf '[Host Settings]\nSaveName="TemplateWorld"\n' > "$LGSM_SERVERFILES/HumanitZServer/REF_GameServerSettings.ini"
bash "$script"
grep -Fxq 'SaveName="TemplateWorld"' "$LGSM_SERVERFILES/HumanitZServer/GameServerSettings.ini"
echo 'PASS: configuration, repeatability, world preservation, validation and preflight'

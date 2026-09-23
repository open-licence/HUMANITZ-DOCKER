#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
trap 'echo "Ошибка на строке $LINENO. Установка не завершена; существующие данные сохранены." >&2' ERR

main() {
    [[ $EUID -eq 0 ]] || { echo 'Запустите: sudo bash install.sh' >&2; return 1; }
    [[ -t 0 ]] || { echo 'Нужен интерактивный терминал SSH.' >&2; return 1; }
    . /etc/os-release
    [[ $ID == ubuntu && $VERSION_ID == 24.04 ]] || { echo 'Поддерживается Ubuntu 24.04 LTS.' >&2; return 1; }
    [[ $(uname -m) == x86_64 ]] || { echo 'Требуется сервер x86_64.' >&2; return 1; }
    local source_dir target=/opt/humanitz answer server_name admin_password server_password ram_kb free_kb
    source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
    [[ -f "$source_dir/docker-compose.yml" && -f "$source_dir/humanitz/Dockerfile" ]] || {
        echo 'Скачайте весь репозиторий, а не только install.sh.' >&2; return 1;
    }
    ram_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
    if (( ram_kb < 3800000 )); then
        echo 'Недостаточно RAM: нужно хотя бы 4 ГБ, рекомендуется 8 ГБ. Увеличьте тариф.' >&2
        return 1
    fi
    free_kb=$(df -Pk /opt | awk 'END {print $4}')
    (( free_kb >= 10485760 )) || { echo 'Нужно хотя бы 10 ГБ свободного места в /opt.' >&2; return 1; }
    echo 'HumanitZ: установка в /opt/humanitz; UDP 7777 и 27015; данные в Docker-томе.'
    echo 'Рекомендуется отдельный сервер с 8 ГБ RAM. Скрипт не меняет SSH и облачный firewall.'
    if [[ -e "$target" ]]; then
        [[ -f "$target/.humanitz-installer" ]] || { echo '/opt/humanitz уже занят другим проектом.' >&2; return 1; }
        read -r -p 'Существующая установка будет перенастроена и перезапущена. Продолжить? [y/N]: ' answer
        [[ $answer == y || $answer == Y ]] || return 0
    fi
    while :; do
        read -r -p 'Имя сервера [HumanitZ Community]: ' server_name
        server_name=${server_name:-HumanitZ Community}
        if [[ $server_name =~ ^[[:alnum:]\ ._-]{1,64}$ && ${server_name,,} != *official* ]]; then break; fi
        echo 'До 64 букв/цифр, пробел, точка, _ или -. Слово Official не допускается.'
    done
    while :; do
        read -r -s -p 'Пароль администратора (16–128 букв/цифр/_/-; Enter — сгенерировать): ' admin_password
        echo
        if [[ -z $admin_password ]]; then
            admin_password=$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')
        fi
        [[ $admin_password =~ ^[A-Za-z0-9_-]{16,128}$ ]] && break
        echo 'Неверная длина или символы пароля.'
    done
    while :; do
        read -r -s -p 'Пароль для игроков (8–128 букв/цифр/_/-; Enter — открытый сервер): ' server_password
        echo
        [[ -z $server_password || $server_password =~ ^[A-Za-z0-9_-]{8,128}$ ]] && break
        echo 'Неверная длина или символы пароля.'
    done
    echo "Сервер: $server_name. Установка Docker (при необходимости), сборка и запуск."
    read -r -p 'Начать установку? [y/N]: ' answer
    [[ $answer == y || $answer == Y ]] || return 0

    if ! command -v docker >/dev/null 2>&1; then
        for package in docker.io docker-compose docker-compose-v2 podman-docker containerd runc; do
            if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
                echo "Обнаружен $package. Сначала согласуйте существующую контейнерную установку; пакеты не удалены." >&2
                return 1
            fi
        done
        apt-get update
        apt-get install -y ca-certificates curl
        install -m 0755 -d /etc/apt/keyrings
        curl --fail --show-error --silent --location --retry 3 https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod 0644 /etc/apt/keyrings/docker.asc
        printf '%s\n' 'Types: deb' 'URIs: https://download.docker.com/linux/ubuntu' 'Suites: noble' 'Components: stable' 'Architectures: amd64' 'Signed-By: /etc/apt/keyrings/docker.asc' > /etc/apt/sources.list.d/docker.sources
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    docker compose version >/dev/null || { echo 'Установите плагин Docker Compose v2 для существующего Docker.' >&2; return 1; }
    systemctl enable --now docker
    docker info >/dev/null

    install -d -m 0700 "$target" "$target/humanitz"
    if [[ -f "$target/.env" ]]; then
        cp -p "$target/.env" "$target/.env.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    if [[ $source_dir != "$target" ]]; then
        install -m 0600 "$source_dir/docker-compose.yml" "$target/docker-compose.yml"
        install -m 0600 "$source_dir/humanitz/"* "$target/humanitz/"
    fi
    # All values have been validated; single quoting prevents Compose interpolation.
    printf "SERVER_NAME='%s'\nADMIN_PASSWORD='%s'\nSERVER_PASSWORD='%s'\n" "$server_name" "$admin_password" "$server_password" > "$target/.env"
    chmod 0600 "$target/.env"
    touch "$target/.humanitz-installer"
    cd "$target"
    docker compose config --quiet
    docker compose build --pull
    docker compose up -d
    echo
    echo 'Контейнер запущен. SteamCMD автоматически установит игру; это ещё не означает готовность сервера.'
    echo 'Откройте в облачном firewall UDP 7777 и 27015. Подключение: публичный_IP:7777.'
    echo 'Администратор — ваш Steam-пользователь. В игровом чате введите:'
    printf '/AdminAccess %s\n' "$admin_password"
    echo 'Пароли сохранены в /opt/humanitz/.env (доступ root).'
    echo 'Логи: cd /opt/humanitz && sudo docker compose logs -f --tail 100'
    echo 'Не удаляйте Docker-том humanitz-data: в нём мир и настройки.'
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi

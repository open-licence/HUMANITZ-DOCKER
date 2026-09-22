FROM gameservermanagers/gameserver:hz

# Keep the upstream automatic installation and startup of HumanitZ.
EXPOSE 7777/udp 27015/udp

# Allow time for the first SteamCMD installation.
HEALTHCHECK --interval=1m --timeout=1m --start-period=30m --retries=3 \
    CMD /app/entrypoint-healthcheck.sh || exit 1

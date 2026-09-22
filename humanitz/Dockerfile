FROM gameservermanagers/gameserver:hz

COPY configure-humanitz.sh /app/configure-humanitz.sh
# Configure after SteamCMD installation/update, immediately before game startup.
# Fail the build if an upstream change removes this integration point.
RUN sed -i 's/\r$//' /app/configure-humanitz.sh \
    && test "$(grep -Fxc './"${GAMESERVER}" start' /app/entrypoint-user.sh)" = 1 \
    && sed -i '/^\.\/"${GAMESERVER}" start$/i /bin/bash /app/configure-humanitz.sh || exit $?' /app/entrypoint-user.sh

# Keep the upstream automatic installation and startup of HumanitZ.
EXPOSE 7777/udp 27015/udp

# Allow time for the first SteamCMD installation.
HEALTHCHECK --interval=1m --timeout=1m --start-period=30m --retries=3 \
    CMD /app/entrypoint-healthcheck.sh || exit 1

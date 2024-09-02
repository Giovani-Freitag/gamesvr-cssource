# Stage 1: Build Counter-Strike: Source server
FROM lacledeslan/steamcmd:linux as cssource-builder

# Copy cached build files (if any)
COPY /build-cache /output

# Download Counter-Strike: Source
RUN /app/steamcmd.sh +force_install_dir /output +login anonymous +app_update 232330 validate +quit;

COPY ./dist/linux/ll-tests /output/ll-tests

#=======================================================================
# Stage 2: Set up the runtime environment
FROM debian:bookworm-slim

ARG BUILDNODE=unspecified
ARG SOURCE_COMMIT=unspecified

HEALTHCHECK NONE

# Install required dependencies
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y \
        ca-certificates lib32gcc-s1 libncurses5:i386 libsdl2-2.0-0:i386 \
        libstdc++6 libstdc++6:i386 locales locales-all tmux \
        zlib1g:i386 libffi8:i386 curl unzip && \
    ln -s /usr/lib/i386-linux-gnu/libffi.so.8 /usr/lib/i386-linux-gnu/libffi.so.6 && \
    apt-get clean && \
    rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

ENV LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8

LABEL com.lacledeslan.build-node=$BUILDNODE \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://github.com/LacledesLAN/README.1ST" \
      org.label-schema.vcs-ref=$SOURCE_COMMIT \
      org.label-schema.vendor="Laclede's LAN" \
      org.label-schema.description="Counter-Strike Source Dedicated Server" \
      org.label-schema.vcs-url="https://github.com/LacledesLAN/gamesvr-cssource"

# Set up Environment
RUN useradd --home /app --gid root --system CSSource && \
    mkdir --parents /app && \
    chown CSSource:root -R /app

COPY --chown=CSSource:root --from=cssource-builder /output /app

# Install additional dependencies
RUN apt-get update && apt-get install -y curl unzip tar && apt-get clean && rm -rf /var/lib/apt/lists/*

# Download and install Metamod: Source
RUN cd /app/cstrike && \
    curl -sSL https://mms.alliedmods.net/mmsdrop/1.11/mmsource-1.11.0-git1144-linux.tar.gz | tar zxvf -

# Download and install SourceMod
RUN cd /app/cstrike && \
    curl -sSL https://sm.alliedmods.net/smdrop/1.11/sourcemod-1.11.0-git6968-linux.tar.gz | tar zxvf -

# Download and install Quake Sounds v3
# RUN cd /app/cstrike && \
#     curl -sSL https://forums.alliedmods.net/attachment.php?attachmentid=125461&d=1380903530 -o quakesounds_v3.zip && \
#     unzip -o quakesounds_v3.zip "GameServer/*" -d /app/cstrike && \
#     rm quakesounds_v3.zip

# RUN cd /app/cstrike/addons/sourcemod/plugins && \
#     curl -sSL https://www.sourcemod.net/vbcompiler.php?file_id=155260 -o quakesounds.smx

# Download and install Source.Python
RUN cd /app/cstrike && \
    curl -sSL http://downloads.sourcepython.com/release/722/source-python-css-April-21-2024.zip -o source-python.zip && \
    unzip source-python.zip -d /app/cstrike && \
    rm source-python.zip

RUN chmod +x /app/ll-tests/*.sh && \
    echo $'\n\nLinking steamclient.so to prevent srcds_run errors' && \
    mkdir --parents /app/.steam/sdk32 && \
    ln -s /app/bin/steamclient.so /app/.steam/sdk32/steamclient.so

USER CSSource

WORKDIR /app

CMD ["/bin/bash"]

ONBUILD USER root

FROM debian:bullseye
ENV DEBIAN_FRONTEND=noninteractive XMAKE_ROOT=y
RUN echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until \
 && echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/99retries \
 && SNAP=20260901T000000Z \
 && printf '%s\n' \
      "deb http://snapshot.debian.org/archive/debian/$SNAP bullseye main" \
      "deb http://snapshot.debian.org/archive/debian-security/$SNAP bullseye-security main" \
      > /etc/apt/sources.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      git ca-certificates curl wget sudo xz-utils unzip zip \
      python3 python3-pip build-essential pkg-config \
 && (echo "deb http://snapshot.debian.org/archive/debian/20260601T000000Z bullseye-backports main" > /etc/apt/sources.list.d/backports.list; apt-get update || rm -f /etc/apt/sources.list.d/backports.list) \
 && apt-get update \
 && apt-get install -y \
      curl libpng-dev libfmt-dev nlohmann-json3-dev \
      libx11-dev libxext-dev libxrender-dev libxcursor-dev \
      libasound2-dev libpulse-dev \
      xutils-dev xorg-dev autoconf automake libtool ninja-build python3-pip \
      libegl-dev libgles-dev cmake \
 && (apt-get install -y -t bullseye-backports libpipewire-0.3-dev || apt-get install -y libpipewire-0.3-dev) \
 && pip3 install --upgrade 'meson>=1.4' \
 && git config --global --add safe.directory '*' \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://xmake.io/shget.text | bash -s v3.0.8 \
 && ln -sf /root/.local/bin/xmake /usr/local/bin/xmake && xmake --version

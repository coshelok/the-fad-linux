FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    xz-utils \
    file \
    gawk \
    bzip2 \
    bison \
    flex \
    libwayland-server0 \
    weston \
    libgl1-mesa-dri \
    libinput-bin \
    libxkbcommon0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY . .

RUN chmod +x create_rootfs.sh

CMD ["./create_rootfs.sh"]
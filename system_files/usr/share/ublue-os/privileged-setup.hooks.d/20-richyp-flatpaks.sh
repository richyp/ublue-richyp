#!/usr/bin/bash

source /usr/lib/ublue/setup-services/libsetup.sh

version-script richyp-flatpaks privileged 1 || exit 0

set -x

flatpak install -y --noninteractive flathub \
    com.heroicgameslauncher.hgl \
    io.github.Faugus.faugus-launcher

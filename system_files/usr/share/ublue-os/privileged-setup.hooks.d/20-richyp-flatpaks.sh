#!/usr/bin/bash

source /usr/lib/ublue/setup-services/libsetup.sh

# Bump the number when the list changes: existing installs re-run this once on their next boot.
version-script richyp-flatpaks privileged 2 || exit 0

set -x

flatpak install -y --noninteractive flathub \
    `# games` \
    com.heroicgameslauncher.hgl \
    io.github.Faugus.faugus-launcher \
    com.vysp3r.ProtonPlus \
    com.github.Matoking.protontricks \
    `# video` \
    org.videolan.VLC \
    com.obsproject.Studio \
    fr.handbrake.ghb \
    `# graphics` \
    org.gimp.GIMP \
    org.kde.krita \
    io.gitlab.adhami3310.Impression \
    `# audio` \
    org.audacityteam.Audacity \
    org.musicbrainz.Picard \
    org.nicotine_plus.Nicotine \
    de.haeckerfelix.Shortwave \
    `# other` \
    com.github.marktext.marktext \
    com.bambulab.BambuStudio

#!/usr/bin/bash

source /usr/lib/ublue/setup-services/libsetup.sh

# Bump the number when the list changes: existing installs re-run this once on their next boot.
version-script richyp-flatpaks privileged 3 || exit 0

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

# Remove Flatpaks this image doesn't want. Needed because a machine that came here by rebasing from stock
# Aurora (stock ISO -> bootc switch) already got Aurora's default Flatpaks at its first boot, and editing
# the default list in build.sh only affects fresh installs of this image. Flatpaks live in /var, so a
# rebase never removes them. App data in ~/.var/app is kept.
#  - unused stock apps: Firefox/Thunderbird (LibreWolf/Evolution instead), Kontact, Bazaar (Discover instead)
for app in org.mozilla.firefox org.mozilla.thunderbird org.kde.kontact io.github.kolunmi.Bazaar; do
    flatpak info --system "$app" >/dev/null 2>&1 && flatpak uninstall -y --noninteractive --system "$app"
done
#  - KDE apps the image ships as RPMs (build.sh KDE_APPS) - only once the RPM is really there
for a in okular gwenview kcalc kclock kweather qrca skanpage haruna; do
    rpm -q "$a" >/dev/null 2>&1 && flatpak info --system "org.kde.$a" >/dev/null 2>&1 \
        && flatpak uninstall -y --noninteractive --system "org.kde.$a"
done
flatpak uninstall -y --noninteractive --system --unused
exit 0

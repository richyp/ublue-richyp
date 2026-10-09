#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /
chmod +x /usr/share/ublue-os/privileged-setup.hooks.d/20-richyp-flatpaks.sh
### Repos
# LibreWolf (official RPM repo)
curl -fsSL https://repo.librewolf.net/librewolf.repo -o /etc/yum.repos.d/librewolf.repo

### Steam repo (RPM Fusion nonfree-steam; disabled by default, used only via --enablerepo)
dnf5 install -y fedora-workstation-repositories

### Core packages (Fedora + RPM Fusion + LibreWolf)
dnf5 install -y --enablerepo=rpmfusion-nonfree-steam --enablerepo=fedora-multimedia \
    kitty \
    evolution evolution-ews \
    libreoffice libreoffice-gtk3 \
    librewolf \
    neovim \
    steam

### Emulation setup (~/Emulation/setup) - tools its scripts need that Aurora-DX lacks.
## Already in the base: python3-pillow, android-tools (adb), 7z, rsync, unzip, nfs-utils, cifs-utils,
## fuse-libs (AppImages: ES-DE, Cemu, ...), udisks2.
##   syncthing          - keeps ~/Emulation in step with richy-server
##   python3-fonttools  - collection cover art (make-collection-art)
##   mame-tools         - chdman, for zip2chd
##   waypipe            - run GUI apps from richy-server/richy-box on this desktop
dnf5 install -y \
    syncthing \
    python3-fonttools \
    mame-tools \
    waypipe
# Syncthing runs per user; enable its user unit for everyone (it starts at login)
systemctl --global enable syncthing.service

### Starship (official release binary, enabled for all bash users)
curl -fsSL https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/bin
cat > /etc/profile.d/starship.sh <<'EOF'
[ -n "$BASH_VERSION" ] && [ -n "$PS1" ] && eval "$(starship init bash)"
EOF

### LibreOffice: always use GTK3 (Orchis theme), and run it through XWayland.
## With mixed 1x/1.5x monitors native-Wayland GTK3 is soft at 1.5x; via XWayland it is sharp there
## and the right size on both. The wrapper adds GDK_BACKEND=x11 for LibreOffice only.
mkdir -p /usr/lib/environment.d
echo 'SAL_USE_VCLPLUGIN=gtk3' > /usr/lib/environment.d/60-libreoffice-gtk3.conf
chmod +x /usr/libexec/libreoffice-xwayland
sed -i 's|^Exec=libreoffice|Exec=/usr/libexec/libreoffice-xwayland|' \
    /usr/share/applications/libreoffice-*.desktop
grep -q 'Exec=/usr/libexec/libreoffice-xwayland' /usr/share/applications/libreoffice-writer.desktop

### Orchis theme (system-wide)
curl -fsSL https://github.com/vinceliuice/Orchis-theme/archive/refs/heads/master.tar.gz | tar -xz -C /tmp
/tmp/Orchis-theme-master/install.sh -d /usr/share/themes
rm -rf /tmp/Orchis-theme-master

### Default Flatpaks: remove unwanted, add your own
BREWFILE=/usr/share/ublue-os/homebrew/system-flatpaks.Brewfile
sed -i \
    -e '/org.mozilla.thunderbird/d' \
    -e '/org.mozilla.firefox/d' \
    -e '/org.kde.kontact/d' \
    "$BREWFILE"

### Services
firewall-offline-cmd --add-service=samba
systemctl enable podman.socket
systemctl enable sshd

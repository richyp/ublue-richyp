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

### Starship (official release binary, enabled for all bash users)
curl -fsSL https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/bin
cat > /etc/profile.d/starship.sh <<'EOF'
[ -n "$BASH_VERSION" ] && [ -n "$PS1" ] && eval "$(starship init bash)"
EOF

### LibreOffice: always use GTK3
mkdir -p /usr/lib/environment.d
echo 'SAL_USE_VCLPLUGIN=gtk3' > /usr/lib/environment.d/60-libreoffice-gtk3.conf

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
cat >> "$BREWFILE" <<'EOF'
flatpak "com.heroicgameslauncher.hgl"
flatpak "io.github.Faugus.faugus-launcher"
EOF

### Services
systemctl enable podman.socket

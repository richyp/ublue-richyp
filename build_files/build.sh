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

### Gaming tools for native Steam / Proton. gamemode (64-bit) is already in Aurora; the .i686 builds are
## for 32-bit games. MangoHud's config comes from the dotfiles (mangohud package).
dnf5 install -y \
    gamescope \
    mangohud mangohud.i686 \
    gamemode.i686

### Dev: stow (dotfiles are Stow packages) and the .NET 10 SDK (current LTS, Fedora's own build).
## Already in Aurora-DX and needed by the dotfiles' neovim config: gcc/make + tree-sitter CLI (treesitter
## grammars compile locally), node/npm, python3, unzip, curl, git (mason installs the language servers
## into ~/.local/share/nvim/mason on first start). Node versions per project come from nvm in $HOME.
dnf5 install -y \
    stow \
    dotnet-sdk-10.0

### Neovim as the default editor for everyone (root, sudo -e, new users, GUI apps), before dotfiles.
## Fedora's nano-default-editor only sets EDITOR when it is unset, and 00- sorts before it.
cat > /etc/profile.d/00-neovim-editor.sh <<'EOF'
export EDITOR=nvim VISUAL=nvim
if [ -n "$BASH_VERSION" ] && [ -n "$PS1" ]; then alias vi=nvim vim=nvim; fi
EOF
mkdir -p /usr/lib/environment.d
printf 'EDITOR=nvim\nVISUAL=nvim\n' > /usr/lib/environment.d/50-neovim-editor.conf

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
## The GTK CSS is compiled from SCSS by parse-sass.sh, which needs sassc. Without it the installer still
## "succeeds" but ships a theme with only assets/ (no gtk.css), so GTK apps silently fall back to Adwaita.
dnf5 install -y sassc
curl -fsSL https://github.com/vinceliuice/Orchis-theme/archive/refs/heads/master.tar.gz | tar -xz -C /tmp
(cd /tmp/Orchis-theme-master && ./parse-sass.sh)
/tmp/Orchis-theme-master/install.sh -d /usr/share/themes
rm -rf /tmp/Orchis-theme-master
test -s /usr/share/themes/Orchis-Light/gtk-3.0/gtk.css
test -s /usr/share/themes/Orchis-Light/gtk-4.0/gtk.css

### Default Flatpaks: remove unwanted, add your own
BREWFILE=/usr/share/ublue-os/homebrew/system-flatpaks.Brewfile
sed -i \
    -e '/org.mozilla.thunderbird/d' \
    -e '/org.mozilla.firefox/d' \
    -e '/org.kde.kontact/d' \
    -e '/io.github.kolunmi.Bazaar/d' \
    "$BREWFILE"

### Mullvad VPN (official repo). Its app installs to "/opt/Mullvad VPN", but on bootc /opt is /var/opt,
## which only reaches a machine at its first install and never updates. So move the app into /usr/lib
## (part of the image), point the launcher there, and keep a link at the old path for anything else.
curl -fsSL https://repository.mullvad.net/rpm/stable/mullvad.repo -o /etc/yum.repos.d/mullvad.repo
mkdir -p /var/opt
dnf5 install -y mullvad-vpn
mv "/var/opt/Mullvad VPN" /usr/lib/mullvad-vpn
sed -i 's|/opt/Mullvad VPN|/usr/lib/mullvad-vpn|g' /usr/share/applications/mullvad-vpn.desktop
echo 'L "/var/opt/Mullvad VPN" - - - - /usr/lib/mullvad-vpn' > /usr/lib/tmpfiles.d/mullvad-vpn.conf
systemctl enable mullvad-daemon.service mullvad-early-boot-blocking.service

### Desktop extras: Quickshell (Fedora repo) and Darkly (Qt style + window decoration; upstream
## publishes a Fedora RPM with each release). Darkly is optional: it is built against particular
## Plasma/Qt versions, so if its RPM is missing for this Fedora or won't install, the build carries on
## without it rather than failing.
dnf5 install -y quickshell
FEDORA=$(rpm -E %fedora)
DARKLY_URL=$(curl -fsSL https://api.github.com/repos/Bali10050/Darkly/releases/latest \
    | jq -r --arg f ".fc${FEDORA}.x86_64.rpm" '.assets[] | select(.name | endswith($f)) | .browser_download_url' | head -1)
if [ -n "$DARKLY_URL" ] && curl -fsSL "$DARKLY_URL" -o /tmp/darkly.rpm && dnf5 install -y /tmp/darkly.rpm; then
    echo "Darkly installed from $DARKLY_URL"
else
    echo "WARNING: Darkly not installed (no fc${FEDORA} RPM in the latest release, or it failed to install)"
fi
rm -f /tmp/darkly.rpm

### Discover instead of Bazaar: Flatpaks + KDE Store only. No rpm-ostree/PackageKit/offline-update
## backends or update notifier - the OS image is updated by uupd, and two updaters would compete.
## install_weak_deps=False stops those backends coming in as recommendations.
dnf5 install -y --setopt=install_weak_deps=False \
    plasma-discover \
    plasma-discover-flatpak \
    plasma-discover-kns
for p in plasma-discover-rpm-ostree plasma-discover-packagekit plasma-discover-notifier; do
    if rpm -q "$p" >/dev/null; then echo "ERROR: $p got installed - it would compete with uupd"; exit 1; fi
done
## Aurora's default panel (both look-and-feel layouts) and app-menu favourites pin Bazaar - point them
## at Discover so new users don't get a dead launcher.
sed -i 's/io\.github\.kolunmi\.Bazaar\.desktop/org.kde.discover.desktop/g' \
    /usr/share/plasma/look-and-feel/dev.getaurora.aurora*.desktop/contents/layouts/org.kde.plasma.desktop-layout.js \
    /usr/share/kde-settings/kde-profile/default/xdg/kicker-extra-favoritesrc
test -f /usr/share/applications/org.kde.discover.desktop
! grep -rq 'kolunmi.Bazaar' /usr/share/plasma/look-and-feel/dev.getaurora.aurora*.desktop \
    /usr/share/kde-settings/kde-profile/default/xdg/kicker-extra-favoritesrc || { echo "ERROR: Bazaar still pinned"; exit 1; }

### Desktop defaults for new users (Aurora's KDE profile, read before the stock KDE settings):
## kitty instead of Konsole, LibreWolf as browser, Evolution for mail + calendar, and Rich's Meta+ shortcuts.
KP=/usr/share/kde-settings/kde-profile/default/xdg
## Plasma's own app-launcher icon instead of Aurora's logo, and the Nuvole wallpaper (ships with Plasma).
LNF_SCRIPTS=(/usr/share/plasma/look-and-feel/dev.getaurora.aurora*.desktop/contents/plasmoidsetupscripts)
sed -i '/writeConfig("icon", "distributor-logo-symbolic")/d' "${LNF_SCRIPTS[@]/%//org.kde.plasma.kickoff.js}"
sed -i 's|writeConfig("Image", "[^"]*")|writeConfig("Image", "file:///usr/share/wallpapers/Nuvole/")|' \
    "${LNF_SCRIPTS[@]/%//org.kde.plasma.folder.js}"
test -d /usr/share/wallpapers/Nuvole
! grep -q distributor-logo "${LNF_SCRIPTS[@]/%//org.kde.plasma.kickoff.js}" || { echo "ERROR: launcher icon not reset"; exit 1; }
grep -q 'wallpapers/Nuvole' "${LNF_SCRIPTS[@]/%//org.kde.plasma.folder.js}"
sed -i 's/org\.kde\.konsole\.desktop/kitty.desktop/g' \
    /usr/share/plasma/look-and-feel/dev.getaurora.aurora*.desktop/contents/layouts/org.kde.plasma.desktop-layout.js \
    "$KP/kicker-extra-favoritesrc"
python3 - "$KP" <<'PY'
import configparser, sys
kp = sys.argv[1]
def setkeys(path, section, keys):
    c = configparser.RawConfigParser(delimiters=("=",), strict=False, interpolation=None)
    c.optionxform = str
    c.read(path)
    if not c.has_section(section): c.add_section(section)
    for k, v in keys.items(): c.set(section, k, v)
    with open(path, "w") as f: c.write(f, space_around_delimiters=False)
web = "librewolf.desktop"; evo = "org.gnome.Evolution.desktop"
setkeys(f"{kp}/kde-mimeapps.list", "Default Applications", {
    "x-scheme-handler/http": web, "x-scheme-handler/https": web,
    "text/html": web, "application/xhtml+xml": web,
    "x-scheme-handler/mailto": evo, "text/calendar": evo, "text/x-vcalendar": evo,
})
setkeys(f"{kp}/kdeglobals", "General", {"TerminalApplication": "kitty", "TerminalService": "kitty.desktop",
                                        "ColorScheme": "BreezeLight"})
# Light mode: Aurora's own light global theme (same layout, Breeze Light colours + breeze icons).
# Aurora puts ColorScheme under [KDE] too, so set it in both places.
setkeys(f"{kp}/kdeglobals", "KDE", {"LookAndFeelPackage": "dev.getaurora.auroralight.desktop",
                                    "ColorScheme": "BreezeLight"})
setkeys(f"{kp}/kdeglobals", "Icons", {"Theme": "breeze"})
# Lock screen wallpaper to match the desktop
nuvole = "file:///usr/share/wallpapers/Nuvole/"
setkeys(f"{kp}/kscreenlockerrc", "Greeter][Wallpaper][org.kde.image][General",
        {"Image": nuvole, "PreviewImage": nuvole})
PY
cat > "$KP/kglobalshortcutsrc" <<'EOF'
[kwin]
Edit Tiles=none,Meta+T,Toggle Tiles Editor

[org_kde_powerdevil]
powerProfile=Battery,Battery\tMeta+B,Switch Power Profile

[services][kitty.desktop]
_launch=Meta+T

[services][librewolf.desktop]
_launch=Meta+B
new-private-window=Meta+Shift+P

[services][org.gnome.Evolution.desktop]
calendar=Meta+C
mail=Meta+M

[services][org.kde.dolphin.desktop]
_launch=Meta+F

[services][org.kde.kate.desktop]
_launch=Meta+E

[services][org.kde.spectacle.desktop]
CurrentMonitorScreenShot=Meta+#
FullScreenScreenShot=Shift+Print\tMeta+Ctrl+#
RecordRegion=Meta+%
RecordWindow=Meta+Ctrl+%
RectangularRegionScreenShot=Meta+$\tMeta+Shift+Print
WindowUnderCursorScreenShot=Meta+Ctrl+$\tMeta+Ctrl+Print
EOF
grep -q 'kitty.desktop' "$KP/kicker-extra-favoritesrc"
grep -q '^TerminalApplication=kitty' "$KP/kdeglobals"
grep -q '^x-scheme-handler/https=librewolf.desktop' "$KP/kde-mimeapps.list"

### Identity: this is ublue-richyp, not Universal Blue's aurora-dx
## Aurora's tools read image-info.json to decide what to update/rebase to (ujust toggle-devmode,
## ublue-rollback-helper, the motd). Left as-is they would point at ghcr.io/ublue-os/aurora-dx.
jq '."image-name" = "ublue-richyp"
  | ."image-vendor" = "richyp"
  | ."image-ref" = "ostree-image-signed:docker://ghcr.io/richyp/ublue-richyp"
  | ."image-tag" = "latest"' \
    /usr/share/ublue-os/image-info.json > /tmp/image-info.json
mv /tmp/image-info.json /usr/share/ublue-os/image-info.json
## Trust images signed with this repo's cosign key (cosign.pub, copied in via system_files to
## /usr/lib/pki/containers/richyp.pub; registries.d/richyp.yaml tells podman/bootc where the signatures
## are). With this, `bootc switch --enforce-container-sigpolicy ghcr.io/richyp/ublue-richyp:latest`
## makes the install refuse any image not signed by the workflow.
jq '.transports.docker."ghcr.io/richyp" = [{
      "type": "sigstoreSigned",
      "keyPaths": ["/usr/lib/pki/containers/richyp.pub"],
      "signedIdentity": {"type": "matchRepository"}
    }]' /etc/containers/policy.json > /tmp/policy.json
mv /tmp/policy.json /etc/containers/policy.json
## "Aurora Preferences" in System Settings switches stream / DX / GPU driver by rebasing to one of
## Universal Blue's images - which would silently replace this image. Nothing else depends on it.
dnf5 remove -y kcm_ublue

### Services
firewall-offline-cmd --add-service=samba
systemctl enable podman.socket
systemctl enable sshd

#!/bin/bash
# ==========================================================
# KOMPLEKSOWY SKRYPT KONFIGURACYJNY SYSTEMU (KDE PLASMA + DEBIAN 13)
# ==========================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- Kolory i logowanie ---
INFO='\033[0;34m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
WARN='\033[0;33m'
NC='\033[0m'

log_info() { echo -e "${INFO}==> $*${NC}"; }
log_ok()   { echo -e "${SUCCESS}✔ $*${NC}"; }
log_err()  { echo -e "${ERROR}✖ BŁĄD: $*${NC}" >&2; }
log_warn() { echo -e "${WARN}⚠ UWAGA: $*${NC}"; }

trap 'log_err "Błąd w linii $LINENO. Polecenie: $BASH_COMMAND"' ERR

# --- Zmienna lokalizująca folder ze skryptem (niezależnie skąd jest uruchamiany) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# --- Funkcja zapobiegająca blokadom APT ---
wait_for_apt() {
    log_info "Zatrzymywanie PackageKit i oczekiwanie na zwolnienie blokad APT..."
    sudo systemctl stop packagekit 2>/dev/null || true

    while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
          sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
          sudo killall -0 apt apt-get dpkg 2>/dev/null; do
        sleep 3
    done
}

# --- Zmienne globalne ---
CURRENT_USER=$(whoami)
OLD_USER_PLACEHOLDER="bartek"
DEB_DIR="/tmp/debs_$$"

log_info "Ten skrypt jest dostosowany do Debian 13 (Stable). Rozpoczynam konfigurację..."

# --- Sprawdzenie uprawnień ---
if [[ "$EUID" -eq 0 ]]; then
    log_err "Nie uruchamiaj skryptu jako root. Użyj zwykłego użytkownika z dostępem do sudo."
    exit 1
fi

# ── Tymczasowy wyjątek sudo dla apt-get ───────────────────────
sudo -v
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/99-temp-installer > /dev/null

# ==========================================================
# 1. PRZYGOTOWANIE
# ==========================================================
log_info "Przygotowanie konfiguracji użytkownika..."

# Kopiowanie skryptu aktualizacji (jeśli istnieje)
if [[ -f "$SCRIPT_DIR/.update.sh" ]]; then
    cp -af "$SCRIPT_DIR/.update.sh" ~/.update.sh
    chmod +x ~/.update.sh
fi

# ==========================================================
# 2. REPOZYTORIA I AKTUALIZACJA SYSTEMU
# ==========================================================
log_info "Konfiguracja repozytoriów APT..."

wait_for_apt

# Wykomentuj wpisy cdrom
sudo sed -i '/cdrom/s/^/#/' /etc/apt/sources.list 2>/dev/null || true

# Dodaj architektury
sudo dpkg --add-architecture i386

# Rozszerzenie repozytoriów o contrib, non-free, non-free-firmware (stary format)
if [[ -f /etc/apt/sources.list ]]; then
    if ! grep -q "non-free-firmware" /etc/apt/sources.list; then
        sudo sed -i -E 's/ main($| )/ main contrib non-free non-free-firmware\1/' /etc/apt/sources.list || true
    fi
fi

# Rozszerzenie repozytoriów dla Debiana 12/13+ (nowy format DEB822)
if [[ -f /etc/apt/sources.list.d/debian.sources ]]; then
    if ! grep -q "non-free-firmware" /etc/apt/sources.list.d/debian.sources; then
        sudo sed -i -E '/^Components:/ s/$/ contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources || true
    fi
fi

# Narzędzia potrzebne do konfiguracji kluczy GPG i wykrywania GPU
wait_for_apt
sudo apt-get update -yq
sudo apt-get install -yq curl wget gnupg pciutils

# Utworzenie zalecanego katalogu na klucze (Debian 12+) i wymuszenie dostępu (755)
sudo mkdir -p /etc/apt/keyrings
sudo chmod 755 /etc/apt/keyrings

# Repozytorium Google Chrome
if [ ! -f /etc/apt/keyrings/google-chrome.gpg ]; then
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
        | sudo gpg --dearmor --yes -o /etc/apt/keyrings/google-chrome.gpg
    sudo chmod 644 /etc/apt/keyrings/google-chrome.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] \
http://dl.google.com/linux/chrome/deb/ stable main" \
        | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null
fi

# Repozytorium Brave (Origin)
sudo mkdir -p /usr/share/keyrings
sudo rm -f /usr/share/keyrings/brave-browser-archive-keyring.gpg
BRAVE_KEY_ID="0686B78420038257"
BRAVE_GNUPGHOME="$(mktemp -d)"
if ! gpg --homedir "$BRAVE_GNUPGHOME" --keyserver hkps://keyserver.ubuntu.com --recv-keys "$BRAVE_KEY_ID"; then
    log_warn "keyserver.ubuntu.com nie odpowiedział, próbuję keys.openpgp.org..."
    gpg --homedir "$BRAVE_GNUPGHOME" --keyserver hkps://keys.openpgp.org --recv-keys "$BRAVE_KEY_ID"
fi
gpg --homedir "$BRAVE_GNUPGHOME" --export "$BRAVE_KEY_ID" \
    | sudo tee /usr/share/keyrings/brave-browser-archive-keyring.gpg > /dev/null
rm -rf "$BRAVE_GNUPGHOME"
sudo chmod 644 /usr/share/keyrings/brave-browser-archive-keyring.gpg
sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
    https://brave-browser-apt-release.s3.brave.com/brave-browser.sources

wait_for_apt
sudo apt-get update -yq && sudo apt-get full-upgrade -yq

# ==========================================================
# 3. INSTALACJA PAKIETÓW
# ==========================================================
log_info "Instalacja podstawowych narzędzi i firmware..."

wait_for_apt
sudo apt-get install -yq isenkram-cli firmware-linux firmware-linux-nonfree \
    || log_warn "Błąd instalacji pakietów firmware."

sudo isenkram-autoinstall-firmware \
    || log_warn "isenkram-autoinstall-firmware zakończył się błędem (ignoruję)"

# --- Usuwanie zbędnych pakietów ---
log_info "Usuwanie zbędnych pakietów..."
PACKAGES_REMOVE=(
    nano konqueror plasma-browser-integration plasma-vault
    krdp krfb plasma-thunderbolt kontact kmail kontrast plasma-welcome
    imagemagick kaddressbook kdepim-runtime akonadi-server
    akregator korganizer kwalletmanager
)
for pkg in "${PACKAGES_REMOVE[@]}"; do
    sudo apt-get purge -yq "$pkg" 2>/dev/null || true
done
sudo apt-get autoremove -yq

# Czyszczenie pozostałości po pakietach KDE PIM
log_info "Czyszczenie pozostałości po Akonadi/KMail/Kontact w katalogu domowym..."
rm -rf ~/.local/share/akonadi ~/.local/share/kmail2 ~/.local/share/local-mail \
       ~/.local/share/contacts ~/.local/share/korganizer ~/.local/share/akregator \
       ~/.local/share/kontact ~/.local/share/konqueror \
rm -rf ~/.config/akonadi* ~/.config/kmail* ~/.config/kontact* \
       ~/.config/korganizer* ~/.config/kaddressbook* ~/.config/akregator* \
       ~/.config/emailidentities ~/.config/mailtransports

# --- Blokowanie KWallet ---
log_info "Całkowite wyłączanie demona KWallet (odbieranie uprawnień i maskowanie D-Bus)..."
sudo chmod -x /usr/bin/kwalletd6 /usr/bin/kwalletd 2>/dev/null || true
mkdir -p ~/.local/share/dbus-1/services/
ln -sf /dev/null ~/.local/share/dbus-1/services/org.kde.kwalletd6.service
ln -sf /dev/null ~/.local/share/dbus-1/services/org.kde.kwalletd.service

# --- Główna instalacja ---
log_info "Instalacja pakietów głównych..."
wait_for_apt
PACKAGES_INSTALL=(
    # Przeglądarki komunikatory
    google-chrome-stable brave-origin thunderbird telegram-desktop thunderbird-l10n-pl
    # Multimedia
    qbittorrent krita audacity gmic mixxx kdenlive handbrake soundconverter
    # Narzędzia systemowe
    vim dconf-editor hunspell-pl fastfetch bleachbit profile-sync-daemon
    plymouth plymouth-themes
    unrar-free kio-admin mc btrfs-progs exfatprogs ntfs-3g os-prober
    adb fastboot fsarchiver inxi pv rsync cdemu-daemon cdemu-client
    7zip makeself zenity innoextract needrestart flatpak timeshift
    # Python
    python3-defusedxml python3-packaging python3-pip python3-tqdm
    # Gaming / GPU
    libayatana-appindicator3-1 gamemode vulkan-tools mangohud
    vkd3d-compiler goverlay
    # Kompilacja
    gcc make cmake meson ninja-build just build-essential git
    # GStreamer
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly
    # Inne
    zsh zsh-syntax-highlighting zsh-autosuggestions
)

FAILED_PACKAGES=()
for pkg in "${PACKAGES_INSTALL[@]}"; do
    sudo apt-get install -yq "$pkg" || FAILED_PACKAGES+=("$pkg")
done
if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
    log_warn "Nie udało się zainstalować: ${FAILED_PACKAGES[*]}"
fi

# --- Winetricks ---
# Nawet na stable instalacja wersji z GitHuba bywa preferowana do gier (nowsze "verbsy")
log_info "Instalacja winetricks..."
sudo apt-get install -yq cabextract unzip wget >/dev/null 2>&1 || true
if sudo curl -fsSLo /usr/local/bin/winetricks \
        https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
     && sudo chmod +x /usr/local/bin/winetricks; then
    log_ok "Winetricks zainstalowany w najnowszej wersji bezpośrednio z GitHub"
elif sudo apt-get install -yq winetricks; then
    log_ok "Winetricks zainstalowany z systemowego repozytorium apt"
else
    log_warn "Nie udało się zainstalować winetricks — pomijam."
fi

# --- WINE ORAZ 32-BITOWE BIBLIOTEKI DO GIER ---
log_info "Instalacja Wine oraz 32-bitowych bibliotek (Audio, MangoHud)..."
wait_for_apt
sudo apt-get install -yq libpulse0:i386 libopenal1:i386 mangohud:i386

if sudo apt-get install -yq wine wine64 wine32:i386; then
    log_ok "Wine zainstalowany z głównego repozytorium Debiana 13."
else
    log_warn "Wystąpił problem z pakietem wine w systemie. Próba instalacji z repozytorium WineHQ..."
    sudo mkdir -pm755 /etc/apt/keyrings
    if sudo curl -fsSLo /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
        && sudo curl -fsSLo /etc/apt/sources.list.d/winehq.sources \
            https://dl.winehq.org/wine-builds/debian/dists/trixie/winehq-trixie.sources; then
        wait_for_apt
        sudo apt-get update -yq
        if sudo apt-get install -yq --install-recommends winehq-stable; then
            log_ok "Wine zainstalowany z repozytorium WineHQ."
        else
            log_err "Nie udało się zainstalować Wine ze źródła zapasowego."
        fi
    fi
fi

# ==========================================================
# WYKRYWANIE GPU: 32-BITOWE BIBLIOTEKI I MODUŁY INITRAMFS
# ==========================================================
log_info "Wykrywanie układu graficznego (biblioteki 32-bit oraz moduły jądra)..."
VGA_INFO=$(lspci -nn | grep -iE "VGA|3D|Display" || true)
MODULES_FILE="/etc/initramfs-tools/modules"

add_module() {
    grep -q "^$1" "$MODULES_FILE" || echo "$1" | sudo tee -a "$MODULES_FILE" > /dev/null
}

wait_for_apt
if echo "$VGA_INFO" | grep -iq "NVIDIA"; then
    log_ok "Wykryto układ NVIDIA. Instaluję biblioteki i dodaję moduł..."
    sudo apt-get install -yq libgl1-nvidia-glvnd-glx:i386
    add_module "nvidia"
    add_module "nvidia_modeset"
    add_module "nvidia_uvm"
    add_module "nvidia_drm"
elif echo "$VGA_INFO" | grep -iq "AMD"; then
    log_ok "Wykryto układ AMD. Instaluję biblioteki Mesa i dodaję moduł amdgpu..."
    sudo apt-get install -yq libgl1-mesa-dri:i386 mesa-vulkan-drivers:i386
    add_module "amdgpu"
elif echo "$VGA_INFO" | grep -iq "Intel"; then
    log_ok "Wykryto układ Intel. Instaluję biblioteki Mesa i dodaję moduł i915..."
    sudo apt-get install -yq libgl1-mesa-dri:i386 mesa-vulkan-drivers:i386
    add_module "i915"
else
    log_warn "Nie rozpoznano jednoznacznie układu. Instaluję domyślne pakiety Mesa."
    sudo apt-get install -yq libgl1-mesa-dri:i386 mesa-vulkan-drivers:i386
fi

log_info "Przebudowa obrazu initramfs..."
sudo update-initramfs -u

# --- Repozytorium Flathub ---
log_info "Dodawanie repozytorium Flathub..."
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

log_info "Odświeżanie metadanych Flathub..."
sudo flatpak update --appstream || true

# --- Gear Lever i Flatseal (Flathub) ---
log_info "Instalacja Flatseal z Flathub..."
sudo flatpak install -y flathub com.github.tchx84.Flatseal || log_warn "Błąd instalacji Flatseal"

log_info "Instalacja Gear Lever z Flathub..."
sudo flatpak install -y flathub it.mijorus.gearlever || log_warn "Błąd instalacji Gear Lever"

# --- Paczki .deb z internetu ---
log_info "Pobieranie i instalacja paczek .deb..."
mkdir -p "$DEB_DIR"

download_deb() {
    local name="$1" url="$2" dest="$3"
    if wget -q --timeout=30 -O "$dest" "$url"; then
        log_ok "Pobrano: $name"
    else
        log_warn "Nie udało się pobrać: $name ($url) — pomijam"
        rm -f "$dest"
    fi
}

get_github_deb_url() {
    local repo="$1" pattern="$2"
    curl -sf "https://api.github.com/repos/${repo}/releases/latest" \
        | grep "browser_download_url.*${pattern}" \
        | cut -d '"' -f 4 \
        || true
}

download_deb "Discord" \
    "https://discord.com/api/download?platform=linux&format=deb" \
    "$DEB_DIR/discord.deb"

LSFG_URL=$(get_github_deb_url "YuriSizov/ls-fg"    "ls-fg_.*deb")
LSFG_VK_URL=$(get_github_deb_url "YuriSizov/ls-fg-vk" "deb")
FAUGUS_URL=$(get_github_deb_url "faugus/faugus-launcher" "deb")

if [[ -n "$LSFG_URL" ]]; then download_deb "ls-fg" "$LSFG_URL" "$DEB_DIR/lsfg.deb"; fi
if [[ -n "$LSFG_VK_URL" ]]; then download_deb "ls-fg-vk" "$LSFG_VK_URL" "$DEB_DIR/lsfg-vk.deb"; fi
if [[ -n "$FAUGUS_URL" ]]; then download_deb "Faugus Launcher" "$FAUGUS_URL" "$DEB_DIR/faugus.deb"; fi

shopt -s nullglob
DEB_FILES=("$DEB_DIR"/*.deb)
if [[ ${#DEB_FILES[@]} -gt 0 ]]; then
    wait_for_apt
    sudo apt-get install -yq "${DEB_FILES[@]}"
else
    log_warn "Brak plików .deb do zainstalowania"
fi
shopt -u nullglob
rm -rf "$DEB_DIR"

# ==========================================================
# 4. WIRTUALIZACJA I FIREWALL
# ==========================================================
log_info "Konfiguracja wirtualizacji i UFW..."

wait_for_apt
sudo apt-get install -yq \
    virt-manager qemu-system qemu-utils \
    libvirt-daemon-system libvirt-clients \
    ovmf dnsmasq \
    bluetooth bluez bluez-firmware bluez-tools ufw

for svc in libvirtd virtqemud; do
    if systemctl list-unit-files "${svc}.service" 2>/dev/null | grep -q "$svc"; then
        sudo systemctl enable --now "${svc}.service"
        log_ok "Uruchomiono serwis: $svc"
        break
    fi
done

if ! sudo virsh net-info default &>/dev/null; then
    log_warn "Sieć 'default' nie jest zdefiniowana - definiuję z domyślnego XML..."
    sudo virsh net-define /usr/share/libvirt/networks/default.xml || true
fi
sudo virsh net-start default 2>/dev/null || true
sudo virsh net-autostart default || log_warn "Nie udało się ustawić autostartu sieci 'default'."

if command -v ufw &>/dev/null || [[ -x /usr/sbin/ufw ]]; then
    if [[ -f /etc/default/ufw ]]; then
        sudo sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' \
            /etc/default/ufw || true
    fi

    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow in  on virbr0
    sudo ufw allow out on virbr0
    sudo ufw allow from 192.168.122.0/24
    sudo ufw --force enable
else
    log_warn "ufw niedostępny — pomijam konfigurację firewalla"
fi

for grp in libvirt libvirt-qemu kvm; do
    if getent group "$grp" &>/dev/null; then
        sudo usermod -aG "$grp" "$CURRENT_USER" \
            && log_ok "Dodano $CURRENT_USER do grupy $grp"
    fi
done

# ==========================================================
# 5. PLYMOUTH (EKRAN STARTOWY)
# ==========================================================
log_info "Konfiguracja Plymouth (bgrt)..."

GRUB_PARAMS="quiet splash plymouth.ignore-serial-consoles"
if ! grep -q "plymouth.ignore-serial-consoles" /etc/default/grub; then
    sudo sed -i \
        "s|GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ${GRUB_PARAMS}\"|" \
        /etc/default/grub || true
fi

sudo plymouth-set-default-theme bgrt \
    || log_warn "plymouth-set-default-theme nie powiodło się (ignoruję)"
sudo update-grub
sudo update-initramfs -u \
    || log_warn "update-initramfs nie powiodło się (ignoruję)"

# ==========================================================
# 6. FINALIZACJA I OPTYMALIZACJA
# ==========================================================
log_info "Finalizacja i optymalizacja..."

sudo systemctl enable fstrim.timer || true
sudo journalctl --vacuum-time=2d || true

sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub || true
sudo update-grub

if [[ -f "$SCRIPT_DIR/piwo.png" ]]; then
    sudo mkdir -p /usr/share/plasma/avatars/ /var/lib/AccountsService/icons/
    sudo cp -af "$SCRIPT_DIR/piwo.png" /usr/share/plasma/avatars/piwo.png
    sudo cp -af "$SCRIPT_DIR/piwo.png" "/var/lib/AccountsService/icons/$CURRENT_USER"
    sudo chmod 644 \
        /usr/share/plasma/avatars/piwo.png \
        "/var/lib/AccountsService/icons/$CURRENT_USER"
fi

# Zmiana ekranu logowania
if [[ -f "$SCRIPT_DIR/login-wallpaper.png" ]]; then
    sudo mkdir -p /usr/share/wallpapers
    sudo cp -f "$SCRIPT_DIR/login-wallpaper.png" /usr/share/wallpapers/login-wallpaper.png
    sudo chmod 644 /usr/share/wallpapers/login-wallpaper.png
fi

# Kopiowanie konfiguracji logowania
if [[ -f "$SCRIPT_DIR/plasmalogin.conf" ]]; then
    sudo cp -f "$SCRIPT_DIR/plasmalogin.conf" /etc/plasmalogin.conf
    sudo chmod 644 /etc/plasmalogin.conf
fi

log_info "Zmiana Tapety..."
TARGET_DIR="$HOME/.local/share/wallpapers"

# Upewnienie się, że katalog docelowy istnieje
mkdir -p "$TARGET_DIR"

# Kopiowanie tapety do katalogu domowego
if [[ -f "$SCRIPT_DIR/wallpaper.jpg" ]]; then
    cp -f "$SCRIPT_DIR/wallpaper.jpg" "$TARGET_DIR/wallpaper.jpg"
    log_ok "Skopiowano wallpaper.jpg do $TARGET_DIR/wallpaper.jpg"
else
    log_warn "Brak pliku wallpaper.jpg w katalogu skryptu."
fi

if [[ -d "$SCRIPT_DIR/bleachbit" ]]; then
    sudo mkdir -p /root/.config/bleachbit
    sudo cp -af "$SCRIPT_DIR/bleachbit/." /root/.config/bleachbit/
    log_ok "Skopiowano konfigurację BleachBit"
fi

ACTIVE_CONN=$(nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null \
    | grep -v "^lo" | head -n 1 | cut -d: -f1 || true)
if [[ -n "$ACTIVE_CONN" ]]; then
    sudo nmcli connection modify "$ACTIVE_CONN" \
        ipv4.dns "1.1.1.1,1.0.0.1" \
        ipv6.dns "2606:4700:4700::1112,2606:4700:4700::1002"
    sudo nmcli connection up "$ACTIVE_CONN" || true
fi

# ==========================================================
# 7. ZSH + OH MY ZSH + POWERLEVEL10K
# ==========================================================
log_info "Konfiguracja ZSH..."

if command -v zsh &>/dev/null; then
    sudo chsh -s /usr/bin/zsh "$CURRENT_USER"

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
            "" --unattended || true
    fi

    P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    if [[ ! -d "$P10K_DIR" ]]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR" || true
    fi

    ZSHRC="$HOME/.zshrc"
    if [[ -f "$ZSHRC" ]]; then
        sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$ZSHRC" || true
        sed -i 's/^plugins=(.*/plugins=(git sudo systemd debian)/' "$ZSHRC" || true
        grep -q "LC_ALL=pl_PL.UTF-8" "$ZSHRC" || echo "export LC_ALL=pl_PL.UTF-8" >> "$ZSHRC"
        grep -q "^fastfetch"         "$ZSHRC" || echo "fastfetch"                  >> "$ZSHRC"
        grep -q "zsh-syntax-highlighting.zsh" "$ZSHRC" || echo "source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> "$ZSHRC"
        grep -q "zsh-autosuggestions.zsh"     "$ZSHRC" || echo "source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"         >> "$ZSHRC"
    fi
fi

# ==========================================================
# 8. KOPIOWANIE KONFIGURACJI I ZMIANA TAPETY
# ==========================================================
log_info "Zatrzymywanie środowiska KDE, aby nie nadpisało naszych zmian..."
systemctl --user stop plasma-plasmashell.service 2>/dev/null || true
kquitapp6 plasmashell 2>/dev/null || killall -9 plasmashell 2>/dev/null || true
sleep 2

log_info "Kopiowanie plików konfiguracyjnych na uśpionym środowisku..."
if [[ -d "$SCRIPT_DIR/.config" ]]; then cp -af "$SCRIPT_DIR/.config/." ~/.config/; fi
if [[ -d "$SCRIPT_DIR/.local" ]]; then cp -af "$SCRIPT_DIR/.local/." ~/.local/; fi
if [[ -d "$SCRIPT_DIR/.icons" ]]; then cp -af "$SCRIPT_DIR/.icons/." ~/.icons/; fi

if [[ "$OLD_USER_PLACEHOLDER" != "$CURRENT_USER" ]]; then
    grep -rl --include="*.conf" --include="*.json" --include="*.ini" \
        "/home/$OLD_USER_PLACEHOLDER" ~/.config 2>/dev/null \
        | xargs -r sed -i "s|/home/$OLD_USER_PLACEHOLDER|/home/$CURRENT_USER|g" || true
fi

log_info "Czyszczenie pamięci podręcznej (Cache)..."
rm -rf ~/.cache/icon-cache.kcache ~/.cache/plasma* ~/.cache/ico*

log_info "Tworzenie wymuszenia tapety przy najbliższym starcie systemu..."
WALLPAPER_PATH="$HOME/.local/share/wallpapers/wallpaper.jpg"
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

# Tworzymy plik .desktop, który wstrzeliwuje tapetę bezpośrednio w działającą sesję
# Skrypt będzie próbował użyć plasma-apply-wallpaperimage. Jeśli operacja się uda (kod 0),
# plik usunie sam siebie z autostartu i przerwie pętlę.
cat > "$AUTOSTART_DIR/force-wallpaper.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Wymuszenie Tapety
Exec=bash -c 'for i in {1..30}; do plasma-apply-wallpaperimage "$WALLPAPER_PATH" && rm -f "$AUTOSTART_DIR/force-wallpaper.desktop" && break; sleep 2; done'
Hidden=false
NoDisplay=true
X-KDE-autostart-condition=
EOF

chmod +x "$AUTOSTART_DIR/force-wallpaper.desktop"
log_ok "Zadanie zmiany tapety zostało zakolejkowane do wykonania po restarcie."

# Odbudowa bazy systemowej
if command -v kbuildsycoca6 &>/dev/null; then
    kbuildsycoca6 --noincremental &>/dev/null || true
fi

# ==========================================================
log_info "Sprzątanie po instalacji..."
sudo rm -f /etc/sudoers.d/99-temp-installer

log_ok "KONFIGURACJA ZAKOŃCZONA SUKCESEM!"
sleep 3
systemctl reboot

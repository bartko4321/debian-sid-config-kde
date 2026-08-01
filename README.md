# 🚀 Debian + KDE Plasma: Comprehensive Configuration Script

An automated, powerful Bash script designed to transform a clean **Debian** installation with **KDE Plasma** into a complete, optimized workstation ready for both work and entertainment.

> ⚠️ **Note:** At the end of its execution, the script automatically restarts the system to apply all changes (including kernel modules and Plymouth configuration).

---

## ✨ Main Features

The script performs a full system deployment divided into several logical stages:

### ⚙️ 1. Repositories & Updates
* Disables outdated CD-ROM entries in `sources.list`.
* Enables the `i386` architecture (required for games and Wine).
* Extends repositories with `contrib`, `non-free`, and `non-free-firmware` sections (supports both the old format and the new `DEB822` format in Debian).
* Adds official repositories for external applications: **Google Chrome** and **Brave Browser**.
* Activates the **Flathub** repository (Flatpak).
* Safely waits for APT locks held by other system processes to be released.

### 🎮 2. Gaming, Drivers & Wine
* **Smart GPU Detection:** Automatically identifies your graphics card (NVIDIA / AMD / Intel) and installs dedicated 32-bit libraries, adding the appropriate modules to `initramfs` (forcing early KMS loading for smooth booting).
* Installs the latest stable version of **Wine** along with 32-bit audio libraries (PulseAudio, OpenAL).
* Automatically downloads and configures the latest version of **Winetricks**.
* Installs useful gaming tools: `gamemode`, `mangohud`, `vulkan-tools`, `vkd3d-compiler`, `goverlay`.

### 📦 3. Package Management
* **Debloat:** Removes unnecessary or rarely used KDE applications (e.g. Konqueror, KMail, Akonadi, Kontact, Plasma Welcome).
* **Everyday tools installation:** Over 40 hand-picked packages (including VLC/GStreamer, Telegram, QBitTorrent, Kdenlive, Audacity, Krita, Vim, Fastfetch, BleachBit, rsync, 7zip, and many more).
* **Hardware detection:** Automatically installs missing firmware using `isenkram`.
* Automatically downloads the latest `.deb` packages from designated GitHub releases (e.g. Discord, faugus-launcher, ls-fg).

### 🔒 4. Virtualization & Firewall (UFW)
* Installs and configures the **QEMU/KVM** virtualization environment and **Virt-Manager**.
* Automatically adds the current user to the `libvirt`, `libvirt-qemu`, and `kvm` groups.
* Configures and enables the **UFW** firewall — blocks incoming traffic by default, allows outgoing, and opens the necessary ports for the virtualization network bridge (`virbr0`).

### 🎨 5. KDE Plasma Personalization
* **Safe sync:** Copies your pre-made configuration files (`.config`, `.local`, `.icons`) after safely suspending the `plasmashell` process — preventing KDE from overwriting your settings with defaults during shutdown.
* **User migration:** Automatically scans config files and replaces the old user placeholder (`bartek`) with your current account name.
* Configures the **Plymouth** boot splash (using the `bgrt` theme) and hides unnecessary GRUB messages (`quiet splash`).
* Automatically sets the user avatar, custom KDE splash screen, and wallpapers in multiple resolutions for the *Next* theme.

### 🐚 6. Modern Shell (ZSH)
* Sets **ZSH** as the default user shell.
* Installs the **Oh My ZSH** framework in unattended mode.
* Downloads and activates the powerful **Powerlevel10k** theme.
* Adds automatic `fastfetch` invocation on terminal startup and enforces correct UTF-8 encoding.

### ⚡ 7. System Optimizations
* Enables regular SSD trimming via `fstrim.timer`.
* Clears old systemd system logs (`journalctl --vacuum-time=2d`).
* Sets the GRUB menu timeout to `0` seconds (instant boot).
* Configures fast and secure DNS servers (Cloudflare `1.1.1.1`) directly in the active **NetworkManager** configuration.

---

## 📂 Required Directory Structure

To allow the script to fully utilize its potential and not skip the visual configuration steps, make sure the following files and folders are present in the script's directory before running it (the script safely skips any missing items):

```text
📂 Your-Repository/
├── 📄 install.sh           # Main installation script
├── 📄 .update.sh          # (Optional) Your personal update script
├── 📄 piwo.png            # (Optional) User avatar image
├── 📄 1920x1080.png       # (Optional) System wallpapers for the Next theme
├── 📄 2560x1440.png       
├── 📄 5120x2880.png       
├── 📂 bleachbit/          # (Optional) Pre-configured BleachBit settings for root
├── 📂 .config/            # (Optional) Your application configuration files
├── 📂 .local/             # (Optional) Local app data / scripts
└── 📂 .icons/             # (Optional) Custom icons / mouse cursors
```

---
### Adding a user to the sudo group:
```bash
sudo usermod -aG sudo $USER
```
## 🚀 How to Run

The script **cannot** be run directly from the `root` account (via `su` or `sudo ./install.sh`). Run it as a regular user with `sudo` privileges. The script will ask for your password once, then temporarily remove the password requirement for installation processes to run uninterrupted.

### Step 1: Clone the repository or download the files
```bash
git clone https://github.com/bartko4321/debian-sid-config-kde.git
```

### Step 2: Enter the downloaded folder
```bash
cd debian-config-kde-sid
```

### Step 3: Make the script executable
```bash
chmod +x install.sh
```

### Step 4: Run the script
```bash
./install.sh
```

Once the process is complete, the computer will restart automatically. After logging in, you'll be greeted by a fully configured ZSH environment and a customized KDE Plasma desktop!

### ☕ Support the Project

If you find this tool helpful and it saved you some time, consider buying me a coffee to support further development! 

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/bartekszczecinski)

---
<img width="1920" height="1080" alt="Zrzut ekranu_20260716_191008" src="https://github.com/user-attachments/assets/8aa4321c-788b-4109-bf77-d22a78e44f7f" />

If you find this project useful, leave a star! ⭐

---
_This script was created to minimize system setup time after a clean installation. Use at your own risk!_

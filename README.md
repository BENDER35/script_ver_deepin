# 🖥️ Desktop Environment Manager for Deepin / Debian

An interactive, robust and automated Bash script for selecting, verifying, repairing and installing different desktop environments (Desktop Environments) on **Deepin OS**, **Debian GNU/Linux** and derived systems. In addition, it allows **detecting installed environments and configuring which one boots automatically at login**.

---

## 📋 Table of Contents

- [✨ Key Features](#-key-features)
- [🪟 Supported Desktop Environments](#-supported-desktop-environments)
- [⚙️ Prerequisites](#-prerequisites)
- [🚀 Quick Installation and Use](#-quick-installation-and-use)
- [🔑 Automatic Session Boot Configuration](#-automatic-session-boot-configuration)
- [🔄 Working Flow](#-working-flow)
- [📁 Project Structure](#-project-structure)
- [🛠️ Troubleshooting](#-troubleshooting)
- [📚 Additional Documentation](#-additional-documentation)

---

## ✨ Key Features

1. **Interactive and Friendly Menu:** Clear colored interface for Linux terminals.
2. **Automatic and Precise Privilege Elevation:** Allows auditing and consulting environments without root; only requests `sudo` when necessary to write to the system (install or change configuration files).
3. **Detailed Package Package Diagnosis:** Checks package by package using `dpkg-query` to accurately detect:
   - Components already installed (`[✓]`).
   - Missing components in the system (`[✗]`).
   - Packages not available in local repositories (`[?]`).
4. **Selective and Intelligent Installation:**
   - If the environment is already complete, informs the user and does not perform unnecessary downloads.
   - If packages are missing (part of the environment or the full environment), requests confirmation before installing.
   - Automatically updates repositories (`apt-get update`) and resolves dependencies.
5. **Automatic Session Boot Configuration:**
   - Dynamically scans `/usr/share/xsessions/*.desktop` (X11) and `/usr/share/wayland-sessions/*.desktop` (Wayland).
   - Shows the list of detected environments and asks which one the user wants to boot automatically at login.
   - Applies changes in key system layers:
     - **AccountsService (`/var/lib/AccountsService/users/<user>`):** Sets `Session=` and `XSession=`. The standard read by Deepin Greeter, GDM and LightDM.
     - **Local `~/.dmrc` file:** Defines the `Session=` variable in the user profile.
     - **LightDM (`/etc/lightdm/lightdm.conf.d/50-default-session.conf`):** Defines the global `user-session=` directive.
     - **SDDM (`/etc/sddm.conf.d/50-default-session.conf`):** In case SDDM is present.
     - **update-alternatives:** Adjusts `x-session-manager` if an alternative binary is registered for that environment.
6. **Restart Control:**
   - Detects if there were changes or installations in the system.
   - Requests user confirmation to restart the equipment (`reboot`) safely, allowing the session manager to recognize the new environment.

---

## 🪟 Supported Desktop Environments

| Environment | Description | Key Packages Evaluated | Typical Display Manager |
| :--- | :--- | :--- | :--- |
| **Budgie** | Modern and light | `budgie-desktop`, `budgie-wm`, `gdm3` | GDM3 |
| **DDE** | Deepin Desktop Environment (native) | `dde`, `dde-desktop`, `dde-dock`, `dde-control-center`, `dde-file-manager`, `dde-session-ui`, `dde-kwin` | LightDM (deepin-greeter) |
| **GNOME** | Modern, focused on productivity | `gnome-core`, `gnome-shell`, `gnome-session`, `gnome-terminal`, `nautilus` | GDM3 |
| **KDE Plasma** | Elegant, flexible and customizable | `kde-plasma-desktop`, `plasma-workspace`, `dolphin`, `konsole` | SDDM |
| **XFCE** | Fast, light and low consumption | `xfce4`, `xfce4-goodies`, `xfce4-terminal`, `thunar` | LightDM |
| **Cinnamon** | Traditional, modern and stylized | `cinnamon-core`, `cinnamon`, `nemo`, `gnome-terminal` | LightDM |
| **MATE** | Traditional (continuation of GNOME 2) | `mate-desktop-environment-core`, `mate-desktop-environment`, `caja`, `mate-terminal` | LightDM |
| **LXQt** | Ultralight based on Qt libraries | `lxqt-core`, `lxqt`, `pcmanfm-qt`, `qterminal` | SDDM |

---

## ⚙️ Prerequisites

- **Operating System:** Deepin OS (version 20.x, 23.x or higher) or Debian / derivatives (Ubuntu, Linux Mint Debian Edition, etc.).
- **Package Manager:** `apt` and `dpkg`.
- **Privileges:** User with `sudo` access or `root` account.
- **Internet Connection:** Required to download packages from official repositories.

---

## 🚀 Quick Installation and Use

### 1. Get into the directory
```bash
cd /home/bender/Descargas/script_ver_deepin
```

### 2. Grant execution permissions
```bash
chmod +x gestor_escritorios.sh
```

### 3. Run the script
```bash
./gestor_escritorios.sh
```
*(You can also invoke it directly with `sudo ./gestor_escritorios.sh`)*.

---

## 🔑 Automatic Session Boot Configuration

The script includes a module to define which environment should boot automatically immediately after login:

### How it works?
1. Automatically detects installed sessions in the system by reading standard definitions in `/usr/share/xsessions/` (X11) and `/usr/share/wayland-sessions/` (Wayland).
2. Asks the user which environment they want to boot automatically.
3. Applies changes in the key system layers:
   - **AccountsService (`/var/lib/AccountsService/users/<user>`):** Sets `Session=` and `XSession=`. It is the standard read by Deepin Greeter, GDM and LightDM.
   - **Local `~/.dmrc` file:** Defines the `Session=` variable in the user profile.
   - **LightDM (`/etc/lightdm/lightdm.conf.d/50-default-session.conf`):** Defines the global directive `user-session=`.
   - **SDDM (`/etc/sddm.conf.d/50-default-session.conf`):** In case SDDM is present.
   - **update-alternatives:** Adjusts `x-session-manager` if there is an alternative binary registered for that environment.

---

## 🔄 Working Flow

```text
[Start]
   │
   ▼
[Main Menu]
   ├── Options 1-7: Manage Environment (DDE, GNOME, KDE, XFCE...)
   │      │
   │      ▼
   │   [DPKG Audit]
   │      ├── All installed? ──► Notify success
   │      └── Missing packages?  ──► Confirm installation ──► apt update && apt install
   │                                                             │
   │      └──────────────────────────────────────────────────────┘
   │      ▼
   │   [Ask: Configure automatic boot?] ──(Yes)──► [Scan & Select Environment]
   │      │
   │      ▼
   │   [Was there installation?] ──(Yes)──► [Ask: Restart team? (y/n)]
   │
   └── Option 8: Configure automatic boot environment directly
   └── Option 9: Exit
```

---

## 📁 Project Structure

```text
/home/bender/Descargas/script_ver_deepin/
├── gestor_escritorios.sh  # Main executable script
├── README.md              # General documentation and user manual
└── GUIA_DIDACTICA.md      # Step-by-step didactic guide on internal operation
```

---

## 🛠️ Troubleshooting

### 1. Message: "Not available in repositories"
- Check your Internet connection.
- Update indices with `sudo apt update`.
- Review `/etc/apt/sources.list` to ensure official Deepin or Debian sources are active.

### 2. Changing environment manually on the login screen
- If you want to switch between environments at any time without running the script, click the session icon (gear or logo) on the Deepin/LightDM login screen, choose the desired desktop and enter your password.

---

## 📚 Additional Documentation

To understand the Linux graphical architecture in depth, the functioning of DDE and the step-by-step analysis of each script function, consult the [Didactic Guide](file:///home/bender/Descargas/script_ver_deepin/GUIA_DIDACTICA.md).
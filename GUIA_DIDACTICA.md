# 🎓 Didactic Guide: Desktop Environment Management in Deepin and Debian

Welcome to the **Didactic Guide**. This document has been elaborated with a pedagogical focus for students, system administrators and GNU/Linux enthusiasts who wish to comprehend in depth both the theoretical concepts of graphical environments as well as the Bash programming that makes possible the automation of the `gestor_escritorios.sh` script.

---

## 📑 Table of Contents

1. [🧑‍💻 Theoretical Foundations: What is a Desktop Environment?](#1-fundamentos-teóricos-qué-es-un-entorno-de-escritorio)
   - 1.1 The Graphical Stack in GNU/Linux
   - 1.2 Anatomy of DDE (Deepin Desktop Environment)
   - 1.3 How the system recognizes a new environment? (XSession / Wayland)
   - 1.4 How is the automatic login environment defined in Linux?
2. [🔍 Detailed Analysis of the `gestor_escritorios.sh` Script](#2-análisis-detallado-del-script-gestor_escritoriossh)
   - 2.1 Interpreter Directive (Shebang) and ANSI Visual Format
   - 2.2 On-demand Administrative Privileges Management (`asegurar_root`)
   - 3. Low-level Package Diagnosis with `dpkg-query`
   - 4. Dynamic Detection of Installed Environments (`listar_entornos_instalados`)
   - 5. Automatic Session Boot Configuration (`configurar_arranque_automatico`)
   - 6. User Interaction and Default Parameters
   - 7. Controlled APT Installation Process
   - 8. Safe System Restart Mechanism
3. [📊 Comparative Table of Supported Environments](#3-tabla-comparativa-de-los-entornos-soportados)
4. [🛠️ Practical Workshop and Self-Evaluation Questions](#4-taller-práctico-y-preguntas-de-autoevaluación)

---

## 1. 🧑‍💻 Theoretical Foundations: What is a Desktop Environment?

In GNU/Linux operating systems, unlike other environments such as Microsoft Windows or macOS, the **Graphical User Interface (GUI)** is completely decoupled from the system **Kernel**. A user can run Linux without a graphical interface (terminal/server mode) or install one or multiple desktop environments simultaneously.

### 1.1 The Graphical Stack in GNU/Linux

For a window to appear on screen and interact with the mouse and keyboard, several layers of software intervene:

```text
┌────────────────────────────────────────────────────────┐
│               User Applications                        │
│       (Browser, File Manager, Terminal)                │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│             Desktop Environment (DE)                   │
│      Shell, Panels, Menus, Widgets, Configuration      │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│             Window Manager (WM)                        │
│    Controls borders, moving, resizing, minimizing        │
│    (kwin, mutter, xfwm4, dde-kwin)                     │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│         Display Manager (DM)                           │
│    Login screen and session selector                   │
│    (LightDM, GDM3, SDDM)                               │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│        Graphical Server (X11 / Wayland)                │
│    Draws pixels and communicates peripherals with hw   │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│       Linux Kernel (DRM/KMS)                           │
└────────────────────────────────────────────────────────┘
```

1. **Graphical Server:** Translates drawing requests to video hardware. The two standards are **X11** (X.Org) and **Wayland**.
2. **Display Manager (DM):** The program that runs when the system boot finishes. It shows the login screen (Login), allows user authentication and **chooses which graphical environment to boot**. Examples: `lightdm`, `gdm3`, `sddm`.
3. **Window Manager (WM):** Responsible for managing the appearance, position, decoration (close/minimize buttons) and behavior of windows. Examples: `dde-kwin`, `mutter`, `kwin`, `xfwm4`.
4. **Desktop Environment (DE):** The complete package that integrates the window manager with a panel (dock/taskbar), application menu, control center, file manager and homogeneous icons.

---

### 1.2 Anatomy of DDE (Deepin Desktop Environment)

**Deepin OS** uses its own environment called **DDE**. DDE stands out for its visual elegance, extensive use of Qt5/Qt6 libraries and DTK (Deepin Tool Kit). Its key pieces are:

- **`dde-desktop`:** Manages the desktop background, desktop icons and contextual menus.
- **`dde-dock`:** The bottom taskbar supporting two modes: *Fashion Mode* (centered dock style) and *Efficient Mode* (traditional end-to-end style).
- **`dde-control-center`:** The translucent side panel for adjusting network, screen, users and themes.
- **`dde-file-manager`:** The official Deepin file manager.
- **`dde-kwin`:** A personalized fork of the KDE (KWin) window manager, optimized with effects and animations for Deepin.
- **`lightdm` + `deepin-greeter`:** The display manager and graphical login interface.

---

### 1.3 How the system recognizes a new environment? (XSession / Wayland)

When you install an environment like XFCE, GNOME or DDE, the package manager places a `.desktop` configuration file in system directories:
- For **X11** based sessions: `/usr/share/xsessions/*.desktop` (examples: `deepin.desktop`, `xfce.desktop`, `gnome.desktop`).
- For **Wayland** based sessions: `/usr/share/wayland-sessions/*.desktop` (examples: `plasmawayland.desktop`, `xfce-wayland.desktop`).

Each file defines, among other properties:
```ini
[Desktop Entry]
Name=Deepin
Comment=This session logs you into Deepin Desktop Environment
Exec=/usr/bin/startdde
Type=Application
```

The **session identifier (Session ID)** is the filename without the `.desktop` extension (for example, `deepin`, `xfce`, `gnome`).

---

### 1.4 How is the automatic login environment defined in Linux?

In a modern Debian/Deepin-based distribution different layers coexist to remember or force the environment with which a user boots:

1. **AccountsService (`/var/lib/AccountsService/users/<user>`):**
   D-Bus service used by modern display managers (Deepin Greeter, GDM3, LightDM). Saves the keys:
   ```ini
   [User]
   Session=deepin
   XSession=deepin
   ```

2. **User `~/.dmrc` file:**
   Historical standard used by LightMDM:
   ```ini
   [Desktop]
   Session=deepin
   ```

3. **Global Display Manager configuration:**
   In LightMDM (`/etc/lightdm/lightdm.conf.d/50-default-session.conf`):
   ```ini
   [Seat:*]
   user-session=deepin
   ```

4. **Debian Alternatives System (`update-alternatives`):**
   Registers the symbolic link of the default session manager `/usr/bin/x-session-manager`.

The `gestor_escritorios.sh` script updates **all these layers coherently** to ensure the change takes effect immediately.

---

## 2. 🔍 Detailed Analysis of the `gestor_escritorios.sh` Script

A continuación, descomponemos las secciones del código para entender la lógica técnica empleada.

### 2.1 Interpreter Directive (Shebang) and ANSI Visual Format

```bash
#!/usr/bin/env bash
```

- **Why `#!/usr/bin/env bash` instead of `#!/bin/bash`?**
  Guarantees portability between different UNIX/Linux distributions where the absolute path of `bash` may vary, resolving the route through the `PATH` environment variable.

- **ANSI Escape Codes:**
  ```bash
  COLOR_RESET="\e[0m"
  COLOR_BOLD="\e[1m"
  COLOR_ROJO="\e[31m"
  COLOR_VERDE="\e[32m"
  COLOR_CYAN="\e[36m"
  ```
  Allow coloring terminal output (`\e[32m` activates green, `\e[0m` resets to neutral format), providing a clear and professional visual experience to the user.

---

### 2.2 On-demand Administrative Privileges Management (`asegurar_root`)

```bash
asegurar_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${COLOR_AMARILLO}[!] This action requires administrator privileges (root).${COLOR_RESET}"
        echo -e "${COLOR_CYAN}[i] Requesting authentication with sudo...${COLOR_RESET}"
        if sudo -v; then
            SUDO_CMD="sudo"
            return 0
        else
            echo -e "${COLOR_ROJO}[!] Authentication failed or permissions denied.${COLOR_RESET}"
            return 1
        fi
    else
        SUDO_CMD=""
        return 0
    fi
}
```

- **Non-intrusive design:** The user can start the script, navigate through the menus and check what packages they have installed without needing to type their administrator password.
- Only when a **installation**, **system configuration change** or **restart** is confirmed, `asegurar_root` is invoked.
- `sudo -v`: Updates or validates the `sudo` authentication token cleanly. If successful, the `SUDO_CMD="sudo"` variable is defined.

---

### 3. Low-level Package Diagnosis with `dpkg-query`

```bash
esta_instalado() {
    local paquete="$1"
    local estado
    estado=$(dpkg-query -W -f='${Status}' "$paquete" 2>/dev/null || true)
    [[ "$estado" == *"install ok installed"* ]]
}
```

- **Why `dpkg-query` instead of `apt list --installed` or `which`?**
  1. `dpkg-query` consults the local state database (`/var/lib/dpkg/status`) directly, so its execution is almost instantane (does not require consulting network caches or waiting for APT locks).
  2. `apt list` shows a warning in automated scripts ("WARNING: apt does not have a stable CLI interface").
  3. `which` only searches executable binaries in the `$PATH`, omitting packages that contain libraries, icons, plugins or themes.

---

### 4. Dynamic Detection of Installed Environments (`listar_entornos_instalados`)

```bash
listar_entornos_instalados() {
    ENTORNOS_IDS=()
    ENTORNOS_NOMBRES=()
    ENTORNOS_TIPOS=()

    local archivos_sesion=(
        /usr/share/xsessions/*.desktop
        /usr/share/wayland-sessions/*.desktop
    )

    for archivo in "${archivos_sesion[@]}"; do
        [[ -f "$archivo" ]] || continue
        local id
        id="$(basename "$archivo" .desktop)"

        [[ "$id" == "lightdm-xsession" ]] && continue

        local nombre
        nombre=$(grep -E "^Name=" "$archivo" | head -n1 | cut -d= -f2-)
        [[ -z "$nombre" ]] && nombre="$id"

        local tipo="X11"
        [[ "$archivo" == *"wayland"* ]] && tipo="Wayland"

        ENTORNOS_IDS+=("$id")
        ENTORNOS_NOMBRES+=("$nombre")
        ENTORNOS_TIPOS+=("$tipo")
    done
}
```

- Reads all session files present in `/usr/share/xsessions/` and `/usr/share/wayland-sessions/`.
- Extracts the descriptive name (`Name=...`) and the session identifier (`id`).
- Automatically discriminates if the session will run under the **X11** or **Wayland** graphical protocol.
- Stores the results in three synchronized index arrays (`$i`).

---

### 5. Automatic Session Boot Configuration (`configurar_arranque_automatico`)

When the user selects the desired environment (for example, `Deepin`, `XFCE Session` or `GNOME`), the script performs the corresponding modifications:

1. **Detection of the real user:**
   ```bash
   target_user=$(obtener_usuario_objetivo)
   ```
   If the script was invoked via `sudo`, the `$SUDO_USER` variable stores the real user (not `root`), avoiding configuring the session for the administrative user.

2. **AccountsService modification:**
   Updates `/var/lib/AccountsService/users/$target_user` replacing or adding the `Session=<id>` and `XSession=<id>` directives.

3. **Local `~/.dmrc` file writing:**
   Saves `Session=<id>` and assigns correct permissions (`chown` and `chmod 644`).

4. **LightDM and SDDM adjustment:**
   Writes `/etc/lightdm/lightdm.conf.d/50-default-session.conf` with `user-session=<id>`.

5. **`update-alternatives` adjustment:**
   Checks if there is a binary registered in `x-session-manager` that matches the chosen environment and activates it.

---

### 6. User Interaction and Default Parameters

```bash
read -rp "Which environment do you want to boot automatically when you log in? (1-${#ENTORNOS_IDS[@]}): " eleccion
```

- Checks that the entered option is numeric and within the valid range (`(( eleccion >= 1 && eleccion <= ${#ENTORNOS_IDS[@]} ))`).
- Offers the option `0` to cancel without altering system configuration.

---

### 7. Controlled APT Installation Process

```bash
$SUDO_CMD apt-get update -y
DEBIAN_FRONTEND=dialog $SUDO_CMD apt-get install -y "${paquetes_faltantes[@]}"
```

1. **`apt-get update -y`:** Synchronizes the most recent package indices to avoid `404 Not Found` errors in repositories.
2. **`DEBIAN_FRONTEND=dialog`:** Allows the package installer to show an interactive window accessible in the console if it needs the user to choose the default display manager (for example, choosing between `lightdm` and `gdm3`).
3. **`"${paquetes_faltantes[@]}"`:** Only downloads and installs the packages that really lack in the system, saving time and bandwidth.

---

### 8. Safe System Restart Mechanism

When graphical environment packages or a new display manager are installed, the system services must be reconfigured:

```bash
if [[ "$respuesta_reinicio" =~ ^[sS]$|^[sS][iI]$ ]]; then
    echo -e "\n[+] Reiniciando el sistema en 3 segundos..."
    sleep 3
    if command -v systemctl &>/dev/null; then
        $SUDO_CMD systemctl reboot
    else
        $SUDO_CMD reboot
    fi
fi
```

- **Strict conditional:** The question is only asked **if and only if** there was an effective package installation in that session.
- **Restart compatibility:** It checks if `systemctl` exists (Systemd standard present in modern Deepin and Debian) and invokes `systemctl reboot`. If not available, it uses the traditional `reboot` binary.
- **Courtesy timer:** A 3-second delay (`sleep 3`) gives the user time to cancel with `Ctrl+C` if they changed their mind at the last second.

---

## 3. 📊 Comparative Table of Supported Environments

| Environment | Approx. RAM Consumption | Framework / Toolkit | Recommended for... |
| :--- | :--- | :--- | :--- |
| **DDE** | ~800 MB - 1.2 GB | Qt5 / DTK | Native experience and visually polished on Deepin. |
| **GNOME** | ~900 MB - 1.4 GB | GTK3 / GTK4 | Modern teams, minimalist design without distractions. |
| **KDE Plasma** | ~600 MB - 900 MB | Qt5 / Qt6 | Users who want to customize every detail and animation. |
| **XFCE** | ~350 MB - 500 MB | GTK3 | Teams with limited resources or maximum speed search. |
| **Cinnamon** | ~650 MB - 900 MB | GTK3 | Users accustomed to traditional Windows-type design. |
| **MATE** | ~400 MB - 600 MB | GTK3 | Lovers of the classic GNOME 2 workflow. |
| **LXQt** | ~300 MB - 450 MB | Qt5 / Qt6 | Old computers requiring Qt-based architecture. |
| **Budgie** | ~500 MB - 800 MB | GNOME-like | Users seeking a balance between modernity and resource consumption. |

---

## 4. 🛠️ Practical Workshop and Self-Evaluation Questions

Test the knowledge acquired with this guide:

### Theoretical Questions

1. **What is the fundamental difference between a *Display Manager* and a *Window Manager*?**
   - *Answer:* The Display Manager manages the authentication screen and loads the selected session; the Window Manager manages the positioning, dimensions and frames of the windows once the session has started.

2. **In which system paths does the Display Manager look for available environments to start a session?**
   - *Answer:* In `/usr/share/xsessions/*.desktop` (for X11) and in `/usr/share/wayland-sessions/*.desktop` (for Wayland).

3. **Why is `/var/lib/AccountsService/users/<user>` updated in addition to `~/.dmrc`?**
   - *Answer:* Because modern display managers like LightDM with `deepin-greeter` or GDM3 primarily read the AccountsService service via D-Bus to remember each user's preferred session.

### Practical Exercises

1. **Add a new environment:** Modify the `obtener_paquetes_entorno()` function in `gestor_escritorios.sh` to include a *tiling window manager* like `i3` or `bspwm`.
2. **Logging (Logging):** Modify the script so that each successful installation or default environment change saves a record with date and time in `/var/log/gestor_escritorios.log`.
3. **Disk space check:** Add a validation with `df -h /` before launching `apt-get install` to ensure the system has at least 2 GB of free space before proceeding.
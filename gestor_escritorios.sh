#!/usr/bin/env bash
# ==============================================================================
# Script: gestor_escritorios.sh
# Descripción: Permite elegir, verificar e instalar entornos de escritorio en
#              Deepin OS / Debian y derivados. Verifica paquetes faltantes,
#              configura el entorno predeterminado para el arranque automático
#              de sesión y ofrece reiniciar el sistema tras instalar.
# Versión: 2.0 - Con mejoras completas de diagnóstico, seguridad y usabilidad
# ==============================================================================

# Colores para la interfaz de consola
COLOR_RESET="\e[0m"
COLOR_BOLD="\e[1m"
COLOR_ROJO="\e[31m"
COLOR_VERDE="\e[32m"
COLOR_AMARILLO="\e[33m"
COLOR_AZUL="\e[34m"
COLOR_CYAN="\e[36m"
COLOR_BLANCO="\e[97m"

# Prefijo para comandos administrativos
SUDO_CMD=""

# Modo simulación (dry-run) - para probar sin hacer cambios
DRY_RUN=false

# ==================== FUNCIONES AUXILIARES ====================

imprimir_banner() {
    clear
    echo -e "${COLOR_CYAN}${COLOR_BOLD}"
    echo "======================================================================"
    echo "         GESTOR DE ENTORNOS DE ESCRITORIO PARA DEEPIN / DEBIAN        "
    echo "======================================================================"
    echo -e "${COLOR_RESET}"
}

asegurar_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${COLOR_AMARILLO}[!] Esta acción requiere permisos de administrador (root).${COLOR_RESET}"
        echo -e "${COLOR_CYAN}[i] Solicitando autenticación con sudo...${COLOR_RESET}"
        if sudo -v; then
            SUDO_CMD="sudo"
            return 0
        else
            echo -e "${COLOR_ROJO}[!] Autenticación fallida o permisos denegados.${COLOR_RESET}"
            return 1
        fi
    else
        SUDO_CMD=""
        return 0
    fi
}

obtener_usuario_objetivo() {
    local target="${SUDO_USER:-$USER}"
    if [[ "$target" == "root" || -z "$target" ]]; then
        local regular_user
        regular_user=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd 2>/dev/null)
        if [[ -n "$regular_user" ]]; then
            target="$regular_user"
        else
            target="root"
        fi
    fi
    echo "$target"
}

# Verificar si un paquete está instalado
esta_instalado() {
    local paquete="$1"
    local estado
    estado=$(dpkg-query -W -f='${Status}' "$paquete" 2>/dev/null || true)
    [[ "$estado" == *"install ok installed"* ]]
}

# Comprobar la existencia del paquete en los repositorios de APT
existe_en_repos() {
    local paquete="$1"
    apt-cache show "$paquete" &>/dev/null
}

# Escanear y listar los entornos de escritorio instalados actualmente en el sistema
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

        # Omitir entradas genéricas auxiliares como lightdm-xsession
        if [[ "$id" == "lightdm-xsession" ]]; then
            continue
        fi

        local nombre
        nombre=$(grep -E "^Name=" "$archivo" | head -n1 | cut -d= -f2-)
        [[ -z "$nombre" ]] && nombre="$id"

        local tipo="X11"
        if [[ "$archivo" == *"wayland"* ]]; then
            tipo="Wayland"
        fi

        ENTORNOS_IDS+=("$id")
        ENTORNOS_NOMBRES+=("$nombre")
        ENTORNOS_TIPOS+=("$tipo")
    done
}

# Mostrar menú interactivo
mostrar_menu() {
    imprimir_banner
    echo -e "${COLOR_BLANCO}${COLOR_BOLD}Seleccione la acción que desea realizar:${COLOR_RESET}\n"
    echo -e "  ${COLOR_CYAN}1)${COLOR_RESET} Deepin Desktop Environment (DDE) - Entorno nativo de Deepin"
    echo -e "  ${COLOR_CYAN}2)${COLOR_RESET} GNOME - Moderno, enfocado en flujos de trabajo limpios"
    echo -e "  ${COLOR_CYAN}3)${COLOR_RESET} KDE Plasma - Altamente personalizable y potente"
    echo -e "  ${COLOR_CYAN}4)${COLOR_RESET} XFCE - Muy ligero, rápido y de bajo consumo"
    echo -e "  ${COLOR_CYAN}5)${COLOR_RESET} Cinnamon - Tradicional, estilizado y fácil de usar"
    echo -e "  ${COLOR_CYAN}6)${COLOR_RESET} MATE - Clásico (continuación tradicional de GNOME 2)"
    echo -e "  ${COLOR_CYAN}7)${COLOR_RESET} LXQt - Ultraligero basado en bibliotecas Qt"
    echo -e "  ${COLOR_AMARILLO}8)${COLOR_RESET} Budgie - Entorno moderno y ligero, sabor oficial de Ubuntu"
    echo -e "  ${COLOR_CYAN}9)${COLOR_RESET} Configurar entorno de arranque automático al iniciar sesión"
    echo -e "  ${COLOR_ROJO}10)${COLOR_RESET} Salir"
    echo ""
}

# Actualizar índices de paquetes con manejo de errores
actualizar_repositorios() {
    echo -e "${COLOR_AZUL}[1/2] Actualizando índices de paquetes (apt-get update)...${COLOR_RESET}"
    if $SUDO_CMD apt-get update -y 2>&1 | grep -q "E:"; then
        echo -e "${COLOR_ROJO}[!] Error al actualizar repositorios${COLOR_RESET}"
        echo -e "${COLOR_AMARILLO}[i] Intentando reparar dependencias rotas...${COLOR_RESET}"
        $SUDO_CMD apt --fix-broken install -y 2>/dev/null || true
        return 1
    fi
    echo -e "${COLOR_VERDE}[✓] Índices de paquetes actualizados exitosamente${COLOR_RESET}"
    return 0
}

# Validar espacio en disco
validar_espacio_disco() {
    local min_gb="$1"
    local available
    available=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    available=${available:-0}
    
    if [[ "$available" -lt "$min_gb" ]]; then
        echo -e "${COLOR_AMARILLO}[!] Espacio en disco insuficiente.${COLOR_RESET}"
        echo -e "${COLOR_BLANCO}   Disponible: ${available}GB"
        echo -e "${COLOR_BLANCO}   Requerido: mínimamente ${min_gb}GB para la instalación${COLOR_RESET}"
        echo -e "${COLOR_CYAN}[i] Continuando de todos modos...${COLOR_RESET}"
        return 1
    fi
    echo -e "${COLOR_VERDE}[✓] Espacio en disco suficiente: ${available}GB disponibles${COLOR_RESET}"
    return 0
}

# Pregunta de confirmación
preguntar_si() {
    local pregunta="$1"
    local default="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${COLOR_CYAN}[DRY-RUN] Se habría preguntado: $pregunta${COLOR_RESET}"
        if [[ "$default" == "S" ]]; then
            echo -e "${COLOR_VERDE}[DRY-RUN] Se asume que responde: S${COLOR_RESET}"
            return 0
        else
            echo -e "${COLOR_VERDE}[DRY-RUN] Se asume que responde: n${COLOR_RESET}"
            return 1
        fi
    fi
    
    local respuesta
    if [[ "$default" == "S" ]]; then
        read -rp "${pregunta} [S/n]: " respuesta
        respuesta=${respuesta:-S}
    else
        read -rp "${pregunta} [s/N]: " respuesta
        respuesta=${respuesta:-n}
    fi
    
    if [[ "$respuesta" =~ ^[sS]$|^[sS][iI]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Crear backup de configuraciones
crear_backup() {
    local usuario="$1"
    local directorio="/tmp/gestor_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$directorio"
    
    echo -e "${COLOR_AZUL}[i] Creando backup en $directorio${COLOR_RESET}"
    
    # Backup de AccountsService
    if [[ -d /var/lib/AccountsService/users ]]; then
        local as_dir="/var/lib/AccountsService/users"
        if [[ -f "${as_dir}/${usuario}" ]]; then
            cp "${as_dir}/${usuario}" "$directorio/"
            echo -e "${COLOR_VERDE}[✓] Backup AccountsService creado${COLOR_RESET}"
        fi
    fi
    
    # Backup de .dmrc
    local home_dir
    home_dir=$(getent passwd "$usuario" | cut -d: -f6)
    if [[ -d "$home_dir" ]] && [[ -f "$home_dir/.dmrc" ]]; then
        cp "$home_dir/.dmrc" "$directorio/"
        echo -e "${COLOR_VERDE}[✓] Backup .dmrc creado${COLOR_RESET}"
    fi
    
    echo "$directorio"
}

# ==================== DEFINICIÓN DE PAQUETES SEGÚN ENTORNO ====================

obtener_paquetes_entorno() {
    local opcion="$1"
    PAQUETES=()
    NOMBRE_ENTORNO=""
    DM_SUGERIDO=""
    
    case "$opcion" in
        1)
            NOMBRE_ENTORNO="Deepin Desktop Environment (DDE)"
            DM_SUGERIDO="lightdm"
            PAQUETES=(
                "dde"
                "dde-desktop"
                "dde-dock"
                "dde-control-center"
                "dde-file-manager"
                "dde-session-ui"
                "dde-kwin"
                "lightdm"
            )
            ;;
        2)
            NOMBRE_ENTORNO="GNOME"
            DM_SUGERIDO="gdm3"
            PAQUETES=(
                "gnome-core"
                "gnome-shell"
                "gnome-session"
                "gnome-terminal"
                "nautilus"
                "gdm3"
            )
            ;;
        3)
            NOMBRE_ENTORNO="KDE Plasma"
            DM_SUGERIDO="sddm"
            PAQUETES=(
                "kde-plasma-desktop"
                "plasma-workspace"
                "dolphin"
                "konsole"
                "sddm"
            )
            ;;
        4)
            NOMBRE_ENTORNO="XFCE"
            DM_SUGERIDO="lightdm"
            PAQUETES=(
                "xfce4"
                "xfce4-goodies"
                "xfce4-terminal"
                "thunar"
                "lightdm"
            )
            ;;
        5)
            NOMBRE_ENTORNO="Cinnamon"
            DM_SUGERIDO="lightdm"
            PAQUETES=(
                "cinnamon-core"
                "cinnamon"
                "nemo"
                "gnome-terminal"
                "lightdm"
            )
            ;;
        6)
            NOMBRE_ENTORNO="MATE"
            DM_SUGERIDO="lightdm"
            PAQUETES=(
                "mate-desktop-environment-core"
                "mate-desktop-environment"
                "caja"
                "mate-terminal"
                "lightdm"
            )
            ;;
        7)
            NOMBRE_ENTORNO="LXQt"
            DM_SUGERIDO="sddm"
            PAQUETES=(
                "lxqt-core"
                "lxqt"
                "pcmanfm-qt"
                "qterminal"
                "sddm"
            )
            ;;
        8)
            NOMBRE_ENTORNO="Budgie"
            DM_SUGERIDO="gdm3"
            PAQUETES=(
                "budgie-desktop"
                "budgie-wm"
                "gdm3"
            )
            ;;
        9)
            # Window managers tipo tiling
            echo -e "\nSeleccione el window manager tipo tiling:"
            echo -e "  ${COLOR_CYAN}1)${COLOR_RESET} i3 (o i3-gaps)"
            echo -e "  ${COLOR_CYAN}2)${COLOR_RESET} bspwm"
            echo -e "  ${COLOR_CYAN}3)${COLOR_RESET} herbstluftwm"
            echo -e "  ${COLOR_CYAN}4)${COLOR_RESET} awesome"
            echo -e "  ${COLOR_ROJO}5)${COLOR_RESET} Cancelar"
            echo ""
            read -rp "Opción (1-5): " wm_opcion
            
            case "$wm_opcion" in
                1) PAQUETES=( "i3" "i3-win" "dmenu" "rofi" ); NOMBRE_ENTORNO="i3 Window Manager"; DM_SUGERIDO="none" ;;
                2) PAQUETES=( "bspwm" "sxhkd" "terminal" ); NOMBRE_ENTORNO="bspwm Window Manager"; DM_SUGERIDO="none" ;;
                3) PAQUETES=( "herbstluftwm" "terminal" ); NOMBRE_ENTORNO="herbstluftwm Window Manager"; DM_SUGERIDO="none" ;;
                4) PAQUETES=( "awesome" "rofi" "terminal" ); NOMBRE_ENTORNO="awesome Window Manager"; DM_SUGERIDO="none" ;;
                5) return 0 ;;
                *) echo -e "${COLOR_ROJO}[!] Opción no válida${COLOR_RESET}"; return 1 ;;
            esac
            ;;
        10)
            echo -e "\n${COLOR_VERDE}Operación finalizada. ¡Hasta pronto!${COLOR_RESET}\n"
            exit 0
            ;;
        *)
            echo -e "\n${COLOR_ROJO}[!] Opción no válida. Por favor, ingrese un número del 1 al 10.${COLOR_RESET}"
            return 1
            ;;
    esac
    return 0
}

# ==================== PROCESAMIENTO DE UN ENTORNO ESPECÍFICO ====================

procesar_entorno() {
    local paquetes_instalados=()
    local paquetes_faltantes=()
    local paquetes_no_disponibles=()
    
    echo -e "\n${COLOR_AZUL}=== Analizando estado de: $NOMBRE_ENTORNO ===${COLOR_RESET}\n"
    echo -e "${COLOR_CYAN}[i] Comprobando componentes individuales...${COLOR_RESET}"
    
    for pkg in "${PAQUETES[@]}"; do
        if esta_instalado "$pkg"; then
            paquetes_instalados+=("$pkg")
            echo -e "  ${COLOR_VERDE}[✓] Instalado:${COLOR_RESET} $pkg"
        else
            # Verificamos si existe en los repositorios locales
            if existe_en_repos "$pkg"; then
                paquetes_faltantes+=("$pkg")
                echo -e "  ${COLOR_ROJO}[✗] Faltante:${COLOR_RESET} $pkg"
            else
                paquetes_no_disponibles+=("$pkg")
                echo -e "  ${COLOR_AMARILLO}[?] No disponible en repositorios:${COLOR_RESET} $pkg"
            fi
        fi
    done
    
    echo ""
    echo -e "${COLOR_BOLD}Resumen de diagnóstico:${COLOR_RESET}"
    echo -e "  - Componentes instalados: ${#paquetes_instalados[@]}"
    echo -e "  - Componentes faltantes:  ${#paquetes_faltantes[@]}"
    if [[ ${#paquetes_no_disponibles[@]} -gt 0 ]]; then
        echo -e "  - Paquetes no hallados en repositorio: ${#paquetes_no_disponibles[@]}"
    fi
    
    local instalacion_realizada=false
    
    # Caso 1: Todos los paquetes ya están presentes
    if [[ ${#paquetes_faltantes[@]} -eq 0 && ${#paquetes_instalados[@]} -gt 0 ]]; then
        echo -e "\n${COLOR_VERDE}${COLOR_BOLD}¡Excelente! El entorno '$NOMBRE_ENTORNO' ya está completamente instalado y verificado.${COLOR_RESET}"
        echo -e "${COLOR_CYAN}Todos los paquetes esenciales se encuentran en el sistema.${COLOR_RESET}"
    # Caso 2: No se encontraron paquetes instalables (problema de repositorios)
    elif [[ ${#paquetes_faltantes[@]} -eq 0 && ${#paquetes_no_disponibles[@]} -gt 0 ]]; then
        echo -e "\n${COLOR_ROJO}[!] Ningún paquete faltante pudo ser localizado en los repositorios configurados de APT.${COLOR_RESET}"
        echo -e "${COLOR_AMARILLO}Por favor, verifique sus fuentes en /etc/apt/sources.list e intente de nuevo.${COLOR_RESET}"
        return 1
    # Caso 3: Faltan paquetes (o el entorno completo)
    else
        local tipo_instalacion="el entorno completo"
        if [[ ${#paquetes_instalados[@]} -gt 0 ]]; then
            tipo_instalacion="los componentes faltantes (${#paquetes_faltantes[@]} paquetes)"
        fi
        
        echo -e "\n${COLOR_AMARILLO}${COLOR_BOLD}Se requiere instalar $tipo_instalacion de '$NOMBRE_ENTORNO'.${COLOR_RESET}"
        echo -e "Paquetes a instalar: ${COLOR_CYAN}${paquetes_faltantes[*]}${COLOR_RESET}\n"
        
        read -rp "¿Desea proceder con la instalación ahora? [S/n]: " respuesta_instalar
        respuesta_instalar=${respuesta_instalar:-S}
        
        if [[ "$respuesta_instalar" =~ ^[sS]$|^[sS][iI]$ ]]; then
            if ! asegurar_root; then
                return 1
            fi
            
            # Validar espacio en disco antes de instalar
            validar_espacio_disco 2
            
            echo -e "\n${COLOR_CYAN}[1/2] Actualizando índices de paquetes (apt-get update)...${COLOR_RESET}"
            if actualizar_repositorios; then
                echo -e "\n${COLOR_CYAN}[2/2] Instalando paquetes faltantes...${COLOR_RESET}"
                if DEBIAN_FRONTEND=dialog $SUDO_CMD apt-get install -y "${paquetes_faltantes[@]}"; then
                    echo -e "\n${COLOR_VERDE}${COLOR_BOLD}¡Instalación completada exitosamente!${COLOR_RESET}"
                    instalacion_realizada=true
                    
                    # Crear backup después de instalación exitosa
                    if [[ "$DRY_RUN" != true ]]; then
                        local user
                        user=$(obtener_usuario_objetivo)
                        crear_backup "$user"
                    fi
                else
                    echo -e "\n${COLOR_ROJO}[!] Ocurrió un error durante la instalación con APT.${COLOR_RESET}"
                    echo -e "${COLOR_AMARILLO}Puede intentar resolver dependencias rotas con: sudo apt --fix-broken install${COLOR_RESET}"
                    return 1
                fi
            else
                echo -e "\n${COLOR_ROJO}[!] No se pudieron actualizar los repositorios.${COLOR_RESET}"
                return 1
            fi
        else
            echo -e "\n${COLOR_AMARILLO}[i] Operación de instalación omitida por el usuario.${COLOR_RESET}"
        fi
    fi
    
    # Pregunta: Configurar con qué entorno arrancar automáticamente
    echo ""
    echo -e "${COLOR_CYAN}${COLOR_BOLD}----------------------------------------------------------------------${COLOR_RESET}"
    read -rp "¿Desea elegir ahora con qué entorno arrancar automáticamente nada más iniciar sesión? [S/n]: " resp_arranque
    resp_arranque=${resp_arranque:-S}
    if [[ "$resp_arranque" =~ ^[sS]$|^[sS][iI]$ ]]; then
        configurar_arranque_automatico
    fi
    echo -e "${COLOR_CYAN}${COLOR_BOLD}----------------------------------------------------------------------${COLOR_RESET}"
    
    # Pregunta: Reiniciar el equipo tras una instalación
    if [[ "$instalacion_realizada" == true ]]; then
        echo ""
        echo -e "${COLOR_BLANCO}${COLOR_BOLD}======================================================================${COLOR_RESET}"
        echo -e "${COLOR_AMARILLO}${COLOR_BOLD}AVISO IMPORTANTE DE REINICIO:${COLOR_RESET}"
        echo -e "Para que el gestor de inicio de sesión (Display Manager) reconozca"
        echo -e "los nuevos componentes y se inicialicen los servicios correctamente,"
        echo -e "se recomienda reiniciar el equipo."
        echo -e "${COLOR_BLANCO}${COLOR_BOLD}======================================================================${COLOR_RESET}\n"
        
        read -rp "¿Desea reiniciar el equipo en este momento? [s/N]: " respuesta_reinicio
        respuesta_reinicio=${respuesta_reinicio:-N}
        
        if [[ "$respuesta_reinicio" =~ ^[sS]$|^[sS][iI]$ ]]; then
            echo -e "\n${COLOR_VERDE}[+] Reiniciando el sistema en 3 segundos... ¡Guarde su trabajo!${COLOR_RESET}"
            sleep 3
            if command -v systemctl &>/dev/null; then
                $SUDO_CMD systemctl reboot
            else
                $SUDO_CMD reboot
            fi
        else
            echo -e "\n${COLOR_CYAN}[i] No se reinició el equipo.${COLOR_RESET}"
            echo -e "    Podrá reiniciar manualmente cuando lo desee con: ${COLOR_BOLD}sudo reboot${COLOR_RESET}"
            echo -e "    O cerrar sesión para cambiar de entorno desde el selector de usuario."
        fi
    fi
}

# ==================== CONFIGURACIÓN DEL ENTORNO DE INICIO AUTOMÁTICO ====================

configurar_arranque_automatico() {
    echo -e "${COLOR_AZUL}=== Configurar Entorno de Arranque Automático al Iniciar Sesión ===${COLOR_RESET}\n"
    
    listar_entornos_instalados
    
    if [[ ${#ENTORNOS_IDS[@]} -eq 0 ]]; then
        echo -e "${COLOR_AMARILLO}[!] No se detectaron entornos de escritorio instalados en /usr/share/xsessions o /usr/share/wayland-sessions.${COLOR_RESET}"
        echo -e "${COLOR_CYAN}Primero instale un entorno de escritorio desde el menú principal.${COLOR_RESET}"
        return 1
    fi
    
    local target_user
    target_user=$(obtener_usuario_objetivo)
    
    echo -e "Usuario objetivo detectado: ${COLOR_CYAN}${COLOR_BOLD}$target_user${COLOR_RESET}"
    echo -e "${COLOR_BLANCO}${COLOR_BOLD}Entornos de escritorio disponibles en el sistema:${COLOR_RESET}\n"
    
    for i in "${!ENTORNOS_IDS[@]}"; do
        local indice=$((i + 1))
        echo -e "  ${COLOR_CYAN}$indice)${COLOR_RESET} ${COLOR_BOLD}${ENTORNOS_NOMBRES[$i]}${COLOR_RESET} (ID: ${ENTORNOS_IDS[$i]}) [${ENTORNOS_TIPOS[$i]}]"
    done
    echo -e "  ${COLOR_ROJO}0)${COLOR_RESET} Cancelar / Omitir cambio"
    echo ""
    
    local eleccion
    read -rp "¿Con qué entorno quieres que se arranque automáticamente nada más iniciar sesión? (1-${#ENTORNOS_IDS[@]}): " eleccion
    
    if [[ "$eleccion" == "0" || -z "$eleccion" ]]; then
        echo -e "${COLOR_AMARILLO}[i] No se realizaron cambios en el entorno de inicio.${COLOR_RESET}"
        return 0
    fi
    
    if ! [[ "$eleccion" =~ ^[0-9]+$ ]] || (( eleccion < 1 || eleccion > ${#ENTORNOS_IDS[@]} )); then
        echo -e "${COLOR_ROJO}[!] Selección no válida.${COLOR_RESET}"
        return 1
    fi
    
    local pos=$((eleccion - 1))
    local elegido_id="${ENTORNOS_IDS[$pos]}"
    local elegido_nombre="${ENTORNOS_NOMBRES[$pos]}"
    
    if ! asegurar_root; then
        return 1
    fi
    
    echo -e "\n[Aplicando configuración para '$elegido_nombre' ($elegido_id)..."
    
    # 1. Configuración en AccountsService (/var/lib/AccountsService/users/<usuario>)
    local as_file="/var/lib/AccountsService/users/$target_user"
    $SUDO_CMD mkdir -p /var/lib/AccountsService/users
    if [[ ! -f "$as_file" ]]; then
        cat <<EOF | $SUDO_CMD tee "$as_file" >/dev/null
[User]
Language=
XSession=$elegido_id
Session=$elegido_id
SystemAccount=false
EOF
    else
        $SUDO_CMD sed -i '/^XSession=/d' "$as_file"
        $SUDO_CMD sed -i '/^Session=/d' "$as_file"
        if grep -q "^\[User\]" "$as_file"; then
            $SUDO_CMD sed -i "/^\[User\]/a Session=$elegido_id\nXSession=$elegido_id" "$as_file"
        else
            echo -e "[User]\nSession=$elegido_id\nXSession=$elegido_id" | $SUDO_CMD tee -a "$as_file" >/dev/null
        fi
    fi
    echo -e "  [✓] AccountsService actualizado ($as_file)"
    
    # 2. Configuración en el directorio de usuario ~/.dmrc
    local home_dir
    home_dir=$(getent passwd "$target_user" | cut -d: -f6)
    if [[ -d "$home_dir" ]]; then
        local dmrc_file="$home_dir/.dmrc"
        cat <<EOF | $SUDO_CMD tee "$dmrc_file" >/dev/null
[Desktop]
Session=$elegido_id
EOF
        $SUDO_CMD chown "$target_user:$target_user" "$dmrc_file" 2>/dev/null || true
        $SUDO_CMD chmod 644 "$dmrc_file"
        echo -e "  [✓] Archivo de sesión local configurado ($dmrc_file)"
    fi
    
    # 3. Configuración para LightDM (Display Manager predeterminado en Deepin)
    if [[ -d /etc/lightdm ]]; then
        $SUDO_CMD mkdir -p /etc/lightdm/lightdm.conf.d
        cat <<EOF | $SUDO_CMD tee /etc/lightdm/lightdm.conf.d/50-default-session.conf >/dev/null
[Seat:*]
user-session=$elegido_id
EOF
        echo -e "  [✓] Configuración de LightDM actualizada (/etc/lightdm/lightdm.conf.d/50-default-session.conf)"
    fi
    
    # 4. Configuración para SDDM (si estuviera instalado)
    if [[ -d /etc/sddm.conf.d || -f /etc/sddm.conf || -d /usr/share/sddm ]]; then
        $SUDO_CMD mkdir -p /etc/sddm.conf.d
        cat <<EOF | $SUDO_CMD tee /etc/sddm.conf.d/50-default-session.conf >/dev/null
[Autologin]
Session=$elegido_id.desktop
EOF
        echo -e "  [✓] Configuración de SDDM actualizada (/etc/sddm.conf.d/50-default-session.conf)"
    fi
    
    # 5. Configurar alternativa x-session-manager si está disponible
    if command -v update-alternatives &>/dev/null; then
        local alt_candidates
        mapfile -t alt_candidates < <(update-alternatives --list x-session-manager 2>/dev/null || true)
        for alt in "${alt_candidates[@]}"; do
            if [[ "$alt" == *"$elegido_id"* ]]; then
                $SUDO_CMD update-alternatives --set x-session-manager "$alt" &>/dev/null || true
                echo -e "  [✓] Alternativa x-session-manager establecida a: $alt"
                break
            fi
        done
    fi
    
    echo -e "\n${COLOR_VERDE}¡Configuración aplicada con éxito!${COLOR_RESET}"
    echo -e "Al iniciar sesión, el usuario '${COLOR_CYAN}$target_user${COLOR_RESET}' entrará automáticamente en '${COLOR_BOLD}$elegido_nombre${COLOR_RESET}'."
    return 0
}

# ==================== BUCLE PRINCIPAL DE EJECUCIÓN ====================

main() {
    while true; do
        mostrar_menu
        read -rp "Ingrese su opción (1-10): " opcion
        
        obtener_paquetes_entorno "$opcion"
        local estado_retorno=$?
        
        if [[ $estado_retorno -eq 0 ]]; then
            procesar_entorno
            echo ""
            read -rp "Presione [ENTER] para regresar al menú principal..." _
        elif [[ $estado_retorno -eq 2 ]]; then
            # Opción 9 (Configurar arranque automático ejecutada directamente)
            echo ""
            read -rp "Presione [ENTER] para regresar al menú principal..." _
        else
            sleep 2
        fi
    done
}

# Ejecutar el script
main "$@"